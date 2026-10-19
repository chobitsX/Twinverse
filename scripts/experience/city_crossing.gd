extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const Traffic = preload("res://scripts/core/city_traffic.gd")
const Lesson = preload("res://scripts/core/city_traffic_lesson.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const Urban = preload("res://scripts/experience/urban_detail.gd")

static func build(stage: Node, pavement: Material, dark: Material) -> void:
	var root: Node3D = Node3D.new()
	root.name = "WestPedestrianCrossing"
	stage.world_root.add_child(root)
	# The west sidewalk ends at x=-13.2. Split the corner so that no raised
	# pavement remains under the two sloping curb ramps.
	for side: float in [-1.0,1.0]:
		Urban.box(root,Vector3(-9.725,.08,side*9.75),Vector3(6.95,.16,4.5),pavement)
		Urban.box(root,Vector3(-13.05,.08,side*6.875),Vector3(.3,.16,1.25),pavement)
		Urban.box(root,Vector3(-8.175,.08,side*6.875),Vector3(3.85,.16,1.25),pavement)
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a: Vector3 = Vector3(-12.9,.04,side*5.8)
		var b: Vector3 = Vector3(-10.1,.04,side*5.8)
		var c: Vector3 = Vector3(-12.9,.16,side*7.5)
		var d: Vector3 = Vector3(-10.1,.16,side*7.5)
		var vertices: Array[Vector3] = []
		vertices.assign([a,b,c,b,d,c] if side>0 else [a,c,b,b,c,d])
		for vertex: Vector3 in vertices: surface.add_vertex(vertex)
		surface.generate_normals()
		Forms.mesh(root,surface.commit(),pavement).name = "CurbRampSouth" if side>0 else "CurbRampNorth"
		var at: Vector3 = Vector3(-9.65,.16,side*7.7)
		var signal_root: Node3D = Node3D.new()
		signal_root.name="PedestrianSignalGeometrySouth" if side>0 else "PedestrianSignalGeometryNorth"
		root.add_child(signal_root)
		Forms.segment(signal_root,at,at+Vector3(0,2.5,0),.055,dark)
		Urban.box(signal_root,at+Vector3(0,2.24,0),Vector3(.48,.66,.26),dark)
		var label: Label3D = Label3D.new()
		label.name = "PedestrianSignalSouth" if side>0 else "PedestrianSignalNorth"
		label.position = at+Vector3(0,2.7,0)
		label.font_size = 36
		label.pixel_size = .012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 10
		signal_root.add_child(label)
		var light: StandardMaterial3D = Forms.material(Color(.9,.15,.08))
		light.emission_enabled = true
		Forms.ellipsoid(signal_root,at+Vector3(0,2.25,side*-.16),Vector3(.26,.26,.10),light)
		var signals: Array = stage.get_meta("pedestrian_signals",[])
		signals.append({"node":signal_root,"label":label,"material":light})
		stage.set_meta("pedestrian_signals",signals)
	var target: Node3D = Node3D.new()
	target.name = "CrossingObservationTarget"
	target.position = Vector3(Traffic.CROSS_X,0,0)
	root.add_child(target)
	var targets: Array = stage.get_meta("urban_targets")
	var signal_nodes: Array[Node3D] = []
	for signal_data: Dictionary in stage.get_meta("pedestrian_signals",[]): signal_nodes.append(signal_data.node)
	targets.append({"node":target,"pick_nodes":signal_nodes,"topic":"crossing","spatial_hint":I18n.text("双击信号灯查看过街用时对照"),"label":I18n.text("路口 · 行人过街与停等"),"role":I18n.text("两位参考行人沿西侧斑马线过街；分相和速度为作者教学规则。"),"distance":50.0,"focus_height":1.0,"view_offset":Vector3(-39,27,2)})
	stage.set_meta("crossing_target",target)

static func update(stage: Node, time: float, walk_duration: float = Traffic.WALK_DURATION) -> void:
	var p: float = Traffic.phase(time,walk_duration)
	var entry: bool = p>=Traffic.WALK_START and p<Traffic.ENTRY_END
	var clearance: bool = p>=Traffic.ENTRY_END and p<Traffic.clear_end(walk_duration)
	var color: Color = Color(.1,.85,.35) if entry else Color(1.0,.6,.1) if clearance else Color(.95,.12,.06)
	for signal_data: Dictionary in stage.get_meta("pedestrian_signals",[]):
		signal_data.label.text = I18n.text(I18n.text("行人 · 通行") if entry else I18n.text("行人 · 清空") if clearance else I18n.text("行人 · 等待"))
		signal_data.label.modulate = color
		signal_data.material.albedo_color = color
		signal_data.material.emission = color
	if stage.has_meta("crossing_target"): stage.get_meta("crossing_target").set_meta("activity",Traffic.readout(time,walk_duration))

static func readout(host: Node) -> String:
	var state: Dictionary=host.world.city_traffic.snapshot(host.world.simulation_time_s)
	var p: float=float(state.phase_s)
	var end: float=20.0 if p<20.0 else 24.0 if p<24.0 else 26.0 if p<26.0 else float(state.clear_end_s) if p<float(state.clear_end_s) else float(state.period_s)
	var phase_name: String=I18n.text("横向通行") if p<20.0 else I18n.text("清空路口") if p<24.0 else I18n.text("行人开始") if p<26.0 else I18n.text("行人清空") if p<float(state.clear_end_s) else I18n.text("清空路口")
	return I18n.text("同一%.1f m平面路线 · %.0f秒走完\n平均 %.2f m/s · 周期 %.0f秒\n%s · 本段剩余 %.1f秒\n%s\n横向红灯最长 %.0f秒（固定分相）") % [float(state.route_m),float(state.walk_duration_s),float(state.mean_speed_m_s),float(state.period_s),phase_name,end-p,Traffic.readout(float(state.elapsed_s),float(state.walk_duration_s)),float(state.period_s)-20.0]

static func marks(host: Node) -> Array[Dictionary]:
	var stage: Node = host.coordinator.active_scene
	var person: Node3D = stage.get_meta("crossing_people")[0]
	return [
		{"at":person.position+Vector3(0,1.5,0),"label":str(person.get_meta("activity",I18n.text("行人"))),"offset":Vector2(30,-80)},
		{"at":Vector3(-15.8,.08,3),"label":I18n.text("车辆在过街带前停等"),"offset":Vector2(-125,65)},
		{"at":Vector3(Traffic.CROSS_X,.055,0),"label":I18n.text("西侧斑马线 · 观察关系"),"offset":Vector2(70,-10)}]
