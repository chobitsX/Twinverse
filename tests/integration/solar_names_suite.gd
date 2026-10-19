extends "res://tests/integration/observation_framing_suite.gd"
## Bounded observation check of labels on the real camera and existing objects.
var observations: Dictionary = {}
var samples: Array[Dictionary] = []

func core_checkpoint() -> Dictionary:
	var value: Dictionary = main.world.checkpoint()
	value.erase("current_scale_id")
	value.erase("local_habitat")
	return value

func sample_names(label: String, required: Array[int] = []) -> void:
	var overlay: Node = main.learning_overlay
	var stage: Node = main.coordinator.active_scene
	var camera: Camera3D = stage.camera
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var ids: Array[int] = []
	var records: Array[Dictionary] = []
	var rectangles: Array[Rect2] = []
	var projected: bool = true
	var clear: bool = true
	var unclipped: bool = true
	var texts: bool = true
	for item: Dictionary in overlay.last_solar_labels:
		var index: int = item.index
		var node: Node3D = stage.world_root.get_node("Sun_AuthoredPhotosphere") if index < 0 else stage.get_meta("solar_bodies")[index].node
		var at: Vector2 = camera.unproject_position(node.global_position)
		var rect: Rect2 = item.rect
		projected = projected and not camera.is_position_behind(node.global_position) and viewport_rect.has_point(at) and at.distance_to(item.at) < .75
		unclipped = unclipped and viewport_rect.encloses(rect) and rect.position.y > 130.0 and rect.end.y < viewport_rect.end.y-190.0
		texts = texts and item.text == ("太阳" if index < 0 else Ephemeris.NAMES[index])
		for previous: Rect2 in rectangles: clear = clear and not rect.grow(2.0).intersects(previous)
		for panel: Rect2 in overlay.solar_reserved_rects: clear = clear and not rect.grow(2.0).intersects(panel)
		ids.append(index)
		rectangles.append(rect)
		records.append({"index":index,"name":item.text,"anchor_px":[at.x,at.y],"rect_px":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	var complete: bool = true
	for index: int in required: complete = complete and ids.has(index)
	check(label+" actual names point to forward visible bodies",projected and texts and not ids.is_empty())
	check(label+" names avoid each other panels and HUD",clear and unclipped)
	check(label+" required names remain readable",complete and overlay.last_solar_font_size >= 16)
	samples.append({"view":label,"window_px":[get_window().size.x,get_window().size.y],"jd":main.solar_jd,"true_distance":main.solar_true_distance,"orbit_focus":main.solar_orbit_focus,"follow":main.solar_follow,"font_size":overlay.last_solar_font_size,"labels":records,"projection_valid":projected,"rectangles_clear":clear,"unclipped":unclipped,"required_names_present":complete})

func body_positions() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for body: Dictionary in main.coordinator.active_scene.get_meta("solar_bodies"): points.append(body.node.position)
	return points

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world228-review="): directory = argument.trim_prefix("--world228-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size = Vector2i(1280,800)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	check("diagnostic cannot consume desktop focus or input",get_window().unfocusable and get_viewport().gui_disable_input)
	get_tree().create_timer(110.0).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	if not await ready_stage():
		await finish(); return
	main._audio.volume_db = -80.0
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world.set_time_scale(2.0)
	main.set_solar_rate(0.0)
	main.world_guide.hide()
	await at_time(12.0)
	var baseline: Dictionary = core_checkpoint()
	var authority: int = main.world.get_instance_id()
	if not await arrive("solar_system"):
		await finish(); return
	main.set_solar_date(2461299.5)
	await settle()
	var stage: Node = main.coordinator.active_scene
	var original_points: Array[Vector3] = body_positions()
	var all_names: Array[int] = [-1,0,1,2,3,4,5,6,7]
	sample_names("ordinary overview",all_names)
	await capture("names-overview")
	var old_hidden: bool = true
	for body: Dictionary in stage.get_meta("solar_bodies"): old_hidden = old_hidden and not body.label.visible
	check("old three-dimensional names cannot duplicate screen labels",old_hidden)
	main._open_guide()
	main.world_guide.world_tour_button.pressed.emit()
	if not await ready_stage():
		await finish(); return
	await settle()
	check("actual optional world tour begins on the same solar scene",main.guided_journey.visible and main.guided_journey.step==0 and main.world.current_scale_id=="solar_system")
	sample_names("world tour overview",all_names)
	await capture("names-world-tour")
	get_window().size = Vector2i(900,650)
	await settle()
	sample_names("compact world tour",all_names)
	await capture("names-world-tour-compact")
	main.guided_journey.pause_button.pressed.emit()
	get_window().size = Vector2i(1280,800)
	await settle()
	check("guide and resize do not reposition planets or replace authority",body_positions()==original_points and main.world.get_instance_id()==authority and core_checkpoint()==baseline and main.solar_jd==2461299.5)
	main.set_solar_date(2418673.34)
	await settle()
	sample_names("historic date",all_names)
	check("date changes actual positions without changing world seconds",body_positions()!=original_points and main.world.simulation_time_s==12.0)
	await capture("names-historic-date")
	main.set_solar_date(2461299.5)
	main.set_solar_distance(true)
	await settle()
	sample_names("true distance overview",[-1,4,5,6,7])
	var true_ids: Array[int] = []
	for item: Dictionary in main.learning_overlay.last_solar_labels: true_ids.append(item.index)
	check("true-distance names preserve original inner-planet visibility policy",not true_ids.has(0) and not true_ids.has(1) and not true_ids.has(2) and not true_ids.has(3))
	await capture("names-true-distance")
	main.explorer_panel.show()
	get_window().size = Vector2i(900,650)
	main.focus_planet_orbit(0)
	await settle()
	sample_names("compact Mercury selected orbit",[0])
	var selected_ids: Array[int] = []
	for item: Dictionary in main.learning_overlay.last_solar_labels:
		if item.index >= 0: selected_ids.append(item.index)
	check("selected-orbit labels retain only the selected planet",selected_ids==[0])
	await capture("names-mercury-orbit-compact")
	get_window().size = Vector2i(1280,800)
	main.set_solar_distance(false)
	main.follow_planet(5)
	await settle()
	sample_names("Saturn close view",[5])
	await capture("names-saturn-close")
	main.explorer_panel.select_topic("mercury_orbit")
	await settle()
	sample_names("Mercury equal-area lesson",[0])
	check("existing four equal-area lesson labels remain available",main.learning_overlay.last_visible_marks==4)
	await capture("names-kepler-lesson")
	main.explorer_panel.markers_toggle.set_pressed_no_signal(false)
	main.explorer_panel.markers_toggle.toggled.emit(false)
	await settle()
	check("actual helper control hides both names and lesson marks",not main.learning_overlay.enabled and main.learning_overlay.last_solar_labels.is_empty() and main.learning_overlay.last_visible_marks==0)
	main.explorer_panel.markers_toggle.set_pressed_no_signal(true)
	main.explorer_panel.markers_toggle.toggled.emit(true)
	await settle()
	check("helper control restores names on the same world",main.learning_overlay.last_solar_labels.size()>0 and main.learning_overlay.last_visible_marks==4 and core_checkpoint()==baseline)
	main.explorer_panel.clear_topic()
	main.explorer_panel.hide()
	main.follow_planet(-1)
	await settle()
	var before_clean: Array[Vector3] = body_positions()
	main.clean_button.pressed.emit()
	await settle()
	check("pure observation hides projected and old names without moving bodies",main.clean_observation.active and not main.hud.visible and main.learning_overlay.last_solar_labels.is_empty() and body_positions()==before_clean and main.solar_jd==2461299.5)
	await capture("names-clean-observation")
	main.clean_observation.exit_button.pressed.emit()
	await settle()
	check("returning from pure view restores all nine names",main.hud.visible and main.learning_overlay.last_solar_labels.size()==9)
	var position: Vector3 = stage.camera.position
	stage.set_pose(position,position+stage.camera.basis.z*100.0)
	await settle()
	check("looking away does not draw names of objects behind the camera",main.learning_overlay.last_solar_labels.is_empty())
	main._reset_observation_view()
	await settle()
	check("resetting real camera recovers the visible names",main.learning_overlay.last_solar_labels.size()==9)
	check("name controls preserve date rate and the sole paused world",main.world.get_instance_id()==authority and core_checkpoint()==baseline and main.world.simulation_time_s==12.0 and main.world.time_scale==2.0 and main.world.paused and main.solar_jd==2461299.5 and main.solar_rate==0.0)
	if not await arrive("earth"):
		await finish(); return
	await settle()
	check("return to Earth removes solar names and retains one world",main.learning_overlay.last_solar_labels.is_empty() and main.earth_entry_panel.visible and main.world.get_instance_id()==authority and core_checkpoint()==baseline and main.solar_jd==2461299.5)
	await capture("names-earth-return")
	observations={"samples":samples,"world_time_s":main.world.simulation_time_s,"world_time_scale":main.world.time_scale,"date_jd":main.solar_jd,"solar_rate":main.solar_rate,"core_models_unchanged":core_checkpoint()==baseline,"authority_unchanged":main.world.get_instance_id()==authority,"comparison_excludes":["current_scale_id","local_habitat"],"window_screen":get_window().current_screen,"primary_screen":DisplayServer.get_primary_screen(),"screen_count":DisplayServer.get_screen_count(),"native_input_disabled":get_viewport().gui_disable_input}
	await finish()

func finish() -> void:
	var report: Dictionary={"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"ephemeris_accuracy_revalidated":false}
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SOLAR_NAMES_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
