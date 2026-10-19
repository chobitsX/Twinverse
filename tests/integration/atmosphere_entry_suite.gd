extends "res://tests/integration/spatial_input_suite.gd"
## The reported missing introduction, real gesture/landmark routes and saved tour.
const OLD_WORLD_ROUTE: Array[String] = ["solar_system", "earth", "reef", "woodland", "desert", "city", "polar", "earth"]
var visited: Array[String] = []
var globe_samples: Array[Dictionary] = []

func ready_stage() -> bool:
	var deadline: int = Time.get_ticks_msec() + (32000 if main.coordinator._target_id in ["pacific", "reef", "woodland", "city"] else 14000)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground:
			if DisplayServer.get_name() == "headless" or DisplayServer.window_can_draw(): return true
	print("ATMOSPHERE_ENTRY_UNAVAILABLE ", JSON.stringify({"scale":main.world.current_scale_id,"target":main.coordinator._target_id,"phase":main.coordinator.phase,"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw(),"loading":main.coordinator.loading_status()}))
	check("stage ready", false)
	return false

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.pressed = down
		dispatch(event)

func earth() -> bool:
	if not await arrive("earth"): return false
	main._reset_camera()
	main.earth_entry_panel.clear_selection()
	main.info_panel.hide()
	main.explorer_panel.hide()
	main.guided_journey.hide()
	await settle()
	return true

func landmark(id: String) -> Vector2:
	var panel: Node = main.earth_entry_panel
	var site: Dictionary = panel.Sites.for_scale(id)
	main.coordinator.active_scene.set_pose(panel.Sites.normal(site.lat, site.lon) * 9.6, Vector3.ZERO)
	main._orbit_target = Vector3.ZERO
	await settle()
	panel.refresh_points()
	check(id + " actual landmark is visible", panel.points.has(id))
	return panel.points[id].pixel if panel.points.has(id) else Vector2(-1,-1)

func boundary(destination: String, inward: bool) -> bool:
	for step: int in range(8):
		magnify(2.0 if inward else .5)
		if main.coordinator.is_busy(): break
	check("gesture boundary requests " + destination, main.coordinator.is_busy() and main.coordinator._target_id == destination)
	if not main.coordinator.is_busy(): return false
	if not await ready_stage(): return false
	check("gesture arrives " + destination, main.world.current_scale_id == destination)
	visited.append(main.world.current_scale_id)
	return main.world.current_scale_id == destination

func free_ocean() -> void:
	if not await earth(): return
	var before: float = radius()
	magnify(1.04)
	check("unselected Earth first zooms continuously", radius() < before and not main.coordinator.is_busy())
	main.world_guide.show()
	var pose: Transform3D = main.coordinator.active_scene.camera.transform
	magnify(2.0)
	check("guide modal blocks default atmosphere approach", not main.coordinator.is_busy() and main.coordinator.active_scene.camera.transform.is_equal_approx(pose))
	main.world_guide.hide()
	main.world.set_foreground(false)
	magnify(2.0)
	check("background blocks default atmosphere approach", not main.coordinator.is_busy() and main.coordinator.active_scene.camera.transform.is_equal_approx(pose))
	main.world.set_foreground(true)
	if not await boundary("atmosphere", true): return
	check("original atmosphere has cloud pass and curved Earth", main.coordinator.active_scene.has_meta("cloud_render_pass") and main.coordinator.active_scene.world_root.find_child("CurvedEarthFarSurface", true, false) != null)
	check("visible atmosphere introduction explains observation entry and limits", main.science_badge.is_visible_in_tree() and main.science_badge.text.contains("地平线") and main.science_badge.text.contains("非当前天气") and main.science_badge.text.contains("海面"))
	await capture("atmosphere-introduction")
	if not await boundary("earth", false): return
	check("atmosphere returns to Earth rather than leaving the planet", main.observation_parent("atmosphere") == "earth")
	if not await earth(): return
	var point: Vector2 = await landmark("reef")
	if point.x < 0: return
	click(point)
	await settle()
	check("ocean sign selects without skipping the introduction", main.earth_entry_panel.selected == "reef" and not main.coordinator.is_busy())
	check("ocean card describes atmosphere and sea before reef", main.earth_entry_panel.footnote.text.contains("大气 → 海面 → 珊瑚礁"))
	await capture("earth-ocean-route")
	main.clean_observation.set_active(true)
	click(point, true)
	check("actual ocean landmark enters atmosphere in clean observation", main.coordinator.is_busy() and main.coordinator._target_id == "atmosphere")
	if not await ready_stage(): return
	check("ocean landmark arrives at the original atmosphere", main.world.current_scale_id == "atmosphere")
	if not await boundary("pacific", true): return
	check("sea retains atmosphere as its observation parent", main.observation_parent("pacific") == "atmosphere")
	await capture("sea-surface")
	if not await boundary("reef", true): return
	check("reef retains sea as its observation parent", main.observation_parent("reef") == "pacific")
	if not await boundary("pacific", false): return
	if not await boundary("atmosphere", false): return
	if not await boundary("earth", false): return
	if not await earth(): return
	point = await landmark("reef")
	if point.x < 0: return
	click(point)
	key(KEY_ENTER)
	check("Enter on the selected ocean sign also enters atmosphere", main.coordinator.is_busy() and main.coordinator._target_id == "atmosphere")
	if not await ready_stage(): return
	if not await earth(): return
	point = await landmark("woodland")
	if point.x < 0: return
	click(point)
	if not await boundary("woodland", true): return
	check("land sign retains its direct regional route", main.observation_parent("woodland") == "earth")
	await boundary("earth", false)

func progress_migration() -> void:
	var guide: Node = main.guided_journey
	var original: Dictionary = guide.checkpoint()
	for old_step: int in range(OLD_WORLD_ROUTE.size()):
		var value: Dictionary = {"version":1,"step":3,"started":true,"completed":false,"active_route":"world","world_tour":{"version":1,"step":old_step,"started":true,"completed":old_step == 7}}
		guide.restore(JSON.parse_string(JSON.stringify(value)))
		check("old tour stop %d keeps its actual destination" % old_step, guide.route_id == "world" and guide.route[guide.step] == OLD_WORLD_ROUTE[old_step] and guide.completed == (old_step == 7))
		var saved: Dictionary = guide.checkpoint()
		check("old tour stop %d persists mapped progress and original life route" % old_step, saved.step == 3 and saved.version == 1 and saved.world_tour.route_revision == 2)
		guide.restore(JSON.parse_string(JSON.stringify(saved)))
		check("mapped tour stop %d survives JSON roundtrip" % old_step, guide.route_id == "world" and guide.route[guide.step] == OLD_WORLD_ROUTE[old_step])
	guide.restore({"version":1,"step":3,"started":true,"completed":false})
	check("legacy life-only preference stays on its original 25 steps", guide.route_id == "life" and guide.step == 3 and guide.route.size() == 25)
	guide.restore({"version":1,"step":3,"started":true,"completed":false,"active_route":"world","world_tour":{"version":1,"route_revision":true,"step":1,"started":true,"completed":false}})
	check("malformed tour revision preserves the valid life preference", guide.route_id == "life" and guide.step == 3)
	guide.restore(original)

func record_globe(_request: int, progress: float) -> void:
	if not is_instance_valid(main._outgoing) or not is_instance_valid(main._incoming): return
	var pair: String = main._outgoing.scale_id + ":" + main._incoming.scale_id
	if pair not in ["earth:atmosphere", "atmosphere:earth"]: return
	var globe: Node = main._outgoing if main._outgoing.scale_id == "earth" else main._incoming
	globe_samples.append({"pair":pair,"progress":progress,"radius":globe.camera.position.length()})

func opposite_flight() -> void:
	if not await earth(): return
	var normal: Vector3 = main.earth_entry_panel.Sites.normal(main.earth_entry_panel.Sites.REEF_LAT, main.earth_entry_panel.Sites.REEF_LON)
	main.coordinator.active_scene.set_pose(-normal * 9.6, Vector3.ZERO)
	main._orbit_target = Vector3.ZERO
	main._reduced_motion = false
	main.coordinator.authoring_progress.connect(record_globe)
	if not await boundary("atmosphere", true): return
	if not await boundary("earth", false): return
	main.coordinator.authoring_progress.disconnect(record_globe)
	var enters: int = 0
	var exits: int = 0
	var smallest: float = INF
	for sample: Dictionary in globe_samples:
		if sample.pair == "earth:atmosphere": enters += 1
		else: exits += 1
		smallest = minf(smallest, sample.radius)
	check("opposite-side atmosphere entry and return sample real authored motion", enters >= 3 and exits >= 3)
	check("opposite-side atmosphere flight stays outside the original globe", smallest >= 3.0)
	check("atmosphere return restores the original opposite Earth direction", main.coordinator.active_scene.camera.position.normalized().dot(-normal) > .99)
	main._reduced_motion = true

func tour() -> void:
	if not await earth(): return
	var guide: Node = main.guided_journey
	guide.restore({"version":1,"step":0,"started":false,"completed":false,"active_route":"world","world_tour":{"version":1,"step":1,"started":true,"completed":false}})
	guide.open("world")
	guide.advance_button.pressed.emit()
	check("Earth tour next requests atmosphere before marine life", main.coordinator.is_busy() and main.coordinator._target_id == "atmosphere" and guide.pending == 2)
	if not await ready_stage(): return
	await settle()
	check("tour commits the atmosphere introduction in its real scene", guide.step == 2 and guide.route[2] == "atmosphere" and guide.heading.text.contains("大气") and guide.description.text.contains("地平线") and guide.boundary.text.contains("不是当前天气"))
	get_window().size = Vector2i(900,650)
	await settle()
	await capture("atmosphere-tour-narrow")
	get_window().size = Vector2i(1280,800)
	await settle()
	guide.lesson_button.pressed.emit()
	await settle()
	check("atmosphere free observation has the existing tour return", main.explorer_panel.visible and main.explorer_panel.journey_return_button.is_visible_in_tree() and guide.has_lesson_return())
	main.explorer_panel.journey_return_button.pressed.emit()
	await settle()
	check("returning to atmosphere tour retains its stop", guide.visible and guide.step == 2 and guide.pending == -1 and main.world.current_scale_id == "atmosphere")
	guide.advance_button.pressed.emit()
	check("tour proceeds from introduction to the original reef", main.coordinator.is_busy() and main.coordinator._target_id == "reef" and guide.pending == 3)
	if not await ready_stage(): return
	await settle()
	check("reef keeps its original lesson at the shifted tour stop", guide.step == 3 and guide.WORLD_LESSONS[3].topic == "algae")
	guide.suspend()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world256-review="): directory = argument.trim_prefix("--world256-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	get_window().size = Vector2i(1280,800)
	get_tree().create_timer(95).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless": main._measurement_screen = get_window().current_screen
	if is_instance_valid(main._audio): main._audio.volume_db = -80
	main._reduced_motion = true
	main.world.set_paused(true)
	main._refresh_observation_controls()
	main.set_solar_rate(0)
	main.world_guide.hide()
	main.explorer_panel.hide()
	main.guided_journey.hide()
	if not await ready_stage(): await finish(); return
	original_id = main.world.get_instance_id()
	original_time = main.world.simulation_time_s
	original_jd = main.solar_jd
	await free_ocean()
	progress_migration()
	await opposite_flight()
	await tour()
	check("restored introduction preserves one world time date pause and target", main.world.get_instance_id() == original_id and main.world.simulation_time_s == original_time and main.world.paused and main.solar_jd == original_jd and main.world.snapshot().target_fish_id == main.WorldState.TARGET_FISH_ID)
	await finish()

func finish() -> void:
	FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"visited":visited,"globe_samples":globe_samples,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"display":DisplayServer.get_name(),"viewport_input_routed":true,"native_os_gestures_tested":false,"performance_test":false,"world_id":main.world.get_instance_id(),"original_world_id":original_id,"date_jd":main.solar_jd,"original_date_jd":original_jd,"world_time_s":main.world.simulation_time_s,"original_world_time_s":original_time,"paused":main.world.paused,"no_save":not main._persistence_enabled},"\t"))
	print("ATMOSPHERE_ENTRY_FINISHED ", failures)
	main._quit(0 if failures.is_empty() else 1)
