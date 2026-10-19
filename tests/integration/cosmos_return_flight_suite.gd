extends "res://tests/integration/world_expansion_suite.gd"
## Finite actual-scene checks for directional camera motion and view recovery.
var progress: float = 0.0
var motion_samples: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var observations: Dictionary = {}
var minimum_earth_ratio: float = INF

func core_checkpoint() -> Dictionary:
	var value: Dictionary = main.world.checkpoint()
	value.erase("current_scale_id")
	value.erase("local_habitat")
	return value

func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen == DisplayServer.get_primary_screen(): continue
		if get_window().current_screen != screen:
			get_window().current_screen = screen
			get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30, 30)
		main._measurement_screen = screen
		break
	for frame: int in range(2): await get_tree().process_frame

func authoring_ready() -> bool:
	var deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if main.coordinator.phase == main.Coordinator.Phase.AUTHORING:
			await get_tree().process_frame
			return true
		if not main.coordinator.is_busy(): break
	check("macro authoring starts", false)
	return false

func sample(_request: int, amount: float) -> void:
	progress = amount
	if not is_instance_valid(main._outgoing) or not is_instance_valid(main._incoming): return
	if main._outgoing.scale_id in ["earth", "solar_system"] and main._incoming.scale_id in ["earth", "solar_system"]:
		for stage: Node in [main._outgoing, main._incoming]:
			var center: Vector3 = Vector3.ZERO
			var radius: float = 3.0
			if stage.scale_id == "solar_system":
				var planet: MeshInstance3D = stage.get_meta("solar_bodies")[2].node
				center = planet.global_position
				radius = float(planet.mesh.radius) * absf(planet.scale.x)
			minimum_earth_ratio = minf(minimum_earth_ratio, stage.camera.global_position.distance_to(center) / radius)
	motion_samples.append({"pair":str(main._outgoing.scale_id) + ":" + str(main._incoming.scale_id),
		"progress":amount,"world_time_s":main.world.simulation_time_s,
		"out_position":var_to_str(main._outgoing.camera.position),
		"in_position":var_to_str(main._incoming.camera.position),"blend":main._progress_alpha})

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var status: Error = get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	check("capture " + label, status == OK)
	captures.append(label + ".png")
	frames.append({"file":label + ".png","progress":progress,"phase":main.coordinator.phase,
		"scale":main.world.current_scale_id,"screen":get_window().current_screen,
		"primary":DisplayServer.get_primary_screen(),"screen_count":DisplayServer.get_screen_count(),
		"window_size":[get_window().size.x,get_window().size.y],"ratio":main._render_ratio})

func flight_frame(label: String, amount: float) -> void:
	while main.coordinator.is_busy() and progress < amount: await get_tree().process_frame
	await capture(label)

func earth_disk(stage: Node) -> Array[Vector2]:
	var center: Vector3 = Vector3.ZERO
	var radius: float = 3.0
	if stage.scale_id == "solar_system":
		var planet: MeshInstance3D = stage.get_meta("solar_bodies")[2].node
		center = planet.global_position
		radius = float(planet.mesh.radius) * absf(planet.scale.x)
	return [stage.camera.unproject_position(center), stage.camera.unproject_position(center + stage.camera.global_basis.x * radius)]

func fly(target: String, label: String, entering: bool, capture_frame: bool = true) -> bool:
	progress = 0.0
	main.navigate_to(target)
	if not await authoring_ready(): return false
	var outgoing: Node = main._outgoing
	var incoming: Node = main._incoming
	var out_anchor: Vector3 = outgoing.target_position if entering else outgoing.default_target
	var in_anchor: Vector3 = incoming.default_target if entering else incoming.target_position
	var out_start: float = main._out_start.position.distance_to(out_anchor)
	var out_end: float = main._out_end.position.distance_to(out_anchor)
	var in_start: float = main._in_start.position.distance_to(in_anchor)
	var in_end: float = main._in_end.position.distance_to(in_anchor)
	check(label + " moves toward the child or away to the parent", out_end < out_start if entering else out_end > out_start)
	check(label + " reveals the destination in the same direction", in_end < in_start if entering else in_end > in_start)
	main.loading_status.refresh()
	check(label + " exposes the authored scene without the loading modal", not main.loading_status.visible and not main.title_label.visible and not main.science_badge.visible)
	if capture_frame:
		await flight_frame(label + "-boundary", .42)
	else:
		while main.coordinator.is_busy() and progress < .42: await get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	if outgoing.scale_id in ["earth", "solar_system"] and incoming.scale_id in ["earth", "solar_system"]:
		var out_disk: Array[Vector2] = earth_disk(outgoing)
		var in_disk: Array[Vector2] = earth_disk(incoming)
		check(label + " matches both Earth disks at the visible boundary", progress >= .42 and progress <= .58 and out_disk[0].distance_to(in_disk[0]) < .1 and out_disk[1].distance_to(in_disk[1]) < .1)
	if not await ready_stage(): return false
	check(label + " arrives without a final camera snap", main.world.current_scale_id == target and main.coordinator.active_scene.camera.position.distance_to(main._in_end.position) < .0001)
	return true

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world251-macro-check="): directory = argument.trim_prefix("--world251-macro-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	get_window().size = Vector2i(1280, 800)
	get_tree().create_timer(95).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless": main._measurement_screen = get_window().current_screen
	if is_instance_valid(main._audio): main._audio.volume_db = -80
	main.world.set_paused(true)
	main._refresh_observation_controls()
	main.set_solar_rate(0)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await ready_stage(): await finish(); return
	await settle()
	check("actual galaxy starts with the sole authoritative world", main.world.current_scale_id == "galaxy" and main.scene_host.get_child_count() == 1)
	var galaxy: Node = main.coordinator.active_scene
	if "--world251-directions-only" in OS.get_cmdline_user_args():
		var galaxy_entry: Dictionary = galaxy.entry_pose("solar_system")
		check("return to galaxy begins near the solar-system anchor", galaxy_entry.position.distance_to(galaxy.target_position) < galaxy.default_position.distance_to(galaxy.default_target) * .15)
		main._reduced_motion = true
		main.navigate_to("solar_system")
		if not await ready_stage(): await finish(); return
		var solar: Node = main.coordinator.active_scene
		var solar_exit: Dictionary = solar.exit_pose("galaxy")
		var solar_entry: Dictionary = solar.entry_pose("earth")
		check("solar-system departure to galaxy increases viewing distance", solar_exit.position.distance_to(solar.default_target) > solar.default_position.distance_to(solar.default_target))
		check("return to solar system starts near the original Earth", solar_entry.position.distance_to(solar.target_position) < solar.default_position.distance_to(solar.default_target) * .1)
		observations["directions"] = {"galaxy_entry":var_to_str(galaxy_entry.position),"solar_exit":var_to_str(solar_exit.position),"solar_entry":var_to_str(solar_entry.position),"earth_anchor":var_to_str(solar.target_position)}
		await finish()
		return
	main._reduced_motion = false
	main.coordinator.authoring_progress.connect(sample)
	var authority: int = main.world.get_instance_id()
	var date: float = main.solar_jd
	var checkpoint: Dictionary = core_checkpoint()
	main._orbit_target = Vector3(.3, 0, .5)
	galaxy.set_pose(Vector3(10, 10, 25), main._orbit_target)
	var galaxy_position: Vector3 = galaxy.camera.position
	var galaxy_target: Vector3 = main._orbit_target
	var galaxy_up: Vector3 = galaxy.camera.basis.y
	if not await fly("solar_system", "galaxy-to-solar", true): await finish(); return
	var solar: Node = main.coordinator.active_scene
	main._orbit_target = Vector3.ZERO
	solar.set_pose(Basis(Vector3.UP, .2) * solar.default_position, main._orbit_target)
	var solar_position: Vector3 = solar.camera.position
	var solar_up: Vector3 = solar.camera.basis.y
	if not await fly("earth", "solar-to-earth", true): await finish(); return
	await capture("earth-arrived")
	var earth: Node = main.coordinator.active_scene
	# Exercise a real opposite-side orbit; a straight return chord crosses Earth.
	main._orbit_target = Vector3.ZERO
	earth.set_pose(-earth.builder.anchor_basis().y * 9.4, main._orbit_target)
	var earth_position: Vector3 = earth.camera.position
	var earth_target: Vector3 = main._orbit_target
	var earth_up: Vector3 = earth.camera.basis.y
	progress = 0.0
	main.navigate_to("solar_system")
	if not await authoring_ready(): await finish(); return
	while main.coordinator.is_busy() and progress < .18: await get_tree().process_frame
	main.coordinator.cancel("macro_flight_short_check")
	if not await ready_stage(): await finish(); return
	check("cancel restores the same Earth camera and sole scene", main.coordinator.active_scene == earth and main.scene_host.get_child_count() == 1 and earth.camera.position.distance_to(earth_position) < .0001 and main._orbit_target.distance_to(earth_target) < .0001 and earth.camera.basis.y.distance_to(earth_up) < .0001)
	check("cancel restores the normal scene captions", main.title_label.visible and main.science_badge.visible)
	if not await fly("solar_system", "earth-to-solar", false): await finish(); return
	check("return to solar system restores the saved view", main.coordinator.active_scene.camera.position.distance_to(solar_position) < .0001 and main._orbit_target.is_zero_approx() and main.coordinator.active_scene.camera.basis.y.distance_to(solar_up) < .0001)
	main.set_solar_distance(true)
	await settle()
	var true_earth: MeshInstance3D = main.coordinator.active_scene.get_meta("solar_bodies")[2].node
	check("true-distance branch uses the original smaller display Earth", absf(true_earth.scale.x - .16) < .0001)
	if not await fly("earth", "true-distance-solar-to-earth", true, false): await finish(); return
	if not await fly("solar_system", "true-distance-earth-to-solar", false, false): await finish(); return
	main.set_solar_distance(false)
	await settle()
	# The existing distance control intentionally resets to the standard view.
	solar_position = main.coordinator.active_scene.camera.position
	if not await fly("galaxy", "solar-to-galaxy", false): await finish(); return
	check("return to galaxy restores the saved view", main.coordinator.active_scene.camera.position.distance_to(galaxy_position) < .0001 and main._orbit_target.distance_to(galaxy_target) < .0001 and main.coordinator.active_scene.camera.basis.y.distance_to(galaxy_up) < .0001)
	await capture("galaxy-restored")
	main._reduced_motion = true
	main.navigate_to("solar_system")
	if not await ready_stage(): await finish(); return
	check("reduced motion reaches the original solar-system view", main.world.current_scale_id == "solar_system" and main.coordinator.active_scene.camera.position.distance_to(solar_position) < .0001)
	main.navigate_to("galaxy")
	if not await ready_stage(): await finish(); return
	check("reduced motion returns to the original galaxy view", main.world.current_scale_id == "galaxy" and main.coordinator.active_scene.camera.position.distance_to(galaxy_position) < .0001)
	check("macro roundtrip preserves date pause world and core state", main.world.get_instance_id() == authority and main.world.paused and core_checkpoint() == checkpoint and main.solar_jd == date)
	check("opposite-side and both distance modes stay outside the displayed Earth", minimum_earth_ratio >= 1.05)
	observations = {"world_id":main.world.get_instance_id(),"original_world_id":authority,"date_jd":main.solar_jd,"original_date_jd":date,"paused":main.world.paused,"persistence_enabled":main._persistence_enabled,"audio_volume_db":main._audio.volume_db if is_instance_valid(main._audio) else null,"native_input_disabled":get_viewport().gui_disable_input,"unfocusable":get_window().unfocusable}
	await finish()

func finish() -> void:
	FileAccess.open(directory.path_join("macro-samples.json"), FileAccess.WRITE).store_string(JSON.stringify({"samples":motion_samples,"frames":frames,"observations":observations,"minimum_earth_ratio":minimum_earth_ratio}, "\t"))
	await super.finish()
