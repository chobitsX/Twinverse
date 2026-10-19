extends "res://tests/integration/solar_entry_context_suite.gd"
## Bounded, real camera/mesh/UI checks for the close observation interaction.
const Framing = preload("res://scripts/experience/satellite_framing.gd")
const Closeup = preload("res://scripts/experience/solar_closeup.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--closeup281-output="): directory=argument.trim_prefix("--closeup281-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(110.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80.0
	if not await ready_stage() or not await interaction_ready(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	main.set_solar_date(USER_JD)
	var stage: Node=main.coordinator.active_scene
	var identity: int=main.world.get_instance_id()
	var date: float=main.solar_jd
	for owner: int in range(8):
		prepare_auto(); main.follow_planet(owner); await settle()
		if not await interaction_ready(): await finish(); return
		var body: MeshInstance3D=Closeup.subject(main)
		var label: String=main.Ephemeris.NAMES[owner]
		check(label+" defaults to the selected physical close subject",body==stage.get_meta("solar_bodies")[owner].node and not Framing.is_pair(stage) and int(stage.get_meta("solar_physical").owner)==owner)
		var before: Vector3=screen_disc(stage,body)
		var geometry: Transform3D=body.transform
		var camera: Transform3D=stage.camera.transform
		for motion: Vector2 in [Vector2(140,-50),Vector2(-260,100),Vector2(95,-75)]: left_drag(motion)
		await settle()
		var after: Vector3=screen_disc(stage,body)
		check(label+" multi-axis dragging keeps size and screen position",Vector2(before.x,before.y).distance_to(Vector2(after.x,after.y))<1.0 and absf(before.z-after.z)<1.0)
		check(label+" drag changes only the observer",not stage.camera.transform.is_equal_approx(camera) and body.transform.is_equal_approx(geometry) and main.solar_jd==date and is_equal_approx(main.solar_rate,1.0/24.0))
		check(label+" close subject remains substantial",after.z/float(stage.viewport.size.y)>(.18 if owner==5 else .38))
		measurements.append({"kind":"stable close drag","owner":owner,"before":str(before),"after":str(after)})
		if owner in [2,4,5]: await capture("close-"+str(owner)+"-drag")
		if owner>=2:
			main.frame_satellite_system(owner,"",false); await settle()
			check(label+" explicit co-frame remains available",Framing.is_pair(stage))
			left_drag(Vector2(18,-6)); await settle()
			check(label+" co-frame drag hands over to subject orbit",not Framing.is_pair(stage) and Closeup.subject(main)==body)
	# UI bearings and actual independent optical output, without enlarging bodies.
	for owner: int in [2,4,5]:
		main.follow_planet(owner); await settle()
		var compass: Node=main.hud.get_node("SolarContextCompass")
		var choices: Dictionary=compass.collect(stage)
		var key: int=9 if owner==2 else -1
		if owner!=2:
			for candidate: int in choices:
				if choices[candidate].has("satellite_key"): key=candidate; break
		check(str(owner)+" provides a real moon bearing",key>=0 and choices.has(key))
		if key<0: continue
		var item: Dictionary=choices[key]
		var transform_before: Transform3D=item.node.transform
		main.optical_inspector.bearing_enter(item,Vector2(820,210))
		await settle()
		check(str(owner)+" inspector renders the same mesh and pose",main.optical_inspector.visible and main.optical_inspector.proxies[0].mesh==item.node.mesh and main.optical_inspector.proxies[0].basis.orthonormalized().is_equal_approx(item.node.basis.orthonormalized()) and main.optical_inspector.sampled_jd==main.solar_jd)
		check(str(owner)+" optical card stays compact and within the window",main.optical_inspector.size.y<430.0 and Rect2(Vector2.ZERO,Vector2(main.ui_view_size())).encloses(main.optical_inspector.get_rect()))
		await RenderingServer.frame_post_draw
		var optical: Image=main.optical_inspector.lens.get_texture().get_image()
		var lit: int=0
		for y: int in range(8,optical.get_height()-8,4):
			for x: int in range(8,optical.get_width()-8,4):
				if optical.get_pixel(x,y).get_luminance()>.08: lit+=1
		check(str(owner)+" optical image contains a readable surface",lit>35)
		check(str(owner)+" optical preview leaves actual scale, orbit and date untouched",item.node.transform.is_equal_approx(transform_before) and main.solar_jd==date)
		await capture("optical-"+str(owner))
		var renders: int=main.optical_inspector.render_count
		await settle()
		check(str(owner)+" paused unchanged optics do not render repeatedly",main.optical_inspector.render_count==renders)
		main.optical_inspector.fly_button.pressed.emit(); await settle()
		check(str(owner)+" fly button selects the actual moon",Closeup.subject(main)==item.node and not main.optical_inspector.visible)
		left_drag(Vector2(60,-25)); await settle()
		check(str(owner)+" moon close drag stays readable",screen_disc(stage,item.node).z/float(stage.viewport.size.y)>.3)
	main.follow_planet(2); await settle()
	main._reduced_motion=false
	var destination: MeshInstance3D=stage.get_meta("solar_bodies")[4].node
	var direction_before: Vector3=stage.camera.to_local(destination.position).normalized()
	var angular_before: float=float(destination.mesh.radius)*destination.scale.x/stage.camera.position.distance_to(destination.position)
	main.follow_planet(4)
	var direction_after: Vector3=stage.camera.to_local(destination.position).normalized()
	var angular_after: float=float(destination.mesh.radius)*destination.scale.x/stage.camera.position.distance_to(destination.position)
	check("cross-planet frame rebase preserves initial sky direction and angular size",direction_before.dot(direction_after)>.9999 and absf(angular_after/angular_before-1.0)<.02)
	main._zoom_camera(stage,.9)
	check("pinch during cross-planet flight retargets without cancelling",main._solar_camera_motion.has("rotation_start"))
	await flight("Earth to Jupiter")
	check("cross-planet arrival is the real Jupiter close frame",int(stage.get_meta("solar_physical").owner)==4 and screen_disc(stage,destination).z/float(stage.viewport.size.y)>.38 and not bool(stage.get_meta("solar_transfer_projection",false)))
	main.follow_content(1); await flight("Jupiter to Sun")
	check("Sun fly-in reaches the actual luminous photosphere",main._content_follow==0 and int(stage.get_meta("solar_physical").owner)==8 and screen_disc(stage,Closeup.subject(main)).z/float(stage.viewport.size.y)>.3)
	await capture("sun-arrival")
	main.follow_planet(2); await flight("Sun to Earth")
	main.frame_satellite_system(2); await flight("Earth to pair")
	left_drag(Vector2(12,-4)); await flight("pair drag handoff")
	check("animated pair drag ends in stable Earth detail",not Framing.is_pair(stage) and main.solar_follow==2)
	main._reduced_motion=true
	main._remember_view(); var saved: Dictionary=main._views.solar_system.duplicate(true)
	var pose: Transform3D=stage.camera.transform
	main._reset_camera(); main._views.solar_system=saved; main._restore_solar_view(); main._apply_saved_view(stage); await settle()
	check("saved orbit restores exact position, roll and lens",stage.camera.transform.is_equal_approx(pose) and main.WorldStore.valid_view(saved))
	var start_date: float=main.solar_jd
	var start_time: float=main.world.simulation_time_s
	main.world.set_paused(false)
	var until: int=Time.get_ticks_msec()+2500
	while main.world.simulation_time_s-start_time<.6 and Time.get_ticks_msec()<until: await get_tree().process_frame
	main.world.set_paused(true); await settle()
	check("all close views retain the single one-hour-per-second clock",main.world.simulation_time_s>start_time and absf(main.solar_jd-start_date-(main.world.simulation_time_s-start_time)/24.0)<.000001)
	date=main.solar_jd
	main.set_solar_rate(1.0); main.follow_planet(5); await settle()
	check("manual speed and paused date survive target changes",main.solar_rate==1.0 and main.solar_jd==date and main.solar_manual_setting)
	# Real scene ownership and returns, using all five non-Earth satellite hosts.
	for owner: int in range(3,8):
		main.follow_planet(owner); await settle(); main.enter_spatial_choice({"planet":owner})
		if not await ready_stage(): await finish(); return
		await settle(); stage=main.coordinator.active_scene
		left_drag(Vector2(24,-8)); await settle()
		var body: MeshInstance3D=Closeup.subject(main)
		check("dedicated "+str(owner)+" drag transfers pair to a real close body",not Framing.is_pair(stage) and is_instance_valid(body))
		if is_instance_valid(body):
			var before: Vector3=screen_disc(stage,body)
			left_drag(Vector2(90,-40)); await settle()
			check("dedicated "+str(owner)+" subject remains stable",before.distance_to(screen_disc(stage,body))<1.0)
		if owner==5: await capture("local-saturn-drag")
		if not await travel("solar_system"): await finish(); return
		stage=main.coordinator.active_scene
		check("dedicated "+str(owner)+" return restores the solar subject",main.solar_follow==owner and not Framing.is_pair(stage))
	main.follow_planet(2); main.enter_spatial_choice({"planet":2})
	if not await ready_stage(): await finish(); return
	check("Earth close can still enter the geographic scene",main.world.current_scale_id=="earth")
	if not await travel("solar_system"): await finish(); return
	main.optical_inspector.dismiss()
	check("inactive magnifier stops rendering",main.optical_inspector.lens.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	check("one World, no-save and original resource limits",main.world.get_instance_id()==identity and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func screen_disc(stage: Node, body: MeshInstance3D) -> Vector3:
	var pixel: Vector2=stage.camera.unproject_position(body.position)
	var radius: float=float(body.mesh.radius)*body.global_basis.get_scale().x
	var diameter: float=radius*float(stage.viewport.size.y)/(-stage.camera.to_local(body.position).z*tan(deg_to_rad(stage.camera.fov*.5)))
	return Vector3(pixel.x,pixel.y,diameter)

func left_drag(relative: Vector2) -> void:
	var event: InputEventMouseMotion=InputEventMouseMotion.new()
	event.button_mask=MOUSE_BUTTON_MASK_LEFT; event.relative=relative
	event.position=get_viewport().get_visible_rect().size*.5
	main._unhandled_input(event)

func flight(label: String) -> void:
	var count: int=0
	var finite: bool=true
	while not main._solar_camera_motion.is_empty() and count<24:
		await get_tree().process_frame; count+=1
		var stage: Node=main.coordinator.active_scene
		finite=finite and stage.camera.position.is_finite() and stage.camera.basis.is_finite() and is_finite(stage.camera.fov)
	check(label+" animated camera completes with finite pose",count>0 and main._solar_camera_motion.is_empty() and finite)
	await settle()
