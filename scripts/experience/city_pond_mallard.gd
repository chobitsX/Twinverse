extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Two illustrative adults of one new species in the existing synthetic park pond.
## Positions and head dips sample the single world clock; no local timer or water state.
const Forms = preload("res://scripts/experience/life_forms.gd")
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const MotionSkin = preload("res://scripts/experience/ecology_motion_skin.gd")
const SOURCE: String = "https://www.allaboutbirds.org/guide/Mallard/id"
const BEHAVIOR_SOURCE: String = "https://www.allaboutbirds.org/guide/Mallard/lifehistory"
const CENTER: Vector3 = Vector3(44.0,0.28,44.0)
const PERIOD_S: float = 48.0
const WATER_MIN_X: float = 38.0
const WATER_MAX_X: float = 50.0
const WATER_MIN_Z: float = 39.0
const WATER_MAX_Z: float = 49.0

static func sample(time: float, index: int) -> Dictionary:
	var phase: float = TAU*time/PERIOD_S+PI*float(index)
	var position: Vector3 = Vector3(CENTER.x+2.8*cos(phase),
		0.12+0.007*sin(2.0*phase),CENTER.z+1.9*sin(phase))
	var velocity: Vector3 = Vector3(-2.8*sin(phase),0.0,1.9*cos(phase))
	var interval: float = fposmod(time+24.0*float(index),PERIOD_S)
	var dip: float = pow(sin(PI*clampf((interval-8.0)/6.0,0.0,1.0)),2.0) if interval>=8.0 and interval<=14.0 else 0.0
	return {"position":position,"heading":-atan2(velocity.z,velocity.x),
		"head_dip":dip,"activity":I18n.text("浅水探食姿态示意") if dip>0.25 else I18n.text("水面缓游")}

static func _rim(root: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = Forms.mesh(root,mesh,material,at)
	node.name = label

static func build(stage: Node) -> void:
	# A narrow, readable bank at the already-authored 12 x 10 m pond. It does
	# not change the water plane, world scale, hydrology or walkway layout.
	var bank: StandardMaterial3D = Forms.material(Color(0.29,0.28,0.235),0.96)
	_rim(stage.world_root,"PondBankSouth",Vector3(44.0,0.245,38.87),Vector3(12.9,0.13,0.55),bank)
	_rim(stage.world_root,"PondBankNorth",Vector3(44.0,0.245,49.13),Vector3(12.9,0.13,0.55),bank)
	_rim(stage.world_root,"PondBankWest",Vector3(37.87,0.245,44.0),Vector3(0.55,0.13,9.8),bank)
	_rim(stage.world_root,"PondBankEast",Vector3(50.13,0.245,44.0),Vector3(0.55,0.13,9.8),bank)
	var plants: Array[Node3D] = []
	var sites: Array[Vector3] = [Vector3(40.8,0.22,48.15),
		Vector3(43.0,0.22,48.35),Vector3(49.15,0.22,46.9)]
	for index: int in range(sites.size()):
		var plant: Node3D = stage.assets.broadleaf_cattail.instantiate()
		plant.name = "CityPondCattail_%02d" % index
		plant.position = sites[index]
		plant.rotation.y = float(index)*.72-.4
		plant.scale = Vector3.ONE*(.84+.055*float(index))
		plant.set_meta("stable_id","3dworld:teaching:city-pond-cattail:%04d" % index)
		stage.world_root.add_child(plant)
		plants.append(plant)
	var overview: Node3D = Node3D.new()
	overview.name = "CityPondOverview"
	overview.position = CENTER+Vector3(0.0,0.22,0.0)
	overview.set_meta("stable_id","3dworld:teaching:city-pond:overview")
	stage.world_root.add_child(overview)
	var birds: Array[Node3D] = []
	var heads: Array[Node3D] = []
	for index: int in range(2):
		var bird: Node3D = (stage.assets.mallard_drake if index==0 else stage.assets.mallard_hen).instantiate()
		LifeMotion.prepare_materials(bird)
		bird.name = "CityMallardDrake" if index==0 else "CityMallardHen"
		bird.set_meta("stable_id","3dworld:teaching:city-mallard:%04d" % index)
		stage.world_root.add_child(bird)
		MotionSkin.prepare(bird)
		var head: Node3D = bird.find_child("HeadPivot",true,false) as Node3D
		assert(head!=null)
		birds.append(bird)
		heads.append(head)
	stage.set_meta("city_pond",{"overview":overview,"birds":birds,"heads":heads,"plants":plants})
	stage.set_meta("city_pond_targets",[
		{"node":overview,"label":I18n.text("城市池塘 · 绿头鸭雌雄与香蒲"),"role":I18n.text("一对绿头鸭为同一物种的雌雄外观参考；岸边三株香蒲复用林地原创模型。合成城市池塘与摆放不是实地调查。"),"source_url":SOURCE,"distance":10.0,"view_offset":Vector3(6.8,3.8,8.2)},
		{"node":birds[0],"label":I18n.text("绿头鸭雄鸟 · Anas platyrhynchos"),"role":I18n.text("繁殖羽参考：绿色头部、白颈环、栗色前胸、黄色扁喙和有白边的蓝色翼镜。48秒游动及低头姿态为作者示意，不按日期模拟换羽或真实取食。"),"source_url":SOURCE,"distance":1.35,"min_distance":.75,"focus_height":.28,"view_offset":Vector3(.90,.55,1.0)},
		{"node":birds[1],"label":I18n.text("绿头鸭雌鸟 · Anas platyrhynchos"),"role":I18n.text("同种雌鸟参考：棕褐斑驳体羽、橙黑色宽扁喙及同样的蓝色翼镜。路线、两只数量和低头间隔均为作者设置。"),"source_url":SOURCE,"distance":1.35,"min_distance":.75,"focus_height":.28,"view_offset":Vector3(.90,.55,1.0)}])
	animate(stage,float(stage.world_snapshot.simulation_time_s))

static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("city_pond"): return
	var pond: Dictionary = stage.get_meta("city_pond")
	var birds: Array = pond.birds
	var heads: Array = pond.heads
	for index: int in range(birds.size()):
		var pose: Dictionary = sample(time,index)
		var bird: Node3D = birds[index]
		bird.position = pose.position
		bird.rotation.y = pose.heading
		var head: Node3D = heads[index]
		head.rotation.z = -.92*pose.head_dip
		MotionSkin.apply(bird)
		bird.set_meta("activity",pose.activity)
		bird.set_meta("head_dip",pose.head_dip)

static func readout(host: Node, topic: String) -> String:
	var pond: Dictionary = host.coordinator.active_scene.get_meta("city_pond",{})
	if pond.is_empty(): return I18n.text("城市池塘尚未就绪")
	if topic=="city_pond":
		return I18n.text("同种绿头鸭：1只雄鸟、1只雌鸟 · 岸边3株香蒲\n池塘、水位与布置为合成场景；无真实种群或水文模型")
	var index: int = 0 if topic=="city_mallard_drake" else 1
	var bird: Node3D = pond.birds[index]
	return I18n.text("%s · %s\n同一世界时间 %.1f s · 48秒作者路线；暂停后姿态与位置冻结") % [
		I18n.text("雄鸟繁殖羽参考") if index==0 else I18n.text("雌鸟羽色参考"),
		str(bird.get_meta("activity",I18n.text("水面缓游"))),host.world.simulation_time_s]

static func marks(host: Node, topic: String) -> Array[Dictionary]:
	var pond: Dictionary = host.coordinator.active_scene.get_meta("city_pond",{})
	if pond.is_empty(): return []
	if topic=="city_pond":
		return [{"at":pond.birds[0].global_position+Vector3(0.0,.48,0.0),
			"label":I18n.text("雄鸟"),"offset":Vector2(-120,-70)},
			{"at":pond.birds[1].global_position+Vector3(0.0,.48,0.0),
			"label":I18n.text("雌鸟"),"offset":Vector2(100,-70)},
			{"at":pond.plants[0].global_position+Vector3(0.0,.90,0.0),
			"label":I18n.text("岸边香蒲"),"offset":Vector2(-100,-90)}]
	var index: int = 0 if topic=="city_mallard_drake" else 1
	var bird: Node3D = pond.birds[index]
	var bill: Node3D = bird.find_child("BillTipAnchor",true,false) as Node3D
	var wing: Node3D = bird.find_child("WingSpeculumAnchor",true,false) as Node3D
	if bill==null or wing==null: return []
	return [{"at":bill.global_position,"label":I18n.text("宽扁喙"),"offset":Vector2(95,-70)},
		{"at":wing.global_position,"label":I18n.text("蓝色翼镜 / 白边"),"offset":Vector2(-145,-55)}]
