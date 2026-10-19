extends "res://tests/integration/solar_scale_suite.gd"
## Reproduce the user's warmed galaxy entry and actual close-camera gestures.

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solar279-output="): directory=argument.trim_prefix("--solar279-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(75.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80.0
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	var world_id: int = main.world.get_instance_id()
	prepare_auto(); main.follow_planet(2,true); await settle()
	check("Earth selection slows the one whole system",is_equal_approx(main.solar_rate,1.0/24.0))
	var date: float = main.solar_jd
	# This is a real successful round trip, not a direct saved-view invocation.
	if not await travel("galaxy"): await finish(); return
	main._reduced_motion=false
	if not await travel("solar_system"): await finish(); return
	var stage: Node = main.coordinator.active_scene
	measurements.append({"kind":"galaxy to solar after Earth close","owner":stage.get_meta("solar_physical").owner,"camera":str(stage.camera.position),"target":str(main._orbit_target),"rate":main.solar_rate,"date":main.solar_jd})
	check("galaxy entry frames the whole solar system",main._orbit_target.distance_to(stage.default_target)<.001 and stage.camera.position.distance_to(stage.default_position)<.001)
	check("galaxy entry clears a stale physical Earth frame",int(stage.get_meta("solar_physical").owner)==-1 and main.solar_follow<0 and main._content_follow<0)
	check("galaxy entry restores overview playback without a date jump",main.solar_rate==10.0 and main.solar_jd==date and main._solar_close_playback.is_empty())
	await capture("galaxy-solar-entry")
	main._reduced_motion=true
	main.follow_planet(2,true); await settle()
	var before: Transform3D = stage.camera.transform
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask=MOUSE_BUTTON_MASK_RIGHT; event.relative=Vector2(100,-20); event.position=get_viewport().get_visible_rect().size*.5
	main._unhandled_input(event); await settle()
	check("right drag looks around without translating the close observer",stage.camera.position.distance_to(before.origin)<.00001 and not stage.camera.basis.is_equal_approx(before.basis))
	check("look around retains Earth physical scale and shared slow rate",int(stage.get_meta("solar_physical").owner)==2 and main.solar_follow==2 and is_equal_approx(main.solar_rate,1.0/24.0))
	main.follow_planet(2,true); await settle()
	var left_position: Vector3 = stage.camera.position
	var left_target: Vector3 = main._orbit_target
	event.button_mask=MOUSE_BUTTON_MASK_LEFT; event.relative=Vector2(22,-7)
	main._unhandled_input(event); await settle()
	check("left drag still orbits the same Earth view target",stage.camera.position.distance_to(left_position)>.01 and main._orbit_target.distance_to(left_target)<.00001)
	check("near context offers directional Sun and Moon access",main.has_method("look_solar_context"))
	if main.has_method("look_solar_context"):
		for index: int in [8,9]:
			main.follow_planet(2,true); await settle()
			var body: MeshInstance3D = stage.world_root.get_node("Sun_AuthoredPhotosphere") if index==8 else stage.get_meta("solar_moon").node
			var label: String = "Sun" if index==8 else "Moon"
			var owner_before: int = int(stage.get_meta("solar_physical").owner)
			var compass: Node = main.hud.get_node("SolarContextCompass")
			check(label+" has an interactive offscreen bearing",compass.visible and compass.buttons[index].visible)
			compass.buttons[index].pressed.emit(); await settle()
			var pixel: Vector2 = stage.camera.unproject_position(body.position)
			check(label+" locator actually brings the same-date body into view",not stage.camera.is_position_behind(body.position) and Rect2(Vector2.ZERO,Vector2(stage.viewport.size)).has_point(pixel))
			check(label+" locator retains Earth frame, rate and World",int(stage.get_meta("solar_physical").owner)==owner_before and main.solar_follow==2 and is_equal_approx(main.solar_rate,1.0/24.0) and main.world.get_instance_id()==world_id and main.solar_jd==date)
			var picked: Dictionary = main.object_pointer.pick(pixel)
			check(label+" is the rendered selectable body",picked.get("node")==body)
			measurements.append({"kind":"Earth context body","index":index,"pixel":str(pixel),"camera":str(stage.camera.position),"body":str(body.position),"radius":float(body.mesh.radius)*body.scale.x,"picked":str(picked.get("label",""))})
			await capture("earth-looking-"+label.to_lower())
		main.follow_planet(2,true); await settle()
		await capture("earth-context-locators")
		var gaze_position: Vector3 = stage.camera.position
		main.look_solar_context(8); await settle()
		gaze_position=stage.camera.position
		var fov: float = stage.camera.fov
		main._zoom_camera(stage,.8); await settle()
		check("pinch while looking at Sun zooms optics without entering Earth",main.world.current_scale_id=="solar_system" and not main.coordinator.is_busy() and stage.camera.position.distance_to(gaze_position)<.00001 and stage.camera.fov<fov)
		main._remember_view()
		var saved: Dictionary = main._views.solar_system.duplicate(true)
		var gaze_pose: Transform3D = stage.camera.transform
		var gaze_fov: float = stage.camera.fov
		main._reset_camera(); main._views.solar_system=saved
		main._restore_solar_view(); main._apply_saved_view(stage); await settle()
		check("saved gaze restores optical view, observer and slow rate",stage.camera.transform.is_equal_approx(gaze_pose) and is_equal_approx(stage.camera.fov,gaze_fov) and bool(stage.get_meta("solar_lookaround")) and main.WorldStore.valid_view(saved) and is_equal_approx(main.solar_rate,1.0/24.0))
		main.world.set_paused(false)
		var moving_time: float = main.world.simulation_time_s
		var moving_jd: float = main.solar_jd
		var deadline: int = Time.get_ticks_msec()+3000
		while main.world.simulation_time_s-moving_time<.6 and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		main.world.set_paused(true); await settle()
		var elapsed: float = main.world.simulation_time_s-moving_time
		check("actual near playback advances only the common one-hour date",elapsed>0.0 and absf(main.solar_jd-moving_jd-elapsed/24.0)<.000001)
		date=main.solar_jd
		measurements.append({"kind":"actual common near playback","elapsed_world_s":elapsed,"delta_tdb_days":date-moving_jd,"rate":main.solar_rate})
		main.follow_planet(2,true); await settle()
		var origin_pose: Transform3D = stage.camera.transform
		if not await travel("galaxy"): await finish(); return
		main.navigation_bar.return_to_origin()
		if not await ready_stage(): await finish(); return
		await settle()
		stage=main.coordinator.active_scene
		measurements.append({"kind":"explicit original observation return","owner":stage.get_meta("solar_physical").owner,"follow":main.solar_follow,"rate":main.solar_rate,"pose_delta":stage.camera.position.distance_to(origin_pose.origin),"camera":str(stage.camera.transform),"expected":str(origin_pose)})
		check("explicit return restores Earth camera and its slow playback together",main.world.current_scale_id=="solar_system" and int(stage.get_meta("solar_physical").owner)==2 and stage.camera.transform.is_equal_approx(origin_pose) and is_equal_approx(main.solar_rate,1.0/24.0) and main.solar_follow==2)
	main.set_solar_rate(1.0)
	if not await travel("galaxy") or not await travel("solar_system"): await finish(); return
	check("explicit manual rate survives galaxy entry",main.solar_rate==1.0 and main.solar_manual_setting and main.solar_jd==date)
	check("one World and original resource budget",main.world.get_instance_id()==world_id and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func travel(id: String) -> bool:
	if not await interaction_ready(): return false
	main.navigate_to(id)
	var requested: bool = main.coordinator.is_busy()
	var until: int = Time.get_ticks_msec()+14000
	while requested and Time.get_ticks_msec()<until:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.world.current_scale_id==id:
			await settle(); check("actual navigation arrived at "+id,true); return true
	check("actual navigation arrived at "+id,false)
	return false
