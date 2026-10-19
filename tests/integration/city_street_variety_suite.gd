extends "res://tests/integration/land_lighting_suite.gd"

## Short real-Metal check for the existing nine-shop block and park views.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world188-review="):
			directory = argument.trim_prefix("--world188-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	get_window().unfocusable = true
	get_window().size = Vector2i(1280, 800)
	get_tree().create_timer(100.).timeout.connect(func() -> void:
		push_error("City street variety short check exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	var stable_since: int = Time.get_ticks_msec()
	var startup_deadline: int = stable_since + 10000
	while Time.get_ticks_msec() - stable_since < 2000 and Time.get_ticks_msec() < startup_deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw():
			stable_since = Time.get_ticks_msec()
	if not await arrive("city"):
		await finish()
		return
	await at_time(9.)
	main._reset_camera()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var storeys: Dictionary = stage.get_meta("shop_floor_counts", {})
	check("nine shops split across two three four storeys", storeys == {2:3,3:3,4:3})
	var placements_and_panels: bool = true
	var roof_heights: Dictionary = {2:[],3:[],4:[]}
	for x: int in range(-3,0):
		for z: int in range(1,4):
			var shop: Node3D = stage.world_root.get_node_or_null("CityBuilding_%d_%d" % [x,z]) as Node3D
			if shop == null:
				placements_and_panels = false
				continue
			var floors: int = int(shop.get_meta("architecture_storeys",0))
			if not roof_heights.has(floors) or not shop.has_meta("solar_anchor_world") or not shop.has_meta("solar_normal_world"):
				placements_and_panels = false
				continue
			var anchor: Vector3 = shop.get_meta("solar_anchor_world")
			var normal: Vector3 = shop.get_meta("solar_normal_world")
			roof_heights[floors].append(anchor.y)
			placements_and_panels = placements_and_panels and shop.position.is_equal_approx(Vector3(x*18,.16,z*18)) and normal.y > .5
	check("existing shop lots and actual solar panels preserved", placements_and_panels)
	var ordered: bool = true
	for floors: int in [2,3,4]:
		ordered = ordered and roof_heights[floors].size() == 3
	if ordered:
		ordered = roof_heights[2].max() < roof_heights[3].min() and roof_heights[3].max() < roof_heights[4].min()
	check("roof elevations come from distinct full-floor meshes", ordered)
	check("same city population and teaching state", stage.get_meta("building_counts") == {"shops":9,"homes":10,"offices":8} and stage.get_meta("actors",[]).size() == 40 and main.world.simulation_time_s == 9.)
	await capture("city-block-varied-overview")
	check("human-scale action remains available", not main.next_button.disabled and main.next_button.text == "走近人群")
	main.next_button.pressed.emit()
	await settle()
	check("human-scale view keeps authoritative time", main._city_people_view and main.world.simulation_time_s == 9.)
	await capture("city-block-varied-human-view")
	stage.set_pose(Vector3(13.0,7.5,31.0),Vector3(-36.0,7.0,31.0))
	await settle()
	await capture("city-block-varied-street-view")
	await at_time(13.)
	check("existing actors still use one world time", main.world.simulation_time_s == 13. and stage.get_meta("actors",[]).size() == 40)
	await finish()
