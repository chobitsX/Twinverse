extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## A transient lesson on the original Earth; all dates and solar geometry are shared.
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Sites = preload("res://scripts/data/earth_sites.gd")
const LATITUDES: Array[float] = [70.0,35.0,0.0,-35.0,-70.0]
const PAIRS: Array[float] = [0.0,35.0,70.0]
const RADIUS: float = 3.025
const HALF_WIDTH_DEG: float = .18
const SEGMENTS: int = 360
const REFERENCE_LONGITUDE_DEG: float = 210.0
const DAY: Color = Color(1.0,.76,.30)
const NIGHT: Color = Color(.24,.59,.95)

static func build(stage: Node) -> void:
	var root: Node3D = Node3D.new()
	root.name = "EarthDaylightParallels"
	stage.world_root.add_child(root)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bands: Array[MeshInstance3D] = []
	for index: int in range(LATITUDES.size()):
		var band: MeshInstance3D = MeshInstance3D.new()
		band.name = "DaylightLatitude_%d" % index
		band.material_override = material
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		band.set_meta("latitude",LATITUDES[index])
		root.add_child(band)
		bands.append(band)
	var site: Dictionary = Sites.for_scale("polar")
	var reference_normal: Vector3 = Sites.normal(float(site.lat),float(site.lon))
	var reference: MeshInstance3D = MeshInstance3D.new()
	reference.name = "PolarLightingReference"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = .055
	sphere.height = .11
	sphere.radial_segments = 16
	sphere.rings = 8
	reference.mesh = sphere
	var reference_material: StandardMaterial3D = material.duplicate()
	reference_material.vertex_color_use_as_albedo = false
	reference.material_override = reference_material
	reference.position = reference_normal*(RADIUS+.05)
	reference.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reference.hide()
	root.add_child(reference)
	root.hide()
	stage.set_meta("earth_daylight",{"root":root,"bands":bands,"active":false,"jd":INF,"sun":Vector3.ZERO,
		"polar_reference":false,"reference":reference,"reference_normal":reference_normal})

static func band_mesh(latitude: float, sun: Vector3) -> ImmediateMesh:
	# Width is a visual symbol. Each segment's colour samples its centre latitude.
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(SEGMENTS):
		var a: float = float(index)*360.0/SEGMENTS
		var b: float = float(index+1)*360.0/SEGMENTS
		var lit: bool = Sites.normal(latitude,(a+b)*.5).dot(sun)>=0.0
		var north_a: Vector3 = Sites.normal(latitude+HALF_WIDTH_DEG,a)*RADIUS
		var south_a: Vector3 = Sites.normal(latitude-HALF_WIDTH_DEG,a)*RADIUS
		var north_b: Vector3 = Sites.normal(latitude+HALF_WIDTH_DEG,b)*RADIUS
		var south_b: Vector3 = Sites.normal(latitude-HALF_WIDTH_DEG,b)*RADIUS
		for point: Vector3 in [north_a,south_a,north_b,north_b,south_a,south_b]:
			mesh.surface_set_color(DAY if lit else NIGHT)
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh

static func set_active(stage: Node, active: bool) -> void:
	if not stage.has_meta("earth_daylight"): return
	var data: Dictionary = stage.get_meta("earth_daylight")
	data.active = active
	data.root.visible = active
	if not active: set_polar_reference(stage,false)

static func set_polar_reference(stage: Node, enabled: bool) -> void:
	if not stage.has_meta("earth_daylight"): return
	var data: Dictionary = stage.get_meta("earth_daylight")
	data.polar_reference = enabled
	data.reference.visible = enabled

static func set_symbols(stage: Node, enabled: bool) -> void:
	if stage.has_meta("earth_daylight"):
		var data: Dictionary = stage.get_meta("earth_daylight")
		data.root.visible = bool(data.active) and enabled

static func update(stage: Node, jd: float) -> void:
	if not stage.has_meta("earth_daylight"): return
	var data: Dictionary = stage.get_meta("earth_daylight")
	if not bool(data.active) or float(data.jd)==jd: return
	var sun: Vector3 = Orientation.sun_ecef(jd)
	for index: int in range(LATITUDES.size()):
		data.bands[index].mesh = band_mesh(LATITUDES[index],sun)
	data.reference.material_override.albedo_color = DAY if data.reference_normal.dot(sun)>=0.0 else NIGHT
	data.jd = jd
	data.sun = sun

static func rows(jd: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for latitude: float in PAIRS:
		result.append({"latitude":latitude,"north":Orientation.latitude_daylight_hours(latitude,jd),"south":Orientation.latitude_daylight_hours(-latitude,jd)})
	return result

static func hours_text(hours: float) -> String:
	if hours>=24.0-1e-8: return I18n.text("24.0 · 极昼")
	if hours<=1e-8: return I18n.text("0.0 · 极夜")
	return "%.1f" % hours

static func focus(host: Node, keep_direction: bool = false) -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="earth": return
	var stage: Node = host.coordinator.active_scene
	host._content_follow = -1
	host._direct_content.clear()
	host._pan_offset = Vector3.ZERO
	host._orbit_target = Vector3.ZERO
	# Fixed authored geographic framing keeps all four date choices comparable.
	var reference_view: bool = bool(stage.get_meta("earth_daylight").polar_reference)
	var authored_direction: Vector3 = Sites.normal(-5.0,0.0) if reference_view else Sites.normal(0.0,REFERENCE_LONGITUDE_DEG)
	var direction: Vector3 = stage.camera.basis.z if keep_direction else authored_direction
	var window: Vector2 = host.get_viewport().get_visible_rect().size
	var left: float = host.explorer_panel.get_global_rect().end.x+16.0 if host.explorer_panel.visible else 0.0
	var available: float = maxf(.25,minf((window.x-left-60.0)/window.y,(window.y-260.0)/window.y))
	var distance: float = RADIUS*1.12/(available*tan(deg_to_rad(stage.camera.fov*.5)))
	stage.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	stage.set_pose(direction.normalized()*distance,Vector3.ZERO)
	set_active(stage,true)
	update(stage,host.solar_jd)
	set_symbols(stage,host.learning_overlay.enabled)

static func focus_polar(host: Node) -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="earth": return
	set_polar_reference(host.coordinator.active_scene,true)
	focus(host)

static func marks(host: Node) -> Array[Dictionary]:
	var stage: Node = host.coordinator.active_scene
	var longitude: float = rad_to_deg(atan2(stage.camera.position.x,stage.camera.position.z))
	var result: Array[Dictionary] = []
	var data: Dictionary = stage.get_meta("earth_daylight")
	for latitude: float in LATITUDES:
		# The nearby 70S label would overlap the explicit 66.5S reference label.
		if bool(data.polar_reference) and latitude==-70.0: continue
		var at: Vector3 = Sites.normal(latitude,longitude)*(RADIUS+.01)
		if at.normalized().dot(stage.camera.position-at)<=0.0: continue
		result.append({"label":I18n.text("赤道") if latitude==0.0 else Sites.latitude_label(latitude),"at":at,"offset":Vector2(52,-17)})
	if bool(data.polar_reference):
		var at: Vector3 = data.reference_normal*(RADIUS+.09)
		if at.normalized().dot(stage.camera.position-at)>0.0:
			result.append({"label":I18n.text("南极光照参考\n66.5°S / 0°"),"at":at,"offset":Vector2(48,-30)})
	return result
