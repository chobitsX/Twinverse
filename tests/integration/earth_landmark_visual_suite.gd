extends "res://tests/integration/spatial_input_suite.gd"
## Capture the reported view and reuse existing input/transition helpers only.
var layout: Array[Dictionary] = []

func pose_region(id: String, distance: float) -> void:
	var panel: Node = main.earth_entry_panel
	var site: Dictionary = panel.Sites.for_scale(id)
	main.coordinator.active_scene.set_pose(panel.Sites.normal(site.lat, site.lon) * distance, Vector3.ZERO)
	main._orbit_target = Vector3.ZERO
	await settle()
	panel.refresh_points()

func record_caption(id: String, label: String) -> Vector2:
	var stage: Node = main.coordinator.active_scene
	var entry: Dictionary = stage.get_meta("earth_entry_markers")[id]
	var point: Vector2 = stage.camera.unproject_position(entry.label.position)
	var sign_point: Vector2 = main.earth_entry_panel.points[id].pixel
	layout.append({"view":label,"sign_pixel":[sign_point.x,sign_point.y],"caption_pixel":[point.x,point.y],"hit_radius":main.earth_entry_panel.points[id].radius,"caption_visible":entry.label.visible,"window_size":[get_window().size.x,get_window().size.y]})
	check(label + " caption starts clear of landmark hit area", absf(point.x - sign_point.x) > float(main.earth_entry_panel.points[id].radius) + 6.0)
	return point

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--marker-output="): directory = argument.trim_prefix("--marker-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(70).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	main._audio.volume_db = -80
	main.world.set_paused(true)
	main.set_solar_rate(0.0)
	main._reduced_motion = true
	get_window().size = Vector2i(1280,800)
	if not await ready_stage(): await finish(); return
	var authority: int = main.world.get_instance_id()
	var before: Dictionary = main.world.checkpoint()
	var date: float = main.solar_jd
	original_id = authority
	original_time = main.world.simulation_time_s
	original_jd = date
	var panel: Node = main.earth_entry_panel
	main.explorer_panel.hide()
	main.info_panel.hide()
	panel.clear_selection()
	panel.hovered = ""
	await settle()
	await capture("earth-overview")
	for id: String in panel.ORDER:
		await pose_region(id,9.6)
		check(id + " original regional landmark remains pickable", panel.points.has(id) and panel.pick(panel.points[id].pixel) == id)
	check("back hemisphere remains excluded", not panel.points.has("city") and not panel.points.has("desert"))
	await pose_region("city",5.7)
	cursor(panel.points.city.pixel)
	await settle()
	var caption_pixel: Vector2 = record_caption("city","city-close-hover")
	await capture("city-close-hover")
	click(caption_pixel + Vector2(32,0))
	check("read-only name does not select a region", panel.selected.is_empty() and not main.coordinator.is_busy())
	click(panel.points.city.pixel)
	await settle()
	check("city landmark still selects original teaching entry", panel.selected == "city" and panel.card_kind.text.contains("非实地地址") and not main.coordinator.is_busy())
	var before_zoom: float = radius()
	magnify(1.04)
	check("selected landmark preserves continuous pinch", radius() < before_zoom and not main.coordinator.is_busy())
	get_window().size = Vector2i(900,650)
	await settle()
	record_caption("city","city-compact-selected")
	await capture("city-compact-selected")
	main.clean_observation.set_active(true)
	await settle()
	check("clean observation retains 3D picking", panel.available() and panel.points.has("city") and panel.pick(panel.points.city.pixel) == "city")
	main.clean_observation.set_active(false)
	get_window().size = Vector2i(1280,800)
	await settle()
	click(panel.points.city.pixel)
	check("repeat landmark click requests original city", main.coordinator.is_busy() and main.coordinator._target_id == "city")
	if not await ready_stage(): await finish(); return
	await capture("city-arrived")
	if not await arrive("earth"): await finish(); return
	panel.clear_selection()
	panel.hovered = ""
	await pose_region("desert",7.0)
	await capture("earth-west")
	check("paused authority time and date survive entry and return", main.world.get_instance_id() == authority and main.world.checkpoint().simulation_time_s == before.simulation_time_s and main.solar_jd == date and main.world.paused)
	await finish()

func finish() -> void:
	FileAccess.open(directory.path_join("layout.json"),FileAccess.WRITE).store_string(JSON.stringify(layout,"\t") + "\n")
	await super.finish()
