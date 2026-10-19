extends RefCounted
## Observer demonstration derived from World time. No cosmological state/solver.
const POINT_SHADER: Shader = preload("res://shaders/cosmic_points.gdshader")
const GALAXY_SHADER: Shader = preload("res://shaders/cosmic_galaxy.gdshader")
const MIST_SHADER: Shader = preload("res://shaders/cosmic_mist.gdshader")
const SOURCE: String = "https://science.nasa.gov/universe/galaxies/large-scale-structures/"
const EXPANSION_SOURCE: String = "https://science.nasa.gov/mission/hubble/science/science-behind-the-discoveries/hubble-constant-and-tension/"
const FIELD_RADIUS: float = 120.0
const MAXIMUM_DISTANCE: float = 150.0

static func build(stage: Node) -> void:
	stage.semantic_size_m = 1.0e25 # Illustrative context; not a calibrated survey.
	stage.default_position = Vector3(10, 13, 29)
	stage.default_target = Vector3.ZERO
	stage.target_position = Vector3.ZERO
	stage.target_radius = 0.55
	stage.close_position = Vector3(0, 0.6, 2.0)
	stage.camera.fov = 58.0
	stage.set_meta("orbit_max_distance", MAXIMUM_DISTANCE)
	stage.environment.glow_intensity = 0.38
	stage.set_meta("scientific_category", "procedural_cosmic_web_and_expansion_demonstration")
	stage.set_meta("scientific_label", "宇宙结构全景 · 星系团、丝状结构与空洞的作者示意\n间距随世界时间增加，表示膨胀趋势；星系本身不被拉大。每次进入重播相对间距演示，非真实宇宙年代或实测星系图。\n银河作为观察参考，不代表宇宙中心；点光、颜色与亮度增强以便辨认，暗物质丝状结构并非肉眼可见的发光绳。")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 261006
	var knots: Array[Vector3] = [Vector3.ZERO]
	for i: int in range(27):
		knots.append(Vector3(rng.randf_range(-19,19),rng.randf_range(-10,10),rng.randf_range(-18,16)))
	# A surrounding 3D field is present from the start. Zoom never scales the
	# content toward the camera or generates a flat star wallpaper.
	for attempt: int in range(2000):
		if knots.size() >= 116: break
		var direction: Vector3 = Vector3(rng.randfn(0,1),rng.randfn(0,1),rng.randfn(0,1)).normalized()
		var radius: float = pow(rng.randf_range(pow(28.0,3),pow(FIELD_RADIUS,3)),1.0/3.0)
		var candidate: Vector3 = direction * radius
		var spaced: bool = true
		for knot: Vector3 in knots:
			if candidate.distance_squared_to(knot) < 144.0: spaced=false; break
		if spaced: knots.append(candidate)
	var points: Array[Vector3] = []
	var colours: Array[Color] = []
	var radii: Array[float] = []
	var haze_points: Array[Vector3] = []
	var haze_colours: Array[Color] = []
	var haze_radii: Array[float] = []
	for k: int in range(knots.size()):
		var origin: Vector3 = knots[k]
		var spread: float = rng.randf_range(1.6,3.1) if k>=28 else .75
		for i: int in range(130):
			var offset: Vector3 = Vector3(rng.randfn(0,spread),rng.randfn(0,spread*.72),rng.randfn(0,spread))
			points.append(origin+offset)
			var tint: Color = Color(.54,.73,1.0).lerp(Color(1.0,.84,.61),rng.randf()*.85)
			tint.a=rng.randf_range(.32,.95)
			colours.append(tint); radii.append(rng.randf_range(.026,.085))
	var edges: Dictionary = {}
	for a: int in range(knots.size()):
		var nearest: Array[Dictionary] = []
		for b: int in range(knots.size()):
			if a!=b: nearest.append({"index":b,"distance":knots[a].distance_squared_to(knots[b])})
		nearest.sort_custom(func(left: Dictionary,right: Dictionary) -> bool: return float(left.distance)<float(right.distance))
		for neighbor: int in range(3):
			var b: int = int(nearest[neighbor].index)
			var key: Vector2i = Vector2i(mini(a,b),maxi(a,b))
			if edges.has(key): continue
			edges[key]=true
			var length: float = knots[a].distance_to(knots[b])
			var count: int = clampi(int(length*5.0),70,260)
			var width: float = clampf(length*.018,.18,.7)
			var bend: Vector3 = Vector3(rng.randfn(0,1),rng.randfn(0,1),rng.randfn(0,1))*length*.07
			for i: int in range(count):
				var t: float = rng.randf()
				var center: Vector3 = knots[a].lerp(knots[b],t)+bend*sin(t*PI)
				points.append(center+Vector3(rng.randfn(0,width),rng.randfn(0,width),rng.randfn(0,width)))
				colours.append(Color(.38,.57,.95,rng.randf_range(.12,.40)))
				radii.append(rng.randf_range(.020,.055))
				if i%12==0:
					var haze_t: float = float(i) / float(count-1)
					haze_points.append(knots[a].lerp(knots[b],haze_t)+bend*sin(haze_t*PI)); haze_colours.append(Color(.28,.45,.9,.12))
					haze_radii.append(width*.7)
	var material: ShaderMaterial = stage.builder._material(stage,POINT_SHADER)
	var cloud: MultiMeshInstance3D = _batch(stage,"CosmicWeb_IllustrativeGalaxies",points,colours,radii,material)
	var mist_material: ShaderMaterial = stage.builder._material(stage,MIST_SHADER)
	_batch(stage,"CosmicWeb_EnhancedDensity_Illustration",haze_points,haze_colours,haze_radii,mist_material)
	var galaxies: Array[Dictionary] = []
	for i: int in range(2):
		var origin: Vector3 = Vector3.ZERO if i==0 else knots[1]
		var disc: QuadMesh = QuadMesh.new(); disc.size = Vector2.ONE*(3.2 if i==0 else .85)
		var glow: ShaderMaterial = stage.builder._material(stage,GALAXY_SHADER)
		glow.set_shader_parameter("inclination",.58 if i==0 else .45)
		glow.set_shader_parameter("phase",rng.randf()*TAU)
		glow.set_shader_parameter("tint",Color(.62,.79,1.0))
		var node: MeshInstance3D = stage.add_mesh(disc,glow,origin)
		node.name = "MilkyWaySemanticAnchor" if i==0 else "DistantGalaxy_Reference"
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		galaxies.append({"node":node,"origin":origin})
	# Distant individual galaxy symbols share one material and one draw batch.
	var galaxy_points: Array[Vector3] = []
	var galaxy_colours: Array[Color] = []
	var galaxy_radii: Array[float] = []
	for i: int in range(348):
		var origin: Vector3 = knots[i%knots.size()]
		galaxy_points.append(origin+Vector3(rng.randfn(0,2.8),rng.randfn(0,2.0),rng.randfn(0,2.8)))
		galaxy_colours.append(Color(.50,.70,1.0) if i%3 else Color(1.0,.76,.5))
		galaxy_radii.append(rng.randf_range(.28,.85))
	var galaxy_material: ShaderMaterial = stage.builder._material(stage,GALAXY_SHADER)
	galaxy_material.set_shader_parameter("batched",true)
	var galaxy_batch: MultiMeshInstance3D = _batch(stage,"DistantGalaxies_Batched",galaxy_points,galaxy_colours,galaxy_radii,galaxy_material,true)
	for i: int in range(galaxy_batch.multimesh.instance_count):
		galaxy_batch.multimesh.set_instance_custom_data(i,Color(rng.randf()*TAU,rng.randf_range(.20,.88),rng.randf()*TAU,1.0 if i%4==0 else 0.0))
	stage.set_meta("cosmic_panorama",{"epoch":float(stage.world_snapshot.simulation_time_s),"points":material,"mist":mist_material,"galaxies":galaxies,"factor":1.0,"galaxy_batch":galaxy_batch,"galaxy_material":galaxy_material,"extent":FIELD_RADIUS,"point_count":points.size(),"mist_count":haze_points.size(),"point_batch":cloud,"knots":knots.size(),"filaments":edges.size()})

static func _batch(stage: Node, label: String, points: Array[Vector3], colours: Array[Color], radii: Array[float], material: ShaderMaterial, custom: bool = false) -> MultiMeshInstance3D:
	var mesh: QuadMesh = QuadMesh.new(); mesh.size=Vector2(2,2)
	var batch: MultiMesh = MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D; batch.use_colors=true; batch.use_custom_data=custom; batch.mesh=mesh
	batch.instance_count=points.size()
	for i: int in range(points.size()):
		batch.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*radii[i]),points[i]))
		batch.set_instance_color(i,colours[i])
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name=label; node.multimesh=batch; node.material_override=material
	# Includes the full 1.65x expansion, point halos and all camera directions.
	node.custom_aabb=AABB(Vector3.ONE*-230.0,Vector3.ONE*460.0)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.world_root.add_child(node)
	return node

static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("cosmic_panorama"): return
	var data: Dictionary = stage.get_meta("cosmic_panorama")
	var elapsed: float = maxf(0.0,time-float(data.epoch))
	# Bounded one-way demonstration: no repeating collapse or expanding galaxies.
	var factor: float = 1.0+.65*(1.0-exp(-elapsed/45.0))
	data.factor=factor
	data.points.set_shader_parameter("expansion_factor",factor)
	data.mist.set_shader_parameter("expansion_factor",factor)
	data.galaxy_material.set_shader_parameter("expansion_factor",factor)
	for galaxy: Dictionary in data.galaxies:
		galaxy.node.position=galaxy.origin*factor
		galaxy.node.basis=stage.camera.basis
