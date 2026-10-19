extends "res://tests/integration/world_expansion_suite.gd"
const Sites = preload("res://scripts/data/earth_sites.gd")
var samples: Array[Dictionary] = []
var flight_progress: float = 0.0
var minimum_globe_radius: float = INF
var saw_local_motion: bool = false
var last_local_position: Vector3
var frame_records: Array[Dictionary] = []

func ready_stage() -> bool:
	# The existing cold ocean request allows 30 seconds before its short fade.
	var deadline: int = Time.get_ticks_msec() + 35000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground:
			if DisplayServer.get_name() == "headless" or DisplayServer.window_can_draw(): return true
	var state: Dictionary = {"loading":main.coordinator.loading_status(),"scale":main.world.current_scale_id,"foreground":main.world.foreground,"drawable":DisplayServer.window_can_draw(),"prepared":main.coordinator.active_scene.is_prepared(),"screen":get_window().current_screen,"screen_count":DisplayServer.get_screen_count()}
	state["request_age_ms"] = (Time.get_ticks_usec() - main.coordinator._intent_us) / 1000.0
	state["incoming_prepared"] = main.coordinator._incoming.is_prepared() if is_instance_valid(main.coordinator._incoming) else null
	FileAccess.open(directory.path_join("ready-failure.json"), FileAccess.WRITE).store_string(JSON.stringify(state, "\t"))
	check("stage ready", false)
	return false

func core_checkpoint() -> Dictionary:
	var value: Dictionary = main.world.checkpoint()
	value.erase("current_scale_id")
	value.erase("local_habitat")
	return value

func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen == DisplayServer.get_primary_screen(): continue
		if get_window().current_screen != screen:
			var original_size: Vector2i = get_window().size
			get_window().current_screen = screen
			get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30, 30)
			get_window().size = original_size
		main._measurement_screen = screen
		break
	for frame: int in range(2): await get_tree().process_frame

func pose_region(id: String) -> void:
	var site: Dictionary = Sites.for_scale(id)
	main._orbit_target = Vector3.ZERO
	main._pan_offset = Vector3.ZERO
	main.coordinator.active_scene.set_pose(Sites.normal(float(site.lat), float(site.lon)) * 9.4, Vector3.ZERO)
	await settle()
	main.earth_entry_panel.refresh_points()

func mouse_button(point: Vector2, pressed: bool, index: int = MOUSE_BUTTON_LEFT) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.pressed = pressed
	event.button_index = index
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and index == MOUSE_BUTTON_LEFT else 0
	main._unhandled_input(event)

func click(point: Vector2) -> void:
	mouse_button(point, true)
	mouse_button(point, false)

func record_flight(_request: int, progress: float) -> void:
	flight_progress = progress
	if main._earth_flight.is_empty(): return
	var entering: bool = main._earth_flight.direction == "enter"
	var globe: Node = main._outgoing if entering else main._incoming
	var local: Node = main._incoming if entering else main._outgoing
	minimum_globe_radius = minf(minimum_globe_radius, globe.camera.position.length())
	if progress > .6 and local.camera.position.distance_to(last_local_position) > .01: saw_local_motion = true
	last_local_position = local.camera.position
	samples.append({"direction":main._earth_flight.direction,"region":main._earth_flight.region,"progress":progress,"world_time_s":main.world.simulation_time_s,"globe_position":var_to_str(globe.camera.position),"globe_target":var_to_str(globe.camera.position - globe.camera.basis.z),"local_position":var_to_str(local.camera.position),"blend":main._progress_alpha})

func authoring_ready() -> bool:
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if main.coordinator.phase == main.Coordinator.Phase.AUTHORING: return true
		if not main.coordinator.is_busy(): break
	input_state("authoring-failure")
	check("authored regional flight starts", false)
	return false

func input_state(label: String) -> void:
	var state: Dictionary = {"selected":main.earth_entry_panel.selected,"entry_available":main.earth_entry_panel.available(),"entry_visible":main.earth_entry_panel.is_visible_in_tree(),"hud_visible":main.hud.visible,"foreground":main.world.foreground,"drawable":DisplayServer.window_can_draw(),"loading":main.coordinator.loading_status(),"request_id":main.coordinator._request_id,"target":main.coordinator._target_id,"scale":main.world.current_scale_id,"clean":main.clean_observation.active}
	FileAccess.open(directory.path_join(label + ".json"), FileAccess.WRITE).store_string(JSON.stringify(state, "\t"))
	print("REGIONAL_INPUT_STATE ", label, " ", JSON.stringify(state))

func flight_frame(label: String, threshold: float) -> void:
	while main.coordinator.is_busy() and flight_progress < threshold: await get_tree().process_frame
	await capture(label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var status: Error = get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	check("capture " + label, status == OK)
	captures.append(label + ".png")
	frame_records.append({"file":label + ".png","progress":flight_progress,"scale":main.world.current_scale_id,"phase":main.coordinator.phase,"screen":get_window().current_screen,"screen_count":DisplayServer.get_screen_count(),"primary":DisplayServer.get_primary_screen(),"window_size":[get_window().size.x,get_window().size.y],"ratio":main._render_ratio})

func finish() -> void:
	FileAccess.open(directory.path_join("flight-samples.json"), FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"frames":frame_records,"minimum_globe_radius":minimum_globe_radius,"saw_local_motion":saw_local_motion}, "\t"))
	await super.finish()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world249-review="): directory = argument.trim_prefix("--world249-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	get_tree().create_timer(120).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	main._audio.volume_db = -80
	main.world.set_paused(true)
	main._refresh_observation_controls()
	main.set_solar_rate(0)
	main.world_guide.hide()
	main.explorer_panel.hide()
	get_window().size = Vector2i(1280, 800)
	if not await ready_stage(): await finish(); return
	await settle()
	var panel: Node = main.earth_entry_panel
	var authority: int = main.world.get_instance_id()
	var date: float = main.solar_jd
	var checkpoint: Dictionary = core_checkpoint()
	if "--world249-branches-only" in OS.get_cmdline_user_args():
		await branch_roundtrips(authority, checkpoint, date, main.coordinator.active_scene.camera.position)
		await finish()
		return
	check("Earth starts with five existing spatial references", main.world.current_scale_id == "earth" and panel.visible and panel.buttons.size() == 5)
	check("spatial map hides overlapping legacy atmosphere target", not main.target_button.visible)
	check("teaching entries state their geographic limits", panel.buttons.city.text.contains("合成") and panel.buttons.woodland.text.contains("合成") and panel.buttons.polar.text.contains("合成") and panel.buttons.reef.text.contains("区域资料"))
	await capture("earth-spatial-east")
	await pose_region("desert")
	check("west hemisphere reveals desert and woodland references", panel.points.has("desert") and panel.points.has("woodland") and not panel.points.has("city") and not panel.points.has("reef"))
	await capture("earth-spatial-west")
	await pose_region("city")
	check("front city marker is hit and back desert is not offered", panel.points.has("city") and panel.pick(panel.points.city.pixel) == "city" and not panel.points.has("desert"))
	var at: Vector2 = panel.points.city.pixel
	var original_position: Vector3 = main.coordinator.active_scene.camera.position
	mouse_button(at, true)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at + Vector2(-90, 12)
	motion.relative = Vector2(-90, 12)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	main._unhandled_input(motion)
	mouse_button(motion.position, false)
	check("drag from marker rotates without selecting or entering", panel.selected.is_empty() and not main.coordinator.is_busy() and main.coordinator.active_scene.camera.position.distance_to(original_position) > .1)
	check("globe interaction does not change paused world or date", core_checkpoint() == checkpoint and main.solar_jd == date)
	await pose_region("city")
	click(panel.points.city.rect.get_center())
	check("click selects a single card without committing a scene", panel.selected == "city" and panel.card.visible and not main.coordinator.is_busy() and panel.card_kind.text.contains("非实地地址"))
	get_window().size = Vector2i(900, 650)
	await settle()
	panel.refresh_points()
	var actions: Control = main.next_button.get_parent()
	var last_action: Control = actions.get_child(actions.get_child_count() - 1)
	var right_options: Control = main.quality_button.get_parent()
	FileAccess.open(directory.path_join("compact-layout.json"), FileAccess.WRITE).store_string(JSON.stringify({"last_action_end_x":last_action.get_global_rect().end.x,"right_options_start_x":right_options.get_global_rect().position.x,"old_empty_container_end_x":actions.get_global_rect().end.x,"window_width":get_window().size.x}, "\t"))
	check("compact bottom actions do not overlap right options", last_action.get_global_rect().end.x <= right_options.get_global_rect().position.x)
	check("compact globe card and active city marker fit", Rect2(Vector2.ZERO, Vector2(get_window().size)).encloses(panel.card.get_global_rect()) and panel.card.get_global_rect().end.y < 500 and panel.points.has("city"))
	await capture("earth-spatial-compact-selected")
	if "--world249-layout-only" in OS.get_cmdline_user_args(): await finish(); return
	get_window().size = Vector2i(1280, 800)
	await settle()
	main.clean_observation.set_active(true)
	check("clean view hides spatial overlays and picking", not panel.available() and not panel.is_visible_in_tree())
	main.clean_observation.set_active(false)
	await settle()
	if not await ready_stage(): await finish(); return
	main._sync_window_availability()
	check("regional controls restored after clean view", panel.available() and panel.selected == "city" and main.hud.visible)
	input_state("before-wheel")
	if not panel.available(): await finish(); return
	main._reduced_motion = false
	main.coordinator.authoring_progress.connect(record_flight)
	var earth_position: Vector3 = main.coordinator.active_scene.camera.position
	var earth_up: Vector3 = main.coordinator.active_scene.camera.basis.y
	var earth_target: Vector3 = main._orbit_target
	flight_progress = 0
	mouse_button(panel.points.city.pixel, true, MOUSE_BUTTON_WHEEL_UP)
	input_state("after-wheel")
	if not await authoring_ready(): await finish(); return
	check("wheel entry uses selected geographic bridge", main._earth_flight.region == "city" and main._earth_flight.direction == "enter" and not panel.visible)
	await flight_frame("entry-globe-close", .35)
	await flight_frame("entry-city-wide", .76)
	if not await ready_stage(): await finish(); return
	check("city arrives with the same paused world", main.world.current_scale_id == "city" and main.world.get_instance_id() == authority and core_checkpoint() == checkpoint and main.solar_jd == date)
	check("arrival has no final pose snap", main.coordinator.active_scene.camera.position.distance_to(main._in_end.position) < .00001)
	await capture("city-arrived")
	flight_progress = 0
	main.navigation_bar.earth_button.pressed.emit()
	if not await authoring_ready(): await finish(); return
	check("exit bridge starts at the same region", main._earth_flight.region == "city" and main._earth_flight.direction == "exit")
	await flight_frame("exit-city-wide", .20)
	await flight_frame("exit-earth-close", .64)
	if not await ready_stage(): await finish(); return
	check("Earth return restores original orbit target position and up", main.world.current_scale_id == "earth" and main.coordinator.active_scene.camera.position.distance_to(earth_position) < .00001 and main._orbit_target.distance_to(earth_target) < .00001 and main.coordinator.active_scene.camera.basis.y.distance_to(earth_up) < .00001)
	check("flight stays outside globe and actually moves local camera", minimum_globe_radius >= 3.2199 and saw_local_motion)
	await capture("earth-restored")
	var earth_instance: int = main.coordinator.active_scene.get_instance_id()
	flight_progress = 0
	main.observe_scale("city")
	if not await authoring_ready(): await finish(); return
	while flight_progress < .22 and main.coordinator.is_busy(): await get_tree().process_frame
	main.coordinator.cancel("regional_flight_short_check")
	await settle()
	check("cancel restores original Earth pose and sole active scene", main.world.current_scale_id == "earth" and main.coordinator.active_scene.get_instance_id() == earth_instance and main.scene_host.get_child_count() == 1 and main.coordinator.active_scene.camera.position.distance_to(earth_position) < .00001 and main._earth_flight.is_empty())
	print("REGIONAL_CANCEL_READY ", JSON.stringify({"phase":main.coordinator.phase,"foreground":main.world.foreground,"drawable":DisplayServer.window_can_draw(),"prepared":main.coordinator.active_scene.is_prepared()}))
	if not await ready_stage(): await finish(); return
	await branch_roundtrips(authority, checkpoint, date, earth_position)
	await finish()

func branch_roundtrips(authority: int, checkpoint: Dictionary, date: float, earth_position: Vector3) -> void:
	main._reduced_motion = true
	for id: String in ["reef", "woodland", "desert", "polar"]:
		input_state("before-" + id)
		main.observe_scale(id)
		if not await ready_stage(): return
		check("reduced motion enters original " + id, main.world.current_scale_id == id and main.world.get_instance_id() == authority)
		main.navigation_bar.earth_button.pressed.emit()
		if not await ready_stage(): return
		check("reduced motion returns from " + id, main.world.current_scale_id == "earth" and main.coordinator.active_scene.camera.position.distance_to(earth_position) < .00001)
	check("all branches preserve date paused authority and core states", main.world.get_instance_id() == authority and main.world.paused and core_checkpoint() == checkpoint and main.solar_jd == date)
