extends "res://tests/integration/deer_skin_suite.gd"
const Iguana = preload("res://scripts/experience/iguana_observation.gd")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world116-check="): directory=argument.trim_prefix("--world116-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless" and DisplayServer.get_screen_count()==1:
		main._measurement_screen=get_window().current_screen
		get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	get_window().size=Vector2i(1280,720)
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("desert"):
		await finish()
		return
	main.ground_light_preview=false
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	check("six views retain four existing plant targets",main.content_targets().size()==6 and main.content_targets()[0].node==stage.get_meta("desert_cactus") and main.content_targets()[1].node==stage.get_meta("desert_shrub"))
	if not stage.has_meta("iguana"):
		check("release initializes actual iguana",false)
		await finish()
		return
	var animal: Node3D = stage.get_meta("iguana")
	var data: Dictionary = animal.get_meta("iguana_skin")
	check("original skin and twenty-three bones are instantiated",animal.find_child("IguanaSkin",true,false)!=null and data.skeleton.get_bone_count()==23)
	check("new lesson selects actual animal",panel.select_topic("desert_iguana") and main._content_follow==4)
	await at_time(15.)
	check("whole animal and both structure labels clear explanation panel",subject_visible(animal) and main.learning_overlay.last_visible_marks==2)
	check("actual pigmented skin visibly renders above terrain",await part_pixels(animal,animal.to_global(Vector3(0,.035,0)),Vector2i(30,30))>100)
	await capture("iguana-resting")
	var transform: Transform3D = animal.transform
	var head: Quaternion = data.skeleton.get_bone_pose_rotation(data.bones.Head.id)
	await settle()
	check("pause fixes root and head pose",animal.transform.is_equal_approx(transform) and head.is_equal_approx(data.skeleton.get_bone_pose_rotation(data.bones.Head.id)) and main.world.simulation_time_s==15.)
	await at_time(1.8)
	transform=animal.transform
	var leg: Quaternion = data.skeleton.get_bone_pose_rotation(data.bones.ForeL.id)
	await capture("iguana-walking")
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("one world clock advances root and limbs together",main.world.simulation_time_s>1.9 and animal.position.distance_to(transform.origin)>.002 and not leg.is_equal_approx(data.skeleton.get_bone_pose_rotation(data.bones.ForeL.id)))
	await at_time(15.)
	panel.object_picker.item_selected.emit(6)
	await settle()
	check("head detail selects same attached animal with close clipping",main._content_follow==5 and stage.camera.near<.001 and main.learning_overlay.topic.is_empty())
	check("head and low dorsal keels render in close view",await part_pixels(animal,animal.to_global(Vector3(.058,.056,0)),Vector2i(25,25))>80 and await part_pixels(animal,animal.to_global(Vector3(0,.057,0)),Vector2i(12,12))>20)
	await capture("iguana-head-detail")
	panel.clear_topic()
	main._content_follow=-1
	main._orbit_target=Vector3(3.3,.7,3.)
	stage.set_pose(main._orbit_target+Vector3(3.,1.8,4.),main._orbit_target)
	await settle()
	await capture("iguana-shrub-habitat")
	transform=animal.transform
	head=data.skeleton.get_bone_pose_rotation(data.bones.Head.id)
	if not await arrive("earth") or not await arrive("desert"):
		await finish()
		return
	animal=main.coordinator.active_scene.get_meta("iguana")
	data=animal.get_meta("iguana_skin")
	check("reentry restores same identity and pose from host time",animal.get_meta("stable_id")=="3dworld:teaching:desert-iguana:0000" and animal.transform.is_equal_approx(transform) and head.is_equal_approx(data.skeleton.get_bone_pose_rotation(data.bones.Head.id)) and main.world.simulation_time_s==15.)
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="desert_iguana": action=button
	check("thirty-fifth guide route opens new iguana lesson",action!=null and main.world_guide.route_buttons.size()==35)
	if action!=null: action.pressed.emit()
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact view retains subject and annotation control",subject_visible(animal) and main.learning_overlay.last_visible_marks==2 and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-12)
	check("lesson identifies authored behavior and plant-food limits",panel.lesson_text.text.contains("作者设置") and panel.lesson_text.text.contains("体温") and panel.lesson_source.visible)
	await capture("iguana-compact")
	await finish()
