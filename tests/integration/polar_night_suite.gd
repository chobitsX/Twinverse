extends "res://tests/integration/polar_water_suite.gd"
## Bounded author-sky appearance check using the existing date and sun geometry.

const NightSeasons = preload("res://scripts/experience/season_observation.gd")
const NightPrimer = preload("res://scripts/render_feature_primer.gd")
var light_samples: Array[Dictionary] = []
var baseline_only: bool = false
var night_sky_dark: bool = false

func color_values(value: Color) -> Array[float]:
	return [value.r, value.g, value.b]

func light_sample(label: String, stage: Node) -> Dictionary:
	var sun: DirectionalLight3D = stage.get_meta("daylight_sun")
	var sky_sun: DirectionalLight3D = stage.get_meta("daylight_sky_sun")
	var sky: ProceduralSkyMaterial = stage.environment.sky.sky_material
	var direction: Vector3 = NightSeasons.sample(main.solar_jd, "polar").sun
	var value: Dictionary = {"view":label,"date_jd":main.solar_jd,"sun_direction":[direction.x,direction.y,direction.z],
		"sun_elevation_deg":stage.get_meta("sun_elevation"),"direct_energy":sun.light_energy,"sky_sun_visible":sky_sun.visible,
		"sky_top":color_values(sky.sky_top_color),"sky_horizon":color_values(sky.sky_horizon_color),
		"ground_horizon":color_values(sky.ground_horizon_color),"ground_bottom":color_values(sky.ground_bottom_color),
		"fog_color":color_values(stage.environment.fog_light_color),"world_time_s":main.world.simulation_time_s}
	light_samples.append(value)
	check(label + " preserves original direction and direct energy", sun.transform.basis.z.normalized().dot(direction) > .99999 and
		absf(sun.light_energy - maxf(0.0, direction.y) * 1.8) < .00001 and sky_sun.transform == sun.transform)
	return value

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world244-review="): directory = argument.trim_prefix("--world244-review=")
	baseline_only = "--night-baseline244" in OS.get_cmdline_user_args()
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	get_window().size = Vector2i(1280, 800)
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen == DisplayServer.get_primary_screen(): continue
		get_window().set_meta("preview_secondary_screen", screen)
		get_window().current_screen = screen
		get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30, 30)
		break
	Engine.max_fps = 5
	if "--night-direct-scene244" in OS.get_cmdline_user_args():
		var primer: Node = NightPrimer.new()
		add_child(primer)
		await primer.prepare()
		primer.queue_free()
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	main._audio.volume_db = -80.0
	get_window().size = Vector2i(1280, 800)
	get_tree().create_timer(75.0).timeout.connect(func() -> void:
		push_error("Polar night appearance short check exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world.simulation_time_s = .1
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
	var core: Dictionary = core_checkpoint()
	var date: float = main.solar_jd
	var surface: MeshInstance3D = stage.world_root.get_node("OpenSouthernOceanReference") as MeshInstance3D
	var material: ShaderMaterial = surface.get_active_material(0) as ShaderMaterial
	var sea_mesh: Mesh = surface.mesh
	var sea_transform: Transform3D = surface.transform
	var sky: ProceduralSkyMaterial = stage.environment.sky.sky_material
	var original_colors: Array[Color] = [sky.sky_top_color,sky.sky_horizon_color,sky.ground_horizon_color,sky.ground_bottom_color]
	await capture("night-fixed-day")
	main.ground_light_preview = true
	main.set_solar_date(NightSeasons.preset(1, "polar"))
	await settle()
	var noon_jd: float = main.solar_jd
	var noon: Dictionary = light_sample("june-noon", stage)
	if not baseline_only: await capture("night-june-noon")
	main.set_solar_date(noon_jd - .5)
	await settle()
	var night: Dictionary = light_sample("june-night", stage)
	check("reference night is twelve hours earlier with sun below geometric horizon", main.solar_jd == noon_jd - .5 and
		night.sun_direction[1] < -.5 and not night.sky_sun_visible and night.direct_energy == 0.0)
	night_sky_dark = sky.sky_top_color.r < .05 and sky.sky_top_color.g < .08 and sky.sky_top_color.b < .12
	await capture("night-june-night")
	if not baseline_only:
		check("author night sky is visibly darker than original fixed daylight", night_sky_dark and sky.sky_top_color != original_colors[0])
		get_window().size = Vector2i(900,650)
		await capture("night-compact")
		get_window().size = Vector2i(1280,800)
		var panel: Node = main.explorer_panel
		panel.show()
		panel._process(0.0)
		await settle()
		check("original krill topic enters underwater without changing night date", panel.select_topic("ice_krill_habitat") and main.solar_jd == noon_jd - .5)
		await settle()
		check("night underwater hides surface and retains original krill", stage.is_underwater and not surface.visible and stage.get_meta("ice_krill").animals.size() == 12)
		await capture("night-underwater")
		check("original penguin topic returns to same above-water scene", panel.select_topic("adelie_penguin"))
		panel.hide()
		await settle()
	main.ground_light_preview = false
	main.set_solar_date(date)
	main._reset_camera()
	await settle()
	check("fixed reference restores original four sky colors", [sky.sky_top_color,sky.sky_horizon_color,sky.ground_horizon_color,sky.ground_bottom_color] == original_colors)
	await capture("night-fixed-return")
	check("original water geometry and sole paused material phase remain", not stage.is_underwater and surface.visible and surface.mesh == sea_mesh and
		surface.transform == sea_transform and surface.get_active_material(0) == material and absf(float(material.get_shader_parameter("world_time"))-.1) < .0001)
	var geometry_held: bool = surface.mesh == sea_mesh and surface.transform == sea_transform
	main.navigation_bar.earth_button.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	check("Earth return restores original five choices", main.world.current_scale_id == "earth" and main.earth_entry_panel.visible and main.earth_entry_panel.buttons.size() == 5)
	check("night observation preserves authority date and core state", main.world == authority and main.world.paused and main.world.simulation_time_s == .1 and
		main.solar_jd == date and core_checkpoint() == core)
	check("resource and user-save limits remain applied", not main._persistence_enabled and get_viewport().gui_disable_input and get_window().unfocusable and
		Engine.max_fps == 5 and ProjectSettings.get_setting("application/run/max_fps") == 30 and
		ProjectSettings.get_setting("threading/worker_pool/max_threads") == 2 and main._render_ratio == .75 and main._audio.volume_db == -80.0)
	observations = {"samples":light_samples,"night_sky_dark":night_sky_dark,"noon_elevation_deg":noon.sun_elevation_deg,
		"night_elevation_deg":night.sun_elevation_deg,"world_time_s":main.world.simulation_time_s,"date_jd":main.solar_jd,"paused":main.world.paused,
		"core_unchanged":core_checkpoint() == core,"authority_unchanged":main.world == authority,"sea_geometry_unchanged":geometry_held,
		"worker_pool_threads":ProjectSettings.get_setting("threading/worker_pool/max_threads"),"max_fps":Engine.max_fps,"foreground_fps":30,
		"render_ratio":main._render_ratio,"audio_volume_db":main._audio.volume_db,"persistence_enabled":main._persistence_enabled,
		"user_save_accessed":false,"native_input_disabled":get_viewport().gui_disable_input,"unfocusable":get_window().unfocusable}
	await finish()

func write_report(status: String) -> void:
	var report: Dictionary = {"status":status,"baseline_only":baseline_only,"cases":cases,"failures":failures,"captures":captures,"observations":observations,
		"capture_window_settings":capture_settings,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"new_light_physics_tested":false}
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")

func finish() -> void:
	write_report("completed")
	print("POLAR_NIGHT_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
