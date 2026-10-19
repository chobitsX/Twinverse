extends "res://tests/integration/life_assets_suite.gd"
const Woodland = preload("res://scripts/experience/woodland_environment.gd")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world89-check="): directory = argument.trim_prefix("--world89-check=")
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
	main.explorer_panel.hide()
	await at_time(22.0)
	var stage: Node = main.coordinator.active_scene
	var layout: Dictionary = stage.get_meta("woodland_layout")
	check("terrain, banks, rocks and understory instantiated",stage.world_root.get_node_or_null("MeanderingRiver")!=null and layout.trees>0 and layout.rocks>0 and layout.ferns>0 and stage.get_meta("grass_instances")>0)
	var banks_valid: bool = true
	for z: float in [-100.,-40.,0.,40.,100.]:
		var x: float = Woodland.river_center(z)
		banks_valid = banks_valid and Woodland.height_at(x,z)<Woodland.WATER_Y and Woodland.height_at(x-12,z)>Woodland.WATER_Y and Woodland.height_at(x+12,z)>Woodland.WATER_Y
	check("river bed stays below water and banks emerge",banks_valid)
	await capture("woodland-overview")
	stage.camera.position = Vector3(5,4,12)
	main._orbit_target = Vector3(-16,.3,-23)
	stage.camera.look_at(main._orbit_target)
	await capture("river-and-banks")
	main.follow_content(1)
	main.explorer_panel.show()
	# process_frame is emitted before Controls refresh; allow one completed UI frame.
	for frame: int in range(2): await get_tree().process_frame
	check("plant topic selects actual object",main.explorer_panel.select_topic("graze"))
	await capture("deer-landscape-topic")
	check("existing plant topic remains linked",main.learning_overlay.last_visible_marks==2)
	main.explorer_panel.select_topic("bird")
	await at_time(3.)
	await capture("bird-groundcover")
	var person_clock: float = main.world.simulation_time_s
	var materials: Array = stage.materials
	check("foliage receives host world time",is_equal_approx(float(materials[-1].get_shader_parameter("world_time")),person_clock))
	var bird: Node3D = main.content_targets()[1].node
	var old: Vector3 = bird.position
	for frame: int in range(4): await get_tree().process_frame
	check("paused time freezes bird and foliage",bird.position.distance_to(old)<.00001 and is_equal_approx(float(materials[-1].get_shader_parameter("world_time")),person_clock))
	main.explorer_panel.hide()
	main.follow_content(0)
	main.ground_light_preview = true
	main.set_solar_date(Ephemeris.DEFAULT_JD+.25)
	await capture("woodland-date-light")
	check("land lighting responds to date",stage.has_meta("sun_elevation") and is_finite(float(stage.get_meta("sun_elevation"))))
	main.ground_light_preview = false
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	stage = main.coordinator.active_scene
	check("reentry keeps deterministic habitat",stage.get_meta("woodland_layout")==layout)
	check("reentry keeps animal location",main.content_targets()[1].node.position.distance_to(old)<.0001)
	if not await arrive("city"):
		await finish()
		return
	main.explorer_panel.hide()
	await capture("city-preserved")
	check("city retains its building layout",main.coordinator.active_scene.get_meta("building_counts").size()==3)
	await finish()
