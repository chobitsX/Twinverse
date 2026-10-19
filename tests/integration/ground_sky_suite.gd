extends "res://tests/integration/spatial_input_suite.gd"
## Short source/actual Release checks for ground observation; one World, no saves.
const Ground = preload("res://scripts/experience/ground_sky_builder.gd")
var reference_path: String
var observed_world_delta: float=0.0

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--sky262-output="): directory=argument.trim_prefix("--sky262-output=")
		if argument.begins_with("--sky262-reference="): reference_path=argument.trim_prefix("--sky262-reference=")
	if not directory.is_absolute_path() or not reference_path.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80
	if not await ready_stage(): await finish(); return
	original_id=main.world.get_instance_id(); original_time=main.world.simulation_time_s
	main.explorer_panel.hide(); main.info_panel.hide(); main.message_label.text=""
	await settle()
	science()
	await sky_view()
	await date_and_moon()
	await geographic_entry()
	check("one World, only requested seconds advanced, no user save",main.world.get_instance_id()==original_id and absf(main.world.simulation_time_s-original_time-observed_world_delta)<1.e-9 and not main._persistence_enabled)
	check("five FPS diagnostic and two workers",Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func v(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func science() -> void:
	var reference: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	var star_error: float=0.; var gal_error: float=0.; var moon_error: float=0.; var planet_error: float=0.
	for row: Dictionary in reference.stars:
		var actual: Vector3=Ground.Geometry.inertial_to_local(row.jd,row.site)*Ground.Geometry.star_direction(row.ra,row.dec)
		star_error=maxf(star_error,actual.distance_to(v(row.local)))
	for row: Dictionary in reference.galactic:
		var actual: Vector3=Ground.Geometry.local_from_galactic(row.jd,row.site)*v(row.galactic)
		gal_error=maxf(gal_error,actual.distance_to(v(row.local)))
	for row: Dictionary in reference.bodies:
		var actual: Dictionary=Ground.Geometry.body(row.jd,int(row.index),row.site)
		var error: float=Vector3(actual.direction).distance_to(v(row.local))
		if int(row.index)==8: moon_error=maxf(moon_error,error)
		else: planet_error=maxf(planet_error,error)
	check("36 SPICE star directions across three dates and latitudes",star_error<2.e-6)
	check("36 ERFA Galactic frame samples align the Gaia map",gal_error<2.e-6)
	check("nine ERFA topocentric Moon directions",moon_error<2.e-6)
	check("18 independent DE440 Sun/Jupiter directions",planet_error<2.e-5)
	records.append({"kind":"science","star_unit_error":star_error,"galactic_unit_error":gal_error,"moon_unit_error":moon_error,"planet_unit_error":planet_error})
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Ground.CATALOG))
	var invalid: int=0
	for row: Array in catalog.rows:
		if float(row[3])>6.5 or int(row[0]) in [92,95,182,1057,1841,2472,2496,3515,3671,6309,6515,7189,7539,8296]: invalid+=1
	check("8404 catalog stars and non-stellar entries excluded",catalog.rows.size()==8404 and invalid==0)

func sky_view() -> void:
	var stage: Node=main.coordinator.active_scene
	check("initial night preset explicit and same date geometry",stage.scale_id=="night_sky" and main.solar_demo_auto and main.solar_rate==1.0/1440.0 and float(stage.get_meta("sun_elevation"))< -18.)
	check("Gaia map loaded and full visible attribution",stage.get_meta("ground_sky").credit and main.immersive_interface.sky_credit.visible and main.immersive_interface.sky_credit.text.contains("A. Moitinho"))
	check("fixed ground eye and wide view",stage.camera.position.is_equal_approx(Ground.EYE) and stage.camera.fov==78.0)
	await capture("night-wide")
	var layered: PackedByteArray=stage.viewport.get_texture().get_image().get_data()
	stage.get_meta("ground_sky").batch.hide(); await settle()
	check("catalog stars remain visible over the Gaia background",layered!=stage.viewport.get_texture().get_image().get_data())
	stage.get_meta("ground_sky").batch.show(); await settle()
	var before: PackedByteArray=get_viewport().get_texture().get_image().get_data()
	await settle(); await settle()
	var after: PackedByteArray=get_viewport().get_texture().get_image().get_data()
	check("pause freezes the actual night image",before==after)
	var motion_jd: float=main.solar_jd
	var motion_time: float=main.world.simulation_time_s
	main.world.set_paused(false)
	for frame: int in range(5): await get_tree().process_frame
	main.world.set_paused(true); main._update_exploration(); await settle()
	observed_world_delta=main.world.simulation_time_s-motion_time
	check("live night motion uses one minute per World second",observed_world_delta>0. and absf(main.solar_jd-motion_jd-observed_world_delta/1440.)<1.e-9)
	check("live motion changes the actual star field",after!=get_viewport().get_texture().get_image().get_data())
	records.append({"kind":"live common clock","world_delta_s":observed_world_delta,"start_jd":motion_jd,"end_jd":main.solar_jd,"rate_days_per_world_s":main.solar_rate})
	await capture("night-motion")
	main.set_solar_date(motion_jd); main.solar_demo_auto=true; main.solar_manual_setting=false; main._update_exploration(); await settle()
	var pose: Transform3D=stage.camera.transform
	magnify(1.4); check("routed pinch changes FOV and retains eye",stage.camera.fov<60. and stage.camera.position.is_equal_approx(Ground.EYE))
	magnify(1./1.4); check("inverse pinch restores wide view",absf(stage.camera.fov-78.)<.0001)
	var motion: InputEventMouseMotion=InputEventMouseMotion.new(); motion.position=Vector2(640,360); motion.relative=Vector2(110,28); motion.button_mask=MOUSE_BUTTON_MASK_RIGHT
	dispatch(motion)
	check("drag rotates from the ground instead of orbiting",not stage.camera.transform.is_equal_approx(pose) and stage.camera.position.is_equal_approx(Ground.EYE))
	await capture("ground-pan")
	main._reset_camera(); main.set_solar_rate(0.); await settle()
	var dome: Node3D=stage.world_root.get_node("TopocentricSky_GalacticCoordinates")
	dome.hide(); await settle()
	var star_image: Image=stage.viewport.get_texture().get_image()
	var bright_pixels: int=0
	for y: int in range(0,int(star_image.get_height()*.6),2):
		for x: int in range(0,star_image.get_width(),2):
			var color: Color=star_image.get_pixel(x,y)
			if color.r+color.g+color.b>.7: bright_pixels+=1
	check("catalog star layer actually emits visible points",bright_pixels>20)
	records.append({"kind":"catalog layer","bright_pixels_sampled":bright_pixels})
	await capture("star-layer")
	dome.show(); await settle()
	var targets: Array[Dictionary]=main.content_targets()
	var picked: Dictionary={}
	for item: Dictionary in targets:
		if not item.has("hr") or stage.camera.is_position_behind(item.node.global_position): continue
		var pixel: Vector2=stage.camera.unproject_position(item.node.global_position)
		if not Rect2(80,90,1100,460).has_point(pixel): continue
		picked=main.object_pointer.pick(pixel)
		if not picked.is_empty():
			cursor(pixel); await settle(); click(pixel); break
	check("real projected star selects its catalog name",not picked.is_empty() and main._content_follow>=0 and main.selected_spatial_choice().label==picked.label and stage.camera.position.is_equal_approx(Ground.EYE))
	await capture("selected-star")
	main._reset_camera(); main.set_solar_rate(1./1440.); main._remember_view()
	check("new minute rate and optical FOV validate for storage",main.WorldStore.valid_view(main._views.night_sky))
	main.clean_observation.set_active(true); await settle()
	check("clean view retains Gaia attribution and 3D controls",main.immersive_interface.sky_credit.visible and main.object_pointer.available())
	main.clean_observation.set_active(false)

func date_and_moon() -> void:
	var stage: Node=main.coordinator.active_scene
	var start_jd: float=main.solar_jd
	var first: Basis=stage.get_meta("ground_sky").root.basis
	main.set_solar_date(start_jd+1./24.); main._update_exploration(); await settle()
	var second: Basis=stage.get_meta("ground_sky").root.basis
	var degrees: float=rad_to_deg(Quaternion(first.inverse()*second).get_angle())
	check("one hour turns the star frame about fifteen degrees",degrees>14. and degrees<16.)
	check("all ground bodies read the common date",absf(float(stage.get_meta("ground_sky").jd)-main.solar_jd)<1.e-10)
	records.append({"kind":"one hour Earth motion","degrees":degrees})
	var noon: float=Ground.Geometry.Seasons.noon(start_jd,float(Ground.Geometry.PARANAL.lon))
	main.set_solar_date(noon); main._update_exploration(); main._reset_camera(); await settle()
	check("same date Sun drives daylight and hides catalog glow",float(stage.get_meta("sun_elevation"))>45. and float(stage.get_meta("night_strength"))<.01)
	await capture("daylight")
	main.set_solar_date(start_jd); main._update_exploration(); main._reset_camera(); await settle()
	var moon_index: int=-1
	for index: int in range(main.content_targets().size()):
		if int(main.content_targets()[index].get("body",-1))==8: moon_index=index
	var sample: Dictionary=stage.get_meta("ground_sky").samples[8]
	if float(sample.altitude)<5.:
		main.set_solar_date(noon+.2); main._update_exploration(); await settle(); sample=stage.get_meta("ground_sky").samples[8]
	check("Moon uses actual angular diameter",float(sample.angular_radius)>deg_to_rad(.23) and float(sample.angular_radius)<deg_to_rad(.29))
	main.follow_content(moon_index+1); await settle()
	var pixel: Vector2=stage.camera.unproject_position(stage.get_meta("ground_sky").moon.global_position)
	var picked: Dictionary=main.object_pointer.pick(pixel)
	records.append({"kind":"Moon optical view","fov":stage.camera.fov,"eye":main.WorldStore.components(stage.camera.position),"picked_body":picked.get("body",-1),"altitude":sample.altitude})
	check("Moon optical view uses fixed eye and actual sky picking",absf(stage.camera.fov-2.4)<.00001 and stage.camera.position.is_equal_approx(Ground.EYE) and int(picked.get("body",-1))==8)
	await capture("moon-optical")
	magnify(1.4); check("Moon pinch zoom retains actual angular geometry",stage.camera.fov<2.4 and int(stage.get_meta("ground_sky").catalog_count)==8404)
	main._reset_camera(); main.set_solar_date(start_jd); main.set_solar_rate(0.); main._update_exploration(); await settle()
	get_window().size=Vector2i(640,420); main._resize(); await settle()
	main.immersive_interface.refresh()
	check("small window keeps time and map attribution inside viewport",Rect2(Vector2.ZERO,Vector2(640,420)).encloses(main.immersive_interface.transport.get_global_rect()) and main.immersive_interface.sky_credit.get_global_rect().end.x<=640.)
	await capture("compact-sky")
	get_window().size=Vector2i(1280,800); main._resize(); await settle()

func geographic_entry() -> void:
	var date: float=main.solar_jd
	if not await arrive("earth"): return
	var stage: Node=main.coordinator.active_scene
	main.focus_earth_reference("night_sky"); await settle()
	main.earth_entry_panel.refresh_points()
	check("Atacama is an actual selectable globe area",main.earth_entry_panel.points.has("night_sky"))
	var point: Vector2=main.earth_entry_panel.points.night_sky.pixel if main.earth_entry_panel.points.has("night_sky") else Vector2.ZERO
	check("geographic surface picking reaches Atacama",main.earth_entry_panel.pick(point)=="night_sky")
	click(point); await settle(); check("globe click names the observer region",main.earth_entry_panel.selected=="night_sky")
	await capture("earth-region")
	click(point)
	if not await ready_stage(): return
	check("second globe click enters with original common date",main.world.current_scale_id=="night_sky" and absf(main.solar_jd-date)<1.e-10 and main.observation_parent("night_sky")=="earth")
	main._reset_camera(); main.coordinator.active_scene.camera.fov=100.
	magnify(.8)
	if not await ready_stage(): return
	check("wide pinch returns to the same Earth context",main.world.current_scale_id=="earth" and main.earth_entry_panel.selected=="night_sky" and absf(main.solar_jd-date)<1.e-10)
