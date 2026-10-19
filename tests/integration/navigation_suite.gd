extends "res://tests/integration/solar_size_suite.gd"

func key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event: InputEventKey=InputEventKey.new()
		event.keycode=code; event.pressed=pressed
		root.push_input(event)
		await get_tree().process_frame
	await frames()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world135-check="): directory=argument.trim_prefix("--world135-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,720)
	if native: root.unfocusable=true
	main=Experience.instantiate(); root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("earth"): finish_navigation(); return
	main._reduced_motion=true; main.world.set_paused(true); main.set_solar_rate(0.)
	main.world_guide.hide()
	var authority: RefCounted=main.world
	var time_before: float=main.world.simulation_time_s
	var bar: Node=main.navigation_bar
	await frames()
	check("Earth path and safe exits",bar.path_buttons.size()==3 and bar.earth_button.disabled and not bar.galaxy_button.disabled and bar.return_button.disabled)
	main.info_panel.show()
	await key(KEY_ESCAPE)
	check("Escape closes information without quitting or navigating",not main.info_panel.visible and main.world.current_scale_id=="earth" and not main._shutting_down)
	var stage: Node=main.coordinator.active_scene
	stage.set_pose(stage.camera.position.rotated(Vector3.UP,.42),main._orbit_target)
	var earth_pose: Transform3D=stage.camera.transform
	bar.path_buttons[1].pressed.emit()
	if not await ready_scale("solar_system"): finish_navigation(); return
	await frames()
	check("clickable breadcrumb reaches parent and commits return",bar.origin.get("scale")=="earth" and not bar.return_button.disabled)
	bar.return_button.grab_focus()
	await key(KEY_ENTER)
	if not await ready_scale("earth"): finish_navigation(); return
	await frames()
	check("keyboard return restores custom camera without advancing world",main.coordinator.active_scene.camera.transform.is_equal_approx(earth_pose) and main.world==authority and main.world.simulation_time_s==time_before)
	bar.galaxy_button.pressed.emit()
	main.coordinator.cancel("navigation_suite_cancel")
	if not await ready_scale("earth"): finish_navigation(); return
	check("cancelled jump retains last successful return point",bar.origin.get("scale")=="solar_system" and bar.pending_restore.is_empty() and bar.departure.is_empty())
	await key(KEY_ESCAPE)
	if not await ready_scale("solar_system"): finish_navigation(); return
	main.follow_planet(0)
	await frames()
	await key(KEY_ESCAPE)
	check("Escape clears tracked planet before ascending",main.solar_follow==-1 and main.world.current_scale_id=="solar_system")
	await key(KEY_ESCAPE)
	if not await ready_scale("galaxy"): finish_navigation(); return
	await key(KEY_ESCAPE)
	check("Escape at outermost scale stays open",main.world.current_scale_id=="galaxy" and not main._shutting_down)
	bar.earth_button.pressed.emit()
	if not await ready_scale("earth"): finish_navigation(); return
	await frames()
	await capture("earth-navigation")
	bar.jump("heart")
	if not await ready_scale("heart"): finish_navigation(); return
	main._select_heart_region("atrium")
	await key(KEY_ESCAPE)
	check("first Escape closes selected anatomy information",not main.info_panel.visible and main.coordinator.active_scene.get_meta("anatomy_selected_region")=="atrium")
	await key(KEY_ESCAPE)
	check("second Escape clears anatomy selection at same scale",main.world.current_scale_id=="heart" and main.coordinator.active_scene.get_meta("anatomy_selected_region")=="")
	root.size=Vector2i(900,650)
	main.guided_journey.started=true; main.guided_journey.step=8; main.guided_journey.open()
	await frames()
	check("guide and anatomy remain below navigation",main.guided_journey.get_global_rect().position.y>=bar.get_global_rect().end.y and main.anatomy_controls.position.y>=bar.get_global_rect().end.y and main.guided_journey.get_global_rect().end.y<650)
	check("resize keeps current breadcrumb visible and guide title unobstructed",bar.path_scroll.get_global_rect().encloses(bar.path_buttons[-1].get_global_rect()) and not main.title_label.visible and main.message_label.get_global_rect().position.y>main.guided_journey.get_global_rect().end.y)
	await capture("heart-guide-navigation-compact")
	await key(KEY_ESCAPE)
	check("Escape suspends guide without leaving heart",not main.guided_journey.visible and main.world.current_scale_id=="heart")
	bar.jump("atom")
	if not await ready_scale("atom"): finish_navigation(); return
	await frames()
	var current_button: Button=bar.path_buttons[-1]
	print("NAVIGATION_LAYOUT ",bar.path_buttons.size()," ",bar.path_scroll.get_global_rect()," ",current_button.get_global_rect()," ",bar.return_button.get_global_rect())
	check("long breadcrumb retains all nodes with current node visible",bar.path_buttons.size()==13 and bar.path_scroll.get_global_rect().encloses(current_button.get_global_rect()) and bar.return_button.get_global_rect().end.x<=900)
	await capture("atom-navigation-compact")
	bar.earth_button.pressed.emit()
	if not await ready_scale("earth"): finish_navigation(); return
	bar.jump("earth_moon")
	if not await ready_scale("earth_moon"): finish_navigation(); return
	await frames()
	main.focus_lunar(true)
	var moon_pose: Transform3D=main.coordinator.active_scene.camera.transform
	var moon_size: float=main.coordinator.active_scene.camera.size
	bar.earth_button.pressed.emit()
	if not await ready_scale("earth"): finish_navigation(); return
	bar.return_button.pressed.emit()
	if not await ready_scale("earth_moon"): finish_navigation(); return
	await frames()
	check("return preserves orthographic observation position and zoom",main.coordinator.active_scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and main.coordinator.active_scene.camera.transform.is_equal_approx(moon_pose) and is_equal_approx(main.coordinator.active_scene.camera.size,moon_size))
	check("all navigation keeps authority and paused world time",main.world==authority and main.world.simulation_time_s==time_before and not main._shutting_down)
	finish_navigation()

func finish_navigation() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"native":native,"debug_build":OS.is_debug_build(),"performance_test":false},"\t")+"\n")
	print("NAVIGATION_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
