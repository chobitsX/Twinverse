extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const EcologySurface = preload("res://scripts/experience/ecology_surface_material.gd")
## Two planted young ginkgo references in the synthetic park.
## Leaf calendar is a bounded teaching illustration, not local phenology data.
const SOURCE: String = "https://plants.ces.ncsu.edu/plants/ginkgo-biloba/"
const GARDEN_SOURCE: String = "https://www.missouribotanicalgarden.org/PlantFinder/PlantFinderDetails.aspx?chr=15&isprofile=0&pt=14&taxonid=280988&z=6"
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const BASES: Array[Vector3] = [Vector3(39.0,.25,22.4),Vector3(42.5,.25,28.0)]
const AU_EPOCH_JD: float = 2440587.5

static func season(jd: float) -> String:
	var date: Dictionary = Time.get_date_dict_from_unix_time(int((jd-AU_EPOCH_JD)*86400.0))
	var month: int = int(date.month)
	var day: int = int(date.day)
	if month>=4 and month<=9: return "green"
	if month==10 or (month==11 and day<=15): return "gold"
	return "bare"

static func season_label(phase: String) -> String:
	match phase:
		"green": return I18n.text("教学日历 · 绿叶期")
		"gold": return I18n.text("教学日历 · 金叶期")
		_: return I18n.text("教学日历 · 落叶枝形")

static func _gold_material(mesh: MeshInstance3D, color: Color) -> Material:
	var original: StandardMaterial3D = mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert(original!=null)
	return EcologySurface.seasonal(original,color)


static func avoids_anonymous_tree(x: float, z: float) -> bool:
	for base: Vector3 in BASES:
		if Vector2(x,z).distance_to(Vector2(base.x,base.z))<5.0: return true
	return false

static func build(stage: Node) -> void:
	var trees: Array[Node3D] = []
	for index: int in range(BASES.size()):
		var tree: Node3D = stage.assets.city_ginkgo.instantiate()
		LifeMotion.prepare_materials(tree)
		tree.name = "CityGinkgo_%02d" % index
		tree.position = BASES[index]
		tree.rotation.y = -.18 if index==0 else .42
		tree.set_meta("stable_id","3dworld:teaching:city-ginkgo:%04d" % index)
		tree.set_meta("activity",I18n.text("银杏种植幼树参考 · 夏季绿叶"))
		var canopy: MeshInstance3D = tree.find_child("GinkgoFanCanopy",true,false) as MeshInstance3D
		var hero: MeshInstance3D = tree.find_child("ReferenceBilobedFanLeaf",true,false) as MeshInstance3D
		var veins: MeshInstance3D = tree.find_child("ReferenceDichotomousVeins",true,false) as MeshInstance3D
		assert(canopy!=null and hero!=null and veins!=null)
		tree.set_meta("ginkgo_leaf_parts",[canopy,hero,veins])
		tree.set_meta("ginkgo_gold_materials",[
			_gold_material(canopy,Color(.77,.55,.12)),
			_gold_material(hero,Color(.85,.64,.18)),
			_gold_material(veins,Color(.30,.21,.07))])
		stage.world_root.add_child(tree)
		trees.append(tree)
	stage.set_meta("city_ginkgos",trees)
	var first: Node3D = trees[0]
	var anchor: Node3D = first.find_child("FanLeafObservationAnchor",true,false) as Node3D
	var base: Node3D = first.find_child("FanLeafBaseAnchor",true,false) as Node3D
	var notch: Node3D = first.find_child("FanLeafNotchAnchor",true,false) as Node3D
	assert(anchor!=null and base!=null and notch!=null)
	var detail: Node3D = Node3D.new()
	detail.name = "CityGinkgoLeafDetail"
	stage.world_root.add_child(detail)
	detail.position = anchor.global_position
	detail.set_meta("plant_root",first)
	detail.set_meta("activity",I18n.text("银杏扇叶 · 观察二裂凹口和分叉叶脉"))
	detail.set_meta("plant_markers",[
		{"at":base.global_position,"label":I18n.text("叶柄连接处"),"offset":Vector2(-125,65)},
		{"at":notch.global_position,"label":I18n.text("扇叶二裂凹口"),"offset":Vector2(95,-55)}])
	stage.set_meta("city_ginkgo_targets",[
		{"node":first,"label":I18n.text("银杏 · Ginkgo biloba"),"role":I18n.text("同一公园里的原创种植幼树形态参考；扇形叶与树形可观察，位置、大小和叶数为作者设置。绿/金/落叶是简化教学日历，不是实地物候预报。"),"source_url":SOURCE,"distance":12.0,"focus_height":2.3,"view_offset":Vector3(5.2,3.6,10.5)},
		{"node":detail,"label":I18n.text("银杏 · 同株扇叶近看"),"role":I18n.text("有叶期比较叶柄、扇面凹口与分叉叶脉；落叶枝形期请切到夏季。叶宽和叶色是作者设置。"),"source_url":SOURCE,"distance":.38,"view_offset":Vector3(.06,.10,.32)}])

static func update(stage: Node, jd: float) -> void:
	if not stage.has_meta("city_ginkgos"): return
	var phase: String = season(jd)
	if stage.get_meta("city_ginkgo_phase","")==phase: return
	stage.set_meta("city_ginkgo_phase",phase)
	var leafy: bool = phase!="bare"
	for tree: Node3D in stage.get_meta("city_ginkgos",[]):
		var parts: Array = tree.get_meta("ginkgo_leaf_parts",[])
		var gold: Array = tree.get_meta("ginkgo_gold_materials",[])
		for index: int in range(parts.size()):
			var mesh: MeshInstance3D = parts[index] as MeshInstance3D
			mesh.visible = leafy
			mesh.set_surface_override_material(0,gold[index] if phase=="gold" else null)
		tree.set_meta("activity",I18n.text("银杏种植幼树参考 · ")+season_label(phase))
	var targets: Array = stage.get_meta("city_ginkgo_targets",[])
	if targets.size()>1:
		var detail: Node3D = targets[1].node
		detail.set_meta("activity",I18n.text("落叶期 · 请切至夏季观察同株扇叶") if not leafy else I18n.text("银杏扇叶 · ")+season_label(phase)+I18n.text(" · 观察分叉叶脉"))
