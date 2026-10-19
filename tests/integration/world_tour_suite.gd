extends "res://tests/integration/observation_framing_suite.gd"
const Journey = preload("res://scripts/experience/guided_journey.gd")
const Species = preload("res://scripts/experience/species_catalog.gd")
var observations: Dictionary = {}
var stops: Array[Dictionary] = []

func core_checkpoint() -> Dictionary:
	var value: Dictionary=main.world.checkpoint()
	value.erase("current_scale_id")
	value.erase("local_habitat") # Current view/LOD follows navigation, not a reset.
	return value

func panel_fits() -> bool:
	var guide: Node=main.guided_journey
	var area: Rect2=guide.get_global_rect()
	return area.end.x<float(get_window().size.x)-8.0 and area.end.y<float(get_window().size.y)-100.0 and area.encloses(guide.advance_button.get_global_rect()) and area.encloses(guide.restart_button.get_global_rect())

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world227-review="): directory=argument.trim_prefix("--world227-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size=Vector2i(1280,800)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	check("diagnostic cannot consume focus or desktop input",get_window().unfocusable and get_viewport().gui_disable_input)
	get_tree().create_timer(110.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage():
		await finish(); return
	main._audio.volume_db=-80.0
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world.set_time_scale(2.0)
	main.world_guide.hide()
	await at_time(12.0)
	var authority: int=main.world.get_instance_id()
	var baseline: Dictionary=core_checkpoint()
	var date: float=main.solar_jd
	var guide: Node=main.guided_journey
	guide.restore({"version":1,"step":2,"started":true,"completed":false})
	check("plain old v1 restores the original route without forcing a panel",guide.route_id=="life" and guide.route.size()==25 and guide.step==2 and guide.started and not guide.visible and not guide.progress_for("world").started)
	var adjacent: bool=true
	for index: int in range(guide.route.size()-1): adjacent=adjacent and main.Catalog.neighbors(guide.route[index]).has(guide.route[index+1])
	check("original twenty-five-step adjacent route remains intact",adjacent)
	main._open_guide()
	await settle()
	var chooser: Node=main.world_guide
	check("actual world guide exposes distinct optional routes",chooser.world_tour_button.is_visible_in_tree() and chooser.journey_button.is_visible_in_tree() and chooser.world_tour_button.text.contains("五分支") and chooser.journey_button.text.contains("第3步"))
	check("existing species and lesson actions are retained",Species.ENTRIES.size()==40 and chooser.species_atlas.cards.size()==40 and chooser.cards.size()==8 and chooser.route_buttons.size()==86)
	await capture("tour-chooser")
	chooser.world_tour_button.pressed.emit()
	for index: int in range(Journey.WORLD_ROUTE.size()):
		if not await ready_stage():
			await finish(); return
		if index==3: get_window().size=Vector2i(900,650)
		await settle()
		var expected: String=Journey.WORLD_ROUTE[index]
		check("real world tour commits ready stop %d %s" % [index+1,expected],guide.visible and guide.route_id=="world" and guide.step==index and guide.pending==-1 and main.world.current_scale_id==expected)
		check("stop %d preserves one paused world date and model state" % [index+1],main.world.get_instance_id()==authority and core_checkpoint()==baseline and main.solar_jd==date and main.world.paused and main.world.time_scale==2.0)
		check("stop %d leaves every guide action on screen" % [index+1],panel_fits())
		var stage: Node=main.coordinator.active_scene
		var point: Vector2=stage.camera.unproject_position(main._orbit_target)
		check("stop %d keeps overview target beside the guide" % [index+1],not stage.camera.is_position_behind(main._orbit_target) and point.x>guide.get_global_rect().end.x+8.0 and point.x<float(get_window().size.x)-8.0 and point.y>80.0 and point.y<float(get_window().size.y)-80.0)
		if expected=="earth": check("Earth entry panel yields to active tour %d" % [index+1],not main.earth_entry_panel.visible)
		stops.append({"step":index+1,"scale":expected,"time_s":main.world.simulation_time_s,"date_jd":main.solar_jd,"guide_end_y":guide.get_global_rect().end.y,"overview_target_px":[point.x,point.y],"window_px":[get_window().size.x,get_window().size.y]})
		await capture("tour-%02d-%s%s" % [index+1,expected,"-compact" if index==3 else ""])
		if expected=="city":
			main.next_button.pressed.emit()
			await settle()
			check("real city people view remains available inside the tour",main._city_people_view and guide.step==index and guide.visible and core_checkpoint()==baseline and main.solar_jd==date)
			await capture("tour-06-city-people")
		if index==3:
			get_window().size=Vector2i(1280,800)
			await settle()
		if index<Journey.WORLD_ROUTE.size()-1: guide.advance_button.pressed.emit()
	guide.advance_button.pressed.emit()
	check("explicit world-tour finish keeps legacy progress independent",guide.completed and guide.step==7 and guide.status.text.contains("路线已结束") and guide.progress_for("life").step==2)
	guide.pause_button.pressed.emit()
	await settle()
	check("closing tour restores Earth entry without changing world",not guide.visible and main.earth_entry_panel.visible and main.world.paused and core_checkpoint()==baseline)
	main._open_guide()
	check("route chooser presents completed world tour and old continuation",chooser.world_tour_button.text.contains("已完成") and chooser.journey_button.text.contains("第3步"))
	chooser.journey_button.pressed.emit()
	await settle()
	check("actual legacy route button resumes original Earth step",guide.route_id=="life" and guide.route.size()==25 and guide.step==2 and guide.visible and not guide.completed and guide.progress_for("world").completed)
	guide.advance_button.pressed.emit()
	if not await ready_stage():
		await finish(); return
	await settle()
	check("original route still enters actual next atmosphere scene",guide.route_id=="life" and guide.step==3 and main.world.current_scale_id=="atmosphere" and core_checkpoint()==baseline and main.solar_jd==date)
	main._remember_view()
	var preferences: Dictionary={"render_ratio":main._render_ratio,"reduced_motion":main._reduced_motion,"muted":true,"guided_journey":guide.checkpoint()}
	for key: String in ["master","environment_volume","music_volume","effects_volume"]: preferences[key]=float(main.soundscape.get(key))
	var store: RefCounted=main.WorldStore.new(directory.path_join("isolated-world"))
	store.load_session()
	var saved: String=store.save_session({"world":main.world.checkpoint(),"observer":{"views":main._views.duplicate(true),"preferences":preferences}})
	var loaded: Dictionary=store.load_session()
	check("real isolated WorldStore saves both route preferences in existing format",saved=="ok" and loaded.status=="ok" and loaded.payload.observer.preferences.guided_journey.step==3 and loaded.payload.observer.preferences.guided_journey.world_tour.completed and loaded.payload.world.simulation_time_s==12.0 and loaded.payload.world.version==14)
	if saved!="ok" or loaded.status!="ok":
		observations={"isolated_save_status":saved,"isolated_load_status":loaded.status}
		await finish(); return
	var clone: Node=Journey.new()
	clone.configure(main,StyleBoxFlat.new())
	clone.restore(loaded.payload.observer.preferences.guided_journey)
	check("serialized optional routes restore independently and stay closed",clone.route_id=="life" and clone.step==3 and clone.progress_for("world").step==7 and clone.progress_for("world").completed and not clone.visible)
	var invalid_world: Dictionary=loaded.payload.observer.preferences.guided_journey.duplicate(true)
	invalid_world.active_route="world"; invalid_world.world_tour.step=9999
	clone.restore(invalid_world)
	check("invalid world-tour preference preserves valid legacy progress",clone.route_id=="life" and clone.step==3 and clone.progress_for("world").step==0 and not clone.progress_for("world").started)
	var intact: Dictionary=clone.checkpoint()
	clone.restore({"version":1,"step":-1,"started":true,"completed":false})
	check("invalid root preference cannot erase either valid route",clone.checkpoint()==intact)
	clone.free()
	guide.pause_button.pressed.emit()
	main._open_guide()
	chooser.world_tour_button.pressed.emit()
	await settle()
	check("reopening finished world route keeps original view until replay",guide.route_id=="world" and guide.step==7 and guide.completed and main.world.current_scale_id=="atmosphere" and guide.progress_for("life").step==3)
	guide.restart_button.pressed.emit()
	if not await ready_stage():
		await finish(); return
	await settle()
	check("real replay resets only world-tour progress",guide.route_id=="world" and guide.step==0 and not guide.completed and guide.progress_for("life").step==3 and main.world.current_scale_id=="solar_system" and core_checkpoint()==baseline and main.solar_jd==date)
	guide.advance_button.pressed.emit()
	var cancelling: bool=main.coordinator.is_busy() and guide.pending==1
	guide.pause_button.pressed.emit()
	if not await ready_stage():
		await finish(); return
	await settle()
	check("cancelling a real pending tour does not commit the next stop",cancelling and guide.pending==-1 and guide.step==0 and not guide.visible and main.world.current_scale_id=="solar_system" and core_checkpoint()==baseline and main.solar_jd==date)
	observations={"stops":stops,"world_route_steps":Journey.WORLD_ROUTE.size(),"legacy_route_steps":25,"species_count":Species.ENTRIES.size(),"guide_actions":chooser.route_buttons.size(),"world_time_s":main.world.simulation_time_s,"world_time_scale":main.world.time_scale,"date_unchanged":main.solar_jd==date,"authority_unchanged":main.world.get_instance_id()==authority,"core_models_unchanged":core_checkpoint()==baseline,"comparison_excludes":["current_scale_id","local_habitat"],"isolated_save_status":saved,"isolated_load_status":loaded.status,"window_screen":get_window().current_screen,"screen_count":DisplayServer.get_screen_count(),"primary_screen":DisplayServer.get_primary_screen(),"native_input_disabled":get_viewport().gui_disable_input}
	await finish()

func finish() -> void:
	var report: Dictionary={"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"old_application_restore_tested":false,"full_legacy_25step_replay_tested":false}
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_TOUR_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
