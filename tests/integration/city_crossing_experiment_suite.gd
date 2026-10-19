extends "res://tests/integration/world_expansion_suite.gd"
const Traffic = preload("res://scripts/core/city_traffic.gd")
const Life = preload("res://scripts/experience/life_asset_motion.gd")
const CityWalk = preload("res://scripts/experience/city_walk_path.gd")
const Store = preload("res://scripts/core/world_store.gd")
var observations: Dictionary = {}
var view_settings: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var resumed: bool = false
var isolated_directory: String = ""

func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen==DisplayServer.get_primary_screen(): continue
		if get_window().current_screen!=screen:
			var wanted: Vector2i=get_window().size
			get_window().current_screen=screen
			get_window().position=DisplayServer.screen_get_usable_rect(screen).position+Vector2i(30,30)
			get_window().size=wanted
		main._measurement_screen=screen
		break
	for frame: int in range(4): await get_tree().process_frame

func capture(label: String) -> void:
	await settle()
	var state: Dictionary=main.world.city_traffic.snapshot(main.world.simulation_time_s)
	view_settings.append({"view":label,"screen_count":DisplayServer.get_screen_count(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"window_size":[get_window().size.x,get_window().size.y]})
	var stage: Node=main.coordinator.active_scene
	var people: Array=stage.get_meta("crossing_people")
	samples.append({"view":label,"world_time_s":main.world.simulation_time_s,"local_state":state,"pedestrian_positions":[Store.components(people[0].position),Store.components(people[1].position)],"pedestrian_signal":stage.get_meta("pedestrian_signals")[0].label.text,"readout":main.explorer_panel.lesson_readout.text})
	await super.capture(label)

func unrelated_checkpoint() -> Dictionary:
	var state: Dictionary=main.world.checkpoint()
	state.erase("city_traffic");state.erase("current_scale_id");state.erase("local_habitat")
	return state

func people_positions() -> Array[Vector3]:
	var values: Array[Vector3]=[]
	for person: Node3D in main.coordinator.active_scene.get_meta("crossing_people"): values.append(person.position)
	return values

func person_bone_signature() -> String:
	var person: Node3D=main.coordinator.active_scene.get_meta("crossing_people")[0]
	var skeleton: Skeleton3D=person.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var values: Array[String]=[]
	for bone: int in range(skeleton.get_bone_count()): values.append(str(skeleton.get_bone_pose(bone)))
	return str(values).sha256_text()

func scene_matches_authority() -> bool:
	var stage: Node=main.coordinator.active_scene
	var state: Dictionary=main.world.city_traffic.snapshot(main.world.simulation_time_s)
	var local_time: float=float(state.elapsed_s)
	var duration: float=float(state.walk_duration_s)
	var correct: bool=true
	var people: Array=stage.get_meta("crossing_people")
	for index: int in range(2):
		var pose: Dictionary=Traffic.pedestrian(local_time,index,duration)
		correct=correct and people[index].position.distance_to(pose.position+Vector3(0,Life.person_root_offset(pose.moving),0))<.0001 and absf(angle_difference(people[index].rotation.y,pose.heading))<.0001
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind=="car":
			var pose: Dictionary=Traffic.vehicle(local_time,actor.index,duration)
			correct=correct and actor.node.position.distance_to(pose.position)<.0001 and actor.node.visible==pose.visible
		elif actor.kind=="person" and actor.index<Traffic.PARK_PEOPLE:
			var pose: Dictionary=CityWalk.itinerary(main.world.simulation_time_s,actor.index,Traffic.PARK_PEOPLE)
			correct=correct and actor.node.position.distance_to(pose.position+Vector3(0,Life.person_root_offset(pose.moving),0))<.0001
	for signal_data: Dictionary in stage.get_meta("signals"):
		var on: bool=Traffic.vehicle_green(local_time,int(signal_data.axis),duration)
		correct=correct and (signal_data.green.emission!=Color.BLACK)==on
	return correct

func controls_fit() -> bool:
	var panel: Node=main.explorer_panel
	var clip: Rect2=panel.scroll.get_global_rect().grow(.5)
	var clear: bool=true
	var controls: Array[Control]=[panel.topic_picker,panel.traffic_profile_buttons[0],panel.traffic_profile_buttons[1],panel.traffic_reset,panel.traffic_strip,panel.traffic_hint]
	for control: Control in controls: clear=clear and control.is_visible_in_tree() and clip.encloses(control.get_global_rect())
	return clear

func subjects_fit() -> bool:
	var stage: Node=main.coordinator.active_scene
	var camera: Camera3D=stage.camera
	var left: float=main.explorer_panel.get_global_rect().end.x+8.0
	var visible_rect: Rect2=Rect2(Vector2(left,112),Vector2(get_window().size.x-left-22,get_window().size.y-218))
	var clear: bool=true
	for person: Node3D in stage.get_meta("crossing_people"):
		for up: float in [0.0,1.8]:
			var at: Vector3=person.position+Vector3.UP*up
			clear=clear and not camera.is_position_behind(at) and visible_rect.has_point(camera.unproject_position(at))
	return clear

func at_elapsed(value: float) -> void:
	main.world.simulation_time_s=main.world.city_traffic.started_at_s+value
	await settle()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world235-review="): directory=argument.trim_prefix("--world235-review=")
		if argument.begins_with("--world-dir="): isolated_directory=argument.trim_prefix("--world-dir=")
		if argument=="--world235-resume": resumed=true
	var target: String=directory.get_file().get_slice("-",0)
	var expected: String=directory.get_base_dir().path_join(target+"-crossing").path_join("isolated-world")
	if not directory.is_absolute_path() or target not in ["source","release"] or isolated_directory!=expected or not isolated_directory.is_absolute_path():
		get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size=Vector2i(1280,800)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	main=Experience.instantiate()
	main.world.set_paused(true)
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage(): await finish();return
	get_window().size=Vector2i(1280,800)
	main._audio.volume_db=-80.0
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	await settle()
	check("runtime uses only explicit isolated save directory",main._persistence_enabled and main._store.directory==isolated_directory and main.world.current_scale_id=="city")
	if resumed:
		await resume_flow()
		return
	main.world.simulation_time_s=12.0
	main.world.set_time_scale(2.0)
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.explorer_panel.show()
	await settle()
	var authority: int=main.world.get_instance_id()
	var panel: Node=main.explorer_panel
	var before: Dictionary=main.world.city_traffic.checkpoint()
	check("real crossing topic activates",panel.select_topic("crossing",true))
	await settle()
	check("entering lesson does not reset traffic time date or playback",main.world.city_traffic.checkpoint()==before and main.world.simulation_time_s==12.0 and main.world.paused and main.world.time_scale==2.0 and main.solar_jd==Ephemeris.DEFAULT_JD and main.solar_rate==0.0)
	check("front controls legend and source are usable",controls_fit() and panel.lesson_source.visible and panel._topic.source==main.world.CityTrafficLesson.SOURCE)
	var people: Array=main.coordinator.active_scene.get_meta("crossing_people")
	var first_id: int=people[0].get_instance_id()
	var stable_id: String=people[0].get_meta("stable_id")
	var unrelated: Dictionary=unrelated_checkpoint()
	panel.traffic_profile_buttons[0].pressed.emit()
	await settle()
	check("real default button changes only the local origin",main.world.city_traffic.profile==0 and main.world.city_traffic.started_at_s==12.0 and unrelated_checkpoint()==unrelated and people[0].get_instance_id()==first_id)
	await at_elapsed(32.0)
	check("default real signals vehicles park routes and pedestrians share authority",scene_matches_authority())
	check("default lesson keeps both people beside panel and HUD",subjects_fit())
	await capture("crossing-default-middle")
	await at_elapsed(44.0)
	var default_late: Array[Vector3]=people_positions()
	check("default pedestrians complete before old clearance ends",Traffic.pedestrian(44,0).fraction==1.0 and Traffic.pedestrian(44,1).fraction==1.0 and main.coordinator.active_scene.get_meta("pedestrian_signals")[0].label.text=="行人 · 等待")
	await capture("crossing-default-late")
	unrelated=unrelated_checkpoint()
	panel.traffic_profile_buttons[1].pressed.emit()
	await settle()
	check("real slow button preserves every other model date and identity",main.world.city_traffic.profile==1 and unrelated_checkpoint()==unrelated and main.world.simulation_time_s==56.0 and main.solar_jd==Ephemeris.DEFAULT_JD and people[0].get_instance_id()==first_id)
	check("strip presents actual 56 second model and longer clearance",float(panel.traffic_strip.state.period_s)==56.0 and float(panel.traffic_strip.state.clear_end_s)==52.0 and panel.lesson_readout.text.contains("0.68 m/s") and panel.lesson_readout.text.contains("36秒"))
	await at_elapsed(32.0)
	check("slow people and actual vehicle signals reflect slower profile",scene_matches_authority() and Traffic.pedestrian(32,0,24).fraction<Traffic.pedestrian(32,0).fraction)
	await capture("crossing-slow-middle")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact window retains front choices restart strip and legend",controls_fit())
	check("compact window retains both actual walking bodies",subjects_fit())
	await capture("crossing-slow-compact")
	get_window().size=Vector2i(1280,800)
	await at_elapsed(44.0)
	check("at old cutoff slow people still cross under matching protection",scene_matches_authority() and people_positions()!=default_late and main.coordinator.active_scene.get_meta("pedestrian_signals")[0].label.text=="行人 · 清空" and panel.lesson_readout.text.contains("8.0秒"))
	await capture("crossing-slow-late")
	var frozen: Array[Vector3]=people_positions()
	var bones: String=person_bone_signature()
	var model: Dictionary=main.world.checkpoint()
	await settle()
	check("pause holds roots bones model and strip phase together",people_positions()==frozen and person_bone_signature()==bones and main.world.checkpoint()==model and float(panel.traffic_strip.state.phase_s)==44.0)
	main._remember_view()
	check("ordinary save path writes v15 to isolated real file",main.save_world()=="ok")
	var reader: Store=Store.new(isolated_directory)
	var saved: Dictionary=reader.load_session()
	check("saved payload contains actual slow origin pause date view and models",saved.status=="ok" and saved.payload.world.version==15 and saved.payload.world.city_traffic.profile==1 and saved.payload.world.city_traffic.started_at_s==56.0 and saved.payload.world.simulation_time_s==100.0 and saved.payload.world.paused and saved.payload.observer.views.city.astronomy.jd==Ephemeris.DEFAULT_JD)
	main._persistence_enabled=false
	main.set_process(false)
	main.world.set_paused(false)
	main.world.advance(.1)
	main.coordinator.active_scene.set_city_traffic_state(main.world.city_traffic.snapshot(main.world.simulation_time_s))
	main.coordinator.active_scene.set_world_time(main.world.simulation_time_s)
	main.world.set_paused(true)
	main.set_process(true)
	await settle()
	check("short continued world time changes crossing roots and real bones",people_positions()!=frozen and person_bone_signature()!=bones and absf(main.world.simulation_time_s-100.2)<.000001 and scene_matches_authority())
	await at_elapsed(52.0)
	check("slow arrival then clearance ends with people inside opposite curb",scene_matches_authority() and Traffic.pedestrian(52,0,24).fraction==1.0 and Traffic.pedestrian(52,1,24).fraction==1.0 and main.coordinator.active_scene.get_meta("pedestrian_signals")[0].label.text=="行人 · 等待")
	await capture("crossing-slow-complete")
	var local: Dictionary=main.world.city_traffic.snapshot(main.world.simulation_time_s)
	unrelated=unrelated_checkpoint()
	check("original traffic topic shares the same experiment",panel.select_topic("traffic",true))
	await settle()
	check("topic switch does not change phase or other authoritative values",main.world.city_traffic.snapshot(main.world.simulation_time_s)==local and unrelated_checkpoint()==unrelated and controls_fit())
	if not await arrive("earth"): await finish();return
	await settle()
	check("Earth return keeps the one world and local choice",main.world.get_instance_id()==authority and main.world.city_traffic.snapshot(main.world.simulation_time_s)==local and unrelated_checkpoint()==unrelated)
	if not await arrive("city"): await finish();return
	main.explorer_panel.show()
	await settle()
	panel=main.explorer_panel
	panel.select_topic("crossing",true)
	await settle()
	check("city reentry restores local phase actual actors and stable individual",main.world.get_instance_id()==authority and main.world.city_traffic.snapshot(main.world.simulation_time_s)==local and scene_matches_authority() and main.coordinator.active_scene.get_meta("crossing_people")[0].get_meta("stable_id")==stable_id)
	check("original city populations and authored motion resources remain",main.coordinator.active_scene.get_meta("actors").size()==40 and main.coordinator.active_scene.get_meta("street_walkers").size()==6 and main.coordinator.active_scene.get_meta("crossing_people").size()==2)
	unrelated=unrelated_checkpoint()
	panel.traffic_reset.pressed.emit()
	await settle()
	check("real restart preserves slow profile world date and other experiments",main.world.city_traffic.profile==1 and main.world.city_traffic.snapshot(main.world.simulation_time_s).elapsed_s==0.0 and unrelated_checkpoint()==unrelated and main.solar_jd==Ephemeris.DEFAULT_JD and main.world.simulation_time_s==108.0 and main.world.paused)
	check("restarted actual people cars and signals share phase zero",scene_matches_authority() and panel.traffic_strip.state.phase_s==0.0)
	check("resource settings keep two workers background five and foreground thirty",int(ProjectSettings.get_setting("threading/worker_pool/max_threads"))==2 and Engine.max_fps==5 and int(ProjectSettings.get_setting("application/run/max_fps"))==30 and main._render_ratio==.75)
	observations={"world_instance":authority,"world_time_s":main.world.simulation_time_s,"saved_world_time_s":100.0,"paused":main.world.paused,"time_scale":main.world.time_scale,"jd":main.solar_jd,"solar_rate":main.solar_rate,"saved_profile":1,"saved_origin_s":56.0,"current_checkpoint_version":15,"capture_window_settings":view_settings,"samples":samples,"user_save_accessed":false,"isolated_world_dir":isolated_directory,"native_input_tested":false,"unfocusable":get_window().unfocusable,"native_input_disabled":get_viewport().gui_disable_input,"audio_volume_db":main._audio.volume_db,"max_fps":Engine.max_fps,"foreground_fps":ProjectSettings.get_setting("application/run/max_fps"),"worker_pool_threads":ProjectSettings.get_setting("threading/worker_pool/max_threads"),"render_ratio":main._render_ratio}
	await finish()

func resume_flow() -> void:
	var loaded: Dictionary=main._store.load_session()
	check("second process uses ordinary world open and actual v15 JSON",loaded.status=="ok" and main.world.simulation_time_s==100.0 and main.world.city_traffic.profile==1 and main.world.city_traffic.started_at_s==56.0 and main.world.paused and main.world.time_scale==2.0)
	check("ordinary open restores same date rate and author origin",main.solar_jd==Ephemeris.DEFAULT_JD and main.solar_rate==0.0 and main.world.city_traffic.snapshot(main.world.simulation_time_s).phase_s==44.0)
	main.explorer_panel.show()
	await settle()
	var before: Dictionary=main.world.checkpoint()
	check("restore lesson activates without reset",main.explorer_panel.select_topic("crossing",true))
	await settle()
	check("restored controls strip actual signals bodies and vehicles agree",scene_matches_authority() and controls_fit() and main.explorer_panel.traffic_profile_buttons[1].button_pressed and main.explorer_panel.traffic_strip.state.phase_s==44.0 and main.coordinator.active_scene.get_meta("pedestrian_signals")[0].label.text=="行人 · 清空")
	check("paused restored authority has no wall-time catch-up",main.world.checkpoint()==before)
	await capture("crossing-restored-slow-late")
	main._persistence_enabled=false
	observations={"restored_from_actual_file":true,"world_time_s":main.world.simulation_time_s,"paused":main.world.paused,"time_scale":main.world.time_scale,"jd":main.solar_jd,"solar_rate":main.solar_rate,"saved_profile":main.world.city_traffic.profile,"saved_origin_s":main.world.city_traffic.started_at_s,"current_checkpoint_version":15,"capture_window_settings":view_settings,"samples":samples,"user_save_accessed":false,"isolated_world_dir":isolated_directory,"native_input_tested":false,"unfocusable":get_window().unfocusable,"native_input_disabled":get_viewport().gui_disable_input,"audio_volume_db":main._audio.volume_db,"max_fps":Engine.max_fps,"foreground_fps":ProjectSettings.get_setting("application/run/max_fps"),"worker_pool_threads":ProjectSettings.get_setting("threading/worker_pool/max_threads"),"render_ratio":main._render_ratio}
	await finish()

func finish() -> void:
	var output: FileAccess=FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"native_input_tested":false,"native_ime_tested":false,"performance_test":false},"\t")+"\n")
	output.close()
	print("CITY_CROSSING_EXPERIMENT235_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
