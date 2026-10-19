extends RefCounted
## One original black sea cucumber reference on the existing reef sand.
const SOURCE: String = "https://lifg.australian.museum/Group.html?groupId=7UQOQa5x"
const FEEDING_SOURCE: String = "https://museum.wa.gov.au/online-collections/names/Holothuria-Halodeima-atra"
const RESEARCH_SOURCE: String = "https://doi.org/10.1071/MF9820255"
const ACTIVITY_SOURCE: String = "https://pmc.ncbi.nlm.nih.gov/articles/PMC9454777/"
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const Activity = preload("res://scripts/experience/sea_cucumber_activity.gd")


static func build(stage: Node) -> void:
	var x: float = 1.13
	var z: float = -.43
	var floor: float = stage.builder._terrain_height(stage,x,z)
	var root: Node3D = stage.assets.holothuria_atra.instantiate()
	LifeMotion.prepare_materials(root)
	root.name = "HolothuriaAtraReference"
	root.position = Vector3(x,floor-.002,z)
	root.rotation.y = -.38
	stage.world_root.add_child(root)
	Activity.prepare(root)
	root.set_meta("stable_id","3dworld:teaching:holothuria-atra:0001")
	root.set_meta("activity","礁坪砂底固定个体 · 摄食触手伸收示意")
	var feeding: Node3D = root.find_child("FeedingEndObservationAnchor",true,false) as Node3D
	var body: Node3D = root.find_child("BodyObservationAnchor",true,false) as Node3D
	assert(feeding!=null and body!=null)
	var feeding_view: Node3D = Node3D.new()
	feeding_view.name="HolothuriaFeedingEndView"
	stage.world_root.add_child(feeding_view)
	feeding_view.position=feeding.global_position
	feeding_view.set_meta("stable_id","3dworld:teaching:holothuria-atra:feeding-end")
	feeding_view.set_meta("holothuria_root",root)
	feeding_view.set_meta("activity","同一只海参的黑色摄食端与短触手 · 世界秒动作示意")
	var role: String = "黑海参 Holothuria atra 是棘皮动物中的海参，礁坪浅水个体常有薄砂覆盖和成列露出的黑色皮肤。它以沉积物中有机成分为食；本个体长约21厘米、露肤斑纹与位置为原创参考，没有实测沉积物处理量、营养循环、活动率或种群密度。"
	stage.set_meta("holothuria_root",root)
	stage.set_meta("holothuria_targets",[
		{"node":root,"label":"黑海参 · Holothuria atra","role":role,"source_url":SOURCE,"distance":.56,"focus_height":.035,"view_offset":Vector3(.19,.15,.30),"min_distance":.10},
		{"node":feeding_view,"label":"黑海参 · 同一只个体的摄食端近看","role":role,"source_url":FEEDING_SOURCE,"distance":.21,"view_offset":Vector3(.12,.085,.14),"min_distance":.07}])
	stage.set_meta("content_summary",str(stage.get_meta("content_summary"))+"\n黑海参提供砂覆与双列露肤、作者触手伸收和摄食端近看；动作与水层教学资源不是沉积物收支模型。")


static func marks(host: Node, close_feeding: bool) -> Array[Dictionary]:
	var stage: Node = host.coordinator.active_scene
	if not stage.has_meta("holothuria_root"): return []
	var root: Node3D = stage.get_meta("holothuria_root")
	var feeding: Node3D = root.find_child("FeedingEndObservationAnchor",true,false) as Node3D
	var body: Node3D = root.find_child("BodyObservationAnchor",true,false) as Node3D
	if close_feeding:
		var tip: MeshInstance3D = root.find_child("FeedingTip00",true,false) as MeshInstance3D
		return [{"at":tip.to_global(tip.get_aabb().get_center()),"label":"触手伸收 · 作者动作","offset":Vector2(65,-65)},
			{"at":body.global_position,"label":"同一只个体的柔软体壁","offset":Vector2(-160,55)}]
	return [{"at":body.global_position,"label":"薄砂覆体与双列露肤","offset":Vector2(-150,-72)},
		{"at":feeding.global_position,"label":"前端摄食触手","offset":Vector2(70,45)}]
