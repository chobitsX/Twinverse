extends "res://tests/integration/navigation_suite.gd"

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world146-check="): directory=arg.trim_prefix("--world146-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,800);root.unfocusable=true
	main=Experience.instantiate();root.add_child(main)
	if native:main._measurement_screen=root.current_screen
	if not await ready_scale("earth"):finish_clean();return
	main.world.set_paused(true);main.set_solar_rate(0.);main._reduced_motion=true
	main.world_guide.hide();main.info_panel.show();await frames()
	var authority: RefCounted=main.world
	var time: float=main.world.simulation_time_s
	var jd: float=main.solar_jd
	var stage: Node=main.coordinator.active_scene
	var pose: Transform3D=stage.camera.transform
	main.clean_button.pressed.emit();await frames()
	check("entry hides HUD including open science panel while keeping reachable exit",not main.hud.is_visible_in_tree() and not main.info_panel.is_visible_in_tree() and main.info_panel.visible and main.clean_observation.exit_button.is_visible_in_tree())
	check("entering keeps camera date and world unchanged",stage.camera.transform.is_equal_approx(pose) and main.world==authority and main.world.simulation_time_s==time and main.solar_jd==jd)
	await capture("earth-clean")
	var mouse: InputEventMouseMotion=InputEventMouseMotion.new()
	mouse.position=Vector2(500,450);mouse.relative=Vector2(35,12);mouse.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(mouse);await frames()
	check("mouse orbit still reaches 3D through hidden HUD",not stage.camera.transform.is_equal_approx(pose))
	var distance: float=stage.camera.position.distance_to(main._orbit_target)
	var wheel: InputEventMouseButton=InputEventMouseButton.new()
	wheel.position=Vector2(500,450);wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	root.push_input(wheel);await frames()
	check("mouse wheel still zooms",stage.camera.position.distance_to(main._orbit_target)<distance)
	pose=stage.camera.transform
	await key(KEY_ESCAPE)
	check("Escape restores panel and changed camera without ascending",main.hud.visible and main.info_panel.is_visible_in_tree() and not main.clean_observation.active and main.world.current_scale_id=="earth" and stage.camera.transform.is_equal_approx(pose))
	main.info_panel.hide();main.world_guide.open();await key(KEY_F9)
	check("guide modal cannot be hidden accidentally by clean shortcut",main.world_guide.visible and main.hud.visible and not main.clean_observation.active)
	main.world_guide.hide();await key(KEY_F9)
	main.clean_observation.pause_button.pressed.emit();await frames()
	check("compact pause control resumes same world",not main.world.paused and main.world==authority and main.world.simulation_time_s>time)
	await key(KEY_SPACE)
	check("Space pauses once and updates compact label",main.world.paused and main.clean_observation.pause_button.text=="继续时间")
	time=main.world.simulation_time_s
	main.observe_scale("woodland")
	check("navigation restores loading and recovery HUD immediately",main.hud.visible and not main.clean_observation.active)
	if not await ready_scale("woodland"):finish_clean();return
	main.explorer_panel.show();await frames();main.explorer_panel.select_topic("bullfrog");await frames()
	var topic: String=main.learning_overlay.topic
	var selected: int=main._content_follow
	stage=main.coordinator.active_scene;pose=stage.camera.transform
	await key(KEY_F9)
	check("selected creature and lesson survive while screen labels disappear",topic=="bullfrog" and main._content_follow==selected and not main.learning_overlay.is_visible_in_tree() and main.explorer_panel.visible and not main.explorer_panel.is_visible_in_tree())
	check("selected camera remains stable",stage.camera.transform.is_equal_approx(pose))
	await capture("frog-clean")
	main.clean_observation.exit_button.pressed.emit();await frames()
	check("exit button restores same lesson markers and panel",main.learning_overlay.topic==topic and main._content_follow==selected and main.explorer_panel.is_visible_in_tree() and main.learning_overlay.is_visible_in_tree())
	await capture("frog-restored")
	main.explorer_panel.hide();main._reset_camera();root.size=Vector2i(900,650);await frames()
	check("compact window can reach new entry",Rect2(Vector2.ZERO,Vector2(root.size)).encloses(main.clean_button.get_global_rect()))
	await key(KEY_F9);await capture("woodland-compact-clean")
	check("compact exit and pause stay inside window",Rect2(Vector2.ZERO,Vector2(root.size)).encloses(main.clean_observation.get_global_rect()))
	await key(KEY_F9)
	check("F9 restores UI without changing time or authority",main.hud.visible and not main.clean_observation.active and main.world==authority and main.world.simulation_time_s==time and main.solar_jd==jd)
	check("resource cap remains active",not native or Engine.max_fps==5)
	finish_clean()

func finish_clean() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"native":native,"debug_build":OS.is_debug_build(),"performance_test":false},"\t")+"\n")
	print("CLEAN_OBSERVATION_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
