extends "res://tests/integration/spatial_input_suite.gd"
## Actual geometry and viewport input for the two local experiments only.
var operation_time: float

func geometry_point(root: Node3D, topic_id: String, action_id: String = "") -> Vector2:
	var stage: Node = main.coordinator.active_scene
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh==null or not mesh.is_visible_in_tree(): continue
		var at: Vector3 = mesh.global_transform*mesh.get_aabb().get_center()
		if stage.camera.is_position_behind(at): continue
		var point: Vector2 = stage.camera.unproject_position(at)
		if not Rect2(Vector2(24,180),Vector2(1232,425)).has_point(point): continue
		var hit: Dictionary = main.object_pointer.pick(point)
		if hit.get("topic","")==topic_id and hit.get("action","")==action_id: return point
	return Vector2(-1,-1)

func control_point(meta_key: String, topic_id: String, action_id: String) -> Vector2:
	var stage: Node = main.coordinator.active_scene
	var control: Dictionary = stage.get_meta(meta_key)
	var point: Vector2 = geometry_point(control.node,topic_id,action_id)
	check(meta_key+" has a real visible geometry hit",point.x>=0)
	return point

func focus_topic(id: String) -> void:
	var entries: Array[Dictionary] = main.content_targets(false)
	for i: int in range(entries.size()):
		if entries[i].get("topic","")==id:
			main.follow_content(i+1)
			main.learning_overlay.select(id)
			return

func road_and_rain() -> void:
	if not await arrive("city"): return
	main.explorer_panel.hide(); main.info_panel.hide()
	focus_topic("crossing")
	await settle()
	var stage: Node = main.coordinator.active_scene
	var signal_node: Node3D = stage.get_meta("pedestrian_signals")[0].node
	var point: Vector2 = geometry_point(signal_node,"crossing")
	check("actual pedestrian signal identifies the crossing",point.x>=0)
	if point.x>=0:
		click(point)
		await settle()
		check("signal click frames the crossing without opening a menu",main.learning_overlay.topic=="crossing" and not main.explorer_panel.visible)
		click(point,true)
		await settle()
		check("signal double click opens its current scene lesson",main.explorer_panel.visible and main.explorer_panel._topic.get("id","")=="crossing")
		await capture("city-signal-entry")
	main.explorer_panel.hide()
	focus_topic("runoff")
	await settle()
	var plot: Node3D = stage.get_meta("runoff_plots")[0].root
	point=geometry_point(plot,"runoff")
	check("actual runoff slab identifies the rain comparison",point.x>=0)
	if point.x>=0:
		click(point)
		await settle()
		check("slab click frames the experiment without opening a menu",main.learning_overlay.topic=="runoff" and not main.explorer_panel.visible)
	point=control_point("runoff_valve","runoff","runoff_rain")
	if point.x<0: return
	var rain_before: bool = main.world.runoff.raining
	operation_time=main.world.simulation_time_s
	var pose: Transform3D = stage.camera.transform
	click(point)
	await settle()
	check("valve click toggles the existing rain state",main.world.runoff.raining!=rain_before)
	check("valve operation preserves the camera and world clock",stage.camera.transform.is_equal_approx(pose) and main.world.simulation_time_s==operation_time)
	check("valve rotation and caption follow the authoritative state",is_equal_approx(stage.get_meta("runoff_valve").handle.rotation.y,PI*.5 if main.world.runoff.raining else 0.0) and stage.get_meta("runoff_valve").caption.text.contains("非真实天气"))
	# Let the ordinary world loop produce actual accumulated water.
	main.world.set_paused(false)
	await get_tree().create_timer(2.3).timeout
	main.world.set_paused(true)
	await settle()
	var state: Dictionary = main.world.runoff.snapshot()
	check("scene rain uses the existing balance and continues with world time",float(state.rain_mm)>0 and stage.get_meta("runoff_plots")[0].drops[0].visible)
	await capture("city-rain-valve")
	point=control_point("runoff_valve","runoff","runoff_rain")
	main.clean_observation.set_active(true)
	await settle()
	var total_before: float = main.world.runoff.rain_mm
	click(point)
	await settle()
	check("physical valve works in clean observation without resetting accumulated water",not main.world.runoff.raining and main.world.runoff.rain_mm==total_before and main.clean_observation.active)
	main.clean_observation.set_active(false)
	main.world_guide.show()
	click(point)
	check("guide modal blocks experiment clicks",not main.world.runoff.raining)
	main.world_guide.hide()
	main.world.set_foreground(false)
	click(point)
	check("background window blocks experiment clicks",not main.world.runoff.raining)
	main.world.set_foreground(true)
	main.info_panel.show()
	click(main.info_panel.get_global_rect().get_center())
	check("GUI input does not operate a valve behind a panel",not main.world.runoff.raining)
	main.info_panel.hide()
	var camera_before: Transform3D = stage.camera.transform
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position=point; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true;dispatch(press)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position=point+Vector2(18,0);motion.relative=Vector2(18,0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;dispatch(motion)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.position=motion.position;release.button_index=MOUSE_BUTTON_LEFT;dispatch(release)
	await settle()
	check("dragging a valve rotates the scene and never operates it",not main.world.runoff.raining and not stage.camera.transform.is_equal_approx(camera_before))
	main.observe_scale("woodland")
	click(point)
	check("in-flight clicks do not change the experiment",not main.world.runoff.raining)
	await ready_stage()

func fence_and_return() -> void:
	if main.world.current_scale_id!="woodland" and not await arrive("woodland"): return
	main.explorer_panel.hide();main.info_panel.hide()
	focus_topic("browse")
	await settle()
	var stage: Node = main.coordinator.active_scene
	var right: Node3D = stage.get_meta("browse_plots")[1].root
	var point: Vector2 = geometry_point(right,"browse")
	check("protected reference has a visible model hit",point.x>=0)
	if point.x>=0:
		click(point)
		await settle()
		check("reference selection opens no menu and changes no protection",not main.explorer_panel.visible and not main.world.browse.protected_left)
	point=control_point("browse_latch","browse","browse_protection")
	if point.x<0: return
	var stock: Array = main.world.browse.snapshot().stock.duplicate()
	operation_time=main.world.simulation_time_s
	click(point)
	await settle()
	check("physical latch protects only the left teaching plot",main.world.browse.protected_left and stage.get_meta("browse_plots")[1].cage.visible)
	check("latch operation preserves stocks and world time",main.world.browse.snapshot().stock==stock and main.world.simulation_time_s==operation_time)
	check("latch caption and lever present the current protection",stage.get_meta("browse_latch").caption.text.contains("保护") and is_zero_approx(stage.get_meta("browse_latch").lever.rotation.z))
	await capture("woodland-protected-latch")
	main.clean_observation.set_active(true)
	await settle()
	click(point)
	await settle()
	check("clean-view latch reopens the left plot and preserves the reference",not main.world.browse.protected_left and stage.get_meta("browse_plots")[1].cage.visible)
	main.clean_observation.set_active(false)
	await capture("woodland-open-latch")
	click(point)
	await settle()
	check("first click of a complete double sequence operates the latch",main.world.browse.protected_left)
	click(point,true)
	await settle()
	check("second half of a physical double click does not operate it twice",main.world.browse.protected_left)
	var rain: Dictionary = main.world.runoff.snapshot()
	var browse: Dictionary = main.world.browse.snapshot()
	if await arrive("city"):
		check("returning to city keeps the same rain and vegetation models",main.world.runoff.snapshot()==rain and main.world.browse.snapshot()==browse)
		focus_topic("runoff")
		await settle()
		check("re-entered valve rebuilds from the saved world state",main.coordinator.active_scene.get_meta("runoff_valve").caption.text.contains("关") and not main.world.runoff.raining)
		var free_position: Vector3 = main.coordinator.active_scene.camera.position
		var free_target: Vector3 = main._orbit_target
		main._clear_observation_selection()
		main.explorer_panel.hide()
		# Keep the same visible local free-camera pose, without an object selection.
		main.coordinator.active_scene.set_pose(free_position,free_target)
		main._orbit_target=free_target
		await settle()
		point=control_point("runoff_valve","runoff","runoff_rain")
		if point.x>=0:
			click(point)
			await settle()
			check("first click on an unfocused valve frames without changing rain",not main.world.runoff.raining and main.learning_overlay.topic=="runoff")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world253-review="): directory=argument.trim_prefix("--world253-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true;get_viewport().gui_disable_input=true;get_window().size=Vector2i(1280,800)
	get_tree().create_timer(100).timeout.connect(func() -> void:get_tree().quit(2))
	main=Experience.instantiate();add_child(main)
	if DisplayServer.get_name()!="headless":main._measurement_screen=get_window().current_screen
	if is_instance_valid(main._audio):main._audio.volume_db=-80
	main._reduced_motion=true;main.world.set_paused(true);main.set_solar_rate(0)
	main.world_guide.hide();main.guided_journey.hide();main.explorer_panel.hide()
	if not await ready_stage():await finish();return
	original_id=main.world.get_instance_id();original_jd=main.solar_jd
	await road_and_rain()
	await fence_and_return()
	check("local actions retain the sole world date pause and target identity",main.world.get_instance_id()==original_id and main.solar_jd==original_jd and main.world.paused and main.world.snapshot().target_fish_id==main.WorldState.TARGET_FISH_ID)
	await finish()

func finish() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"viewport_input_routed":true,"native_os_gestures_tested":false,"performance_test":false,"world_id":main.world.get_instance_id(),"original_world_id":original_id,"date_jd":main.solar_jd,"original_date_jd":original_jd,"paused":main.world.paused,"no_save":not main._persistence_enabled},"\t"))
	print("SPATIAL_EXPERIMENTS_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
