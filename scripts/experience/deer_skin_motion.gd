extends RefCounted
## Original doe skin, evaluated from the host clock. Not biomechanics.
const SkinPose = preload("res://scripts/experience/human_skin_motion.gd")
const SOURCE: String = "https://www.nps.gov/yell/learn/nature/white-tailed-deer.htm"

static func prepare(root: Node3D) -> bool:
	var skeletons: Array[Node] = root.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty(): return false
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var bones: Dictionary = {}
	for i: int in range(skeleton.get_bone_count()):
		var name: String = skeleton.get_bone_name(i)
		if name.begins_with("Head"): name = "Head"
		if name.begins_with("EarL"): name = "EarL"
		if name.begins_with("EarR"): name = "EarR"
		var rest: Transform3D = skeleton.get_bone_global_rest(i)
		bones[name] = {"id":i,"rest_rotation":skeleton.get_bone_rest(i).basis.get_rotation_quaternion(),"axis_z":(rest.basis.inverse()*Vector3.BACK).normalized(),"axis_y":(rest.basis.inverse()*Vector3.UP).normalized(),"origin":rest.origin}
	for key: String in ["Neck","Head","EarL","EarR","Tail","ForeL","ForeR","HindL","HindR","ForeLHoof","ForeRHoof","HindLHoof","HindRHoof"]:
		if not bones.has(key): return false
	var marker: Node3D = root.find_child("EcologyMuzzleRest", true, false) as Node3D
	root.set_meta("deer_skin",{"skeleton":skeleton,"bones":bones,"selected_skin":marker != null,
		"muzzle_rest":marker.position if marker != null else Vector3(.90,1.33,0)})
	root.set_meta("asset_species","deer")
	return true

static func sample(time: float, index: int) -> Dictionary:
	var clock: float = time+index*7.7
	var cycle: float = fposmod(clock,48.)
	var moving: float = smoothstep(0.,1.,cycle)*(1.-smoothstep(10.,12.,cycle))
	# Integral of the movement envelope: root stops where the legs stop.
	var travel: float
	if cycle<1.:
		travel = cycle*cycle*cycle-.5*pow(cycle,4)
	elif cycle<10.:
		travel = cycle-.5
	elif cycle<12.:
		var u: float = (cycle-10.)/2.
		travel = 9.5+2.*(u-pow(u,3)+.5*pow(u,4))
	else: travel = 10.5
	travel += floor(clock/48.)*10.5
	var angle: float = travel*.055+index*1.5
	var rx: float = 3.+index*.5
	var rz: float = 2.+index*.4
	return {"position":Vector3(2.5+cos(angle)*rx,0,-1.5+sin(angle)*rz),"heading":atan2(-cos(angle)*rz,-sin(angle)*rx),"moving":moving,"grazing":smoothstep(13.,16.,cycle)*(1.-smoothstep(35.,38.,cycle)),"step_phase":travel*.055*sqrt((rx*rx+rz*rz)*.5)/(.30/.64),"activity":"缓行 · 寻找取食点" if cycle<12 else "低头 · 植物食物示意" if cycle<38 else "停步 · 抬头观察"}

static func pose(root: Node3D, time: float, moving: float, grazing: float, phase: float) -> void:
	var data: Dictionary = root.get_meta("deer_skin")
	var keys: Array[String] = ["ForeL","HindR","ForeR","HindL"]
	for index: int in range(4):
		var key: String = keys[index]
		var upper3: Vector3 = data.bones[key+"Knee"].origin-data.bones[key].origin
		var lower3: Vector3 = data.bones[key+"Hoof"].origin-data.bones[key+"Knee"].origin
		var upper: Vector2 = Vector2(upper3.x,upper3.y)
		var lower: Vector2 = Vector2(lower3.x,lower3.y)
		var rest: Vector2 = upper+lower
		var p: float = fposmod(phase+index*.25,1.)
		var step: Vector2
		if p<.64: step = Vector2(lerpf(.15,-.15,p/.64),0)
		else:
			var swing: float = (p-.64)/.36
			step = Vector2(lerpf(-.15,.15,smoothstep(0.,1.,swing)),sin(swing*PI)*.075)
		var foot: Vector2 = rest+step*moving+Vector2(0,.012*moving)
		var l1: float = upper.length()
		var l2: float = lower.length()
		var d: float = clampf(foot.length(),absf(l1-l2)+.0001,l1+l2-.0001)
		var direction: float = atan2(foot.x,-foot.y)
		var bend: float = 1. if key.begins_with("Fore") else -1.
		var a: float = direction+bend*acos(clampf((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1))
		var b: float = direction-bend*acos(clampf((l2*l2+d*d-l1*l1)/(2*l2*d),-1,1))
		var rest_a: float = atan2(upper.x,-upper.y)
		var rest_b: float = atan2(lower.x,-lower.y)
		SkinPose._angle(data,key,a-rest_a)
		SkinPose._angle(data,key+"Knee",b-a-(rest_b-rest_a))
		SkinPose._angle(data,key+"Hoof",-(b-rest_b))
	# Head counter-rotation lets the muzzle approach plants without turning backwards.
	SkinPose._angle(data,"Neck",(-2.60 if data.selected_skin else -1.65)*grazing)
	SkinPose._angle(data,"Head",.65*grazing+sin(time*.8)*.025*(1.-grazing),sin(time*.42)*.08*(1.-grazing))
	SkinPose._angle(data,"EarL",0,sin(time*.67)*.075)
	SkinPose._angle(data,"EarR",0,sin(time*.53+1.)*.075)
	SkinPose._angle(data,"Tail",0,sin(time*1.5)*.08)

static func point(root: Node3D, key: String, rest_point: Vector3) -> Vector3:
	var data: Dictionary = root.get_meta("deer_skin")
	var skeleton: Skeleton3D = data.skeleton
	var id: int = data.bones[key].id
	return skeleton.to_global(skeleton.get_bone_global_pose(id)*skeleton.get_bone_global_rest(id).affine_inverse()*rest_point)

static func muzzle(root: Node3D) -> Vector3:
	return point(root,"Head",root.get_meta("deer_skin").muzzle_rest)
