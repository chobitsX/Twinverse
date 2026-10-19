extends RefCounted
## Four flippers and the breathing head use the existing host clock.
static func prepare(root: Node3D) -> bool:
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return false
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var bones: Dictionary = {}
	for id: int in range(skeleton.get_bone_count()):
		var rest: Transform3D = skeleton.get_bone_global_rest(id)
		bones[skeleton.get_bone_name(id)] = {"id":id, "origin":rest.origin,
			"rotation":skeleton.get_bone_rest(id).basis.get_rotation_quaternion(),
			"axis_x":(rest.basis.inverse()*Vector3.RIGHT).normalized(),
			"axis_y":(rest.basis.inverse()*Vector3.UP).normalized(),
			"axis_z":(rest.basis.inverse()*Vector3.BACK).normalized()}
	for key: String in ["Body", "Head", "FlipperL", "FlipperR", "HindFlipperL", "HindFlipperR"]:
		if not bones.has(key): return false
	var markers: Dictionary = {}
	for name: String in ["Nose", "Carapace", "Flipper", "HindFlipper"]:
		var marker: Node3D = root.find_child("Ecology"+name+"Rest",true,false) as Node3D
		if marker==null: return false
		markers[name] = marker.position
	root.set_meta("turtle_skin",{"skeleton":skeleton,"bones":bones,"markers":markers})
	return true

static func angle(data: Dictionary, name: String, angles: Vector3) -> void:
	var bone: Dictionary = data.bones[name]
	data.skeleton.set_bone_pose_rotation(bone.id,bone.rotation*
		Quaternion(bone.axis_x,angles.x)*Quaternion(bone.axis_y,angles.y)*Quaternion(bone.axis_z,angles.z))

static func pose(root: Node3D, state: Dictionary) -> void:
	var data: Dictionary = root.get_meta("turtle_skin")
	angle(data,"FlipperL",state.fore_left)
	angle(data,"FlipperR",state.fore_right)
	angle(data,"HindFlipperL",state.hind_left)
	angle(data,"HindFlipperR",state.hind_right)
	angle(data,"Head",Vector3(0,0,state.head_angle))

static func point(root: Node3D, name: String, marker: String) -> Vector3:
	var data: Dictionary = root.get_meta("turtle_skin")
	var skeleton: Skeleton3D = data.skeleton
	var id: int = data.bones[name].id
	return skeleton.to_global(skeleton.get_bone_global_pose(id)*
		skeleton.get_bone_global_rest(id).affine_inverse()*(data.markers[marker] as Vector3))

static func raised_nose(root: Node3D, angle_rad: float) -> Vector3:
	var data: Dictionary = root.get_meta("turtle_skin")
	var pivot: Vector3 = data.bones.Head.origin
	return (pivot+Basis(Vector3.BACK,angle_rad)*((data.markers.Nose as Vector3)-pivot))*root.scale.x
