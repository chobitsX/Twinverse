"""Regress the real clean-import failure: callback/manifest dependencies, never caches."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

REPO=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('snapshot',REPO/'tools/prepare_public_snapshot.py')
snapshot=importlib.util.module_from_spec(spec);spec.loader.exec_module(snapshot)

class PublicSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)/'project';self.root.mkdir()
        for name in ['project.godot','export_presets.cfg','tools/check_reef_placements.gd','tests/core/test_world_store.gd','tests/core/test_reef_export_inputs.gd']:
            self.put(name,'')
    def tearDown(self):self.temp.cleanup()
    def put(self,name,value):
        p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(value)
    def test_import_callback_and_canonical_texture_are_retained_without_generated_cache(self):
        self.put('scenes/main.tscn','[ext_resource path="res://assets/models/a.glb"]')
        self.put('assets/models/a.glb','model input')
        self.put('assets/models/a.glb.import','path="res://.godot/imported/a.scn"\nimport_script/path="res://tools/art/shared.gd"')
        self.put('.godot/imported/a.scn','generated cache')
        self.put('tools/art/shared.gd','const MANIFEST="res://assets/data/shared.json"')
        self.put('tools/art/shared.gd.uid','uid://test')
        self.put('assets/data/shared.json','{"textures":{"res://assets/models/a.png":{"canonical_path":"res://assets/models/b.png"}}}')
        self.put('assets/models/a.png','pixels');self.put('assets/models/b.png','pixels')
        names=snapshot.resource_files(self.root)
        self.assertTrue({'tools/art/shared.gd','tools/art/shared.gd.uid','assets/models/a.png','assets/models/b.png'} <= names)
        self.assertFalse(any(n.startswith('.godot/') for n in names))
    def test_direct_runtime_cache_dependency_is_rejected(self):
        self.put('scripts/main.gd','const X=preload("res://.godot/imported/a.scn")')
        with self.assertRaises(ValueError):snapshot.resource_files(self.root)
    def test_git_metadata_is_never_a_resource(self):
        self.put('.git/config','private repository metadata')
        self.put('scripts/main.gd','const X="res://.git/config"')
        with self.assertRaises(ValueError):snapshot.resource_files(self.root)
    def test_reference_outside_project_is_rejected(self):
        (Path(self.temp.name)/'outside.gd').write_text('external data')
        self.put('scripts/main.gd','const X=preload("res://../outside.gd")')
        with self.assertRaises(ValueError):snapshot.resource_files(self.root)

if __name__=='__main__':unittest.main()
