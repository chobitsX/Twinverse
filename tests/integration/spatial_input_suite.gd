extends "res://tests/integration/world_expansion_suite.gd"
## Finite viewport-routed gesture and geometry checks; no OS input or saves.
const ZOOM_SCALES: Array[String] = ["galaxy","solar_system","earth","atmosphere","pacific","reef","school","fish","heart","cardiomyocyte","mitochondrion","molecule","atom","woodland","city","desert","polar","earth_moon","jupiter_moons"]
var original_id: int
var original_time: float
var original_jd: float
var records: Array[Dictionary] = []

func dispatch(event: InputEvent) -> void:
	# Enable only synchronously while injecting through the real input/GUI route.
	# The unfocusable diagnostic otherwise rejects external UI input.
	get_viewport().gui_disable_input = false
	get_viewport().notify_mouse_entered()
	get_viewport().push_input(event, true)
	get_viewport().gui_disable_input = true

func cursor(point: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	dispatch(event)

func magnify(factor: float, point: Vector2 = Vector2(640,400)) -> void:
	cursor(point)
	var event: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	event.position = point
	event.factor = factor
	dispatch(event)

func pan(delta: Vector2, shifted: bool = false) -> void:
	cursor(Vector2(640,400))
	var event: InputEventPanGesture = InputEventPanGesture.new()
	event.position = Vector2(640,400)
	event.delta = delta
	event.shift_pressed = shifted
	dispatch(event)

func click(point: Vector2, twice: bool = false) -> void:
	cursor(point)
	for down: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.double_click = twice and down
		dispatch(event)

func settle() -> void:
	for frame: int in range(2): await get_tree().process_frame

func radius() -> float:
	return main.coordinator.active_scene.camera.position.distance_to(main._orbit_target)

func zoom_scale(id: String) -> void:
	if not await arrive(id): return
	main.explorer_panel.hide()
	main.info_panel.hide()
	main._reset_camera()
	await settle()
	var before: float = radius()
	magnify(1.04)
	check(id + " pinch reaches the real camera", not main.coordinator.is_busy() and radius() < before * .999)
	magnify(1.0/1.04)
	check(id + " inverse pinch restores distance", absf(radius() - before) < maxf(.0001, before * .0001))
	pan(Vector2(0,-.3))
	check(id + " two-finger scroll zooms inward", not main.coordinator.is_busy() and radius() < before * .999)
	pan(Vector2(0,.3))
	var pose: Transform3D = main.coordinator.active_scene.camera.transform
	pan(Vector2(2,0))
	check(id + " horizontal scroll does not zoom or rotate", main.coordinator.active_scene.camera.transform.is_equal_approx(pose))
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.position = Vector2(640,400)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.factor = .2
	wheel.pressed = true
	dispatch(wheel)
	check(id + " fractional wheel gives a small camera step", radius() < before and radius() > before * .95)
	records.append({"scale":id,"before":before,"after_fractional_wheel":radius()})

func visible_choice(destination: String = "", label_part: String = "") -> Dictionary:
	var picker: Node = main.object_pointer
	var stage: Node = main.coordinator.active_scene
	picker.rebuild(stage)
	var entries: Dictionary = {}
	for choice: Dictionary in picker.choices.values():
		if not destination.is_empty() and str(choice.get("destination", "")) != destination and not (choice.get("primary", false) and main.Catalog.relative(stage.scale_id,1) == destination): continue
		if not label_part.is_empty() and not str(choice.label).contains(label_part): continue
		if entries.has(choice.node.get_instance_id()): continue
		entries[choice.node.get_instance_id()] = true
		var centers: Array[Vector3] = [choice.get("focus_position", choice.node.global_position + Vector3(0,float(choice.get("focus_height",0)),0))]
		if choice.node is MultiMeshInstance3D:
			for i: int in range(choice.node.multimesh.instance_count): centers.append(choice.node.global_transform * choice.node.multimesh.get_instance_transform(i).origin)
		for center: Vector3 in centers:
			if stage.camera.is_position_behind(center): continue
			var projected: Vector2 = stage.camera.unproject_position(center)
			for offset: Vector2 in [Vector2.ZERO, Vector2(8,0), Vector2(-8,0), Vector2(0,8), Vector2(0,-8), Vector2(18,12), Vector2(-18,12), Vector2(25,-15), Vector2(-25,-15)]:
				var point: Vector2 = projected + offset
				if not Rect2(25,145,1230,460).has_point(point): continue
				var hit: Dictionary = picker.pick(point)
				if hit.get("node") == choice.node: return {"point":point, "choice":hit}
	return {}

func object_entry(source: String, destination: String, capture_name: String = "") -> void:
	if not await arrive(source): return
	main._reset_camera()
	main.explorer_panel.hide()
	main.info_panel.hide()
	await settle()
	var hit: Dictionary = visible_choice(destination)
	check(source + " child has a visible geometry hit", not hit.is_empty())
	if hit.is_empty(): return
	click(hit.point)
	await settle()
	check(source + " geometry click selects without opening menus", not main.explorer_panel.visible and not main.world_guide.visible and (main._content_follow >= 0 or main.solar_follow >= 0))
	if source == "fish": check("selected fish remains inside the sharp depth range", main.coordinator.active_scene.camera.attributes.dof_blur_far_distance >= radius())
	check(source + " primary entry does not need overlay buttons", not main.next_button.is_visible_in_tree() and not main.target_button.is_visible_in_tree())
	if not capture_name.is_empty(): await capture(capture_name)
	click(hit.point, true)
	check(source + " double click routes to " + destination, main.coordinator.is_busy() and main.coordinator._target_id == destination)
	if await ready_stage(): check(source + " spatial entry arrives", main.world.current_scale_id == destination)

func earth_marks() -> void:
	if not await arrive("earth"): return
	main._reset_camera()
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.earth_entry_panel
	panel.clear_selection()
	await settle()
	panel.refresh_points()
	var markers: Dictionary = stage.get_meta("earth_entry_markers", {})
	check("five Earth signs are in the existing World3D with depth-tested captions", markers.size() == 5 and markers.reef.root.get_parent() == stage.world_root and markers.reef.label is Label3D and not markers.reef.label.no_depth_test)
	check("Earth card contains no navigation button", panel.find_children("*","Button",true,false).is_empty())
	for id: String in panel.ORDER:
		var normal: Vector3 = panel.Sites.normal(float(panel.Sites.for_scale(id).lat), float(panel.Sites.for_scale(id).lon))
		stage.set_pose(normal * 9.6, Vector3.ZERO)
		await settle()
		panel.refresh_points()
		check(id + " sign projects to its actual Earth region", panel.points.has(id) and panel.pick(panel.points[id].pixel) == id)
	check("Earth backside signs cannot be picked", panel.points.size() < 5)
	var normal: Vector3 = panel.Sites.normal(panel.Sites.REEF_LAT, panel.Sites.REEF_LON)
	stage.set_pose(normal * 9.6, Vector3.ZERO)
	await settle()
	panel.refresh_points()
	var point: Vector2 = panel.points.reef.pixel
	var original_pose: Transform3D = stage.camera.transform
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	dispatch(press)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.position = point + Vector2(45,15)
	drag.relative = Vector2(45,15)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	dispatch(drag)
	press.pressed = false
	press.position = drag.position
	dispatch(press)
	check("dragging a 3D sign rotates Earth without selecting or entering", not stage.camera.transform.is_equal_approx(original_pose) and panel.selected.is_empty() and not main.coordinator.is_busy())
	stage.set_pose(normal * 9.6, Vector3.ZERO)
	await settle()
	click(point)
	check("3D reef sign selects without entering immediately", panel.selected == "reef" and not main.coordinator.is_busy())
	var before: float = radius()
	magnify(1.04)
	check("selected Earth pinch first zooms continuously", not main.coordinator.is_busy() and radius() < before)
	await capture("earth-3d-signs")
	main.clean_observation.set_active(true)
	await settle()
	panel.refresh_points()
	check("clean view retains depth-tested signs and picking", panel.available() and panel.points.has("reef") and markers.reef.root.visible and not markers.reef.label.visible)
	main.clean_observation.set_active(false)
	await settle()
	stage.set_pose(normal * 3.9, Vector3.ZERO)
	magnify(1.08)
	check("pinching through the near boundary enters the chosen 3D region", main.coordinator.is_busy() and main.coordinator._target_id == "reef")
	main.coordinator.cancel("short_spatial_entry_check")
	await ready_stage()
	check("cancelled near entry keeps the Earth context and selection", main.world.current_scale_id == "earth" and panel.selected == "reef" and main.scene_host.get_child_count() == 1)
	stage.set_pose(normal * 9.6, Vector3.ZERO)
	await settle()
	panel.refresh_points()
	var old_pose: Transform3D = stage.camera.transform
	click(panel.points.reef.pixel)
	check("repeat geometry click starts selected reef entry", main.coordinator.is_busy() and main.coordinator._target_id == "reef")
	if not await ready_stage(): return
	var parent_distance: float = main.coordinator.active_scene.default_position.distance_to(main.coordinator.active_scene.default_target)
	var local: Node = main.coordinator.active_scene
	local.set_pose(main._orbit_target + (local.camera.position-main._orbit_target).normalized() * parent_distance * 2.95, main._orbit_target)
	pan(Vector2(0,.5))
	check("two-finger pullback starts the original Earth return", main.coordinator.is_busy() and main.coordinator._target_id == "earth")
	if await ready_stage(): check("spatial return retains selected region and Earth pose", panel.selected == "reef" and main.coordinator.active_scene.camera.transform.is_equal_approx(old_pose))
	check("breadcrumb shows the actual regional route", main.observation_parent("reef") == "earth" and not main.observation_breadcrumb().has("pacific"))

func land_selection(id: String, label: String) -> void:
	if not await arrive(id): return
	main._reset_camera()
	main.explorer_panel.hide()
	main.info_panel.hide()
	await settle()
	var hit: Dictionary = visible_choice("",label)
	check(id + " exposes an actual individual geometry", not hit.is_empty())
	if hit.is_empty(): return
	click(hit.point)
	await settle()
	check(id + " geometry selects the clicked individual without a menu", main._direct_content.get("node") == hit.choice.node and not main.explorer_panel.visible)

func extra_paths() -> void:
	await object_entry("atmosphere","pacific")
	await object_entry("reef","school")
	await object_entry("school","fish")
	await land_selection("city","行人")
	await land_selection("woodland","白尾鹿")

func guards() -> void:
	if not await arrive("earth"): return
	main._reset_camera()
	await settle()
	var pose: Transform3D = main.coordinator.active_scene.camera.transform
	main.info_panel.show()
	await settle()
	magnify(1.2, main.info_panel.get_global_rect().get_center())
	check("pinch over a visible UI panel does not reach the camera", main.coordinator.active_scene.camera.transform.is_equal_approx(pose))
	main.info_panel.hide()
	main.world_guide.show()
	magnify(1.2)
	check("guide modal owns gestures", main.coordinator.active_scene.camera.transform.is_equal_approx(pose))
	main.world_guide.hide()
	main.world.set_foreground(false)
	magnify(1.2)
	check("background window rejects gestures", main.coordinator.active_scene.camera.transform.is_equal_approx(pose))
	main.world.set_foreground(true)
	magnify(0)
	magnify(-1)
	magnify(INF)
	check("invalid magnification cannot corrupt the pose", main.coordinator.active_scene.camera.transform.is_equal_approx(pose))
	pan(Vector2(1,.2), true)
	check("Shift two-finger scroll pans without changing distance", absf(radius() - pose.origin.length()) < .001 and main._pan_offset.length() > .001)
	main.observe_scale("city")
	var request: int = main.coordinator._request_id
	magnify(2)
	pan(Vector2(0,-5))
	check("in-flight gestures do not replace or cancel the request", main.coordinator.is_busy() and main.coordinator._request_id == request and main.coordinator._target_id == "city")
	await ready_stage()
	if not await arrive("earth_moon"): return
	main.explorer_panel.show()
	await settle()
	check("lunar special view selects the actual available topic", main.explorer_panel.select_topic("lunar_phases"))
	main.focus_lunar(true)
	main.explorer_panel.hide()
	await settle()
	var width: float = main.coordinator.active_scene.camera.size
	magnify(1.05)
	check("lunar orthographic pinch changes width", main.coordinator.active_scene.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and main.coordinator.active_scene.camera.size < width)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world252-input-check="): directory = argument.trim_prefix("--world252-input-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	get_window().size = Vector2i(1280,800)
	get_tree().create_timer(150).timeout.connect(func() -> void: get_tree().quit(2))
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
	if not "--world252-followup" in OS.get_cmdline_user_args():
		for id: String in ZOOM_SCALES: await zoom_scale(id)
	await earth_marks()
	await object_entry("galaxy","solar_system")
	await object_entry("solar_system","earth")
	await object_entry("solar_system","jupiter_moons")
	await object_entry("fish","heart","fish-direct-selection")
	await object_entry("heart","cardiomyocyte","ventricle-direct-selection")
	await object_entry("cardiomyocyte","mitochondrion","mitochondrion-direct-selection")
	await object_entry("mitochondrion","molecule")
	await object_entry("molecule","atom","oxygen-direct-selection")
	await extra_paths()
	await guards()
	check("all input preserves the single world time date pause and target identity", main.world.get_instance_id() == original_id and main.world.simulation_time_s == original_time and main.world.paused and main.solar_jd == original_jd and main.world.snapshot().target_fish_id == main.WorldState.TARGET_FISH_ID)
	await finish()

func finish() -> void:
	FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"records":records,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"display":DisplayServer.get_name(),"viewport_input_routed":true,"native_os_gestures_tested":false,"performance_test":false,"world_id":main.world.get_instance_id(),"original_world_id":original_id,"date_jd":main.solar_jd,"original_date_jd":original_jd,"paused":main.world.paused,"no_save":not main._persistence_enabled},"\t"))
	print("SPATIAL_INPUT_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
