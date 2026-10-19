extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const Model = preload("res://scripts/core/jovian_ephemeris.gd")
const Cosmos = preload("res://scripts/experience/cosmos_builder.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const Satellites = preload("res://scripts/experience/satellite_system_builder.gd")
const States = preload("res://scripts/core/natural_satellites.gd")
const SURFACE = preload("res://shaders/jovian_surface.gdshader")
const RADIUS_KM: float = 69911.
const KEYS: Array[String] = ["io","europa","ganymede","callisto"]
const MAP_SOURCE: String = "https://astrogeology.usgs.gov/search/map/jupiter-voyager-and-galileo-global-mosaics"

static func build(stage: Node) -> void:
	stage.semantic_size_m=4.e9
	stage.default_position=Vector3(18,42,57)
	stage.default_target=Vector3.ZERO
	stage.close_position=Vector3(0,1.3,3.5)
	stage.target_position=Vector3.ZERO
	stage.target_radius=1.
	stage.camera.fov=48.
	stage.camera.near=.008
	stage.camera.far=600.
	stage.environment.background_color=Color(.0008,.0012,.003)
	stage.environment.ambient_light_energy=.03
	stage.environment.glow_enabled=true
	stage.environment.glow_intensity=.10
	var root: Node3D = Node3D.new()
	root.name="JupiterCentredSystem"
	stage.world_root.add_child(root)
	var planet_mat: ShaderMaterial = ShaderMaterial.new()
	planet_mat.shader=SURFACE
	planet_mat.set_shader_parameter("surface_map",stage.textures.jupiter)
	planet_mat.set_shader_parameter("longitude_offset",.5)
	planet_mat.set_shader_parameter("polar_clamp",.06)
	var jupiter: MeshInstance3D
	# add_mesh owns render resources through the stage; system visibility groups them.
	jupiter=stage.add_mesh(Cosmos._sphere(1.,128,64),planet_mat)
	jupiter.reparent(root)
	jupiter.name="Jupiter"
	var bodies: Array[Dictionary] = []
	var palette: Array[Color] = [Color(.75,.57,.20),Color(.30,.68,.73),Color(.62,.51,.80),Color(.48,.62,.48)]
	for i: int in range(4):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader=SURFACE
		material.set_shader_parameter("surface_map",stage.textures[KEYS[i]])
		material.set_shader_parameter("coverage_map",stage.textures[KEYS[i]+"_coverage"])
		material.set_shader_parameter("has_coverage",true)
		material.set_shader_parameter("longitude_offset",.5 if i==0 else 0.)
		var moon: MeshInstance3D = stage.add_mesh(Cosmos._sphere(Model.RADII_KM[i]/RADIUS_KM,96,48),material)
		moon.reparent(root)
		moon.name=KEYS[i].capitalize()
		var label: Label3D = Label3D.new()
		label.text=Model.NAMES[i]
		label.font_size=20
		label.pixel_size=.015
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test=true
		root.add_child(label)
		var orbit: MeshInstance3D = Cosmos._line(stage,PackedVector3Array([Vector3.ZERO,Vector3.ONE]),palette[i]*.65,"Trajectory"+str(i))
		orbit.reparent(root)
		bodies.append({"node":moon,"label":label,"orbit":orbit,"material":material})
	Cosmos._stars(stage,1200,150,220,false)
	stage.set_meta("jovian",{"root":root,"jupiter":jupiter,"planet_material":planet_mat,"bodies":bodies,"orbit_date":-INF,"true_size":false,"valid":false})
	I18n.set_meta_text(stage,"content_summary","木星与四颗伽利略卫星 · 星历轨迹与历史表面拼图\n距离始终按木星平均半径同比缩放；宿主与卫星平均半径、距离始终同比；小对象用明确的识别点，不放大实体球。选择卫星近看，并用天文日期比较运动。")
	var existing: Dictionary = {}
	for i: int in range(4): existing[501+i]=bodies[i].node
	Satellites.attach(stage,"jupiter",jupiter,planet_mat,existing)
	set_view(stage,Ephemeris.DEFAULT_JD,false)

static func set_view(stage: Node, jd: float, true_size: bool) -> void:
	if not stage.has_meta("jovian"): return
	var data: Dictionary = stage.get_meta("jovian")
	var sun: Dictionary = Model.sample(4,jd)
	data.valid=States.available(jd)
	data.root.visible=data.valid
	if not data.valid:
		for body: Dictionary in data.bodies: body.node.set_meta("activity","当前日期无卫星位置 · 主要卫星支持1995—2050。")
		I18n.set_meta_text(stage,"scientific_label","木星主要卫星支持1995—2050 TDB；范围外不外推轨迹。")
		Satellites.set_view(stage,jd,true_size)
		return
	var sunlight: Vector3 = sun.world_km.normalized() if sun.valid else -Ephemeris.display_position(4,jd,true).normalized()
	data.sunlight=sunlight
	data.jupiter.basis=Orientation.body_basis(4,jd)
	data.planet_material.set_shader_parameter("sun_direction",sunlight)
	data.true_size=true
	for i: int in range(4):
		var body: Dictionary = data.bodies[i]
		var record: Dictionary = States.major_records("jupiter")[i]
		var state: Dictionary = States.sample(record,jd)
		body.node.position=States.world_position(state,RADIUS_KM)
		var v: Array = state.velocity_km_day
		var velocity: Vector3 = Vector3(v[0],v[2],-v[1])
		var pole: Vector3 = body.node.position.cross(velocity).normalized()
		var prime: Vector3 = -body.node.position.normalized()
		# Ideal synchronous orientation. Does not claim measured libration or pole.
		body.node.basis=Basis(pole.cross(prime),pole,prime).scaled(Vector3.ONE*1.0)
		body.material.set_shader_parameter("sun_direction",sunlight)
		body.material.set_shader_parameter("body_center",body.node.position)
		body.label.position=body.node.position+Vector3(0,Model.RADII_KM[i]/RADIUS_KM*1.0+.35,0)
		body.node.set_meta("activity",I18n.format_text("距木星中心 %.0f km · 平均绕行 %.3f 天\n%s",[state.distance_km,Model.period_days(i),"半径与距离同比"]))
		if absf(jd-float(data.orbit_date))>.02:
			var period: float = Model.period_days(i)
			var start: float = clampf(jd-period*.5,States.START_JD,States.END_JD-period)
			var mesh: ImmediateMesh = ImmediateMesh.new()
			mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for k: int in range(161): mesh.surface_add_vertex(States.world_position(States.sample(record,start+period*k/160.),RADIUS_KM))
			mesh.surface_end()
			body.orbit.mesh=mesh
	if absf(jd-float(data.orbit_date))>.02: data.orbit_date=jd
	I18n.set_meta_text(stage,"scientific_label",{"format":"JPL木心几何星历 · 主要卫星1995—2050 TDB\n距离同比；%s。历史影像拼图与理想同步姿态，非地面观测预报/实时表面。","args":"卫星真实半径（识别点不代表大小）"})
	Satellites.set_view(stage,jd,true_size)

static func targets(stage: Node) -> Array[Dictionary]:
	if not stage.has_meta("jovian"): return []
	var data: Dictionary = stage.get_meta("jovian")
	var direction: Vector3 = data.get("sunlight",Vector3.FORWARD).rotated(Vector3.UP,.45)
	var result: Array[Dictionary] = [{"node":data.jupiter,"label":"木星 · 云带与自转","source_url":"https://science.nasa.gov/jupiter/","role":"木星平均半径69911km；IAU自转模型，Hubble历史拼图，极区边缘颜色延伸为显示辅助。","distance":3.8,"min_distance":1.3,"view_offset":direction*3.8}]
	for i: int in range(4):
		var size: float = Model.RADII_KM[i]/RADIUS_KM*1.0
		result.append({"node":data.bodies[i].node,"label":Model.NAMES[i],"source_url":MAP_SOURCE,"role":I18n.format_text("NASA/JPL/USGS历史影像拼图；蓝灰斜纹为影像缺测区，非真实地形。平均半径%.2f km；星历位置与理想同步朝向分别计算，没有求解潮汐、火山或内部海洋。",Model.RADII_KM[i]),"distance":size*4.8,"min_distance":size*1.4,"view_offset":direction*size*4.8})
	return result

static func readout(host: Node) -> String:
	if not States.available(host.solar_jd): return I18n.text("当前日期超出1995—2050卫星星历范围。")
	var text: String = I18n.text("木心几何轨迹 · TDB日期\n2026年9—12月星历区间平均绕行周期：")
	for i: int in range(4): text+=I18n.format_text("\n%s：%.3f 天",[Model.NAMES[i],Model.period_days(i)])
	return text+I18n.text("\n周期按缓存角位移估计；不是潮汐或共振动力学求解。")

static func entry_pose(stage: Node, _source: String) -> Dictionary:
	return {"position":stage.default_position*1.2,"target":Vector3.ZERO}
static func exit_pose(stage: Node, _target: String) -> Dictionary:
	return {"position":stage.default_position*1.3,"target":Vector3.ZERO}

static func overview_position(stage: Node, available_width: float, height: float) -> Vector3:
	return Vector3(18,42,57)*maxf(1.,height/maxf(100.,available_width)*1.25)

static func update_camera(stage: Node) -> void:
	if not stage.has_meta("jovian"): return
	var data: Dictionary = stage.get_meta("jovian")
	var close: bool = stage.camera.position.length()<5.
	for i: int in range(4):
		var radius: float = Model.RADII_KM[i]/RADIUS_KM*1.0
		close=close or stage.camera.position.distance_to(data.bodies[i].node.position)<radius*12.
	for body: Dictionary in data.bodies:
		body.label.visible=false # Hover and selection identify moons without permanent captions.
		body.orbit.visible=not close
		# Maintain readable labels at overview distances; close views use the panel.
		var depth: float = -stage.camera.to_local(body.label.position).z
		body.label.pixel_size=maxf(.001,depth*2.*tan(deg_to_rad(stage.camera.fov*.5))/maxf(1.,stage.camera.get_viewport().size.y))
	Satellites.update_camera(stage)
