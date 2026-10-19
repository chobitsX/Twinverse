extends "res://tests/integration/spatial_experiments_suite.gd"
## A finite check of the actual selected-object input routes, with no OS input.

func ready_stage() -> bool:
	var deadline: int = Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground:
			if DisplayServer.get_name()=="headless" or DisplayServer.window_can_draw(): return true
	records.append({"action":"arrival timeout","requested":main.coordinator._target_id,"scale":main.world.current_scale_id,"phase":main.coordinator.phase,"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw(),"recovery":main.coordinator.recovery_state(),"message":main.message_label.text})
	print("SELECTED_ENTRY_OBSERVATION ",JSON.stringify(records[-1]))
	check("stage ready",false)
	return false

func press(code: Key = KEY_ENTER) -> void:
	get_viewport().gui_release_focus()
	for down: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode=code; event.pressed=down
		dispatch(event)

func select_planet(index: int) -> bool:
	main.explorer_panel.hide(); main.info_panel.hide()
	# Use the existing camera observer to make the actual mesh visible.
	main.follow_planet(index)
	await settle()
	var hit: Dictionary = visible_choice("",main.Ephemeris.NAMES[index])
	check("planet "+str(index)+" has a visible mesh hit",not hit.is_empty())
	if hit.is_empty(): return false
	click(hit.point)
	await settle()
	check("mesh click selects planet "+str(index),main.solar_follow==index and not main.explorer_panel.visible)
	return true

func jupiter_entry(baseline: bool) -> void:
	if not await arrive("solar_system") or not await select_planet(4): return
	if not baseline: await capture("selected-jupiter")
	press()
	records.append({"action":"Jupiter Enter","requested":main.coordinator._target_id,"scale":main.world.current_scale_id,"phase":main.coordinator.phase,"foreground":main.world.foreground,"recovery":main.coordinator.recovery_state()})
	print("SELECTED_ENTRY_OBSERVATION ",JSON.stringify(records[-1]))
	check("Enter on Jupiter requests its own satellite scene",main.coordinator.is_busy() and main.coordinator._target_id=="jupiter_moons")
	if baseline and main.coordinator._target_id!="jupiter_moons": return
	if await ready_stage():
		check("selected Jupiter arrives at its satellite scene",main.world.current_scale_id=="jupiter_moons")
		if not baseline: check("Jupiter entry retains its actual parent",main.observation_parent("jupiter_moons")=="solar_system")

func planets_and_earth() -> void:
	if not await arrive("solar_system") or not await select_planet(3): return
	var stage: Node = main.coordinator.active_scene
	var pose: Transform3D = stage.camera.transform
	press(KEY_DOWN)
	check("Down on an overview-only planet keeps that planet and camera",not main.coordinator.is_busy() and main.world.current_scale_id=="solar_system" and stage.camera.transform.is_equal_approx(pose))
	check("overview-only selection explains its entry boundary",main.message_label.text.contains("仅支持近看"))
	var hit: Dictionary = visible_choice("",main.Ephemeris.NAMES[3])
	if not hit.is_empty():
		click(hit.point);click(hit.point,true)
		check("complete double click on an overview-only planet stays in the same scene",not main.coordinator.is_busy() and main.solar_follow==3)
	for step: int in range(5): magnify(2.0)
	check("approaching an overview-only planet does not enter the default Earth",not main.coordinator.is_busy() and main.world.current_scale_id=="solar_system" and main.solar_follow==3)
	if not await select_planet(2): return
	main.world.set_foreground(false)
	press()
	check("background Enter cannot start selected entry",not main.coordinator.is_busy())
	main.world.set_foreground(true)
	main.world_guide.show();press()
	check("guide modal blocks selected Enter",not main.coordinator.is_busy())
	main.world_guide.hide()
	main.size_comparison.show();press()
	check("size comparison modal blocks selected Enter",not main.coordinator.is_busy())
	main.size_comparison.hide()
	press(KEY_KP_ENTER)
	check("keypad Enter on Earth requests Earth",main.coordinator.is_busy() and main.coordinator._target_id=="earth")
	press()
	check("repeated Enter while entering does not cancel or redirect",main.coordinator.is_busy() and main.coordinator._target_id=="earth")
	if not await ready_stage(): return
	check("selected Earth entry arrives",main.world.current_scale_id=="earth")
	stage=main.coordinator.active_scene
	var site: Dictionary = main.earth_entry_panel.Sites.for_scale("desert")
	stage.set_pose(main.earth_entry_panel.Sites.normal(site.lat,site.lon)*9.6,Vector3.ZERO)
	main._orbit_target=Vector3.ZERO
	main.explorer_panel.hide()
	await settle()
	main.earth_entry_panel.refresh_points()
	var point: Vector2 = main.earth_entry_panel.points.desert.pixel
	click(point)
	main.clean_observation.set_active(true)
	press()
	check("selected Earth region enters in clean observation",main.coordinator.is_busy() and main.coordinator._target_id=="desert")
	if await ready_stage(): check("selected Earth region keeps its parent",main.world.current_scale_id=="desert" and main.observation_parent("desert")=="earth")
	main.clean_observation.set_active(false)

func jupiter_pointer_routes() -> void:
	for mode: String in ["double", "magnify"]:
		if not await arrive("solar_system") or not await select_planet(4): return
		if mode=="double":
			var hit: Dictionary = visible_choice("jupiter_moons")
			check("Jupiter complete double sequence starts on actual geometry",not hit.is_empty())
			if hit.is_empty(): return
			click(hit.point);click(hit.point,true)
		else:
			for step: int in range(6):
				magnify(2.0)
				if main.coordinator.is_busy(): break
		check(mode+" on selected Jupiter requests the same satellite scene",main.coordinator.is_busy() and main.coordinator._target_id=="jupiter_moons")
		if await ready_stage(): check(mode+" Jupiter route arrives",main.world.current_scale_id=="jupiter_moons")

func anatomy_entry() -> void:
	if not await arrive("heart"): return
	main.explorer_panel.hide();main.info_panel.hide()
	var entries: Array[Dictionary] = main.content_targets(false)
	for item: Dictionary in entries:
		if item.get("region","")=="atrium":
			main.follow_content(entries.find(item)+1)
			break
	await settle()
	var hit: Dictionary = visible_choice("","心房")
	check("atrium has a visible anatomy mesh hit",not hit.is_empty())
	if not hit.is_empty():
		click(hit.point)
		await settle()
		var pose: Transform3D = main.coordinator.active_scene.camera.transform
		press()
		check("Enter on the atrium keeps its selected anatomy and camera",not main.coordinator.is_busy() and main.coordinator.active_scene.camera.transform.is_equal_approx(pose) and main.coordinator.active_scene.get_meta("anatomy_selected_region")=="atrium")
		check("atrium gives overview-only feedback",main.message_label.text.contains("仅支持近看"))
		for step: int in range(4): magnify(2.0)
		check("approaching the atrium does not enter another heart region",not main.coordinator.is_busy() and main.world.current_scale_id=="heart")
	for item: Dictionary in entries:
		if item.get("region","")=="ventricle":
			main.follow_content(entries.find(item)+1)
			break
	await settle()
	hit=visible_choice("cardiomyocyte")
	check("ventricle has a visible entry mesh hit",not hit.is_empty())
	if not hit.is_empty():
		click(hit.point)
		await settle()
		press()
		check("Enter on the ventricle requests its actual cell scene",main.coordinator.is_busy() and main.coordinator._target_id=="cardiomyocyte")
		if await ready_stage(): check("ventricle cell entry retains the heart parent",main.world.current_scale_id=="cardiomyocyte" and main.observation_parent("cardiomyocyte")=="heart")

func city_selection() -> void:
	if not await arrive("city"): return
	main.explorer_panel.hide();main.info_panel.hide()
	focus_topic("crossing")
	await settle()
	var stage: Node = main.coordinator.active_scene
	var point: Vector2 = geometry_point(stage.get_meta("pedestrian_signals")[0].node,"crossing")
	check("signal geometry is a selected lesson entry",point.x>=0)
	if point.x>=0:
		click(point)
		await settle()
		press()
		check("Enter on the signal opens the crossing lesson instead of changing city view",main.explorer_panel.visible and main.explorer_panel._topic.get("id","")=="crossing" and not main._city_people_view and not main._city_street_view)
		await capture("selected-signal-lesson")
	main.explorer_panel.hide()
	focus_topic("runoff")
	await settle()
	point=control_point("runoff_valve","runoff","runoff_rain")
	if point.x>=0:
		click(point)
		await settle()
		var rain: bool = main.world.runoff.raining
		var pose: Transform3D = stage.camera.transform
		press()
		check("Enter on the selected valve operates the same rain model",main.world.runoff.raining!=rain and main.world.current_scale_id=="city" and not main.explorer_panel.visible)
		check("selected valve Enter retains camera and world time",stage.camera.transform.is_equal_approx(pose) and main.world.simulation_time_s==original_time)
		var before_double: bool = main.world.runoff.raining
		click(point)
		click(point,true)
		check("complete double click on the selected valve still operates only once",main.world.runoff.raining!=before_double)
		press(KEY_DOWN)
		check("Down after control clicks keeps and operates the current valve",main.world.runoff.raining==before_double and main.coordinator.active_scene.camera.transform.is_equal_approx(pose))
	main._clear_observation_selection()
	main.explorer_panel.hide()
	press()
	check("clearing selection retains the existing city keyboard overview",main._city_people_view and main._content_follow<0)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world254-review="): directory=argument.trim_prefix("--world254-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true;get_viewport().gui_disable_input=true;get_window().size=Vector2i(1280,800)
	get_tree().create_timer(100).timeout.connect(func() -> void:get_tree().quit(2))
	main=Experience.instantiate();add_child(main)
	if DisplayServer.get_name()!="headless":main._measurement_screen=get_window().current_screen
	if is_instance_valid(main._audio):main._audio.volume_db=-80
	main._reduced_motion=true;main.world.set_paused(true);main.set_solar_rate(0)
	main.world_guide.hide();main.guided_journey.hide();main.explorer_panel.hide()
	if not await ready_stage():await finish();return
	original_id=main.world.get_instance_id();original_jd=main.solar_jd;original_time=main.world.simulation_time_s
	var baseline: bool = "--world254-baseline" in OS.get_cmdline_user_args()
	await jupiter_entry(baseline)
	if not baseline:
		await jupiter_pointer_routes()
		await planets_and_earth()
		await anatomy_entry()
		await city_selection()
	check("selected entry retains the sole world date time pause and target identity",main.world.get_instance_id()==original_id and main.solar_jd==original_jd and main.world.simulation_time_s==original_time and main.world.paused and main.world.snapshot().target_fish_id==main.WorldState.TARGET_FISH_ID)
	await finish()

func finish() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"records":records,"failures":failures,"captures":captures,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"viewport_input_routed":true,"native_os_gestures_tested":false,"performance_test":false,"world_id":main.world.get_instance_id(),"original_world_id":original_id,"date_jd":main.solar_jd,"original_date_jd":original_jd,"world_time_s":main.world.simulation_time_s,"original_world_time_s":original_time,"paused":main.world.paused,"no_save":not main._persistence_enabled},"\t"))
	print("SELECTED_ENTRY_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
