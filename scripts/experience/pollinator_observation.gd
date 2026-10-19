extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## A small flowering clearing, evaluated from the host time. No population model.
const Life = preload("res://scripts/experience/life_asset_motion.gd")
const SOURCE: String = "https://www.nps.gov/articles/monarch-butterfly.htm"
const PLANT_SOURCE: String = "https://plants.ces.ncsu.edu/plants/asclepias-syriaca/"
const URBAN_GARDEN_SOURCE: String = "https://www.fws.gov/initiative/pollinators/monarchs/gardeners"
const PERIOD: float = 40.0
const CITY_BED_CENTER: Vector3 = Vector3(25.0,.225,22.4)
const CITY_PLANT_POSITIONS: Array[Vector2] = [
	Vector2(23.3,21.5),Vector2(26.7,21.5),
	Vector2(23.3,23.3),Vector2(26.7,23.3)]

static func sample(time: float, index: int) -> Dictionary:
	var p: float = fposmod(time+index*8.3,PERIOD)
	var position: Vector3 = Vector3.ZERO
	var basis: Basis = Basis.IDENTITY
	var moving: float = smoothstep(10,12,p)*(1-smoothstep(36,38,p))
	var visiting: bool = p<9.0 or p>39.0
	var activity: String = I18n.text("访花 · 口器伸向花蜜") if visiting else I18n.text("合拢口器 · 展翼准备") if p<12 else I18n.text("飞行 · 返回同一花序") if p<36 else I18n.text("接近花序 · 收翼停留")
	if p>=12 and p<36:
		var u: float = smoothstep(0,1,(p-12)/24)
		var angle: float = TAU*u
		position = Vector3(.65*sin(angle),.35*pow(sin(PI*u),2),-.45*(1-cos(angle)))
		var tangent: Vector3 = Vector3(.65*TAU*cos(angle),.35*PI*sin(angle),-.45*TAU*sin(angle))
		var heading: float = atan2(-tangent.z,tangent.x)
		var pitch: float = atan2(tangent.y,Vector2(tangent.x,tangent.z).length())
		basis = Basis(Vector3.UP,heading)*Basis(Vector3.BACK,pitch)
	return {"position":position,"basis":basis,"moving":moving,"visiting":visiting,"phase":p,"activity":activity}

static func build(stage: Node) -> void:
	var plants: Array[Node3D] = []
	var anchors: Array[Node3D] = []
	# A sunlit herbaceous clearing, outside the existing deer and robin routes.
	var positions: Array[Vector2] = [Vector2(6,7),Vector2(7.6,7.3),Vector2(4.4,7.5),Vector2(6.6,9.1),Vector2(4.6,9.3),Vector2(8.6,8.7)]
	for index: int in range(positions.size()):
		var plant: Node3D = stage.assets.common_milkweed.instantiate()
		plant.name = "CommonMilkweed%02d" % index
		Life.prepare_materials(plant)
		var at: Vector2 = positions[index]
		plant.position = Vector3(at.x,stage.builder._height(at.x,at.y),at.y)
		stage.world_root.add_child(plant)
		plant.set_meta("activity",I18n.text("普通乳草 · 对生叶与夏季花序参考"))
		plants.append(plant)
		anchors.append(plant.find_child("NectarFlowerAnchor",true,false) as Node3D)
	var actors: Array[Dictionary] = []
	for index: int in range(4):
		actors.append(_actor(stage,index,anchors[index],"monarch"))
	stage.set_meta("pollinators",actors)
	stage.set_meta("milkweed_plants",plants)
	var targets: Array[Dictionary] = [
		{"node":actors[0].node,"label":I18n.text("帝王蝶 · Danaus plexippus"),"role":I18n.text("成虫吸食多种花的花蜜；幼虫取食乳草叶片。可切换幼虫主题比较叶片上的另一生命阶段。"),"source_url":SOURCE,"distance":.34,"focus_height":.004,"view_offset":Vector3(.12,.21,.27)},
		{"node":plants[0],"label":I18n.text("普通乳草 · Asclepias syriaca"),"role":I18n.text("开花草本参考：对生长圆叶与粉色伞形花序，提供花蜜，也是帝王蝶幼虫寄主；当前为固定花期。"),"source_url":PLANT_SOURCE,"distance":1.8,"focus_height":.54,"view_offset":Vector3(-.4,.6,-1.8)}]
	stage.set_meta("pollinator_targets",targets)

static func _actor(stage: Node, index: int, anchor: Node3D, prefix: String) -> Dictionary:
	var node: Node3D = stage.assets.monarch.instantiate()
	node.name = ("CityMonarch" if prefix=="city-monarch" else "Monarch")+"%02d" % index
	node.set_meta("stable_id","3dworld:teaching:%s:%04d" % [prefix,index])
	stage.world_root.add_child(node)
	var joints: Dictionary = {}
	for key: String in ["ForeWingL","ForeWingR","HindWingL","HindWingR","MiddleLegL","MiddleLegR","HindLegL","HindLegR","ProboscisCoiled","ProboscisExtended","ProboscisTip"]:
		joints[key] = node.find_child(key,true,false)
	var tip: Vector3 = node.to_local(joints.ProboscisTip.global_position)
	return {"node":node,"index":index,"joints":joints,"anchor":anchor,"tip":tip}

static func city_reserved(x: float, z: float) -> bool:
	return x>21.2 and x<28.8 and z>19.8 and z<25.0

static func _city_box(stage: Node, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	stage.world_root.add_child(node)

static func build_city(stage: Node) -> void:
	# One planted display strip within the existing park, outside paved walks.
	_city_box(stage,CITY_BED_CENTER,Vector3(6.4,.09,3.7),Color(.28,.22,.15))
	var edge: Color = Color(.58,.57,.49)
	for side: float in [-1.0,1.0]:
		_city_box(stage,CITY_BED_CENTER+Vector3(side*3.23,.06,0),Vector3(.13,.13,3.9),edge)
		_city_box(stage,CITY_BED_CENTER+Vector3(0,.06,side*1.88),Vector3(6.57,.13,.13),edge)
	var plants: Array[Node3D] = []
	var anchors: Array[Node3D] = []
	for index: int in range(CITY_PLANT_POSITIONS.size()):
		var plant: Node3D = stage.assets.common_milkweed.instantiate()
		plant.name = "CityCommonMilkweed%02d" % index
		Life.prepare_materials(plant)
		plant.position = Vector3(CITY_PLANT_POSITIONS[index].x,.27,CITY_PLANT_POSITIONS[index].y)
		plant.rotation.y = float(index)*1.73
		if index==0: plant.set_meta("stable_id","3dworld:teaching:city-milkweed:0000")
		plant.set_meta("activity",I18n.text("普通乳草 · 教学种植花序，静态花期"))
		stage.world_root.add_child(plant)
		if index==0:
			var leaf: Node3D = plant.find_child("MilkweedLeafAnchor",true,false) as Node3D
			var flower: Node3D = plant.find_child("NectarFlowerAnchor",true,false) as Node3D
			plant.set_meta("plant_markers",[
				{"at":leaf.global_position,"label":I18n.text("对生叶 · 幼虫寄主组织"),"offset":Vector2(-150,50)},
				{"at":flower.global_position,"label":I18n.text("花序 · 成虫花蜜资源"),"offset":Vector2(110,-65)}])
		plants.append(plant)
		anchors.append(plant.find_child("NectarFlowerAnchor",true,false) as Node3D)
	var actors: Array[Dictionary] = []
	for index: int in range(2):
		actors.append(_actor(stage,index,anchors[[1,3][index]],"city-monarch"))
	stage.set_meta("pollinators",actors)
	stage.set_meta("milkweed_plants",plants)
	stage.set_meta("city_pollinator_bed",CITY_BED_CENTER)
	stage.set_meta("pollinator_targets",[
		{"node":actors[0].node,"label":I18n.text("城市种植片区 · 帝王蝶成虫"),"role":I18n.text("原创北美物种参考，成虫可吸食花蜜；访花动作与个体数量是作者示意，不计算授粉、迁徙或城市种群。"),"source_url":SOURCE,"distance":1.0,"view_offset":Vector3(.6,.45,.8)},
		{"node":plants[0],"label":I18n.text("种植片区 · 普通乳草"),"role":I18n.text("普通乳草是帝王蝶幼虫的寄主，也能为成虫提供花蜜；此处是合成城市里的北美植物教学样本，并非光照坐标所指地点的本地种植推荐。"),"source_url":PLANT_SOURCE,"distance":2.1,"focus_height":.65,"view_offset":Vector3(-.9,.9,-1.7)}])

static func animate(stage: Node, time: float) -> void:
	for actor: Dictionary in stage.get_meta("pollinators",[]):
		var pose: Dictionary = sample(time,actor.index)
		var node: Node3D = actor.node
		var anchor: Node3D = actor.anchor
		var joints: Dictionary = actor.joints
		node.position = anchor.global_position-actor.tip+pose.position
		node.basis = pose.basis
		var wave: float = lerpf(1.15,.18+.64*sin((time+actor.index*.19)*21),pose.moving)
		for side: int in [-1,1]:
			var suffix: String = "L" if side>0 else "R"
			joints["ForeWing"+suffix].rotation.x = -side*wave
			joints["HindWing"+suffix].rotation.x = -side*(wave*.96)
			joints["MiddleLeg"+suffix].rotation.z = -.95*pose.moving
			joints["HindLeg"+suffix].rotation.z = -.95*pose.moving
		joints.ProboscisCoiled.visible = not pose.visiting
		joints.ProboscisExtended.visible = pose.visiting
		node.set_meta("activity",pose.activity)
		node.set_meta("flower_distance_m",joints.ProboscisTip.global_position.distance_to(anchor.global_position))

static func tracking_target(stage: Node) -> Vector3:
	var actor: Dictionary = stage.get_meta("pollinators")[0]
	return actor.node.position.lerp(actor.anchor.global_position,.5)

static func readout(host: Node) -> String:
	var actor: Dictionary = host.coordinator.active_scene.get_meta("pollinators")[0]
	return I18n.text("%s\n口器端点与花序参考点 %.2f m（场景尺度）") % [actor.node.get_meta("activity"),float(actor.node.get_meta("flower_distance_m",0))]

static func marks(host: Node) -> Array[Dictionary]:
	var actor: Dictionary = host.coordinator.active_scene.get_meta("pollinators")[0]
	var node: Node3D = actor.node
	var mesh: MeshInstance3D = node.find_child("ForeWingSurfaceL",true,false) as MeshInstance3D
	var flying: bool = float(node.get_meta("flower_distance_m",0.0))>.03
	var mouth: MeshInstance3D = actor.joints.ProboscisCoiled as MeshInstance3D
	return [
		{"at":mesh.to_global(mesh.get_aabb().get_center()),"label":I18n.text("帝王蝶 · 两对翅"),"offset":Vector2(-150,75) if flying else Vector2(-110,-70)},
		{"at":actor.joints.ProboscisTip.global_position if actor.joints.ProboscisExtended.visible else mouth.to_global(mouth.get_aabb().get_center()),"label":I18n.text("口器 · 吸食花蜜") if actor.joints.ProboscisExtended.visible else I18n.text("口器 · 飞行时收拢"),"offset":Vector2(85,125) if flying else Vector2(115,-45)},
		{"at":actor.anchor.global_position,"label":I18n.text("乳草花序 · 花蜜来源"),"offset":Vector2(65,70),"link":1}]
