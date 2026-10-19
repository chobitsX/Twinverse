@tool
extends EditorScenePostImport
## Share verified identical LOD textures at import time, before runtime IO/GPU upload.
## Original GLBs, meshes, material settings and extracted source images stay intact.

const MANIFEST: String = "res://assets/data/shared_model_textures.json"
var _mapping: Dictionary = {}
var _verified: Dictionary = {}
var _valid: bool = true


func _post_import(scene: Node) -> Object:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary or not data.get("textures") is Dictionary:
		push_error("Missing shared texture import manifest")
		return null
	_mapping = data.textures
	_verified.clear()
	_valid = true
	_visit(scene)
	return scene if _valid else null


func _visit(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		_rewrite_material(node.material_override)
		_rewrite_material(node.material_overlay)
		for surface: int in range(node.mesh.get_surface_count()):
			_rewrite_material(node.mesh.surface_get_material(surface))
			_rewrite_material(node.get_surface_override_material(surface))
	for child: Node in node.get_children():
		_visit(child)


func _rewrite_material(material: Material) -> void:
	if not material is BaseMaterial3D:
		return
	for slot: int in range(BaseMaterial3D.TEXTURE_MAX):
		var texture: Texture2D = material.get_texture(slot)
		if texture == null or not _mapping.has(texture.resource_path):
			continue
		var source: String = texture.resource_path
		var item: Dictionary = _mapping[source]
		var canonical: String = item.canonical_path
		if not _verified.has(source):
			# Refuse stale aliases after an artist changes either image or import settings.
			var source_params: String = FileAccess.get_file_as_string(source + ".import").get_slice("[params]", 1)
			var canonical_params: String = FileAccess.get_file_as_string(canonical + ".import").get_slice("[params]", 1)
			_verified[source] = FileAccess.get_sha256(source) == item.source_sha256 \
				and FileAccess.get_sha256(canonical) == item.source_sha256 \
				and not source_params.is_empty() and source_params == canonical_params
		if not _verified[source]:
			push_error("Shared texture verification changed; regenerate manifest: " + source)
			_valid = false
			continue
		var shared: Texture2D = load(canonical)
		if shared == null:
			push_error("Shared texture could not load: " + canonical)
			_valid = false
			continue
		material.set_texture(slot, shared)
