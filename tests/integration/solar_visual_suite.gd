extends "res://tests/integration/solar_spacing_suite.gd"
## Finite actual Metal review of A overview, B close views and camera handoff.

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solar265-output="): directory=argument.trim_prefix("--solar265-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(125).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80
	if not await ready_stage(): await finish(); return
	var world_id: int=main.world.get_instance_id()
	main.world_guide.hide(); main.explorer_panel.hide(); main.message_label.text=""
	if "--solar265-moon" in OS.get_cmdline_user_args():
		main.set_solar_date(jd_for("2000-01-04T14:17:00")); await settle()
		if await drawable_window(): await foreground_moon()
		if await drawable_window(): await navigation()
		check("Moon flow keeps the single paused World and no save",main.world.get_instance_id()==world_id and main.world.paused and main.world.simulation_time_s==0.0 and not main._persistence_enabled)
		await finish(); return
	if "--solar265-science" in OS.get_cmdline_user_args():
		await stable_time(); await geometry(); await paths()
		check("scientific views keep the single paused World and no save",main.world.get_instance_id()==world_id and main.world.paused and main.world.simulation_time_s==0.0 and not main._persistence_enabled)
		await finish(); return
	await cinematic()
	await camera_handoff()
	if not await drawable_window(): await finish(); return
	await moving_observer()
	var world_time: float=main.world.simulation_time_s
	if not "--solar265-basic" in OS.get_cmdline_user_args():
		await stable_time()
		if not await drawable_window(): await finish(); return
		await geometry()
		if not await drawable_window(): await finish(); return
		await foreground_moon()
		await paths()
		if not await drawable_window(): await finish(); return
		await navigation()
	check("single paused World and no save survive visual cameras",main.world.get_instance_id()==world_id and main.world.simulation_time_s==world_time and main.world.paused and not main._persistence_enabled)
	check("bounded five FPS and two worker diagnostic",Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func finish() -> void:
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify({"samples":measurements,"native_os_gestures_tested":false,"performance_test":false},"\t")+"\n")
	await super.finish()

func framed(node: MeshInstance3D) -> bool:
	var stage: Node=main.coordinator.active_scene
	var size: Vector2=Vector2(stage.viewport.size)
	var region: Rect2=main._solar_observation_frame()
	var clear: bool=true
	var bounds: Rect2
	var count: int=0
	for surface: int in range(node.mesh.get_surface_count()):
		var vertices: PackedVector3Array=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var point: Vector3=node.to_global(vertex)
			var pixel: Vector2=stage.camera.unproject_position(point)
			bounds=Rect2(pixel,Vector2.ZERO) if count==0 else bounds.expand(pixel)
			count+=1
			clear=clear and not stage.camera.is_position_behind(point) and pixel.x>size.x*region.position.x and pixel.x<size.x*region.end.x and pixel.y>size.y*region.position.y and pixel.y<size.y*region.end.y
	measurements.append({"kind":"projected subject bounds","name":str(node.name),"bounds":str(bounds),"viewport":str(size),"jd":main.solar_jd})
	return clear and count>0

func cinematic() -> void:
	main.set_solar_distance(false); main.set_solar_date(jd_for("2026-10-07T00:00:00")); main.set_solar_rate(30.0)
	main._reset_camera(); await settle()
	var stage: Node=main.coordinator.active_scene
	var coherent: bool=true
	for index: int in range(8):
		var body: Node3D=stage.get_meta("solar_bodies")[index].node
		coherent=coherent and body.position.is_equal_approx(Ephemeris.display_position(index,main.solar_jd,false)) and body.basis.is_equal_approx(Orientation.body_basis(index,main.solar_jd)) and not stage.camera.is_position_behind(body.position)
	check("cinematic overview keeps all eight actual same-date poses",coherent)
	await capture("cinematic-overview")
	main.follow_planet(4); await settle()
	var jupiter: MeshInstance3D=stage.get_meta("solar_bodies")[4].node
	check("whole Jupiter fits the observation area",framed(jupiter))
	check("close Jupiter remains pickable in 3D",main.object_pointer.pick(stage.camera.unproject_position(jupiter.position)).get("planet",-1)==4)
	await capture("jupiter-close")
	main.follow_planet(5); await settle()
	var saturn: Dictionary=stage.get_meta("solar_bodies")[5]
	check("whole Saturn and complete rings fit wide view",framed(saturn.node) and framed(saturn.extras[0]))
	await capture("saturn-close")
	get_window().size=Vector2i(1280,880); get_window().position=Vector2i(30,30); await settle(); main.follow_planet(5); await settle()
	check("whole Saturn and rings fit narrow Retina view",framed(saturn.node) and framed(saturn.extras[0]))
	await capture("saturn-narrow")
	get_window().size=Vector2i(2560,1600); get_window().position=Vector2i(30,30); await settle()
	main.follow_planet(0); await settle()
	check("Mercury close camera remains outside visible Sun",stage.camera.position.length()>1.65 and framed(stage.get_meta("solar_bodies")[0].node))
	await capture("mercury-close")
	main.follow_content(1); await settle(); await capture("sun-close")
	var sun: MeshInstance3D=stage.world_root.get_node("Sun_AuthoredPhotosphere")
	check("authored Sun remains a depth-tested opaque sphere",not sun.material_override.shader.code.contains("depth_test_disabled") and not sun.material_override.shader.code.contains("ALPHA"))
	check("science panel identifies authored photosphere corona and rings",str(ScienceReference.describe("solar_system").limit).contains("太阳光球纹理、日冕、土星环带"))
	main._reset_camera(); await settle()

func outside_bodies() -> bool:
	var stage: Node=main.coordinator.active_scene
	var position: Vector3=stage.camera.position
	var sun: MeshInstance3D=stage.world_root.get_node("Sun_AuthoredPhotosphere")
	if position.length()<sun.mesh.radius*sun.scale.x+.001: return false
	for index: int in range(8):
		var node: MeshInstance3D=stage.get_meta("solar_bodies")[index].node
		var extent: float=node.mesh.radius*node.scale.x*(2.25 if index==5 and not main.solar_true_distance else 1.0)
		if position.distance_to(node.position)<extent+.001: return false
	var moon: Dictionary=stage.get_meta("solar_moon")
	return position.distance_to(moon.node.position)>moon.radius*moon.node.scale.x+.001

func camera_handoff() -> void:
	var stage: Node=main.coordinator.active_scene
	print("SOLAR265_WINDOW_BEFORE ",JSON.stringify({"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw(),"processing":main.is_processing(),"measurement_screen":main._measurement_screen,"focused":get_window().has_focus()}))
	main.set_process(false); main._reduced_motion=false
	var overview: Transform3D=stage.camera.transform
	main.follow_planet(5)
	check("selection starts a flight without immediate camera teleport",stage.camera.transform.is_equal_approx(overview) and not main._solar_camera_motion.is_empty())
	var safe: bool=true
	for sample: int in range(36):
		main._update_solar_camera(1.15/36.0)
		safe=safe and outside_bodies()
		if sample==17: await capture("approach-midpoint")
	main._update_solar_camera(.001)
	check("sampled approach stays outside ten body and ring envelopes",safe)
	check("approach arrives with whole Saturn and rings",main._solar_camera_motion.is_empty() and framed(stage.get_meta("solar_bodies")[5].extras[0]))
	await capture("approach-arrival")
	var before_return: Transform3D=stage.camera.transform
	main._reset_camera()
	check("return also starts without teleport",stage.camera.transform.is_equal_approx(before_return) and not main._solar_camera_motion.is_empty())
	main._update_solar_camera(.575); await capture("return-midpoint")
	main._update_solar_camera(.576)
	check("return reaches overview without moving the world",main._solar_camera_motion.is_empty() and stage.camera.position.is_equal_approx(stage.default_position))
	main.follow_planet(4); main._update_solar_camera(.2)
	main._zoom_camera(stage,1.1)
	var manual: Transform3D=stage.camera.transform
	main._update_solar_camera(2.0)
	check("zoom takes over flight and camera stops fighting input",main._solar_camera_motion.is_empty() and stage.camera.transform.is_equal_approx(manual))
	main.follow_planet(5); main._update_solar_camera(.2)
	main._pan_camera(stage,Vector2(12,-4)); manual=stage.camera.transform; main._update_solar_camera(2.0)
	check("pan takes over flight and camera stays at user pose",main._solar_camera_motion.is_empty() and stage.camera.transform.is_equal_approx(manual))
	main.follow_planet(0); main._update_solar_camera(.2); main._toggle_reduced_motion()
	check("reduced motion finishes current camera flight",main._solar_camera_motion.is_empty() and main._reduced_motion)
	main._reset_camera(); main.set_process(true); await settle()

func moving_observer() -> void:
	var stage: Node=main.coordinator.active_scene
	main._reduced_motion=false
	for rate: float in [1.0/24.0,30.0]:
		if not await drawable_window(): return
		main.set_solar_date(Ephemeris.DEFAULT_JD); main.set_solar_rate(rate)
		main._reset_camera(); main._update_solar_camera(2.0)
		main.follow_planet(5)
		var time: float=main.world.simulation_time_s
		main.world.set_paused(false)
		var deadline: int=Time.get_ticks_msec()+4000
		while not main._solar_camera_motion.is_empty() and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		main.world.set_paused(true); await settle()
		var elapsed: float=main.world.simulation_time_s-time
		check("camera flight tracks actual common date at rate "+str(rate),elapsed>0.0 and absf(main.solar_jd-Ephemeris.DEFAULT_JD-elapsed*rate)<.00001 and main._solar_camera_motion.is_empty() and main._orbit_target.is_equal_approx(Ephemeris.display_position(5,main.solar_jd,false)+main._pan_offset))
		var coherent: bool=stage.world_root.get_node("Sun_AuthoredPhotosphere").basis.is_equal_approx(Orientation.sun_basis(main.solar_jd))
		for index: int in range(8):
			var node: MeshInstance3D=stage.get_meta("solar_bodies")[index].node
			coherent=coherent and node.position.is_equal_approx(Ephemeris.display_position(index,main.solar_jd,false)) and node.basis.orthonormalized().is_equal_approx(Orientation.body_basis(index,main.solar_jd))
		coherent=coherent and absf(float(stage.get_meta("solar_moon").jd)-main.solar_jd)<1e-10
		check("all ten scientific bodies share date during camera flight "+str(rate),coherent)
		measurements.append({"kind":"moving camera common clock","rate":rate,"elapsed_world_s":elapsed,"jd":main.solar_jd,"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw(),"processing":main.is_processing(),"science_error":main.world.science.error})
	main._reduced_motion=true; main.set_solar_rate(1.0/24.0); main._reset_camera(); await settle()
	var pixels: PackedByteArray=(await stage_image()).get_data()
	check("paused camera and authored solar shader pixels remain frozen",pixels==(await stage_image()).get_data())

func drawable_window() -> bool:
	if get_window().mode!=Window.MODE_WINDOWED: get_window().mode=Window.MODE_WINDOWED
	if get_window().size!=Vector2i(2560,1600): get_window().size=Vector2i(2560,1600)
	get_window().position=DisplayServer.screen_get_usable_rect(get_window().current_screen).position+Vector2i(30,30)
	print("SOLAR265_REQUEST_ACTIVATION")
	var deadline: int=Time.get_ticks_msec()+7000
	var stable: int=0
	while stable<4 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		stable=stable+1 if DisplayServer.window_can_draw() and main.world.foreground else 0
	check("diagnostic window actually drawable before motion and input",stable>=4)
	var state: Dictionary={"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw(),"processing":main.is_processing(),"measurement_screen":main._measurement_screen,"focused":get_window().has_focus(),"shutting_down":main._shutting_down,"mode":get_window().mode,"position":str(get_window().position),"size":str(get_window().size)}
	print("SOLAR265_WINDOW_AFTER ",JSON.stringify(state))
	FileAccess.open(directory.path_join("window.json"),FileAccess.WRITE).store_string(JSON.stringify(state,"\t")+"\n")
	return stable>=4

func foreground_moon() -> void:
	main.follow_content(2); await settle()
	var stage: Node=main.coordinator.active_scene
	var earth: MeshInstance3D=stage.get_meta("solar_bodies")[2].node
	var moon: MeshInstance3D=stage.get_meta("solar_moon").node
	stage.set_pose(moon.position+(moon.position-earth.position).normalized()*.55,moon.position)
	var air: MeshInstance3D=earth.get_parent().get_node("SingleScatteringAtmosphere")
	var layers: int=air.layers
	var before_camera: Transform3D=stage.camera.transform
	var with_air: Image=await stage_image()
	await capture("moon-opaque-occultation")
	air.layers=0
	var without_air: Image=await stage_image()
	var same_frame: bool=with_air.get_size()==without_air.get_size() and before_camera.is_equal_approx(stage.camera.transform)
	check("occultation compares unchanged pixel dimensions and camera",same_frame)
	var center: Vector2=stage.camera.unproject_position(moon.position)
	var error: float=0.0
	if same_frame:
		for offset: Vector2 in [Vector2.ZERO,Vector2(-30,0),Vector2(30,0),Vector2(0,-30),Vector2(0,30)]:
			var pixel: Vector2i=Vector2i(center+offset)
			var a: Color=with_air.get_pixelv(pixel); var b: Color=without_air.get_pixelv(pixel)
			error=maxf(error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	check("foreground opaque Moon receives no Earth air overlay",same_frame and error<.008)
	var changed: int=0
	if same_frame:
		for y: int in range(0,with_air.get_height(),16):
			for x: int in range(0,with_air.get_width(),16):
				if with_air.get_pixel(x,y)!=without_air.get_pixel(x,y): changed+=1
	check("atmosphere remains visible outside the foreground Moon",changed>0)
	air.layers=layers
	with_air.save_png(directory.path_join("moon-control-with-air.png"))
	without_air.save_png(directory.path_join("moon-control-without-air.png"))
	measurements.append({"kind":"opaque Moon pixel difference","maximum_rgb_error":error,"affected_air_pixels":changed,"with_size":str(with_air.get_size()),"without_size":str(without_air.get_size()),"camera_equal":before_camera.is_equal_approx(stage.camera.transform),"foreground":main.world.foreground,"window_mode":get_window().mode})
	check("overlapping projection picks nearest Moon",main.object_pointer.pick(center).get("node")==moon)
	main.set_solar_distance(true); await settle()
	var moon_data: Dictionary=stage.get_meta("solar_moon")
	check("AU mode reframes both local bodies consistently",absf(moon_data.node.scale.x-Ephemeris.body_display_scale(2,true))<.000001 and absf(stage.camera.position.distance_to(moon_data.node.position)-.55*Ephemeris.body_display_scale(2,true))<.000001)
	main.set_solar_distance(false); main._reset_camera(); await settle()

func navigation() -> void:
	main.follow_content(2); await settle()
	main.enter_spatial_choice(main.selected_spatial_choice())
	if not await ready_stage(): return
	check("Moon enters same-date real Earth-Moon stage",main.world.current_scale_id=="earth_moon" and main._solar_camera_motion.is_empty())
	main.set_solar_distance(true); await settle(); await capture("true-earth-moon")
	if not await drawable_window(): return
	main._navigate_relative(-1)
	if not await ready_stage(): return
	check("return restores same observer and solar stage",main.world.current_scale_id=="solar_system")
	main.set_solar_distance(false); main._reset_camera(); await settle()
