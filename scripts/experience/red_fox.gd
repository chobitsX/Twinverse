extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## One authored fox. Pose and route sample the existing world seconds only.
const SkinPose = preload("res://scripts/experience/human_skin_motion.gd")
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const Woodland = preload("res://scripts/experience/woodland_environment.gd")
const SOURCE: String = "https://www.nps.gov/isro/learn/nature/red-fox.htm"
const SHAPE_SOURCE: String = "https://www.nps.gov/yell/learn/nature/red-fox.htm"
const STABLE_ID: String = "3dworld:teaching:red-fox:0000"
const HEAD_ID: String = "3dworld:teaching:red-fox:head"
const PERIOD_S: float = 40.0
const RADIUS_M: float = 1.4

static func prepare(root: Node3D) -> Dictionary:
	LifeMotion.prepare_materials(root)
	var skeletons: Array[Node] = root.find_children("*","Skeleton3D",true,false)
	assert(not skeletons.is_empty())
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var bones: Dictionary = {}
	for i: int in range(skeleton.get_bone_count()):
		var name: String = skeleton.get_bone_name(i)
		var rest: Transform3D = skeleton.get_bone_global_rest(i)
		bones[name] = {"id":i,"rest_rotation":skeleton.get_bone_rest(i).basis.get_rotation_quaternion(),"axis_z":(rest.basis.inverse()*Vector3.BACK).normalized(),"axis_y":(rest.basis.inverse()*Vector3.UP).normalized(),"origin":rest.origin}
	for key: String in ["Spine","Neck","Head","EarL","EarR","Tail0","Tail1","Tail2","Tail3","ForeL","ForeR","HindL","HindR","ForeLPaw","ForeRPaw","HindLPaw","HindRPaw"]:
		assert(bones.has(key),"Missing authored fox bone: "+key)
	var marker: Node3D = root.find_child("EcologyMuzzleRest", true, false) as Node3D
	var data: Dictionary = {"skeleton":skeleton,"bones":bones,
		"muzzle_rest":marker.position if marker != null else Vector3(.406,.422,0)}
	root.set_meta("fox_skin",data)
	return data

static func sample(time: float) -> Dictionary:
	var cycle: float = fposmod(time,PERIOD_S)
	var moving: float = smoothstep(0.,1.5,cycle)*(1.-smoothstep(11.,13.,cycle))
	# Integrate the same speed envelope for both the root and foot phase.
	var travel_s: float
	if cycle<1.5:
		var u: float = cycle/1.5
		travel_s = 1.5*(pow(u,3)-.5*pow(u,4))
	elif cycle<11.:
		travel_s = cycle-.75
	elif cycle<13.:
		var u: float = (cycle-11.)/2.
		travel_s = 10.25+2.*(u-pow(u,3)+.5*pow(u,4))
	else:
		travel_s = 11.25
	travel_s += floor(time/PERIOD_S)*11.25
	var distance: float = travel_s*.18
	var angle: float = distance/RADIUS_M+.35
	return {"position":Vector3(-5.+cos(angle)*RADIUS_M,0,5.+sin(angle)*RADIUS_M),"heading":atan2(-cos(angle),-sin(angle)),"moving":moving,"step_phase":distance/(.16/.64),"distance":distance,"activity":I18n.text("缓行 · 林缘作者路线") if cycle<13. else I18n.text("停步 · 头部与耳尾微动")}

static func pose(root: Node3D,time: float,state: Dictionary) -> void:
	var data: Dictionary = root.get_meta("fox_skin")
	var keys: Array[String] = ["ForeL","HindR","ForeR","HindL"]
	for i: int in range(keys.size()):
		var key: String = keys[i]
		var hip: Vector3 = data.bones[key].origin
		var knee: Vector3 = data.bones[key+"Knee"].origin
		var ankle: Vector3 = data.bones[key+"Paw"].origin
		var upper: Vector2 = Vector2(knee.x-hip.x,knee.y-hip.y)
		var lower: Vector2 = Vector2(ankle.x-knee.x,ankle.y-knee.y)
		var step: Vector2 = LifeMotion._step(float(state.step_phase)+float(i)*.25,.16,.040)*float(state.moving)
		var foot_world: Vector3 = root.to_global(ankle+Vector3(step.x,0,0))
		var ground_delta: float = Woodland.height_at(foot_world.x,foot_world.z)-root.position.y
		var foot: Vector2 = upper+lower+step+Vector2(0,ground_delta)
		var l1: float = upper.length()
		var l2: float = lower.length()
		var d: float = clampf(foot.length(),absf(l1-l2)+.0001,l1+l2-.0001)
		var direction: float = atan2(foot.x,-foot.y)
		var bend: float = 1. if key.begins_with("Fore") else -1.
		var a: float = direction+bend*acos(clampf((l1*l1+d*d-l2*l2)/(2*l1*d),-1.,1.))
		var b: float = direction-bend*acos(clampf((l2*l2+d*d-l1*l1)/(2*l2*d),-1.,1.))
		var rest_a: float = atan2(upper.x,-upper.y)
		var rest_b: float = atan2(lower.x,-lower.y)
		SkinPose._angle(data,key,a-rest_a)
		SkinPose._angle(data,key+"Knee",b-a-(rest_b-rest_a))
		SkinPose._angle(data,key+"Paw",-(b-rest_b))
	SkinPose._angle(data,"Neck",.025*sin(time*.55))
	SkinPose._angle(data,"Head",.022*sin(time*.73),.10*sin(time*.37))
	SkinPose._angle(data,"EarL",0,.065*sin(time*.91))
	SkinPose._angle(data,"EarR",0,.065*sin(time*.71+.7))
	for i: int in range(4):
		SkinPose._angle(data,"Tail%d" % i,0,.027*sin(time*.80-float(i)*.38))

static func point(root: Node3D,key: String,rest_point: Vector3) -> Vector3:
	var data: Dictionary = root.get_meta("fox_skin")
	var skeleton: Skeleton3D = data.skeleton
	var id: int = int(data.bones[key].id)
	return skeleton.to_global(skeleton.get_bone_global_pose(id)*skeleton.get_bone_global_rest(id).affine_inverse()*rest_point)

static func build(stage: Node) -> void:
	var root: Node3D = stage.assets.red_fox.instantiate()
	root.name = "RedFoxReference"
	root.set_meta("stable_id",STABLE_ID)
	stage.world_root.add_child(root)
	prepare(root)
	var head_view: Node3D = Node3D.new()
	head_view.name = "RedFoxHeadObserver"
	head_view.set_meta("stable_id",HEAD_ID)
	head_view.set_meta("fox_root",root)
	stage.world_root.add_child(head_view)
	stage.set_meta("red_fox",{"root":root,"head_view":head_view})
	stage.set_meta("red_fox_targets",[
		{"node":root,"label":I18n.text("赤狐 · Vulpes vulpes"),"role":I18n.text("林缘犬科/杂食性参考；一个米制参考个体沿作者路线缓行、停步。没有实际猎物或捕猎求解。"),"source_url":SOURCE,"distance":1.85,"min_distance":.70,"focus_height":.33,"view_offset_local":Vector3(1.2,.42,1.4)},
		{"node":head_view,"label":I18n.text("赤狐 · 同一只的尖吻与尖耳"),"role":I18n.text("近看同一只赤狐的细长吻、黑鼻、尖耳和浅色喉部；不是标本、亚种或个体鉴定。"),"source_url":SHAPE_SOURCE,"distance":.55,"min_distance":.22,"view_offset_local":Vector3(.40,.06,.38)}])
	animate(stage,float(stage.world_snapshot.simulation_time_s))

static func animate(stage: Node,time: float) -> void:
	if not stage.has_meta("red_fox"): return
	var data: Dictionary = stage.get_meta("red_fox")
	var root: Node3D = data.root
	var state: Dictionary = sample(time)
	root.position = state.position
	root.position.y = Woodland.height_at(root.position.x,root.position.z)-.004*float(state.moving)
	root.rotation.y = state.heading
	pose(root,time,state)
	root.set_meta("activity",state.activity)
	root.set_meta("sampled_world_time_s",time)
	var skin: Dictionary = root.get_meta("fox_skin")
	data.head_view.position = point(root,"Head",(skin.bones.Head.origin as Vector3).lerp(skin.muzzle_rest, .45))
	data.head_view.rotation.y = root.rotation.y
	data.head_view.set_meta("activity",state.activity)

static func readout(host: Node,topic: String) -> String:
	var data: Dictionary = host.coordinator.active_scene.get_meta("red_fox",{})
	if data.is_empty(): return I18n.text("赤狐参考未载入")
	if topic=="red_fox_head": return I18n.text("同一只赤狐 · 尖吻、尖耳和浅色喉部\n头部观察点随原骨骼与世界秒更新")
	return I18n.text("赤狐 · 1只作者参考个体\n")+str(data.root.get_meta("activity",""))+I18n.text("\n肩高约40厘米；40秒作者节律")

static func marks(host: Node,topic: String) -> Array[Dictionary]:
	var data: Dictionary = host.coordinator.active_scene.get_meta("red_fox",{})
	if data.is_empty(): return []
	var root: Node3D = data.root
	var skin: Dictionary = root.get_meta("fox_skin")
	if topic=="red_fox_head":
		return [{"at":point(root,"Head",skin.muzzle_rest),"label":I18n.text("细长尖吻"),"offset":Vector2(85,35)},
			{"at":point(root,"EarL",skin.bones.EarL.origin+Vector3(0,.05,0)),"label":I18n.text("尖耳"),"offset":Vector2(-85,-55)}]
	return [{"at":point(root,"Head",skin.bones.Head.origin),"label":I18n.text("尖耳与尖吻"),"offset":Vector2(75,-70)},
		{"at":point(root,"Tail3",skin.bones.Tail3.origin+Vector3(-.05,-.03,0)),"label":I18n.text("白尾端"),"offset":Vector2(-85,45)}]
