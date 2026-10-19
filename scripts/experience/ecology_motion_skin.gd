extends RefCounted
## Copy the existing authored joint transforms into the replacement continuous skin.
## The scene controller still owns motion and samples the single world clock.

static func prepare(root: Node3D) -> bool:
	var skeleton: Skeleton3D
	for node: Node in root.find_children("*","Skeleton3D",true,false):
		var candidate: Skeleton3D = node as Skeleton3D
		if candidate.find_bone("DriverRoot") >= 0:
			skeleton = candidate
			break
	if skeleton == null: return false
	var drivers: Array[Dictionary] = []
	for bone: int in range(skeleton.get_bone_count()):
		var bone_name: String = skeleton.get_bone_name(bone)
		if bone_name == "DriverRoot": continue
		var name: String = bone_name.trim_prefix("Skin_")
		var driver: Node3D = root.find_child(name,true,false) as Node3D
		assert(driver != null,"Missing original ecology joint: " + name)
		var transform: Transform3D = skeleton.global_transform.affine_inverse()*driver.global_transform
		drivers.append({"id":bone,"node":driver,"inverse":transform.affine_inverse(),
			"rest":skeleton.get_bone_global_rest(bone)})
	root.set_meta("ecology_motion_skin",{"skeleton":skeleton,"drivers":drivers})
	return true

static func apply(root: Node3D) -> void:
	if not root.has_meta("ecology_motion_skin"): return
	var data: Dictionary = root.get_meta("ecology_motion_skin")
	var skeleton: Skeleton3D = data.skeleton
	for entry: Dictionary in data.drivers:
		var id: int = entry.id
		var driver: Node3D = entry.node
		var current: Transform3D = skeleton.global_transform.affine_inverse()*driver.global_transform
		var desired: Transform3D = current*entry.inverse*entry.rest
		var parent: int = skeleton.get_bone_parent(id)
		var local: Transform3D = skeleton.get_bone_global_pose(parent).affine_inverse()*desired if parent >= 0 else desired
		skeleton.set_bone_pose_position(id,local.origin)
		skeleton.set_bone_pose_rotation(id,local.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(id,local.basis.get_scale())
