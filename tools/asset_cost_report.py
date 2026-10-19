#!/usr/bin/env python3
"""Inventory the experience scene's current file dependencies, not runtime memory.

Pure Python standard library; does not launch Godot/Blender or rewrite assets.
Source GLB mesh definitions and encoded image payloads are counted once per file.
Runtime procedural instances, material duplication and GPU allocations are distinct.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET_SUFFIXES = {'.glb', '.png', '.jpg', '.jpeg', '.webp', '.ogg', '.wav', '.res'}
TEXT_SUFFIXES = {'.tscn', '.tres', '.gd', '.gdshader', '.gdshaderinc'}
CACHE: dict[str, bytes] = {}


def raw(path: str) -> bytes:
    if path not in CACHE:
        CACHE[path] = (ROOT / path).read_bytes()
    return CACHE[path]


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def record(path: str) -> dict:
    value = raw(path)
    return {'path': path, 'disk_bytes': len(value), 'sha256': digest(value)}


def image_info(value: bytes) -> dict:
    if value.startswith(b'\x89PNG\r\n\x1a\n'):
        width, height, depth, kind = struct.unpack_from('>IIBB', value, 16)
        return {'format': 'PNG', 'width': width, 'height': height, 'bit_depth': depth,
                'png_color_type': kind, 'alpha_channel': kind in (4, 6)}
    if value.startswith(b'\xff\xd8'):
        offset = 2
        while offset < len(value):
            if value[offset] != 0xFF:
                offset += 1
                continue
            while value[offset] == 0xFF:
                offset += 1
            marker = value[offset]
            offset += 1
            if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
                continue
            length = int.from_bytes(value[offset:offset + 2], 'big')
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                depth, height, width, channels = struct.unpack_from('>BHHB', value, offset + 2)
                return {'format': 'JPEG', 'width': width, 'height': height,
                        'bit_depth': depth, 'channels': channels, 'alpha_channel': False}
            if length < 2:
                break
            offset += length
    return {'format': 'unparsed', 'width': None, 'height': None}


def glb_info(path: str) -> dict:
    value = raw(path)
    assert struct.unpack_from('<4sII', value) == (b'glTF', 2, len(value)), path
    offset, document, binary = 12, None, b''
    while offset < len(value):
        size, kind = struct.unpack_from('<II', value, offset)
        chunk = value[offset + 8:offset + 8 + size]
        if kind == 0x4E4F534A:
            document = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + size
    assert document is not None and offset == len(value), path
    meshes, images, points = [], [], []
    for index, mesh in enumerate(document.get('meshes', [])):
        surfaces = []
        for primitive in mesh['primitives']:
            position = document['accessors'][primitive['attributes']['POSITION']]
            if 'min' in position and 'max' in position:
                points.extend((position['min'], position['max']))
            count = document['accessors'][primitive['indices']]['count'] if 'indices' in primitive else position['count']
            mode = primitive.get('mode', 4)
            triangles = count // 3 if mode == 4 else max(0, count - 2) if mode in (5, 6) else 0
            surfaces.append({'topology_mode': mode, 'vertices_with_seams': position['count'],
                             'indices_or_vertices': count, 'triangles': triangles,
                             'material_index': primitive.get('material')})
        meshes.append({'index': index, 'name': mesh.get('name'), 'surfaces': surfaces,
                       'triangles': sum(p['triangles'] for p in surfaces)})
    for index, image in enumerate(document.get('images', [])):
        if 'bufferView' not in image:
            raise ValueError(f'{path}: external image URI is outside this self-contained GLB accounting contract')
        view = document['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        payload = binary[start:start + view['byteLength']]
        assert len(payload) == view['byteLength']
        images.append({'index': index, 'name': image.get('name'), 'buffer_view': image['bufferView'],
                       'encoded_bytes': len(payload), 'sha256': digest(payload), **image_info(payload)})
    bounds = [[min(p[k] for p in points) for k in range(3)],
              [max(p[k] for p in points) for k in range(3)]] if points else None
    return {**record(path), 'kind': 'self_contained_glb', 'mesh_definitions': len(meshes),
            'mesh_node_instances_in_file': sum('mesh' in n for n in document.get('nodes', [])),
            'surfaces': sum(len(m['surfaces']) for m in meshes),
            'triangles_unique_mesh_definitions': sum(m['triangles'] for m in meshes),
            'materials': len(document.get('materials', [])), 'meshes': meshes,
            'embedded_images': images, 'image_definitions': len(images),
            'embedded_encoded_image_bytes': sum(i['encoded_bytes'] for i in {i['buffer_view']: i for i in images}.values()),
            'position_buffer_bounds_m': bounds,
            'position_buffer_extent_m': [bounds[1][k] - bounds[0][k] for k in range(3)] if bounds else None,
            'bounds_scope': 'glTF POSITION buffer min/max; rest/bind geometry, no animated skin or scene placement evaluation',
            'animations': [a.get('name') for a in document.get('animations', [])],
            'skin_count': len(document.get('skins', []))}


def references(path: str) -> list[str]:
    if Path(path).suffix not in TEXT_SUFFIXES:
        return []
    text = raw(path).decode('utf-8')
    found = set(re.findall(r'["\']res://([^"\'\s]+)["\']', text))
    return sorted(p for p in found if '%' not in p and (ROOT / p).is_file())


def closure(start: list[str]) -> set[str]:
    seen, pending = set(), list(start)
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        seen.add(path)
        pending.extend(references(path))
    return seen


def configured_stages() -> tuple[dict[str, str], dict[str, str]]:
    main = raw('scripts/experience/experience.gd').decode('utf-8')
    block = re.search(r'const STAGE_PATHS\s*:\s*Dictionary\s*=\s*\{(.*?)\}', main, re.S)
    if not block:
        raise ValueError('STAGE_PATHS contract changed: review stage discovery before reusing this report')
    mapping = dict(re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', block[1]))
    if 'res://scenes/experience/%s_stage.tscn' not in main:
        raise ValueError('Stage path template changed: do not silently count unrelated .tscn files')
    stages = {family: f'scenes/experience/{family}_stage.tscn' for family in sorted(set(mapping.values()))}
    assert all((ROOT / path).is_file() for path in stages.values())
    return mapping, stages


def totals(paths: list[str], assets: dict[str, dict]) -> dict:
    models = [assets[p] for p in paths if assets[p]['kind'] == 'self_contained_glb']
    return {'unique_asset_files': len(paths), 'disk_bytes': sum(assets[p]['disk_bytes'] for p in paths),
            'glb_files': len(models), 'standalone_image_files': sum(assets[p]['kind'] == 'standalone_image' for p in paths),
            'godot_binary_resource_files': sum(assets[p]['kind'] == 'godot_binary_resource' for p in paths),
            'mesh_definitions': sum(a['mesh_definitions'] for a in models),
            'surfaces': sum(a['surfaces'] for a in models),
            'triangles_unique_mesh_definitions': sum(a['triangles_unique_mesh_definitions'] for a in models),
            'embedded_image_definitions': sum(a['image_definitions'] for a in models),
            'embedded_encoded_image_bytes': sum(a['embedded_encoded_image_bytes'] for a in models)}


def duplicate_images(assets: dict[str, dict]) -> dict:
    groups = defaultdict(list)
    for path, asset in assets.items():
        if asset['kind'] == 'self_contained_glb':
            for image in {i['buffer_view']: i for i in asset['embedded_images']}.values():
                groups[image['sha256']].append({'path': path, 'image_index': image['index'],
                    'name': image['name'], 'encoded_bytes': image['encoded_bytes'],
                    'size': [image['width'], image['height']], 'storage': 'embedded'})
        elif asset['kind'] == 'standalone_image':
            groups[asset['sha256']].append({'path': path, 'image_index': None, 'name': Path(path).name,
                'encoded_bytes': asset['disk_bytes'], 'size': [asset['width'], asset['height']], 'storage': 'standalone'})
    duplicate = [{'sha256': key, 'copies': copies,
                  'redundant_encoded_bytes': copies[0]['encoded_bytes'] * (len(copies) - 1)}
                 for key, copies in groups.items() if len(copies) > 1]
    return {'matching_rule': 'identical encoded image bytes via SHA-256; visual similarity is not deduplicated',
            'image_payload_copies': sum(len(c) for c in groups.values()), 'unique_encoded_image_payloads': len(groups),
            'encoded_bytes_all_copies': sum(c['encoded_bytes'] for copies in groups.values() for c in copies),
            'encoded_bytes_unique_payloads': sum(copies[0]['encoded_bytes'] for copies in groups.values()),
            'redundant_encoded_bytes': sum(g['redundant_encoded_bytes'] for g in duplicate),
            'groups': sorted(duplicate, key=lambda g: g['redundant_encoded_bytes'], reverse=True),
            'not_a_memory_measurement': True}


def rework() -> list[dict]:
    pairs = [('海葵高档 v3→v4', 'reef/anemone_v3/anemone_v3_lod1.glb', 'reef/anemone_v4_attached/anemone_v4_lod1.glb'),
             ('海葵低档 v3→v4', 'reef/anemone_v3/anemone_v3_lod2.glb', 'reef/anemone_v4_attached/anemone_v4_lod2.glb'),
             ('鱼近景 v8→v9（胸鳍修订）', 'fish/v8/percula_v8_lod0.glb', 'fish/v9/percula_v9_lod0.glb'),
             ('鱼中远景 v8→v9（对应重简化）', 'fish/v8/percula_v8_lod1.glb', 'fish/v9/percula_v9_lod1.glb'),
             ('鱼近景 v7→v8（头部修订）', 'fish/v7/percula_v7_lod0.glb', 'fish/v8/percula_v8_lod0.glb'),
             ('鱼中远景 v7→v8（对应重简化）', 'fish/v7/percula_v7_lod1.glb', 'fish/v8/percula_v8_lod1.glb'),
             ('鱼近景 v6→v7（法线修订）', 'fish/v6/percula_v6_lod0.glb', 'fish/v7/percula_v7_lod0.glb'),
             ('鱼中远景 v6→v7（原样沿用）', 'fish/v6/percula_v6_lod1.glb', 'fish/v7/percula_v7_lod1.glb'),
             ('鱼近景 v5→v6（历史）', 'fish/v5/percula_v5_lod0.glb', 'fish/v6/percula_v6_lod0.glb'),
             ('鱼中远景 v5→v6（原样沿用）', 'fish/v5/percula_v5_lod1.glb', 'fish/v6/percula_v6_lod1.glb'),
             ('鱼近景 v1→v2（历史）', 'fish/percula_lod0.glb', 'fish/percula_v2_lod0.glb'),
             ('鱼中远景 v1→v2（历史）', 'fish/percula_lod1.glb', 'fish/percula_v2_lod1.glb'),
             ('鱼近景 v2→v3（历史）', 'fish/percula_v2_lod0.glb', 'fish/v3/percula_v3_lod0.glb'),
             ('鱼中远景 v2→v3（历史）', 'fish/percula_v2_lod1.glb', 'fish/v3/percula_v3_lod1.glb'),
             ('鱼近景 v3→v4（历史）', 'fish/v3/percula_v3_lod0.glb', 'fish/v4/percula_v4_lod0.glb'),
             ('鱼中远景 v3→v4（历史）', 'fish/v3/percula_v3_lod1.glb', 'fish/v4/percula_v4_lod1.glb'),
             ('鱼近景 v4→v5（历史）', 'fish/v4/percula_v4_lod0.glb', 'fish/v5/percula_v5_lod0.glb'),
             ('鱼中远景 v4→v5（历史）', 'fish/v4/percula_v4_lod1.glb', 'fish/v5/percula_v5_lod1.glb'),
             ('海葵高档 v1→v2（历史）', 'reef/anemone_lod0.glb', 'reef/anemone_v2_lod1.glb'),
             ('海葵低档 v1→v2（历史）', 'reef/anemone_lod1.glb', 'reef/anemone_v2_lod2.glb'),
             ('海葵高档 v2→v3', 'reef/anemone_v2_lod1.glb', 'reef/anemone_v3/anemone_v3_lod1.glb'),
             ('海葵低档 v2→v3', 'reef/anemone_v2_lod2.glb', 'reef/anemone_v3/anemone_v3_lod2.glb'),
             ('盘珊瑚高档 v1→v2', 'reef/plate_coral_lod0.glb', 'reef/plate_v2/plate_v2_lod0.glb'),
             ('盘珊瑚低档 v1→v2', 'reef/plate_coral_lod1.glb', 'reef/plate_v2/plate_v2_lod1.glb')]
    pairs += [(f'盘珊瑚 v2→v3 {form} LOD{lod}（分支比较）',
               f'reef/plate_v2/plate_v2_lod{lod}.glb',
               f'reef/plate_v3/plate_v3_{form}_lod{lod}.glb')
              for form in ('fan', 'cup', 'lobed') for lod in (0, 1)]
    pairs += [(f'盘珊瑚 v3→v4 {form} LOD{lod}',
               f'reef/plate_v3/plate_v3_{form}_lod{lod}.glb',
               f'reef/plate_v4/plate_v4_{form}_lod{lod}.glb')
              for form in ('fan', 'cup', 'lobed') for lod in (0, 1)]
    pairs += [(f'枝状 v1→v2 {form} LOD{lod}（分支比较）',
               f'reef/branching_coral_lod{lod}.glb',
               f'reef/branching_v2/branching_v2_{form}_lod{lod}.glb')
              for form in ('cushion', 'bush') for lod in (0, 1)]
    pairs += [(f'枝状 v2→v3_uv {form} LOD{lod}',
               f'reef/branching_v2/branching_v2_{form}_lod{lod}.glb',
               f'reef/branching_v3_uv/branching_v3_uv_{form}_lod{lod}.glb')
              for form in ('cushion', 'bush') for lod in (0, 1)]
    pairs += [(f'枝状 v3_uv→v4 {form} LOD{lod}',
               f'reef/branching_v3_uv/branching_v3_uv_{form}_lod{lod}.glb',
               f'reef/branching_v4/branching_v4_{form}_lod{lod}.glb')
              for form in ('cushion', 'bush') for lod in (0, 1)]
    result = []
    for label, before, after in pairs:
        old, new = glb_info('assets/models/' + before), glb_info('assets/models/' + after)
        metric = ['disk_bytes', 'mesh_definitions', 'surfaces', 'triangles_unique_mesh_definitions', 'image_definitions']
        result.append({'label': label, 'before': {'path': old['path'], **{k: old[k] for k in metric}},
                       'after': {'path': new['path'], **{k: new[k] for k in metric}},
                       'change': {k: new[k] - old[k] for k in metric},
                       'semantic_note': 'Recorded version replacement, including history; active dependencies are listed separately. Anemone LOD labels differ, not equivalent tessellation levels'})
    return result


def production_records() -> dict:
    paths = ['assets/source/reef/manifest.json', 'assets/source/reef/anemone_v2_manifest.json',
             'assets/source/reef/anemone_v3/manifest.json', 'assets/source/reef/plate_v2/manifest.json',
             'assets/source/reef/plate_v3/manifest.json',
             'assets/source/reef/plate_v4/manifest.json', 'assets/source/reef/branching_v2/manifest.json',
             'assets/source/reef/branching_v3/manifest.json', 'assets/source/reef/branching_v3_uv/manifest.json',
             'assets/source/reef/branching_v4/manifest.json',
             'assets/source/reef/coast_rock_candidate013/manifest.json',
             'assets/source/reef/anemone_v4_candidate007/manifest.json',
             'assets/source/reef/anemone_v4_fit002/manifest.json',
             'assets/source/fish/manifest.json', 'assets/source/fish/manifest_v2.json',
             'assets/source/fish/v3/manifest_v3.json',
             'assets/source/fish/v4/manifest_v4.json',
             'assets/source/fish/v5/manifest_v5.json',
             'assets/source/fish/v6/manifest_v6.json',
             'assets/source/fish/v7/manifest_v7.json',
             'assets/source/fish/v8/manifest_v8.json',
             'assets/source/fish/v8/lod1-build.json',
             'assets/source/fish/v9/percula_v9-build.json',
             'assets/source/fish/v9/lod1-build.json',
             'assets/source/heart/manifest.json']
    records = []
    for path in paths:
        document = json.loads(raw(path))
        key = next((key for key in ('total_build_seconds', 'build_seconds', 'elapsed_build_s', 'elapsed_s', 'seconds') if key in document), 'build_seconds')
        records.append({'manifest': path, 'sha256': digest(raw(path)), 'recorded_field': key,
                        'latest_recorded_script_seconds': document.get(key),
                        'scope': 'one recorded generator execution; excludes planning, coding, troubleshooting, rendering and review',
                        'blender': document.get('blender')})
    ledger_path = 'docs/references/lookdev/imagegen-ledger.json'
    ledger = json.loads(raw(ledger_path))
    return {'generator_records': records, 'imagegen_ledger': ledger_path,
            'selected_imagegen_outputs': [{'id': item['id'], 'path': item['path'], 'size': item['size'],
                                          'sha256': item['sha256'], 'model_version': item['model_version']} for item in ledger],
            'total_generator_runs': None, 'human_design_coding_review_hours': None,
            'imagegen_elapsed_seconds': None, 'imagegen_billed_cost': None,
            'unknown_reason': 'Latest manifests/logs are partial checkpoints; repeated runs and human/agent iteration were not time-tracked comprehensively.'}


def mib(value: int) -> str:
    return f'{value / 1048576:.2f}'


def short_link(path: str) -> str:
    target = '../' + path if not path.startswith('docs/') else path[5:]
    return f'[{Path(path).name}]({target})'


def write_markdown(report: dict, destination: Path) -> None:
    t, dup = report['active_unique_totals'], report['encoded_image_duplication']
    lines = ['# 阶段 0 资产与制作成本清点', '',
             f"> 生成于 {report['generated_at_utc']} · 当前入口 `{report['experience_entry']}` · 可重跑：`python3 tools/asset_cost_report.py`。",
             '', f"当前 4 类场景引用 **{t['unique_asset_files']} 个唯一二进制资产文件，磁盘共 {mib(t['disk_bytes'])} MiB**。这是当前场景的文件依赖集合，不是 RSS、GPU 驻留、发布包大小或每帧渲染量。", '',
             '## 统计口径', '',
             '- 从主入口的 `STAGE_PATHS` 找到实际使用的场景，再递归读取其文件引用；相同文件跨场景只计一次。没有把整个仓库旧版本相加。',
             '- 表中 mesh / surface / 三角形指 GLB 内唯一网格定义。包含场景声明的高低 LOD，即使构建器当前只实例化其中一个；不乘场景中的礁块或 MultiMesh 实例，也不等于 GPU draw calls。',
             '- GLB 自包含的 PNG 已在 GLB 字节中，单独统计图片负担时不再加回总磁盘体积。`.blend`、离线图、概念参考、历史版本、`.godot` 缓存和生成中的几何另列。',
             '- 纹理尺寸是实际编码图片头部读数，不以提示词所请求的尺寸代替。未推算解压纹理内存，也未把准入估算 `_estimate_mb()` 当成测量。',
             '- JSON 保存依赖路径和 SHA-256；这是生成时快照，主场景换资源后应重跑。', '',
             '## 当前场景文件依赖', '',
             '| 场景族 / 对应尺度 | GLB / 独立图片 / Godot资源 | 磁盘 MiB | mesh / surface | 资源三角形合计 |',
             '|---|---:|---:|---:|---:|']
    for family, stage in report['stages'].items():
        v = stage['totals']
        lines.append(f"| {family} / {', '.join(stage['scale_ids'])} | {v['glb_files']} / {v['standalone_image_files']} / {v['godot_binary_resource_files']} | {mib(v['disk_bytes'])} | {v['mesh_definitions']} / {v['surfaces']} | {v['triangles_unique_mesh_definitions']:,} |")
    for asset in report['assets']:
        if asset['kind'] == 'godot_binary_resource':
            lines.extend(['', f"Godot二进制资源：{short_link(asset['path'])}，{asset['disk_bytes']}字节；只计本文件，不解析其内部依赖或估算内存。"])
    lines.extend(['', '各场景行不能直接相加作为唯一集合：鱼近景 GLB 同时用于海洋与心脏上下文，合计只算一次。微观行的零磁盘模型不代表没有几何或渲染成本。', '',
                  '## 当前 GLB 逐文件', '',
                  '| 文件 | MiB | mesh / surface | 三角形 | 内嵌图片数 / 实际尺寸 | 源几何包围盒 X×Y×Z（m） |',
                  '|---|---:|---:|---:|---|---|'])
    for asset in report['assets']:
        if asset['kind'] != 'self_contained_glb':
            continue
        sizes = ', '.join(sorted({f"{i['width']}×{i['height']}" for i in asset['embedded_images']}))
        extent = ' × '.join(f'{x:.6f}' for x in asset['position_buffer_extent_m'])
        lines.append(f"| {short_link(asset['path'])} | {mib(asset['disk_bytes'])} | {asset['mesh_definitions']} / {asset['surfaces']} | {asset['triangles_unique_mesh_definitions']:,} | {asset['image_definitions']} / {sizes} | {extent} |")
    lines.extend(['', '包围盒来自 glTF POSITION 的静止/绑定网格数据；不是运动极限、摆入场景后的尺寸或生物测量。A. percula 设计总长 80 mm，两档实际包围盒见上表；全鳍展开宽高不等于鱼体厚度和体深。心脏规范模型约 1.114 m 长，4 mm 仅是嵌入鱼体的作者化布局假设；它是一般硬骨鱼示意，不是目标鱼精确重建。礁区及海葵形态同样没有宣称逐物种扫描。', '',
                  '## 独立图片与重复贴图', '',
                  '| 当前引用图片 | MiB | 实际尺寸 | 编码 |', '|---|---:|---:|---|'])
    for asset in report['assets']:
        if asset['kind'] == 'standalone_image':
            lines.append(f"| {short_link(asset['path'])} | {mib(asset['disk_bytes'])} | {asset['width']}×{asset['height']} | {asset['format']} |")
    lines.extend(['', f"当前依赖里共有 {dup['image_payload_copies']} 份编码图片载荷，按完整字节 SHA-256 分组后有 {dup['unique_encoded_image_payloads']} 份不同内容。重复编码载荷合计 **{mib(dup['redundant_encoded_bytes'])} MiB**。这说明自包含 GLB 的磁盘重复，不证明 Godot 已去重或重复分配同样大小的 GPU 内存。", '',
                  '| 完全相同的图片 | 份数 | 重复编码 MiB | 所在资产 |', '|---|---:|---:|---|'])
    for group in dup['groups']:
        copies = group['copies']
        paths = ', '.join(sorted({Path(c['path']).name for c in copies}))
        lines.append(f"| {copies[0]['name']} ({copies[0]['size'][0]}×{copies[0]['size'][1]}) | {len(copies)} | {mib(group['redundant_encoded_bytes'])} | {paths} |")
    lines.extend(['', '只识别编码字节完全相同的内容；RGB 相同但 Alpha/PNG 编码不同的图没有冒充可直接去重。可在视觉稳定后评估外置共享贴图、导入复用与发布包压缩，再用实际驻留和加载测试判断收益。', '',
                  '## 版本返工变化（含历史）', '',
                  '| 版本替换关系 | 磁盘 MiB | 三角形 | surface |', '|---|---:|---:|---:|'])
    for item in report['rework_comparisons']:
        a, b = item['before'], item['after']
        lines.append(f"| {item['label']}：{Path(a['path']).name} → {Path(b['path']).name} | {mib(a['disk_bytes'])} → {mib(b['disk_bytes'])} | {a['triangles_unique_mesh_definitions']:,} → {b['triangles_unique_mesh_definitions']:,} | {a['surfaces']} → {b['surfaces']} |")
    lines.extend(['', '上表包含历史版本，不代表全部同时接入；盘珊瑚v3的三种形态各与同一个v2源比较，分支差值不能相加作为总增长；实际依赖以本报告当前GLB逐文件表为准。海葵高档使用LOD1、低档使用LOD2，旧版LOD编号不同的替换不作为同等网格精度比较。鱼体细节、海葵曲线和珊瑚支撑均需实际组合评阅，高三角数不等于高画质。', '',
                  '## 可编辑源与程序生成几何', '',
                  '| 支撑当前资产的可编辑源 | 磁盘 MiB |', '|---|---:|'])
    for source in report['selected_editable_blends']:
        lines.append(f"| {short_link(source['path'])} | {mib(source['disk_bytes'])} |")
    lines.extend(['', '这些源文件用于制作和修改，不在当前运行场景的直接文件依赖中；源库内含历史对象也不将它们算作运行驻留。完整未引用 GLB 列表与字节数保存在 JSON 的 `excluded_unreferenced_glbs`，仅供清理/归档决策，不加入上表。', '',
                  '微观、星空、海面/海床网格、粒子和部分灯光/材质在 GDScript 中运行时构建。磁盘 GLB 表没有覆盖它们的实例数、vertex buffer 或纹理分配。已有微观 headless 构建证据单独列于下表；它不是本脚本重新测量，也不是每帧可见量。', '',
                  '| 已有微观证据尺度 | 报告 mesh_triangles | 报告 particle_quads |', '|---|---:|---:|'])
    micro = report.get('existing_micro_construction_evidence', {})
    for stage in micro.get('stages', []):
        lines.append(f"| {stage['scale_id']} | {stage.get('mesh_triangles', 0):,} | {stage.get('particle_quads', 0):,} |")
    lines.extend(['', f"证据：{short_link('assets/source/micro/construction-audit.json')}。几何、材质、SSS、景深、透明与实例化的实际帧代价仍需主任务采样。", '',
                  '## 已记录的制作投入', '',
                  '| 记录 | 最新记录的单次脚本秒数 |', '|---|---:|'])
    for item in report['production']['generator_records']:
        lines.append(f"| {short_link(item['manifest'])} / `{item['recorded_field']}` | {item['latest_recorded_script_seconds']} |")
    lines.extend(['', '上述数字只是各 manifest 保存的一次生成脚本耗时。礁区 total_build_seconds 已包含其分项，不重复相加。它们不包括资料核查、编写生成器、反复调形、失败重跑、离线渲染、引擎联调和审核；日志会被后续运行覆盖，无法重建完整制作投入。**设计/对话/审核人工时、总重跑次数、imagegen 等待时间与费用均未知**，没有将几秒脚本运行包装成几秒完成高质量资产。', '',
                  'imagegen ledger 记录了 3 份选定输出：1 份水下目标参考、2 份已被场景引用的二维纹理（海床和悬浮粒子）。可确认减少了寻找/绘制二维底图、粒子抠图和提出视觉方向的工作；具体节省多少小时没有对照记录。未由工具暴露的模型版本和收费不推测。', '',
                  '## 成本判断与未测边界', '',
                  '原创程序建模已快速提供可编辑拓扑、UV、PBR 图片、骨架、LOD 和可重复导出；同源生成也便于修正比例、替换材质和做自动审计。imagegen 对二维参考、海床和 RGBA 小素材有效。二者目前没有替代近景形体雕刻、自然不规则性、可信的鳍/眼/皮肤、材质与灯光统一、运动打磨以及科学审核。', '',
                  '实际鱼体与海葵关键近景仍有程序模型感；心脏与微观仍是作者化科学示意。资产文件增加、面数增加、格式审计通过都不能证明已达到“真实且精美”。继续投入应优先做同相机/同光照/同时间对照、局部形体和材质修正，再依据性能实测决定删面、代理或贴图共享，避免单纯堆面数。', '',
                  '**本报告没有 RSS、GPU 资源占用、转场峰值、GPU 帧时间、加载时长或完整发布包大小测量。** 多个场景是否共享资源、同时驻留多少、材质复制多少，均留给运行实测。图像分辨率、源文件磁盘 MiB 和 `_estimate_mb()` 与这些指标不能互换。', '',
                  f"原始可机读清单：{short_link('docs/evidence/M0-005/asset-cost-inventory.json')}。默认工程入口当前为 `{report['project_default_scene']}`；本报告始终针对明确指定的体验入口，二者不相同时不要混用旧 Release 的成本结论。", ''])
    destination.write_text('\n'.join(lines), encoding='utf-8')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', default='docs/evidence/M0-005/asset-cost-inventory.json')
    parser.add_argument('--markdown', default='docs/ASSET_COST_REPORT.md')
    args = parser.parse_args()
    mapping, stages = configured_stages()
    family_dependencies = {family: closure([path]) for family, path in stages.items()}
    dependencies = closure(['scenes/experience.tscn']) | set().union(*family_dependencies.values())
    asset_paths = sorted(p for p in dependencies if Path(p).suffix in ASSET_SUFFIXES)
    assets = {}
    for path in asset_paths:
        if path.endswith('.glb'):
            assets[path] = glb_info(path)
        elif path.endswith('.res'):
            assets[path] = {**record(path), 'kind': 'godot_binary_resource'}
        else:
            assets[path] = {**record(path), 'kind': 'standalone_image', **image_info(raw(path))}
    family_reports = {}
    for family, refs in family_dependencies.items():
        paths = sorted(set(asset_paths) & refs)
        family_reports[family] = {'scene': stages[family], 'scale_ids': [s for s, f in mapping.items() if f == family],
                                  'asset_paths': paths, 'totals': totals(paths, assets)}
    excluded = [record(str(p.relative_to(ROOT))) for p in sorted((ROOT / 'assets/models').rglob('*.glb'))
                if str(p.relative_to(ROOT)) not in assets]
    source_assets = {
        'assets/source/reef/reef_library.blend': ['reef/branching_coral_', 'reef/massive_', 'reef/reef_rock_', 'reef/plate_coral_'],
        'assets/source/reef/anemone_v2.blend': ['reef/anemone_v2_'],
        'assets/source/reef/anemone_v3/anemone_v3.blend': ['reef/anemone_v3/'],
        'assets/source/reef/anemone_v4_fit002/anemone_v4.blend': ['reef/anemone_v4_attached/'],
        'assets/source/reef/coast_rock_candidate013/coast_rocks_05_rebaked.blend': ['reef/coast_rock_v1/'],
        'assets/source/reef/plate_v2/plate_v2.blend': ['reef/plate_v2/'],
        'assets/source/reef/plate_v3/plate_v3.blend': ['reef/plate_v3/'],
        'assets/source/reef/plate_v4/plate_v4.blend': ['reef/plate_v4/'],
        'assets/source/reef/branching_v2/branching_v2.blend': ['reef/branching_v2/'],
        'assets/source/reef/branching_v3_uv/branching_v3_uv.blend': ['reef/branching_v3_uv/'],
        'assets/source/reef/branching_v4/branching_v4.blend': ['reef/branching_v4/'],
        'assets/source/fish/v3/percula_v3.blend': ['fish/v3/'],
        'assets/source/fish/v4/percula_v4.blend': ['fish/v4/'],
        'assets/source/fish/v5/percula_v5.blend': ['fish/v5/'],
        'assets/source/fish/v6/percula_v6.blend': ['fish/v6/'],
        'assets/source/fish/v7/percula_v7.blend': ['fish/v7/'],
        'assets/source/fish/v8/percula_v8.blend': ['fish/v8/'],
        'assets/source/fish/v9/percula_v9.blend': ['fish/v9/percula_v9'],
        'assets/source/heart/teleost_heart.blend': ['heart/'],
    }
    editable = [source for source, prefixes in source_assets.items()
                if any(path.startswith('assets/models/' + prefix) for path in asset_paths for prefix in prefixes)]
    project = raw('project.godot').decode('utf-8')
    default = re.search(r'run/main_scene="([^"]+)"', project)
    report = {'schema_version': 1, 'generated_at_utc': datetime.now(timezone.utc).isoformat(timespec='seconds'),
              'experience_entry': 'scenes/experience.tscn', 'project_default_scene': default[1] if default else None,
              'scope': 'Current experience file dependencies; not measured residency, per-frame geometry, GPU/RSS or export package size',
              'stages': family_reports, 'active_unique_totals': totals(asset_paths, assets),
              'assets': list(assets.values()), 'encoded_image_duplication': duplicate_images(assets),
              'rework_comparisons': rework(), 'selected_editable_blends': [record(p) for p in editable],
              'excluded_unreferenced_glbs': excluded,
              'unreferenced_glbs_ignored_by_godot': [r['path'] for r in excluded if any((p / '.gdignore').exists() for p in (ROOT / r['path']).parents if p.is_relative_to(ROOT))], 'production': production_records(),
              'existing_micro_construction_evidence': {'path': 'assets/source/micro/construction-audit.json',
                    'scope': 'Existing external evidence, not rerun by inventory script',
                    **json.loads(raw('assets/source/micro/construction-audit.json'))},
              'unknown_metrics': {'resident_set_bytes': None, 'gpu_resident_bytes': None,
                                  'transition_peak_bytes': None, 'actual_frame_triangles': None,
                                  'gpu_draw_calls': None, 'imported_texture_allocation_bytes': None},
              'dependency_inputs': [record(p) for p in sorted(dependencies)],
              'source_note': 'Byte hashes freeze this report snapshot; scene references may change during parallel integration.'}
    assert report['active_unique_totals']['disk_bytes'] == sum(a['disk_bytes'] for a in report['assets'])
    assert not (set(asset_paths) & {p['path'] for p in excluded})
    json_path, md_path = ROOT / args.json, ROOT / args.markdown
    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    write_markdown(report, md_path)
    print(json.dumps({'json': str(json_path.relative_to(ROOT)), 'markdown': str(md_path.relative_to(ROOT)),
                      'active': report['active_unique_totals'], 'duplicate_encoded_bytes': report['encoded_image_duplication']['redundant_encoded_bytes'],
                      'excluded_unreferenced_glb_count': len(excluded)}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
