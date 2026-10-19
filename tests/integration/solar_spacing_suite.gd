extends "res://tests/integration/solar_trajectory_suite.gd"
## Finite reproduction of changing UI geometry, body clearance and occultation.
const Orientation=preload("res://scripts/core/celestial_orientation.gd")
var measurements: Array[Dictionary]=[]

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solar264-output="): directory=argument.trim_prefix("--solar264-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(95).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80
	if not await ready_stage(): await finish(); return
	var world_id: int=main.world.get_instance_id()
	var world_time: float=main.world.simulation_time_s
	main.world_guide.hide(); main.explorer_panel.hide(); main.message_label.text=""
	main.set_solar_rate(1.0/24.0); main._reset_camera(); await settle()
	await stable_time()
	await geometry()
	await foreground_moon()
	await paths()
	await navigation()
	check("unchanged single paused authority and no save",main.world.get_instance_id()==world_id and main.world.simulation_time_s==world_time and main.world.paused and not main._persistence_enabled)
	check("bounded five FPS and two worker diagnostic",Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	var file: FileAccess=FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":measurements,"native_os_gestures_tested":false,"performance_test":false},"\t")+"\n")
	await finish()

func jd_for(value: String) -> float:
	return 2440587.5+float(Time.get_unix_time_from_datetime_string(value))/86400.0

func stable_time() -> void:
	main.follow_content(2); main.set_solar_date(jd_for("2000-01-04T14:17:00")); await settle()
	var ui: Node=main.immersive_interface
	var card: Rect2=ui.transport.get_global_rect()
	var date_rect: Rect2=main.time_label.get_global_rect()
	var rate_rect: Rect2=ui.rate_button.get_global_rect()
	var font: Font=main.time_label.get_theme_font("font")
	var first_width: float=font.get_string_size("0",HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	var tabular: bool=true
	for digit: int in range(10): tabular=tabular and absf(font.get_string_size(str(digit),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x-first_width)<.001
	check("all ten numerals have equal advance in actual date font",tabular)
	for value: String in ["2000-01-04T14:18:00","2000-01-04T14:19:00","2000-01-04T14:20:00","1999-12-31T23:59:00","2000-01-01T00:00:00","2011-11-11T11:11:00","2008-08-08T08:08:00"]:
		main.set_solar_date(jd_for(value)); await settle()
		check("timestamp layout stationary at "+value,ui.transport.get_global_rect()==card and main.time_label.get_global_rect()==date_rect and ui.rate_button.get_global_rect()==rate_rect)
		measurements.append({"kind":"time slot","value":value,"text":main.time_label.text,"card":str(ui.transport.get_global_rect()),"date":str(main.time_label.get_global_rect())})
	for rate: float in [0.0,1.0/24.0,1.0,30.0,100.0]:
		main.set_solar_rate(rate); await settle()
		check("rate and date formats keep fixed transport "+str(rate),ui.transport.get_global_rect()==card and main.time_label.get_global_rect()==date_rect)
	main.set_solar_rate(1.0/24.0); main.set_solar_date(jd_for("2000-01-04T14:17:00")); await settle()
	await capture("moon-reported-date")
	get_window().size=Vector2i(1280,880); await settle()
	check("fixed date fits narrow Retina window",Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).encloses(ui.transport.get_global_rect()))
	await capture("narrow-time-slot")
	get_window().size=Vector2i(2560,1600); await settle()
	main._reset_camera()

func geometry() -> void:
	var stage: Node=main.coordinator.active_scene
	for true_distance: bool in [false,true]:
		main.set_solar_distance(true_distance)
		for jd: float in [Ephemeris.START_JD,jd_for("2000-01-04T14:17:00"),jd_for("2020-12-21T12:00:00"),Ephemeris.DEFAULT_JD,Ephemeris.END_JD]:
			main.set_solar_date(jd); await settle()
			var centers: Array[Vector3]=[Vector3.ZERO]
			var extents: Array[float]=[1.65*stage.world_root.get_node("Sun_AuthoredPhotosphere").scale.x]
			var coherent: bool=true
			for index: int in range(8):
				var body: Dictionary=stage.get_meta("solar_bodies")[index]
				centers.append(body.node.position)
				extents.append(body.node.mesh.radius*absf(body.node.scale.x)*(2.25 if index==5 and not true_distance else 1.0))
				coherent=coherent and body.node.position.is_equal_approx(Ephemeris.display_position(index,jd,true_distance)) and body.node.basis.orthonormalized().is_equal_approx(Orientation.body_basis(index,jd))
				if true_distance: coherent=coherent and absf(body.node.position.length()/Ephemeris.position_au(index,jd).length()-.55)<.000001
			var moon: Dictionary=stage.get_meta("solar_moon")
			centers.append(moon.node.position); extents.append(moon.radius*absf(moon.node.scale.x))
			coherent=coherent and (moon.node.position-centers[3]).is_equal_approx(stage.builder.solar_moon_offset(jd,true_distance)) and moon.node.basis.orthonormalized().is_equal_approx(Orientation.moon_basis(jd))
			var clearance: float=INF
			for i: int in range(centers.size()):
				for k: int in range(i+1,centers.size()): clearance=minf(clearance,centers[i].distance_to(centers[k])-extents[i]-extents[k])
			check("all ten bodies including ring clearance at "+str(jd)+" AU="+str(true_distance),clearance>0.0)
			check("same date poses and common AU mapping at "+str(jd)+" AU="+str(true_distance),coherent)
			measurements.append({"kind":"scene clearance","jd":jd,"au_view":true_distance,"minimum_gap":clearance,"pairs":45})
		main.set_solar_date(jd_for("2020-12-21T12:00:00")); main._reset_camera(); await settle()
		await capture("au-overview" if true_distance else "spaced-overview")
		if not true_distance:
			main.follow_planet(5); await settle(); await capture("jupiter-saturn-conjunction")
			main._reset_camera()
	main.set_solar_distance(false); main.set_solar_date(jd_for("2000-01-04T14:17:00")); await settle()

func stage_image() -> Image:
	for frame: int in range(3): await RenderingServer.frame_post_draw
	return main.coordinator.active_scene.viewport.get_texture().get_image()

func foreground_moon() -> void:
	main.follow_content(2); await settle()
	var stage: Node=main.coordinator.active_scene
	var earth: MeshInstance3D=stage.get_meta("solar_bodies")[2].node
	var moon: MeshInstance3D=stage.get_meta("solar_moon").node
	var direction: Vector3=(moon.position-earth.position).normalized()
	stage.set_pose(moon.position+direction*.55,moon.position)
	var air: MeshInstance3D=earth.get_parent().get_node("SingleScatteringAtmosphere")
	air.show(); var with_air: Image=await stage_image()
	await capture("moon-opaque-occultation")
	# Production pose updates restore visibility every frame. Use the render
	# layer mask to exclude air only for this diagnostic comparison.
	var air_layers: int=air.layers
	air.layers=0; var without_air: Image=await stage_image()
	var error: float=0.0
	var center: Vector2=stage.camera.unproject_position(moon.position)
	for offset: Vector2 in [Vector2.ZERO,Vector2(-30,0),Vector2(30,0),Vector2(0,-30),Vector2(0,30)]:
		var pixel: Vector2i=Vector2i(center+offset)
		var a: Color=with_air.get_pixelv(pixel); var b: Color=without_air.get_pixelv(pixel)
		error=maxf(error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	check("foreground opaque Moon receives no Earth air overlay",error<.008)
	var changed: int=0
	# Include the atmospheric limb outside both projected disks, not just the
	# inner 300px which this close-up fills entirely with the foreground Moon.
	for y: int in range(0,with_air.get_height(),16):
		for x: int in range(0,with_air.get_width(),16):
			if with_air.get_pixel(x,y)!=without_air.get_pixel(x,y): changed+=1
	check("atmosphere remains visible outside the foreground Moon",changed>0)
	measurements.append({"kind":"opaque Moon pixel difference","maximum_rgb_error":error,"affected_air_pixels":changed})
	air.layers=air_layers
	var hit: Dictionary=main.object_pointer.pick(center)
	check("overlapping projection picks nearest Moon",hit.get("node")==moon)
	main.set_solar_distance(true); await settle()
	var moon_data: Dictionary=stage.get_meta("solar_moon")
	check("AU mode reframes both local bodies consistently",absf(moon_data.node.scale.x-Ephemeris.body_display_scale(2,true))<.000001 and absf(stage.camera.position.distance_to(moon_data.node.position)-.55*Ephemeris.body_display_scale(2,true))<.000001)
	main.set_solar_distance(false); main._reset_camera(); await settle()

func paths() -> void:
	var stage: Node=main.coordinator.active_scene
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	for true_distance: bool in [false,true]:
		main.set_solar_distance(true_distance)
		for index: int in range(8):
			main.focus_planet_orbit(index); await settle()
			var path: MeshInstance3D=stage.world_root.get_node("SelectedDE440Trajectory")
			var point: Vector3=stage.get_meta("solar_bodies")[index].node.position
			var distance: float=distance_to_path(path,point)
			check("date path follows actual body "+Ephemeris.NAMES[index]+" AU="+str(true_distance),distance<.01 and int(path.get_meta("index"))==index)
			measurements.append({"kind":"body to date polyline","index":index,"au_view":true_distance,"error_display_units":distance})
			if index==5 and not true_distance: await capture("saturn-orbit")
	main.set_solar_distance(false); main._reset_camera(); await settle()

func navigation() -> void:
	main.follow_content(2); await settle()
	main.enter_spatial_choice(main.selected_spatial_choice())
	if not await ready_stage(): return
	check("Moon enters same-date real Earth-Moon stage",main.world.current_scale_id=="earth_moon")
	main.set_solar_distance(true); await settle(); await capture("true-earth-moon")
	main._navigate_relative(-1)
	if not await ready_stage(): return
	check("return restores the solar system",main.world.current_scale_id=="solar_system")
	main.set_solar_distance(false); main._reset_camera()
	if not await arrive("earth"): return
	await capture("earth-air-regression")
	if not await arrive("atmosphere"): return
	await capture("local-air-regression")
	check("local atmospheric compositing still enabled",main.coordinator.active_scene.world_root.get_node("SingleScatteringAtmosphere").material_override.get_shader_parameter("composite_local_air"))
