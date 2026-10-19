extends "res://tests/integration/land_lighting_suite.gd"

## Bounded, no-save Metal views of the real city park and its existing routes.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world186-review="):
			directory = argument.trim_prefix("--world186-review=")
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
		push_error("City park ground short check exceeded bounded runtime")
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
	var cover: Dictionary = stage.get_meta("city_park_ground_cover", {})
	var people: int = 0
	var cars: int = 0
	for actor: Dictionary in stage.get_meta("actors", []):
		if actor.kind == "person": people += 1
		if actor.kind == "car": cars += 1
	check("city still has 28 people and 12 cars", people == 28 and cars == 12)
	var anonymous_canopies: int = 0
	var complete_crowns: bool = true
	var crown_names: Array[String] = []
	for node: Node in stage.world_root.get_children():
		if not node.is_in_group("city_anonymous_canopy"): continue
		anonymous_canopies += 1
		var leaves: Node = node.find_child("CrownLeaves",true,false)
		if crown_names.size() < 4: crown_names.append("%s:%s" % [node.get_meta("canopy_variant",""),leaves.name if leaves!=null else "missing"])
		complete_crowns = complete_crowns and node.get_meta("canopy_variant","") in ["broadleaf_a","broadleaf_b"] and leaves is MeshInstance3D
	comparisons.city_canopy = {"count":anonymous_canopies,"complete":complete_crowns,"samples":crown_names}
	check("existing park and street tree sites use complete anonymous crowns",anonymous_canopies>=20 and complete_crowns)
	check("park cover exists as one bounded batched draw", not cover.is_empty() and cover.count == 700 and cover.node is MultiMeshInstance3D)
	if cover.is_empty():
		await finish()
		return
	var multimesh: MultiMesh = cover.node.multimesh
	var clear: bool = true
	for index: int in range(multimesh.instance_count):
		var at: Vector3 = multimesh.get_instance_transform(index).origin
		if at.x <= 12.0 or at.x >= 54.0 or at.z <= 12.0 or at.z >= 54.0 or absf(at.x - 33.0) < 2.6 or absf(at.z - 33.0) < 2.6 or (at.x > 38.0 and at.x < 50.0 and at.z > 39.0 and at.z < 49.0):
			clear = false
			break
	check("ground cover leaves central paths pond and perimeter clear", clear)
	await capture("city-park-overview")
	check("existing human-scale park action is available", not main.next_button.disabled and main.next_button.text == "走近人群")
	main.next_button.pressed.emit()
	await settle()
	check("human-scale view keeps the same people and world time", main._city_people_view and stage.get_meta("actors", []).size() == 40 and main.world.simulation_time_s == 9.)
	await capture("city-park-human-view")
	stage.set_pose(Vector3(45.5, 1.65, 25.0), Vector3(39.5, 0.2, 25.0))
	await settle()
	await capture("city-park-lawn-close")
	await at_time(13.)
	check("one authoritative world time still advances existing city actors", main.world.simulation_time_s == 13. and stage.get_meta("actors", []).size() == 40 and stage.get_meta("city_park_ground_cover", {}).node == cover.node)
	await finish()
