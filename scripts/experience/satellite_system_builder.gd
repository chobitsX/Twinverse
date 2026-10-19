extends RefCounted
const Model = preload("res://scripts/core/natural_satellites.gd")
const Cosmos = preload("res://scripts/experience/cosmos_builder.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const SURFACE = preload("res://shaders/jovian_surface.gdshader")
const REFERENCE = preload("res://shaders/satellite_reference.gdshader")
const POINT = preload("res://shaders/satellite_point.gdshader")
const RINGS = preload("res://shaders/satellite_rings.gdshader")
const INDEX: Dictionary = {"mars":3,"jupiter":4,"saturn":5,"uranus":6,"neptune":7}
const INNER_EXTENT: Dictionary = {"mars":9.0,"jupiter":30.0,"saturn":28.0,"uranus":26.0,"neptune":20.0}

static func build(stage: Node) -> void:
	var host: String = Model.host_for_scale(stage.scale_id)
	var index: int = int(INDEX[host])
	stage.semantic_size_m = float(Ephemeris.RADII_KM[index])*2000.0
	stage.camera.fov = 48.0
	stage.camera.near = .008
	stage.camera.far = 10000.0
	stage.environment.background_color = Color(.001,.002,.004)
	stage.environment.ambient_light_energy = .04
	stage.environment.glow_enabled = true
	stage.environment.glow_intensity = .1
	var material: ShaderMaterial = ShaderMaterial.new()
	if stage.textures.has(host):
		material.shader = SURFACE
		material.set_shader_parameter("surface_map",stage.textures[host])
		material.set_shader_parameter("longitude_offset",.5)
	else:
		material.shader = REFERENCE
		material.set_shader_parameter("colour",Vector3(.37,.72,.78) if host=="uranus" else Vector3(.14,.34,.75))
	var planet: MeshInstance3D = stage.add_mesh(Cosmos._sphere(1.,96,48),material)
	planet.name = Model.name(host)
	attach(stage,host,planet,material)
	if host=="saturn":
		var ring_material: ShaderMaterial = ShaderMaterial.new()
		ring_material.shader = RINGS
		ring_material.set_shader_parameter("planet_radius",1.0)
		var rings: MeshInstance3D = stage.add_mesh(Cosmos._planet_rings(1.24,2.25),ring_material)
		rings.name = "SaturnRings_DisplayReference"
		stage.get_meta("natural_satellites").rings = rings
		stage.get_meta("natural_satellites").ring_material = ring_material
	Cosmos._stars(stage,1000,1800,3000,false)
	set_view(stage,Ephemeris.DEFAULT_JD,false)

static func attach(stage: Node, host: String, planet: MeshInstance3D, material: ShaderMaterial, existing: Dictionary = {}) -> void:
	var index: int = int(INDEX[host])
	var radius: float = float(Ephemeris.RADII_KM[index])
	var root: Node3D = Node3D.new()
	root.name = "NaturalSatelliteCatalogue"
	stage.world_root.add_child(root)
	var bodies: Array[Dictionary] = []
	var point_mesh: QuadMesh = QuadMesh.new()
	point_mesh.size = Vector2.ONE
	var point_material: ShaderMaterial = ShaderMaterial.new()
	point_material.shader = POINT
	for item: Dictionary in Model.records(host):
		if item.get("ephemeris_status","")!="vectors": continue
		var reused: bool = existing.has(int(item.code))
		var known_radius: float = float(item.physical.get("mean_radius_km",0.0)) if item.physical.get("mean_radius_km")!=null else 0.0
		var node: MeshInstance3D
		var body_material: ShaderMaterial
		if reused: node=existing[int(item.code)]
		elif known_radius>0.0:
			body_material=ShaderMaterial.new()
			body_material.shader=REFERENCE
			node=stage.add_mesh(Cosmos._sphere(known_radius/radius,32,16),body_material)
			node.reparent(root)
		else:
			node=stage.add_mesh(point_mesh,point_material)
			node.reparent(root)
		if not reused: node.name=str(item.key)
		var point: MeshInstance3D = node
		if known_radius>0.0:
			point=stage.add_mesh(point_mesh,point_material)
			point.reparent(root)
			point.name=str(item.key)+"_identity_point"
		var orbit: MeshInstance3D = Cosmos._line(stage,PackedVector3Array([Vector3.ZERO,Vector3.ONE]),Color(.11,.25,.31),str(item.key)+"_sampled_arc")
		orbit.reparent(root)
		orbit.visible=false
		bodies.append({"record":item,"node":node,"point":point,"material":body_material,"radius_km":known_radius,"reused":reused,"orbit":orbit,"orbit_jd":-INF})
	var inner: float = float(INNER_EXTENT[host])
	var extent: float = inner
	for item: Dictionary in Model.records(host):
		if item.get("mean_elements")!=null: extent=maxf(extent,float(item.mean_elements.a_km)*(1.0+float(item.mean_elements.e))/radius)
	stage.default_position=Vector3(.23,.66,1.0).normalized()*inner*2.5
	stage.default_target=Vector3.ZERO
	stage.close_position=Vector3(0,1.3,3.5)
	stage.target_position=Vector3.ZERO
	stage.target_radius=1.0
	stage.camera.far=maxf(10000.0,extent*6.0)
	stage.set_meta("orbit_max_distance",extent*5.0)
	stage.set_meta("natural_satellites",{"host":host,"index":index,"radius_km":radius,"planet":planet,"planet_material":material,"root":root,"bodies":bodies,"selected":-1,"valid":false,"true_size":false,"extent":extent,"inner_extent":inner})
	stage.set_meta("content_summary","%s · 完整%d颗天然卫星名录\n近域可观察主要卫星；全域显示已缓存小卫星。距离始终同比缩放，已知卫星距离与半径同比，点标仅用于识别。选择或指向时显示名字。" % [Model.name(host),Model.count(host)])

static func set_view(stage: Node, jd: float, true_size: bool) -> void:
	if not stage.has_meta("natural_satellites"): return
	var data: Dictionary = stage.get_meta("natural_satellites")
	data.valid=Model.available(jd)
	data.root.visible=data.valid
	data.true_size=true
	var direction: Vector3 = -Ephemeris.display_position(int(data.index),jd,true).normalized()
	data.sunlight=direction
	data.planet.basis=Orientation.body_basis(int(data.index),jd)
	data.planet_material.set_shader_parameter("sun_direction",direction)
	if data.has("rings"):
		data.rings.basis=data.planet.basis
		data.ring_material.set_shader_parameter("sun_direction",direction)
	if not data.valid:
		for body: Dictionary in data.bodies: body.node.set_meta("activity","当前日期无卫星位置 · 主要卫星支持1995—2050")
		stage.set_meta("scientific_label","卫星位置支持1995—2050 TDB；当前日期不在覆盖范围，不外推轨迹。")
		return
	var covered: int = 0
	for body: Dictionary in data.bodies:
		var state: Dictionary = Model.sample(body.record,jd)
		body.node.visible=state.valid
		body.node.set_meta("satellite_position_valid",state.valid)
		if not state.valid:
			body.point.hide()
			body.node.set_meta("activity","当前日期缺少此卫星的位置数据；身份保留在名录中。")
			continue
		covered+=1
		if not body.reused:
			body.node.position=Model.world_position(state,float(data.radius_km))
			if float(body.radius_km)>0.0:
				var basis: Basis = Orientation.orientation_basis(body.record.rotation,jd) if body.record.get("rotation")!=null else Basis.IDENTITY
				# Mean radius and distance both use the host mean radius as their unit.
				body.node.basis=basis
				body.material.set_shader_parameter("sun_direction",direction)
		body.point.position=body.node.position
		body.node.set_meta("activity","距%s中心 %.0f km · %s\n%s" % [Model.name(str(data.host)),state.distance_km,"识别点标，尺寸未知" if float(body.radius_km)==0.0 else "半径与距离同比","历史影像" if body.reused else "中性示意球，未提供真实表面影像" if float(body.radius_km)>0.0 else "位置来自同日期Horizons星历"])
	data.available_count=covered
	stage.set_meta("scientific_label","%s：名录%d颗，同日期可定位%d颗\nJPL几何星历 · 主要卫星1995—2050；其它条目日期范围见名录。距离同比，%s；灰色球为尺寸示意，点标不是大小。" % [Model.name(str(data.host)),Model.count(str(data.host)),covered,"真实半径；识别点不代表大小"])
	if str(data.host)=="saturn": stage.set_meta("scientific_label",str(stage.get_meta("scientific_label"))+"土星环宽/条带为显示示意。")
	update_camera(stage)
	_update_orbits(stage,jd)

static func targets(stage: Node) -> Array[Dictionary]:
	var data: Dictionary = stage.get_meta("natural_satellites")
	var direction: Vector3 = (Vector3(data.get("sunlight",Vector3.FORWARD))+Vector3.UP*.25).normalized()
	var result: Array[Dictionary] = [{"node":data.planet,"label":Model.name(str(data.host)),"source_url":"https://ssd.jpl.nasa.gov/sats/","role":"行星平均半径与IAU参考朝向；卫星距离同比。","distance":3.8,"min_distance":1.25,"view_offset":direction*3.8}]
	for i: int in range(data.bodies.size()):
		var body: Dictionary = data.bodies[i]
		var radius: float = float(body.radius_km)/float(data.radius_km)*1.0
		var distance: float = maxf(.012,radius*5.0) if radius>0.0 else .12
		result.append({"node":body.node,"pick_nodes":[body.point],"satellite_key":str(body.record.key),"label":str(body.record.display_name),"source_url":"https://ssd.jpl.nasa.gov/sats/","role":Model.description(body.record)+("\nUSGS历史影像拼图；理想同步姿态。" if body.reused else "\n中性球仅表达已知平均半径；未拟造真实表面/地形。" if float(body.radius_km)>0.0 else ""),"distance":distance,"min_distance":maxf(.0015,radius*1.4) if radius>0.0 else .015,"view_offset":direction*distance})
	return result

static func select(stage: Node, index: int) -> void:
	if stage.has_meta("natural_satellites"): stage.get_meta("natural_satellites").selected=index-1

static func focus_system(stage: Node, outer: bool) -> void:
	stage.set_meta("satellite_framing",{})
	stage.camera.fov=48.0
	stage.camera.near=.008
	var data: Dictionary = stage.get_meta("natural_satellites")
	data.selected=-1
	var extent: float = float(data.extent if outer else data.inner_extent)
	stage.default_position=Vector3(.23,.66,1.0).normalized()*extent*2.5
	stage.set_pose(stage.default_position,Vector3.ZERO)

static func update_camera(stage: Node) -> void:
	if not stage.has_meta("natural_satellites"): return
	var data: Dictionary = stage.get_meta("natural_satellites")
	var factor: float = 2.0*tan(deg_to_rad(stage.camera.fov*.5))/maxf(1.0,stage.viewport.size.y)
	for i: int in range(data.bodies.size()):
		var body: Dictionary = data.bodies[i]
		var depth: float = -stage.camera.to_local(body.point.position).z
		var pixel_world: float = maxf(.000001,depth*factor)
		var valid_position: bool = bool(body.node.get_meta("satellite_position_valid",false))
		var far_detail: bool = body.node.position.length()<float(data.inner_extent)*2.0 or stage.camera.position.length()>float(data.inner_extent)*3.5 or i==int(data.selected)
		body.point.visible=data.valid and valid_position and far_detail and depth>stage.camera.near and (float(body.radius_km)==0.0 or float(body.radius_km)/float(data.radius_km)*1.0*2.0 < pixel_world*5.0)
		body.point.basis=stage.camera.basis.scaled(Vector3.ONE*pixel_world*6.0)

static func _update_orbits(stage: Node, jd: float) -> void:
	var data: Dictionary = stage.get_meta("natural_satellites")
	for i: int in range(data.bodies.size()):
		var body: Dictionary = data.bodies[i]
		var visible_arc: bool = not body.reused and (i==int(data.selected) or float(body.radius_km)>=190.0 or str(data.host)=="mars")
		body.orbit.visible=data.valid and bool(body.node.get_meta("satellite_position_valid",false)) and visible_arc and stage.camera.position.distance_to(body.node.position)>.7
		if not body.orbit.visible or absf(jd-float(body.orbit_jd))<.2: continue
		var bounds: Array[float] = Model.date_range(body.record)
		var period: float = minf(bounds[1]-bounds[0],float(body.record.mean_elements.table_period_days)) if body.record.get("mean_elements")!=null else 91.0
		var start: float = clampf(jd-period*.5,bounds[0],bounds[1]-period)
		var mesh: ImmediateMesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k: int in range(161):
			var state: Dictionary = Model.sample(body.record,start+period*k/160.0)
			if state.valid: mesh.surface_add_vertex(Model.world_position(state,float(data.radius_km)))
		mesh.surface_end()
		body.orbit.mesh=mesh
		body.orbit_jd=jd

static func readout(host: Node) -> String:
	var data: Dictionary = host.coordinator.active_scene.get_meta("natural_satellites")
	return "%s名录%d颗 · 同日期可定位%d颗\n自转与公转共用TDB日期和倍率。靠近看主要卫星，拉远自然显现远方小卫星。\n线条取自有效日期内的几何星历；灰色球仅表示平均半径。\n主要卫星1995—2050，其它条目日期范围见名录；缺位置/尺寸/朝向的数据明确标注，不推算猜测轨迹。名录冻结于2026-10-13。" % [Model.name(str(data.host)),Model.count(str(data.host)),int(data.get("available_count",0))]

static func entry_pose(stage: Node, _source: String) -> Dictionary:
	return {"position":stage.default_position*1.2,"target":Vector3.ZERO}
static func exit_pose(stage: Node, _target: String) -> Dictionary:
	return {"position":stage.default_position*1.3,"target":Vector3.ZERO}
static func overview_position(stage: Node, width: float, height: float) -> Vector3:
	return stage.default_position*maxf(1.0,height/maxf(100.0,width)*1.25)
