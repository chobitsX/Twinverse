extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Synthetic lowland Sonoran setting, shared world clock and observer only.
const Iguana = preload("res://scripts/experience/iguana_observation.gd")
const Rat = preload("res://scripts/experience/kangaroo_rat_observation.gd")
const Terrain = preload("res://scripts/experience/desert_terrain.gd")
const Life = preload("res://scripts/experience/life_asset_motion.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const Land = preload("res://scripts/experience/land_builder.gd")
const GROUND = preload("res://shaders/desert_ground.gdshader")
const ROCK = preload("res://shaders/desert_rock.gdshader")
const ROCK_COLOR = preload("res://assets/textures/woodland89/rock_surface_diff_1k.jpg")
const CACTUS_SOURCE: String = "https://www.nps.gov/sagu/learn/nature/saguaro.htm"
const SHRUB_SOURCE: String = "https://www.nps.gov/tont/learn/nature/treesandshrubs.htm"
const MESQUITE_SOURCE: String = "https://www.nps.gov/orpi/learn/nature/treesandshrubs.htm"
const MESQUITE_ECOLOGY_SOURCE: String = "https://research.fs.usda.gov/feis/species-reviews/provel"
const HABITAT_SOURCE: String = "https://www.usgs.gov/geology-and-ecology-of-national-parks/ecology-saguaro-national-park"
const GEOLOGY_SOURCE: String = "https://www.nps.gov/sagu/learn/nature/geology.htm"
const OCOTILLO_SOURCE: String = "https://www.nps.gov/orpi/learn/nature/treesandshrubs.htm"
const OCOTILLO_ECOLOGY_SOURCE: String = "https://research.fs.usda.gov/feis/species-reviews/fouspl"
const BRITTLEBUSH_SOURCE: String = "https://www.nps.gov/orpi/learn/nature/treesandshrubs.htm"
const BRITTLEBUSH_ECOLOGY_SOURCE: String = "https://research.fs.usda.gov/feis/species-reviews/encfar"

static func height_at(x: float, z: float) -> float:
	return Terrain.height_at(x,z)

static func build(stage: Node) -> void:
	stage.semantic_size_m=280.0
	stage.camera.fov=48.0
	stage.camera.near=.06
	stage.camera.far=1400.0
	stage.default_position=Vector3(17,8.5,25)
	stage.default_target=Vector3(0,2,-7)
	stage.target_position=Vector3(-3,2.8,-2)
	stage.close_position=Vector3(3,4,9)
	stage.environment.background_mode=Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color(.18,.39,.61)
	sky_mat.sky_horizon_color=Color(.76,.76,.66)
	sky_mat.ground_horizon_color=sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color=Color(.32,.23,.14)
	sky.sky_material=sky_mat
	stage.environment.sky=sky
	stage.environment.ambient_light_color=Color(.78,.84,.93)
	stage.environment.ambient_light_energy=.55
	stage.environment.ssao_enabled=true
	stage.environment.ssao_radius=1.2
	stage.environment.ssao_intensity=.8
	stage.environment.fog_enabled=true
	stage.environment.fog_density=.0008
	stage.environment.fog_sky_affect=.12
	stage.environment.fog_light_color=Color(.74,.73,.62)
	var sun: DirectionalLight3D = stage.add_sun(Vector3(-35,-42,0),Color(1,.91,.73),1.55)
	# The overview is already about 35 m away: the generic 32 m cut-off
	# removed plant/rock contact shadows across most of the visible habitat.
	sun.directional_shadow_max_distance=100.0
	stage.set_meta("daylight_sun",sun)
	stage.set_meta("night_lamps",[])
	_terrain(stage)
	_plants(stage)
	_rocks(stage)
	_wash_gravel(stage)
	Iguana.build(stage)
	_mesquite(stage)
	Rat.build(stage)
	_ocotillo(stage)
	_brittlebush(stage)
	I18n.set_meta_text(stage,"scientific_label","索诺兰荒漠 · 合成低地灌丛\n巨柱仙人掌、三齿拉瑞阿、绒毛牧豆树、Ocotillo、Brittlebush、沙漠鬣蜥与梅氏袋鼠鼠参考。32°N / 112°W仅用于光照；不是国家公园测绘或生物实测位置。")
	I18n.set_meta_text(stage,"content_summary","9株巨柱仙人掌 · 64株三齿拉瑞阿灌木 · 4株沟缘绒毛牧豆树 · 6株Ocotillo · 8株Brittlebush · 1只沙漠鬣蜥 · 1只梅氏袋鼠鼠\n砾质裸地、浅枯沟、岩石与远山构成作者设计的干旱生境。比较肉质茎、成对小叶、木本荚果、带刺花枝、灰白叶冠/黄花头与夜间食籽动物。\n七种具名动植物参考；Ocotillo与Brittlebush花序均为静态形态样本，不表示当前日期花期或降雨。袋鼠鼠夜间有限教学种子搬运保留。株数、尺寸和布局不是实测群落；未模拟真实种子库存、取食/萌发、植物储水、生长、地下水或物候。")

static func _terrain(stage: Node) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 160
	for z: int in range(count):
		for x: int in range(count):
			var p: Vector2 = Vector2(x-count/2,z-count/2)*2.0
			for offset: Vector2 in [Vector2.ZERO,Vector2(2,0),Vector2(0,2),Vector2(2,0),Vector2(2,2),Vector2(0,2)]:
				var point: Vector2 = p+offset
				surface.add_vertex(Vector3(point.x,height_at(point.x,point.y),point.y))
	surface.generate_normals()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader=GROUND
	stage.add_mesh(surface.commit(),material).name="DryWashTerrain"
	# Authored rocky ridges and a low apron; the animal-support terrain above
	# remains unchanged. Same 7,200 triangles as the original distant ring.
	var hills: SurfaceTool = SurfaceTool.new()
	hills.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed=15032
	noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency=.0055
	noise.fractal_type=FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves=2
	noise.fractal_gain=.38
	for ring: int in range(21):
		var t: float=float(ring)/20.0
		var radius: float=145.0+t*460.0
		for sector: int in range(180):
			var a: float=TAU*float(sector)/180.0
			var at: Vector2=Vector2(cos(a),sin(a))*radius
			var apron: float=smoothstep(.0,.19,t)*(1.0-smoothstep(.82,1.0,t))
			var crest_radius: float=340.0+55.0*sin(a*3.0+.9)+27.0*sin(a*7.0)
			var width: float=180.0 if radius<crest_radius else 240.0
			var profile: float=maxf(0.0,1.0-absf(radius-crest_radius)/width)
			var sample: float=noise.get_noise_2d(at.x,at.y)
			var broken_ridge: float=1.0-sqrt(sample*sample+.018)
			var peak: float=62.0+34.0*sin(a*2.0-.8)+18.0*cos(a*5.0)
			var relief: float=apron*(4.0+peak*pow(profile,1.15)*pow(broken_ridge,2.1))
			hills.set_uv(Vector2(float(sector)/180.0,t))
			hills.add_vertex(Vector3(at.x,height_at(at.x,at.y)+relief,at.y))
	for ring: int in range(20):
		for sector: int in range(180):
			var next: int=(sector+1)%180
			for index: int in [ring*180+sector,(ring+1)*180+sector,ring*180+next,ring*180+next,(ring+1)*180+sector,(ring+1)*180+next]:
				hills.add_index(index)
	hills.generate_normals()
	var rock: ShaderMaterial = ShaderMaterial.new()
	rock.shader=ROCK
	rock.set_shader_parameter("rock_color",ROCK_COLOR)
	stage.add_mesh(hills.commit(),rock).name="AuthoredDistantFoothills"

static func _plant(stage: Node, key: String, at: Vector2, size: float, yaw: float, index: int) -> Node3D:
	var root: Node3D = stage.asset_instance(key)
	Life.prepare_materials(root)
	stage.world_root.add_child(root)
	root.position=Vector3(at.x,height_at(at.x,at.y)-.018,at.y)
	root.scale=Vector3.ONE*size
	root.rotation.y=yaw
	root.set_meta("stable_id","3dworld:teaching:%s:%03d" % [key,index])
	var activity: String = "巨柱仙人掌 · 静态外部形态参考" if key=="saguaro" else "三齿拉瑞阿 · 细枝与成对小叶" if key=="creosote_bush" else "Ocotillo · 多根带刺茎与花序形态参考" if key=="ocotillo" else "Brittlebush · 灰白叶丛与静态黄花形态" if key=="brittlebush" else "绒毛牧豆树 · 冠层、成对小叶与荚果参考"
	root.set_meta("activity",activity)
	return root

static func _brittlebush(stage: Node) -> void:
	# Distinct foliage and composite heads within the existing authored habitat;
	# flowering is a morphology sample, not a date or rain response.
	var places: Array[Vector2] = [Vector2(8,5),Vector2(-10,2),Vector2(14,-17),Vector2(-17,-14),Vector2(32,-35),Vector2(-36,-30),Vector2(43,-64),Vector2(-47,-60)]
	var sizes: Array[float] = [1.12,.96,1.05,.87,.94,1.08,.91,1.0]
	var hero: Node3D
	for i: int in range(places.size()):
		var plant: Node3D = _plant(stage,"brittlebush",places[i],sizes[i],float(i)*1.37,i)
		plant.name = "Brittlebush%d" % i
		if i==0: hero=plant
	stage.set_meta("desert_brittlebush",hero)
	stage.set_meta("desert_brittlebush_count",places.size())
	var role: String = "Brittlebush（Encelia farinosa）。多枝圆丘状灌木，灰白绒毛叶集中枝端，黄色头状花序高出叶冠。这里显示一株静态开花形态；八株位置、枝叶与花头数量是作者设计，不由观察日期或降雨推断物候，也不模拟传粉、结实或生长。"
	var targets: Array = stage.get_meta("desert_targets")
	targets.append({"node":hero,"label":"Brittlebush · 整株叶冠与花头","role":role,"source_url":BRITTLEBUSH_SOURCE,"distance":2.8,"focus_height":.5,"view_offset":Vector3(1.4,.85,2.2)})
	for anchor_name: String in ["BrittlebushLeafAnchor","BrittlebushFlowerAnchor"]:
		var anchor: Node3D = hero.find_child(anchor_name,true,false) as Node3D
		if anchor==null:
			push_error("Brittlebush GLB missing " + anchor_name)
			continue
		var observer: Node3D = Node3D.new()
		observer.name = anchor_name+"Observer"
		stage.world_root.add_child(observer)
		observer.position = anchor.global_position
		observer.set_meta("reference_root",hero)
		var is_flower: bool = anchor_name=="BrittlebushFlowerAnchor"
		observer.set_meta("stable_id","3dworld:teaching:brittlebush:"+("flower" if is_flower else "leaf"))
		observer.set_meta("activity","同株黄色头状花序 · 静态开花形态" if is_flower else "同株灰白绒毛叶 · 表面质感简化")
		targets.append({"node":observer,"label":"Brittlebush · 黄色花头" if is_flower else "Brittlebush · 灰白叶片","role":role,"source_url":BRITTLEBUSH_ECOLOGY_SOURCE,"distance":.26 if is_flower else .30,"min_distance":.05,"view_offset":Vector3(.11,.12,.20)})
	stage.set_meta("desert_targets",targets)

static func _ocotillo(stage: Node) -> void:
	# Sparse authored composition on the existing lowland terrain; flowering is
	# a morphology sample, not a world-date or rainfall-driven phenology claim.
	var places: Array[Vector2] = [Vector2(-13,7),Vector2(31,-34),Vector2(-46,-47),Vector2(52,-73),Vector2(-70,-67),Vector2(25,-69)]
	var sizes: Array[float] = [1.0,.88,1.09,.82,.96,.91]
	var hero: Node3D
	for i: int in range(places.size()):
		var plant: Node3D = _plant(stage,"ocotillo",places[i],sizes[i],float(i)*1.41,i)
		plant.name = "Ocotillo%d" % i
		if i==0: hero=plant
	stage.set_meta("desert_ocotillo",hero)
	stage.set_meta("desert_ocotillo_count",places.size())
	var role: String = "Ocotillo（Fouquieria splendens）。基部长出多根上举带刺茎，红色管状花集中于梢端；旱期可落叶，雨后可重新生叶。本模型只展示带花形态，不按当前日期推断实际花期或降雨。株数、茎刺花数量与位置为作者设计；不模拟生长、传粉或水分过程。"
	var targets: Array = stage.get_meta("desert_targets")
	targets.append({"node":hero,"label":"Ocotillo · 整株与多茎","role":role,"source_url":OCOTILLO_SOURCE,"distance":7.0,"focus_height":1.8,"view_offset":Vector3(4.3,2.2,6.0)})
	for detail: String in ["OcotilloSpineAnchor","OcotilloFlowerAnchor"]:
		var anchor: Node3D = hero.find_child(detail,true,false) as Node3D
		if anchor==null:
			push_error("Ocotillo GLB missing " + detail)
			continue
		var point: Node3D = Node3D.new()
		point.name = detail+"Observer"
		stage.world_root.add_child(point)
		point.position = anchor.global_position
		point.set_meta("reference_root",hero)
		var is_flower: bool = detail=="OcotilloFlowerAnchor"
		point.set_meta("stable_id","3dworld:teaching:ocotillo:"+("flower" if is_flower else "spine"))
		point.set_meta("activity","同株梢端管状花序 · 静态开花形态" if is_flower else "同株茎刺 · 旱期近看形态")
		targets.append({"node":point,"label":"Ocotillo · 梢端红花" if is_flower else "Ocotillo · 茎刺近看","role":role,"source_url":OCOTILLO_SOURCE,"distance":.62 if is_flower else .75,"min_distance":.12 if is_flower else .09,"view_offset":Vector3(.28,.21,.54) if is_flower else Vector3(.28,.17,.68)})
	stage.set_meta("desert_targets",targets)

static func _mesquite(stage: Node) -> void:
	var places: Array[Vector2]=[Vector2(15,-18),Vector2(9,-51),Vector2(19,-82),Vector2(2,-98)]
	var sizes: Array[float]=[1.0,.86,1.13,.77]
	var hero: Node3D
	for i: int in range(places.size()):
		var tree: Node3D=_plant(stage,"velvet_mesquite",places[i],sizes[i],float(i)*1.73,i)
		tree.name="VelvetMesquite%d" % i
		if i==0: hero=tree
	stage.set_meta("desert_mesquite",hero)
	stage.set_meta("desert_mesquite_count",places.size())
	var role: String="绒毛牧豆树Prosopis velutina。分枝冠层提供局部树荫，细小成对小叶和弯曲荚果可近看；荚果可成为动物食物并参与种子传播。这里的沟缘位置、株高与数量是作者布局，未模拟地下水、开花结荚季节、动物取食或传播。"
	var targets: Array=stage.get_meta("desert_targets")
	targets.append({"node":hero,"label":"绒毛牧豆树 · 整株与树荫","role":role,"source_url":MESQUITE_SOURCE,"distance":9.0,"focus_height":2.7,"view_offset":Vector3(5,2.5,7.0)})
	for name: String in ["CompoundLeafAnchor","SeedPodAnchor"]:
		var anchor: Node3D=hero.find_child(name,true,false) as Node3D
		if anchor==null: continue
		var point: Node3D=Node3D.new()
		point.name="Mesquite"+name+"Observer"
		stage.world_root.add_child(point)
		point.position=anchor.global_position
		point.set_meta("reference_root",hero)
		point.set_meta("activity","同株复叶近看 · 每条叶轴18对小叶为作者参考" if name=="CompoundLeafAnchor" else "同株荚果近看 · 未模拟成熟或种子传播")
		targets.append({"node":point,"label":"绒毛牧豆树 · 成对小叶" if name=="CompoundLeafAnchor" else "绒毛牧豆树 · 弯曲荚果","role":role,"source_url":MESQUITE_SOURCE,"distance":1.0 if name=="CompoundLeafAnchor" else 1.2,"min_distance":.20,"view_offset":Vector3(.30,.75,.55) if name=="CompoundLeafAnchor" else Vector3(.40,.85,.80)})
	stage.set_meta("desert_targets",targets)

static func _plants(stage: Node) -> void:
	var cactus: Node3D = _plant(stage,"saguaro",Vector2(-3,-2),1.0,0.0,0)
	var shrub: Node3D = _plant(stage,"creosote_bush",Vector2(3,3),1.0,0.0,0)
	stage.set_meta("desert_cactus",cactus)
	stage.set_meta("desert_shrub",shrub)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed=11532
	var cactus_places: Array[Vector2] = [Vector2(-18,-18),Vector2(22,-27),Vector2(-31,8),Vector2(39,-55),Vector2(-56,-48),Vector2(14,-81),Vector2(-20,-97),Vector2(72,-29)]
	for i: int in range(cactus_places.size()): _plant(stage,"saguaro",cactus_places[i],rng.randf_range(.58,1.19),rng.randf()*TAU,i+1)
	var count: int = 1
	while count<64:
		var at: Vector2 = Vector2(rng.randf_range(-90,90),rng.randf_range(-110,35))
		if at.distance_to(Vector2(-3,-2))<5 or at.distance_to(Vector2(3,3))<4: continue
		if absf(at.x-8.0-3.0*sin(at.y*.055))<3.8: continue
		_plant(stage,"creosote_bush",at,rng.randf_range(.72,1.50),rng.randf()*TAU,count)
		count+=1
	var cactus_role: String = "巨柱仙人掌Carnegiea gigantea。肉质茎外侧褶皱可随储水伸缩；刺从刺座伸出。内部木质支撑肋未剖开显示，不能把表面棱脊直接当作木骨架；臂数不用于估算年龄。当前为静态作者参考。"
	var shrub_role: String = "三齿拉瑞阿Larrea tridentata。多枝灌木，叶由基部相连的两枚小叶构成。这里可观察同株细枝与毫米级小叶；不模拟树脂气味、降雨响应或生长。"
	var targets: Array[Dictionary] = [
		{"node":cactus,"label":"巨柱仙人掌 · 整株","role":cactus_role,"source_url":CACTUS_SOURCE,"distance":11.0,"focus_height":2.8,"view_offset":Vector3(4,2.4,10)},
		{"node":shrub,"label":"三齿拉瑞阿 · 整株","role":shrub_role,"source_url":SHRUB_SOURCE,"distance":3.0,"focus_height":.68,"view_offset":Vector3(1.2,1.0,2.5)}]
	for is_leaf: bool in [false,true]:
		var root: Node3D = shrub if is_leaf else cactus
		var anchor: Node3D = root.find_child("PairedLeafletsAnchor" if is_leaf else "AreoleAnchor",true,false) as Node3D
		var point: Node3D = Node3D.new()
		stage.world_root.add_child(point)
		point.position=anchor.global_position
		point.set_meta("reference_root",root)
		point.set_meta("activity","同株成对小叶 · 镜头靠近，模型保持原尺寸" if is_leaf else "外部棱脊与刺座 · 未模拟储水变化")
		targets.append({"node":point,"label":"三齿拉瑞阿 · 成对小叶" if is_leaf else "巨柱仙人掌 · 棱脊与刺座","role":shrub_role if is_leaf else cactus_role,"source_url":SHRUB_SOURCE if is_leaf else CACTUS_SOURCE,"distance":.06 if is_leaf else .42,"min_distance":.025 if is_leaf else .13,"view_offset":Vector3(.020,.043,.048) if is_leaf else Vector3(.17,.11,.40)})
	stage.set_meta("desert_targets",targets)

static func _rocks(stage: Node) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed=11507
	var material: StandardMaterial3D = Forms.material(Color(.32,.235,.15))
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius=1.0;mesh.height=2.0;mesh.radial_segments=7;mesh.rings=3
	for i: int in range(220):
		var at: Vector2 = Vector2(rng.randf_range(-90,90),rng.randf_range(-110,40))
		if at.distance_to(Vector2(-3,-2))<1.0 or at.distance_to(Vector2(3,3))<1.1: continue
		var size: float = rng.randf_range(.10,.52) if i>15 else rng.randf_range(.7,1.7)
		var node: MeshInstance3D = stage.add_mesh(mesh,material,Vector3(at.x,height_at(at.x,at.y)+size*.17,at.y))
		node.scale=Vector3(size,size*.55,size*.8)
		node.rotation=Vector3(rng.randf()*.5,rng.randf()*TAU,.12)

static func _wash_gravel(stage: Node) -> void:
	# One low-poly batch follows the existing authored dry wash. This is a
	# visible sand/gravel morphology cue, never a measured sediment deposit.
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius=1.0
	mesh.height=2.0
	mesh.radial_segments=6
	mesh.rings=3
	var material: StandardMaterial3D = Forms.material(Color(.34,.27,.19),.96)
	mesh.material=material
	var gravel: MultiMesh = MultiMesh.new()
	gravel.transform_format=MultiMesh.TRANSFORM_3D
	gravel.mesh=mesh
	gravel.instance_count=300
	var rng: RandomNumberGenerator=RandomNumberGenerator.new()
	rng.seed=20432
	for i: int in range(gravel.instance_count):
		var z: float=rng.randf_range(-112.0,44.0)
		var center: float=8.0+3.0*sin(z*.055)
		var spread: float=5.7+1.5*sin(z*.073+1.7)
		var x: float=center+rng.randf_range(-spread,spread)
		var size: float=rng.randf_range(.08,.24)
		var surface: Dictionary=Terrain.surface_at(x,z)
		var basis: Basis=Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,size*.24,size*.68))
		gravel.set_instance_transform(i,Transform3D(basis,Vector3(x,float(surface.height)+size*.08,z)))
	var layer: MultiMeshInstance3D=MultiMeshInstance3D.new()
	layer.name="DryWashGravel"
	layer.multimesh=gravel
	layer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.world_root.add_child(layer)
	stage.set_meta("desert_wash_gravel_count",gravel.instance_count)

static func animate(stage: Node, time: float) -> void:
	Iguana.animate(stage,time)
	Rat.animate(stage,time)

static func update_camera(stage: Node) -> void:
	stage.camera.near=.06
	for item: Dictionary in stage.get_meta("desert_targets",[]):
		if item.has("min_distance") and stage.camera.position.distance_to(item.node.global_position)<.65: stage.camera.near=.0008

static func set_daylight(stage: Node, jd: float, enabled: bool) -> void:
	Land.set_daylight(stage,jd,enabled)
	Rat.set_daylight(stage,enabled)

static func entry_pose(stage: Node, _source: String) -> Dictionary:
	return {"position":stage.default_position*1.3,"target":stage.default_target}

static func exit_pose(stage: Node, _target: String) -> Dictionary:
	return {"position":stage.default_position*1.4,"target":stage.default_target}

static func marks(host: Node, topic: String) -> Array[Dictionary]:
	var stage: Node = host.coordinator.active_scene
	var root: Node3D = stage.get_meta("desert_shrub" if topic=="desert_leaf" else "desert_cactus")
	var anchor: Node3D = root.find_child("PairedLeafletsAnchor" if topic=="desert_leaf" else "AreoleAnchor",true,false) as Node3D
	return [{"at":anchor.global_position,"label":"两枚小叶 · 基部相连" if topic=="desert_leaf" else "刺座与刺 · 位于茎棱脊","offset":Vector2(70,-75)}]
