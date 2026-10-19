extends "res://tests/integration/world_expansion_suite.gd"
## Bounded appearance/navigation evidence; no new water physics or user saves.

var observations: Dictionary = {}
var capture_settings: Array[Dictionary] = []
var times: Array[Dictionary] = []

func core_checkpoint() -> Dictionary:
	var value: Dictionary = main.world.checkpoint()
	value.erase("current_scale_id")
	value.erase("local_habitat")
	return value

func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen == DisplayServer.get_primary_screen(): continue
		if get_window().current_screen != screen:
			var wanted: Vector2i = get_window().size
			get_window().current_screen = screen
			get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30, 30)
			get_window().size = wanted
		main._measurement_screen = screen
		break
	for frame: int in range(4): await get_tree().process_frame

func capture(label: String) -> void:
	await settle()
	capture_settings.append({"view":label,"screen_count":DisplayServer.get_screen_count(),
		"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),
		"window_size":[get_window().size.x,get_window().size.y]})
	await super.capture(label)
	write_report("running")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world243-review="): directory = argument.trim_prefix("--world243-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	main._audio.volume_db = -80.0
	get_window().size = Vector2i(1280, 800)
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		push_error("Polar water appearance short check exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world.simulation_time_s = 0.1
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.ground_light_preview = false
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await arrive("polar"):
		await finish()
		return
	await settle()
	main._reset_camera()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var authority: RefCounted = main.world
	var baseline: Dictionary = core_checkpoint()
	var date: float = main.solar_jd
	var surface: MeshInstance3D = stage.world_root.get_node("OpenSouthernOceanReference") as MeshInstance3D
	var material: ShaderMaterial = surface.get_active_material(0) as ShaderMaterial
	var sea_transform: Transform3D = surface.transform
	var sea_mesh: Mesh = surface.mesh
	var birds: Array = stage.get_meta("polar").birds
	var bird_ids: Array[int] = []
	for bird: Node3D in birds: bird_ids.append(bird.get_instance_id())
	var ice: Array[Dictionary] = []
	for child: Node in stage.world_root.get_children():
		if child.name.begins_with("AuthoredIceFloe_"):
			var floe: MeshInstance3D = child as MeshInstance3D
			ice.append({"node":floe,"transform":floe.transform,"mesh":floe.mesh})
	check("original flat sea and coast remain in the prepared scene", material != null and
		stage.world_root.has_node("ExposedRockCoast") and not stage.is_underwater and surface.visible)
	check("existing twelve ice and four birds remain the same actual objects", ice.size() == 12 and bird_ids.size() == 4)
	check("shader phase receives the sole paused world clock", absf(float(material.get_shader_parameter("world_time")) - 0.1) < .0001)
	await capture("water-default")
	main._orbit_target = Vector3(0, -.1, -12)
	stage.set_pose(Vector3(5, 2.8, 5), main._orbit_target)
	await capture("water-near")
	for frame: int in range(4): await get_tree().process_frame
	check("paused frames hold the material phase", absf(float(material.get_shader_parameter("world_time")) - .1) < .0001)
	main.world.simulation_time_s = 8.1
	await settle()
	times.append({"world_time_s":main.world.simulation_time_s,"material_time_s":material.get_shader_parameter("world_time")})
	check("explicit shared time updates the existing material phase", absf(float(material.get_shader_parameter("world_time")) - 8.1) < .0001 and main.world == authority)
	await capture("water-near-later")
	main.world.simulation_time_s = .1
	await settle()
	check("seeking back restores the sole material phase", absf(float(material.get_shader_parameter("world_time")) - .1) < .0001)
	check("time changes do not move sea or authored ice geometry", surface.transform == sea_transform and surface.mesh == sea_mesh and
		ice.all(func(item: Dictionary) -> bool: return item.node.transform == item.transform and item.node.mesh == item.mesh))
	main._reset_camera()
	get_window().size = Vector2i(900, 650)
	await capture("water-compact")
	check("compact scene remains drawable with the original waterline", DisplayServer.window_can_draw() and surface.visible and not stage.is_underwater)
	get_window().size = Vector2i(1280, 800)
	await settle()
	var panel: Node = main.explorer_panel
	panel.show()
	panel._process(0.0)
	await settle()
	check("original season topic selects existing local noon control", panel.select_topic("season_light"))
	panel.hide()
	main._reset_camera()
	panel.select_season(1)
	await capture("water-june")
	var sun: DirectionalLight3D = stage.get_meta("daylight_sun")
	var sky_sun: DirectionalLight3D = stage.get_meta("daylight_sky_sun")
	check("near-horizon sky disc shares direction without near-black surface energy", sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY and
		sky_sun.sky_mode == DirectionalLight3D.SKY_MODE_SKY_ONLY and not sky_sun.shadow_enabled and
		sky_sun.transform == sun.transform and (not sky_sun.visible or sky_sun.light_energy > .5))
	check("date lighting keeps paused world and material phase", main.ground_light_preview and main.world.simulation_time_s == .1 and
		absf(float(material.get_shader_parameter("world_time")) - .1) < .0001)
	panel.select_season(3)
	await capture("water-december")
	check("summer restores visible sky disc on the same existing direction", sky_sun.visible and sky_sun.transform == sun.transform and sun.light_energy > 0.0)
	check("summer reference keeps the same ice and bird instances", ice.all(func(item: Dictionary) -> bool: return item.node.transform == item.transform) and
		birds.all(func(bird: Node3D) -> bool: return bird.get_instance_id() in bird_ids))
	main.set_solar_date(date)
	main.ground_light_preview = false
	check("existing krill topic enters the same underwater scene", panel.select_topic("ice_krill_habitat"))
	panel.show()
	await settle()
	check("underwater view hides the original surface and retains real krill", stage.is_underwater and not surface.visible and
		stage.get_meta("ice_krill").animals.size() == 12)
	await capture("water-underwater")
	check("penguin view returns above water without a replacement surface", panel.select_topic("adelie_penguin"))
	await settle()
	check("above-water return restores the same surface material", not stage.is_underwater and surface.visible and surface.get_active_material(0) == material)
	var geometry_held: bool = (surface.transform == sea_transform and surface.mesh == sea_mesh and
		ice.all(func(item: Dictionary) -> bool: return item.node.transform == item.transform and item.node.mesh == item.mesh))
	main.navigation_bar.earth_button.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	check("Earth return restores the original five choices", main.world.current_scale_id == "earth" and main.earth_entry_panel.visible and main.earth_entry_panel.buttons.size() == 5)
	check("authority date and core state are unchanged at finish", main.world == authority and main.world.paused and
		main.world.simulation_time_s == .1 and main.solar_jd == date and core_checkpoint() == baseline)
	check("resource and user-save limits remain applied", not main._persistence_enabled and get_viewport().gui_disable_input and
		get_window().unfocusable and Engine.max_fps == 5 and ProjectSettings.get_setting("application/run/max_fps") == 30 and
		ProjectSettings.get_setting("threading/worker_pool/max_threads") == 2 and main._render_ratio == .75 and main._audio.volume_db == -80.0)
	observations = {"times":times,"world_time_s":main.world.simulation_time_s,"date_jd":main.solar_jd,"paused":main.world.paused,
		"core_unchanged":core_checkpoint() == baseline,"authority_unchanged":main.world == authority,"sea_and_ice_geometry_unchanged":geometry_held,
		"worker_pool_threads":ProjectSettings.get_setting("threading/worker_pool/max_threads"),"max_fps":Engine.max_fps,"foreground_fps":30,
		"render_ratio":main._render_ratio,"audio_volume_db":main._audio.volume_db,"persistence_enabled":main._persistence_enabled,
		"user_save_accessed":false,"native_input_disabled":get_viewport().gui_disable_input,"unfocusable":get_window().unfocusable}
	await finish()

func write_report(status: String) -> void:
	var report: Dictionary = {"status":status,"cases":cases,"failures":failures,"captures":captures,"observations":observations,
		"capture_window_settings":capture_settings,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"new_water_physics_tested":false}
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ") + "\n")

func finish() -> void:
	write_report("completed")
	print("POLAR_WATER_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
