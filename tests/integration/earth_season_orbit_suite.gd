extends "res://tests/integration/solar_orbit_views_suite.gd"
## Limited actual-window observation; original model values, no save or performance test.
const Seasons = preload("res://scripts/experience/season_observation.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
var sample_sets: Array[Dictionary] = []

func reference_sample(label: String) -> void:
	var stage: Node = main.coordinator.active_scene
	var data: Dictionary = stage.get_meta("earth_season_orbit")
	var good: bool = data.active and data.root.visible and data.samples.size()==4
	var values: Array[Dictionary] = []
	var left: float = main.explorer_panel.get_global_rect().end.x+6.0
	for index: int in range(data.samples.size()):
		var entry: Dictionary = data.samples[index]
		var jd: float = Seasons.preset(index,"earth")
		var expected: Vector3 = Ephemeris.display_position(2,jd,main.solar_true_distance)
		var pole: Vector3 = Orientation.body_basis(2,jd).y
		var point: Vector2 = stage.camera.unproject_position(entry.node.position)
		good = good and entry.jd==jd and entry.node.position.distance_to(expected)<1e-6 and entry.pole.distance_to(pole)<1e-6
		good = good and entry.sun.distance_to(Orientation.sun_direction(jd))<1e-6
		good = good and not stage.camera.is_position_behind(entry.node.position) and point.x>left+20 and point.x<get_window().size.x-30 and point.y>155 and point.y<get_window().size.y-135
		values.append({"jd":jd,"position":[expected.x,expected.y,expected.z],"pole":[pole.x,pole.y,pole.z],"dot_north_sun":pole.dot(entry.sun),"north_hours":Orientation.latitude_daylight_hours(35,jd),"south_hours":Orientation.latitude_daylight_hours(-35,jd),"distance_au":Ephemeris.position_au(2,jd).length(),"screen_xy":[point.x,point.y]})
	check(label+" four actual references match old positions axes sun and visible viewport",good)
	check(label+" June and December north sunlight and daylight reverse",values[1].dot_north_sun>0.35 and values[3].dot_north_sun<-.35 and values[1].north_hours>values[1].south_hours and values[3].north_hours<values[3].south_hours)
	var hud: Array[Dictionary] = main.learning_overlay.last_season_labels
	var fits: bool = hud.size()==4
	var rects: Array[Rect2] = []
	var tags: Array[Dictionary] = []
	for item: Dictionary in hud:
		var rect: Rect2 = item.rect
		fits = fits and rect.position.x>left and rect.end.x<get_window().size.x and rect.position.y>=120 and rect.end.y<=get_window().size.y-135
		for other: Rect2 in rects: fits = fits and not rect.intersects(other)
		rects.append(rect)
		tags.append({"date_index":item.date_index,"font_size":item.font_size,"text":item.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	check(label+" four fixed-size date and north labels remain legible",hud.size()==4 and hud.all(func(item: Dictionary) -> bool: return item.font_size>=16 and item.text.ends_with(" · N")))
	check(label+" date labels avoid panel HUD and one another",fits)
	sample_sets.append({"view":label,"true_distance":main.solar_true_distance,"selected_jd":main.solar_jd,"samples":values,"date_labels":tags})

func panel_fits() -> bool:
	var panel: Node = main.explorer_panel
	var controls: Node = panel.earth_season_controls
	var clip: Rect2 = panel.scroll.get_global_rect().grow(.5)
	var good: bool = clip.encloses(panel.earth_season_toggle.get_global_rect())
	for button: Button in controls.date_buttons: good = good and clip.encloses(button.get_global_rect())
	return good and clip.encloses(controls.readout.get_global_rect()) and clip.encloses(controls.earth_button.get_global_rect()) and clip.encloses(controls.distance.get_global_rect())

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world246-review="): directory=argument.trim_prefix("--world246-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size=Vector2i(1280,800)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	get_tree().create_timer(75.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage(): await finish(); return
	get_window().size=Vector2i(1280,800)
	main._audio.volume_db=-80
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world.set_time_scale(2)
	main.world.simulation_time_s=12
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.set_solar_rate(1)
	main.world_guide.hide()
	main.explorer_panel.show()
	await settle()
	var authority: int = main.world.get_instance_id()
	var core: Dictionary = core_checkpoint()
	var stage: Node = main.coordinator.active_scene
	var identities: Array[int] = body_ids()
	var original: Array[Vector3] = body_positions()
	var panel: Node = main.explorer_panel
	panel.earth_season_toggle.pressed.emit()
	await settle()
	check("actual season action retains original dated world and eight model identities",panel.earth_season_controls.visible and main.solar_jd==Ephemeris.DEFAULT_JD and main.solar_rate==1 and body_ids()==identities and body_positions()==original)
	check("wide date controls and readouts fit",panel_fits())
	reference_sample("season-orbit-wide")
	await capture("season-orbit-wide")
	for index: int in range(4):
		panel.earth_season_controls.date_buttons[index].pressed.emit()
		await settle()
		check("actual reference date %d uses original preset and stops date playback only" % index,main.solar_jd==Seasons.preset(index,"earth") and main.solar_rate==0 and main.world.simulation_time_s==12 and main.world.paused and positions_match_date())
		if index in [1,3]: await capture("season-june" if index==1 else "season-december")
	get_window().size=Vector2i(900,650)
	panel.earth_season_controls.date_buttons[1].pressed.emit()
	await settle()
	check("compact date controls and readouts fit",panel_fits())
	reference_sample("season-orbit-compact")
	await capture("season-orbit-compact")
	get_window().size=Vector2i(1280,800)
	panel.earth_season_controls.distance.set_pressed_no_signal(true)
	panel.earth_season_controls.distance.toggled.emit(true)
	await settle()
	reference_sample("season-orbit-true-distance")
	check("true-distance original bodies remain unchanged at the original data positions",positions_match_date() and body_ids()==identities)
	await capture("season-orbit-true-distance")
	main.learning_overlay.enabled=false
	await settle()
	check("helper off hides references and restores original planet nodes",not stage.get_meta("earth_season_orbit").root.visible and stage.get_meta("solar_bodies")[2].node.visible and main.learning_overlay.last_season_labels.is_empty())
	main.learning_overlay.enabled=true
	await settle()
	check("helper on restores same date samples without authority writes",stage.get_meta("earth_season_orbit").root.visible and main.solar_jd==Seasons.preset(1,"earth") and core_checkpoint()==core)
	panel.earth_season_toggle.pressed.emit()
	await settle()
	check("actual exit restores eight original planets and all original controls",not panel.earth_season_controls.visible and panel.body_picker.visible and stage.get_meta("solar_bodies").all(func(body: Dictionary) -> bool: return body.node.visible) and body_ids()==identities and positions_match_date() and main.learning_overlay.last_season_labels.is_empty())
	await capture("season-original-solar")
	panel.earth_season_toggle.pressed.emit()
	await settle()
	var jd: float = main.solar_jd
	panel.earth_season_controls.earth_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	check("actual same-date Earth entry opens existing daylight with original authority",main.world.current_scale_id=="earth" and main.learning_overlay.topic=="earth_daylight" and main.solar_jd==jd and main.world.get_instance_id()==authority)
	await capture("season-earth-daylight")
	if not await arrive("solar_system"): await finish(); return
	await settle()
	check("solar return clears references and restores original world and date",not main.explorer_panel.earth_season_controls.visible and not main.coordinator.active_scene.has_meta("earth_season_orbit") and positions_match_date() and core_checkpoint()==core and main.world.simulation_time_s==12 and main.world.paused and main.world.time_scale==2 and main.solar_jd==jd)
	check("two worker 30 foreground 5 diagnostic and save resource limits remain",int(ProjectSettings.get_setting("threading/worker_pool/max_threads"))==2 and Engine.max_fps==5 and main._render_ratio==.75 and not main._persistence_enabled and get_window().unfocusable and get_viewport().gui_disable_input)
	observations={"samples":sample_sets,"world_time_s":main.world.simulation_time_s,"paused":main.world.paused,"time_scale":main.world.time_scale,"date_jd":main.solar_jd,"solar_rate":main.solar_rate,"authority_unchanged":main.world.get_instance_id()==authority,"core_unchanged":core_checkpoint()==core,"named_species":41,"guide_routes":93,"worker_pool_threads":2,"max_fps":Engine.max_fps,"foreground_fps":ProjectSettings.get_setting("application/run/max_fps"),"render_ratio":main._render_ratio,"audio_volume_db":main._audio.volume_db,"persistence_enabled":main._persistence_enabled,"user_save_accessed":false,"native_input_disabled":get_viewport().gui_disable_input,"unfocusable":get_window().unfocusable}
	await finish()

func finish() -> void:
	var output: FileAccess = FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"status":"completed","cases":cases,"failures":failures,"captures":captures,"observations":observations,"capture_window_settings":view_settings,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false},"  ")+"\n")
	output.close()
	print("EARTH_SEASON246_FINISHED ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
