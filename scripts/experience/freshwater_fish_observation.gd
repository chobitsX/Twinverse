extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## One authored freshwater reference in the existing woodland channel.
## The small group is an observable time-driven layout, not a population or flow solver.
const Woodland = preload("res://scripts/experience/woodland_environment.gd")
const LifeAssetMotion = preload("res://scripts/experience/life_asset_motion.gd")
const SOURCE: String = "https://www.nps.gov/keaq/learn/nature/fish.htm"
const HABITAT_SOURCE: String = "https://www.nps.gov/upde/learn/nature/nongame-fish-species.htm"
const PERIOD_S: float = 32.0
const OFFSETS: Array[Vector3] = [
	Vector3(-.44,-.04,.80),Vector3(-.21,.03,-.55),Vector3(.13,-.02,-.45),
	Vector3(.40,.02,-.32),Vector3(-.35,.02,.32),Vector3(-.06,-.04,.44),
	Vector3(.24,.04,.37),Vector3(.49,-.03,.50)]

static func center_sample(time: float) -> Dictionary:
	var phase: float=TAU*fposmod(time,PERIOD_S)/PERIOD_S
	var z: float=10.8+.035*cos(phase)
	var x: float=Woodland.river_center(z)+.55*sin(phase)
	var velocity: Vector3=Vector3(.55*cos(phase),0.,-.035*sin(phase))
	return {"position":Vector3(x,Woodland.WATER_Y-.36,z),"heading":atan2(-velocity.z,velocity.x),"phase":phase}

static func build(stage: Node) -> void:
	var fish: Array[Node3D]=[]
	var tails: Array[Node3D]=[]
	for i: int in range(OFFSETS.size()):
		var node: Node3D=stage.assets.golden_shiner.instantiate()
		LifeAssetMotion.prepare_materials(node)
		node.name="GoldenShiner%02d" % i
		node.set_meta("stable_id","3dworld:teaching:golden-shiner:%04d" % i)
		node.set_meta("activity",I18n.text("金色鲦 · 缓流水层中的作者小群"))
		stage.world_root.add_child(node)
		fish.append(node)
		var tail: Node3D=node.find_child("TailPivot",true,false) as Node3D
		assert(tail!=null)
		tails.append(tail)
	var eye: Node3D=fish[0].find_child("ShinerEyeAnchor",true,false) as Node3D
	var gill: Node3D=fish[0].find_child("ShinerGillAnchor",true,false) as Node3D
	var caudal: Node3D=fish[0].find_child("ShinerTailAnchor",true,false) as Node3D
	assert(eye!=null and gill!=null and caudal!=null)
	eye.set_meta("stable_id","3dworld:teaching:golden-shiner:eye")
	var school: Node3D=Node3D.new()
	school.name="FreshwaterSchoolCenter"
	school.set_meta("stable_id","3dworld:teaching:freshwater-school:overview")
	school.set_meta("activity",I18n.text("缓流河道的金色鲦小群 · 作者路线"))
	stage.world_root.add_child(school)
	stage.set_meta("freshwater_school",{"fish":fish,"tails":tails,"center":school,"eye":eye,"gill":gill,"caudal":caudal})
	stage.set_meta("freshwater_targets",[
		{"node":school,"label":I18n.text("淡水鱼群 · 缓流河道的水下层"),"role":I18n.text("八尾金色鲦参考在同一合成河道小群活动；水下视角用于看清真实量级鱼体，不是透明河流或实测群体密度。"),"source_url":HABITAT_SOURCE,"distance":2.6,"view_offset":Vector3(.20,.09,2.55)},
		{"node":fish[0],"label":I18n.text("金色鲦 · Notemigonus crysoleucas"),"role":I18n.text("深体形、小而上翘的口、橄榄背与银金侧面；原创约20厘米成鱼参考。路径与八尾数量是作者设置。"),"source_url":SOURCE,"distance":.55,"min_distance":.25,"view_offset":Vector3(.12,.05,.51),"view_from_subject_side":true,"view_side_sign":-1.0},
		{"node":eye,"label":I18n.text("金色鲦 · 眼、鳃盖与侧线"),"role":I18n.text("近看实际鱼体上的眼和鳃盖，侧线只作形态线索；不能从这个模型读取真实感知或呼吸速率。"),"source_url":SOURCE,"distance":.42,"min_distance":.22,"view_offset":Vector3(.08,.05,.39),"view_from_subject_side":true,"view_side_sign":-1.0}])
	animate(stage,float(stage.world_snapshot.simulation_time_s))

static func animate(stage: Node,time: float) -> void:
	if not stage.has_meta("freshwater_school"): return
	var data: Dictionary=stage.get_meta("freshwater_school")
	var sample: Dictionary=center_sample(time)
	var school: Node3D=data.center
	school.position=sample.position
	for i: int in range(data.fish.size()):
		var fish: Node3D=data.fish[i]
		var offset: Vector3=OFFSETS[i]
		var drift: Vector3=Vector3(.026*sin(time*.43+float(i)*1.7),.016*sin(time*.65+float(i)),.021*cos(time*.37+float(i)*1.3))
		fish.position=sample.position+offset+drift
		fish.rotation.y=sample.heading+.10*sin(time*.55+float(i)*.7)
		data.tails[i].rotation.y=.19*sin(time*4.3+float(i)*.8)
		fish.set_meta("activity",I18n.text("金色鲦 · 小群游动（世界时间 %.1f s，作者路线）") % time)

static func readout(host: Node, topic: String) -> String:
	if topic=="freshwater_school": return I18n.text("8尾金色鲦 · 同一条合成缓流河道\n水下视角揭示真实量级个体；不是种群密度或水流计算。")
	return I18n.text("金色鲦 · 约20厘米原创参考\n橄榄背、银金侧面、小而上翘的口；游动读取唯一世界时间。")

static func marks(host: Node,topic: String) -> Array[Dictionary]:
	if topic!="golden_shiner": return []
	var stage: Node=host.coordinator.active_scene
	if not stage.has_meta("freshwater_school"): return []
	var data: Dictionary=stage.get_meta("freshwater_school")
	return [{"at":data.eye.global_position,"label":I18n.text("眼与上翘的口"),"offset":Vector2(-78,-76)},
		{"at":data.gill.global_position,"label":I18n.text("鳃盖"),"offset":Vector2(105,28)},
		{"at":data.caudal.global_position,"label":I18n.text("叉形尾鳍"),"offset":Vector2(52,72)}]
