extends "res://tests/integration/navigation_suite.gd"

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world148-check="):directory=arg.trim_prefix("--world148-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(900,650);root.unfocusable=true
	main=Experience.instantiate();root.add_child(main)
	if native:main._measurement_screen=root.current_screen
	if not await ready_scale("earth"):finish_loading_status();return
	main.world_guide.hide();main.world.set_paused(true);main.set_solar_rate(0.);main._reduced_motion=true
	await frames()
	var world: RefCounted=main.world
	var time: float=main.world.simulation_time_s
	var original: Node=main.coordinator.active_scene
	check("idle has no loading overlay",not main.loading_status.visible)
	main.clean_observation.set_active(true)
	# Keep real loader progress, but hold only the presentation acknowledgement
	# long enough to inspect/cancel before main-thread construction (as in suite121).
	main.coordinator.set_process(false)
	main.navigate_to("earth_moon")
	await frames()
	main.coordinator._first_response_us=0
	main.coordinator._poll_loading()
	main.loading_status.refresh()
	check("loading exposes real target and restores normal HUD",main.loading_status.visible and main.hud.visible and not main.clean_observation.active and main.loading_status.heading.text.contains("地月"))
	var snapshot: Dictionary=main.coordinator.loading_status()
	var progress: Array=[]
	ResourceLoader.load_threaded_get_status(main.coordinator._path,progress)
	check("resource percentage comes from engine loading report",not progress.is_empty() and is_equal_approx(float(progress[0]),float(snapshot.resource_fraction)))
	check("resource completion does not claim interactive completion",main.world.current_scale_id=="earth" and original==main.coordinator.active_scene and main.loading_status.phase_label.text.contains("随后准备场景"))
	check("cancel control and panel fit small viewport",Rect2(Vector2.ZERO,Vector2(root.size)).encloses(main.loading_status.get_global_rect()) and main.loading_status.cancel_button.is_visible_in_tree())
	await capture("loading-progress-compact")
	main.loading_status.cancel_button.pressed.emit();await frames()
	check("cancel keeps original paused world and hides progress panel",main.world==world and main.world.simulation_time_s==time and main.world.current_scale_id=="earth" and original==main.coordinator.active_scene and not main.loading_status.visible)
	check("cancelled worker remains single request until drained",main.coordinator.phase==main.Coordinator.Phase.DRAINING and main.coordinator.request_transition("woodland",main._path_for("woodland"),190.)==-1)
	main.coordinator.set_process(true)
	if not await ready_scale("earth"):finish_loading_status();return
	main.navigate_to("earth_moon")
	if not await ready_scale("earth_moon"):finish_loading_status();return
	await frames()
	check("ordinary retry reaches destination and removes loading panel",main.world==world and main.world.simulation_time_s==time and not main.loading_status.visible and main.scene_host.get_child_count()==1)
	await capture("destination-after-loading")
	main.navigate_to("earth")
	if not await ready_scale("earth"):finish_loading_status();return
	check("return retains authority time and clean idle state",main.world==world and main.world.simulation_time_s==time and not main.coordinator.is_busy() and main.coordinator.recovery_state().is_empty())
	check("resource restrictions remain in force",int(ProjectSettings.get_setting("threading/worker_pool/max_threads"))==2 and (not native or Engine.max_fps==5))
	finish_loading_status()

func finish_loading_status() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"native":native,"debug_build":OS.is_debug_build(),"performance_test":false,"controlled_setup":"first visual acknowledgement held only for loading-panel capture and cancel; actual ResourceLoader progress and production cancellation"},"\t")+"\n")
	print("LOADING_STATUS_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
