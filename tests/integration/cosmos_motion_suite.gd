extends "res://tests/integration/spatial_input_suite.gd"
## Short actual World-driven motion, pause, navigation and scientific UI checks.
var motion_samples: Array[Dictionary] = []
var section: String = "all"

func ready_stage() -> bool:
	var deadline: int = Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground and DisplayServer.window_can_draw(): return true
		if not main.coordinator.recovery_state().is_empty(): break
	var details: Dictionary = {"scale":main.world.current_scale_id,"phase":main.coordinator.phase,"foreground":main.world.foreground,"drawable":DisplayServer.window_can_draw(),"recovery":main.coordinator.recovery_state(),"science_error":main.world.science.error}
	FileAccess.open(directory.path_join("stage-failure.json"),FileAccess.WRITE).store_string(JSON.stringify(details,"\t"))
	check("ready stage",false); return false

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cosmos259-output="): directory = arg.trim_prefix("--cosmos259-output=")
		if arg.begins_with("--cosmos259-section="): section = arg.trim_prefix("--cosmos259-section=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(120).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate(); add_child(main)
	main._measurement_screen = get_window().current_screen
	main._reduced_motion = true; main.world.set_paused(true)
	if is_instance_valid(main._audio): main._audio.volume_db = -80
	if not await ready_stage(): await finish(); return
	original_id = main.world.get_instance_id()
	if section=="motion":
		await motion(main.world.current_scale_id)
		await finish(); return
	check("universe has real navigation above galaxy",main.Catalog.relative("galaxy",-1)=="universe" and main.Catalog.relative("universe",1)=="galaxy")
	await zoom_scale("universe"); main._reset_camera(); await settle()
	check("universe keeps scientific boundary accessible",main.immersive_interface.source_button.text.contains("示意") and main.ScienceReference.describe("universe").sources.size()==2)
	await motion("universe")
	var universe: Node = main.coordinator.active_scene
	var panorama: Dictionary = universe.get_meta("cosmic_panorama")
	check("galaxies remain bound-size objects during expansion",panorama.galaxies[1].node.scale==Vector3.ONE and panorama.galaxies[0].node.position==Vector3.ZERO)
	main.immersive_interface._menu_action(11); await settle()
	check("expansion replay changes presentation only",panorama.factor==1.0 and main.world.get_instance_id()==original_id and main.world.paused)
	await object_entry("universe","galaxy")
	if not await ready_stage(): await finish(); return
	check("3D Milky Way entry reaches galaxy",main.world.current_scale_id=="galaxy")
	main._reset_camera(); await settle(); await motion("galaxy")
	var galaxy: Node = main.coordinator.active_scene
	check("moving Sun stays at reference galactocentric distance",absf(galaxy.target_position.length()-galaxy.builder.Galactic.sun_position().length())<.00001)
	check("galactic shader reads the same World time",is_equal_approx(float(galaxy.materials[0].get_shader_parameter("world_time")),main.world.simulation_time_s))
	main._navigate_relative(-1); if not await ready_stage(): await finish(); return
	check("galaxy returns to cosmic context",main.world.current_scale_id=="universe")
	if not await arrive("solar_system"): await finish(); return
	main.explorer_panel.hide(); main.info_panel.hide(); main._reset_camera(); await settle()
	check("first solar overview runs astronomy dates by default",main.solar_demo_auto and main.solar_rate==10.0)
	check("compact astronomy UI exposes rate and date",main.immersive_interface.rate_button.text=="10天/秒" and main.time_label.text.contains("TDB") and main.immersive_interface.source_button.text.contains("世界秒"))
	await motion("solar_system")
	var solar: Node = main.coordinator.active_scene
	var bodies: Array = solar.get_meta("solar_bodies")
	check("planets still use the exact displayed ephemeris positions",bodies[0].node.position.is_equal_approx(Ephemeris.display_position(0,main.solar_jd,main.solar_true_distance)) and bodies[7].node.position.is_equal_approx(Ephemeris.display_position(7,main.solar_jd,main.solar_true_distance)))
	main._remember_view()
	var view: Dictionary = main._views.solar_system
	check("new astronomy auto setting remains a valid observer save",main.WorldStore.valid_view(view) and view.astronomy.auto)
	main.immersive_interface._set_rate(0); await settle()
	check("user date hold overrides autoplay",main.solar_rate==0.0 and not main.solar_demo_auto)
	var date: float = main.solar_jd; main.world.set_paused(false); await seconds(.7); main.world.set_paused(true)
	check("date hold retains date while life seconds can continue",main.solar_jd==date)
	main.immersive_interface._set_rate(3); main.follow_planet(2); await settle()
	var offset: Vector3 = solar.camera.position-main._orbit_target
	main.world.set_paused(false); await seconds(1.0); main.world.set_paused(true); await settle()
	check("planet following continues through real motion",(solar.camera.position-main._orbit_target).is_equal_approx(offset))
	main.set_solar_distance(true); await settle()
	check("true-distance mode preserves AU mapping and hides visual history",not solar.get_meta("solar_history").node.visible and absf(bodies[7].node.position.length()/Ephemeris.position_au(7,main.solar_jd).length()-.55)<.00001)
	main.set_solar_distance(false); main.follow_planet(5); await settle()
	var markers: Node3D = solar.world_root.get_node_or_null("SelectedOrbitEqualTime")
	check("near planets keep equal-time teaching markers out of the close view",markers==null or not markers.visible)
	check("astronomy transport leaves the knowledge action accessible",main.immersive_interface.details_button.get_global_rect().end.x<main.immersive_interface.transport.get_global_rect().position.x)
	await capture("saturn-detail")
	main.focus_planet_orbit(5); await settle()
	check("orbit teaching view still exposes its original date samples",solar.world_root.get_node("SelectedOrbitEqualTime").visible and solar.world_root.get_node("SelectedDE440Trajectory").visible)
	main.set_solar_date(Ephemeris.END_JD-.01); main.set_solar_rate(100.0)
	main.world.set_paused(false); await seconds(.4); main.world.set_paused(true); await settle()
	check("motion stops at ephemeris date boundary",main.solar_rate==0 and main.solar_jd==Ephemeris.END_JD)
	main.set_solar_date(Ephemeris.DEFAULT_JD); main.set_solar_rate(0.0)
	if not await arrive("earth"): await finish(); return
	check("Earth UI and authority remain usable",is_instance_valid(main.earth_entry_panel) and main.world.get_instance_id()==original_id)
	await capture("earth-retained-ui")
	check("diagnostic never saves or lifts the background cap",not main._persistence_enabled and Engine.max_fps<=5)
	await finish()

func seconds(duration: float) -> void:
	var until: int = Time.get_ticks_msec()+int(duration*1000)
	while Time.get_ticks_msec()<until: await get_tree().process_frame

func motion(id: String) -> void:
	var stage: Node = main.coordinator.active_scene
	var time: float = main.world.simulation_time_s
	var date: float = main.solar_jd
	var before: Vector3 = stage.target_position
	var factor: float = float(stage.get_meta("cosmic_panorama").factor) if id=="universe" else 1.0
	cursor(Vector2(1100,580)); main.object_pointer.clear_hover(); await settle()
	await capture(id+"-before")
	main.world.set_paused(false)
	# Five FPS diagnostics admit smaller engine deltas than wall-clock seconds.
	# Observe the real World, without raising caps or synthesizing time.
	var deadline: int = Time.get_ticks_msec()+10000
	while main.world.simulation_time_s-time<3.2 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	main.world.set_paused(true); await settle()
	var elapsed: float = main.world.simulation_time_s-time
	check(id+" motion uses actual advancing World",elapsed>=3.0 and elapsed<8.0 and main.world.get_instance_id()==original_id)
	var state: Dictionary = {"scale":id,"seconds":elapsed,"skipped":main.world.skipped_wall_time_s,"science_error":main.world.science.error,"paused":main.world.paused,"foreground":main.world.foreground,"drawable":DisplayServer.window_can_draw(),"window_screen":main._measurement_screen}
	FileAccess.open(directory.path_join(id+"-state.json"),FileAccess.WRITE).store_string(JSON.stringify(state,"\t"))
	print("COSMOS259_MOTION_STATE ",JSON.stringify(state))
	if id=="universe": check("cosmic distances expand visibly",float(stage.get_meta("cosmic_panorama").factor)>factor+.04)
	elif id=="galaxy": check("solar anchor visibly orbits the galactic center",stage.target_position.distance_to(before)>.7)
	else:
		check("solar dates advance at labelled rate",absf((main.solar_jd-date)-elapsed*30.0)<.00001)
		check("inner and outer orbit speeds stay distinct",stage.get_meta("solar_bodies")[0].node.position.distance_to(Ephemeris.display_position(0,date))>1.0 and stage.get_meta("solar_bodies")[7].node.position.distance_to(Ephemeris.display_position(7,date))<.3)
	await capture(id+"-after")
	var held_time: float = main.world.simulation_time_s
	var held_date: float = main.solar_jd
	var held_target: Vector3 = stage.target_position
	var image_before: PackedByteArray = get_viewport().get_texture().get_image().get_data()
	await seconds(.8)
	check(id+" pause freezes World date and target",main.world.simulation_time_s==held_time and main.solar_jd==held_date and stage.target_position==held_target)
	check(id+" rendered paused image is stable",image_before==get_viewport().get_texture().get_image().get_data())
	motion_samples.append({"scale":id,"world_seconds":elapsed,"days":main.solar_jd-date,"before_target":var_to_str(before),"after_target":var_to_str(stage.target_position),"expansion_factor":stage.get_meta("cosmic_panorama").factor if id=="universe" else null})

func finish() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"motion_samples":motion_samples,"debug_build":OS.is_debug_build(),"driver":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"os_physical_gestures_tested":false},"\t")+"\n")
	print("COSMOS259_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
