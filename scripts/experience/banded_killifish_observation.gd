extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## A second freshwater fish at the same authored woodland reach. All movement
## samples the host's existing world time; this is not a population or flow solver.
const Woodland = preload("res://scripts/experience/woodland_environment.gd")
const LifeAssetMotion = preload("res://scripts/experience/life_asset_motion.gd")
const SOURCE: String = "https://www.nps.gov/keaq/learn/nature/fish.htm"
const PERIOD_S: float = 22.0
const OFFSETS: Array[Vector3] = [
	Vector3(-.27,-.011,-.23),Vector3(-.10,.009,.08),Vector3(.07,-.016,-.13),
	Vector3(.24,.005,.17),Vector3(-.19,.016,.27),Vector3(.28,-.007,-.30)]

static func center_sample(time: float) -> Vector3:
	var phase: float=TAU*fposmod(time,PERIOD_S)/PERIOD_S
	var z: float=10.8+.14*sin(phase)
	return Vector3(Woodland.river_center(z)+1.36+.10*cos(phase),Woodland.WATER_Y-.12,z)

static func build(stage: Node) -> void:
	var fish: Array[Node3D]=[]
	var tails: Array[Node3D]=[]
	for i: int in range(OFFSETS.size()):
		var node: Node3D=stage.assets.banded_killifish.instantiate()
		LifeAssetMotion.prepare_materials(node)
		node.name="BandedKillifish%02d" % i
		node.set_meta("stable_id","3dworld:teaching:banded-killifish:%04d" % i)
		node.set_meta("activity",I18n.text("斑纹鳉 · 植被旁近水面作者小群"))
		stage.world_root.add_child(node)
		fish.append(node)
		var tail: Node3D=node.find_child("TailPivot",true,false) as Node3D
		assert(tail!=null)
		tails.append(tail)
	var eye: Node3D=fish[0].find_child("KillifishEyeAnchor",true,false) as Node3D
	var band: Node3D=fish[0].find_child("KillifishBandAnchor",true,false) as Node3D
	var caudal: Node3D=fish[0].find_child("KillifishTailAnchor",true,false) as Node3D
	assert(eye!=null and band!=null and caudal!=null)
	var shoal: Node3D=Node3D.new()
	shoal.name="BandedKillifishShoal"
	shoal.set_meta("stable_id","3dworld:teaching:banded-killifish:shoal")
	shoal.set_meta("activity",I18n.text("斑纹鳉 · 苦草旁浅水层作者小群"))
	stage.world_root.add_child(shoal)
	var comparison: Node3D=Node3D.new()
	comparison.name="TwoFreshwaterFishHabitats"
	comparison.position=Vector3(Woodland.river_center(10.8)+1.0,Woodland.WATER_Y-.27,10.8)
	comparison.set_meta("stable_id","3dworld:teaching:freshwater-habitats:comparison")
	comparison.set_meta("activity",I18n.text("同一河道 · 金色鲦与斑纹鳉的水层位置对照"))
	stage.world_root.add_child(comparison)
	stage.set_meta("banded_killifish",{"fish":fish,"tails":tails,"shoal":shoal,"comparison":comparison,"eye":eye,"band":band,"caudal":caudal})
	stage.set_meta("banded_killifish_targets",[
		{"node":comparison,"label":I18n.text("同一河道 · 两种淡水鱼与沉水植物"),"role":I18n.text("较深水层的金色鲦与近水面植被旁的斑纹鳉同框对照；都是参考模型和作者布局，不显示自然分布密度或植物导致的鱼类选择。"),"source_url":SOURCE,"distance":2.45,"view_offset":Vector3(0.,.05,2.45)},
		{"node":shoal,"label":I18n.text("斑纹鳉 · 植被边缘近水面小群"),"role":I18n.text("六尾同种斑纹鳉沿浅水层短程游动；NPS描述此物种常在植被旁缓流浅水近水面成群。数量与路线为作者设置。"),"source_url":SOURCE,"distance":1.2,"view_offset":Vector3(.15,-.06,1.18)},
		{"node":fish[0],"label":I18n.text("斑纹鳉 · Fundulus diaphanus"),"role":I18n.text("原创约11厘米形态参考：细长鱼体、浅腹、深色体侧横纹及鳍。近看实际模型，不是标本扫描。"),"source_url":SOURCE,"distance":.34,"min_distance":.18,"view_offset":Vector3(.08,.01,.32),"view_from_subject_side":true,"view_side_sign":-1.0}])
	animate(stage,float(stage.world_snapshot.simulation_time_s))

static func animate(stage: Node,time: float) -> void:
	if not stage.has_meta("banded_killifish"): return
	var data: Dictionary=stage.get_meta("banded_killifish")
	var center: Vector3=center_sample(time)
	var phase: float=TAU*fposmod(time,PERIOD_S)/PERIOD_S
	data.shoal.position=center
	for i: int in range(data.fish.size()):
		var fish: Node3D=data.fish[i]
		var drift: Vector3=Vector3(.011*sin(phase+float(i)),.005*sin(2.*phase+float(i)),.012*cos(phase+float(i)*1.3))
		fish.position=center+OFFSETS[i]+drift
		fish.rotation.y=.12*sin(2.*phase+float(i)*.8)
		data.tails[i].rotation.y=.17*sin(18.*phase+float(i)*.9)

static func readout(_host: Node,topic: String) -> String:
	if topic=="freshwater_habitats": return I18n.text("同一合成河道 · 2种淡水鱼、20处美洲苦草叶丛\n金色鲦在较深水层；斑纹鳉在植被旁近水面。位置是作者对照，非实测选择。")
	if topic=="banded_killifish_shoal": return I18n.text("6尾斑纹鳉 · 同种浅水小群\n靠近植被边缘、近水面；22秒路线读取唯一世界时间。")
	return I18n.text("斑纹鳉 · 原创约11厘米参考\n浅腹、细长鱼体和16条作者体侧横纹；NPS描述该物种常有10–20条横纹。")

static func marks(host: Node,topic: String) -> Array[Dictionary]:
	if topic!="banded_killifish": return []
	var stage: Node=host.coordinator.active_scene
	if not stage.has_meta("banded_killifish"): return []
	var data: Dictionary=stage.get_meta("banded_killifish")
	return [{"at":data.eye.global_position,"label":I18n.text("眼与口"),"offset":Vector2(-76,-72)},
		{"at":data.band.global_position,"label":I18n.text("体侧横纹"),"offset":Vector2(65,-40)},
		{"at":data.caudal.global_position,"label":I18n.text("尾鳍"),"offset":Vector2(63,62)}]
