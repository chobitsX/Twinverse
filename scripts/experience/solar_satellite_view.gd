extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Local satellite context in the existing solar viewport; one date and one scale.
const Model = preload("res://scripts/core/natural_satellites.gd")
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const SURFACE = preload("res://shaders/jovian_surface.gdshader")
const REFERENCE = preload("res://shaders/satellite_reference.gdshader")
const POINT = preload("res://shaders/satellite_point.gdshader")
const INDEX: Dictionary = {"mars":3,"jupiter":4,"saturn":5,"uranus":6,"neptune":7}
const MAPS: Dictionary = {501:"io",502:"europa",503:"ganymede",504:"callisto"}

static func build(stage: Node) -> void:
	var systems: Dictionary = {}
	for host: String in INDEX:
		var index: int = int(INDEX[host])
		var root: Node3D = Node3D.new()
		root.name=host.capitalize()+"SatelliteContext"
		stage.world_root.add_child(root)
		var bodies: Array[Dictionary] = []
		for item: Dictionary in Model.major_records(host):
			var material: ShaderMaterial = ShaderMaterial.new()
			var key: String = str(MAPS.get(int(item.code),""))
			material.shader=SURFACE if not key.is_empty() else REFERENCE
			if not key.is_empty():
				material.set_shader_parameter("surface_map",stage.textures[key])
				material.set_shader_parameter("coverage_map",stage.textures[key+"_coverage"])
				material.set_shader_parameter("has_coverage",true)
				material.set_shader_parameter("longitude_offset",.5 if key=="io" else 0.0)
			var radius: float = float(item.physical.mean_radius_km)/Ephemeris.RADII_KM[index]
			var node: MeshInstance3D = stage.add_mesh(stage.builder._sphere(radius,48,24),material)
			node.reparent(root)
			node.name=str(item.key)
			var marker_material: ShaderMaterial = ShaderMaterial.new()
			marker_material.shader=POINT
			var quad: QuadMesh = QuadMesh.new()
			quad.size=Vector2.ONE
			var point: MeshInstance3D = stage.add_mesh(quad,marker_material)
			point.reparent(root)
			point.name=str(item.key)+"_identity_point"
			var orbit: MeshInstance3D = stage.builder._line(stage,PackedVector3Array([Vector3.ZERO,Vector3.ONE]),Color(.12,.24,.29),str(item.key)+"_trajectory")
			orbit.reparent(root)
			bodies.append({"record":item,"node":node,"material":material,"point":point,"orbit":orbit,"orbit_jd":-INF,"mapped":not key.is_empty()})
		root.hide()
		systems[index]={"host":host,"index":index,"root":root,"bodies":bodies,"alpha":0.0,"valid":false}
	stage.set_meta("solar_satellite_systems",systems)

static func radius(stage: Node, index: int) -> float:
	var planet: MeshInstance3D = stage.get_meta("solar_bodies")[index].node
	return float(planet.mesh.radius)*absf(planet.scale.x)

static func enlargement(stage: Node) -> float:
	return 1.0

static func update(stage: Node, jd: float) -> void:
	if not stage.has_meta("solar_satellite_systems"): return
	for system: Dictionary in stage.get_meta("solar_satellite_systems").values(): system.valid=Model.available(jd)
	update_camera(stage)

static func _positions(stage: Node, index: int, system: Dictionary, jd: float) -> void:
	var planet: MeshInstance3D = stage.get_meta("solar_bodies")[index].node
	var scale: float = radius(stage,index)
	var centre: Vector3=planet.position
	var physical: Dictionary=stage.get_meta("solar_physical",{})
	if int(physical.get("owner",-1))==index:
		# A transfer's far-depth projection must never become an orbital origin.
		scale=float(planet.mesh.radius); centre=physical.anchor
	if float(system.get("sampled_jd",-INF))==jd and float(system.get("sampled_scale",0.0))==scale and Vector3(system.get("sampled_centre",Vector3.INF))==centre: return
	var direction: Vector3 = -Ephemeris.display_position(index,jd,true).normalized()
	for body: Dictionary in system.bodies:
		var state: Dictionary = Model.sample(body.record,jd)
		body.node.visible=state.valid
		if not state.valid: body.point.hide(); continue
		var relative: Vector3 = Model.world_position(state,Ephemeris.RADII_KM[index])
		body.node.position=centre+relative*scale
		var basis: Basis = Basis.IDENTITY
		if body.mapped:
			var v: Array = state.velocity_km_day
			var velocity: Vector3 = Vector3(v[0],v[2],-v[1])
			var pole: Vector3 = relative.cross(velocity).normalized()
			var prime: Vector3 = -relative.normalized()
			basis=Basis(pole.cross(prime),pole,prime)
		elif body.record.get("rotation")!=null: basis=Orientation.orientation_basis(body.record.rotation,jd)
		body.node.basis=basis.scaled(Vector3.ONE*scale*enlargement(stage))
		body.material.set_shader_parameter("sun_direction",direction)
		if body.mapped: body.material.set_shader_parameter("body_center",body.node.position)
		body.point.position=body.node.position
		body.orbit.position=centre
		body.orbit.scale=Vector3.ONE*scale
		body.node.set_meta("activity",I18n.text("距%s中心 %.0f km · 局部距离同比\n%s · %s") % [Model.name(str(system.host)),float(state.distance_km),I18n.text("距离与半径同比（识别点非大小）"),I18n.text("历史影像") if body.mapped else I18n.text("中性尺寸示意球")])
	system.sampled_jd=jd; system.sampled_scale=scale; system.sampled_centre=centre

static func update_camera(stage: Node) -> void:
	if not stage.has_meta("solar_satellite_systems"): return
	var camera: Camera3D = stage.camera
	var pixel_factor: float = 2.0*tan(deg_to_rad(camera.fov*.5))/maxf(1.0,stage.viewport.size.y)
	var focus: int = int(stage.get_meta("solar_focus_index",-1))
	var orbit_view: bool = bool(stage.get_meta("solar_orbit_overview",false))
	var systems: Dictionary = stage.get_meta("solar_satellite_systems")
	var selected_key: String = str(stage.get_meta("solar_satellite_selected_key",""))
	var bridge_index: int = int(stage.get_meta("solar_satellite_bridge_index",-1))
	var exploring: bool = bool(stage.get_meta("solar_camera_exploring",false))
	var previous_visible: int = int(stage.get_meta("solar_visible_context",-1))
	var physical_owner: int = int(stage.get_meta("solar_physical",{}).get("owner",-1))
	var screen: Rect2 = Rect2(Vector2.ZERO,Vector2(stage.viewport.size))
	var visible_index: int = -1
	var best_pixels: float = 0.0
	for index: int in systems:
		var system: Dictionary = systems[index]
		var planet: MeshInstance3D = stage.get_meta("solar_bodies")[index].node
		var scale: float = radius(stage,index)
		var depth: float = -camera.to_local(planet.position).z
		var pixels: float = scale/maxf(.0001,depth*pixel_factor)
		var nearby: bool = camera.position.distance_to(planet.position)<scale*(24.0 if previous_visible==index else 22.0)
		var onscreen: bool = depth>camera.near and screen.has_point(camera.unproject_position(planet.position))
		system.alpha=smoothstep(18.0,42.0,pixels) if onscreen and nearby and not orbit_view and (exploring or focus==index) else 0.0
		if bridge_index==index or selected_key.begins_with(str(system.host)+"_") or int(stage.get_meta("satellite_framing",{}).get("owner",-1))==index: system.alpha=1.0
		if focus>=0 and focus!=index: system.alpha=0.0
		system.root.visible=system.valid and float(system.alpha)>.02 and physical_owner==index
		if system.root.visible:
			var score: float = pixels*float(system.alpha)
			if score>best_pixels: visible_index=index; best_pixels=score
		if system.root.visible: _positions(stage,index,system,float(stage.get_meta("solar_jd")))
		for body: Dictionary in system.bodies:
			body.node.transparency=1.0-float(system.alpha)
			var moon_depth: float = -camera.to_local(body.point.position).z
			var pixel_world: float = maxf(.000001,moon_depth*pixel_factor)
			var moon_radius: float = float(body.node.mesh.radius)*scale*enlargement(stage)
			body.point.visible=system.valid and body.node.visible and moon_depth>camera.near and moon_radius*2.0<pixel_world*5.0
			body.point.basis=camera.basis.scaled(Vector3.ONE*pixel_world*5.0*float(system.alpha))
			body.orbit.visible=system.root.visible and pixels<180.0
			if body.orbit.visible: _orbit(stage,body,float(stage.get_meta("solar_jd")))
	# Satellite detail supplements the existing solar world. Selecting a planet
	# must not remove its neighbours: the parent builder owns their visibility,
	# positions, overview enlargement and the dedicated teaching-view masks.
	# The custom corona writes ALPHA, overriding the node's transparency default.
	# Hide the two nodes together; never fade an opaque Sun into a hollow corona.
	var sun: MeshInstance3D = stage.world_root.get_node("Sun_AuthoredPhotosphere")
	var corona: MeshInstance3D = stage.world_root.get_node("SolarCorona_Illustration")
	sun.transparency=0.0; corona.transparency=0.0
	sun.visible=true
	corona.visible=sun.visible and not orbit_view and not bool(stage.get_meta("solar_true_distance",false))
	stage.set_meta("solar_visible_context",visible_index)

static func _orbit(stage: Node, body: Dictionary, jd: float) -> void:
	if absf(jd-float(body.orbit_jd))<.2: return
	var period: float = float(body.record.mean_elements.table_period_days)
	var bounds: Array[float] = Model.date_range(body.record)
	var start: float = clampf(jd-period*.5,bounds[0],bounds[1]-period)
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i: int in range(97):
		var state: Dictionary = Model.sample(body.record,start+period*float(i)/96.0)
		if state.valid: mesh.surface_add_vertex(Model.world_position(state,Ephemeris.RADII_KM[int(body.record.host_index)]))
	mesh.surface_end()
	body.orbit.mesh=mesh
	body.orbit_jd=jd

static func targets(stage: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not stage.has_meta("solar_satellite_systems"): return result
	var systems: Dictionary = stage.get_meta("solar_satellite_systems")
	for index: int in systems:
		var system: Dictionary = systems[index]
		var scale: float = radius(stage,index)
		for body: Dictionary in system.bodies:
			var size: float = float(body.node.mesh.radius)*scale*enlargement(stage)
			var distance: float = maxf(.012,size*5.0)
			result.append({"node":body.node,"pick_nodes":[body.point],"label":I18n.text(str(body.record.display_name)),"satellite_key":str(body.record.key),"host_planet":index,"destination":Model.BRANCHES[str(system.host)],"distance":distance,"min_distance":maxf(.0015,size*1.5),"entry_distance":distance*.55,"role":Model.description(body.record),"source_url":"https://ssd.jpl.nasa.gov/sats/ephem/"})
	return result

static func local_pose(solar: Node, index: int, pose: Dictionary) -> Dictionary:
	var centre: Vector3 = solar.get_meta("solar_bodies")[index].node.position
	var factor: float = radius(solar,index)
	return {"position":(Vector3(pose.position)-centre)/factor,"target":(Vector3(pose.target)-centre)/factor,"up":pose.get("up",Vector3.UP)}

static func solar_pose(solar: Node, index: int, pose: Dictionary) -> Dictionary:
	var centre: Vector3 = solar.get_meta("solar_bodies")[index].node.position
	var factor: float = radius(solar,index)
	return {"position":centre+Vector3(pose.position)*factor,"target":centre+Vector3(pose.target)*factor,"up":pose.get("up",Vector3.UP)}
