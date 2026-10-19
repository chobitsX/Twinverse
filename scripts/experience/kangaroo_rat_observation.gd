extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## A visible authored seed-carrying route driven by the sole world time.
const Terrain = preload("res://scripts/experience/desert_terrain.gd")
const Life = preload("res://scripts/experience/life_asset_motion.gd")
const MotionSkin = preload("res://scripts/experience/ecology_motion_skin.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const SOURCE: String = "https://home.nps.gov/orpi/learn/nature/kangaroo-rat.htm"
const SPECIES_SOURCE: String = "https://www.nps.gov/tont/learn/nature/rodents.htm"
const ECOLOGY_SOURCE: String = "https://research.fs.usda.gov/feis/species-reviews/provel"
const Seeds = preload("res://scripts/core/desert_seed_transfer.gd")
const SEED_POINT: Vector2 = Vector2(15.75, -18.5)
const DEN_POINT: Vector2 = Vector2(17.35, -19.0)
const CYCLE_S: float = 24.0


static func sample(time: float, night: bool, resources: Dictionary = {}) -> Dictionary:
	if not night:
		var retained: bool=int(resources.get("pouch_units",0))>0
		return {"where":DEN_POINT,"facing":SEED_POINT-DEN_POINT,"moving":false,"carrying":retained,
			"activity":I18n.text("日间静态形态参考 · 颊囊教学单位待夜间续接") if retained else I18n.text("日间静态形态参考 · 夜间才示意采种")}
	if int(resources.get("ground_units",1))==0 and int(resources.get("pouch_units",0))==0:
		return {"where":DEN_POINT,"facing":SEED_POINT-DEN_POINT,"moving":false,"carrying":false,
			"activity":I18n.text("地表教学种子已搬完 · 洞穴缓存留存")}
	var cycle: float = fposmod(time,CYCLE_S)
	if cycle<3.0:
		return {"where":DEN_POINT.lerp(SEED_POINT,smoothstep(0.0,3.0,cycle)),
			"facing":SEED_POINT-DEN_POINT,"moving":true,"carrying":false,
			"activity":I18n.text("夜间出洞 · 接近落地牧豆树荚果")}
	if cycle<6.0:
		return {"where":SEED_POINT,"facing":DEN_POINT-SEED_POINT,"moving":false,"carrying":false,
			"activity":I18n.text("夜间取种 · 颊囊可储存种子")}
	if cycle<10.0:
		return {"where":SEED_POINT.lerp(DEN_POINT,smoothstep(6.0,10.0,cycle)),
			"facing":DEN_POINT-SEED_POINT,"moving":true,"carrying":int(resources.get("pouch_units",1))>0,
			"activity":I18n.text("颊囊携种回洞 · 循环路线为作者示意")}
	return {"where":DEN_POINT,"facing":SEED_POINT-DEN_POINT,"moving":false,"carrying":false,
		"activity":I18n.text("洞口停留 · 缓存计数是有限教学单位")}


static func _terrain_position(point: Vector2) -> Vector3:
	return Vector3(point.x,Terrain.height_at(point.x,point.y),point.y)


static func _ellipse(stage: Node, name: String, point: Vector2, radius: float, color: Color, height: float) -> MeshInstance3D:
	var mesh: CylinderMesh=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=24
	var node: MeshInstance3D=stage.add_mesh(mesh,Forms.material(color),_terrain_position(point)+Vector3(0,height*.5,0))
	node.name=name
	node.scale=Vector3(1.15,1.0,.85)
	return node


static func build(stage: Node) -> void:
	var root: Node3D=stage.asset_instance("merriams_kangaroo_rat")
	root.name="MerriamsKangarooRat"
	Life.prepare_materials(root)
	stage.world_root.add_child(root)
	MotionSkin.prepare(root)
	root.set_meta("stable_id","3dworld:teaching:merriams-kangaroo-rat:0000")
	stage.set_meta("kangaroo_rat",root)
	for key: String in ["HindLegPivotL","HindLegPivotR","HindShinL","HindShinR","ForepawPivotL","ForepawPivotR","TailPivot","FurLinedCheekPouchL","FurLinedCheekPouchR"]:
		if root.find_child(key,true,false)==null: push_error("Merriam kangaroo rat missing "+key)
	_ellipse(stage,"KangarooRatBurrowRim",DEN_POINT,.09,Color(.36,.27,.17),.016)
	var den: MeshInstance3D=_ellipse(stage,"KangarooRatBurrowOpening",DEN_POINT,.058,Color(.075,.052,.032),.007)
	den.position.y+=.010
	stage.set_meta("kangaroo_rat_den",den)
	var pod: CapsuleMesh=CapsuleMesh.new()
	pod.radius=.010
	pod.height=.16
	var fallen: MeshInstance3D=stage.add_mesh(pod,Forms.material(Color(.47,.34,.15)),_terrain_position(SEED_POINT)+Vector3(0,.014,0))
	fallen.name="FallenMesquitePod"
	fallen.rotation.z=PI*.5
	fallen.rotation.y=.35
	stage.set_meta("kangaroo_rat_pod",fallen)
	var seed_mesh: SphereMesh=SphereMesh.new()
	seed_mesh.radius=.012
	seed_mesh.height=.023
	seed_mesh.radial_segments=8
	seed_mesh.rings=4
	var seed_material: StandardMaterial3D=Forms.material(Color(.78,.60,.30))
	var ground_units: Array[MeshInstance3D]=[]
	var cache_units: Array[MeshInstance3D]=[]
	var cache_center: Vector2=DEN_POINT+Vector2(.27,.02)
	var cache_disc: MeshInstance3D=_ellipse(stage,"BurrowCacheCutaway",cache_center,.088,Color(.17,.13,.09),.010)
	stage.set_meta("kangaroo_rat_cache_display",cache_disc)
	for i: int in range(Seeds.INITIAL_UNITS):
		var ground_point: Vector2=SEED_POINT+Vector2(.09+float(i%4)*.035,-.027+float(i/4)*.055)
		var ground: MeshInstance3D=stage.add_mesh(seed_mesh,seed_material,_terrain_position(ground_point)+Vector3(0,.014,0))
		ground.name="GroundSeedUnit%d" % i
		ground_units.append(ground)
		var cache_point: Vector2=cache_center+Vector2(-.03+float(i%4)*.020,-.014+float(i/4)*.028)
		var cached: MeshInstance3D=stage.add_mesh(seed_mesh,seed_material,_terrain_position(cache_point)+Vector3(0,.024,0))
		cached.name="BurrowCacheUnit%d" % i
		cached.visible=false
		cache_units.append(cached)
	stage.set_meta("kangaroo_rat_ground_units",ground_units)
	stage.set_meta("kangaroo_rat_cache_units",cache_units)
	var lamp: OmniLight3D=OmniLight3D.new()
	lamp.name="KangarooRatObservationLight"
	lamp.position=_terrain_position((SEED_POINT+DEN_POINT)*.5)+Vector3(0,1.2,0)
	lamp.light_color=Color(.74,.80,1.0)
	lamp.light_energy=0.0
	lamp.omni_range=5.0
	lamp.shadow_enabled=false
	stage.world_root.add_child(lamp)
	stage.set_meta("kangaroo_rat_observation_light",lamp)
	stage.set_meta("kangaroo_rat_night",false)
	var role: String=I18n.text("梅氏袋鼠鼠Dipodomys merriami。大后足、长尾、小耳、大眼与颊囊是形态参考；NPS记录夜间采食牧豆树种子并在洞内贮藏，USFS记录袋鼠鼠可搬运并缓存牧豆树种子。此个体、洞口、落地荚果、24秒路线和8枚可见教学单位为作者设置；洞口旁圆盘是缓存剖面示意，不是露在地面的真实种子。白天仅静态展示，夜间提供辅助观察光，不代表月光、实测搬运率、真实取食或萌发。")
	var targets: Array=stage.get_meta("desert_targets",[])
	targets.append({"node":root,"label":I18n.text("梅氏袋鼠鼠 · 后足、长尾与颊囊"),"role":role,"source_url":SPECIES_SOURCE,"distance":.70,"min_distance":.16,"focus_height":.10,"view_offset":Vector3(.34,.27,.52)})
	var habitat: Node3D=Node3D.new()
	habitat.name="KangarooRatSeedRouteObserver"
	habitat.position=_terrain_position((SEED_POINT+DEN_POINT)*.5)
	stage.world_root.add_child(habitat)
	stage.set_meta("kangaroo_rat_route_observer",habitat)
	habitat.set_meta("activity",I18n.text("同株附近落地荚果、洞口与袋鼠鼠 · 夜间循环示意"))
	targets.append({"node":habitat,"label":I18n.text("梅氏袋鼠鼠 · 荚果与洞穴"),"role":role,"source_url":ECOLOGY_SOURCE,"distance":3.0,"focus_height":.22,"view_offset":Vector3(1.45,1.4,2.0)})
	stage.set_meta("desert_targets",targets)
	animate(stage,0.0)


static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("kangaroo_rat"): return
	var root: Node3D=stage.get_meta("kangaroo_rat")
	var resources: Dictionary=stage.world_snapshot.get("desert_seed_transfer",{})
	var route_time: float=float(resources.get("active_elapsed_s",time))
	var state: Dictionary=sample(route_time,bool(stage.get_meta("kangaroo_rat_night",false)),resources)
	var point: Vector2=state.where
	var position: Vector3=_terrain_position(point)
	var up: Vector3=Terrain.surface_at(point.x,point.y).normal
	var face: Vector2=state.facing.normalized()
	var forward: Vector3=Vector3(face.x,0,face.y).slide(up).normalized()
	var cycle: float=fposmod(route_time,CYCLE_S)
	if state.moving: position+=up*(.006+.012*pow(sin(cycle*TAU*1.4),2.0))
	root.transform=Transform3D(Basis(forward,up,forward.cross(up)),position)
	var kick: float=sin(cycle*TAU*1.4)*(.28 if state.moving else .025)
	for side: String in ["L","R"]:
		var hind: Node3D=root.find_child("HindLegPivot"+side,true,false) as Node3D
		var fore: Node3D=root.find_child("ForepawPivot"+side,true,false) as Node3D
		var cheek: Node3D=root.find_child("FurLinedCheekPouch"+side,true,false) as Node3D
		if hind!=null: hind.rotation.z=kick
		if fore!=null: fore.rotation.z=-kick*.45
		if cheek!=null: cheek.scale=Vector3.ONE*(1.18 if state.carrying else 1.0)
	var tail: Node3D=root.find_child("TailPivot",true,false) as Node3D
	if tail!=null:
		tail.rotation.y=sin(time*1.8)*(.20 if state.moving else .05)
		tail.rotation.z=sin(time*1.3)*(.10 if state.moving else .025)
	MotionSkin.apply(root)
	root.set_meta("activity",state.activity)
	root.set_meta("motion_sample",state)
	var ground_units: Array=stage.get_meta("kangaroo_rat_ground_units",[])
	var cache_units: Array=stage.get_meta("kangaroo_rat_cache_units",[])
	var show_cache_cutaway: bool=stage.camera.position.distance_to(root.position)>1.5
	stage.get_meta("kangaroo_rat_cache_display").visible=show_cache_cutaway
	for i: int in range(Seeds.INITIAL_UNITS):
		if i<ground_units.size(): ground_units[i].visible=i<int(resources.get("ground_units",Seeds.INITIAL_UNITS))
		if i<cache_units.size(): cache_units[i].visible=show_cache_cutaway and i<int(resources.get("cache_units",0))


static func set_daylight(stage: Node, enabled: bool) -> void:
	var night: bool=enabled and float(stage.get_meta("sun_elevation",45.0))<-6.0
	stage.set_meta("kangaroo_rat_night",night)
	var lamp: OmniLight3D=stage.get_meta("kangaroo_rat_observation_light")
	lamp.light_energy=1.8 if night else 0.0
