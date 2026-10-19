extends RefCounted
## Synthetic park lawn detail. Flat geometry preserves authored routes and platforms.
const LAWN = preload("res://shaders/city_park_lawn.gdshader")
const Runoff = preload("res://scripts/experience/runoff_observation.gd")
const Pollinators = preload("res://scripts/experience/pollinator_observation.gd")
const COVER_COUNT: int = 700

static func lawn_material(stage: Node) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = LAWN
	stage.materials.append(material)
	return material

static func build_cover(stage: Node) -> void:
	var mesh: ArrayMesh = _tuft_mesh()
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = COVER_COUNT
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 186042
	var placed: int = 0
	var attempts: int = 0
	while placed < COVER_COUNT and attempts < COVER_COUNT * 30:
		attempts += 1
		var x: float = rng.randf_range(12.2, 53.8)
		var z: float = rng.randf_range(12.2, 53.8)
		if not _available(x, z):
			continue
		var yaw: float = rng.randf_range(0.0, TAU)
		var size: float = rng.randf_range(0.55, 0.9)
		var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size))
		multimesh.set_instance_transform(placed, Transform3D(basis, Vector3(x, 0.202, z)))
		multimesh.set_instance_color(placed, Color(rng.randf_range(0.82, 1.05), rng.randf_range(0.88, 1.05), rng.randf_range(0.78, 1.02)))
		placed += 1
	if placed != COVER_COUNT:
		push_error("City park ground cover could not fit the authored clearances")
		multimesh.instance_count = placed
	var cover: MultiMeshInstance3D = MultiMeshInstance3D.new()
	cover.name = "ParkGroundCover"
	cover.multimesh = multimesh
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.world_root.add_child(cover)
	stage.set_meta("city_park_ground_cover", {"node": cover, "count": placed, "seed": rng.seed})

static func _available(x: float, z: float) -> bool:
	# Clear both park loops, the crossing paths, pond, runoff teaching platforms,
	# and the perimeter. Ground cover never becomes walkable or simulated habitat.
	if absf(x - 33.0) < 2.7 or absf(z - 33.0) < 2.7:
		return false
	if (absf(x - 17.0) < 1.65 or absf(x - 49.0) < 1.65) and z < 35.0 and z > 15.0:
		return false
	if absf(z - 17.0) < 1.65 and x > 15.0 and x < 51.0:
		return false
	if x > 37.2 and x < 50.8 and z > 38.2 and z < 49.8:
		return false
	return not Runoff.reserved(x, z) and not Pollinators.city_reserved(x, z)

static func _tuft_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	for index: int in range(5):
		var angle: float = float(index) * TAU / 5.0
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var sideways: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var height: float = 0.17 + float(index % 3) * 0.045
		var reach: float = 0.075 + float(index % 2) * 0.035
		var tint: Color = Color(0.19, 0.33, 0.105) if index % 2 == 0 else Color(0.235, 0.365, 0.13)
		vertices.append(-sideways * 0.052)
		vertices.append(sideways * 0.052)
		vertices.append(direction * reach + Vector3.UP * height)
		colors.append_array(PackedColorArray([tint, tint, tint.lerp(Color(0.27, 0.39, 0.14), 0.28)]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	return mesh
