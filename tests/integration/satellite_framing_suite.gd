extends "res://tests/integration/solar_entry_context_suite.gd"
## Actual camera/picking/navigation checks. No replacement ephemeris or test body.
const Framing = preload("res://scripts/experience/satellite_framing.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--framing280-output="): directory=argument.trim_prefix("--framing280-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(110.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80.0
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	var identity: int=main.world.get_instance_id()
	var stage: Node=main.coordinator.active_scene
	for owner: int in range(2,8):
		prepare_auto(); main.follow_planet(owner); await settle()
		if not await interaction_ready(): await finish(); return
		var label: String=main.Ephemeris.NAMES[owner]
		check(label+" defaults to a physical co-framed system",Framing.is_pair(stage) and int(stage.get_meta("solar_physical").owner)==owner)
		var data: Dictionary=Framing.subjects(stage,owner,str(Framing.state(stage).key))
		check_pair(stage,data,label)
		var geometry: Transform3D=data.moon.transform
		var centre: Vector3=data.planet.position
		var date: float=main.solar_jd
		var moon_pixel: Vector2=stage.camera.unproject_position(data.moon.position)
		check(label+" co-frame selects the real moon mesh",main.object_pointer.pick(moon_pixel).get("node")==data.moon)
		await capture("solar-"+str(owner)+"-pair")
		var planet_pixel: Vector2=stage.camera.unproject_position(centre)
		if not await interaction_ready(): await finish(); return
		main.object_pointer.activate(planet_pixel); await settle()
		check(label+" clicking the planet enters its separate close view",str(Framing.state(stage).get("mode",""))=="detail" and main.solar_follow==owner and is_equal_approx(stage.camera.fov,50.0))
		main._zoom_camera(stage,1.6); await settle()
		check(label+" pulling away from the planet restores co-frame",Framing.is_pair(stage))
		data=Framing.subjects(stage,owner,str(Framing.state(stage).key))
		if not await interaction_ready(): await finish(); return
		measurements.append({"kind":"moon click","owner":owner,"scale":stage.scale_id,"foreground":main.world.foreground,"available":main.object_pointer.available(),"picked":str(main.object_pointer.pick(stage.camera.unproject_position(data.moon.position)).get("label",""))})
		main.object_pointer.activate(stage.camera.unproject_position(data.moon.position)); await settle()
		check(label+" clicking the moon enters its separate close view",str(Framing.state(stage).get("mode",""))=="detail" and main._content_follow>=1 and main.object_pointer.pick(stage.camera.unproject_position(data.moon.position)).get("node")==data.moon)
		if owner==2: await capture("moon-separate-close")
		if owner==3:
			main._remember_view(); var close_saved: Dictionary=main._views.solar_system.duplicate(true)
			var close_fov: float=stage.camera.fov
			main._reset_camera(); main._views.solar_system=close_saved; main._restore_solar_view(); main._apply_saved_view(stage); await settle()
			check("tiny physical moon restores its optical close lens",main._content_follow>=1 and is_equal_approx(stage.camera.fov,close_fov) and close_fov<40.0 and main.WorldStore.valid_view(close_saved))
		main._zoom_camera(stage,1.6); await settle()
		check(label+" pulling away from the moon restores co-frame",Framing.is_pair(stage))
		check(label+" camera changes never alter a body, date or global rate",data.moon.transform.is_equal_approx(geometry) and data.planet.position==centre and main.solar_jd==date and is_equal_approx(main.solar_rate,1.0/24.0))
		main._remember_view(); var saved: Dictionary=main._views.solar_system.duplicate(true)
		var pose: Transform3D=stage.camera.transform
		var fov: float=stage.camera.fov
		main._reset_camera(); main._views.solar_system=saved; main._restore_solar_view(); main._apply_saved_view(stage); await settle()
		check(label+" saved co-frame restores subject, optics and slow clock",Framing.is_pair(stage) and main.WorldStore.valid_view(saved) and stage.camera.position.distance_to(pose.origin)<.0001 and stage.camera.basis.is_equal_approx(pose.basis) and is_equal_approx(stage.camera.fov,fov) and is_equal_approx(main.solar_rate,1.0/24.0))
		if owner==2:
			var invalid: Dictionary=saved.duplicate(true); invalid.satellite_framing.eye=[0,0,0]
			invalid.satellite_framing.aim=[0,0,0]
			check("save rejects a degenerate co-frame observer",not main.WorldStore.valid_view(invalid))
			var event: InputEventMouseMotion=InputEventMouseMotion.new()
			event.button_mask=MOUSE_BUTTON_MASK_LEFT; event.relative=Vector2(5,-2)
			event.position=get_viewport().get_visible_rect().size*.5
			var drag_pose: Transform3D=stage.camera.transform
			if not await interaction_ready(): await finish(); return
			main._unhandled_input(event); var moved: Transform3D=stage.camera.transform; await settle()
			check("pair drag rotates the observer without snapping back",not moved.is_equal_approx(drag_pose) and stage.camera.position.distance_to(moved.origin)<.0001 and data.moon.transform.is_equal_approx(geometry))
			main.frame_satellite_system(2,"",false); await settle()
			var before: Vector3=data.moon.position
			var before_time: float=main.world.simulation_time_s
			main.world.set_paused(false)
			var until: int=Time.get_ticks_msec()+3000
			while main.world.simulation_time_s-before_time<.6 and Time.get_ticks_msec()<until: await get_tree().process_frame
			main.world.set_paused(true); await settle()
			var elapsed: float=main.world.simulation_time_s-before_time
			check("co-frame follows actual orbital motion on the one clock",elapsed>0.0 and data.moon.position.distance_to(before)>0.0 and absf(main.solar_jd-date-elapsed/24.0)<.000001)
			check_pair(stage,data,"moving Earth-Moon")
		# True orbit overview is reached by retreating from the co-frame, and
		# restores its overview time preference without moving celestial bodies.
		main._zoom_camera(stage,2.0); await settle()
		check(label+" further retreat returns to schematic solar overview",not Framing.is_pair(stage) and int(stage.get_meta("solar_physical").owner)==-1 and main.solar_rate==10.0)
	# The same view/interaction exists in every actual dedicated satellite scene.
	for owner: int in range(3,8):
		main.follow_planet(owner); await settle()
		main.enter_spatial_choice({"planet":owner})
		if not await ready_stage(): await finish(); return
		await settle(); stage=main.coordinator.active_scene
		var data: Dictionary=Framing.subjects(stage,owner,str(Framing.state(stage).get("key","")))
		check("dedicated "+str(owner)+" arrives in the same pair view",Framing.is_pair(stage) and not data.is_empty())
		if data.is_empty(): await finish(); return
		check_pair(stage,data,"dedicated "+str(owner))
		if owner in [3,5]: await capture("local-"+str(owner)+"-pair")
		if not await interaction_ready(): await finish(); return
		measurements.append({"kind":"moon click","owner":owner,"scale":stage.scale_id,"foreground":main.world.foreground,"available":main.object_pointer.available(),"picked":str(main.object_pointer.pick(stage.camera.unproject_position(data.moon.position)).get("label",""))})
		main.object_pointer.activate(stage.camera.unproject_position(data.moon.position)); await settle()
		check("dedicated "+str(owner)+" actual moon click enters detail",str(Framing.state(stage).get("mode",""))=="detail" and main._content_follow>0)
		main._zoom_camera(stage,1.6); await settle()
		check("dedicated "+str(owner)+" pinch retreat returns to pair",Framing.is_pair(stage))
		if not await travel("solar_system"): await finish(); return
		stage=main.coordinator.active_scene
		check("dedicated "+str(owner)+" return restores solar co-frame and lens",Framing.is_pair(stage) and main.solar_follow==owner and is_equal_approx(stage.camera.fov,float(Framing.state(stage).fov)))
	prepare_auto(); main._reduced_motion=false; main.follow_planet(2)
	var frames: int=0; var finite_flight: bool=true
	while not main._solar_camera_motion.is_empty() and frames<20:
		await get_tree().process_frame; frames+=1
		finite_flight=finite_flight and main.coordinator.active_scene.camera.transform.origin.is_finite() and is_finite(main.coordinator.active_scene.camera.fov)
	check("actual co-frame flight finishes with continuous finite lens",frames>0 and main._solar_camera_motion.is_empty() and finite_flight and Framing.is_pair(main.coordinator.active_scene))
	await capture("earth-animated-arrival")
	main.follow_planet(2,true); frames=0
	while not main._solar_camera_motion.is_empty() and frames<20: await get_tree().process_frame; frames+=1
	check("actual separate close flight restores the normal lens",frames>0 and main._solar_camera_motion.is_empty() and is_equal_approx(main.coordinator.active_scene.camera.fov,50.0))
	main._reduced_motion=true
	main.follow_planet(2); main.focus_kepler(); await settle()
	check("Mercury orbit lesson releases the pair observer",not Framing.is_pair(main.coordinator.active_scene) and main._orbit_target.length()<.0001 and is_equal_approx(main.coordinator.active_scene.camera.fov,50.0))
	main.follow_planet(2); main.focus_planet_orbit(2); await settle()
	check("fixed seasonal orbit view releases the pair observer",not Framing.is_pair(main.coordinator.active_scene) and main._orbit_target.length()<.0001)
	main.set_solar_rate(1.0); main.follow_planet(2); await settle()
	check("explicit manual common rate survives co-frame selection",main.solar_rate==1.0 and main.solar_manual_setting)
	if not await travel("earth_moon"): await finish(); return
	await settle(); stage=main.coordinator.active_scene
	var lunar: Dictionary=Framing.subjects(stage,2)
	check("standalone Earth-Moon also offers co-frame",Framing.is_pair(stage))
	check_pair(stage,lunar,"standalone Earth-Moon")
	main._reset_camera(); await settle()
	check("Earth-Moon orbit overview contains both true-distance bodies",not stage.camera.is_position_behind(lunar.moon.position) and Rect2(Vector2.ZERO,Vector2(stage.viewport.size)).has_point(stage.camera.unproject_position(lunar.moon.position)) and not Framing.is_pair(stage) and lunar.moon.position.length()>50.0)
	await capture("earth-moon-orbit-overview")
	main.set_solar_rate(0.0); main.frame_satellite_system(2); await settle()
	check("explicit date hold stays held in co-frame",main.solar_rate==0.0)
	check("one World, no-save and original resource limits",main.world.get_instance_id()==identity and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func check_pair(stage: Node, data: Dictionary, label: String) -> void:
	var host: Vector2=stage.camera.unproject_position(data.planet.position)
	var moon: Vector2=stage.camera.unproject_position(data.moon.position)
	var factor: float=float(stage.viewport.size.y)/(2.0*tan(deg_to_rad(stage.camera.fov*.5)))
	var host_radius: float=float(data.radius)*factor/-stage.camera.to_local(data.planet.position).z
	var moon_radius: float=float(data.moon_radius)*factor/-stage.camera.to_local(data.moon.position).z
	var screen: Rect2=Rect2(Vector2.ZERO,Vector2(stage.viewport.size))
	check(label+" both physical discs are readable in frame",not stage.camera.is_position_behind(data.planet.position) and not stage.camera.is_position_behind(data.moon.position) and screen.has_point(host) and screen.has_point(moon) and host_radius>85.0 and moon_radius>24.0)
	check(label+" pair silhouettes do not overlap",host.distance_to(moon)>host_radius+moon_radius+8.0)
	var q: float=main.Orientation.MOON_RADIUS_KM/main.Ephemeris.RADII_KM[2] if int(data.owner)==2 else float(data.record.physical.mean_radius_km)/main.Ephemeris.RADII_KM[int(data.owner)]
	check(label+" physical size ratio remains unchanged",absf(float(data.moon_radius)/float(data.radius)-q)<.00001)
	measurements.append({"kind":"physical co-frame","label":label,"fov_deg":stage.camera.fov,"host_pixels_radius":host_radius,"moon_pixels_radius":moon_radius,"host_pixel":str(host),"moon_pixel":str(moon),"physical_radius_ratio":float(data.moon_radius)/float(data.radius),"separation_host_radii":data.planet.position.distance_to(data.moon.position)/float(data.radius),"observer_host_radii":stage.camera.position.distance_to(data.planet.position)/float(data.radius)})
