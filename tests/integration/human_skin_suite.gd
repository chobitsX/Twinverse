extends "res://tests/integration/life_assets_suite.gd"
const WalkPath = preload("res://scripts/experience/city_walk_path.gd")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world90-check="): directory = argument.trim_prefix("--world90-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	if not await arrive("city"):
		await finish()
		return
	main.explorer_panel.hide()
	await at_time(9.0)
	main.follow_content(1)
	var continuous: bool = true
	var at: float = 0.0
	for side: int in range(4):
		at += 28.0 if side%2==0 else 12.0
		for boundary: float in [at,at+PI]:
			var before: Dictionary = WalkPath.sample(boundary-.001)
			var after: Dictionary = WalkPath.sample(boundary+.001)
			continuous = continuous and before.position.distance_to(after.position)<.003 and absf(angle_difference(before.heading,after.heading))<.002
		at += PI
	check("park corners and loop position/heading continuous",continuous)
	var person: Node3D = main.content_targets()[0].node
	var skin: Dictionary = person.get_meta("human_skin",{})
	check("person has imported fifteen bone skeleton",not skin.is_empty() and skin.skeleton.get_bone_count()==15)
	var leg: MeshInstance3D = person.find_child("ContinuousLegL",true,false) as MeshInstance3D
	check("continuous leg has skin weights",leg!=null and leg.skin!=null and leg.mesh.surface_get_format(0)&Mesh.ARRAY_FORMAT_WEIGHTS)
	check("walking people remain separated",people_separated())
	await capture("person-walk-a")
	var previous: Vector3 = person.position
	var knee: Quaternion = skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id)
	await at_time(9.3)
	check("world time moves root and deforms knee",person.position.distance_to(previous)>.2 and knee.angle_to(skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id))>.01)
	await capture("person-walk-b")
	previous = person.position
	knee = skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id)
	for frame: int in range(5): await get_tree().process_frame
	check("paused person and skeleton remain fixed",person.position.distance_to(previous)<.00001 and knee.angle_to(skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id))<.001)
	await at_time(112.)
	main.explorer_panel.show()
	await capture("person-resting")
	var foot_y: float = skin.skeleton.get_bone_global_pose(skin.bones.FootL.id).origin.y
	var hand_y: float = skin.skeleton.get_bone_global_pose(skin.bones.HandL.id).origin.y
	check("standing feet and hands remain below hips and shoulders",foot_y>.07 and foot_y<.17 and hand_y>.70 and hand_y<1.0)
	check("resting people remain separated",people_separated())
	check("standing activity remains observable",str(person.get_meta("activity")).contains("停留"))
	main.explorer_panel.hide()
	var second: Node3D = main.coordinator.active_scene.get_meta("actors")[1].node
	var target: Vector3 = second.position+Vector3(0,.95,0)
	main._content_follow = -1
	main._orbit_target = target
	main.coordinator.active_scene.camera.position = target+Vector3(-1.8,1.25,2.8)
	main.coordinator.active_scene.camera.look_at(target)
	await capture("second-person")
	check("second variant uses skeleton",second.has_meta("human_skin"))
	await finish()

func people_separated() -> bool:
	var people: Array[Vector3] = []
	for actor: Dictionary in main.coordinator.active_scene.get_meta("actors"):
		if actor.kind=="person": people.append(actor.node.position)
	for i: int in range(people.size()):
		for j: int in range(i+1,people.size()):
			if people[i].distance_to(people[j])<.65: return false
	return true
