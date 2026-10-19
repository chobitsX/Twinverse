extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const EcologySurface = preload("res://scripts/experience/ecology_surface_material.gd")
## One original reef-floor reference. Time is supplied by the existing host.
const SkinShader = preload("res://shaders/day_octopus_skin.gdshader")
const SOURCE: String = "https://lifg.australian.museum/Group.html?groupId=ZTSahEU7"
const MORPHOLOGY_SOURCE: String = "https://www.fao.org/4/i3489e/i3489e.pdf"
const FIELD_SOURCE: String = "https://australian.museum/blog/amri-news/news-from-lirs-octopus-pair-at-lizard-island/"
const MANTLE_LENGTH_M: float = .120
const PLACE: Vector2 = Vector2(-2.60, 2.80)


static func motion_y(point: Vector3, time: float) -> float:
	var p: Vector2 = Vector2(point.x - .030, point.z)
	return .007 * smoothstep(.15, .52, p.length()) * sin(time * TAU / 16.0 + 2.0 * atan2(p.y, p.x))


static func _prepare_meshes(node: Node, stage: Node, cache: Dictionary, materials: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D:
		var geometry: MeshInstance3D = node as MeshInstance3D
		var source_mesh: Mesh = geometry.mesh
		var copy: ArrayMesh = ArrayMesh.new()
		for surface: int in range(source_mesh.get_surface_count()):
			var arrays: Array = source_mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# One-time placement conforms this reference to the existing terrain.
			# The imported mesh is shared; only the instance receives the copy.
			for index: int in range(vertices.size()):
				var at: Vector3 = geometry.to_global(vertices[index])
				at.y += stage.builder._terrain_height(stage, at.x, at.z) - float(stage.get_meta("octopus_floor"))
				vertices[index] = geometry.to_local(at)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var source_material: StandardMaterial3D = source_mesh.surface_get_material(surface) as StandardMaterial3D
			assert(source_material != null)
			var key: int = source_material.get_instance_id()
			if not cache.has(key):
				var material: ShaderMaterial = ShaderMaterial.new()
				material.shader = SkinShader
				EcologySurface.copy_maps(source_material,material)
				material.set_shader_parameter("base_color", source_material.albedo_color)
				material.set_shader_parameter("surface_roughness", source_material.roughness)
				material.set_shader_parameter("use_vertex_color", bool(source_mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR))
				material.set_shader_parameter("skin_color_comparison", source_material.resource_name.contains("MottledSkin"))
				cache[key] = material
				materials.append(material)
				stage.materials.append(material)
			copy.surface_set_material(surface, cache[key])
		geometry.mesh = copy
	for child: Node in node.get_children(): _prepare_meshes(child, stage, cache, materials)


static func build(stage: Node) -> void:
	var root: Node3D = stage.assets.octopus_cyanea.instantiate()
	root.name = "OctopusCyaneaReference"
	var floor: float = stage.builder._terrain_height(stage, PLACE.x, PLACE.y)
	root.position = Vector3(PLACE.x, floor, PLACE.y)
	root.rotation.y = -.15
	root.set_meta("stable_id", "3dworld:teaching:octopus-cyanea:0000")
	root.set_meta("activity", I18n.text("礁底参考个体 · 作者腕端微动"))
	stage.world_root.add_child(root)
	stage.set_meta("octopus_floor", floor)
	var materials: Array[ShaderMaterial] = []
	_prepare_meshes(root, stage, {}, materials)
	var source_anchor: Node3D = root.find_child("SuckerRowsObservationAnchor", true, false) as Node3D
	assert(source_anchor != null)
	var arm_view: Node3D = Node3D.new()
	arm_view.name = "OctopusSameArmSuckersView"
	arm_view.set_meta("stable_id", "3dworld:teaching:octopus-cyanea:suckers")
	arm_view.set_meta("octopus_root", root)
	stage.world_root.add_child(arm_view)
	var local_anchor: Vector3 = root.to_local(source_anchor.global_position)
	stage.set_meta("day_octopus", {"root":root, "arm_view":arm_view, "local_anchor":local_anchor,
		"materials":materials, "pale":false})
	animate(stage, float(stage.world_snapshot.simulation_time_s))
	var role: String = I18n.text("日间章鱼 Octopus cyanea 是礁区头足类参考：八腕、两列吸盘及腕间膜。外套膜约12厘米、448个简化吸盘、姿态和低幅腕端活动均为作者设置；并非实测个体或捕食、爬行、吸附力模型。")
	stage.set_meta("octopus_targets", [
		{"node":root, "label":I18n.text("日间章鱼 · Octopus cyanea"), "role":role, "source_url":SOURCE,
			"distance":1.90, "focus_height":.090, "min_distance":.50, "view_offset":Vector3(.78,.80,1.57)},
		{"node":arm_view, "label":I18n.text("日间章鱼 · 同一条腕的双列吸盘"), "role":role, "source_url":MORPHOLOGY_SOURCE,
			"distance":.26, "min_distance":.17, "view_offset":Vector3(.25,.025,.045)}])
	I18n.set_meta_text(stage,"content_summary",{"parts":[I18n.meta_message(stage,"content_summary"),"\n日间章鱼增加八腕/双列吸盘的头足类近看；体色为两种作者参考，腕端微动不表示抓取、爬行或自动伪装。"]})


static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("day_octopus"): return
	var data: Dictionary = stage.get_meta("day_octopus")
	var root: Node3D = data.root
	var at: Vector3 = data.local_anchor
	var point: Vector3 = root.to_global(at)
	point.y += stage.builder._terrain_height(stage, point.x, point.z) - float(stage.get_meta("octopus_floor"))
	point.y += motion_y(at, time)
	(data.arm_view as Node3D).position = point


static func set_pale(host: Node, pale: bool) -> void:
	var stage: Node = host.coordinator.active_scene
	if stage == null or not stage.has_meta("day_octopus"): return
	var data: Dictionary = stage.get_meta("day_octopus")
	data.pale = pale
	for material: ShaderMaterial in data.materials:
		material.set_shader_parameter("pale_amount", 1.0 if pale else 0.0)
	stage.set_meta("day_octopus", data)


static func readout(host: Node) -> String:
	var stage: Node = host.coordinator.active_scene
	if not stage.has_meta("day_octopus"): return ""
	var pale: bool = bool(stage.get_meta("day_octopus").pale)
	return I18n.text("同一只个体 · 外套膜约12 cm · 八腕\n%s · 体色对照不表示自动伪装\n腕端16秒作者微动；暂停后姿态保持") % (I18n.text("较浅参考体色") if pale else I18n.text("褐斑参考体色"))


static func marks(host: Node, close_arm: bool) -> Array[Dictionary]:
	var stage: Node = host.coordinator.active_scene
	if not stage.has_meta("day_octopus"): return []
	var data: Dictionary = stage.get_meta("day_octopus")
	var root: Node3D = data.root
	if close_arm:
		return [{"at":data.arm_view.global_position, "label":I18n.text("两列吸盘 · 数量简化"), "offset":Vector2(55,-70)},
			{"at":root.to_global(Vector3(.012,.110,.071)), "label":I18n.text("头部的真眼"), "offset":Vector2(-75,45)}]
	return [{"at":root.to_global(Vector3(-.09,.165,0)), "label":I18n.text("外套膜 · 约12 cm"), "offset":Vector2(-80,-65)},
		{"at":root.to_global(Vector3(.06,.070,0)), "label":I18n.text("八腕与腕间膜"), "offset":Vector2(110,65)}]
