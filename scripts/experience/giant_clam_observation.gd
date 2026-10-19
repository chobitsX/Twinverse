extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## One original static T. maxima reference on the existing reef floor.
const SOURCE: String = "https://lifg.australian.museum/Group.html?groupId=ZXlLbbF4&hierarchyId=PVWrQCLG"
const LIGHT_SOURCE: String = "https://www.fisheries.noaa.gov/endangered-species-conservation/frequently-asked-questions-proposed-rule-10-species-giant-clams"
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")


static func build(stage: Node) -> void:
	# Leave the large coral patch around (-2.57, -0.91) clear and keep the
	# reference on open sand near the standard reef approach.
	var x: float = .35
	var z: float = -.75
	var floor: float = stage.builder._terrain_height(stage,x,z)
	var root: Node3D = stage.assets.tridacna_maxima.instantiate()
	LifeMotion.prepare_materials(root)
	root.name = "TridacnaMaximaReference"
	root.position = Vector3(x,floor-.015,z)
	stage.world_root.add_child(root)
	root.set_meta("stable_id","3dworld:teaching:tridacna-maxima:0001")
	root.set_meta("activity",I18n.text("静态砗磲参考 · 壳的铰合侧朝下，外套膜朝向光"))
	var mantle: Node3D = root.find_child("MantleObservationAnchor",true,false) as Node3D
	var scutes: Node3D = root.find_child("ShellScuteObservationAnchor",true,false) as Node3D
	assert(mantle!=null and scutes!=null)
	# Observation targets live in stage coordinates, as follow_content uses
	# target.position. Imported child anchors remain attached for labels.
	var mantle_view: Node3D = Node3D.new()
	mantle_view.name="TridacnaMantleView"
	stage.world_root.add_child(mantle_view)
	mantle_view.position=mantle.global_position
	mantle_view.set_meta("stable_id","3dworld:teaching:tridacna-maxima:mantle")
	mantle_view.set_meta("clam_root",root)
	mantle_view.set_meta("activity",I18n.text("同一只砗磲的斑驳外套膜 · 朝向光的静态结构"))
	var scute_view: Node3D = Node3D.new()
	scute_view.name="TridacnaShellScuteView"
	stage.world_root.add_child(scute_view)
	scute_view.position=scutes.global_position
	scute_view.set_meta("stable_id","3dworld:teaching:tridacna-maxima:scutes")
	scute_view.set_meta("clam_root",root)
	scute_view.set_meta("activity",I18n.text("同一只砗磲的外壳密集鳞片 · 手工参考形态"))
	var role: String = I18n.text("砗磲 Tridacna maxima 是双壳类动物。两壳铰合侧向下，蓝绿褐斑驳外套膜向上受光；共生藻可提供营养。壳长29cm、外鳞片/色斑数量、个体位置和开度是作者参考设置；未计算实时光合、过滤、开合反应或种群。")
	stage.set_meta("clam_root",root)
	stage.set_meta("clam_targets",[
		{"node":root,"label":I18n.text("砗磲 · Tridacna maxima"),"role":role,"source_url":SOURCE,"distance":.60,"focus_height":.09,"view_offset":Vector3(.29,.17,.34)},
		{"node":scute_view,"label":I18n.text("砗磲 · 同一外壳的鳞片近看"),"role":role,"source_url":SOURCE,"distance":.22,"view_offset":Vector3(.13,.075,.15),"min_distance":.08},
		{"node":mantle_view,"label":I18n.text("砗磲 · 同一外套膜近看"),"role":role,"source_url":LIGHT_SOURCE,"distance":.24,"view_offset":Vector3(.14,.20,.13),"min_distance":.08}])
	I18n.set_meta_text(stage,"content_summary",{"parts":[I18n.meta_message(stage,"content_summary"),"\n砗磲提供双壳、密集外鳞片和向光外套膜近看；颜色和尺寸为原创参考，不是扫描标本或已模拟营养通量。"]})


static func marks(host: Node, close_mantle: bool) -> Array[Dictionary]:
	var stage: Node = host.coordinator.active_scene
	if not stage.has_meta("clam_root"): return []
	var root: Node3D = stage.get_meta("clam_root")
	var mantle: Node3D = root.find_child("MantleObservationAnchor",true,false) as Node3D
	var scutes: Node3D = root.find_child("ShellScuteObservationAnchor",true,false) as Node3D
	if close_mantle:
		return [{"at":mantle.global_position,"label":I18n.text("向光外套膜 · 共生藻所在组织"),"offset":Vector2(70,-75)},
			{"at":scutes.global_position,"label":I18n.text("下方双壳 · 不是珊瑚"),"offset":Vector2(-170,55)}]
	return [{"at":mantle.global_position,"label":I18n.text("斑驳外套膜"),"offset":Vector2(75,-85)},
		{"at":scutes.global_position,"label":I18n.text("密集外鳞片"),"offset":Vector2(-145,70)}]
