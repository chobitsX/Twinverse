extends "res://tests/integration/spatial_input_suite.gd"
## Finite checks of restored playback intent, actual picking and rendered motion.
var motion_samples: Array[Dictionary] = []
var observer_input: String = ""

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solar260-output="): directory=argument.trim_prefix("--solar260-output=")
		if argument.begins_with("--solar260-observer="): observer_input=argument.trim_prefix("--solar260-observer=")
	if not directory.is_absolute_path() or not observer_input.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(100.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80
	if not await ready_stage(): await finish(); return
	original_id=main.world.get_instance_id()
	main.explorer_panel.hide(); main.info_panel.hide(); main._reset_camera(); await settle()
	check("fresh solar overview defaults to visible date playback",main.world.current_scale_id=="solar_system" and main.solar_rate==10.0 and main.solar_demo_auto and not main.solar_manual_setting)
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(observer_input))
	check("input reproduces user's held default without a paused World",legacy.world.current_scale_id=="solar_system" and not legacy.world.paused and legacy.astronomy.solar_system.jd==Ephemeris.DEFAULT_JD and legacy.astronomy.solar_system.rate==0 and not legacy.astronomy.solar_system.auto)
	main._views={}
	for id: String in legacy.astronomy: main._views[id]={"astronomy":legacy.astronomy[id].duplicate(true)}
	var world_before: Dictionary=main.world.checkpoint()
	main._restore_solar_view(); main._update_ui(); await settle()
	check("actual old observer fields resume the default solar playback",main.solar_demo_auto and not main.solar_manual_setting and main.solar_rate==10.0 and main.solar_jd==Ephemeris.DEFAULT_JD)
	check("restoring playback keeps the same World and checkpoint",main.world.get_instance_id()==original_id and main.world.checkpoint()==world_before)
	check("compact UI states the active orbital rate and TDB date",main.immersive_interface.rate_button.text=="10天/秒" and main.time_label.text.contains("TDB") and main.immersive_interface.source_button.text.contains("公转") and main.immersive_interface.source_button.text.contains("世界秒"))
	main._views={}; cursor(Vector2(1250,160)); main.object_pointer.clear_hover(); await settle()
	check("overview has no persistent name boxes or leader lines",main.learning_overlay.last_solar_labels.is_empty() and not main.object_pointer.tooltip.visible and not main.immersive_interface.context_panel.visible)
	var bodies: Array=main.coordinator.active_scene.get_meta("solar_bodies")
	var hidden: bool=true
	for body: Dictionary in bodies: hidden=hidden and not body.label.visible
	check("old three-dimensional planet labels also stay hidden",hidden)
	await capture("overview-no-names")
	for index: int in range(-1,8):
		main._reset_camera(); await settle()
		var name: String="太阳" if index<0 else Ephemeris.NAMES[index]
		var hit: Dictionary=visible_choice("",name)
		check(name+" has an actual visible mesh hit",not hit.is_empty())
		if hit.is_empty(): continue
		cursor(hit.point); await settle()
		check(name+" hover exposes only the pointed name",main.object_pointer.tooltip.visible and main.object_pointer.tooltip.text==name and main.learning_overlay.last_solar_labels.is_empty())
		if index in [-1,2]: await capture("hover-sun" if index<0 else "hover-earth")
		click(hit.point); await settle()
		check(name+" click gives selected context without an object menu",main.selected_spatial_choice().get("label","")==name and main.immersive_interface.context_panel.visible and main.immersive_interface.context_title.text==name and not main.explorer_panel.visible and not main.world_guide.visible)
		if index==2: await capture("selected-earth")
	main._reset_camera(); await settle()
	var sun: Dictionary=visible_choice("","太阳")
	click(sun.point); await settle()
	# The original object selector must switch from Sun to a planet without
	# leaving the Sun observer selected.
	main.follow_planet(2); await settle()
	check("planet selection clears the prior Sun observer",main._content_follow==-1 and main.selected_spatial_choice().get("planet",-1)==2)
	main._reset_camera(); await settle()
	main.clean_observation.set_active(true)
	sun=visible_choice("","太阳"); cursor(sun.point); await settle()
	check("pure observation still permits requested solar hover names",main.object_pointer.tooltip.is_visible_in_tree() and main.object_pointer.tooltip.text=="太阳")
	await capture("pure-hover")
	main.clean_observation.set_active(false); cursor(Vector2(1250,160)); main.object_pointer.clear_hover(); await settle()
	await orbital_motion()
	var saturn_hit: Dictionary=visible_choice("","土星")
	check("moving hover starts from real Saturn geometry",not saturn_hit.is_empty())
	cursor(saturn_hit.point); await settle()
	main.world.set_paused(false); await world_seconds(.3); main.world.set_paused(true); await settle()
	check("stationary pointer retains the name while Saturn moves underneath",main.object_pointer.tooltip.is_visible_in_tree() and main.object_pointer.tooltip.text=="土星" and main.object_pointer.pick(saturn_hit.point).get("planet",-1)==5)
	cursor(Vector2(1250,160)); await settle()
	check("moving-body caption clears when the pointer leaves",not main.object_pointer.tooltip.visible)
	var position: Vector3=bodies[5].node.position
	main.follow_planet(5); await settle()
	var offset: Vector3=main.coordinator.active_scene.camera.position-main._orbit_target
	main.world.set_paused(false); await world_seconds(.4); main.world.set_paused(true); await settle()
	check("following a moving planet retains the same camera offset",bodies[5].node.position.distance_to(position)>.001 and (main.coordinator.active_scene.camera.position-main._orbit_target).is_equal_approx(offset))
	main.set_solar_rate(0.0); main.set_solar_date(Ephemeris.DEFAULT_JD); main._remember_view()
	var saved: Dictionary=main._views.solar_system.duplicate(true)
	check("new explicit date hold is a valid marked observer save",saved.astronomy.manual and not saved.astronomy.auto and saved.astronomy.rate==0 and main.WorldStore.valid_view(saved))
	main.solar_demo_auto=true; main.solar_manual_setting=false
	main._restore_solar_view(); main._update_ui(); await settle()
	check("explicitly held default survives restore without autoplay",not main.solar_demo_auto and main.solar_manual_setting and main.solar_rate==0 and main.solar_jd==Ephemeris.DEFAULT_JD)
	var date: float=main.solar_jd
	main.world.set_paused(false); await world_seconds(.4); main.world.set_paused(true); await settle()
	check("explicit hold stops orbits while life seconds can advance",main.solar_jd==date and main.world.get_instance_id()==original_id)
	var old: Dictionary=saved.astronomy.duplicate(true); old.erase("manual"); old.jd=Ephemeris.DEFAULT_JD+7.0; old.time=main.world.simulation_time_s
	main._views={"solar_system":{"astronomy":old}}; main._restore_solar_view(); main._update_ui()
	check("legacy chosen non-default dates are preserved exactly",not main.solar_demo_auto and main.solar_manual_setting and main.solar_jd==Ephemeris.DEFAULT_JD+7.0 and main.solar_rate==0)
	old.jd=Ephemeris.DEFAULT_JD; old.rate=10.0
	main._restore_solar_view(); main._update_ui()
	check("legacy chosen nonzero rates are preserved",not main.solar_demo_auto and main.solar_rate==10.0)
	main._views={}; main._reset_camera(); main.set_solar_rate(30.0); main._remember_view()
	check("new orbital rate survives the shared save validator",main.WorldStore.valid_view(main._views.solar_system))
	var invalid: Dictionary=main._views.solar_system.duplicate(true); invalid.astronomy.manual="yes"
	check("invalid manual intent does not pass save validation",not main.WorldStore.valid_view(invalid))
	main.immersive_interface._set_rate(1); main.follow_planet(2); await settle()
	var basis: Basis=bodies[2].node.basis
	main.world.set_paused(false); await world_seconds(.65); main.world.set_paused(true); await settle()
	check("rotation observing rate uses the real IAU date pose",absf(main.solar_rate-1.0/24.0)<1e-12 and not bodies[2].node.basis.is_equal_approx(basis))
	await capture("earth-rotation-view")
	main._reset_camera(); main.set_solar_rate(30.0); main.set_solar_date(Ephemeris.DEFAULT_JD)
	get_window().size=Vector2i(900,650); await settle()
	var compact: Dictionary=visible_choice("","太阳"); cursor(compact.point); await settle()
	check("compact hover caption fits inside the actual window",not compact.is_empty() and main.object_pointer.tooltip.visible and get_viewport().get_visible_rect().encloses(main.object_pointer.tooltip.get_global_rect()))
	await capture("compact-hover")
	get_window().size=Vector2i(1280,800); cursor(Vector2(1250,160)); main.object_pointer.clear_hover(); await settle()
	main.set_solar_date(Ephemeris.END_JD-.01); main.set_solar_rate(30.0)
	main.world.set_paused(false); await world_seconds(.3); main.world.set_paused(true); await settle()
	check("automatic dates stop at the ephemeris boundary",main.solar_jd==Ephemeris.END_JD and main.solar_rate==0)
	check("diagnostic keeps one authority and the bounded no-save engine",main.world.get_instance_id()==original_id and not main._persistence_enabled and Engine.max_fps<=5)
	await finish()

func world_seconds(duration: float) -> void:
	var start: float=main.world.simulation_time_s
	var deadline: int=Time.get_ticks_msec()+int(duration*1800.0)+2500
	while main.world.simulation_time_s-start<duration and Time.get_ticks_msec()<deadline: await get_tree().process_frame

func orbital_motion() -> void:
	main._reset_camera(); main.message_label.text=""; cursor(Vector2(1250,160)); main.object_pointer.clear_hover(); await settle()
	var stage: Node=main.coordinator.active_scene
	var before: Array[Vector3]=[]
	var pixels: Array[Vector2]=[]
	for body: Dictionary in stage.get_meta("solar_bodies"):
		before.append(body.node.position); pixels.append(stage.camera.unproject_position(body.node.global_position))
	var date: float=main.solar_jd
	var start: float=main.world.simulation_time_s
	await capture("orbit-before")
	var recorder: RefCounted=main.MotionRecorder.new()
	check("short motion recorder observes the actual viewport",recorder.begin(directory.path_join("orbital-motion"),get_viewport(),{"max_duration_s":12.0,"max_frames":60,"max_output_bytes":52428800,"queue_frame_limit":2,"scenario":"solar orbital playback from legacy observer","performance_test":false})==OK)
	main.world.set_paused(false)
	var deadline: int=Time.get_ticks_msec()+12000
	while main.world.simulation_time_s-start<5.2 and Time.get_ticks_msec()<deadline:
		recorder.sample({"world_s":main.world.simulation_time_s,"jd":main.solar_jd,"rate_days_per_world_s":main.solar_rate})
		await RenderingServer.frame_post_draw
	main.world.set_paused(true)
	var motion: Dictionary=recorder.finish()
	await settle()
	var elapsed: float=main.world.simulation_time_s-start
	check("default restored playback visibly advances the real date",elapsed>=5.0 and absf((main.solar_jd-date)-elapsed*10.0)<.00001)
	var exact: bool=true
	var body_samples: Array[Dictionary]=[]
	for index: int in range(8):
		var node: Node3D=stage.get_meta("solar_bodies")[index].node
		var at: Vector2=stage.camera.unproject_position(node.global_position)
		var displacement: float=at.distance_to(pixels[index])
		exact=exact and node.position.is_equal_approx(Ephemeris.display_position(index,main.solar_jd,main.solar_true_distance))
		check(Ephemeris.NAMES[index]+" visibly moves on the fixed overview camera",displacement>1.0 and node.position.distance_to(before[index])>.001)
		body_samples.append({"name":Ephemeris.NAMES[index],"pixel_displacement":displacement,"world_displacement":node.position.distance_to(before[index]),"before":var_to_str(before[index]),"after":var_to_str(node.position)})
	check("all eight bodies still use the common DE440 date",exact)
	var angles: Array[float]=[]
	for index: int in [2,5,7]: angles.append(Ephemeris.position_au(index,date).normalized().angle_to(Ephemeris.position_au(index,main.solar_jd).normalized()))
	check("inner planets orbit faster than the outer planets",angles[0]>angles[1]*5.0 and angles[1]>angles[2]*2.0)
	check("actual rendered motion records finite frames without writer errors",motion.get("written_frames",0)>=20 and motion.get("writer_errors",[]).is_empty())
	motion_samples.append({"world_seconds":elapsed,"days":main.solar_jd-date,"common_rate":main.solar_rate,"bodies":body_samples,"capture_manifest":motion})
	await capture("orbit-after")
	var paused_pixels: PackedByteArray=get_viewport().get_texture().get_image().get_data()
	var paused_time: float=main.world.simulation_time_s
	var paused_date: float=main.solar_jd
	for frame: int in range(4): await get_tree().process_frame
	check("World pause stops orbital dates and rendered motion",main.world.simulation_time_s==paused_time and main.solar_jd==paused_date and paused_pixels==get_viewport().get_texture().get_image().get_data())

func finish() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"motion_samples":motion_samples,"debug_build":OS.is_debug_build(),"driver":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"os_physical_gestures_tested":false,"observer_input":observer_input},"\t")+"\n")
	print("SOLAR260_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
