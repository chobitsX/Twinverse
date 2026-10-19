extends "res://tests/integration/solar_closeup_suite.gd"
## Reproduce a continuous gesture crossing the close-to-overview return flight.

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--zoom283-output="): directory=argument.trim_prefix("--zoom283-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(85.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80.0
	if not await ready_stage() or not await interaction_ready(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	prepare_auto(); main.follow_planet(2); await settle()
	var stage: Node=main.coordinator.active_scene
	zoom_out("pinch")
	await settle()
	check("Earth first widens to its same-system co-frame",Framing.is_pair(stage) and main.world.current_scale_id=="solar_system")
	main._reduced_motion=false
	zoom_out("pinch")
	check("co-frame starts a return flight within the solar system",main.solar_follow<0 and not main._solar_camera_motion.is_empty() and not main.coordinator.is_busy())
	zoom_out("pinch")
	check("remaining pinch packets cannot skip the solar overview",not main.coordinator.is_busy() and main.world.current_scale_id=="solar_system" and not main._solar_camera_motion.is_empty())
	measurements.append({"kind":"continuous close zoom","scale":main.world.current_scale_id,"busy":main.coordinator.is_busy(),"camera":str(stage.camera.position),"target":str(main._orbit_target),"motion":str(main._solar_camera_motion)})
	if "--zoom283-baseline" in OS.get_cmdline_user_args() or not failures.is_empty(): await finish(); return
	var identity: int=main.world.get_instance_id()
	var date: float=main.solar_jd
	var held: bool=true
	for frame: int in range(12):
		zoom_out(["pinch","pan","wheel"][frame%3])
		held=held and not main.coordinator.is_busy() and main.world.current_scale_id=="solar_system"
		await get_tree().process_frame
	check("continuous pinch/pan/wheel finishes overview without leaving it",held and overview(stage))
	check("overview restores global rate and preserves date and pause",main.solar_rate==10.0 and main.solar_jd==date and main.world.paused)
	await capture("earth-return-overview")
	await get_tree().create_timer(.35).timeout
	zoom_out("pinch"); zoom_out("pinch")
	if not await ready_stage(): await finish(); return
	check("a fresh outward gesture from overview can enter the galaxy",main.world.current_scale_id=="galaxy")
	if not await travel("solar_system"): await finish(); return
	stage=main.coordinator.active_scene
	main._reduced_motion=true
	for index: int in range(10):
		prepare_auto()
		if index<8: main.follow_planet(index)
		else: main.follow_content(index-7)
		await settle()
		var label: String=main.Ephemeris.NAMES[index] if index<8 else "Sun" if index==8 else "Moon"
		var reached: bool=false
		for packet: int in range(16):
			zoom_out(["wheel","pinch","pan"][index%3])
			if main.coordinator.is_busy(): break
			if main.solar_follow<0 and main._content_follow<0 and int(stage.get_meta("solar_physical").owner)<0:
				reached=true; break
		for packet: int in range(5): zoom_out("pinch")
		check(label+" zoom first lands at solar overview even with reduced motion",reached and not main.coordinator.is_busy() and overview(stage))
		check(label+" keeps the shared date and returns the automatic rate",main.solar_jd==date and main.solar_rate==10.0 and main.world.paused)
		if main.coordinator.is_busy(): await finish(); return
	# Optical look-around must also have a way back out; it must not stick at 80°.
	main.follow_planet(2); await settle()
	main.look_solar_context(8); await settle()
	zoom_out("pan"); zoom_out("pan"); zoom_out("pan")
	check("optical look-around zooms out to solar overview",overview(stage) and not main.coordinator.is_busy())
	# Existing manual speed, true-distance preference, and the observer-only frame survive.
	main.set_solar_rate(1.0); main.set_solar_distance(true); main.follow_planet(5); await settle()
	for packet: int in range(6): zoom_out("wheel")
	check("AU preference and manual speed survive close zoom return",overview(stage) and main.solar_true_distance and main.solar_rate==1.0 and main.solar_manual_setting and main.solar_jd==date)
	main.set_solar_distance(false)
	# Reverse input during the flight adjusts its endpoint instead of cancelling at large coordinates.
	main.follow_planet(2); main.frame_satellite_system(2,"",false); await settle()
	main._reduced_motion=false
	zoom_out("pinch")
	var original_finish: Vector3=main._solar_camera_motion.finish
	main._zoom_camera(stage,.8)
	check("reverse pinch retargets the return without a galaxy jump",main._solar_camera_motion.has("overview_return") and Vector3(main._solar_camera_motion.finish).length()<original_finish.length() and not main.coordinator.is_busy())
	await flight("reversed overview return")
	check("reverse arrival stays finite and within solar overview",stage.camera.position.is_finite() and main.world.current_scale_id=="solar_system" and main.solar_follow<0 and int(stage.get_meta("solar_physical").owner)<0)
	# Fresh selection should immediately release a previous gesture guard.
	main._reduced_motion=true; main.follow_planet(5); await settle()
	left_drag(Vector2(35,-10)); zoom_out("pinch")
	check("new planet selection remains immediately draggable and zoomable",Framing.is_pair(stage) and int(Framing.state(stage).owner)==5)
	await capture("saturn-zoom-coframe")
	zoom_out("pinch"); zoom_out("pinch")
	check("Saturn co-frame also returns to solar overview first",overview(stage) and not main.coordinator.is_busy())
	check("one World, no-save and original resource budget",main.world.get_instance_id()==identity and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func overview(stage: Node) -> bool:
	return main.world.current_scale_id=="solar_system" and main.solar_follow<0 and main._content_follow<0 and int(stage.get_meta("solar_physical",{}).get("owner",-1))<0 and not Framing.is_pair(stage) and main._solar_camera_motion.is_empty() and stage.camera.position.distance_to(stage.default_position)<.001 and main._orbit_target.distance_to(stage.default_target)<.001

func zoom_out(device: String) -> void:
	var point: Vector2=get_viewport().get_visible_rect().size*Vector2(.45,.4)
	if device=="pinch":
		var event: InputEventMagnifyGesture=InputEventMagnifyGesture.new()
		event.position=point; event.factor=.5; main._unhandled_input(event)
	elif device=="pan":
		var event: InputEventPanGesture=InputEventPanGesture.new()
		event.position=point; event.delta=Vector2(0,4.6); main._unhandled_input(event)
	else:
		var event: InputEventMouseButton=InputEventMouseButton.new()
		event.position=point; event.button_index=MOUSE_BUTTON_WHEEL_DOWN; event.factor=4.0; event.pressed=true
		main._unhandled_input(event)
