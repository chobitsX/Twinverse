extends "res://tests/integration/world_expansion_suite.gd"
const Ruler = preload("res://scripts/experience/observation_ruler.gd")
const Store = preload("res://scripts/core/world_store.gd")
const Species = preload("res://scripts/experience/species_catalog.gd")
var samples: Array[Dictionary] = []
var settings: Array[Dictionary] = []
var observations: Dictionary = {}
var authority: int
var initial_date: float
var initial_resources: Dictionary
var visited: Array[String] = []
var max_projection_error_px: float = 0.0


func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen == DisplayServer.get_primary_screen(): continue
		if get_window().current_screen != screen:
			var wanted: Vector2i = get_window().size
			get_window().current_screen = screen
			get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
			get_window().size = wanted
		main._measurement_screen = screen
		break
	for frame: int in range(3): await get_tree().process_frame


func unchanged_clock() -> bool:
	return main.world.get_instance_id() == authority and main.world.paused and main.world.simulation_time_s == 5.0 and main.world.time_scale == 2.0 and main.solar_jd == initial_date and main.solar_rate == 0.0


func resource_checkpoint() -> Dictionary:
	var state: Dictionary = main.world.checkpoint()
	var selected: Dictionary = {}
	for key: String in ["version","model_version","data_version","target_fish_id","seed","science","woodland_browse","urban_runoff","coral_symbiosis","deadwood_decomposition","algal_grazing","desert_seed_transfer","zooplankton_lesson","city_traffic"]: selected[key] = state[key]
	return selected.duplicate(true)


func choose(scale_id: String, topic: String = "") -> bool:
	main.explorer_panel.clear_topic()
	main.explorer_panel.hide()
	if not await arrive(scale_id): return false
	await settle()
	if not topic.is_empty():
		main.explorer_panel.show()
		await settle()
		if not main.explorer_panel.select_topic(topic):
			check("existing topic "+topic,false)
			return false
		await settle()
	if not scale_id in visited: visited.append(scale_id)
	check("same paused authority at "+scale_id,unchanged_clock())
	return true


func ruler_sample(label: String) -> Dictionary:
	var stage: Node = main.coordinator.active_scene
	var camera: Camera3D = stage.camera
	var measured: Dictionary = main.learning_overlay.last_ruler
	if measured.is_empty(): return {}
	var half: Vector3 = camera.global_basis.x.normalized() * float(measured.length_m) * .5
	var center: Vector3 = main._orbit_target
	var actual_pixels: float = camera.unproject_position(center+half).distance_to(camera.unproject_position(center-half))
	var error: float = absf(actual_pixels - float(measured.pixels))
	max_projection_error_px = maxf(max_projection_error_px,error)
	var rect: Rect2 = measured.rect
	var unobscured: bool = true
	for control: Control in [main.explorer_panel,main.guided_journey,main.info_panel,main.observation_panel,main.sound_panel,main.science_badge]:
		if control.is_visible_in_tree(): unobscured = unobscured and not rect.intersects(control.get_global_rect().grow(4.0))
	return {"view":label,"scale":main.world.current_scale_id,"topic":main.learning_overlay.topic,"length_m":measured.length_m,"label":measured.label,"bar_pixels":measured.pixels,"independent_bar_pixels":actual_pixels,"projection_error_px":error,"metres_per_pixel":measured.metres_per_pixel,"depth_m":measured.depth_m,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"viewport":[stage.viewport.size.x,stage.viewport.size.y],"render_ratio":stage.render_scale,"camera_position":Store.components(camera.position),"camera_target":Store.components(center),"world_time_s":main.world.simulation_time_s,"jd":main.solar_jd,"paused":main.world.paused,"time_scale":main.world.time_scale,"panel_clear":unobscured}


func inspect(label: String) -> void:
	var sample: Dictionary = ruler_sample(label)
	check(label+" actual plane length and screen bar agree",not sample.is_empty() and float(sample.get("projection_error_px",INF)) < .75 and float(sample.get("bar_pixels",0.0)) >= 55.0 and float(sample.get("bar_pixels",INF)) <= 140.001)
	check(label+" clears original controls and keeps clock",not sample.is_empty() and sample.get("panel_clear",false) and unchanged_clock())
	if not sample.is_empty(): samples.append(sample)


func capture(label: String) -> void:
	await settle()
	inspect(label)
	settings.append({"view":label,"screen_count":DisplayServer.get_screen_count(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"window_size":[get_window().size.x,get_window().size.y]})
	await super.capture(label)
	write_report("running")


func write_report(status: String) -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":status,"cases":cases,"failures":failures,"captures":captures,"samples":samples,"observations":observations,"capture_window_settings":settings,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"new_persistence_or_dynamics_tested":false},"  ")+"\n")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world240-review="): directory = argument.trim_prefix("--world240-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	main = Experience.instantiate()
	main.world.set_paused(true)
	add_child(main)
	main._measurement_screen = get_window().current_screen
	if not await ready_stage(): await finish(); return
	get_window().size = Vector2i(1280,800)
	main._audio.volume_db = -80.0
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world.set_time_scale(2.0)
	main.world.simulation_time_s = 5.0
	main.set_solar_rate(0.0)
	await settle()
	authority = main.world.get_instance_id()
	initial_date = main.solar_jd
	initial_resources = resource_checkpoint()
	if not await choose("reef","turtle_compare_sea"): await finish(); return
	await capture("sea-ruler")
	main.learning_overlay.enabled = false
	await settle()
	check("existing auxiliary switch hides the ruler and marks",main.learning_overlay.last_ruler.is_empty() and main.learning_overlay.last_visible_marks == 0 and unchanged_clock())
	main.learning_overlay.enabled = true
	await settle()
	check("auxiliary switch restores the plane reference",not main.learning_overlay.last_ruler.is_empty() and unchanged_clock())
	main.clean_observation.set_active(true)
	await settle()
	check("existing clean observation hides ruler with HUD",main.clean_observation.active and not main.hud.visible and main.learning_overlay.last_ruler.is_empty() and unchanged_clock())
	main.clean_observation.set_active(false)
	await settle()
	check("return from clean observation restores ruler",not main.clean_observation.active and not main.learning_overlay.last_ruler.is_empty() and unchanged_clock())
	main._open_guide()
	await settle()
	check("existing full guide hides ruler",main.world_guide.visible and main.learning_overlay.last_ruler.is_empty())
	main.world_guide.hide()
	main.explorer_panel.show()
	await settle()
	if not await choose("woodland","turtle_compare_land"): await finish(); return
	await capture("land-ruler")
	var stage: Node = main.coordinator.active_scene
	var target: Vector3 = main._orbit_target
	var position: Vector3 = stage.camera.position
	var pan: Vector3 = main._pan_offset
	var before: Dictionary = main.learning_overlay.last_ruler.duplicate()
	stage.set_pose(target+(position-target)*1.8,target)
	await settle()
	var zoomed: Dictionary = main.learning_overlay.last_ruler
	check("camera zoom updates metric at the actual unchanged reference plane",not zoomed.is_empty() and absf(float(zoomed.metres_per_pixel)/float(before.metres_per_pixel)-1.8)<.003 and unchanged_clock())
	main._pan_camera(stage,Vector2(35,-18))
	await settle()
	var panned: Dictionary = main.learning_overlay.last_ruler
	check("original parallel pan retains depth scale",not panned.is_empty() and absf(float(panned.metres_per_pixel)/float(zoomed.metres_per_pixel)-1.0)<.003 and unchanged_clock())
	main._orbit_target = target
	main._pan_offset = pan
	stage.set_pose(position,target)
	get_window().size = Vector2i(900,650)
	await settle()
	check("existing egg topic remains reachable",main.explorer_panel.select_topic("monarch_egg"))
	await settle()
	await capture("egg-ruler-compact")
	check("millimetre plane reference retains original tiny egg",str(main.learning_overlay.last_ruler.get("label","")).ends_with("毫米") and main.coordinator.active_scene.get_meta("monarch_life_stages").egg.node.scale.is_equal_approx(Vector3.ONE) and unchanged_clock())
	get_window().size = Vector2i(1280,800)
	if not await choose("city","crossing"): await finish(); return
	await capture("city-ruler")
	if not await choose("desert","desert_cactus"): await finish(); return
	await capture("desert-ruler")
	if not await choose("polar","ice_krill"): await finish(); return
	await capture("krill-ruler")
	if not await choose("fish"): await finish(); return
	await capture("fish-ruler")
	if not await choose("school"): await finish(); return
	inspect("school-original")
	if not await choose("pacific"): await finish(); return
	inspect("surface-original")
	if not await choose("earth"): await finish(); return
	check("Earth globe does not receive a local metre ruler",main.learning_overlay.last_ruler.is_empty())
	if not await choose("solar_system"): await finish(); return
	check("compressed solar scene keeps its own scale explanation",main.learning_overlay.last_ruler.is_empty() and not Ruler.supported("solar_system"))
	main.observe_scale("reef")
	check("real transition hides the old reference immediately",main.coordinator.is_busy())
	var transition_hidden: bool = true
	var busy_frames: int = 0
	var transition_deadline: int = Time.get_ticks_msec()+10000
	while main.coordinator.is_busy() and Time.get_ticks_msec()<transition_deadline:
		await RenderingServer.frame_post_draw
		if main.coordinator.is_busy():
			busy_frames += 1
			transition_hidden = transition_hidden and main.learning_overlay.last_ruler.is_empty()
	check("busy transition has no obsolete ruler",transition_hidden and not main.coordinator.is_busy())
	if not await ready_stage(): await finish(); return
	await settle()
	check("ready local scene restores the actual new camera ruler",main.world.current_scale_id == "reef" and not main.learning_overlay.last_ruler.is_empty() and unchanged_clock())
	var resources_unchanged: bool = initial_resources == resource_checkpoint()
	check("read-only ruler leaves original science and local experiments intact",resources_unchanged)
	check("all eight original metre views retain species and guide counts",visited.size() == 10 and Species.ENTRIES.size() == 41 and main.world_guide.route_buttons.size() == 93)
	check("resource and user-save boundaries hold",Engine.max_fps == 5 and ProjectSettings.get_setting("application/run/max_fps") == 30 and ProjectSettings.get_setting("threading/worker_pool/max_threads") == 2 and main._render_ratio == .75 and not main._persistence_enabled and get_window().unfocusable and get_viewport().gui_disable_input)
	observations = {"visited":visited,"busy_rendered_frames":busy_frames,"max_projection_error_px":max_projection_error_px,"named_species":Species.ENTRIES.size(),"guide_routes":main.world_guide.route_buttons.size(),"paused":main.world.paused,"time_scale":main.world.time_scale,"world_time_s":main.world.simulation_time_s,"jd":main.solar_jd,"one_original_world":main.world.get_instance_id() == authority,"original_resource_state_unchanged":resources_unchanged,"max_fps":Engine.max_fps,"foreground_fps":ProjectSettings.get_setting("application/run/max_fps"),"worker_pool_threads":ProjectSettings.get_setting("threading/worker_pool/max_threads"),"render_ratio":main._render_ratio,"audio_volume_db":main._audio.volume_db,"user_save_accessed":false,"save_schema_changed":false}
	await finish()


func finish() -> void:
	write_report("completed")
	print("LOCAL_RULER_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	main._quit(0 if failures.is_empty() else 1)
