extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Two authored species references on the existing synthetic woodland riverbank.
## Motion samples the host world time; no independent ecology or hydrology state.
const Woodland = preload("res://scripts/experience/woodland_environment.gd")
const CATTAIL_SOURCE: String = "https://home.nps.gov/miss/learn/nature/cattails.htm"
const DARNER_SOURCE: String = "https://www.nps.gov/articles/000/common-green-darner.htm"
const DARNER_PERIOD_S: float = 18.0
const CATTAIL_Z: Array[float] = [8.7, 9.05, 9.45, 11.35, 11.75, 12.15, 14.05, 14.42, 14.95]
const CATTAIL_BANK_OFFSETS: Array[float] = [6.4, 6.85, 6.25, 6.7, 6.3, 6.95, 6.5, 6.9, 6.35]

static func darner_center() -> Vector3:
	return Vector3(Woodland.river_center(11.4)+5.4,Woodland.WATER_Y+.59,11.4)

static func darner_sample(time: float) -> Dictionary:
	var phase: float=TAU*fposmod(time,DARNER_PERIOD_S)/DARNER_PERIOD_S
	var position: Vector3=darner_center()+Vector3(.48*sin(phase),.045*sin(phase*2.0),1.2*cos(phase))
	var velocity: Vector3=Vector3(.48*cos(phase),.09*cos(phase*2.0),-1.2*sin(phase))
	return {"position":position,"heading":atan2(-velocity.z,velocity.x),"wing_phase":phase}

static func build(stage: Node) -> void:
	var plants: Array[Node3D] = []
	for i: int in range(CATTAIL_Z.size()):
		var z: float=CATTAIL_Z[i]
		var x: float=Woodland.river_center(z)+CATTAIL_BANK_OFFSETS[i]
		var node: Node3D=stage.assets.broadleaf_cattail.instantiate()
		node.name="BroadleafCattail%02d" % i
		node.position=Vector3(x,Woodland.height_at(x,z),z)
		node.rotation.y=.32*float(i%4)-.42
		node.scale=Vector3.ONE*(.87+.037*float(i%5))
		node.set_meta("stable_id","3dworld:teaching:broadleaf-cattail:%04d" % i)
		node.set_meta("activity",I18n.text("宽叶香蒲 · 河岸挺水植物（作者布置）"))
		stage.world_root.add_child(node)
		plants.append(node)
	var first: Node3D=plants[2]
	var female: Node3D=first.find_child("CattailFemaleSpikeAnchor",true,false) as Node3D
	var male: Node3D=first.find_child("CattailMaleSpikeAnchor",true,false) as Node3D
	assert(female!=null and male!=null)
	female.set_meta("stable_id","3dworld:teaching:broadleaf-cattail:spike")
	var darner: Node3D=stage.assets.common_green_darner.instantiate()
	darner.name="CommonGreenDarner"
	darner.set_meta("stable_id","3dworld:teaching:common-green-darner:0000")
	darner.set_meta("activity",I18n.text("绿纹蜻蜓 · 水边短程巡游（作者路线）"))
	stage.world_root.add_child(darner)
	var wings: Array[Node3D] = []
	for wing_name: String in ["ForeWingLPivot","ForeWingRPivot","HindWingLPivot","HindWingRPivot"]:
		var pivot: Node3D=darner.find_child(wing_name,true,false) as Node3D
		assert(pivot!=null)
		wings.append(pivot)
	var wing_anchor: Node3D=darner.find_child("DarnerWingAnchor",true,false) as Node3D
	assert(wing_anchor!=null)
	wing_anchor.set_meta("stable_id","3dworld:teaching:common-green-darner:wings")
	var overview: Node3D=Node3D.new()
	overview.name="RiverWetlandOverview"
	overview.position=Vector3(Woodland.river_center(10.5)+6.2,Woodland.WATER_Y+.72,10.5)
	overview.set_meta("stable_id","3dworld:teaching:river-wetland:overview")
	overview.set_meta("activity",I18n.text("缓水河岸 · 挺水植物、蜻蜓与牛蛙的空间对照"))
	stage.world_root.add_child(overview)
	stage.set_meta("river_wetland",{"plants":plants,"darner":darner,"wings":wings,"overview":overview})
	stage.set_meta("river_wetland_targets",[
		{"node":overview,"label":I18n.text("缓水河岸 · 香蒲、蜻蜓与牛蛙"),"role":I18n.text("同一合成河岸里比较挺水植物、空中成虫和岸边两栖动物。邻近展示不等于模拟种间捕食、繁殖或完整湿地。"),"source_url":CATTAIL_SOURCE,"distance":12.0,"view_offset":Vector3(7.1,3.8,8.9)},
		{"node":first,"label":I18n.text("宽叶香蒲 · Typha latifolia"),"role":I18n.text("泥滩与浅水中的挺水植物；宽带状叶与高于叶丛的花穗可对照。九株位置、高度和花期均为作者设置。"),"source_url":CATTAIL_SOURCE,"distance":3.0,"focus_height":.84,"view_offset":Vector3(1.9,1.25,2.5)},
		{"node":female,"label":I18n.text("香蒲花穗 · 下方雌穗与上方雄穗"),"role":I18n.text("两个部分彼此相邻；下方棕色柱状雌穗，上方较窄雄穗。模型不表示实际授粉或种子释放。"),"source_url":CATTAIL_SOURCE,"distance":.51,"view_offset":Vector3(.26,.20,.43)},
		{"node":darner,"label":I18n.text("绿纹蜻蜓 · Anax junius"),"role":I18n.text("成年雄性参考：绿色胸部、大复眼、蓝色腹部与四翅。短程巡游是作者路线，不表示实测飞行。"),"source_url":DARNER_SOURCE,"distance":.31,"min_distance":.18,"view_offset":Vector3(.14,.13,.25)},
		{"node":wing_anchor,"label":I18n.text("绿纹蜻蜓 · 四翅近看"),"role":I18n.text("蜻蜓有两对翅；翅脉与薄膜由原创几何简化。真实量级模型未放大；未计算气动力或捕食。"),"source_url":DARNER_SOURCE,"distance":.25,"min_distance":.16,"view_offset":Vector3(.11,.15,.18)}])
	animate(stage,float(stage.world_snapshot.simulation_time_s))

static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("river_wetland"): return
	var data: Dictionary=stage.get_meta("river_wetland")
	var darner: Node3D=data.darner
	var sample: Dictionary=darner_sample(time)
	darner.position=sample.position
	darner.rotation.y=sample.heading
	var wing_phase: float=TAU*1.8*time
	for i: int in range(data.wings.size()):
		var wing: Node3D=data.wings[i]
		wing.rotation.x=(1.0 if i%2==0 else -1.0)*.13*sin(wing_phase+(.45 if i>=2 else 0.0))
	darner.set_meta("activity",I18n.text("绿纹蜻蜓 · 水边短程巡游（世界时间 %.1f s，作者路线）") % time)

static func readout(host: Node, topic: String) -> String:
	if topic=="river_wetland": return I18n.text("9株宽叶香蒲 · 1只绿纹蜻蜓 · 2只牛蛙\n另可切至水下看8尾同种金色鲦；均为作者布局，不表示自然种群或捕食。")
	if topic=="cattail": return I18n.text("宽叶香蒲 · 约1.77 m原创模型\n宽叶、下方棕色雌穗与相邻上方雄穗；未模拟授粉与散种。")
	return I18n.text("绿纹蜻蜓 · 约9.6 cm原创翅展\n四翅与绿色胸部、蓝色雄虫腹部；短程活动读取唯一世界时间。")

static func marks(host: Node, topic: String) -> Array[Dictionary]:
	var stage: Node=host.coordinator.active_scene
	if not stage.has_meta("river_wetland"): return []
	var data: Dictionary=stage.get_meta("river_wetland")
	if topic=="cattail":
		var plant: Node3D=data.plants[2]
		var blade: Node3D=plant.find_child("CattailLeafAnchor",true,false) as Node3D
		var female: Node3D=plant.find_child("CattailFemaleSpikeAnchor",true,false) as Node3D
		var male: Node3D=plant.find_child("CattailMaleSpikeAnchor",true,false) as Node3D
		return [{"at":blade.global_position,"label":I18n.text("宽带状叶"),"offset":Vector2(-155,55)},
			{"at":female.global_position,"label":I18n.text("下方雌穗"),"offset":Vector2(110,-65)},
			{"at":male.global_position,"label":I18n.text("上方雄穗"),"offset":Vector2(95,-95)}]
	if topic=="green_darner":
		var darner: Node3D=data.darner
		var thorax: Node3D=darner.find_child("DarnerThoraxAnchor",true,false) as Node3D
		var abdomen: Node3D=darner.find_child("DarnerAbdomenAnchor",true,false) as Node3D
		var wing: Node3D=darner.find_child("DarnerWingAnchor",true,false) as Node3D
		return [{"at":thorax.global_position,"label":I18n.text("绿色胸部"),"offset":Vector2(-125,-70)},
			{"at":abdomen.global_position,"label":I18n.text("蓝色雄虫腹部"),"offset":Vector2(-160,65)},
			{"at":wing.global_position,"label":I18n.text("两对翅"),"offset":Vector2(100,-65)}]
	return []
