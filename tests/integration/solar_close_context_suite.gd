extends "res://tests/integration/solar_drag_visibility_suite.gd"
## Planet-focused dragging must keep the same solar world visible and pickable.

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solar277-output="): directory=argument.trim_prefix("--solar277-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(65.0).timeout.connect(func() -> void: get_tree().quit(2))
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
		prepare_auto(); main.follow_planet(index); await settle()
		var label: String = main.Ephemeris.NAMES[index]
		check(label+" selection retains Sun and all eight planets",sun_visible(stage) and overview_visible(stage))
		check(label+" close observation retains one global slow rate",is_equal_approx(main.solar_rate,1.0/24.0) and float(main._solar_close_playback.get("rate",0.0))==10.0)
		var planet: MeshInstance3D = stage.get_meta("solar_bodies")[index].node
		var radius: float = Solar.radius(stage,index)
		var radial: Vector3 = planet.position.normalized()
		# Orbit the selected body, with the actual Sun to one side of its disk.
		# This is the existing camera/input path, not a duplicate backdrop camera.
		var distance: float = float({0:8.0,1:8.0,2:8.0,3:10.0,4:17.0,5:12.0,6:20.0,7:18.0}[index])
		stage.set_pose(planet.position+(radial.rotated(Vector3.UP,.5)+Vector3.UP*.08).normalized()*radius*distance,planet.position)
		main._orbit_target=planet.position
		var before: Transform3D = stage.camera.transform
		drag(Vector2(30.0,-10.0)); await settle()
		check(label+" actual drag changes the close camera without leaving solar space",not stage.camera.transform.is_equal_approx(before) and main.solar_follow==index and main.world.current_scale_id=="solar_system")
		var sun_point: Vector2 = stage.camera.unproject_position(Vector3.ZERO)
		check(label+" orbit can frame the actual Sun",not stage.camera.is_position_behind(Vector3.ZERO) and Rect2(Vector2.ZERO,Vector2(stage.viewport.size)).has_point(sun_point))
		check(label+" background Sun remains pickable",main.object_pointer.pick(sun_point).get("label","")=="太阳")
		await sun_pixels(stage,label+"-close-drag")
		var unchanged: bool = true
		for other: int in range(8):
			var body: Dictionary = stage.get_meta("solar_bodies")[other]
			unchanged=unchanged and body.node.position.is_equal_approx(main.Ephemeris.display_position(other,main.solar_jd,false)) and is_equal_approx(body.node.scale.x,main.Ephemeris.body_display_scale(other,false))
		check(label+" background keeps original ephemeris positions and display sizes",unchanged)
		var peers: Array[int] = pickable_peers(stage,index)
		# A body can be outside this particular Sun-facing camera. Continue a
		# real orbit gesture to check discovery, rather than require all at once.
		for attempt: int in range(8):
			if not peers.is_empty(): break
			drag(Vector2(160.0,0.0)); await settle()
			peers=pickable_peers(stage,index)
		check(label+" orbit can pick another planet",not peers.is_empty())
		check(label+" paused drag preserves the date and World time",main.solar_jd==USER_JD and main.world.simulation_time_s==time and main.world.paused)
		if index>=3:
			check(label+" near view still reveals its major moons",stage.get_meta("solar_satellite_systems")[index].root.visible)
		measurements.append({"kind":"close context","planet":index,"sun_pixel":str(sun_point),"pickable_peer_indices":peers,"jd":main.solar_jd,"rate":main.solar_rate,"camera_position":str(stage.camera.position)})
		if index in [3,5,7]: await capture(["mercury","venus","earth","mars","jupiter","saturn","uranus","neptune"][index]+"-close-drag")
	main.set_solar_distance(true); await settle()
	check("AU-distance near view also retains Sun and all planets",sun_visible(stage) and overview_visible(stage))
	var extras_hidden: bool = not stage.world_root.get_node("SolarCorona_Illustration").visible
	for body: Dictionary in stage.get_meta("solar_bodies"):
		for extra: MeshInstance3D in body.extras: extras_hidden=extras_hidden and not extra.visible
	check("AU-distance view preserves its existing auxiliary masks",extras_hidden)
	main.set_solar_distance(false); main._reset_camera(); await settle()
	check("reset restores the overview rate and clears the selected planet",main.solar_follow<0 and main._content_follow<0 and main.solar_rate==10.0 and main._solar_close_playback.is_empty() and sun_visible(stage) and overview_visible(stage))
	check("single World no user save and short resource limits",main.world.get_instance_id()==identity and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func pickable_peers(stage: Node, index: int) -> Array[int]:
	var result: Array[int] = []
	for other: int in range(8):
		var node: MeshInstance3D = stage.get_meta("solar_bodies")[other].node
		if other==index or stage.camera.is_position_behind(node.position): continue
		var point: Vector2 = stage.camera.unproject_position(node.position)
		if Rect2(Vector2.ZERO,Vector2(stage.viewport.size)).has_point(point) and int(main.object_pointer.pick(point).get("planet",-1))==other: result.append(other)
	return result
