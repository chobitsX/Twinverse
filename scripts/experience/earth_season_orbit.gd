extends RefCounted
## Four dated teaching samples in the original SolarSystem; no world entities.
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Seasons = preload("res://scripts/experience/season_observation.gd")

static func ensure(stage: Node) -> void:
	if stage.has_meta("earth_season_orbit"): return
	var root: Node3D = Node3D.new()
	root.name = "EarthSeasonDateReferences"
	stage.world_root.add_child(root)
	root.hide()
	stage.set_meta("earth_season_orbit",{"root":root,"active":false,"symbols":true,"distance":null,"samples":[]})

static func set_active(stage: Node, enabled: bool) -> void:
	if not stage.has_meta("solar_bodies"): return
	ensure(stage)
	var data: Dictionary = stage.get_meta("earth_season_orbit")
	data.active = enabled
	data.root.visible = enabled
	stage.builder.set_solar_view(stage,float(stage.get_meta("solar_jd")),bool(stage.get_meta("solar_true_distance")))

static func update(stage: Node) -> void:
	if not stage.has_meta("earth_season_orbit"): return
	var data: Dictionary = stage.get_meta("earth_season_orbit")
	var active: bool = data.active and data.symbols
	data.root.visible = active
	var bodies: Array = stage.get_meta("solar_bodies")
	for index: int in range(bodies.size()):
		bodies[index].node.visible = not active
		bodies[index].orbit.visible = not active or index==2
		if active:
			bodies[index].name_visible = false
			for extra: MeshInstance3D in bodies[index].extras: extra.hide()
	var equal_time: Node3D = stage.world_root.get_node_or_null("SelectedOrbitEqualTime")
	if active and equal_time!=null: equal_time.hide()
	if not active: return
	var true_distance: bool = stage.get_meta("solar_true_distance")
	if data.distance!=null and bool(data.distance)==true_distance: return
	data.distance = true_distance
	for child: Node in data.root.get_children(): child.free()
	data.samples.clear()
	var factor: float = Orbit.body_display_scale(2,true_distance)
	for index: int in range(4):
		var jd: float = Seasons.preset(index,"earth")
		var point: Vector3 = Orbit.display_position(2,jd,true_distance)
		var basis: Basis = Orientation.body_basis(2,jd)
		var pole: Vector3 = basis.y
		var sun: Vector3 = -point.normalized()
		var material: ShaderMaterial = bodies[2].material.duplicate()
		material.set_shader_parameter("planet_center",point)
		material.set_shader_parameter("sun_direction",sun)
		material.set_shader_parameter("ecef_from_local",basis.transposed())
		var globe: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = .70*factor
		sphere.height = 1.40*factor
		sphere.radial_segments = 48
		sphere.rings = 24
		globe.mesh = sphere
		globe.material_override = material
		globe.position = point
		globe.basis = basis
		globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		globe.name = "EarthDateReference_%d" % index
		data.root.add_child(globe)
		_line(data.root,PackedVector3Array([point-pole*1.6*factor,point+pole*1.6*factor]),Color(.55,.96,.84))
		_line(data.root,PackedVector3Array([sun*(-.36*factor),point+sun*.73*factor]),Color(.93,.69,.30))
		data.samples.append({"jd":jd,"position":point,"pole":pole,"sun":sun,"node":globe})

static func _line(root: Node3D, points: PackedVector3Array, color: Color) -> void:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point: Vector3 in points: mesh.surface_add_vertex(point)
	mesh.surface_end()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)

static func set_symbols(stage: Node, enabled: bool) -> void:
	if not stage.has_meta("earth_season_orbit"): return
	var data: Dictionary = stage.get_meta("earth_season_orbit")
	data.symbols = enabled
	update(stage)
