extends "res://tests/integration/world_expansion_suite.gd"
const Topics = preload("res://scripts/experience/learning_topics.gd")

func run() -> void:
	var session: String = ""
	var fixture: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world91-check="): directory = argument.trim_prefix("--world91-check=")
		if argument.begins_with("--guide-session="): session = argument.trim_prefix("--guide-session=")
		if argument.begins_with("--world-dir="): fixture = argument.trim_prefix("--world-dir=")
	if not directory.is_absolute_path() or (session.is_empty() and not "--no-save" in OS.get_cmdline_user_args()) or (not session.is_empty() and (not fixture.is_absolute_path() or not fixture.ends_with("/guide91-fixture"))):
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
	if not session.is_empty():
		await check_session(session)
		return
	check("diagnostic launch does not force first visit",not main.world_guide.visible and not main._persistence_enabled)
	var camera: Transform3D = main.coordinator.active_scene.camera.transform
	var world_time: float = main.world.simulation_time_s
	main._open_guide()
	await capture("world-guide")
	check("guide frame fits the window",main.world_guide.panel.get_rect().end.y<=720)
	print("GUIDE_LAYOUT ",main.world_guide.panel.get_rect(), " minimum=",main.world_guide.panel.get_combined_minimum_size())
	check("opening guide preserves camera, time and pause",main.coordinator.active_scene.camera.transform.is_equal_approx(camera) and main.world.simulation_time_s==world_time and main.world.paused)
	var valid: bool = true
	for button: Button in main.world_guide.route_buttons:
		var id: String = button.get_meta("guide_scale")
		var topic: String = button.get_meta("guide_topic")
		valid = valid and main.Catalog.contains(id)
		if not topic.is_empty(): valid = valid and Topics.for_scale(id).any(func(entry: Dictionary) -> bool: return entry.id==topic)
	check("every guide action maps to an existing scene and lesson",valid)
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	main._input(escape)
	check("Escape returns to observation without quitting",not main.world_guide.visible and not main._shutting_down)
	for route: Array in [["solar_system",""],["earth_moon",""],["reef","school"],["woodland","bird"],["city","traffic"],["city","solar_roof"],["fish",""],["heart",""]]:
		if not await visit(route[0],route[1]):
			await finish()
			return
		if route[1] in ["bird","solar_roof"]: await capture("guide-"+str(route[1]))
	main._open_guide()
	get_window().size = Vector2i(900,650)
	for frame: int in range(4): await get_tree().process_frame
	check("compact guide switches to one scrollable column",main.world_guide.grid.columns==1 and main.world_guide.panel.get_rect().end.x<=900 and main.world_guide.panel.get_rect().end.y<=650)
	await capture("guide-compact")
	await finish()

func visit(id: String, topic: String) -> bool:
	main._open_guide()
	var clicked: bool = false
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_scale")==id and button.get_meta("guide_topic")==topic:
			button.pressed.emit()
			clicked = true
			break
	if not clicked or not await ready_stage(): return false
	for frame: int in range(2): await get_tree().process_frame
	var arrived: bool = main.world.current_scale_id==id and not main.world_guide.visible and main.explorer_panel.visible
	check("guide enters "+id+" / "+topic,arrived)
	if not topic.is_empty(): check("actual lesson selected "+topic,main.explorer_panel._topic.get("id","")==topic and main._content_follow>=0)
	return arrived

func check_session(mode: String) -> void:
	if mode=="first":
		check("fresh fixture opens Earth and world guide",main._first_visit and main.world_guide.visible and main.world.current_scale_id=="earth")
		await capture("first-world")
		if not await visit("city","solar_roof"):
			await finish()
			return
		main.world.simulation_time_s = 123.0
		main.set_solar_date(Ephemeris.DEFAULT_JD+.125)
		main.explorer_panel.hide()
		main._content_follow = -1
		main._orbit_target = Vector3(19,4,18)
		main.coordinator.active_scene.set_pose(Vector3(24,9,26),main._orbit_target)
		check("isolated fixture saved",main.save_world(false)=="ok")
	else:
		check("existing world resumes without guide",not main._first_visit and not main.world_guide.visible and main.world.current_scale_id=="city")
		check("resume preserves time, date and camera",main.world.simulation_time_s==123.0 and is_equal_approx(main.solar_jd,Ephemeris.DEFAULT_JD+.125) and main.coordinator.active_scene.camera.position.distance_to(Vector3(24,9,26))<.001 and main._orbit_target.distance_to(Vector3(19,4,18))<.001)
		main._open_guide()
		main.world_guide.resume_button.pressed.emit()
		check("guide return preserves restored position",not main.world_guide.visible and main.coordinator.active_scene.camera.position.distance_to(Vector3(24,9,26))<.001)
	await finish()
