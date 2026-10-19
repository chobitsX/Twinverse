extends "res://tests/integration/solar_drag_visibility_suite.gd"
## Physical near systems, angular far context, one clock and actual selection.
const Physical = preload("res://scripts/experience/solar_physical_context.gd")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solar278-output="): directory=argument.trim_prefix("--solar278-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(85.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80.0
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	main.set_solar_date(USER_JD)
	var stage: Node = main.coordinator.active_scene
	var identity: int = main.world.get_instance_id()
	var time: float = main.world.simulation_time_s
	for index: int in range(8):
		prepare_auto(); main.follow_planet(index,true); await settle()
		if not await interaction_ready(): await finish(); return
		var label: String = main.Ephemeris.NAMES[index]
		var data: Dictionary = stage.get_meta("solar_physical")
		var host: MeshInstance3D = stage.get_meta("solar_bodies")[index].node
		var km_unit: float = float(host.mesh.radius)/main.Ephemeris.RADII_KM[index]
		check(label+" establishes a physical host frame",int(data.owner)==index and bool(stage.get_meta("solar_physical_active")) and is_equal_approx(float(data.km_to_world),km_unit))
		check(label+" near keeps all ten bodies without a mask",sun_visible(stage) and overview_visible(stage) and stage.get_meta("solar_moon").node.visible)
		check(label+" one global slow rate",is_equal_approx(main.solar_rate,1.0/24.0))
		var coherent: bool = true
		for other: int in range(10):
			var node: MeshInstance3D = stage.get_meta("solar_bodies")[other].node if other<8 else stage.world_root.get_node("Sun_AuthoredPhotosphere") if other==8 else stage.get_meta("solar_moon").node
			var true_sight: Vector3 = Vector3(data.physical_positions[other])-stage.camera.position
			var rendered_sight: Vector3 = node.position-stage.camera.position
			var radius: float = float(node.get_meta("physical_radius_km"))*km_unit
			var rendered_radius: float = float(node.mesh.radius)*node.scale.x
			coherent=coherent and true_sight.normalized().distance_to(rendered_sight.normalized())<.0001 and absf(radius/true_sight.length()-rendered_radius/rendered_sight.length())<.00001
		check(label+" distant body direction and angular size are preserved",coherent)
		if index>=3:
			var context: Dictionary = stage.get_meta("solar_satellite_systems")[index]
			var positions: bool = context.root.visible; var sizes: bool = true
			for body: Dictionary in context.bodies:
				var state: Dictionary = Model.sample(body.record,main.solar_jd)
				positions=positions and body.node.position.distance_to(host.position+Model.world_position(state,main.Ephemeris.RADII_KM[index])*float(host.mesh.radius))<.0001
				var radius: float = float(body.node.mesh.radius)*body.node.scale.x
				sizes=sizes and absf(radius-float(body.record.physical.mean_radius_km)*km_unit)<.00001
			check(label+" every major moon shares the host distance scale",positions)
			check(label+" every major moon has its un-enlarged mean radius",sizes)
		elif index==2:
			var moon: MeshInstance3D = stage.get_meta("solar_moon").node
			check("Moon physical distance and mean radius share Earth units",moon.position.distance_to(host.position+Orientation.moon_position_km(main.solar_jd)*km_unit)<.0001 and absf(moon.mesh.radius*moon.scale.x-Orientation.MOON_RADIUS_KM*km_unit)<.00001)
		# Use a real camera orbit around the same selected planet.
		var before: Transform3D = stage.camera.transform
		drag(Vector2(40,-8)); await settle()
		check(label+" actual drag retains the frame and shared date",not stage.camera.transform.is_equal_approx(before) and int(data.owner)==index and main.solar_jd==USER_JD and main.world.simulation_time_s==time)
		# Frame the actual Sun, then query its real mesh/identity point registry.
		var sun: MeshInstance3D = stage.world_root.get_node("Sun_AuthoredPhotosphere")
		var direction: Vector3 = (sun.position-host.position).normalized()
		stage.set_pose(host.position+direction*float(host.mesh.radius)*8.0,host.position+direction*float(host.mesh.radius)*9.0)
		var pixel: Vector2 = stage.camera.unproject_position(sun.position)
		var picked: Dictionary = main.object_pointer.pick(pixel)
		measurements.append({"kind":"far Sun pick","host":index,"available":main.object_pointer.available(),"foreground":main.world.foreground,"drawable":DisplayServer.window_can_draw(),"pixel":str(pixel),"picked":str(picked.get("label","")),"radius":sun.mesh.radius*sun.scale.x,"sun_position":str(sun.position),"camera_position":str(stage.camera.position)})
		if picked.is_empty():
			var ray: Vector3 = stage.camera.project_ray_origin(pixel)
			var end: Vector3 = ray+stage.camera.project_ray_normal(pixel)*stage.camera.far
			var hits: Array[Dictionary] = []
			for surface: Dictionary in main.object_pointer.surfaces:
				var hit: Variant = main.object_pointer.surface_hit(surface,ray,end)
				if hit is Vector3: hits.append({"name":str(surface.node.name),"choice":str(surface.choice.get("label","")),"distance":ray.distance_to(hit),"opaque":surface.opaque})
			print("SCALE278_PICK_DIAG ",JSON.stringify({"host":index,"hits":hits,"available":main.object_pointer.available()}))
		check(label+" far Sun identity point remains selectable",picked.get("label","")=="太阳")
		main.follow_planet(index,true); await settle()
		if index in [2,4,5]: await capture(["mercury","venus","earth","mars","jupiter","saturn","uranus","neptune"][index]+"-physical-context")
	main._reset_camera(); await settle()
	check("reset restores schematic overview and original rate",int(stage.get_meta("solar_physical").owner)==-1 and main.solar_rate==10.0 and main._solar_close_playback.is_empty())
	var planet: MeshInstance3D = stage.get_meta("solar_bodies")[4].node
	main._orbit_target=planet.position
	stage.set_pose(planet.position+Vector3(.6,.4,1).normalized()*float(planet.mesh.radius)*30.0,planet.position)
	if not await interaction_ready(): await finish(); return
	var zoom: InputEventMagnifyGesture = InputEventMagnifyGesture.new(); zoom.factor=2.0; zoom.position=get_viewport().get_visible_rect().size*.5
	main._unhandled_input(zoom); await settle()
	check("unselected natural approach establishes physical frame",int(stage.get_meta("solar_physical").owner)==4 and stage.get_meta("solar_satellite_systems")[4].root.visible and main.solar_follow<0)
	main._remember_view(); var saved: Dictionary = main._views.solar_system.duplicate(true)
	check("physical frame observer validates",main.WorldStore.valid_view(saved) and int(saved.solar_physical_context)==4)
	var kept: Transform3D = stage.camera.transform
	main._reset_camera(); main._solar_close_playback=saved.astronomy.get("close_playback",{}).duplicate(); main._views.solar_system=saved
	main._restore_solar_view(); main._apply_saved_view(stage); main._update_exploration()
	check("natural frame and camera restore without persistence writes",int(stage.get_meta("solar_physical").owner)==4 and kept.is_equal_approx(stage.camera.transform) and is_equal_approx(main.solar_rate,1.0/24.0))
	main.follow_content(2); await settle()
	check("select Moon switches to physical Earth frame",int(stage.get_meta("solar_physical").owner)==2 and main._content_follow==1)
	main._remember_view(); saved=main._views.solar_system.duplicate(true); kept=stage.camera.transform
	main._reset_camera(); main._solar_close_playback=saved.astronomy.get("close_playback",{}).duplicate(); main._content_follow=1;main._views.solar_system=saved
	main._restore_solar_view(); main._apply_saved_view(stage)
	measurements.append({"kind":"Moon camera restore","saved":str(kept),"actual":str(stage.camera.transform),"position_delta":kept.origin.distance_to(stage.camera.position),"view_valid":main.WorldStore.valid_view(saved)})
	check("physical Moon close camera restores",kept.is_equal_approx(stage.camera.transform) and main.WorldStore.valid_view(saved))
	main.follow_content(1); await settle()
	check("select Sun switches to physical Sun frame",int(stage.get_meta("solar_physical").owner)==8)
	main.follow_planet(5); main.set_solar_distance(true); await settle()
	check("AU overview preference cannot enlarge near satellite solids",Solar.enlargement(stage)==1.0 and int(stage.get_meta("solar_physical").owner)==5 and is_equal_approx(Solar.radius(stage,5),.93))
	main.set_solar_distance(false); main._reset_camera(); await settle()
	check("one World and short resource limits",main.world.get_instance_id()==identity and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	main.navigate_to("earth_moon")
	if not await ready_stage(): await finish(); return
	var lunar: Dictionary = main.coordinator.active_scene.get_meta("lunar")
	check("standalone Earth-Moon default uses common physical units",lunar.moon.position.distance_to(Orientation.moon_position_km(main.solar_jd)/main.Ephemeris.RADII_KM[2])<.00001 and is_equal_approx(lunar.moon.mesh.radius,Orientation.MOON_RADIUS_KM/main.Ephemeris.RADII_KM[2]) and is_equal_approx(lunar.earth.mesh.radius,1.0))
	main.follow_content(2); await settle()
	var point: Vector2 = main.coordinator.active_scene.camera.unproject_position(lunar.moon.position)
	check("physical standalone Moon remains selectable",main.object_pointer.pick(point).get("node")==lunar.moon)
	main.focus_lunar(true); await settle()
	check("lunar near phase view keeps physical distance",main.coordinator.active_scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and lunar.moon.position.length()>50.0 and main._content_follow==1)
	await capture("moon-physical-near")
	check("Earth-Moon navigation retains the one date and World",main.solar_jd==USER_JD and main.world.get_instance_id()==identity and main.world.simulation_time_s==time)
	await finish()

func interaction_ready() -> bool:
	if main.world.foreground and DisplayServer.window_can_draw(): return true
	print("SATELLITES273_REQUEST_ACTIVATION")
	get_window().show(); get_window().grab_focus.call_deferred()
	var deadline: int = Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if main.world.foreground and DisplayServer.window_can_draw(): return true
	check("actual window stays available for interaction",false)
	return false
