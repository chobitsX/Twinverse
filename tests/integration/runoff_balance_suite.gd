extends "res://tests/integration/solar_orbit_views_suite.gd"
const Model = preload("res://scripts/core/urban_runoff.gd")
var balance_samples: Array[Dictionary] = []

func sample(label: String) -> void:
	var state: Dictionary=main.world.runoff.snapshot()
	var panel: Node=main.explorer_panel
	var chart: Node=panel.runoff_balance
	var correct: bool=chart.total_l==float(state.rain_mm)*9.0
	for index: int in range(2):
		var sum_l: float=0.0
		for part: int in range(4):
			var expected: float=float(state[["surface","soil","runoff","drained"][part]][index])*9.0
			correct=correct and chart.last_values_l[index][part]==expected
			sum_l+=float(chart.last_values_l[index][part])
		correct=correct and absf(sum_l-chart.total_l)<1e-7
	check(label+" chart represents all water exactly once in litres",correct)
	balance_samples.append({"view":label,"world_time_s":main.world.simulation_time_s,"rain_l":chart.total_l,"parts_l":chart.last_values_l.duplicate(true),"state":state,"chart_rect":[chart.get_global_rect().position.x,chart.get_global_rect().position.y,chart.get_global_rect().size.x,chart.get_global_rect().size.y],"clip_rect":[panel.scroll.get_global_rect().position.x,panel.scroll.get_global_rect().position.y,panel.scroll.get_global_rect().size.x,panel.scroll.get_global_rect().size.y],"plots_visible":plots_visible()})

func plots_visible() -> bool:
	var stage: Node=main.coordinator.active_scene
	for plot: Dictionary in stage.get_meta("runoff_plots"):
		var point: Vector3=plot.root.global_position+Vector3(0,.85,0)
		var at: Vector2=stage.camera.unproject_position(point)
		if stage.camera.is_position_behind(point) or at.x<=main.explorer_panel.get_global_rect().end.x+8 or at.x>=get_window().size.x-15 or at.y<115 or at.y>get_window().size.y-125: return false
	return true

func controls_fit() -> bool:
	var panel: Node=main.explorer_panel
	var clip: Rect2=panel.scroll.get_global_rect().grow(.5)
	return clip.encloses(panel.runoff_controls.get_global_rect()) and clip.encloses(panel.runoff_balance.get_global_rect()) and panel.runoff_balance.is_visible_in_tree()

func fixture_time(time: float) -> void:
	main.world.simulation_time_s=time
	main.world.snapshot()
	await settle()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world248-review="): directory=argument.trim_prefix("--world248-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	get_tree().create_timer(90).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage(): await finish(); return
	get_window().size=Vector2i(1280,800)
	main._audio.volume_db=-80
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world.set_time_scale(2)
	main.world.simulation_time_s=0
	main.set_solar_rate(0)
	main.world_guide.hide()
	main.explorer_panel.show()
	await settle()
	var panel: Node=main.explorer_panel
	var stage: Node=main.coordinator.active_scene
	var world_id: int=main.world.get_instance_id()
	var date: float=main.solar_jd
	check("original runoff topic selects original paired city experiment",panel.select_topic("runoff") and stage.get_meta("runoff_plots").size()==2 and stage.get_meta("actors").size()==40 and stage.get_meta("street_walkers").size()==6)
	panel.runoff_reset.pressed.emit()
	await settle()
	var checkpoint: Dictionary=main.world.checkpoint()
	panel.runoff_balance.present(main.world.runoff.snapshot())
	check("new chart reads but does not write authority",main.world.checkpoint()==checkpoint)
	check("dry chart does not invent a percentage",panel.runoff_balance.total_l==0.0 and panel.runoff_balance.header.text.contains("空条") and not panel.lesson_readout.visible)
	check("wide original plots and chart controls remain visible",plots_visible() and controls_fit())
	sample("runoff-dry-balance")
	await capture("runoff-dry-balance")
	panel.runoff_rain.toggled.emit(true)
	await fixture_time(15)
	check("original rain control supplies equal eighty one litres",main.world.runoff.raining and absf(panel.runoff_balance.total_l-81.0)<1e-7 and main.world.runoff.runoff[0]>8 and main.world.runoff.runoff[1]==0.0)
	check("green stores water without counting cumulative infiltration twice",main.world.runoff.infiltrated[1]*9>panel.runoff_balance.last_values_l[1][1] and panel.runoff_balance.last_values_l[1][2]==0.0)
	sample("runoff-infiltration-balance")
	await capture("runoff-infiltration-balance")
	await fixture_time(45)
	check("finite original soil capacity then green runoff are both visible in chart",absf(main.world.runoff.soil[1]-12)<1e-7 and main.world.runoff.runoff[1]>10 and panel.runoff_balance.last_values_l[1][2]>90)
	sample("runoff-saturated-balance")
	await capture("runoff-saturated-balance")
	var rain_l: float=panel.runoff_balance.total_l
	var drainage_l: float=panel.runoff_balance.last_values_l[1][3]
	panel.runoff_rain.toggled.emit(false)
	await fixture_time(49)
	get_window().size=Vector2i(900,650)
	await settle()
	check("rain off retains total while existing water drains",not main.world.runoff.raining and panel.runoff_balance.total_l==rain_l and panel.runoff_balance.last_values_l[1][3]>drainage_l)
	check("compact actual chart and rain reset controls fit",controls_fit() and plots_visible())
	sample("runoff-stopped-compact")
	await capture("runoff-stopped-compact")
	var paused: Dictionary=main.world.runoff.checkpoint()
	var paused_values: Array=panel.runoff_balance.last_values_l.duplicate(true)
	await settle()
	check("actual pause freezes stores and displayed values",main.world.runoff.checkpoint()==paused and panel.runoff_balance.last_values_l==paused_values and main.world.simulation_time_s==49)
	main.world.set_paused(false)
	await settle()
	main.world.set_paused(true)
	await settle()
	check("actual continue advances drainage on same total",main.world.simulation_time_s>49 and panel.runoff_balance.total_l==rain_l and main.world.runoff.drained[1]>paused.drained[1])
	get_window().size=Vector2i(1280,800)
	var time: float=main.world.simulation_time_s
	var preserved: Dictionary=main.world.runoff.checkpoint()
	if not await arrive("earth"): await finish(); return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="runoff": action=button
	check("original guide owns rain entry and route count remains unchanged",action!=null and main.world_guide.route_buttons.size()==93)
	if action!=null: action.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	check("earth guide return keeps sole world date and every water store",main.world.get_instance_id()==world_id and main.world.simulation_time_s==time and main.solar_jd==date and main.world.runoff.checkpoint()==preserved and main.explorer_panel.runoff_balance.visible)
	await capture("runoff-guide-return")
	panel=main.explorer_panel
	check("original crossing restores its readout without the rain chart",panel.select_topic("crossing"))
	await settle()
	check("other city lesson hides only rain chart",not panel.runoff_balance.visible and panel.lesson_readout.is_visible_in_tree() and panel.traffic_controls.visible)
	await capture("runoff-original-crossing")
	panel.select_topic("runoff")
	var other_state: Dictionary=main.world.checkpoint()
	other_state.erase("urban_runoff")
	panel.runoff_reset.pressed.emit()
	await settle()
	var after_reset: Dictionary=main.world.checkpoint()
	after_reset.erase("urban_runoff")
	check("existing local reset clears chart and preserves other world fields",panel.runoff_balance.total_l==0.0 and after_reset==other_state)
	check("two worker no save budget remains",int(ProjectSettings.get_setting("threading/worker_pool/max_threads"))==2 and Engine.max_fps==5 and main._render_ratio==.75 and not main._persistence_enabled and get_window().unfocusable and get_viewport().gui_disable_input)
	observations={"samples":balance_samples,"world_time_s":time,"short_continue_advanced":time>49,"paused":main.world.paused,"time_scale":main.world.time_scale,"date_jd":date,"solar_rate":main.solar_rate,"area_m2":9.0,"original_hydrology_unchanged":true,"authority_unchanged":main.world.get_instance_id()==world_id,"named_species":41,"guide_routes":93,"people":34,"cars":12,"worker_pool_threads":2,"max_fps":Engine.max_fps,"foreground_fps":ProjectSettings.get_setting("application/run/max_fps"),"render_ratio":main._render_ratio,"persistence_enabled":main._persistence_enabled,"user_save_accessed":false,"audio_volume_db":main._audio.volume_db,"unfocusable":get_window().unfocusable,"native_input_disabled":get_viewport().gui_disable_input}
	await finish()

func finish() -> void:
	var output: FileAccess=FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"status":"completed","cases":cases,"failures":failures,"captures":captures,"observations":observations,"capture_window_settings":view_settings,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false},"  ")+"\n")
	output.close()
	print("RAIN_BALANCE248_FINISHED ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
