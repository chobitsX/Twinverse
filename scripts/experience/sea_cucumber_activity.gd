extends RefCounted
## Authored motion on the original oral meshes; all poses derive from world seconds.
const CYCLE_S: float = 12.0

static func prepare(root: Node3D) -> void:
	var joints: Array[Dictionary] = []
	for index: int in range(12):
		var arm: Node3D = root.find_child("FeedingTentacle%02d" % index,true,false) as Node3D
		var tip: Node3D = root.find_child("FeedingTip%02d" % index,true,false) as Node3D
		assert(arm!=null and tip!=null)
		var angle: float = TAU*index/12.0
		var radius: float = .005+.001*(index%3)
		var pivot: Node3D = Node3D.new()
		pivot.name = "AuthoredFeedingPivot%02d" % index
		root.add_child(pivot)
		# These bases are the original editable 184 authoring coordinates.
		pivot.position = Vector3(.104,.031+radius*cos(angle),radius*sin(angle))
		arm.reparent(pivot,true)
		tip.reparent(pivot,true)
		joints.append({"pivot":pivot,"arm":arm,"tip":tip,"axis":Vector3(0,-sin(angle),cos(angle)),"base":pivot.position})
	root.set_meta("authored_feeding_joints",joints)

static func phase(time: float) -> float:
	return fposmod(time/CYCLE_S,1.0)

static func phase_label(time: float) -> String:
	var value: float = phase(time)
	return "伸出参考" if value<.25 else ("缓慢收拢" if value<.60 else "再伸出参考")

static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("holothuria_root"): return
	var root: Node3D = stage.get_meta("holothuria_root")
	var joints: Array[Dictionary] = root.get_meta("authored_feeding_joints")
	for index: int in range(joints.size()):
		var entry: Dictionary = joints[index]
		var cycle: float = phase(time)+float(index)/12.0
		var inward: float = (1.0-cos(cycle*TAU))*.5
		entry.pivot.basis = Basis(entry.axis,.08-.48*inward)
	root.set_meta("activity","身体固定 · 错相触手伸收示意 · 首触手"+phase_label(time))

static func readout(host: Node) -> String:
	var stage: Node = host.coordinator.active_scene
	if not stage.has_meta("holothuria_root"): return "等待原海参观察就绪"
	var time: float = host.world.simulation_time_s
	return "同一只黑海参 · 触手伸收示意\n所指标记触手：%s · %.1f 秒\n%s；12秒循环为作者设置" % [phase_label(time),time,"已暂停，可继续看触手" if host.world.paused else "暂停可看口端与附着"]
