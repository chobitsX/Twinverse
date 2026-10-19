extends "res://tests/integration/spatial_experiments_suite.gd"
## Two local teaching experiments and their real Earth/mesh/input context.
var arrival_failed: bool = false

func ready_stage() -> bool:
	var timeout_ms: int = 32000 if main.coordinator._target_id in ["pacific","reef","school","fish"] else 12000
	var deadline: int = Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground:
			if DisplayServer.get_name()=="headless" or DisplayServer.window_can_draw(): return true
	arrival_failed=true
	print("SPATIAL_ECOLOGY_UNAVAILABLE ",JSON.stringify({"scale":main.world.current_scale_id,"target":main.coordinator._target_id,"phase":main.coordinator.phase,"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw(),"loading":main.coordinator.loading_status(),"recovery":main.coordinator.recovery_state(),"first_response_us":main.coordinator._first_response_us,"message":main.message_label.text}))
	check("stage ready",false)
	return false

func press(code: Key = KEY_ENTER) -> void:
	for down: bool in [true,false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode=code;event.pressed=down;dispatch(event)

func enter_region(id: String) -> bool:
	if main.world.current_scale_id!="earth" and not await arrive("earth"): return false
	main.explorer_panel.hide();main.info_panel.hide()
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.earth_entry_panel
	var site: Dictionary = panel.Sites.for_scale(id)
	stage.set_pose(panel.Sites.normal(site.lat,site.lon)*9.6,Vector3.ZERO)
	main._orbit_target=Vector3.ZERO
	panel.clear_selection()
	await settle()
	panel.refresh_points()
	check(id+" has a visible Earth landmark",panel.points.has(id))
	if not panel.points.has(id): return false
	click(panel.points[id].pixel)
	check(id+" actual landmark selects without leaving Earth",panel.selected==id and not main.coordinator.is_busy())
	for step: int in range(4):
		magnify(2.0)
		if main.coordinator.is_busy(): break
	check(id+" gesture entry requests the selected region",main.coordinator.is_busy() and main.coordinator._target_id==id)
	if not await ready_stage(): return false
	check(id+" region arrives with its Earth observation parent",main.world.current_scale_id==id and main.observation_parent(id)=="earth")
	return main.world.current_scale_id==id

func stock() -> Dictionary:
	var state: Dictionary = main.world.deadwood.snapshot()
	return {"wood":state.wood,"organic":state.organic,"respired":state.respired}

func woodland() -> void:
	if not await enter_region("woodland"): return
	focus_topic("deadwood")
	main.explorer_panel.hide()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var plots: Array = stage.get_meta("deadwood_plots")
	var point: Vector2 = geometry_point(plots[0].root,"deadwood")
	check("actual left log or tray identifies the deadwood experiment",point.x>=0)
	if point.x<0: return
	click(point)
	await settle()
	check("wood click keeps the actual local experiment and opens no menu",main.learning_overlay.topic=="deadwood" and not main.explorer_panel.visible)
	check("existing browse gate and new dial coexist in one scene",stage.get_meta("spatial_controls").size()==2 and stage.has_meta("browse_latch"))
	await capture("woodland-moist")
	point=control_point("deadwood_dial","deadwood","deadwood_condition")
	if point.x<0: return
	var before: Dictionary = stock()
	var pose: Transform3D = stage.camera.transform
	var time: float = main.world.simulation_time_s
	click(point)
	await settle()
	check("physical condition dial switches the left sample to waterlogged",main.world.deadwood.left_mode==2 and plots[0].water.visible and not plots[1].water.visible)
	check("condition change preserves camera carbon stocks and world time",stage.camera.transform.is_equal_approx(pose) and stock()==before and main.world.simulation_time_s==time)
	check("dial readout and pointer reflect the same condition",stage.get_meta("deadwood_dial").caption.text.contains("浸水缺氧") and is_equal_approx(stage.get_meta("deadwood_dial").pointer.rotation.y,TAU/3.))
	await capture("woodland-waterlogged")
	click(point);click(point,true)
	await settle()
	check("complete dial double click changes condition once to dry",main.world.deadwood.left_mode==0 and not plots[0].water.visible)
	await capture("woodland-dry")
	press()
	await settle()
	check("Enter on the actual dial returns the same sample to moist",main.world.deadwood.left_mode==1 and not main.explorer_panel.visible)
	main.world.set_time_scale(4.0);main.world.set_paused(false)
	await get_tree().create_timer(2.1).timeout
	main.world.set_paused(true);main.world.set_time_scale(1.0)
	await settle()
	var state: Dictionary = main.world.deadwood.snapshot()
	check("ordinary world time decomposes moist wood and leaves dry reference unchanged",state.wood[0]<99.0 and state.wood[1]==100.0 and state.organic[0]>0 and state.respired[0]>0)
	check("visible carbon bars use the original closed accounting",absf(state.wood[0]+state.organic[0]+state.respired[0]-100.)<.000001 and plots[0].bars[1].visible and plots[0].bars[2].visible)
	main.clean_observation.set_active(true)
	point=control_point("deadwood_dial","deadwood","deadwood_condition")
	if point.x>=0:
		click(point)
		check("actual dial works while interface annotations are hidden",main.world.deadwood.left_mode==2 and main.clean_observation.active)
	main.clean_observation.set_active(false)
	main.world_guide.show();press()
	check("guide modal blocks the selected dial",main.world.deadwood.left_mode==2)
	main.world_guide.hide()
	main.world.set_foreground(false);press()
	check("background blocks the selected dial",main.world.deadwood.left_mode==2)
	main.world.set_foreground(true)
	var retained: Dictionary = main.world.deadwood.snapshot()
	press(KEY_UP)
	if not await ready_stage():return
	check("woodland returns to its actual Earth context",main.world.current_scale_id=="earth")
	if not await enter_region("woodland"):return
	check("re-entered logs retain carbon and condition",main.world.deadwood.snapshot()==retained)
	main.observe_scale("earth")
	await ready_stage()

func coral() -> void:
	if not await enter_region("reef"): return
	main.explorer_panel.hide()
	focus_topic("coral_symbiosis")
	await settle()
	var stage: Node = main.coordinator.active_scene
	var point: Vector2 = geometry_point(stage.get_meta("coral_root"),"coral_symbiosis")
	check("actual colony geometry identifies its symbiosis lesson",point.x>=0)
	if point.x<0: return
	click(point)
	await settle()
	check("colony click frames the same living reference without a menu",main.learning_overlay.topic=="coral_symbiosis" and not main.explorer_panel.visible)
	point=control_point("coral_heat_switch","coral_symbiosis","coral_heat")
	if point.x<0: return
	var before: Dictionary = main.world.symbiosis.snapshot()
	var fish: Dictionary = main.world.science.snapshot()
	var pose: Transform3D = stage.camera.transform
	var time: float = main.world.simulation_time_s
	click(point)
	await settle()
	check("physical coral switch operates the sole local heat state",main.world.symbiosis.heated!=before.heated)
	check("heat switch preserves camera stocks fish state and world clock",stage.camera.transform.is_equal_approx(pose) and main.world.symbiosis.symbiont==before.symbiont and main.world.simulation_time_s==time and main.world.science.snapshot()==fish)
	await capture("coral-heat-on")
	main.world.set_time_scale(4.0);main.world.set_paused(false)
	await get_tree().create_timer(2.1).timeout
	main.world.set_paused(true);main.world.set_time_scale(1.0)
	await settle()
	check("world time drives existing stress and same colony tissue colors",main.world.symbiosis.stress>0 and main.world.symbiosis.symbiont<before.symbiont and is_equal_approx(stage.get_meta("coral_tissue_materials")[0].get_shader_parameter("symbiont_proxy"),main.world.symbiosis.symbiont))
	point=control_point("coral_heat_switch","coral_symbiosis","coral_heat")
	if point.x<0: return
	click(point);click(point,true)
	await settle()
	check("complete coral switch double click relieves heat only once",not main.world.symbiosis.heated)
	check("teaching apparatus explicitly describes its author assumption",stage.get_meta("coral_heat_switch").caption.text.contains("作者代理") and stage.get_meta("coral_heat_switch").caption.text.contains("非真实加热"))
	await capture("coral-heat-relieved")
	var retained: Dictionary = main.world.symbiosis.snapshot()
	var targets: Array = stage.get_meta("coral_targets")
	var slot: int = main.content_targets(false).find(targets[1])
	check("attached polyp keeps its existing observation slot",slot>=0)
	var hero: Node3D = stage.get_meta("coral_root").find_child("HeroPolyp",true,false)
	point=Vector2(-1,-1)
	for step: int in range(3):
		magnify(1.4)
		await settle()
		point=geometry_point(hero,"coral_polyp")
		if point.x>=0:break
	if point.x<0:
		var observed: Array = []
		for node: Node in hero.find_children("*","MeshInstance3D",true,false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			var at: Vector3 = mesh.global_transform*mesh.get_aabb().get_center()
			var pixel: Vector2 = stage.camera.unproject_position(at)
			observed.append({"mesh":mesh.name,"pixel":pixel,"behind":stage.camera.is_position_behind(at),"hit_topic":main.object_pointer.pick(pixel).get("topic","")})
		print("POLYP_APPROACH_OBSERVATION ",JSON.stringify({"slot":slot,"follow":main._content_follow,"camera":stage.camera.position,"target":main._orbit_target,"meshes":observed}))
		await capture("colony-approached")
	check("pinching toward the same colony exposes its attached polyp mesh",point.x>=0)
	if point.x>=0:
		click(point)
		await settle()
		check("polyp click stays on the same colony and anatomical lesson",main.learning_overlay.topic=="coral_polyp" and main._direct_content.node==targets[1].node and main.world.symbiosis.snapshot()==retained)
		check("polyp close view keeps submillimeter clipping and hides apparatus label",stage.camera.near<.001 and not stage.get_meta("coral_heat_switch").caption.visible)
		await capture("attached-polyp")
		click(point,true)
		check("polyp double click opens the current anatomical explanation",main.explorer_panel.visible and main.explorer_panel._topic.get("id","")=="coral_polyp")
	main.explorer_panel.hide()
	press(KEY_UP)
	if await ready_stage(): check("reef returns to its selected Earth branch context",main.world.current_scale_id=="earth" and main.world.symbiosis.snapshot()==retained)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world255-review="): directory=argument.trim_prefix("--world255-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true;get_viewport().gui_disable_input=true;get_window().size=Vector2i(1280,800)
	get_tree().create_timer(55).timeout.connect(func() -> void:get_tree().quit(2))
	main=Experience.instantiate();add_child(main)
	if DisplayServer.get_name()!="headless":main._measurement_screen=get_window().current_screen
	if is_instance_valid(main._audio):main._audio.volume_db=-80
	main._reduced_motion=true;main.world.set_paused(true);main.set_solar_rate(0)
	main.world_guide.hide();main.guided_journey.hide();main.explorer_panel.hide()
	if not await ready_stage():await finish();return
	original_id=main.world.get_instance_id();original_jd=main.solar_jd
	if not "--world255-coral-only" in OS.get_cmdline_user_args():await woodland()
	if not arrival_failed:await coral()
	check("experiments retain sole world date pause and target fish identity",main.world.get_instance_id()==original_id and main.solar_jd==original_jd and main.world.paused and main.world.snapshot().target_fish_id==main.WorldState.TARGET_FISH_ID)
	await finish()

func finish() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"debug":OS.is_debug_build(),"headless":DisplayServer.get_name()=="headless","renderer":RenderingServer.get_current_rendering_driver_name(),"viewport_input_routed":true,"native_os_gestures_tested":false,"performance_test":false,"world_id":main.world.get_instance_id(),"original_world_id":original_id,"date_jd":main.solar_jd,"original_date_jd":original_jd,"world_time_s":main.world.simulation_time_s,"paused":main.world.paused,"no_save":not main._persistence_enabled},"\t"))
	print("SPATIAL_ECOLOGY_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
