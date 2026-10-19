extends RefCounted
const EcologySurface = preload("res://scripts/experience/ecology_surface_material.gd")
## Two authored young species references in the existing synthetic city park.
## Seasonal appearances sample the host astronomical date, not a second clock.
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const SOURCE_MAPLE: String = "https://plants.ces.ncsu.edu/plants/acer-rubrum/"
const SOURCE_REDBUD: String = "https://plants.ces.ncsu.edu/plants/cercis-canadensis/"
const AU_EPOCH_JD: float = 2440587.5
const MAPLE_BASE: Vector3 = Vector3(15.0,.25,42.0)
const REDBUD_BASE: Vector3 = Vector3(15.5,.25,49.5)

static func phase(jd: float) -> String:
	var date: Dictionary = Time.get_date_dict_from_unix_time(int((jd-AU_EPOCH_JD)*86400.0))
	var month: int = int(date.month)
	var day: int = int(date.day)
	if month==3 or (month==4 and day<=20): return "spring"
	if month>=4 and month<=9: return "summer"
	if month==10 or (month==11 and day<=15): return "autumn"
	return "winter"

static func phase_label(value: String) -> String:
	match value:
		"spring": return "教学日历 · 紫荆先花后叶"
		"summer": return "教学日历 · 两种绿叶"
		"autumn": return "教学日历 · 枫红与紫荆黄叶"
		_: return "教学日历 · 冬季枝形"

static func avoids_anonymous_tree(x: float,z: float) -> bool:
	return Vector2(x,z).distance_to(Vector2(MAPLE_BASE.x,MAPLE_BASE.z))<4.4 or Vector2(x,z).distance_to(Vector2(REDBUD_BASE.x,REDBUD_BASE.z))<4.2

static func _color_material(mesh: MeshInstance3D,color: Color) -> Material:
	var original: StandardMaterial3D = mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert(original!=null)
	return EcologySurface.seasonal(original,color)


static func _target(node: Node3D,label: String,role: String,source: String,distance: float,offset: Vector3) -> Dictionary:
	return {"node":node,"label":label,"role":role,"source_url":source,"distance":distance,"view_offset":offset}

static func _detail(stage: Node, name: String, anchor: Node3D, plant: Node3D, stable_id: String, markers: Array) -> Node3D:
	# Observation uses node.position in world_root coordinates, so imported child
	# anchors must be projected to a world-root target before camera framing.
	var detail: Node3D = Node3D.new()
	detail.name = name
	stage.world_root.add_child(detail)
	detail.position = anchor.global_position
	detail.set_meta("stable_id",stable_id)
	detail.set_meta("plant_root",plant)
	detail.set_meta("plant_markers",markers)
	return detail

static func build(stage: Node) -> void:
	var maple: Node3D = stage.assets.red_maple.instantiate()
	var redbud: Node3D = stage.assets.eastern_redbud.instantiate()
	for tree: Node3D in [maple,redbud]:
		LifeMotion.prepare_materials(tree)
		stage.world_root.add_child(tree)
	maple.name = "CityRedMaple"
	maple.position = MAPLE_BASE
	maple.rotation.y = -.32
	maple.set_meta("stable_id","3dworld:teaching:city-red-maple:0000")
	redbud.name = "CityEasternRedbud"
	redbud.position = REDBUD_BASE
	redbud.rotation.y = .40
	redbud.set_meta("stable_id","3dworld:teaching:city-eastern-redbud:0000")
	var maple_canopy: MeshInstance3D = maple.find_child("MapleLeafCanopy",true,false) as MeshInstance3D
	var maple_hero: MeshInstance3D = maple.find_child("ReferenceMapleLobedLeaf",true,false) as MeshInstance3D
	var redbud_canopy: MeshInstance3D = redbud.find_child("RedbudLeafCanopy",true,false) as MeshInstance3D
	var redbud_hero: MeshInstance3D = redbud.find_child("ReferenceRedbudHeartLeaf",true,false) as MeshInstance3D
	var redbud_blooms: MeshInstance3D = redbud.find_child("RedbudFlowerClusters",true,false) as MeshInstance3D
	var redbud_flower: MeshInstance3D = redbud.find_child("ReferenceRedbudFlower",true,false) as MeshInstance3D
	assert(maple_canopy!=null and maple_hero!=null and redbud_canopy!=null and redbud_hero!=null and redbud_blooms!=null and redbud_flower!=null)
	stage.set_meta("city_park_trees",{
		"maple":maple,"redbud":redbud,
		"maple_leaves":[maple_canopy,maple_hero],
		"redbud_leaves":[redbud_canopy,redbud_hero],
		"redbud_flowers":[redbud_blooms,redbud_flower],
		"maple_autumn":[_color_material(maple_canopy,Color(.74,.18,.09)),_color_material(maple_hero,Color(.80,.22,.10))],
		"redbud_autumn":[_color_material(redbud_canopy,Color(.70,.52,.14)),_color_material(redbud_hero,Color(.78,.61,.20))]})
	var maple_leaf: Node3D = maple.find_child("MapleLeafObservationAnchor",true,false) as Node3D
	var maple_base: Node3D = maple.find_child("MapleLeafBaseAnchor",true,false) as Node3D
	var maple_tip: Node3D = maple.find_child("MapleLeafTipAnchor",true,false) as Node3D
	var redbud_leaf: Node3D = redbud.find_child("RedbudLeafObservationAnchor",true,false) as Node3D
	var redbud_base: Node3D = redbud.find_child("RedbudLeafBaseAnchor",true,false) as Node3D
	var redbud_tip: Node3D = redbud.find_child("RedbudHeartTipAnchor",true,false) as Node3D
	var bloom: Node3D = redbud.find_child("RedbudFlowerAnchor",true,false) as Node3D
	assert(maple_leaf!=null and maple_base!=null and maple_tip!=null and redbud_leaf!=null and redbud_base!=null and redbud_tip!=null and bloom!=null)
	var maple_detail: Node3D = _detail(stage,"CityMapleLeafDetail",maple_leaf,maple,"3dworld:teaching:city-red-maple:leaf",[
		{"at":maple_base.global_position,"label":"对生叶柄","offset":Vector2(-130,60)},
		{"at":maple_tip.global_position,"label":"掌状主裂片","offset":Vector2(100,-60)}])
	var redbud_detail: Node3D = _detail(stage,"CityRedbudLeafDetail",redbud_leaf,redbud,"3dworld:teaching:city-eastern-redbud:leaf",[
		{"at":redbud_base.global_position,"label":"心形叶基","offset":Vector2(-130,60)},
		{"at":redbud_tip.global_position,"label":"心形叶尖","offset":Vector2(100,-60)}])
	var flower_detail: Node3D = _detail(stage,"CityRedbudFlowerDetail",bloom,redbud,"3dworld:teaching:city-eastern-redbud:flower",[
		{"at":bloom.global_position,"label":"叶前粉紫花簇","offset":Vector2(100,-65)}])
	var overview: Node3D = Node3D.new()
	overview.name = "CityParkTreeOverview"
	overview.position = Vector3(15.25,1.9,45.75)
	overview.set_meta("stable_id","3dworld:teaching:city-park-trees:overview")
	overview.set_meta("activity","两种种植幼树 · 红枫与东部紫荆")
	stage.world_root.add_child(overview)
	stage.set_meta("city_park_tree_targets",[
		_target(overview,"城市公园 · 红枫与东部紫荆","比较同一公园两种种植树的叶形和作者季节外观；邻近不代表真实自然群落或物候观测。",SOURCE_MAPLE,12.0,Vector3(7.5,4.0,8.5)),
		_target(maple,"红枫 · Acer rubrum","原创幼树参考；对生掌状裂叶与秋季红色系可观察。尺寸、冠幅和株位为作者设置。",SOURCE_MAPLE,9.0,Vector3(5.0,3.3,7.5)),
		_target(maple_detail,"红枫 · 同株掌状裂叶","对生单叶有3–5主裂片与粗齿轮廓；示范叶是简化原创几何，不能单凭模型作野外鉴定。",SOURCE_MAPLE,.40,Vector3(.13,.13,.34)),
		_target(redbud,"东部紫荆 · Cercis canadensis","原创幼树参考；春季粉紫花先于心形叶出现，夏季可比较互生叶。花期日界是作者教学设置。",SOURCE_REDBUD,8.0,Vector3(4.8,3.1,7.2)),
		_target(flower_detail,"东部紫荆 · 叶前花近看","粉紫花簇在枝条上，早春叶片尚未展开；花形和数量为教学示意，没有传粉计算。",SOURCE_REDBUD,.33,Vector3(.12,.12,.27)),
		_target(redbud_detail,"东部紫荆 · 同株心形叶","夏季近看互生的心形全缘叶；冬季或早春枝形期可切换到夏季。",SOURCE_REDBUD,.40,Vector3(.12,.14,.33))])

static func update(stage: Node,jd: float) -> void:
	if not stage.has_meta("city_park_trees"): return
	var value: String = phase(jd)
	if stage.get_meta("city_park_tree_phase","")==value: return
	stage.set_meta("city_park_tree_phase",value)
	var data: Dictionary = stage.get_meta("city_park_trees")
	var maple_leafy: bool = value!="winter"
	var redbud_leafy: bool = value=="summer" or value=="autumn"
	var flowering: bool = value=="spring"
	for i: int in range(2):
		var maple_part: MeshInstance3D = data.maple_leaves[i]
		maple_part.visible = maple_leafy
		maple_part.set_surface_override_material(0,data.maple_autumn[i] if value=="autumn" else null)
		var redbud_part: MeshInstance3D = data.redbud_leaves[i]
		redbud_part.visible = redbud_leafy
		redbud_part.set_surface_override_material(0,data.redbud_autumn[i] if value=="autumn" else null)
		var flower_part: MeshInstance3D = data.redbud_flowers[i]
		flower_part.visible = flowering
	data.maple.set_meta("activity","红枫幼树参考 · "+phase_label(value))
	data.redbud.set_meta("activity","东部紫荆幼树参考 · "+phase_label(value))
	var targets: Array = stage.get_meta("city_park_tree_targets",[])
	if targets.size()==6:
		targets[2].node.set_meta("activity","红枫裂叶 · "+("冬季枝形，切至夏季观察" if not maple_leafy else phase_label(value)))
		targets[4].node.set_meta("activity","紫荆花 · "+("早春花期示意" if flowering else "切至春季观察"))
		targets[5].node.set_meta("activity","紫荆心形叶 · "+("切至夏季观察" if not redbud_leafy else phase_label(value)))
