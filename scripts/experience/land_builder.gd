extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const Deadwood = preload("res://scripts/experience/deadwood_observation.gd")
const Fungi = preload("res://scripts/experience/fungus_observation.gd")
const Frogs = preload("res://scripts/experience/frog_observation.gd")
const RiverWetland = preload("res://scripts/experience/river_wetland_observation.gd")
const FreshwaterFish = preload("res://scripts/experience/freshwater_fish_observation.gd")
const WildCelery = preload("res://scripts/experience/wild_celery_observation.gd")
const BandedKillifish = preload("res://scripts/experience/banded_killifish_observation.gd")
const Runoff = preload("res://scripts/experience/runoff_observation.gd")
const Browse = preload("res://scripts/experience/browse_observation.gd")
const DeerSkin = preload("res://scripts/experience/deer_skin_motion.gd")
const RedFox = preload("res://scripts/experience/red_fox.gd")
const BoxTurtle = preload("res://scripts/experience/box_turtle.gd")
## Representative educational biomes and synthetic city; not a surveyed real place.
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const GROUND = preload("res://shaders/landscape_surface.gdshader")
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const AvatarClothing = preload("res://shaders/avatar_clothing_268.gdshader")
const Robin = preload("res://scripts/experience/robin_motion.gd")
const Traffic = preload("res://scripts/core/city_traffic.gd")
const Crossing = preload("res://scripts/experience/city_crossing.gd")
const CityWalk = preload("res://scripts/experience/city_walk_path.gd")
const CityStreetWalk = preload("res://scripts/experience/city_street_walk_path.gd")
const CitySparrow = preload("res://scripts/experience/city_sparrow.gd")
const CityPondMallard = preload("res://scripts/experience/city_pond_mallard.gd")
const CityGinkgo = preload("res://scripts/experience/city_ginkgo.gd")
const CityParkTrees = preload("res://scripts/experience/city_park_trees.gd")
const Woodland = preload("res://scripts/experience/woodland_environment.gd")
const UrbanEnvironment = preload("res://scripts/experience/urban_environment.gd")
const CityParkGround = preload("res://scripts/experience/city_park_ground.gd")
const Sites = preload("res://scripts/data/earth_sites.gd")
const MonarchStages = preload("res://scripts/experience/monarch_life_stages.gd")
const Larva = preload("res://scripts/experience/monarch_larva_observation.gd")
const Pollinators = preload("res://scripts/experience/pollinator_observation.gd")
const Plants = preload("res://scripts/experience/plant_observation.gd")
const Urban = preload("res://scripts/experience/urban_detail.gd")

static func build(stage: Node) -> void:
	stage.semantic_size_m = 150.0
	stage.camera.near = 0.08
	stage.camera.far = 800.0
	stage.camera.fov = 48.0
	stage.environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.21,0.43,0.62)
	sky_mat.sky_horizon_color = Color(0.78,0.82,0.76)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.2,0.25,0.19)
	sky.sky_material = sky_mat
	stage.environment.sky = sky
	stage.environment.ambient_light_color = Color(0.76,0.84,0.94)
	stage.environment.ambient_light_energy = 0.55
	stage.environment.ssao_enabled = true
	stage.environment.ssao_radius = 2.0
	stage.environment.ssao_intensity = 1.1
	stage.environment.fog_enabled = true
	stage.environment.fog_density = 0.0007
	# Keep the sky gradient visible; distance haze still applies to the district.
	stage.environment.fog_sky_affect = .18
	stage.environment.fog_light_color = Color(0.69,0.78,0.75)
	stage.environment.glow_enabled = true
	stage.environment.glow_intensity = 0.10
	var sun: DirectionalLight3D = stage.add_sun(Vector3(-35,-42,0),Color(1.0,0.88,0.68),1.55)
	# The city overview is about 100 m away; the generic 32 m range left it unshadowed.
	sun.directional_shadow_max_distance = 220.0 if stage.scale_id == "city" else 110.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	stage.set_meta("daylight_sun",sun)
	stage.set_meta("night_lamps",[])
	stage.set_meta("actors",[])
	if stage.scale_id == "woodland": _woodland(stage)
	else: _city(stage)
	animate(stage,float(stage.world_snapshot.simulation_time_s))

static func _surface(stage: Node, color: Color, water: bool = false) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GROUND
	mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("water",1.0 if water else 0.0)
	stage.materials.append(mat)
	return mat

static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	return Forms.mesh(parent,box,mat,pos)

static func _height(x: float, z: float) -> float:
	return Woodland.height_at(x,z)

static func _tree(stage: Node, at: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	# Reuse the fuller anonymous woodland crowns at the existing city tree sites.
	var key: String = "broadleaf_a" if rng.randf()<0.5 else "broadleaf_b"
	var tree: Node3D = stage.assets[key].instantiate()
	LifeMotion.prepare_materials(tree)
	tree.add_to_group("city_anonymous_canopy")
	tree.set_meta("canopy_variant",key)
	stage.world_root.add_child(tree)
	tree.position = at
	tree.scale = Vector3.ONE*height
	tree.rotation.y = rng.randf()*TAU

static func _woodland(stage: Node) -> void:
	stage.default_position = Vector3(15,6,19)
	stage.default_target = Vector3(0,1.8,-5)
	stage.target_position = Vector3(1,1.5,1)
	stage.close_position = Vector3(5,3,7)
	I18n.set_meta_text(stage,"scientific_label","陆地 · 林地与水边教学场景\n北美温带林缘意象：白尾鹿、赤狐、东部箱龟、阔叶乔木、草本、美洲知更鸟与美洲牛蛙。参考形态模型；合成布局与活动不代表实测种群。")
	stage.environment.fog_density = .00085
	stage.environment.fog_sky_affect = .18
	Woodland.build(stage)
	Plants.build(stage)
	Pollinators.build(stage)
	Larva.build(stage)
	MonarchStages.build(stage)
	Browse.build(stage)
	Frogs.build(stage)
	RiverWetland.build(stage)
	FreshwaterFish.build(stage)
	WildCelery.build(stage)
	BandedKillifish.build(stage)
	Fungi.build(stage)
	Deadwood.build(stage)
	RedFox.build(stage)
	BoxTurtle.build(stage)
	var actors: Array = stage.get_meta("actors")
	for k: int in range(8):
		var deer: Node3D = stage.assets.deer.instantiate()
		deer.scale = Vector3.ONE*(0.94+0.02*(k%4))
		LifeMotion.prepare(deer,"deer")
		deer.set_meta("stable_id","3dworld:teaching:doe:%04d" % k)
		stage.world_root.add_child(deer)
		actors.append({"node":deer,"kind":"deer","index":k,"label":"白尾鹿 · 缓行 / 取食 / 观察"})
	for k: int in range(12):
		var bird: Node3D = stage.assets.american_robin.instantiate()
		LifeMotion.prepare(bird,"bird")
		bird.set_meta("stable_id","3dworld:teaching:robin:%04d" % k)
		stage.world_root.add_child(bird)
		actors.append({"node":bird,"kind":"bird","index":k,"label":"美洲知更鸟 · Turdus migratorius", "source_url":"https://www.allaboutbirds.org/guide/American_Robin/id", "role":"地面取食无脊椎动物，也食果实；模型以成鸟为参考。"})
	I18n.set_meta_text(stage,"content_summary","8只白尾鹿 · 1只赤狐 · 1只东部箱龟 · 12只美洲知更鸟 · 4只成蝶、1只晚龄幼虫及叶背单卵/悬挂绿蛹、普通乳草花丛 · 2只美洲牛蛙 · 河岸9株宽叶香蒲与1只绿纹蜻蜓、河水中8尾金色鲦、6尾斑纹鳉与20处美洲苦草叶丛 · 1段枯木上的云芝参考\n北美白橡与东部白松幼树参考形态\n选择植物可近看株形，或直接观察北美白橡圆裂叶与东部白松五针一束。可从叶背卵到幼虫、悬挂蛹和成蝶比较同种不同阶段与食物。卵/蛹为固定三维参考；阶段切换不生成同一个体的发育，未模拟完整变态、蜕皮或叶片消耗。牛蛙可近看鼓膜、喉部与趾蹼；香蒲可看宽叶与相邻上下穗，蜻蜓可看四翅、绿色胸部和蓝色雄虫腹部；切至水下可比较较深的金色鲦、植被旁近水面的斑纹鳉与美洲苦草的基生莲座、带状叶和走茎。蜻蜓在缓水河岸的短程路线来自统一世界时间，未模拟水中幼体或捕食，两种淡水鱼的游动与苦草轻微摆动也只是作者演示，鱼—草同框不是因果模型。云芝是真菌，可看同一附木子实体的色带与底面孔口，菌丝主要隐在木内。旁边的局部枯木对照可切换水分条件并看碳去向，采用加速教学参数；未计算全林地分解或养分流。其余背景树、草本和蕨状地被仍未鉴种。\n东部箱龟是陆生杂食性爬行类，可近看高拱背甲、后足四趾与同一头部；14厘米背甲、短步路线/40秒节律为作者参考，腹甲铰链静态，不演示闭壳、冬眠、捕食或种群。赤狐可食小动物和植物；本场景的一只米制参考只沿作者路线缓行/停步，不计算捕猎，也未把已有鹿/鸟指定为猎物。白尾鹿以植物为食，林缘提供取食与遮蔽空间。生物数量与布局为教学表达；一只鹿接入成对样方的取食/恢复相对模型，其余活动为作者路线。河岸和浅水颜色来自合成地形的显示映射，不是测绘或水文模拟。未标定真实生长速度、种群或季节物候。")

static func _tint_person(root: Node, index: int) -> void:
	# Each instance owns its palette; imported meshes remain shared.
	var shirts: Array[Color]=[
		Color(0.24,0.43,0.44),Color(0.56,0.25,0.13),Color(0.70,0.62,0.40),
		Color(0.28,0.32,0.46),Color(0.36,0.41,0.20),Color(0.52,0.39,0.48),
		Color(0.17,0.36,0.57),Color(0.65,0.44,0.21),Color(0.33,0.49,0.34),
		Color(0.64,0.55,0.57),Color(0.25,0.48,0.47),Color(0.48,0.29,0.39),
		Color(0.71,0.66,0.52)]
	var trousers: Array[Color]=[
		Color(0.07,0.10,0.15),Color(0.16,0.21,0.28),Color(0.17,0.18,0.16),
		Color(0.25,0.20,0.16),Color(0.12,0.17,0.24),Color(0.27,0.27,0.24),
		Color(0.19,0.23,0.18)]
	var hair: Array[Color]=[
		Color(0.025,0.018,0.014),Color(0.10,0.057,0.034),Color(0.23,0.12,0.058),
		Color(0.36,0.25,0.11),Color(0.15,0.11,0.09),Color(0.35,0.34,0.30),
		Color(0.27,0.21,0.16)]
	var skin: Array[Color]=[
		Color(0.51,0.30,0.19),Color(0.72,0.48,0.32),Color(0.31,0.17,0.10),
		Color(0.60,0.37,0.23),Color(0.77,0.57,0.43),Color(0.42,0.24,0.15)]
	var shirt_color: Color=shirts[(index*7)%shirts.size()]
	var long_sleeves: bool=index%3==1
	_tint_person_node(root,shirt_color,trousers[(index*5)%trousers.size()],hair[(index*3)%hair.size()],skin[(index*5)%skin.size()],long_sleeves)

static func _tint_person_node(root: Node, shirt_color: Color, trousers_color: Color, hair_color: Color, skin_color: Color, long_sleeves: bool) -> void:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			for slot: int in range(child.mesh.get_surface_count()):
				var source: StandardMaterial3D = child.mesh.surface_get_material(slot) as StandardMaterial3D
				if source==null: continue
				if source.resource_name.begins_with("EcologyAvatar"):
					var garment: ShaderMaterial = ShaderMaterial.new()
					garment.shader = AvatarClothing
					garment.set_shader_parameter("color_map",source.albedo_texture)
					garment.set_shader_parameter("garment_color",shirt_color)
					garment.set_shader_parameter("female_style",source.resource_name.begins_with("EcologyAvatarFemale"))
					garment.set_shader_parameter("has_normal",source.normal_enabled and source.normal_texture!=null)
					if source.normal_texture!=null: garment.set_shader_parameter("normal_map",source.normal_texture)
					garment.set_shader_parameter("has_roughness",source.roughness_texture!=null)
					if source.roughness_texture!=null: garment.set_shader_parameter("roughness_map",source.roughness_texture)
					garment.set_shader_parameter("roughness_value",source.roughness)
					child.set_surface_override_material(slot,garment)
					continue
				var copy: StandardMaterial3D = source.duplicate() as StandardMaterial3D
				if source.resource_name in ["Cloth","ClothTrim"]:
					copy.vertex_color_use_as_albedo = false
					copy.albedo_color = shirt_color
					if source.resource_name=="ClothTrim": copy.albedo_color=copy.albedo_color.darkened(.18)
				elif source.resource_name=="Skin":
					copy.albedo_color = shirt_color if long_sleeves and child.name.begins_with("ContinuousArm") else skin_color
				elif source.resource_name=="Trousers":
					copy.albedo_color = trousers_color
				elif source.resource_name=="Hair":
					copy.albedo_color = hair_color
				child.set_surface_override_material(slot,copy)
		_tint_person_node(child,shirt_color,trousers_color,hair_color,skin_color,long_sleeves)

static func _city(stage: Node) -> void:
	stage.environment.tonemap_exposure = .82
	stage.default_position = Vector3(68,45,72)
	stage.default_target = Vector3(0,6,-7)
	stage.target_position = Vector3(8,1.6,8)
	stage.close_position = Vector3(17,6,19)
	I18n.set_meta_text(stage,"scientific_label","城市与人类 · 合成教学街区\n建筑/人口非现实映射；行人与车辆沿规则路径运行。十字路口分相通行是简化规则示意，不是实测交通流。")
	var ground: Material = _surface(stage,Color(0.49,0.49,0.42))
	var road: StandardMaterial3D = Forms.material(Color(0.085,0.11,0.125))
	var pavement: StandardMaterial3D = Forms.material(Color(0.62,0.62,0.53))
	var white: StandardMaterial3D = Forms.material(Color(0.88,0.86,0.70))
	_box(stage.world_root,Vector3(0,-0.3,0),Vector3(240,0.5,240),ground)
	for rotation: float in [0.0,PI/2.0]:
		var node: MeshInstance3D = _box(stage.world_root,Vector3(0,0,0),Vector3(240,0.04,12),road)
		node.rotation.y = rotation
		for side: float in [-1.0,1.0]:
			for section: float in [-1.0,1.0]:
				var west_corner: bool = is_zero_approx(rotation) and section<0
				node = _box(stage.world_root,Vector3(section*(66.6 if west_corner else 66.0),0.08,side*8).rotated(Vector3.UP,rotation),Vector3(106.8 if west_corner else 108.0,0.16,3.5),pavement)
				node.rotation.y = rotation
		for k: int in range(-29,30):
			if abs(k)<3: continue
			node = _box(stage.world_root,Vector3(k*4,0.035,0).rotated(Vector3.UP,rotation),Vector3(2,0.025,0.12),white)
			node.rotation.y = rotation
		for side: float in [-1.0,1.0]:
			for k: int in range(-5,6):
				node = _box(stage.world_root,Vector3(side*11.5,0.04,k*0.9).rotated(Vector3.UP,rotation),Vector3(2.8,0.03,0.4),white)
				node.rotation.y = rotation
	UrbanEnvironment.build(stage,road,pavement)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 84013
	var building_cache: Dictionary = {}
	var building_counts: Dictionary = {"shops":0,"homes":0,"offices":0}
	var shop_floor_counts: Dictionary = {2:0,3:0,4:0}
	var urban_targets: Array[Dictionary] = []
	for x: int in range(-3,4):
		for z: int in range(-3,4):
			if x==0 or z==0 or (x>0 and z>0): continue
			var category: int = 0 if z>0 else 2 if z<-1 and absi(x)<3 else 1
			var shop_variant: int = posmod(x+z,3)
			var key: String = ["shops_terracotta","residential_balconies","office_fins"][category]
			if category==0: key = ["shops_terracotta","shops_low","shops_midrise"][shop_variant]
			var building: Node3D = stage.assets[key].instantiate()
			building.name = "CityBuilding_%d_%d" % [x,z]
			building.position = Vector3(x*18,.16,z*18)
			building.rotation.y = float((x+z+6)%4)*PI/2
			stage.world_root.add_child(building)
			Urban.building_materials(stage,building,building_cache,category,posmod(x*5+z*3,5))
			Urban.cache_solar_geometry(building)
			if category==0:
				var floors: int = [3,2,4][shop_variant]
				building.set_meta("architecture_storeys",floors)
				shop_floor_counts[floors] += 1
			_box(stage.world_root,Vector3(x*18,.07,z*18),Vector3(16.2,.14,16.2),pavement)
			var category_name: String = ["shops","homes","offices"][category]
			building_counts[category_name] += 1
			if x==-1 and z==1:
				urban_targets.append({"node":building,"label":"临街商铺 · 檐棚与步行界面","role":"观察建筑入口、遮蔽与步行空间。布局为原创教学设计。","distance":32.0,"focus_height":5.0,"view_offset":Vector3(22,10,-22)})
			if x==1 and z==-1:
				urban_targets.append({"node":building,"label":"住宅 · 阳台与屋顶光伏","role":"屋顶光伏表示能源设施；尚未接入发电量或碳排放计算。","distance":26.0,"focus_height":13.0,"view_offset":Vector3(-12,12,13)})
	stage.set_meta("building_counts",building_counts)
	stage.set_meta("shop_floor_counts",shop_floor_counts)
	stage.set_meta("urban_targets",urban_targets)
	var grass: Material = CityParkGround.lawn_material(stage)
	_box(stage.world_root,Vector3(33,0.1,33),Vector3(44,0.2,44),grass)
	CityParkGround.build_cover(stage)
	_box(stage.world_root,Vector3(33,0.25,33),Vector3(4,0.2,43),pavement)
	_box(stage.world_root,Vector3(33,0.26,33),Vector3(43,0.2,4),pavement)
	_box(stage.world_root,Vector3(44,0.23,44),Vector3(12,0.1,10),_surface(stage,Color(0.07,0.26,0.3),true))
	for k: int in range(28):
		var x: float = rng.randf_range(14,53)
		var z: float = rng.randf_range(14,53)
		if absf(x-33)<4 or absf(z-33)<4 or absf(x-17)<2 or absf(x-49)<2 or absf(z-17)<2 or (x>37 and z>37) or Runoff.reserved(x,z) or CityGinkgo.avoids_anonymous_tree(x,z) or CityParkTrees.avoids_anonymous_tree(x,z) or Pollinators.city_reserved(x,z): continue
		_tree(stage,Vector3(x,0.25,z),rng.randf_range(4,6),rng)
	CityGinkgo.build(stage)
	CityParkTrees.build(stage)
	Pollinators.build_city(stage)
	CityPondMallard.build(stage)
	for k: int in range(-6,7):
		for side: float in [-1.0,1.0]:
			if abs(k)<2: continue
			_tree(stage,Vector3(k*10,0.17,side*9),4.5,rng)
	for x: float in [17.0,49.0]:
		_box(stage.world_root,Vector3(x,0.27,25),Vector3(2.2,0.2,18),pavement)
	_box(stage.world_root,Vector3(33,0.27,17),Vector3(34,0.2,2.2),pavement)
	_box(stage.world_root,Vector3(33,0.27,33),Vector3(34,0.2,2.2),pavement)
	var lamps: Array = stage.get_meta("night_lamps")
	for x: float in [-40.0,-20.0,20.0,40.0]:
		for z: float in [-9.0,9.0]:
			var at: Vector3 = Vector3(x,0.0,z)
			Forms.segment(stage.world_root,at,at+Vector3(0,5,0),0.06,road)
			var lamp: OmniLight3D = OmniLight3D.new()
			lamp.position = at+Vector3(0,4.8,0)
			lamp.omni_range = 12.0
			lamp.light_color = Color(1.0,0.77,0.42)
			lamp.light_energy = 0.0
			stage.world_root.add_child(lamp)
			var glow: StandardMaterial3D = Forms.material(Color(0.8,0.74,0.52))
			glow.emission_enabled = true
			Forms.ellipsoid(stage.world_root,lamp.position,Vector3(0.45,0.13,0.4),glow)
			lamps.append({"light":lamp,"material":glow})
	var signals: Array[Dictionary] = []
	for axis: int in range(2):
		var at: Vector3 = Vector3(-11,0,6).rotated(Vector3.UP,axis*PI/2)
		Forms.segment(stage.world_root,at,at+Vector3(0,4.0,0),0.085,road)
		_box(stage.world_root,at+Vector3(0,3.6,0),Vector3(0.4,1.2,0.35),road)
		var red: StandardMaterial3D = Forms.material(Color(0.5,0.02,0.01))
		red.emission_enabled = true
		var green: StandardMaterial3D = Forms.material(Color(0.02,0.6,0.20))
		green.emission_enabled = true
		Forms.ellipsoid(stage.world_root,at+Vector3(0,3.9,0.2),Vector3(0.25,0.25,0.15),red)
		Forms.ellipsoid(stage.world_root,at+Vector3(0,3.35,0.2),Vector3(0.25,0.25,0.15),green)
		signals.append({"axis":axis,"red":red,"green":green})
	stage.set_meta("signals",signals)
	Crossing.build(stage,pavement,road)
	var crossing_people: Array[Node3D] = []
	stage.set_meta("crossing_people",crossing_people)
	var actors: Array = stage.get_meta("actors")
	var person_forms: Array[String] = ["human_short","human_long"]
	for k: int in range(28):
		var person_key: String = person_forms[k%person_forms.size()]
		var person: Node3D = stage.assets[person_key].instantiate()
		LifeMotion.prepare(person,"person")
		person.set_meta("appearance_variant",person_key)
		_tint_person(person,k)
		var stature: float=[0.94,1.00,1.05,0.98,1.03,0.96,1.07][(k*5)%7]
		var build: float=[0.94,1.00,1.06,0.98,1.03][(k*3)%5]
		# Preserve forward stride length so the authored planted-foot motion stays put.
		person.scale=Vector3(1.0,stature,build)
		stage.world_root.add_child(person)
		actors.append({"node":person,"kind":"person","index":k,"label":"行人 · 步道行走 / 公园停留" if k<Traffic.PARK_PEOPLE else "行人 · 路缘等待 / 斑马线过街"})
		if k>=Traffic.PARK_PEOPLE:
			crossing_people.append(person)
			person.set_meta("stable_id","3dworld:teaching:crossing-person:%04d" % (k-Traffic.PARK_PEOPLE))
			if k==Traffic.PARK_PEOPLE:
				urban_targets.append({"node":person,"label":"过街行人 · 等待与行走","role":"合成人物；由统一世界时间决定的教学路线，没有行人决策或真实车流标定。","distance":4.5,"focus_height":.95,"view_offset":Vector3(2.0,2.5,4.0)})
	var street_walkers: Array[Node3D] = []
	var street_walker_targets: Array[Dictionary] = []
	for index: int in range(CityStreetWalk.COUNT):
		var appearance: int = index+28
		var street_person_key: String = person_forms[appearance%person_forms.size()]
		var street_person: Node3D = stage.assets[street_person_key].instantiate()
		street_person.name = "StreetWalker_%02d" % index
		LifeMotion.prepare(street_person,"person")
		street_person.set_meta("appearance_variant",street_person_key)
		street_person.set_meta("stable_id","3dworld:teaching:street-walker:%04d" % index)
		_tint_person(street_person,appearance)
		var stature: float = [0.94,1.00,1.05,0.98,1.03,0.96,1.07][(appearance*5)%7]
		var build: float = [0.94,1.00,1.06,0.98,1.03][(appearance*3)%5]
		street_person.scale = Vector3(1.0,stature,build)
		stage.world_root.add_child(street_person)
		street_walkers.append(street_person)
		street_walker_targets.append({"node":street_person,"label":I18n.format_text("街道人行道行人 %d",(index+1)),"label_message":{"format":"街道人行道行人 %d","args":index+1},"role":"同一位合成行人；外观、身形和人行道路线为作者设置，不代表现实人口或个人身份。","distance":4.0,"min_distance":1.35,"focus_height":.95,"view_offset_local":Vector3(3.4,1.2,.8)})
	stage.set_meta("street_walkers",street_walkers)
	stage.set_meta("street_walker_targets",street_walker_targets)
	Runoff.build(stage)
	CitySparrow.build(stage)
	Urban.furniture(stage)
	Urban.park_lights(stage,road)
	for k: int in range(12):
		var car: Node3D = stage.assets["compact_sedan" if k%2==0 else "compact_wagon"].instantiate()
		Urban.prepare_car(car,k)
		stage.world_root.add_child(car)
		actors.append({"node":car,"kind":"car","index":k,"label":"车辆 · 分相通行 / 停车等待"})
	I18n.set_meta_text(stage,"content_summary","近景27栋商铺/住宅/办公楼 · 34位合成行人 · 12辆原创车辆 · 公园里4只欧亚树麻雀、2只帝王蝶/4株普通乳草种植样本，以及池塘里同种绿头鸭雌雄各1只、岸边3株香蒲；周边为简化街区背景\n观察主题：临街入口、阳台、屋顶能源设施、道路和绿地；可选择建筑、公园小鸟、种植片区和池塘雌雄近看。树麻雀警觉、帝王蝶访花和绿头鸭游动/低头均为作者教学活动，不是实测行为频率或种群。普通乳草与香蒲复用已有原创物种模型；具体栽植、两只绿头鸭和光照坐标均不表示真实地址、当地原生性或现实生境建议。银杏、红枫和东部紫荆幼树及叶/花可近看；季节外观读取统一观察日期，具体月界为教学日历。\n车辆在交叉口前等待，在各自通行时段通过；26位行人在公园两条步道环路活动，2位在西侧斑马线等待/过街，另6位沿两侧连续人行道往返。默认48秒分相；24秒步行方案同步延长清空、周期为56秒。用时、通行窗口和速度为作者规则；街道路线也没有人群决策、碰撞避让或真实人口密度，不是现实交通指导。\n雨水与地表主题：两块9m²剖面台比较入渗、暂存、径流与深排水；作者参数，不是城市洪水预测。")

static func update_camera(stage: Node) -> void:
	# Only a camera close to the real attached cap needs millimetre clipping.
	stage.camera.near = .08
	var targets: Array = stage.get_meta("fungus_targets",[])
	for i: int in range(1,targets.size()):
		if stage.camera.position.distance_to(targets[i].node.position)<.35:
			stage.camera.near = .001
			break
	stage.camera.near=minf(stage.camera.near,MonarchStages.near_clip(stage))
	stage.camera.near=minf(stage.camera.near,BoxTurtle.near_clip(stage))

static func animate(stage: Node, time: float) -> void:
	var traffic_state: Dictionary=stage.world_snapshot.get("city_traffic",{})
	var traffic_time: float=float(traffic_state.get("elapsed_s",time))
	var walk_duration: float=float(traffic_state.get("walk_duration_s",Traffic.WALK_DURATION))
	Deadwood.animate(stage)
	Frogs.animate(stage,time)
	RiverWetland.animate(stage,time)
	FreshwaterFish.animate(stage,time)
	WildCelery.animate(stage,time)
	BandedKillifish.animate(stage,time)
	RedFox.animate(stage,time)
	BoxTurtle.animate(stage,time)
	Pollinators.animate(stage,time)
	Larva.animate(stage,time)
	Browse.animate(stage)
	Runoff.animate(stage,time)
	if stage.scale_id=="city":
		Crossing.update(stage,traffic_time,walk_duration)
	for signal_data: Dictionary in stage.get_meta("signals",[]):
		var green_on: bool = Traffic.vehicle_green(traffic_time,int(signal_data.axis),walk_duration)
		signal_data.green.albedo_color = Color(.025,.40,.09) if green_on else Color(.006,.025,.01)
		signal_data.red.albedo_color = Color(.018,.004,.003) if green_on else Color(.42,.015,.003)
		signal_data.green.emission = Color(0.05,1.0,0.25) if green_on else Color.BLACK
		signal_data.red.emission = Color.BLACK if green_on else Color(1.0,0.025,0.005)
	for actor: Dictionary in stage.get_meta("actors",[]):
		var node: Node3D = actor.node
		var k: int = actor.index
		match str(actor.kind):
			"deer":
				var pose: Dictionary = Browse.deer_pose(stage.world_snapshot.get("woodland_browse",{})) if k==7 else DeerSkin.sample(time,k)
				var p: Vector3 = pose.position
				p.y = _height(p.x,p.z)+.006
				node.position = p
				node.rotation.y = pose.heading
				DeerSkin.pose(node,time,pose.moving,pose.grazing,pose.step_phase)
				node.set_meta("activity",pose.activity)
				node.set_meta("grazing",pose.grazing)
			"bird":
				var pose: Dictionary = Robin.sample(time,k)
				var p: Vector3 = pose.position
				p.y += _height(p.x,p.z)+(.003 if node.has_meta("robin_skin") else .008)
				node.position = p
				node.basis = Robin.body_basis(pose)
				LifeMotion.bird(node,time+k*.11,pose.wings,pose.inspect,pose.walking,pose.tuck,pose.step_phase,stage.builder)
				node.set_meta("activity",pose.activity)
				node.set_meta("height_above_ground_m",pose.height)
			"person":
				if k>=Traffic.PARK_PEOPLE:
					var crossing_pose: Dictionary = Traffic.pedestrian(traffic_time,k-Traffic.PARK_PEOPLE,walk_duration)
					node.position = crossing_pose.position+Vector3(0,LifeMotion.person_root_offset(crossing_pose.moving),0)
					node.rotation.y = crossing_pose.heading
					LifeMotion.person(node,time,crossing_pose.moving,float(k)*.21,crossing_pose.travel)
					node.set_meta("activity",crossing_pose.activity)
					continue
				var pose: Dictionary = CityWalk.itinerary(time,k,Traffic.PARK_PEOPLE)
				var moving: float = pose.moving
				node.position = pose.position+Vector3(0,LifeMotion.person_root_offset(moving),0)
				node.rotation.y = pose.heading
				LifeMotion.person(node,time,moving,float(k)*0.21,pose.travel)
				node.set_meta("activity","步道行走" if moving>0 else "停留 · 观察公园绿地")
			"car":
				var vehicle_pose: Dictionary = Traffic.vehicle(traffic_time,k,walk_duration)
				node.visible = vehicle_pose.visible
				node.position = vehicle_pose.position
				node.rotation.y = vehicle_pose.heading
				for wheel: Node3D in node.get_meta("wheels",[]): wheel.rotation.z = -vehicle_pose.distance/.315
				node.set_meta("activity",vehicle_pose.activity)
	if stage.scale_id=="city":
		var street_walkers: Array = stage.get_meta("street_walkers",[])
		for index: int in range(street_walkers.size()):
			var person: Node3D = street_walkers[index]
			var street_pose: Dictionary = CityStreetWalk.sample(time,index)
			person.position = street_pose.position+Vector3(0,LifeMotion.person_root_offset(street_pose.moving),0)
			person.rotation.y = street_pose.heading
			LifeMotion.person(person,time,street_pose.moving,float(index+28)*.21,street_pose.travel)
			person.set_meta("activity",street_pose.activity)
		CitySparrow.animate(stage,time)
		CityPondMallard.animate(stage,time)

static func entry_pose(stage: Node, _source: String) -> Dictionary:
	return {"position":stage.default_position*1.4,"target":stage.default_target}

static func exit_pose(stage: Node, _target: String) -> Dictionary:
	return {"position":stage.default_position*1.5,"target":stage.default_target}


static func set_daylight(stage: Node, jd: float, enabled: bool) -> void:
	if not stage.has_meta("daylight_sun"): return
	if stage.scale_id=="city":
		CityGinkgo.update(stage,jd)
		CityParkTrees.update(stage,jd)
	# Identical sky uniforms dirty the radiance map too. The authored daylight
	# is constant; date-driven light still updates for every distinct world date.
	var daylight_key: Array = [enabled, jd if enabled else 0.0, stage.materials.size()]
	if stage.get_meta("applied_land_daylight", []) == daylight_key: return
	stage.set_meta("applied_land_daylight", daylight_key)
	var sun: DirectionalLight3D = stage.get_meta("daylight_sun")
	var site: Dictionary = Sites.for_scale(stage.scale_id)
	var direction: Vector3 = Orientation.local_sun(jd,site.lat,site.lon) if enabled else Vector3(0.5,0.72,0.48).normalized()
	# Teaching coordinates: woodland 35N/75W, synthetic city 35N/120E.
	sun.look_at_from_position(direction*100.0,Vector3.ZERO,Vector3.FORWARD if absf(direction.y)>0.99 else Vector3.UP)
	var day: float = smoothstep(-0.12,0.15,direction.y)
	var night: float = 1.0-day
	sun.light_energy = maxf(0.0,direction.y)*1.9
	sun.light_color = Color(1.0,0.5,0.26).lerp(Color(1.0,0.94,0.80),smoothstep(0.0,0.45,direction.y))
	stage.environment.ambient_light_energy = lerpf(0.08,0.55,day)
	var day_fog: Color = Color(0.55,0.65,0.68) if stage.scale_id=="city" else Color(0.69,0.78,0.75)
	stage.environment.fog_light_color = Color(0.02,0.035,0.065).lerp(day_fog,day)
	var sky: ProceduralSkyMaterial = stage.environment.sky.sky_material
	sky.sky_top_color = Color(0.002,0.005,0.014).lerp(Color(0.21,0.43,0.62),day)
	sky.sky_horizon_color = Color(0.025,0.035,0.06).lerp(Color(0.78,0.82,0.76),day)
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = Color(0.008,0.012,0.018).lerp(Color(0.2,0.25,0.19),day)
	for material: ShaderMaterial in stage.materials: material.set_shader_parameter("night_amount",night)
	for lamp: Dictionary in stage.get_meta("night_lamps",[]):
		lamp.light.light_energy = night*2.4
		lamp.material.emission = Color(1.0,0.67,0.30)*night*2.0
	stage.set_meta("sun_elevation",rad_to_deg(asin(direction.y)))
