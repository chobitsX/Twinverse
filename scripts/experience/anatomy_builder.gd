extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## General teleost illustration. All moving materials receive the host's world time.

const TISSUE: Shader = preload("res://shaders/anatomy_tissue.gdshader")
const FLOW: Shader = preload("res://shaders/anatomy_flow.gdshader")
const CONTEXT: Shader = preload("res://shaders/anatomy_context.gdshader")
const CANONICAL_WIDTH_M: float = 1.114145696
const SEMANTIC_WIDTH_M: float = 0.004
const SCIENCE_LABEL: String = "科学示意 · 一般硬骨鱼结构（参考成年斑马鱼）\n并非 A. percula 的精确解剖重建；尺寸、颜色、节律与血流标记均为观察而简化。"


static func build(stage: Node) -> void:
	stage.scale_id = "heart"
	stage.semantic_size_m = SEMANTIC_WIDTH_M
	stage.is_underwater = false
	stage.default_position = Vector3(0.76, 0.36, 1.48)
	stage.default_target = Vector3(-0.015, 0.015, 0.0)
	stage.target_position = Vector3(-0.115, -0.17, 0.067)
	stage.target_radius = 0.045
	stage.close_position = stage.target_position + Vector3(0.075, 0.04, 0.13)
	stage.camera.near = 0.002
	stage.camera.far = 80.0
	stage.camera.fov = 46.0
	stage.environment.background_color = Color(0.085, 0.125, 0.14)
	stage.environment.ambient_light_color = Color(0.52, 0.60, 0.62)
	stage.environment.ambient_light_energy = 0.70
	stage.environment.ssao_enabled = true
	stage.environment.ssao_radius = 0.08
	stage.environment.ssao_intensity = 1.1
	stage.environment.glow_enabled = false
	var key: DirectionalLight3D = stage.add_sun(Vector3(-38, -26, 0), Color(1.0, 0.93, 0.89), 0.90)
	key.light_specular = 0.35
	var fill: DirectionalLight3D = stage.add_sun(Vector3(28, 138, 0), Color(0.60, 0.81, 0.94), 0.45)
	fill.shadow_enabled = false
	fill.light_specular = 0.15
	_add_area_key(stage)
	var solid: Node3D = stage.asset_instance("heart_solid")
	solid.name = "HeartExternal"
	stage.world_root.add_child(solid)
	var cutaway: Node3D = stage.asset_instance("heart_cutaway")
	cutaway.name = "HeartCutaway"
	stage.world_root.add_child(cutaway)
	var material_cache: Dictionary = {}
	_apply_tissue(stage, solid, material_cache)
	_apply_tissue(stage, cutaway, material_cache)
	stage.set_meta("anatomy_refined_trabeculae", _refine_trabeculae(stage, cutaway))
	stage.set_meta("anatomy_solid", solid)
	stage.set_meta("anatomy_cutaway", cutaway)
	stage.set_meta("anatomy_regions", _region_definitions())
	I18n.set_meta_text(stage,"scientific_label",SCIENCE_LABEL)
	I18n.set_meta_text(stage,"scientific_note",SCIENCE_LABEL)
	stage.set_meta("anatomy_flow_label", "暖色穿透标记仅表示血流方向；不是血氧颜色、细胞实测轨迹或流速。")
	stage.set_meta("anatomy_scale_label", "示意放大 · 4 mm 仅为鱼体内布局假设")
	stage.set_meta("orbit_min_distance", 0.22)
	stage.set_meta("orbit_max_distance", 6.0)
	_add_context(stage)
	_add_flow(stage)
	set_cutaway(stage, true)
	set_reduced_motion(stage, stage.reduced_motion)


static func _add_area_key(stage: Node) -> void:
	var key: OmniLight3D = OmniLight3D.new()
	key.name = "SoftOrganKey"
	key.position = Vector3(-0.55, 0.95, 1.05)
	key.light_color = Color(1.0, 0.88, 0.82)
	key.light_energy = 1.0
	key.light_specular = 0.45
	key.light_size = 0.5
	key.omni_range = 4.0
	key.shadow_enabled = true
	stage.world_root.add_child(key)


static func _ventricle_attachment(t: float, angle: float) -> Vector3:
	# Same authored wall profile as tools/art/heart_build.py:ventricle.
	# Place the centre inside its 0.018 / 0.016 thick wall, away from the cut lip.
	var radius: float = 0.002 + 0.197 * pow(sin(PI * t), 0.68) * (0.7 + 0.3 * t)
	var irregular: float = 1.0 + 0.065 * cos(3.0 * angle + 0.4) + 0.017 * sin(angle * 9.0 + t * 18.0)
	return Vector3(-0.13 + 0.22 * t + (radius - 0.010) * cos(angle) * irregular,
		-0.36 + 0.48 * t, (radius * 0.72 - 0.009) * sin(angle) * irregular)


static func _refine_trabeculae(stage: Node, node: Node) -> int:
	var count: int = 0
	if node is MeshInstance3D and str(node.name).begins_with("Trabecula_"):
		var target: MeshInstance3D = node as MeshInstance3D
		var index: int = str(node.name).trim_prefix("Trabecula_").to_int()
		var material: Material = target.get_surface_override_material(0)
		var t: float = 0.24 + 0.033 * float(index)
		var left: Vector3 = _ventricle_attachment(t, 0.82 * PI + 0.08)
		var right: Vector3 = _ventricle_attachment(t, 2.31 * PI - 0.08)
		var points: Array[Vector3] = []
		for row: int in range(33):
			var f: float = float(row) / 32.0
			var point: Vector3 = left.lerp(right, f)
			point.y += 0.012 * sin(PI * f) * sin(float(index) * 0.9)
			point.z -= 0.040 * sin(PI * f)
			points.append(point)
		var local_from_canonical: Transform3D = target.global_transform.affine_inverse() * stage.world_root.global_transform
		target.mesh = _trabecula_mesh(points, 0.0042 + 0.0005 * sin(float(index) * 1.7), local_from_canonical)
		target.set_surface_override_material(0, material)
		count = 1
	for child: Node in node.get_children():
		count += _refine_trabeculae(stage, child)
	return count


static func _trabecula_mesh(points: Array[Vector3], radius: float, local_from_canonical: Transform3D) -> ArrayMesh:
	const SIDES: int = 20
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uv: PackedVector2Array = []
	var indices: PackedInt32Array = []
	var normal_basis: Basis = local_from_canonical.basis.inverse().transposed()
	for row: int in range(points.size()):
		var direction: Vector3 = (points[mini(row + 1, points.size() - 1)] - points[maxi(row - 1, 0)]).normalized()
		var side: Vector3 = direction.cross(Vector3.UP).normalized()
		var up: Vector3 = side.cross(direction).normalized()
		for column: int in range(SIDES + 1):
			var angle: float = float(column) / float(SIDES) * TAU
			var normal: Vector3 = side * cos(angle) + up * sin(angle)
			vertices.append(local_from_canonical * (points[row] + normal * radius))
			normals.append((normal_basis * normal).normalized())
			uv.append(Vector2(float(row) / float(points.size() - 1), float(column) / float(SIDES)))
	for row: int in range(points.size() - 1):
		for column: int in range(SIDES):
			var a: int = row * (SIDES + 1) + column
			var b: int = a + SIDES + 1
			indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	# Both cap centres are buried in the wall, preserving a closed tube.
	for end: int in range(2):
		var row: int = 0 if end == 0 else points.size() - 1
		var direction: Vector3 = (points[0] - points[1] if end == 0 else points[-1] - points[-2]).normalized()
		var center: int = vertices.size()
		vertices.append(local_from_canonical * points[row])
		normals.append((normal_basis * direction).normalized())
		uv.append(Vector2(float(end), 0.5))
		for column: int in range(SIDES):
			var a: int = row * (SIDES + 1) + column
			indices.append_array(PackedInt32Array([center, a + 1, a] if end == 0 else [center, a, a + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_tangents()
	return surface.commit()


static func _apply_tissue(stage: Node, node: Node, cache: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		mesh_node.extra_cull_margin = 0.05
		for surface: int in range(mesh_node.mesh.get_surface_count()):
			var source: BaseMaterial3D = mesh_node.get_active_material(surface) as BaseMaterial3D
			var key: String = source.resource_name if source != null else "fallback"
			if not cache.has(key):
				var material: ShaderMaterial = ShaderMaterial.new()
				material.shader = TISSUE
				material.resource_name = "Anatomy_" + key
				if source != null:
					material.set_shader_parameter("tissue_color", source.albedo_color)
					material.set_shader_parameter("tissue_roughness", clampf(source.roughness + 0.16, 0.50, 0.68))
					material.set_shader_parameter("has_base_texture", source.albedo_texture != null)
					material.set_shader_parameter("has_normal_texture", source.normal_texture != null)
					if source.albedo_texture != null:
						material.set_shader_parameter("base_texture", source.albedo_texture)
					if source.normal_texture != null:
						material.set_shader_parameter("normal_texture", source.normal_texture)
				if "atrial" in key.to_lower():
					material.set_shader_parameter("translucency", 0.16)
				cache[key] = material
				stage.materials.append(material)
			mesh_node.set_surface_override_material(surface, cache[key])
	for child: Node in node.get_children():
		_apply_tissue(stage, child, cache)


static func _add_context(stage: Node) -> void:
	if not stage.assets.has("fish_context"):
		return
	# Keep the same anatomical embedding transform as the fish view. This is a
	# static orientation shell, so it does not create another simulated fish.
	var context: Node3D = stage.assets["fish_context"].instantiate() as Node3D
	context.name = "TargetFishContext"
	var display_scale: float = CANONICAL_WIDTH_M / SEMANTIC_WIDTH_M
	context.scale = Vector3.ONE * display_scale
	context.position = -Vector3(0.018, -0.007, 0.0) * display_scale
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = CONTEXT
	material.render_priority = -10
	stage.set_meta("anatomy_context_material", material)
	stage.set_meta("anatomy_context", context)
	_mask_context(context, material)
	stage.world_root.add_child(context)


static func _mask_context(node: Node, material: ShaderMaterial) -> void:
	if node is AnimationPlayer:
		(node as AnimationPlayer).stop()
		(node as AnimationPlayer).active = false
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		mesh_node.visible = mesh_node.name == "Body"
		mesh_node.material_override = material
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for child: Node in node.get_children():
		_mask_context(child, material)


static func _flow_points() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-0.55, 0.19, -0.03), Vector3(-0.42, 0.19, -0.03),
		Vector3(-0.29, 0.21, -0.01), Vector3(-0.14, 0.25, 0.0),
		Vector3(0.03, 0.17, 0.0), Vector3(0.075, 0.08, 0.0),
		Vector3(-0.03, -0.07, 0.025), Vector3(-0.06, -0.24, 0.025),
		Vector3(0.055, -0.16, 0.025), Vector3(0.12, -0.015, -0.008),
		Vector3(0.28, 0.03, -0.008), Vector3(0.42, 0.06, -0.008),
		Vector3(0.54, 0.18, -0.008),
	])


static func _add_flow(stage: Node) -> void:
	var curve: Curve3D = Curve3D.new()
	var points: PackedVector3Array = _flow_points()
	curve.bake_interval = 0.002
	for index: int in range(points.size()):
		var before: Vector3 = points[maxi(index - 1, 0)]
		var after: Vector3 = points[mini(index + 1, points.size() - 1)]
		var tangent: Vector3 = (after - before) / 6.0
		curve.add_point(points[index], -tangent, tangent)
	var image: Image = Image.create(256, 1, false, Image.FORMAT_RGBF)
	var curve_length: float = curve.get_baked_length()
	for index: int in range(256):
		var point: Vector3 = curve.sample_baked(curve_length * float(index) / 255.0, true)
		image.set_pixel(index, 0, Color(point.x, point.y, point.z, 1.0))
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = FLOW
	material.set_shader_parameter("flow_path", ImageTexture.create_from_image(image))
	material.render_priority = 8
	stage.materials.append(material)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.0035
	sphere.height = 0.006
	sphere.radial_segments = 8
	sphere.rings = 4
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = sphere
	multimesh.instance_count = 32
	multimesh.custom_aabb = AABB(Vector3(-0.65, -0.42, -0.20), Vector3(1.3, 0.9, 0.4))
	for index: int in range(32):
		multimesh.set_instance_transform(index, Transform3D.IDENTITY)
		multimesh.set_instance_custom_data(index, Color(float(index) / 32.0, fmod(float(index) * 0.618034, 1.0), 0.0, 1.0))
	var flow: MultiMeshInstance3D = MultiMeshInstance3D.new()
	flow.name = "IllustrativeBloodFlow"
	flow.multimesh = multimesh
	flow.material_override = material
	flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.world_root.add_child(flow)
	stage.set_meta("anatomy_flow", flow)


static func _region_definitions() -> Array[Dictionary]:
	return [
		{"id": "sinus_venosus", "node_name": "SinusVenosus", "label": "静脉窦", "position": Vector3(-0.34, 0.205, 0.02), "radius": 0.10, "description": "接受回流血液，连接心房。这里采用一般硬骨鱼结构示意。", "next_id": "atrium"},
		{"id": "atrium", "node_name": "Atrium", "label": "心房", "position": Vector3(-0.13, 0.24, 0.065), "radius": 0.18, "description": "相对薄壁的受血区，经房室连接进入心室；先于心室的相位仅作教学示意。", "next_id": "ventricle"},
		{"id": "ventricle", "node_name": "Ventricle", "cutaway_node_name": "Ventricle_Cutaway", "label": "心室", "position": Vector3(-0.03, -0.13, 0.07), "radius": 0.23, "description": "肌性泵血区；剖面显露壁厚与肌小梁示意，不代表目标鱼的扫描或组织学重建。", "next_id": "bulbus_arteriosus"},
		{"id": "bulbus_arteriosus", "node_name": "BulbusArteriosus", "label": "动脉球", "position": Vector3(0.27, 0.04, 0.06), "radius": 0.15, "description": "弹性流出结构，缓冲搏动后经腹主动脉流向鳃；不是第二个主动泵血心室。", "next_id": "gills"},
	]


static func get_regions(stage: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Dictionary in stage.get_meta("anatomy_regions", []):
		var item: Dictionary = source.duplicate(true)
		var solid: Node3D = stage.get_meta("anatomy_solid") as Node3D
		var cutaway: Node3D = stage.get_meta("anatomy_cutaway") as Node3D
		item["external_node"] = solid.find_child(str(item.node_name), true, false)
		item["cutaway_node"] = cutaway.find_child(str(item.get("cutaway_node_name", item.node_name)), true, false)
		result.append(item)
	return result


static func set_cutaway(stage: Node, enabled: bool) -> void:
	(stage.get_meta("anatomy_solid") as Node3D).visible = not enabled
	(stage.get_meta("anatomy_cutaway") as Node3D).visible = enabled
	stage.set_meta("anatomy_cutaway_active", enabled)


static func select_region(stage: Node, region_id: String) -> void:
	var center: Vector3 = Vector3.ZERO
	var radius: float = 0.0
	for item: Dictionary in stage.get_meta("anatomy_regions", []):
		if item.id == region_id:
			center = item.position
			radius = float(item.radius)
	for material: ShaderMaterial in stage.materials:
		if material.shader == TISSUE:
			material.set_shader_parameter("selected_center", center)
			material.set_shader_parameter("selected_radius", radius)
	stage.set_meta("anatomy_selected_region", region_id)


static func set_reduced_motion(stage: Node, enabled: bool) -> void:
	for material: ShaderMaterial in stage.materials:
		material.set_shader_parameter("motion_amount", 0.0 if enabled else 1.0)


static func update_camera(stage: Node) -> void:
	if stage.has_meta("anatomy_context_material"):
		var material: ShaderMaterial = stage.get_meta("anatomy_context_material") as ShaderMaterial
		material.set_shader_parameter("anatomy_camera", stage.camera.position)


static func entry_pose(stage: Node, source_id: String) -> Dictionary:
	if source_id == "fish":
		return _fish_boundary_pose()
	if source_id == "cardiomyocyte":
		return {"position": stage.close_position, "target": stage.target_position}
	return {"position": stage.default_position, "target": stage.default_target}


static func exit_pose(stage: Node, target_id: String) -> Dictionary:
	if target_id == "fish":
		return _fish_boundary_pose()
	return {"position": stage.close_position, "target": stage.target_position}


static func _fish_boundary_pose() -> Dictionary:
	# Match the ocean builder's +(.001, .001, .008) m camera offset from
	# the heart anchor after converting the fish scale into this local scale.
	return {"position": Vector3(0.001, 0.001, 0.008) * (CANONICAL_WIDTH_M / SEMANTIC_WIDTH_M), "target": Vector3.ZERO}
