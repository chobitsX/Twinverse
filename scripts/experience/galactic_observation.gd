extends RefCounted
## A dimensional reference in an authored galaxy, not a Galactic coordinate map.
const LIGHT_YEAR_M: float = 9460730472580800.0
const REFERENCE_DIAMETER_LY: float = 100000.0
const SUN_RADIUS_LY: float = 26000.0
const DISPLAY_DIAMETER: float = 30.0
const LY_PER_UNIT: float = REFERENCE_DIAMETER_LY/DISPLAY_DIAMETER
const SOURCE: String = "https://science.nasa.gov/learn/basics-of-space-flight/chapter1-1/"
const SIZE_SOURCE: String = "https://science.nasa.gov/universe/exoplanets/our-milky-way-galaxy-how-big-is-space/"

static func sun_position() -> Vector3:
	# Retain the authored azimuth, replacing only its previously arbitrary radius.
	return Vector3(5.5,0,2.0).normalized()*(SUN_RADIUS_LY/LY_PER_UNIT)

static func build(stage: Node) -> void:
	var lines: Array[Node3D]=[]
	var radius: MeshInstance3D=stage.builder._line(stage,PackedVector3Array([Vector3.ZERO,stage.target_position]),Color(.42,.86,.78),"SunGalactocentricDistance")
	lines.append(radius)
	var points: PackedVector3Array=[]
	for k: int in range(129):
		var angle: float=TAU*float(k)/128.
		points.append(Vector3(cos(angle),0,sin(angle))*DISPLAY_DIAMETER*.5)
	lines.append(stage.builder._line(stage,points,Color(.18,.34,.4),"GalacticReferenceDiameter"))
	for line: Node3D in lines: line.hide()
	stage.set_meta("galactic_observation",{"lines":lines,"view":"overview"})

static func focus(host: Node, side: bool) -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="galaxy": return
	host._pan_offset=Vector3.ZERO
	var stage: Node=host.coordinator.active_scene
	host._content_follow=-1
	host._orbit_target=Vector3.ZERO
	stage.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	var visible: Vector2=host.get_viewport().get_visible_rect().size
	var panel_width: float=host.explorer_panel.get_global_rect().end.x+16.0 if host.explorer_panel.visible else 0.0
	# Reserve the existing breadcrumb/header and bottom controls, not just the
	# left lesson panel. The reference rim must remain in the observation area.
	var horizontal: float=maxf(.25,(visible.x-panel_width-70.)/maxf(1.,visible.y))
	var vertical: float=maxf(.25,(visible.y-220.)/maxf(1.,visible.y))
	var distance: float=DISPLAY_DIAMETER*.6/(minf(vertical,horizontal)*tan(deg_to_rad(stage.camera.fov*.5)))
	stage.set_pose(Vector3(0,0,distance) if side else Vector3(0,distance,0),Vector3.ZERO,Vector3.UP if side else Vector3.BACK)
	stage.get_meta("galactic_observation").view="side" if side else "top"

static func update(stage: Node, visible: bool) -> void:
	if not stage.has_meta("galactic_observation"): return
	for line: Node3D in stage.get_meta("galactic_observation").lines: line.visible=visible
	if visible:
		var radius: MeshInstance3D = stage.get_meta("galactic_observation").lines[0]
		var mesh: ImmediateMesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		mesh.surface_add_vertex(Vector3.ZERO); mesh.surface_add_vertex(stage.target_position)
		mesh.surface_end(); radius.mesh = mesh

static func readout(_host: Node) -> String:
	return "太阳距银心约 2.6 万光年\n参考星盘直径约 10 万光年\n太阳绕银心一周约 2.3 亿年\n光年是距离：光走一年约9.46万亿公里\n理想化差速与旋臂转动均为时间压缩示意"

static func marks(host: Node) -> Array[Dictionary]:
	var stage: Node=host.coordinator.active_scene
	return [{"at":Vector3.ZERO,"label":"银心 · 中央隆起","offset":Vector2(-135,-70)},
		{"at":stage.target_position,"label":"太阳系 · 距银心约2.6万光年","offset":Vector2(25,-45),"link":0},
		{"at":Vector3(-15,0,0),"label":"参考盘径约10万光年 · 非硬边界","offset":Vector2(-30,65)}]
