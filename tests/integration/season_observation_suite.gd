extends "res://tests/integration/life_assets_suite.gd"
const Seasons = preload("res://scripts/experience/season_observation.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world97-check="): directory = argument.trim_prefix("--world97-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
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
	if not await arrive("woodland"):
		await finish()
		return
	var panel: Node = main.explorer_panel
	panel.show()
	for frame: int in range(3): await get_tree().process_frame
	check("forest seasonal lesson is selectable",panel.select_topic("season_light") and main.ground_light_preview and main._content_follow==-1)
	var stage: Node = main.coordinator.active_scene
	var camera: Transform3D = stage.camera.transform
	var actor: Node3D = stage.get_meta("actors")[0].node
	var actor_position: Vector3 = actor.position
	var time: float = main.world.simulation_time_s
	panel.season_controls.get_child(0).pressed.emit()
	for frame: int in range(3): await get_tree().process_frame
	var summer: float = stage.get_meta("sun_elevation")
	check("summer preset drives the real forest light",summer>78 and summer<79 and stage.get_meta("daylight_sun").global_basis.z.dot(Seasons.sample(main.solar_jd,"woodland").sun)>.9999)
	await capture("woodland-june-noon")
	panel.season_controls.get_child(1).pressed.emit()
	for frame: int in range(3): await get_tree().process_frame
	check("winter light is lower at the same viewpoint",float(stage.get_meta("sun_elevation"))>31 and float(stage.get_meta("sun_elevation"))<32 and stage.camera.transform.is_equal_approx(camera))
	check("readout has date elevation daylight and source",panel.lesson_readout.text.contains("9.6 h") and panel.lesson_readout.text.contains("TDB") and panel.lesson_source.visible)
	check("date comparison preserves animals and world time",actor.position.is_equal_approx(actor_position) and main.world.simulation_time_s==time and main.solar_rate==0)
	await capture("woodland-december-noon")
	var noon_jd: float = main.solar_jd
	for hour_step: int in range(4): panel.lesson_controls.get_child(1).pressed.emit()
	for frame: int in range(3): await get_tree().process_frame
	check("hour controls reach night using the same clock",absf(main.solar_jd-noon_jd-.5)<1e-8 and float(stage.get_meta("sun_elevation"))<0 and stage.get_meta("daylight_sun").light_energy==0)
	panel.lesson_controls.get_child(2).pressed.emit()
	for frame: int in range(3): await get_tree().process_frame
	check("noon button restores daytime",float(stage.get_meta("sun_elevation"))>31 and main.solar_rate==0)
	get_window().size = Vector2i(900,650)
	for frame: int in range(4): await get_tree().process_frame
	check("compact forest controls precede objects without scrolling",panel.scroll.scroll_vertical==0 and panel.season_controls.get_global_rect().end.y<panel.get_global_rect().end.y and panel.topic_box.get_index()<panel.object_box.get_index())
	await capture("woodland-season-compact")
	get_window().size = Vector2i(1280,720)
	if not await arrive("city"):
		await finish()
		return
	panel.show()
	for frame: int in range(3): await get_tree().process_frame
	check("roof lesson retains real panel selection",panel.select_topic("solar_roof") and main._content_follow==3)
	panel.season_controls.get_child(1).pressed.emit()
	for frame: int in range(3): await get_tree().process_frame
	stage = main.coordinator.active_scene
	check("city noon respects its different longitude",absf(main.solar_jd-Seasons.preset(3,"city"))<1e-8 and float(stage.get_meta("sun_elevation"))>31 and panel.Topics.solar_sample(main).factor>0)
	get_window().size = Vector2i(900,650)
	for frame: int in range(4): await get_tree().process_frame
	check("roof time and season controls visible in compact window",panel.scroll.scroll_vertical==0 and panel.season_controls.visible and panel.season_controls.get_global_rect().end.y<panel.get_global_rect().end.y and panel.lesson_controls.get_global_rect().end.x<panel.get_global_rect().end.x)
	await capture("city-roof-winter-noon")
	if not await arrive("earth"):
		await finish()
		return
	check("normal return hides land lesson without advancing world",not panel.season_controls.visible and main.world.simulation_time_s==time)
	await finish()
