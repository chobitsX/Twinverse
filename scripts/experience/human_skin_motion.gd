extends RefCounted
## Read imported rest frames; all angles are author animation, evaluated from host time.
static func prepare(root: Node3D) -> bool:
	var skeletons: Array[Node] = root.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty(): return false
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var bones: Dictionary = {}
	for i: int in range(skeleton.get_bone_count()):
		var name: String = skeleton.get_bone_name(i)
		if name.begins_with("Head"): name = "Head"
		var rest: Transform3D = skeleton.get_bone_global_rest(i)
		bones[name] = {"id":i,"rest_rotation":skeleton.get_bone_rest(i).basis.get_rotation_quaternion(),"axis_z":(rest.basis.inverse()*Vector3(0,0,1)).normalized(),"axis_y":(rest.basis.inverse()*Vector3.UP).normalized(),"origin":rest.origin}
	root.set_meta("human_skin",{"skeleton":skeleton,"bones":bones})
	var joints: Dictionary = {}
	for name: String in ["LegL","LegR","LegLKnee","LegRKnee","FootL","FootR","ArmL","ArmR","ArmLElbow","ArmRElbow","Spine","Head"]:
		if not bones.has(name): return false
	for name: String in ["LegL","LegR","LegLKnee","LegRKnee","ArmL","ArmR","ArmLElbow","ArmRElbow"]: joints[name] = bones[name].id
	root.set_meta("life_joints",joints)
	root.set_meta("asset_species","person")
	return true

static func _angle(data: Dictionary,name: String,value: float,yaw: float = 0.) -> void:
	var bone: Dictionary = data.bones[name]
	data.skeleton.set_bone_pose_rotation(bone.id,bone.rest_rotation*Quaternion(bone.axis_z,value)*Quaternion(bone.axis_y,yaw))

static func person(root: Node3D,time: float,moving: float,phase: float,steps: Array[Vector2]) -> void:
	var data: Dictionary = root.get_meta("human_skin")
	for side: int in range(2):
		var key: String = "LegL" if side==0 else "LegR"
		var upper3: Vector3 = data.bones[key+"Knee"].origin-data.bones[key].origin
		var lower3: Vector3 = data.bones["FootL" if side==0 else "FootR"].origin-data.bones[key+"Knee"].origin
		var upper: Vector2 = Vector2(upper3.x,upper3.y)
		var lower: Vector2 = Vector2(lower3.x,lower3.y)
		# The entire stance, including its endpoints, must fit the imported leg.
		var rest_foot: Vector2 = upper+lower
		var foot: Vector2 = rest_foot+steps[side]+Vector2(0,.065*moving)
		var l1: float = upper.length()
		var l2: float = lower.length()
		var distance: float = clampf(foot.length(),absf(l1-l2)+.001,l1+l2-.001)
		var direction: float = atan2(foot.x,-foot.y)
		var a: float = direction+acos(clampf((l1*l1+distance*distance-l2*l2)/(2*l1*distance),-1,1))
		var b: float = direction-acos(clampf((l2*l2+distance*distance-l1*l1)/(2*l2*distance),-1,1))
		var rest_a: float = atan2(upper.x,-upper.y)
		var rest_b: float = atan2(lower.x,-lower.y)
		_angle(data,key,a-rest_a)
		_angle(data,key+"Knee",b-a-(rest_b-rest_a))
		# Counter rotate the ankle so the shoe sole stays level during stance.
		_angle(data,"FootL" if side==0 else "FootR",-(b-rest_b))
		var wave: float = sin((phase+side*.5)*TAU)
		_angle(data,"ArmL" if side==0 else "ArmR",-wave*.24*moving)
		_angle(data,"ArmLElbow" if side==0 else "ArmRElbow",.09+maxf(0,wave)*.22*moving)
	_angle(data,"Spine",sin(phase*TAU)*.016*moving)
	_angle(data,"Head",sin(time*.8)*.022*(1.-moving),sin(time*.35)*.14*(1.-moving))
