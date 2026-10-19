extends "res://tests/integration/world_expansion_suite.gd"

## Bounded source-world visual sample across seven primary branches.
var observations: Dictionary = {}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world189-audit="):
			directory = argument.trim_prefix("--world189-audit=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	check("diagnostic window excludes native focus and GUI input", get_window().unfocusable and get_viewport().gui_disable_input)
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	main._audio.volume_db = -80.0
	check("diagnostic playback is muted to existing minus80dB policy", is_equal_approx(main._audio.volume_db, -80.0))
	get_window().size = Vector2i(1280, 800)
	get_tree().create_timer(100.).timeout.connect(func() -> void:
		push_error("Stage 3 cross-branch visual sample exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.set_solar_rate(0.0)
	main.world_guide.hide()
	main.explorer_panel.hide()
	var stable_since: int = Time.get_ticks_msec()
	var startup_deadline: int = stable_since + 10000
	while Time.get_ticks_msec() - stable_since < 2000 and Time.get_ticks_msec() < startup_deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw():
			stable_since = Time.get_ticks_msec()
	var time_before: float = main.world.simulation_time_s
	var date_before: float = main.solar_jd
	for scale_id: String in ["solar_system","earth","reef","woodland","desert","city","polar"]:
		if not await arrive(scale_id):
			await finish()
			return
		main._reset_camera()
		for frame: int in range(4): await get_tree().process_frame
		await capture(scale_id + "-default")
		if scale_id == "city":
			check("human-scale city action available", not main.next_button.disabled and main.next_button.text == "走近人群")
			main.next_button.pressed.emit()
			for frame: int in range(4): await get_tree().process_frame
			await capture("city-human")
	check("all branch views keep the same paused world time", main.world.paused and main.world.simulation_time_s == time_before)
	check("all branch views keep the same diagnostic date", main.solar_jd == date_before and main.solar_rate == 0.0)
	observations = {"world_time_before_s": time_before, "world_time_after_s": main.world.simulation_time_s,
		"paused": main.world.paused, "time_scale": main.world.time_scale, "date_before_jd": date_before,
		"date_after_jd": main.solar_jd, "solar_rate": main.solar_rate,
		"native_input_disabled": get_viewport().gui_disable_input, "unfocusable": get_window().unfocusable,
		"screen_count": DisplayServer.get_screen_count(), "screen": get_window().current_screen,
		"primary_screen": DisplayServer.get_primary_screen(), "early_secondary_requested": "--preview-secondary" in OS.get_cmdline_user_args(),
		"audio_volume_db": main._audio.volume_db, "fixed_reference_light": not main.ground_light_preview,
		"branches": ["solar_system", "earth", "reef", "woodland", "desert", "city", "polar"]}
	await finish()

func finish() -> void:
	await super.finish()
	var file: FileAccess = FileAccess.open(directory.path_join("checks.json"), FileAccess.READ)
	var report: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	report["observations"] = observations
	report["native_input_tested"] = false
	report["native_ime_tested"] = false
	file = FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
