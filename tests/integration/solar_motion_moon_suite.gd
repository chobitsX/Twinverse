extends "res://tests/integration/spatial_input_suite.gd"
## Bounded scientific/reference, common-date and real geometry checks.
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
var reference_path: String = ""
var measurements: Array[Dictionary] = []

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solar261-output="): directory=argument.trim_prefix("--solar261-output=")
		if argument.begins_with("--solar261-reference="): reference_path=argument.trim_prefix("--solar261-reference=")
	if not directory.is_absolute_path() or not reference_path.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(100.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80
	if not await ready_stage(): await finish(); return
	original_id=main.world.get_instance_id()
	main.explorer_panel.hide(); main.info_panel.hide()
	science_reference()
	await overview_and_moon()
	await common_time()
	await filtered_and_sharp()
	await moon_entry_and_return()
	check("same World throughout scientific observation",main.world.get_instance_id()==original_id and not main._persistence_enabled)
	check("short diagnostic retains five FPS and two workers",Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func pose_error(actual: Basis, columns: Array) -> float:
	var error: float=0.0
	for axis: int in range(3):
		var expected: Vector3=Vector3(columns[axis][0],columns[axis][1],columns[axis][2])
		error=maxf(error,rad_to_deg(actual[axis].angle_to(expected)))
	return error

func science_reference() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	for row: Dictionary in data.periods:
		var index: int=int(row.index)
		var days: float=Orientation.rotation_days(index) if index<8 else 360.0/float(Orientation.SUN_ROTATION.polynomials[2][1]) if index==8 else 360.0/float(Orientation.Lunar.Data.ROTATION.polynomials[2][1])
		check("NAIF independent signed rotation period "+str(row.name if row.has("name") else row.body),absf(days-float(row.model_rotation_days))<1e-10)
		if index<8: check("JPL nominal orbital period "+Ephemeris.NAMES[index],absf(Ephemeris.PERIOD_YEARS[index]-float(row.jpl_orbit_years))<1e-12)
	for row: Dictionary in data.poses:
		var index: int=int(row.index)
		var pose: Basis=Orientation.body_basis(index,row.jd) if index<8 else Orientation.sun_basis(row.jd) if index==8 else Orientation.moon_basis(row.jd)
		var error: float=pose_error(pose,row.columns)
		check("SPICE reference pose %s at %s" % [row.name,str(row.jd)],error<.0002 and absf(pose.determinant()-1.0)<.00001)
		measurements.append({"kind":"SPICE pose","body":row.name,"jd":row.jd,"max_axis_error_deg":error})
	for row: Dictionary in data.moon_positions:
		var p: Vector3=Orientation.moon_position_km(row.jd)
		var error: float=p.distance_to(Vector3(row.erfa_world_km[0],row.erfa_world_km[1],row.erfa_world_km[2]))
		check("independent ERFA lunar position at "+str(row.jd),error<.06)
		measurements.append({"kind":"ERFA moon","jd":row.jd,"implementation_error_km":error})
	check("Jupiter and Saturn physically spin faster than Earth",absf(Orientation.rotation_days(4))<Orientation.rotation_days(5) and Orientation.rotation_days(5)<Orientation.rotation_days(2))
	check("Venus retrograde and Uranus sideways remain",Orientation.rotation_days(1)<0 and Orientation.rotation_days(6)<0 and Orientation.obliquity_deg(6,Ephemeris.DEFAULT_JD)>95.0)
	check("lunar sidereal and phase periods are not confused",absf(float(data.periods[9].model_rotation_days)-27.3217)<.0001 and 29.53-absf(float(data.periods[9].model_rotation_days))>2.0)

func overview_and_moon() -> void:
	main.set_solar_rate(0); main.set_solar_date(Ephemeris.DEFAULT_JD); main._reset_camera(); await settle()
	var stage: Node=main.coordinator.active_scene
	var bodies: Array=stage.get_meta("solar_bodies")
	var moon: Dictionary=stage.get_meta("solar_moon")
	check("solar overview contains Sun eight planets and a selectable Moon",bodies.size()==8 and moon.node.visible and main.content_targets().size()==2)
	check("Moon is not parented to the rotating Earth mesh",moon.node.get_parent()==stage.world_root and not bodies[2].node.is_ancestor_of(moon.node))
	check("overview keeps actual lunar Earth radius ratio",absf(float(moon.radius)/float(bodies[2].node.mesh.radius)-Orientation.MOON_RADIUS_KM/Ephemeris.RADII_KM[2])<.000001)
	check("same-date lunar position is used in solar overview",(moon.node.position-bodies[2].node.position).is_equal_approx(stage.builder.solar_moon_offset(main.solar_jd,false)) and moon.node.basis.is_equal_approx(Orientation.moon_basis(main.solar_jd)))
	main.object_pointer.rebuild(stage)
	check("ten actual celestial meshes are registered for picking",main.object_pointer.choices.size()==10)
	check("planet names stay hidden until hover or selection",main.learning_overlay.last_solar_labels.is_empty())
	await capture("solar-with-moon")
	main.follow_planet(2); await settle()
	await capture("earth-and-moon")
	var at: Vector2=stage.camera.unproject_position(moon.node.global_position)
	var hit: Dictionary=main.object_pointer.pick(at)
	check("Moon can be picked directly beside the Earth",hit.get("node")==moon.node and hit.get("label","")=="月球")
	if hit.get("node")==moon.node:
		cursor(at); main.object_pointer._process(.2); await settle()
		check("actual lunar hover displays only its name",main.object_pointer.tooltip.visible and main.object_pointer.tooltip.text=="月球")
		await capture("moon-hover")
		click(at); await settle()
	else:
		main.follow_content(2); await settle()
	check("lunar selection uses existing observer and scientific context",main._content_follow==1 and main.solar_follow==-1 and main.immersive_interface.context.get("title","")=="月球" and str(main.immersive_interface.context.get("note","")).contains("27.3"))
	var local_only: bool = bodies[2].node.visible and moon.node.visible and not stage.world_root.get_node("Sun_AuthoredPhotosphere").visible
	for index: int in range(8):
		local_only = local_only and (bodies[index].node.visible==(index==2)) and not bodies[index].orbit.visible
		if index!=2:
			for extra: MeshInstance3D in bodies[index].extras: local_only = local_only and not extra.visible
	check("lunar close view shows local group without enlarged distant planets",local_only and not stage.get_meta("solar_history").node.visible)
	await capture("moon-near")
	var offset: Vector3=stage.camera.position-main._orbit_target
	main.set_solar_date(Ephemeris.DEFAULT_JD+7); await settle()
	check("Moon follow retains the camera offset as date advances",(stage.camera.position-main._orbit_target).is_equal_approx(offset) and main._orbit_target.is_equal_approx(moon.node.position))
	await capture("moon-seven-days-later")
	main.set_solar_distance(true); await settle()
	check("changing global distance preserves selected lunar observer",main._content_follow==1 and main.selected_spatial_choice().get("moon",false) and main._orbit_target.is_equal_approx(moon.node.position))
	check("global distance mode keeps the declared local Moon legible",moon.node.visible and absf(moon.node.scale.x-Ephemeris.body_display_scale(2,true))<.00001 and (moon.node.position-bodies[2].node.position).is_equal_approx(stage.builder.solar_moon_offset(main.solar_jd,true)))
	check("global distance reframes the Moon using its current displayed size",absf(stage.camera.position.distance_to(moon.node.position)-.55*Ephemeris.body_display_scale(2,true))<.00001)
	check("global distance scientific limit declares local enlargement",main.ScienceReference.text_for("solar_system").contains("地月局部") and main.ScienceReference.text_for("solar_system").contains("月距压缩"))
	main.set_solar_distance(false); main.set_solar_date(Ephemeris.DEFAULT_JD)
	await settle()
	check("return from global distance keeps lunar follow and scale",main._content_follow==1 and absf(moon.node.scale.x-1.0)<.00001 and main._orbit_target.is_equal_approx(moon.node.position))
	check("return from global distance restores the lunar camera distance",absf(stage.camera.position.distance_to(moon.node.position)-.55)<.00001)
	main.focus_planet_orbit(4); await settle()
	check("Moon auxiliary respects another planet's isolated orbit view",not moon.node.visible and not moon.orbit.visible)
	main._reset_camera(); await settle()
	var restored: bool = moon.node.visible and stage.world_root.get_node("Sun_AuthoredPhotosphere").visible
	for body: Dictionary in bodies: restored = restored and body.node.visible and body.orbit.visible
	check("leaving lunar close view restores the complete solar overview",restored and stage.get_meta("solar_history").node.visible)

func advance(seconds: float) -> float:
	var start: float=main.world.simulation_time_s
	var deadline: int=Time.get_ticks_msec()+5000
	main.world.set_paused(false)
	while main.world.simulation_time_s-start<seconds and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true); await settle()
	return main.world.simulation_time_s-start

func common_time() -> void:
	var stage: Node=main.coordinator.active_scene
	for rate: float in [1.0/24.0,1.0,30.0]:
		main.set_solar_date(Ephemeris.DEFAULT_JD); main.set_solar_rate(rate)
		var date: float=main.solar_jd
		var elapsed: float=await advance(.5)
		check("shared date matches actual World advancement at "+str(rate),elapsed>=.5 and absf(main.solar_jd-date-elapsed*rate)<.00001)
		var all_dates: bool=true
		for index: int in range(8):
			var body: Node3D=stage.get_meta("solar_bodies")[index].node
			all_dates=all_dates and body.position.is_equal_approx(Ephemeris.display_position(index,main.solar_jd,main.solar_true_distance)) and body.basis.is_equal_approx(Orientation.body_basis(index,main.solar_jd))
		var moon: Dictionary=stage.get_meta("solar_moon")
		all_dates=all_dates and absf(float(moon.jd)-main.solar_jd)<1e-10 and moon.node.basis.is_equal_approx(Orientation.moon_basis(main.solar_jd)) and stage.world_root.get_node("Sun_AuthoredPhotosphere").basis.is_equal_approx(Orientation.sun_basis(main.solar_jd))
		check("positions and rotations of all ten bodies share date at "+str(rate),all_dates)
		measurements.append({"kind":"actual common clock","rate_days_per_world_s":rate,"elapsed_world_s":elapsed,"elapsed_days":main.solar_jd-date})
	main.set_solar_date(Ephemeris.DEFAULT_JD); main.set_solar_rate(1.0/24.0); main.world.set_time_scale(2.0)
	var date: float=main.solar_jd
	var elapsed: float=await advance(.6)
	check("World speed also scales the whole observer without per-body rates",absf(main.solar_jd-date-elapsed/24.0)<.00001 and elapsed>=.6)
	main.world.set_time_scale(1.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD); main.set_solar_rate(1.0/24.0)
	await settle()
	var start_poses: Array[Basis]=[]
	for index: int in range(8):
		var initial: Basis=stage.get_meta("solar_bodies")[index].node.basis
		start_poses.append(initial)
		check("spin measurement starts after the requested date is rendered "+Ephemeris.NAMES[index],initial.is_equal_approx(Orientation.body_basis(index,main.solar_jd)))
	var start_date: float=main.solar_jd
	await advance(.8)
	var angles: Array[float]=[]
	for index: int in range(8):
		var finish_pose: Basis=stage.get_meta("solar_bodies")[index].node.basis
		var angle: float=rad_to_deg(atan2(start_poses[index].z.cross(finish_pose.z).dot(start_poses[index].y),start_poses[index].z.dot(finish_pose.z)))
		var expected: float=(main.solar_jd-start_date)*360.0/Orientation.rotation_days(index)
		angles.append(angle)
		check("visible signed low-speed spin follows its physical period "+Ephemeris.NAMES[index],absf(angle-expected)<.05)
	check("Jupiter Saturn Earth visible spin ratio remains physical",absf(angles[4]/angles[2]-Orientation.rotation_days(2)/Orientation.rotation_days(4))<.002 and absf(angles[5]/angles[2]-Orientation.rotation_days(2)/Orientation.rotation_days(5))<.002)
	measurements.append({"kind":"visible spin ratio","days":main.solar_jd-start_date,"angles_deg":angles})
	var paused_jd: float=main.solar_jd
	var paused_pose: Basis=stage.get_meta("solar_moon").node.basis
	var paused_position: Vector3=stage.get_meta("solar_moon").node.position
	var pixels: PackedByteArray=get_viewport().get_texture().get_image().get_data()
	for frame: int in range(3): await get_tree().process_frame
	check("pause freezes common JD lunar geometry and rendered pixels",main.solar_jd==paused_jd and stage.get_meta("solar_moon").node.basis==paused_pose and stage.get_meta("solar_moon").node.position==paused_position and pixels==get_viewport().get_texture().get_image().get_data())

func filtered_and_sharp() -> void:
	main.set_solar_date(Ephemeris.DEFAULT_JD); main.set_solar_rate(1.0/24.0); main.follow_planet(4); await settle()
	await capture("jupiter-hour-rate")
	main.set_solar_rate(30.0)
	main.world.set_paused(false); await settle()
	var stage: Node=main.coordinator.active_scene
	var bodies: Array=stage.get_meta("solar_bodies")
	check("fast-forward filters unresolved Jupiter Saturn detail",float(bodies[4].material.get_shader_parameter("rotation_exposure_turns"))>1.0 and float(bodies[5].material.get_shader_parameter("rotation_exposure_turns"))>1.0)
	check("filter keeps actual shared-date pose untouched",bodies[4].node.basis.is_equal_approx(Orientation.body_basis(4,main.solar_jd)) and bodies[5].node.basis.is_equal_approx(Orientation.body_basis(5,main.solar_jd)))
	await capture("jupiter-fast-forward")
	main.follow_planet(5); await capture("saturn-fast-forward")
	main.world.set_paused(true); await settle()
	check("pause clears render exposure without stopping a separate clock",float(bodies[4].material.get_shader_parameter("rotation_exposure_turns"))==0.0 and float(bodies[5].material.get_shader_parameter("rotation_exposure_turns"))==0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD+30); await settle()
	check("manual date jump has zero invented exposure",float(bodies[4].material.get_shader_parameter("rotation_exposure_turns"))==0.0)
	main.follow_content(2); await settle()
	get_window().size=Vector2i(640,420); await settle()
	main.immersive_interface.refresh(); main.immersive_interface.fit_window(Vector2i(640,420)); await settle()
	check("compact lunar context and timeline stay inside the window",Rect2(Vector2.ZERO,Vector2(640,420)).encloses(main.immersive_interface.transport.get_global_rect()) and main.immersive_interface.context_title.text=="月球")
	await capture("compact-moon-context")
	get_window().size=Vector2i(1280,800); await settle()

func moon_entry_and_return() -> void:
	main.set_solar_date(Ephemeris.DEFAULT_JD+7); main.set_solar_rate(1.0/24.0)
	main.follow_content(2); await settle()
	var jd: float=main.solar_jd
	var rate: float=main.solar_rate
	main.enter_spatial_choice(main.selected_spatial_choice())
	if not await ready_stage(): return
	check("spatial Moon entry reaches original same-date lunar stage",main.world.current_scale_id=="earth_moon" and main.solar_jd==jd and main.solar_rate==rate and main.coordinator.active_scene.has_meta("lunar"))
	check("Moon entered from solar returns directly to solar",main.observation_parent("earth_moon")=="solar_system")
	main.immersive_interface.refresh()
	check("lunar stage exposes the same astronomical rate menu",main.immersive_interface.rate_button.text=="1小时/秒" and main.immersive_interface.rate_button.get_popup().item_count==6)
	main.set_solar_distance(true); await settle()
	var stage: Node=main.coordinator.active_scene
	var data: Dictionary=stage.get_meta("lunar")
	check("original lunar true-distance view uses physical radius conversion",data.moon.position.is_equal_approx(Orientation.moon_position_km(jd)/Ephemeris.RADII_KM[2]) and data.moon.basis.is_equal_approx(Orientation.moon_basis(jd)))
	main._reset_camera(); await settle(); await capture("lunar-true-distance")
	main._navigate_relative(-1)
	if not await ready_stage(): return
	check("return preserves solar stage observer date and rate",main.world.current_scale_id=="solar_system" and main.solar_jd==jd and main.solar_rate==rate)
	main.set_solar_distance(false); main._reset_camera(); await settle()
	await capture("solar-return")

func finish() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"measurements":measurements,"debug_build":OS.is_debug_build(),"driver":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"os_physical_gestures_tested":false,"reference":reference_path},"\t")+"\n")
	print("SOLAR261_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
