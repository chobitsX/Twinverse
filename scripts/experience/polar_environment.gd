extends RefCounted
## Bounded authored polar scenery. Date rotation reuses the existing sky authority.

const Forms = preload("res://scripts/experience/life_forms.gd")
const SkyGeometry = preload("res://scripts/core/ground_sky.gd")
const ICE = preload("res://shaders/polar_ice_267.gdshader")
const AURORA = preload("res://shaders/polar_aurora_267.gdshader")
const STARS = preload("res://shaders/ground_sky_stars.gdshader")
const CATALOG: String = "res://assets/data/ground_sky262/bsc-visible.json"
const AURORA_SOURCE: String = "https://www.nesdis.noaa.gov/about/k-12-education/optical-phenomena/what-aurora"
const POLES_SOURCE: String = "https://nsidc.org/learn/ask-scientist/how-does-antarctic-sea-ice-differ-arctic-sea-ice"


static func _material(stage: Node, shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	stage.materials.append(material)
	return material


static func _ice_point(angle: float, level: int, seed: float, size: Vector3) -> Vector3:
	# Tabular ice with an uneven crown and cut faces, rather than circular cones.
	const RADII: Array[float] = [.0, .28, .55, .77, .92, 1.0, 1.015]
	const HEIGHTS: Array[float] = [1.0, 1.02, .97, .94, .84, .08, -.12]
	var variation: float = 1.0 + .12 * sin(angle * 3.0 + seed) + .055 * sin(angle * 7.0 + seed * 2.7)
	var crown: float = (.11 * sin(angle * 3.0 + seed) + .028 * sin(angle * 17.0 - seed)) * RADII[level]
	var crevasse: float = pow(.5 + .5 * sin(angle * 9.0 + seed), 18.0) * smoothstep(.3, .92, RADII[level]) * .10
	crown -= crevasse
	var height: float = HEIGHTS[level] + crown if level < 5 else HEIGHTS[level]
	var x: float = signf(cos(angle)) * pow(absf(cos(angle)), .65)
	var z: float = signf(sin(angle)) * pow(absf(sin(angle)), .65)
	return Vector3(x * RADII[level] * variation * size.x, height * size.y,
		z * RADII[level] * variation * size.z)


static func _ice_mass(parent: Node3D, name: String, center: Vector3, size: Vector3,
		seed: float, material: Material) -> MeshInstance3D:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS: int = 64
	for level: int in range(6):
		for segment: int in range(SEGMENTS):
			var a: float = TAU * float(segment) / SEGMENTS
			var b: float = TAU * float(segment + 1) / SEGMENTS
			var p: Vector3 = _ice_point(a, level, seed, size)
			var q: Vector3 = _ice_point(a, level + 1, seed, size)
			var r: Vector3 = _ice_point(b, level + 1, seed, size)
			var s: Vector3 = _ice_point(b, level, seed, size)
			# SurfaceTool uses clockwise fronts: this order points the snow crown up.
			for point: Vector3 in [p, q, r, p, r, s]:
				surface.set_color(Color(.95, .95, .95) if level < 4 else Color(.24, .24, .24))
				surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	var node: MeshInstance3D = Forms.mesh(parent, surface.commit(), material, center)
	node.name = name
	node.layers = 1
	return node


static func _pressure_ridge(root: Node3D, center: Vector3, seed: float, ice: Material) -> void:
	# Broken, tilted slabs give the sea-ice ridge a physical silhouette; no drifting model.
	for index: int in range(9):
		var shape: BoxMesh = BoxMesh.new()
		shape.size = Vector3(2.8 + .5 * float(index % 3), .9 + .2 * float(index % 4), 1.7 + .4 * float(index % 3))
		var node: MeshInstance3D = Forms.mesh(root, shape, ice,
			center + Vector3(float(index - 4) * 2.1, .45 + .5 * sin(index * 2.2 + seed), 1.8 * sin(index * 1.7 + seed)))
		node.name = "ArcticPressureSlab_%02d_%02d" % [int(seed), index]
		node.rotation = Vector3(.24 * sin(index * 1.7 + seed), .5 * sin(index + seed), .65 * sin(index * 2.1 + seed))
		node.layers = 1


static func _curtain(stage: Node, root: Node3D, index: int) -> ShaderMaterial:
	var material: ShaderMaterial = _material(stage, AURORA)
	material.set_shader_parameter("curtain_seed", float(index) * 2.17)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS: int = 96
	const ROWS: int = 10
	for column: int in range(SEGMENTS):
		for row: int in range(ROWS):
			var u: float = float(column) / SEGMENTS
			var v: float = float(row) / ROWS
			for uv: Vector2 in [Vector2(u, v), Vector2(u + 1.0 / SEGMENTS, v), Vector2(u, v + 1.0 / ROWS),
					Vector2(u + 1.0 / SEGMENTS, v), Vector2(u + 1.0 / SEGMENTS, v + 1.0 / ROWS), Vector2(u, v + 1.0 / ROWS)]:
				var angle: float = lerpf(-1.25, 1.25, uv.x)
				var radius: float = 255.0 + float(index) * 44.0 + sin(uv.x * 11.0 + index * 2.1) * 32.0 + sin(uv.x * 23.0 + index) * 9.0
				var bend: float = sin(uv.x * 7.0 + index * 2.1) * 19.0 + sin(uv.x * 17.0 + index) * 7.0
				var height: float = 90.0 + 35.0 * (.5 + .5 * sin(uv.x * 13.0 + index))
				surface.set_uv(uv)
				surface.add_vertex(Vector3(sin(angle) * radius,
						42.0 + index * 16.0 + uv.y * height + bend, -cos(angle) * radius))
	surface.generate_normals()
	surface.index()
	var node: MeshInstance3D = Forms.mesh(root, surface.commit(), material)
	node.name = "IllustratedAuroraCurtain_%02d" % index
	node.layers = 4
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves vertices by <=10 m outside the authored mesh bounds.
	node.extra_cull_margin = 12.0
	return material


static func build(stage: Node, ice: ShaderMaterial, arctic: bool = false) -> void:
	var root: Node3D = Node3D.new()
	root.name = "AuthoredPolarEnvironment"
	stage.world_root.add_child(root)
	if arctic:
		# Arctic Ocean view: broad sea ice and pressure ridges, no Antarctic glaciers or penguins.
		_ice_mass(root, "ArcticObservationIce_SnowMantle", Vector3(0, -.10, 24), Vector3(29, 1.2, 19), 3.1, ice)
		_ice_mass(root, "ArcticWestIce_PressureRidge", Vector3(-27, -.10, -29), Vector3(22, 2.1, 27), 1.1, ice)
		_ice_mass(root, "ArcticEastIce_PressureRidge", Vector3(28, -.10, -54), Vector3(20, 1.7, 33), 4.3, ice)
		_pressure_ridge(root, Vector3(-14, 1.3, -13), 1.1, ice)
		_pressure_ridge(root, Vector3(30, .7, -25), 4.3, ice)
		_pressure_ridge(root, Vector3(-1, .8, 13), 3.1, ice)
	else:
		_ice_mass(root, "WestGlacier_SnowAndBlueIce", Vector3(-118, -.10, -218), Vector3(88, 37, 58), 1.1, ice)
		_ice_mass(root, "EastGlacier_SnowAndBlueIce", Vector3(88, -.10, -275), Vector3(105, 52, 75), 4.3, ice)
		_ice_mass(root, "NearIceberg_BlueCrevasses", Vector3(24, -.10, -65), Vector3(12, 11, 8), 2.2, ice)
		_ice_mass(root, "MidIceberg_BroadSnowCrown", Vector3(-31, -.10, -103), Vector3(17, 6, 10), 5.8, ice)
	for index: int in range(8):
		var x: float = -62.0 + float(index) * 16.0
		var z: float = -130.0 - float((index * 17) % 74)
		_ice_mass(root, "DistantIceFragment_%02d" % index, Vector3(x, -.10, z),
			Vector3(2.6 + float(index % 3), .45 + .24 * float(index % 4), 1.8 + float(index % 3)) * (3.0 if arctic else 1.0), float(index) * 3.8, ice)
	var curtains: Array[ShaderMaterial] = []
	for index: int in range(3):
		curtains.append(_curtain(stage, root, index))
	var sky_root: Node3D = Node3D.new()
	sky_root.name = "PolarJ2000Stars_CommonDate"
	root.add_child(sky_root)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var stars: ShaderMaterial = _material(stage, STARS)
	stars.set_shader_parameter("night_strength", 0.0)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = catalog.rows.size()
	for index: int in range(catalog.rows.size()):
		var row: Array = catalog.rows[index]
		var direction: Vector3 = SkyGeometry.star_direction(float(row[1]), float(row[2]))
		var size: float = clampf(2.5 - float(row[3]) * .29, .55, 3.2)
		mm.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), direction * 740.0))
		var color: Color = Color(.73, .84, 1.0).lerp(Color(1.0, .70, .43), clampf((float(row[4]) + .25) / 2.1, 0.0, 1.0))
		color.a = clampf(pow(10.0, -.18 * float(row[3])) * 1.35, .22, 2.5)
		mm.set_instance_color(index, color)
	var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
	batch.name = "PolarBSC5P_Stars"
	batch.multimesh = mm
	batch.material_override = stars
	batch.layers = 4
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_root.add_child(batch)
	stage.set_meta("polar_environment", {"root":root, "ice":ice, "curtains":curtains,
		"stars":stars, "sky_root":sky_root, "star_count":catalog.rows.size(), "night":0.0, "arctic":arctic})


static func set_daylight(stage: Node, jd: float, site: Dictionary, sun_height: float, enabled: bool) -> void:
	if not stage.has_meta("polar_environment"):
		return
	var data: Dictionary = stage.get_meta("polar_environment")
	var night: float = (1.0 - smoothstep(-14.0, -4.0, sun_height)) if enabled else 0.0
	data.night = night
	data.sky_root.basis = SkyGeometry.inertial_to_local(jd, site)
	data.stars.set_shader_parameter("night_strength", night * .84)
	for material: ShaderMaterial in data.curtains:
		material.set_shader_parameter("night_strength", night)


static func update_camera(stage: Node, underwater: bool) -> void:
	if stage.has_meta("polar_environment"):
		stage.get_meta("polar_environment").root.visible = not underwater
