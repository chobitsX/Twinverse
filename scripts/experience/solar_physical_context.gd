extends RefCounted
## One physical length scale in a near system; distant bodies keep their real
## direction and angular radius on a separate, explicit far-field projection.
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
const Span = preload("res://scripts/core/satellite_ephemeris_span.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const POINT = preload("res://shaders/satellite_point.gdshader")
const SUN_RADIUS_KM: float = 695700.0 # IAU 2015 nominal conversion constant.
const EARTH_GM: float = 398600.436 # JPL physical-parameter table, km^3/s^2.
const MOON_GM: float = 4902.800
const FAR_DISTANCE: float = 4096.0

static func build(stage: Node) -> void:
	var points: Array[MeshInstance3D] = []
	for index: int in range(10):
		var quad: QuadMesh = QuadMesh.new(); quad.size=Vector2.ONE
		var material: ShaderMaterial = ShaderMaterial.new(); material.shader=POINT
		material.set_shader_parameter("colour",Color(1.0,.79,.40) if index==8 else Color(.56,.80,.91))
		var point: MeshInstance3D = stage.add_mesh(quad,material)
		point.name="PhysicalBodyIdentityPoint_%d" % index
		point.hide(); points.append(point)
	stage.set_meta("solar_physical",{"owner":-1,"points":points,"jd":-INF,"centres":[]})
	for index: int in range(8): stage.get_meta("solar_bodies")[index].pick_nodes=[points[index]]
	stage.set_meta("solar_subject_frame",-1)
	stage.set_meta("solar_natural_frame",-1)

static func owner(stage: Node) -> int:
	var seasons: Dictionary = stage.get_meta("earth_season_orbit",{})
	if bool(stage.get_meta("solar_orbit_overview",false)) or bool(seasons.get("active",false)) or bool(stage.get_meta("solar_frame_suppressed",false)): return -1
	for key: String in ["solar_satellite_bridge_index","solar_focus_index","solar_subject_frame","solar_natural_frame"]:
		var index: int = int(stage.get_meta(key,-1))
		if index>=0 and index<=8: return index
	return -1

static func centres_km(jd: float) -> Array:
	var centres: Array = []
	for index: int in range(8):
		var p: Array[float] = Orbit.De440.position_components_au(index,jd)
		if p.is_empty():
			var fallback: Vector3 = Orbit.position_au(index,jd)
			p.assign([fallback.x,fallback.y,fallback.z])
		for axis: int in range(3): p[axis]*=Orbit.AU_KM
		var offset: Array[float] = Span.planet_centre_offset(index,jd)
		if not offset.is_empty():
			for axis: int in range(3): p[axis]+=offset[axis]
		centres.append(p)
	# The DE440 cache is EMB, whereas the lunar vector is geocentric. Make
	# that distinction explicit instead of placing Earth's body at the EMB.
	var moon: Vector3 = Orientation.moon_position_km(jd)
	var relative: Array[float] = [moon.x,-moon.z,moon.y]
	var mass_fraction: float = MOON_GM/(EARTH_GM+MOON_GM)
	for axis: int in range(3): centres[2][axis]-=relative[axis]*mass_fraction
	centres.append([0.0,0.0,0.0]) # Sun, heliocentric origin.
	centres.append([centres[2][0]+relative[0],centres[2][1]+relative[1],centres[2][2]+relative[2]])
	return centres

static func relative_world(a: Array, b: Array, scale: float) -> Vector3:
	return Vector3((float(a[0])-float(b[0]))*scale,(float(a[2])-float(b[2]))*scale,-(float(a[1])-float(b[1]))*scale)

static func update(stage: Node, jd: float) -> void:
	if not stage.has_meta("solar_physical"): return
	var data: Dictionary = stage.get_meta("solar_physical")
	data.owner=owner(stage)
	if int(data.owner)<0:
		for point: MeshInstance3D in data.points: point.hide()
		stage.set_meta("solar_physical_active",false)
		return
	if float(data.jd)!=jd:
		data.centres=centres_km(jd); data.jd=jd
	var index: int = int(data.owner)
	var primary: MeshInstance3D = stage.get_meta("solar_bodies")[index].node if index<8 else stage.world_root.get_node("Sun_AuthoredPhotosphere")
	data.radius_world=float(primary.mesh.radius)
	data.km_to_world=float(data.radius_world)/(Orbit.RADII_KM[index] if index<8 else SUN_RADIUS_KM)
	data.anchor=Orbit.display_position(index,jd,bool(stage.get_meta("solar_true_distance",false))) if index<8 else Vector3.ZERO
	update_camera(stage)

static func update_camera(stage: Node) -> void:
	if not stage.has_meta("solar_physical"): return
	var data: Dictionary = stage.get_meta("solar_physical")
	var owner_index: int = int(data.owner)
	if owner_index<0 or data.centres.is_empty(): return
	var camera: Camera3D = stage.camera
	camera.far=maxf(camera.far,FAR_DISTANCE*1.5)
	var pixel_factor: float = 2.0*tan(deg_to_rad(camera.fov*.5))/maxf(1.0,stage.viewport.size.y)
	var radii: Array[float] = []; radii.assign(Orbit.RADII_KM); radii.append(SUN_RADIUS_KM); radii.append(Orientation.MOON_RADIUS_KM)
	var positions: Array[Vector3] = []
	var render_radii: Array[float] = []
	for index: int in range(10):
		var node: MeshInstance3D = stage.get_meta("solar_bodies")[index].node if index<8 else stage.world_root.get_node("Sun_AuthoredPhotosphere") if index==8 else stage.get_meta("solar_moon").node
		var physical: Vector3 = Vector3(data.anchor)+relative_world(data.centres[index],data.centres[owner_index],float(data.km_to_world))
		var radius: float = radii[index]*float(data.km_to_world)
		var sight: Vector3 = physical-camera.position
		var distance: float = sight.length()
		# Only far objects use the capped depth; foreground satellites/host keep
		# their unmodified physical coordinates. Scaling R and D together keeps
		# asin(R/D) and hence the actual angular radius, including parallax.
		var factor: float = minf(1.0,FAR_DISTANCE/maxf(.001,distance))
		if (index==owner_index or index==9 and owner_index==2) and not bool(stage.get_meta("solar_transfer_projection",false)): factor=1.0
		node.position=physical if factor==1.0 else camera.position+sight*factor
		var displayed_radius: float = radius*factor
		var basis: Basis = node.basis.orthonormalized()
		node.basis=basis.scaled(Vector3.ONE*displayed_radius/float(node.mesh.radius))
		node.transparency=0.0; node.visible=true
		positions.append(physical); render_radii.append(displayed_radius)
		var material: ShaderMaterial = node.material_override
		var sunward: Vector3 = -relative_world(data.centres[index],data.centres[8],1.0).normalized()
		if index<8:
			material.set_shader_parameter("planet_center",node.position)
			material.set_shader_parameter("sun_direction",sunward)
			if index==5 and index!=owner_index:
				material.set_shader_parameter("ring_inner",0.0)
				material.set_shader_parameter("ring_outer",0.0)
			for extra: MeshInstance3D in stage.get_meta("solar_bodies")[index].extras:
				extra.position=node.position; extra.scale=node.scale
				extra.visible=index==owner_index
				extra.material_override.set_shader_parameter("planet_center",node.position)
				extra.material_override.set_shader_parameter("sun_direction",sunward)
				if index==5: extra.material_override.set_shader_parameter("planet_radius",displayed_radius)
			stage.get_meta("solar_bodies")[index].orbit.hide()
		elif index==9:
			material.set_shader_parameter("planet_center",node.position)
			material.set_shader_parameter("sun_direction",sunward)
		var point: MeshInstance3D = data.points[index]
		var depth: float = -camera.to_local(node.position).z
		var pixel_world: float = maxf(.000001,depth*pixel_factor)
		point.position=node.position
		point.basis=camera.basis.scaled(Vector3.ONE*pixel_world*5.0)
		point.visible=depth>camera.near and 2.0*displayed_radius<pixel_world*5.0
		node.set_meta("physical_radius_km",radii[index])
		node.set_meta("physical_distance_from_host_km",relative_world(data.centres[index],data.centres[owner_index],1.0).length())
	data.physical_positions=positions; data.render_radii=render_radii
	var sun: MeshInstance3D = stage.world_root.get_node("Sun_AuthoredPhotosphere")
	var corona: MeshInstance3D = stage.world_root.get_node("SolarCorona_Illustration")
	corona.position=sun.position; corona.scale=sun.scale
	corona.visible=sun.visible and not bool(stage.get_meta("solar_true_distance",false))
	stage.get_meta("solar_history").node.hide()
	stage.get_meta("solar_moon").orbit.visible=owner_index==2 and str(stage.get_meta("satellite_framing",{}).get("mode",""))!="pair"
	stage.set_meta("solar_physical_active",true)
