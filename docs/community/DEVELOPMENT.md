# 开发与验证 / Development

项目完全采用 AI Coding 方式开发，欢迎使用 Codex、Claude Code 等工具共同维护。开始前读根目录 [AGENTS.md](../../AGENTS.md)、[AI 共建指南](AI_COLLABORATION.md) 和 [贡献指南](../../CONTRIBUTING.md)。Claude Code 入口 [CLAUDE.md](../../CLAUDE.md) 导入同一份规范；公共源码不依赖维护者的私人开发历史或服务账号。

## 依赖

- 标准版Godot **4.7.2**，完整标识以仓库根目录的[.godot-version](../../.godot-version)为准。不要用其他版本得到的结果冒充固定版本验证。
- macOS辅助脚本：Python 3.11或更新版本与系统自带的Shell工具。项目没有Node依赖。
- 制作新3D资产才需要Blender；运行应用不需要Tripo账号或API Key。

[Godot官方归档](https://godotengine.org/download/archive/4.7.2-stable/)提供固定版本编辑器。导出应用还需匹配版本的导出模板。当前Mac原生使用Forward+ / Metal；其他后端仍需实际验证。

## macOS第一次运行

从仓库根目录执行，先安装Godot到`/Applications/Godot.app`，或设置实际可执行路径：

```sh
# 只有不在默认位置时才需要这一行，替换为你自己的路径。
export GODOT_BIN="/path/to/Godot.app/Contents/MacOS/Godot"

# 首次运行/资源变更后导入；等待退出再运行下一条。
./tools/godot.sh --headless --editor --quit

# 首次体验：不写入用户存档，从宇宙视图开始。
./tools/godot.sh -- --no-save --experience-preset --scale=universe
```

若使用默认安装位置，请省略`export GODOT_BIN`那一行。运行`./tools/godot.sh`可使用正常保存功能；增加`--editor`可打开编辑器。辅助脚本会核对版本、降低任务优先级，并在已有本项目引擎进程时返回75。关闭预览后继续操作，不删除运行锁。

也可以直接从Godot项目管理器导入`project.godot`，等待导入完毕后按F5。编辑器和独立运行窗口保持单实例，不同时启动多个3D预览。

## Windows与Linux贡献者

使用同版本Godot项目管理器导入`project.godot`并等待资源导入。`godot.sh`、`preview_macos.py`和`export_macos.sh`是macOS开发辅助入口，不能作为Windows脚本运行。项目的Windows/低配验证尚未完成；遇到导入、驱动或画面问题时使用设备测试模板反馈，不要修改科学时间倍率来掩盖帧率。

## 相称验证

文档和社区配置：

```sh
python3 tools/check_community.py
```

翻译与导出资源清单：

```sh
python3 tools/check_localization.py
python3 tools/sync_export_resources.py --check
```

macOS / Linux 的轻量工具测试（不启动真实3D引擎）：

```sh
python3 -m unittest discover -s tests/tools -p 'test_*.py'
```

`test_project_runtime_guard.py` 使用 Unix 进程/文件锁接口；Windows 可先运行静态检查及 `test_public_snapshot.py`、`test_localization.py`，不要将未跑的运行锁检查写成通过。

macOS核心保存测试（独立临时文件，不改用户存档）：

```sh
mkdir -p .local/verification
./tools/godot.sh --headless --script res://tests/core/test_world_store.gd -- \
  --world-store-report=res://.local/verification/world-store.json
```

画面或输入修改：打开受影响场景，检查进入、返回、暂停和相关操作；附一张必要截图或说明。保留30/5 FPS、两共享工作线程。只有改动或复现问题需要时才扩大测试；不要将缺少Windows实机、听感或长测的部分写成通过。

`tests/integration/`包含历史场景诊断；部分用例需要额外科学对照资料或可见原生窗口。公共静态检查不宣称执行了这些套件，详细诊断记录也不随公开仓库全量分发。

## macOS本地导出

安装匹配模板后串行执行：

```sh
./tools/export_macos.sh
```

输出为`builds/macos/3DWorld.app`，不会自动生成维护者本机的`current`版本链接。导出前检查会报告礁区使用缓存还是运行时计算布局；当前替换后的生态资源使用已有的计算回退，首次进入仍可能需要准备。该检查验证当前依赖与配方，不把失效的旧物种文件当作必需输入，也不冒称重做了接触/性能验收。该导出预设用于开发验证；公开分发的签名、公证和新机器安装体验仍需独立处理。

导出后，可用 `python3 tools/preview_macos.py --screen <实际显示器编号>` 打开受运行锁保护的预览。它优先使用已有的 `builds/macos/current/3DWorld.app`；没有该版本入口时使用上述普通导出，首次贡献不需要创建维护者专用链接。先核对实际主/副屏，优先副屏；关闭窗口后才释放运行锁。

## 目录

| 目录 | 责任 |
|---|---|
| `scripts/core/` | 世界时间、科学模型、保存与资源预算 |
| `scripts/experience/` | 场景构建、空间观察、交互、说明界面 |
| `shaders/` | 表面、体积和点云的显示实现 |
| `scenes/` | 入口及各尺度的资源引用 |
| `assets/` | 运行模型、纹理、科学数据与许可 |
| `data/environment/` | 区域环境参考输入 |
| `tests/` | 核心和场景检查 |
| `tools/` | 启动、导出及公共检查辅助工具 |

GLB导入会抽取一些纹理，这些派生文件由公共`.gitignore`排除；请修改GLB或清单中的规范共享纹理，新增外部素材需补来源与哈希。

完整开发历史、原始大图、未采用资产与大量原生证据保留在维护资料中。公共快照保留运行依赖和来源，不依赖维护者的绝对路径或已有Godot缓存。

## English summary

Use the exact standard Godot build pinned in `.godot-version`. Import the project before running it. On macOS the helper accepts `GODOT_BIN`, enforces the version and serializes engine jobs. Windows/Linux users should use the editor's project manager; those platforms are not certified yet. Run `python3 tools/check_community.py` for documentation changes. The isolated save test above is available on macOS after import. Keep validation proportional and distinguish tested results from unverified platforms.


## 发行包的引擎许可 / Engine notices in binary distributions

分发导出应用时，同时附上`LICENSES/GODOT-MIT.txt`与`LICENSES/GODOT-NOTICES.txt`，以及项目的`LICENSING.md`、`THIRD_PARTY_NOTICES.md`和资源署名。当前完整引擎/组件文本通过同版本官方Godot的`Engine.get_license_text()`、`get_copyright_info()`与`get_license_info()`取得；包含可选/编辑器组件时不表示这些组件都进入应用。更新Godot版本时重新取得对应版本的声明；不把全部第三方代码归为项目MIT。

Ship the Godot MIT text and full component notices alongside any binary distribution. The checked files are `LICENSES/GODOT-MIT.txt` and `LICENSES/GODOT-NOTICES.txt`; keep project/asset attribution too. Refresh the engine notices when updating the pinned Godot version. Optional/editor-only inventory entries may be included.
