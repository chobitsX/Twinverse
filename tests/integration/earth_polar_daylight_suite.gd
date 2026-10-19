extends "res://tests/integration/polar_water_suite.gd"
## One bounded observation route on the original globe and coast; no new solar model.
const GlobalDaylight = preload("res://scripts/experience/earth_daylight.gd")
const LocalSeasons = preload("res://scripts/experience/season_observation.gd")
const GeoOrientation = preload("res://scripts/core/celestial_orientation.gd")
const ReferenceSites = preload("res://scripts/data/earth_sites.gd")
const CatalogSpecies = preload("res://scripts/experience/species_catalog.gd")
var samples: Array[Dictionary] = []

func linkage_sample(label: String) -> Dictionary:
	var site: Dictionary = ReferenceSites.for_scale("polar")
	var normal: Vector3 = ReferenceSites.normal(float(site.lat),float(site.lon))
	var sun: Vector3 = GeoOrientation.sun_ecef(main.solar_jd)
	var local: Dictionary = LocalSeasons.sample(main.solar_jd,"polar")
	var stage: Node = main.coordinator.active_scene
	var value: Dictionary = {"view":label,"scale":main.world.current_scale_id,"jd":main.solar_jd,
		"solar_rate":main.solar_rate,"world_time_s":main.world.simulation_time_s,"point_dot_sun":normal.dot(sun),
		"local_sun_y":local.sun.y,"elevation_deg":local.elevation,"daylight_hours":local.daylight,
		"sun_ecef":[sun.x,sun.y,sun.z],"local_sun":[local.sun.x,local.sun.y,local.sun.z]}
	if main.world.current_scale_id=="earth":
		var data: Dictionary = stage.get_meta("earth_daylight")
		var reference: MeshInstance3D = data.reference
		var color: Color = reference.material_override.albedo_color
		value["reference_active"] = data.polar_reference
		value["reference_position"] = [reference.position.x,reference.position.y,reference.position.z]
		value["reference_color"] = [color.r,color.g,color.b]
		check(label+" original globe shader, point and local sun agree",stage.materials[0].get_shader_parameter("sun_direction").is_equal_approx(sun) and
			absf(normal.dot(sun)-float(local.sun.y))<.000001 and reference.position.is_equal_approx(normal*(GlobalDaylight.RADIUS+.05)) and
			color==(GlobalDaylight.DAY if local.sun.y>=0.0 else GlobalDaylight.NIGHT))
	else:
		value["coast_elevation_deg"] = stage.get_meta("sun_elevation")
		var light: DirectionalLight3D = stage.get_meta("daylight_sun")
		value["direct_energy"] = light.light_energy
		value["sky_sun_visible"] = stage.get_meta("daylight_sky_sun").visible
		check(label+" original coastal direction and direct energy match globe point",absf(normal.dot(sun)-float(local.sun.y))<.000001 and
			absf(float(stage.get_meta("sun_elevation"))-float(local.elevation))<.00001 and light.basis.z.normalized().dot(local.sun)>.99999 and
			absf(light.light_energy-maxf(0.0,float(local.sun.y))*1.8)<.00001)
	samples.append(value)
	return value

func take(label: String) -> void:
	await settle()
	linkage_sample(label)
	await capture(label)

func controls_fit(earth: bool) -> bool:
	var panel: Node = main.explorer_panel
	var clip: Rect2 = panel.scroll.get_global_rect().grow(.5)
	var controls: Array[Control] = [panel.topic_picker]
	if panel.journey_return_button.is_visible_in_tree(): controls.append(panel.journey_return_button)
	if earth:
		var daylight: Node = panel.earth_daylight_controls
		controls.append_array([daylight.date_label,daylight.table,daylight.reference_button,daylight.coast_button,daylight.reference_label,daylight.exit_button])
		for button: Button in daylight.date_buttons: controls.append(button)
	else:
		controls.append_array([panel.polar_globe_button,panel.lesson_controls,panel.season_controls,panel.lesson_readout])
	for control: Control in controls:
		if not control.is_visible_in_tree() or not clip.encloses(control.get_global_rect()): return false
	return true

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world245-review="): directory=argument.trim_prefix("--world245-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	main=Experience.instantiate()
	main.world.set_paused(true)
	add_child(main)
	main._measurement_screen=get_window().current_screen
	main._audio.volume_db=-80.0
	get_window().size=Vector2i(1280,800)
	get_tree().create_timer(75.0).timeout.connect(func() -> void:
		push_error("Earth/polar linkage short check exceeded its bound")
		get_tree().quit(2))
	if not await ready_stage(): await finish(); return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world.simulation_time_s=12.0
	main.world.set_time_scale(2.0)
	main.set_solar_rate(1.0)
	var noon_jd: float = LocalSeasons.preset(1,"polar")
	var night_jd: float = noon_jd-.5
	main.set_solar_date(night_jd)
	main.ground_light_preview=false
	main.world_guide.hide()
	main.explorer_panel.show()
	await settle()
	var panel: Node = main.explorer_panel
	var authority: RefCounted = main.world
	var core: Dictionary = core_checkpoint()
	check("original Earth daylight topic remains reachable",panel.select_topic("earth_daylight"))
	await settle()
	var data: Dictionary = main.coordinator.active_scene.get_meta("earth_daylight")
	check("ordinary five parallels keep reference point hidden and original controls",data.bands.size()==5 and not data.polar_reference and not data.reference.visible and
		panel.earth_daylight_controls.date_buttons.size()==4 and panel.earth_daylight_controls.values.size()==6 and main.solar_jd==night_jd and main.solar_rate==1.0)
	panel.earth_daylight_controls.reference_button.pressed.emit()
	await settle()
	check("actual reference action shows the same globe with unchanged date playback",data.polar_reference and data.reference.visible and data.root.visible and
		main.solar_jd==night_jd and main.solar_rate==1.0 and core_checkpoint()==core and
		main.coordinator.active_scene.world_root.find_children("Earth_NASA_2004_01","MeshInstance3D",true,false).size()==1)
	check("wide Earth reference point and original date controls fit",controls_fit(true) and main.learning_overlay.last_visible_marks>0)
	await take("earth-reference-night")
	panel.earth_daylight_controls.coast_button.pressed.emit()
	var cancel_started: bool = main.coordinator.is_busy()
	check("actual coastal visit can be cancelled before commit",cancel_started)
	if cancel_started: main.coordinator.cancel("earth_polar245_cancel")
	if not await ready_stage(): await finish(); return
	await settle()
	check("cancellation keeps original globe authority date rate and no pending visit",main.world.current_scale_id=="earth" and main.world==authority and
		main.solar_jd==night_jd and main.solar_rate==1.0 and core_checkpoint()==core and main._guide_visit.is_empty())
	panel.show()
	panel._process(0.0)
	panel.earth_daylight_controls.coast_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	check("actual coastal link selects original season topic without forcing noon",main.world.current_scale_id=="polar" and main.learning_overlay.topic=="season_light" and
		main.solar_jd==night_jd and main.solar_rate==1.0 and main.ground_light_preview and core_checkpoint()==core)
	check("wide coast shows existing date controls and new globe return",controls_fit(false))
	await take("polar-reference-night")
	# Restore only the existing seventh-station fixture, then exercise its real lesson/return.
	var tour: Node = main.guided_journey
	tour.restore({"version":1,"step":0,"started":false,"completed":false,"active_route":"world",
		"world_tour":{"version":1,"step":6,"started":true,"completed":false}})
	tour.open("world")
	await settle()
	tour.lesson_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	check("original seventh tour station enters same night lesson without date changes",tour.has_lesson_return() and tour.step==6 and
		main.learning_overlay.topic=="season_light" and main.solar_jd==night_jd and main.solar_rate==1.0 and core_checkpoint()==core)
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact coastal comparison and original season controls fit",controls_fit(false))
	await take("polar-reference-compact")
	panel.polar_globe_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	data=main.coordinator.active_scene.get_meta("earth_daylight")
	check("actual globe return restores corresponding point without changing date rate",main.world.current_scale_id=="earth" and main.learning_overlay.topic=="earth_daylight" and
		data.polar_reference and data.reference.visible and main.solar_jd==night_jd and main.solar_rate==1.0 and main.world==authority and core_checkpoint()==core)
	check("globe link retains original seventh-station tour return",panel.journey_return_button.is_visible_in_tree() and tour.has_lesson_return() and tour.step==6)
	check("compact Earth comparison and original dates table exit fit",controls_fit(true))
	await take("earth-reference-compact")
	main.learning_overlay.enabled=false
	await settle()
	check("observation helper toggle hides reference and arcs together",not data.root.visible and not data.reference.is_visible_in_tree() and main.learning_overlay.last_visible_marks==0)
	main.learning_overlay.enabled=true
	await settle()
	check("helper toggle restores same reference without clock or date writes",data.root.visible and data.reference.is_visible_in_tree() and main.solar_jd==night_jd and core_checkpoint()==core)
	panel.journey_return_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	check("actual tour return reaches original seventh station with date authority held",tour.visible and tour.step==6 and tour.pending==-1 and
		main.world.current_scale_id=="polar" and main.solar_jd==night_jd and main.solar_rate==1.0 and main.world==authority and core_checkpoint()==core)
	tour.lesson_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	panel.polar_globe_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	check("same lesson and globe link reopen after original tour return",main.world.current_scale_id=="earth" and main.learning_overlay.topic=="earth_daylight" and
		main.coordinator.active_scene.get_meta("earth_daylight").polar_reference and main.solar_jd==night_jd and tour.has_lesson_return())
	data=main.coordinator.active_scene.get_meta("earth_daylight")
	panel.select_topic("earth_daylight")
	await settle()
	check("ordinary Earth lesson reopens original framing without pending reference",not data.polar_reference and not data.reference.visible and data.bands.size()==5 and main.solar_jd==night_jd and main.solar_rate==1.0)
	panel.earth_daylight_controls.date_buttons[1].pressed.emit()
	await settle()
	check("original explicit June date still pauses date playback only",main.solar_jd==LocalSeasons.preset(1,"earth") and main.solar_rate==0.0 and core_checkpoint()==core)
	main.set_solar_date(noon_jd)
	get_window().size=Vector2i(1280,800)
	panel.earth_daylight_controls.reference_button.pressed.emit()
	await settle()
	check("same June reference twelve hours later is above geometric horizon",main.solar_jd==noon_jd and noon_jd-night_jd==.5 and LocalSeasons.sample(main.solar_jd,"polar").sun.y>0.0)
	await take("earth-reference-day")
	panel.earth_daylight_controls.coast_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	check("daytime coast keeps corresponding date zero date rate and original animals",main.world.current_scale_id=="polar" and main.solar_jd==noon_jd and main.solar_rate==0.0 and
		main.coordinator.active_scene.get_meta("polar").birds.size()==4 and main.coordinator.active_scene.get_meta("ice_krill").animals.size()==12 and core_checkpoint()==core)
	await take("polar-reference-day")
	panel.polar_globe_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	main._remember_view()
	check("reference context adds no observer save fields",not main._views.earth.has("polar_reference") and not main._views.earth.has("earth_polar_reference") and
		main._views.earth.astronomy.jd==noon_jd)
	panel.earth_daylight_controls.exit_button.pressed.emit()
	await settle()
	data=main.coordinator.active_scene.get_meta("earth_daylight")
	check("exit restores original five Earth choices and hides all transient reference",not data.active and not data.polar_reference and not data.root.visible and
		main.learning_overlay.topic.is_empty() and main.earth_entry_panel.visible and main.earth_entry_panel.buttons.size()==5 and main.solar_jd==noon_jd)
	await capture("earth-original-entrances")
	check("sole authority models paused seconds playback and existing content remain",main.world==authority and core_checkpoint()==core and main.world.paused and
		main.world.simulation_time_s==12.0 and main.world.time_scale==2.0 and CatalogSpecies.ENTRIES.size()==41 and main.world_guide.route_buttons.size()==93)
	check("resource and diagnostic user-save limits remain applied",Engine.max_fps==5 and ProjectSettings.get_setting("application/run/max_fps")==30 and
		ProjectSettings.get_setting("threading/worker_pool/max_threads")==2 and main._render_ratio==.75 and main._audio.volume_db==-80.0 and
		not main._persistence_enabled and get_window().unfocusable and get_viewport().gui_disable_input)
	observations={"samples":samples,"world_time_s":main.world.simulation_time_s,"paused":main.world.paused,"time_scale":main.world.time_scale,
		"date_jd":main.solar_jd,"solar_rate":main.solar_rate,"authority_unchanged":main.world==authority,"core_unchanged":core_checkpoint()==core,
		"named_species":41,"guide_routes":93,"worker_pool_threads":2,"max_fps":Engine.max_fps,"foreground_fps":30,"render_ratio":main._render_ratio,
		"audio_volume_db":main._audio.volume_db,"persistence_enabled":main._persistence_enabled,"user_save_accessed":false,
		"native_input_disabled":get_viewport().gui_disable_input,"unfocusable":get_window().unfocusable,
		"world_tour_seventh_station_fixture":true,"full_world_tour_replayed":false}
	await finish()

func write_report(status: String) -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":status,"cases":cases,"failures":failures,
		"captures":captures,"observations":observations,"capture_window_settings":capture_settings,"debug":OS.is_debug_build(),
		"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false,
		"new_light_physics_tested":false},"  ")+"\n")

func finish() -> void:
	write_report("completed")
	print("EARTH_POLAR_DAYLIGHT245_FINISHED ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
