extends "res://tests/integration/satellite_coverage_suite.gd"
## Finite visible-source/Release checks of the accepted satellite exploration flow.
const SolarView = preload("res://scripts/experience/solar_satellite_view.gd")
const Span = preload("res://scripts/core/satellite_ephemeris_span.gd")
const FUTURE_JD: float = 2461596.5 # 2027-07-10, the user's formerly empty preview date.
var bridge_samples: int = 0
var maximum_projection_difference: float = 0.0

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--satellites275-output="): directory=argument.trim_prefix("--satellites275-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(105.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=false
	main.coordinator.metrics_recorded.connect(func(record: Dictionary) -> void:
		measurements.append({"kind":"transition outcome","record":record,"can_draw":DisplayServer.window_can_draw(),"foreground":main.world.foreground})
		print("SATELLITES275_TRANSITION ",JSON.stringify(record)))
	if is_instance_valid(main._audio): main._audio.volume_db=-80.0
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide()
	main.set_solar_date(FUTURE_JD); main.set_solar_rate(1.0/24.0)
	var identity: int = main.world.get_instance_id()
	var names: Dictionary = {3:"mars",4:"jupiter",5:"saturn",6:"uranus",7:"neptune"}
	var expected_counts: Array[int] = [2,4,8,5,3]
	var solar: Node = main.coordinator.active_scene
	main._reduced_motion=true; main._reset_camera(); await settle()
	var hidden: bool = true
	for system: Dictionary in solar.get_meta("solar_satellite_systems").values(): hidden=hidden and not system.root.visible
	check("global overview keeps small satellite context out of the frame",hidden)
	main._reduced_motion=false
	var original_target: Vector3 = solar.get_meta("camera_look_target")
	main.follow_planet(4)
	main.enter_spatial_choice({"planet":4})
	check("fast double-click captures the actual current view",Vector3(main._out_start.target).distance_to(original_target)<.0001)
	if not await ready_with_bridge(): await finish(); return
	check("fast double-click approaches a usable local system",main.coordinator.active_scene.scale_id=="jupiter_moons" and main.coordinator.active_scene.camera.position.length()<=10.01)
	main.navigate_to("solar_system")
	if not await ready_with_bridge(): await finish(); return
	solar=main.coordinator.active_scene
	for index: int in names:
		var host_name: String = str(names[index])
		main._reduced_motion=true; main.follow_planet(index); await settle()
		var context: Dictionary = solar.get_meta("solar_satellite_systems")[index]
		check("approach automatically reveals major moons "+host_name,context.root.visible and context.bodies.size()==expected_counts[index-3])
		var coherent: bool = true
		var visible_count: int = 0
		for body: Dictionary in context.bodies:
			var state: Dictionary = Model.sample(body.record,main.solar_jd)
			var local: Vector3 = Model.world_position(state,main.Ephemeris.RADII_KM[index])
			coherent=coherent and state.valid and body.node.position.distance_to(solar.get_meta("solar_bodies")[index].node.position+local*SolarView.radius(solar,index))<.0005
			var projected: Vector2 = solar.camera.unproject_position(body.node.position)
			if not solar.camera.is_position_behind(body.node.position) and Rect2(Vector2.ZERO,Vector2(solar.viewport.size)).has_point(projected): visible_count+=1
		check("same-date positions and radius scale in solar context "+host_name,coherent and visible_count>0)
		if host_name in ["jupiter","saturn"]: await capture(host_name+"-solar-context")
		if not await interaction_ready(): await finish(); return
		main._reduced_motion=false
		var kept_jd: float = main.solar_jd
		var kept_time: float = main.world.simulation_time_s
		for pinch: int in range(5):
			var gesture: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
			gesture.factor=2.0; gesture.position=get_viewport().get_visible_rect().size*.5
			main._unhandled_input(gesture)
			if main.coordinator.is_busy(): break
		check("pinch enters the selected planet system "+host_name,main.coordinator.is_busy())
		if not await ready_with_bridge(): await finish(); return
		var stage: Node = main.coordinator.active_scene
		check("entry preserves the shared date, clock and explicit rate "+host_name,stage.scale_id==Model.BRANCHES[host_name] and main.solar_jd==kept_jd and main.world.simulation_time_s==kept_time and main.world.get_instance_id()==identity and is_equal_approx(main.solar_rate,1.0/24.0))
		var data: Dictionary = stage.get_meta("natural_satellites")
		var mean_radii: bool = true
		var unknowns: bool = true
		for body: Dictionary in data.bodies:
			if float(body.radius_km)>0.0:
				mean_radii=mean_radii and body.node.mesh is SphereMesh and absf(body.node.mesh.radius*body.node.scale.x-float(body.radius_km)/float(data.radius_km))<.000001
			else: unknowns=unknowns and body.node.mesh is QuadMesh and body.point==body.node
		check("all known satellite solids have physical mean radii "+host_name,mean_radii)
		check("unknown sizes use identity points without invented spheres "+host_name,unknowns)
		var all_major: bool = true
		for body: Dictionary in data.bodies:
			if body.record.get("code")!=null and Span.covers(int(body.record.code)): all_major=all_major and body.node.visible and Model.sample(body.record,main.solar_jd).valid
		check("future-date major moons remain visible "+host_name,data.root.visible and all_major)
		check("entry retains a local near view "+host_name,stage.camera.position.length()<10.0)
		main.set_solar_date(Model.CACHE_END_JD+.02); main._update_exploration()
		check("crossing old December boundary keeps satellites present "+host_name,data.root.visible and int(data.available_count)>=expected_counts[index-3])
		main.set_solar_date(FUTURE_JD); main._update_exploration()
		main._reduced_motion=true; main.follow_content(2); await settle()
		var moon: Node3D = main.content_targets()[1].node
		var point: Vector2 = stage.camera.unproject_position(moon.position)
		check("same satellite can be picked in its future-date close view "+host_name,main.object_pointer.pick(point).get("node")==moon)
		if host_name in ["mars","neptune"]: await capture(host_name+"-future-close")
		if host_name=="saturn":
			var start_time: float = main.world.simulation_time_s
			var start_jd: float = main.solar_jd
			var prior: Vector3 = moon.position
			main.world.set_paused(false)
			var until: int = Time.get_ticks_msec()+3000
			while main.world.simulation_time_s-start_time<.6 and Time.get_ticks_msec()<until: await get_tree().process_frame
			main.world.set_paused(true); main._update_exploration()
			var elapsed: float = main.world.simulation_time_s-start_time
			check("actual future playback uses one World date for every moon",elapsed>0.0 and absf(main.solar_jd-start_jd-elapsed/24.0)<.000001 and moon.position.distance_to(prior)>0.0)
			measurements.append({"kind":"future shared playback","elapsed_world_s":elapsed,"rate_days_s":main.solar_rate,"date_delta_days":main.solar_jd-start_jd})
		main._remember_view()
		check("close-view save remains valid "+host_name,main.WorldStore.valid_view(main._views[stage.scale_id]))
		var offset: Vector3 = stage.camera.position-moon.position
		main.set_solar_date(FUTURE_JD+.05); main._update_exploration(); main._apply_saved_view(stage)
		check("saved view follows the same future-date moon "+host_name,main._content_follow==1 and (stage.camera.position-moon.position).distance_to(offset)<.0005)
		main._reduced_motion=false; main.navigate_to("solar_system")
		if not await ready_with_bridge(): await finish(); return
		solar=main.coordinator.active_scene
		var centre: Vector3 = solar.get_meta("solar_bodies")[index].node.position
		check("return keeps planet context at the current date "+host_name,main.world.current_scale_id=="solar_system" and main.solar_follow==index and main.world.get_instance_id()==identity and main._orbit_target.distance_to(centre)<.0005)
		main.set_solar_date(FUTURE_JD); main.set_solar_rate(1.0/24.0)
	check("matched bridge has equal actual projected planet position",bridge_samples>=10 and maximum_projection_difference<2.0)
	main._reduced_motion=true; main.follow_planet(5)
	var saturn: Dictionary = solar.get_meta("solar_satellite_systems")[5]
	var first: Dictionary = saturn.bodies[0]
	main._reset_camera()
	main.follow_planet(5)
	var targets: Array[Dictionary] = main.content_targets(false)
	for i: int in range(targets.size()):
		if str(targets[i].get("satellite_key",""))!=str(first.record.key): continue
		main.follow_content(i+1); await settle(); main._remember_view()
		check("solar satellite selection has a stable valid saved identity",main.WorldStore.valid_view(main._views.solar_system) and main._views.solar_system.satellite_key==str(first.record.key))
		main.enter_spatial_choice(targets[i]); break
	if await ready_stage():
		var stage: Node = main.coordinator.active_scene
		check("double-click moon keeps the same identity across scales",main.selected_spatial_choice().get("satellite_key","")==str(first.record.key))
		main.set_solar_date(FUTURE_JD+.06); main._update_exploration()
		main._reduced_motion=false; main.navigate_to("solar_system")
		if not await ready_with_bridge(): await finish(); return
		check("return from a moon restores its same current-date identity",main.selected_spatial_choice().get("satellite_key","")==str(first.record.key))
		main._reduced_motion=true; main.enter_spatial_choice(main.selected_spatial_choice())
		if not await ready_stage(): await finish(); return
		stage=main.coordinator.active_scene
		main._reset_camera(); Builder.focus_system(stage,false); main._orbit_target=Vector3.ZERO; await settle()
		var data: Dictionary = stage.get_meta("natural_satellites")
		var far: Array[Dictionary] = []
		for body: Dictionary in data.bodies:
			if body.node.position.length()>float(data.inner_extent)*2.0 and Model.has_state(body.record,main.solar_jd): far.append(body)
		var hidden_far: int = 0
		for body: Dictionary in far:
			if not body.point.visible: hidden_far+=1
		Builder.focus_system(stage,true); main._orbit_target=Vector3.ZERO; await settle()
		var shown_far: int = 0
		for body: Dictionary in far:
			if body.point.visible: shown_far+=1
		check("zoom scale reveals far small moons without a visibility switch",far.size()>0 and hidden_far==far.size() and shown_far>0)
		await capture("saturn-future-outer")
		main.set_solar_date(Model.END_JD); main.set_solar_rate(1.0/24.0)
		main._solar_origin_time=main.world.simulation_time_s-1.0; main._update_exploration()
		check("shared 2050 boundary pauses while keeping moons visible",main.solar_jd==Model.END_JD and main.solar_rate==0.0 and data.root.visible)
		main.set_solar_date(FUTURE_JD); main.set_solar_rate(1.0/24.0)
		main._reduced_motion=true
		var outward: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
		outward.factor=.5; outward.position=get_viewport().get_visible_rect().size*.5
		main._unhandled_input(outward)
		if await ready_stage(): check("zoom-out return restores the solar overview",main.solar_follow==-1 and main._content_follow==-1)
	check("single World and short native resource limits",main.world.get_instance_id()==identity and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	measurements.append({"kind":"matched visible camera projections","samples":bridge_samples,"maximum_difference_pixels":maximum_projection_difference})
	await finish()

func ready_with_bridge() -> bool:
	print("SATELLITES273_REQUEST_ACTIVATION")
	var target: String = str(main.coordinator.loading_status().target)
	var deadline: int = Time.get_ticks_msec()+16000
	var observed: bool = false
	while main.coordinator.is_busy() and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if main.coordinator.phase!=main.Coordinator.Phase.AUTHORING or main._satellite_bridge.is_empty(): continue
		observed=true
		var progress: float = float(main._progress_alpha)
		if progress<.001 or progress>.999: continue
		var entering: bool = bool(main._satellite_bridge.entering)
		var solar: Node = main._outgoing if entering else main._incoming
		var local: Node = main._incoming if entering else main._outgoing
		var centre: Vector3 = solar.get_meta("solar_bodies")[int(main._satellite_bridge.index)].node.position
		if not solar.camera.basis.is_equal_approx(local.camera.basis) or absf(solar.camera.fov-local.camera.fov)>.001: continue
		var a: Vector2 = solar.camera.unproject_position(centre)
		var b: Vector2 = local.camera.unproject_position(Vector3.ZERO)
		# Projection error in a nearly parallel/behind-camera direction is not a
		# visible handoff error. Compare the actual visible overlap of both frames.
		if solar.camera.is_position_behind(centre) or local.camera.is_position_behind(Vector3.ZERO): continue
		if not Rect2(Vector2.ZERO,Vector2(solar.viewport.size)).has_point(a) or not Rect2(Vector2.ZERO,Vector2(local.viewport.size)).has_point(b): continue
		var error: float = a.distance_to(b)
		maximum_projection_difference=maxf(maximum_projection_difference,error); bridge_samples+=1
	await settle()
	var arrived: bool = not main.coordinator.is_busy() and main.world.current_scale_id==target
	check("visible matched flight reaches interaction",observed and arrived)
	return observed and arrived

func interaction_ready() -> bool:
	if main.world.foreground and DisplayServer.window_can_draw(): return true
	print("SATELLITES273_REQUEST_ACTIVATION")
	get_window().show(); get_window().grab_focus.call_deferred()
	var until: int = Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<until:
		await get_tree().process_frame
		if main.world.foreground and DisplayServer.window_can_draw(): return true
	check("actual window stays drawable before satellite input",false)
	return false
