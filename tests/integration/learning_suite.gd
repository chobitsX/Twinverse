extends "res://tests/integration/life_assets_suite.gd"
const Topics = preload("res://scripts/experience/learning_topics.gd")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world88-check="): directory = argument.trim_prefix("--world88-check=")
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
	if not await arrive("reef"):
		await finish()
		return
	main.explorer_panel.show()
	await at_time(19.0)
	await get_tree().process_frame
	var panel: Node = main.explorer_panel
	check("object selector visible before scrolling",panel.scroll.scroll_vertical==0 and panel.object_picker.get_global_rect().end.y<panel.get_global_rect().end.y)
	check("topic selector visible before scrolling",panel.topic_picker.get_global_rect().end.y<panel.get_global_rect().end.y)
	check("food topic selects its live object",panel.select_topic("algae") and main._content_follow==0)
	await capture("reef-food-topic")
	check("food source and live marks",panel.lesson_source.visible and main.learning_overlay.last_visible_marks==2)
	panel.markers_toggle.set_pressed(false)
	await get_tree().process_frame
	await get_tree().process_frame
	check("annotations can be disabled",not main.learning_overlay.enabled and main.learning_overlay.last_visible_marks==0)
	panel.markers_toggle.set_pressed(true)
	check("school topic selects live fish group",panel.select_topic("school") and main._content_follow==2)
	await capture("school-topic")
	check("ray structure topic",panel.select_topic("ray") and main._content_follow==4)
	await capture("ray-structure")
	check("three ray structure markers",main.learning_overlay.last_visible_marks==3)
	if not await arrive("woodland"):
		await finish()
		return
	panel.show()
	await at_time(22.0)
	check("plant relation selects herbivore",panel.select_topic("graze") and main._content_follow==0)
	await capture("deer-plant-topic")
	check("plant relation has two labels",main.learning_overlay.last_visible_marks==2)
	await at_time(3.0)
	check("bird topic selects correct object",panel.select_topic("bird") and main._content_follow==1)
	await capture("bird-structure")
	var marker_count: int = main.learning_overlay.last_visible_marks
	await at_time(33.0)
	check("topic reads actual flight state",Topics.readout(main,"bird").contains("飞行"))
	await capture("bird-flight-topic")
	check("bird labels track ground and flight",marker_count==3 and main.learning_overlay.last_visible_marks==3)
	if not await arrive("city"):
		await finish()
		return
	panel.show()
	await at_time(39.0)
	check("traffic topic follows a car",panel.select_topic("traffic") and main._content_follow==1)
	await capture("traffic-topic")
	check("traffic describes signal phase",Topics.readout(main,"traffic")=="信号：纵向放行 / 横向等待")
	check("street topic selects architecture",panel.select_topic("street") and main._content_follow==2)
	await capture("street-topic")
	check("roof topic activates date lighting",panel.select_topic("solar_roof") and main.ground_light_preview and main._content_follow==3)
	var stage: Node = main.coordinator.active_scene
	var building: Node3D = stage.get_meta("urban_targets")[1].node
	var normal: Vector3 = building.get_meta("solar_normal_world",Vector3.ZERO)
	check("panel normal comes from actual tilted mesh",normal.dot(building.global_basis*Vector3(0,cos(.16),sin(.16)))>.9999)
	main.set_solar_rate(0)
	var sun_time: float = Ephemeris.DEFAULT_JD
	for fraction: float in [0.0,.25,.5,.75]:
		if stage.builder.Orientation.local_sun(Ephemeris.DEFAULT_JD+fraction,35,120).y>.4:
			sun_time = Ephemeris.DEFAULT_JD+fraction
			break
	main.set_solar_date(sun_time)
	await get_tree().process_frame
	await capture("roof-sunlight")
	check("roof time controls visible without scrolling",panel.scroll.scroll_vertical==0 and panel.lesson_controls.get_global_rect().end.y<panel.get_global_rect().end.y)
	var previous_jd: float = main.solar_jd
	panel.lesson_controls.get_child(1).pressed.emit()
	await get_tree().process_frame
	check("roof time button advances exactly three hours",absf(main.solar_jd-previous_jd-.125)<1e-9)
	main.set_solar_date(sun_time)
	var day: Dictionary = Topics.solar_sample(main)
	check("daytime projection is bounded and positive",day.factor>0 and day.factor<=1)
	main.set_solar_date(sun_time+.5)
	await get_tree().process_frame
	await capture("roof-night")
	var night: Dictionary = Topics.solar_sample(main)
	check("night projection zero",night.factor==0.0 and not night.above_horizon)
	check("astronomy lesson does not age biological world",is_equal_approx(main.world.simulation_time_s,39.0))
	panel.object_picker.item_selected.emit(1)
	await get_tree().process_frame
	check("manual object selection clears lesson markers",main.learning_overlay.topic.is_empty() and main._content_follow==0)
	main._navigate_relative(-1)
	if not await ready_stage():
		await finish()
		return
	check("lesson leaves through normal navigation",main.world.current_scale_id=="earth")
	if not await arrive("solar_system"):
		await finish()
		return
	panel.show()
	for frame: int in range(3): await get_tree().process_frame
	check("planet picker visible before scrolling",panel.scroll.scroll_vertical==0 and panel.body_picker.get_global_rect().end.y<panel.get_global_rect().end.y)
	panel.body_picker.item_selected.emit(3)
	await get_tree().process_frame
	check("planet picker still follows Earth",main.solar_follow==2)
	await capture("solar-selector")
	await finish()
