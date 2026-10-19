extends "res://tests/integration/land_lighting_suite.gd"
## Bounded Metal check of the real selected-planet orbit camera, not an ephemeris test.

const DATES: Array[float] = [2461299.5, 2418673.34] # 2026-09-16 and a 1910 sample

func _project_bounds(camera: Camera3D, points: Array[Vector3]) -> Dictionary:
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var all_forward: bool = true
	for point: Vector3 in points:
		all_forward = all_forward and not camera.is_position_behind(point)
		var pixel: Vector2 = camera.unproject_position(point)
		minimum.x = minf(minimum.x, pixel.x)
		minimum.y = minf(minimum.y, pixel.y)
		maximum.x = maxf(maximum.x, pixel.x)
		maximum.y = maxf(maximum.y, pixel.y)
	return {"min": minimum, "max": maximum, "forward": all_forward}

func _mesh_points(node: MeshInstance3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var bounds: AABB = node.get_aabb()
	for corner: int in range(8):
		points.append(node.to_global(bounds.get_endpoint(corner)))
	return points

func _body_points(body: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if body.node is MeshInstance3D:
		points.append_array(_mesh_points(body.node))
	for item: Node in body.node.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = item as MeshInstance3D
		if mesh.visible and mesh.mesh != null: points.append_array(_mesh_points(mesh))
	for extra: MeshInstance3D in body.extras:
		if extra.visible and extra.mesh != null: points.append_array(_mesh_points(extra))
	return points

func _sample(stage: Node, index: int, date_jd: float, true_distance: bool) -> Dictionary:
	var body: Dictionary = stage.get_meta("solar_bodies")[index]
	var path: MeshInstance3D = stage.world_root.get_node("SelectedDE440Trajectory")
	var points: Array[Vector3] = []
	for point: Vector3 in path.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		points.append(path.to_global(point))
	var orbit: Dictionary = _project_bounds(stage.camera, points)
	var planet: Dictionary = _project_bounds(stage.camera, _body_points(body))
	var viewport: Vector2 = stage.camera.get_viewport().get_visible_rect().size
	var safe_left: float = main.explorer_panel.get_global_rect().end.x + 16.0
	var safe_top: float = 112.0
	var safe_right: float = viewport.x - 22.0
	var safe_bottom: float = viewport.y - 104.0
	var orbit_safe: bool = orbit.forward and orbit.min.x >= safe_left and orbit.max.x <= safe_right and orbit.min.y >= safe_top and orbit.max.y <= safe_bottom
	var body_safe: bool = planet.forward and planet.min.x >= safe_left and planet.max.x <= safe_right and planet.min.y >= safe_top and planet.max.y <= safe_bottom
	return {"planet": index, "jd": date_jd, "true_distance": true_distance,
		"orbit": orbit, "body": planet, "safe": [safe_left, safe_top, safe_right, safe_bottom],
		"orbit_safe": orbit_safe, "body_safe": body_safe}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world187-review="):
			directory = argument.trim_prefix("--world187-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	get_window().unfocusable = true
	get_window().size = Vector2i(1280, 800)
	get_tree().create_timer(125.).timeout.connect(func() -> void:
		push_error("Solar orbit framing short check exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.set_solar_rate(0.)
	main.world_guide.hide()
	main.explorer_panel.show()
	var stable_since: int = Time.get_ticks_msec()
	var startup_deadline: int = stable_since + 10000
	while Time.get_ticks_msec() - stable_since < 2000 and Time.get_ticks_msec() < startup_deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw():
			stable_since = Time.get_ticks_msec()
	if not await arrive("solar_system"):
		await finish()
		return
	await at_time(9.)
	main.explorer_panel.body_picker.item_selected.emit(6)
	await settle()
	main.explorer_panel.orbit_view_button.pressed.emit()
	await settle()
	check("UI opens Saturn's actual orbit view", main.solar_orbit_focus == 5)
	var stage: Node = main.coordinator.active_scene
	var world_time: float = main.world.simulation_time_s
	var samples: Array[Dictionary] = []
	for mode: bool in [false, true]:
		main.set_solar_distance(mode)
		for date_jd: float in DATES if not mode else [DATES[0]]:
			main.set_solar_date(date_jd)
			for index: int in range(8):
				main.focus_planet_orbit(index)
				await settle()
				var sample: Dictionary = _sample(stage, index, date_jd, mode)
				samples.append(sample)
				if not sample.orbit_safe or not sample.body_safe:
					print("SOLAR_FRAME_UNSAFE ", JSON.stringify(sample))
				if not mode and date_jd == DATES[0] and index == 5:
					await capture("saturn-orbit-safe-frame")
				if not mode and date_jd == DATES[0] and index == 7:
					await capture("neptune-orbit-safe-frame")
				if not mode and date_jd == DATES[1] and index == 4:
					await capture("jupiter-historic-safe-frame")
				if mode and index == 0:
					await capture("mercury-true-distance-frame")
	comparisons["solar_frame_samples"] = samples
	var all_safe: bool = true
	for sample: Dictionary in samples:
		all_safe = all_safe and sample.orbit_safe and sample.body_safe
	check("all sampled planets and DE440 paths remain outside the panel and HUD", all_safe and samples.size() == 24)
	get_window().size = Vector2i(900, 650)
	await settle()
	main.set_solar_distance(false)
	main.set_solar_date(DATES[0])
	main.focus_planet_orbit(5)
	await settle()
	var compact: Dictionary = _sample(stage, 5, DATES[0], false)
	comparisons["compact_saturn"] = compact
	check("compact window still holds Saturn and its selected orbit", compact.orbit_safe and compact.body_safe)
	await capture("saturn-orbit-compact-frame")
	var trajectory: MeshInstance3D = stage.world_root.get_node("SelectedDE440Trajectory")
	check("camera review preserves the one world time and orbit sources", main.world.simulation_time_s == world_time and trajectory.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 257 and stage.get_meta("solar_bodies")[5].orbit.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > 0)
	await finish()
