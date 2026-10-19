extends "res://tests/integration/observation_framing_suite.gd"
const Journey = preload("res://scripts/experience/guided_journey.gd")
var observations: Dictionary = {}
var visits: Array[Dictionary] = []

func core_checkpoint() -> Dictionary:
	var value: Dictionary=main.world.checkpoint()
	value.erase("current_scale_id")
	value.erase("local_habitat")
	return value

func guide_fits() -> bool:
	var guide: Node=main.guided_journey
	var rect: Rect2=guide.get_global_rect()
	return rect.end.x<float(get_window().size.x)-8.0 and rect.end.y<float(get_window().size.y)-95.0 and rect.encloses(guide.lesson_button.get_global_rect()) and rect.encloses(guide.restart_button.get_global_rect())

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world229-review="): directory=argument.trim_prefix("--world229-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size=Vector2i(1280,800)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	check("diagnostic cannot consume focus or desktop input",get_window().unfocusable and get_viewport().gui_disable_input)
	get_tree().create_timer(140.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage():
		await finish(); return
	main._audio.volume_db=-80.0
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world.set_time_scale(2.0)
	main.set_solar_rate(0.0)
	main.world_guide.hide()
	await at_time(12.0)
	var authority: int=main.world.get_instance_id()
	var baseline: Dictionary=core_checkpoint()
	var date: float=main.solar_jd
	var guide: Node=main.guided_journey
	guide.restore({"version":1,"step":2,"started":true,"completed":false})
	main._open_guide()
	main.world_guide.journey_button.pressed.emit()
	await settle()
	check("legacy twenty-five-step guide has no world lesson button",guide.route_id=="life" and guide.route.size()==25 and guide.step==2 and not guide.lesson_button.visible)
	guide.pause_button.pressed.emit()
	main._open_guide()
	main.world_guide.world_tour_button.pressed.emit()
	check("world lesson mapping follows existing eight stops",Journey.WORLD_LESSONS.size()==8 and guide.route.size()==8)
	for index: int in range(Journey.WORLD_ROUTE.size()):
		if not await ready_stage():
			await finish(); return
		if index==3: get_window().size=Vector2i(900,650)
		await settle()
		var scale_id: String=Journey.WORLD_ROUTE[index]
		var entry: Dictionary=Journey.WORLD_LESSONS[index]
		check("ready world station %d exposes its actual observation button" % [index+1],guide.visible and guide.route_id=="world" and guide.step==index and guide.pending==-1 and main.world.current_scale_id==scale_id and guide.lesson_button.is_visible_in_tree() and not guide.lesson_button.disabled and guide.lesson_button.text==entry.label)
		check("station %d keeps all guide actions in the viewport" % [index+1],guide_fits())
		var saved: Dictionary=guide.checkpoint().duplicate(true)
		guide.lesson_button.pressed.emit()
		if not await ready_stage():
			await finish(); return
		await settle()
		var actual_topic: String="species_atlas" if index==7 else main.learning_overlay.topic
		if index==7:
			check("final real lesson opens existing species atlas",main.world_guide.visible and main.world_guide.species_atlas.visible and main.world_guide.species_atlas.cards.size()==40 and main.world_guide.resume_button.text=="返回世界漫游")
		else:
			check("real station %d opens its existing scene and topic" % [index+1],not guide.visible and main.world.current_scale_id==entry.scale and main.explorer_panel.visible and main.learning_overlay.topic==entry.topic and main.explorer_panel._topic.id==entry.topic)
			var return_rect: Rect2=main.explorer_panel.journey_return_button.get_global_rect()
			check("topic %d presents a visible return control at the panel top" % [index+1],main.explorer_panel.journey_return_button.is_visible_in_tree() and main.explorer_panel.get_global_rect().encloses(return_rect) and return_rect.position.y<250.0 and main.explorer_panel.scroll.scroll_vertical==0)
		check("lesson %d cannot advance either route or change date and authority" % [index+1],guide.has_lesson_return() and guide.checkpoint()==saved and main.world.get_instance_id()==authority and main.world.simulation_time_s==12.0 and main.world.time_scale==2.0 and main.world.paused and main.solar_jd==date and core_checkpoint()==baseline)
		var json_state: String=JSON.stringify(guide.checkpoint())
		check("lesson %d keeps temporary return state outside optional v1 preferences" % [index+1],guide.checkpoint().size()==6 and not json_state.contains("lesson") and guide.progress_for("life").step==2)
		if index==0:
			var clone: Node=Journey.new()
			clone.configure(main,StyleBoxFlat.new())
			clone.restore(JSON.parse_string(json_state))
			check("restoring preferences does not manufacture a temporary topic return",clone.route_id=="world" and clone.step==0 and not clone.visible and not clone.has_lesson_return() and clone.checkpoint()==saved)
			clone.free()
		visits.append({"step":index+1,"station_scale":scale_id,"lesson_scale":main.world.current_scale_id,"topic":actual_topic,"time_s":main.world.simulation_time_s,"date_jd":main.solar_jd,"window_px":[get_window().size.x,get_window().size.y],"guide_end_y":guide.get_global_rect().end.y})
		await capture("lesson-%02d-%s%s" % [index+1,entry.scale,"-compact" if index==3 else ""])
		if index==7: main.world_guide.resume_button.pressed.emit()
		else: main.explorer_panel.journey_return_button.pressed.emit()
		if not await ready_stage():
			await finish(); return
		await settle()
		check("actual return %d restores only the current ready station" % [index+1],guide.visible and guide.route_id=="world" and guide.step==index and guide.pending==-1 and main.world.current_scale_id==scale_id and not guide.has_lesson_return() and not main.explorer_panel.visible and not main.world_guide.visible and guide.checkpoint()==saved and main.learning_overlay.topic.is_empty())
		check("return %d preserves world date models and legacy progress" % [index+1],main.world.get_instance_id()==authority and core_checkpoint()==baseline and main.solar_jd==date and main.world.simulation_time_s==12.0 and guide.progress_for("life").step==2 and guide_fits())
		if index in [0,3,7]: await capture("return-%02d-%s%s" % [index+1,scale_id,"-compact" if index==3 else ""])
		if index==3:
			get_window().size=Vector2i(1280,800)
			await settle()
		if index<Journey.WORLD_ROUTE.size()-1: guide.advance_button.pressed.emit()
	guide.advance_button.pressed.emit()
	await settle()
	check("explicit finish still affects only world route progress",guide.completed and guide.step==7 and guide.progress_for("life").step==2 and not guide.lesson_button.visible and not guide.has_lesson_return() and main.world.current_scale_id=="earth")
	guide.pause_button.pressed.emit()
	main._open_guide()
	check("existing guide actions and species counts stay unchanged",main.world_guide.route_buttons.size()==86 and main.world_guide.species_atlas.cards.size()==40)
	check("final world date and authority remain paused and unchanged",main.world.get_instance_id()==authority and core_checkpoint()==baseline and main.world.simulation_time_s==12.0 and main.world.time_scale==2.0 and main.world.paused and main.solar_jd==date and main.solar_rate==0.0)
	observations={"visits":visits,"world_route_steps":8,"legacy_route_steps":25,"guide_actions":86,"species_count":40,"world_time_s":main.world.simulation_time_s,"world_time_scale":main.world.time_scale,"date_jd":main.solar_jd,"date_unchanged":main.solar_jd==date,"core_models_unchanged":core_checkpoint()==baseline,"authority_unchanged":main.world.get_instance_id()==authority,"comparison_excludes":["current_scale_id","local_habitat"],"window_screen":get_window().current_screen,"primary_screen":DisplayServer.get_primary_screen(),"screen_count":DisplayServer.get_screen_count(),"native_input_disabled":get_viewport().gui_disable_input}
	await finish()

func finish() -> void:
	var report: Dictionary={"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"full_legacy_25step_replay_tested":false,"existing_lesson_simulations_revalidated":false}
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_TOUR_LESSONS_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
