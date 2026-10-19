extends "res://tests/integration/deer_skin_suite.gd"
const Frog = preload("res://scripts/experience/frog_observation.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world112-check="): directory=argument.trim_prefix("--world112-check=")
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
	if DisplayServer.get_name()!="headless":
		var stable: int = Time.get_ticks_msec()
		var startup_deadline: int = stable+10000
		while Time.get_ticks_msec()-stable<2000 and Time.get_ticks_msec()<startup_deadline:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable=Time.get_ticks_msec()
	get_window().size=Vector2i(1280,720)
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("woodland"):
		await finish()
		return
	main.ground_light_preview=false
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	var frogs: Array = stage.get_meta("frogs",[])
	check("two original frogs append two views without moving old targets",frogs.size()==2 and main.content_targets().size()==11 and main.content_targets()[8].node==stage.get_meta("browse_targets")[0].node)
	if frogs.size()!=2:
		await finish()
		return
	var frog: Node3D = frogs[0]
	if not frog.has_meta("frog_skin"):
		check("release frog initialization exists",false)
		await finish()
		return
	var data: Dictionary = frog.get_meta("frog_skin")
	var skin: MeshInstance3D = frog.find_child("FrogSkin",true,false) as MeshInstance3D
	var material: StandardMaterial3D = skin.mesh.surface_get_material(0) as StandardMaterial3D
	check("original skinned geometry and skin pigment render in engine",skin.skin!=null and data.skeleton.get_bone_count()==15 and material.vertex_color_use_as_albedo)
	check("primary frog is on its actual dry stone top",absf(frog.position.y-float(frog.get_meta("contact_y")))<.000001 and frog.position.y>Frog.Woodland.WATER_Y+.06)
	check("frog topic selects the appended actual animal",panel.select_topic("bullfrog") and main._content_follow==9)
	await at_time(.0)
	check("close subject and three structure marks clear the explanation panel",subject_visible(frog) and main.learning_overlay.last_visible_marks==3)
	check("skin visibly renders instead of being hidden by bank vegetation",await part_pixels(frog,frog.to_global(Vector3(.018,.040,0)),Vector2i(50,45))>200)
	check("near tympanum visibly renders",await part_pixels(frog,frog.to_global(Vector3(.019,.044,.042)))>20)
	await capture("bullfrog-structure")
	var rest: Vector3 = data.skeleton.get_bone_pose_position(data.throat)
	await at_time(1.4)
	check("world time drives actual throat deformation",not rest.is_equal_approx(data.skeleton.get_bone_pose_position(data.throat)))
	var transform: Transform3D = frog.transform
	var throat: Vector3 = data.skeleton.get_bone_pose_position(data.throat)
	await settle()
	check("pause fixes root and throat pose",frog.transform.is_equal_approx(transform) and throat.is_equal_approx(data.skeleton.get_bone_pose_position(data.throat)) and main.world.simulation_time_s==1.4)
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("normal shared clock advances throat while feet remain in place",main.world.simulation_time_s>1.5 and not throat.is_equal_approx(data.skeleton.get_bone_pose_position(data.throat)) and frog.transform.is_equal_approx(transform))
	panel.object_picker.item_selected.emit(11)
	await settle()
	check("rear-foot view retains same real frog with reachable clipping",main._content_follow==10 and main.learning_overlay.topic.is_empty() and subject_visible(frog) and stage.camera.near<.09)
	var web_pixels: int = await part_pixels(frog,frog.to_global(Vector3(-.025,.004,.078)),Vector2i(20,20))
	check("rear web actually appears in its overhead view",web_pixels>50)
	await capture("bullfrog-hind-foot")
	panel.clear_topic()
	main._content_follow=-1
	main._orbit_target=frog.position+Vector3(0,.07,0)
	stage.set_pose(main._orbit_target+Vector3(.7,.8,1.3),main._orbit_target)
	await settle()
	await capture("bullfrog-riverbank")
	await at_time(1.4)
	throat=data.skeleton.get_bone_pose_position(data.throat)
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	frog=main.coordinator.active_scene.get_meta("frogs")[0]
	data=frog.get_meta("frog_skin")
	check("reentry reconstructs same frog identity and pose from host time",frog.get_meta("stable_id")=="3dworld:teaching:bullfrog:0000" and frog.transform.is_equal_approx(transform) and throat.is_equal_approx(data.skeleton.get_bone_pose_position(data.throat)) and main.world.simulation_time_s==1.4)
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="bullfrog": action=button
	check("twenty-ninth guide route opens frog observation",action!=null and main.world_guide.route_buttons.size()==29)
	if action!=null: action.pressed.emit()
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact frog view keeps subject and annotation toggle visible",main.learning_overlay.topic=="bullfrog" and subject_visible(frog) and main.learning_overlay.last_visible_marks==3 and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-12)
	check("lesson distinguishes authored micro-motion and night activity",panel.lesson_text.text.contains("主要夜间活动") and panel.lesson_text.text.contains("呼吸生理") and panel.lesson_source.visible)
	await capture("bullfrog-compact")
	await finish()
