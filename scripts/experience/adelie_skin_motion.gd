extends RefCounted
## Selected continuous Tripo skin; the existing world clock owns every pose.
const SkinPose = preload("res://scripts/experience/human_skin_motion.gd")

static func prepare(root: Node3D) -> Dictionary:
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return {}
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var bones: Dictionary = {}
	for index: int in range(skeleton.get_bone_count()):
		var rest: Transform3D = skeleton.get_bone_global_rest(index)
		bones[skeleton.get_bone_name(index)] = {"id": index, "origin": rest.origin,
			"rest_rotation": skeleton.get_bone_rest(index).basis.get_rotation_quaternion(),
			"axis_x": (rest.basis.inverse()*Vector3.RIGHT).normalized(),
			"axis_y": (rest.basis.inverse()*Vector3.UP).normalized(),
			"axis_z": (rest.basis.inverse()*Vector3.BACK).normalized()}
	for key: String in ["Head", "NeckTwist01", "L_Clavicle", "R_Clavicle", "L_Thigh", "R_Thigh", "L_Calf", "R_Calf", "L_Foot", "R_Foot", "FeatherTail"]:
		assert(bones.has(key), "Missing selected Adelie skin bone: "+key)
	var data: Dictionary = {"skeleton": skeleton, "bones": bones, "continuous_skin": true}
	root.set_meta("adelie_skin", data)
	return data

static func pose(data: Dictionary, state: Dictionary, time: float) -> void:
	var swim: float = float(state.get("swim", 0.0))
	var walk: float = float(state.get("walk", 0.0))
	# Distribute the swimming neck counter-turn across the real weighted chain.
	SkinPose._angle(data, "NeckTwist01", .55*swim)
	SkinPose._angle(data, "Head", (PI/2.0-.55)*swim+float(state.get("head_bob", 0.0)))
	SkinPose._angle(data, "FeatherTail", PI/2.0*swim)
	for index: int in range(2):
		var key: String = "L" if index == 0 else "R"
		var wing: Dictionary = data.bones[key+"_Clavicle"]
		var side: float = signf((wing.origin as Vector3).z)
		var folded: float = side*(.32*(1.0-swim)+swim*(.95+.40*sin(TAU*time*1.4)))
		(data.skeleton as Skeleton3D).set_bone_pose_rotation(wing.id,
			wing.rest_rotation*Quaternion(wing.axis_x, folded))
		var stride: float = sin(TAU*time*1.25+float(index)*PI)
		SkinPose._angle(data, key+"_Thigh", .16*walk*stride-.10*swim)
		SkinPose._angle(data, key+"_Calf", -.08*walk*maxf(0.0, stride))
		SkinPose._angle(data, key+"_Foot", -.12*walk*stride)

static func point(root: Node3D, key: String, rest_point: Vector3) -> Vector3:
	var data: Dictionary = root.get_meta("adelie_skin")
	var skeleton: Skeleton3D = data.skeleton
	var index: int = int(data.bones[key].id)
	return skeleton.to_global(skeleton.get_bone_global_pose(index)*skeleton.get_bone_global_rest(index).affine_inverse()*rest_point)
