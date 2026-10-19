extends RefCounted
## Original amphibian reference, with deterministic authored throat movement.
## This is a presentation of the host clock; no independent physiology state.
const Forms = preload("res://scripts/experience/life_forms.gd")
const Life = preload("res://scripts/experience/life_asset_motion.gd")
const Woodland = preload("res://scripts/experience/woodland_environment.gd")
const SOURCE: String = "https://www.nps.gov/chat/learn/nature/bullfrog.htm"
const MALE_SOURCE: String = "https://dwr.virginia.gov/wildlife/information/american-bullfrog/"
const PERIOD: float = 2.8

static func sample(time: float, index: int) -> float:
	# 0–0.8 mm of local throat movement; not a measured breathing rate.
	return .0008*(.5-.5*cos(TAU*fposmod(time+index*.93,PERIOD)/PERIOD))

static func prepare(root: Node3D) -> bool:
	var skeletons: Array[Node] = root.find_children("*","Skeleton3D",true,false)
	if skeletons.size()!=1: return false
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var id: int = skeleton.find_bone("Throat")
	if id<0: return false
	var parent: int = skeleton.get_bone_parent(id)
	var rest: Transform3D = skeleton.get_bone_rest(id)
	root.set_meta("frog_skin",{"skeleton":skeleton,"throat":id,"rest":rest.origin,"direction":skeleton.get_bone_global_rest(parent).basis.inverse()*Vector3.DOWN})
	return true

static func pose(root: Node3D, time: float, index: int) -> void:
	var data: Dictionary = root.get_meta("frog_skin")
	data.skeleton.set_bone_pose_position(data.throat,data.rest+data.direction*sample(time,index))
	root.set_meta("activity","岸边静伏 · 喉部轻微起伏（作者动作）")

static func _shelf(stage: Node, at: Vector2) -> Vector3:
	# A small authored shore stone. Its actual flat top is the foot-contact plane.
	# The stone crosses the analytic/triangle terrain difference at this scale.
	var y: float = maxf(Woodland.WATER_Y+.07,Woodland.height_at(at.x,at.y)+.07)
	var surf: SurfaceTool = SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(24):
		var a: float = TAU*i/24.
		var b: float = TAU*(i+1)/24.
		var ra: float = 1.+.07*sin(i*2.4)
		var rb: float = 1.+.07*sin((i+1)*2.4)
		var p: Vector3 = Vector3(cos(a)*.43*ra,y,sin(a)*.31*ra)
		var q: Vector3 = Vector3(cos(b)*.43*rb,y,sin(b)*.31*rb)
		var low_p: Vector3 = Vector3(p.x*1.12,y-.26,p.z*1.12)
		var low_q: Vector3 = Vector3(q.x*1.12,y-.26,q.z*1.12)
		for v: Vector3 in [Vector3(0,y,0),p,q,p,low_p,q,q,low_p,low_q]: surf.add_vertex(v)
	surf.generate_normals()
	var material: StandardMaterial3D = Woodland._pbr(Woodland.ROCK_COLOR,Woodland.ROCK_NORMAL,Woodland.ROCK_ARM,3.5)
	material.albedo_color = Color(.64,.68,.60)
	var stone: MeshInstance3D = Forms.mesh(stage.world_root,surf.commit(),material,Vector3(at.x,0,at.y))
	stone.name = "BullfrogShoreStone"
	return Vector3(at.x,y,at.y)

static func build(stage: Node) -> void:
	var frogs: Array[Node3D] = []
	for i: int in range(2):
		var z: float = 5.0+i*1.3
		var point: Vector3 = _shelf(stage,Vector2(Woodland.river_center(z)+7.6,z))
		var node: Node3D = stage.assets.american_bullfrog.instantiate()
		node.name = "AmericanBullfrog%02d" % i
		Life.prepare_materials(node)
		stage.world_root.add_child(node)
		node.position = point
		node.rotation.y = .3 if i==0 else -1.0
		node.set_meta("stable_id","3dworld:teaching:bullfrog:%04d" % i)
		node.set_meta("contact_y",point.y)
		if not prepare(node):
			push_error("Bullfrog rig must include its throat bone")
			node.queue_free()
			continue
		frogs.append(node)
	stage.set_meta("frogs",frogs)
	stage.set_meta("frog_targets",[
		{"node":frogs[0],"label":"美洲牛蛙 · 鼓膜与喉部","role":"Lithobates catesbeianus成年雄性参考；黄色喉部、眼后鼓膜和短耳后褶。常见于有遮蔽的静水或缓流，主要夜间活动。","source_url":MALE_SOURCE,"distance":.37,"min_distance":.20,"focus_height":.035,"view_offset":Vector3(.20,.12,.30)},
		{"node":frogs[0],"label":"美洲牛蛙 · 后足与趾蹼","role":"比较短前肢与折叠后肢，前足四趾、后足五趾；最长后趾末端伸出蹼缘。当前仅静伏微动，没有游泳、跳跃或捕食求解。","source_url":SOURCE,"distance":.34,"min_distance":.20,"focus_height":.025,"view_offset":Vector3(-.13,.28,.18)}])

static func animate(stage: Node, time: float) -> void:
	var frogs: Array = stage.get_meta("frogs",[])
	for i: int in range(frogs.size()): pose(frogs[i],time,i)

static func readout(host: Node) -> String:
	return "成年雄性参考 · 体长约15 cm（作者尺度）\n岸边静伏；喉部起伏不代表实测呼吸频率或鸣叫。"

static func marks(host: Node) -> Array[Dictionary]:
	var node: Node3D = host.coordinator.active_scene.get_meta("frogs")[0]
	return [
		{"at":node.to_global(Vector3(.019,.044,.042)),"label":"鼓膜 · 位于眼后","offset":Vector2(-130,-65)},
		{"at":node.to_global(Vector3(.045,.024,.018)),"label":"雄性黄色喉部","offset":Vector2(95,65)},
		{"at":node.to_global(Vector3(-.025,.004,.078)),"label":"后足 · 五趾与趾蹼","offset":Vector2(-110,75)}]
