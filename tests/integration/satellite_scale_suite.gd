extends "res://tests/integration/satellite_coverage_suite.gd"
## Short physical-unit checks in each actual standalone satellite stage.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--satellites278-output="): directory=argument.trim_prefix("--satellites278-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(80.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate();main.world.set_paused(true);add_child(main)
	main._measurement_screen=get_window().current_screen;main._reduced_motion=true
	if is_instance_valid(main._audio):main._audio.volume_db=-80.0
	if not await ready_stage():await finish();return
	main.world_guide.hide();main.explorer_panel.hide();main.info_panel.hide()
	main.set_solar_date(main.Ephemeris.DEFAULT_JD);main.set_solar_rate(1.0/24.0)
	var identity: int = main.world.get_instance_id()
	for index: int in range(3,8):
		var host: String = Model.HOSTS[index]
		main.follow_planet(index);await settle()
		if not await interaction_ready():await finish();return
		main.enter_spatial_choice({"planet":index})
		if not await ready_stage():await finish();return
		var stage: Node = main.coordinator.active_scene
		if stage.scale_id!=Model.BRANCHES[host] or not stage.has_meta("natural_satellites"):
			check(host+" reached its actual satellite stage",false);await finish();return
		check(host+" reached its actual satellite stage",true)
		var data: Dictionary = stage.get_meta("natural_satellites")
		var radii: bool = true;var unknown: bool = true;var positions: bool = true
		for body: Dictionary in data.bodies:
			var state: Dictionary = Model.sample(body.record,main.solar_jd)
			positions=positions and state.valid and body.node.position.distance_to(Model.world_position(state,float(data.radius_km)))<.0005
			if float(body.radius_km)>0.0:
				radii=radii and body.node.mesh is SphereMesh and absf(body.node.mesh.radius*body.node.scale.x-float(body.radius_km)/float(data.radius_km))<.000001
			else:unknown=unknown and body.node.mesh is QuadMesh and body.point==body.node
		check(host+" all cached positions agree with the one date",positions)
		check(host+" all known mean radii are physical without x5",radii and is_equal_approx(data.planet.mesh.radius,1.0))
		check(host+" unknown sizes only have identity points",unknown)
		check(host+" one World and rate remain unchanged",main.world.get_instance_id()==identity and main.solar_jd==main.Ephemeris.DEFAULT_JD and is_equal_approx(main.solar_rate,1.0/24.0))
		main.follow_content(2);await settle()
		if not await interaction_ready():await finish();return
		var moon: Node3D = main.content_targets(false)[1].node
		var pixel: Vector2 = stage.camera.unproject_position(moon.position)
		check(host+" actual physical Moon can be picked in close view",main.object_pointer.pick(pixel).get("node")==moon)
		main._remember_view()
		check(host+" observer with physical-unit version validates",main.WorldStore.valid_view(main._views[stage.scale_id]) and int(main._views[stage.scale_id].local_geometry_version)==1)
		if index in [3,4,7]:await capture(host+"-physical-moon")
		if not await interaction_ready():await finish();return
		main.navigate_to("solar_system")
		if not await ready_stage():await finish();return
		check(host+" return keeps the date in the real solar stage",main.world.current_scale_id=="solar_system" and main.solar_jd==main.Ephemeris.DEFAULT_JD)
	check("no persistence writes or expanded runtime limits",not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()
func interaction_ready() -> bool:
	if main.world.foreground and DisplayServer.window_can_draw():return true
	print("SATELLITES273_REQUEST_ACTIVATION")
	get_window().show();get_window().grab_focus.call_deferred()
	var until: int = Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<until:
		await get_tree().process_frame
		if main.world.foreground and DisplayServer.window_can_draw():return true
	check("actual window drawable before satellite operation",false)
	return false
