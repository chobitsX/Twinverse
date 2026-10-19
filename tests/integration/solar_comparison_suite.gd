extends "res://tests/integration/observation_framing_suite.gd"
var observations: Dictionary = {}
var samples: Array[Dictionary] = []
var selected: Array[int] = []

func core_checkpoint() -> Dictionary:
	var value: Dictionary=main.world.checkpoint()
	value.erase("current_scale_id"); value.erase("local_habitat")
	return value

func body_positions() -> Array[Vector3]:
	var values: Array[Vector3]=[]
	for body: Dictionary in main.coordinator.active_scene.get_meta("solar_bodies"): values.append(body.node.position)
	return values

func body_ids() -> Array[int]:
	var values: Array[int]=[]
	for body: Dictionary in main.coordinator.active_scene.get_meta("solar_bodies"): values.append(body.node.get_instance_id())
	return values

func sample_table(label: String) -> void:
	var table: Node=main.explorer_panel.solar_comparison
	var correct: bool=table.entries.size()==8 and table.date_jd==main.solar_jd
	for index: int in range(table.entries.size()):
		var entry: Dictionary=table.entries[index]
		correct=correct and entry.index==index and entry.name==Ephemeris.NAMES[index] and entry.jd==main.solar_jd and entry.distance_source=="de440" and entry.speed_source=="de440"
		correct=correct and absf(float(table.distances[index].text)-Ephemeris.position_au(index,main.solar_jd).length())<.000501 and absf(float(table.speeds[index].text)-Ephemeris.speed_km_s(index,main.solar_jd))<.00501
	check(label+" eight displayed rows match the actual date and existing data",correct)
	samples.append({"view":label,"jd":table.date_jd,"true_distance":main.solar_true_distance,"entries":table.entries.duplicate(true),"rows_valid":correct})

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world230-review="): directory=argument.trim_prefix("--world230-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size=Vector2i(1280,800)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	check("diagnostic cannot consume desktop focus or input",get_window().unfocusable and get_viewport().gui_disable_input)
	get_tree().create_timer(110.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage():
		await finish(); return
	main._audio.volume_db=-80.0
	main._reduced_motion=true
	main.world.set_paused(true); main.world.set_time_scale(2.0)
	main.set_solar_rate(1.0)
	main.world_guide.hide()
	await at_time(12.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	await settle()
	var authority: int=main.world.get_instance_id()
	var baseline: Dictionary=core_checkpoint()
	var date: float=main.solar_jd
	main._open_guide()
	main.world_guide.world_tour_button.pressed.emit()
	if not await ready_stage():
		await finish(); return
	await settle()
	var guide: Node=main.guided_journey
	guide.lesson_button.pressed.emit()
	await settle()
	var panel: Node=main.explorer_panel
	var table: Node=panel.solar_comparison
	var saved: Dictionary=guide.checkpoint().duplicate(true)
	var points: Array[Vector3]=body_positions()
	var identities: Array[int]=body_ids()
	check("real Mercury lesson exposes comparison beside the existing return",main.learning_overlay.topic=="mercury_orbit" and panel.solar_compare_button.is_visible_in_tree() and panel.journey_return_button.is_visible_in_tree())
	panel.solar_compare_button.pressed.emit()
	await settle()
	check("comparison opens without resetting date rate models or route",table.is_visible_in_tree() and main.learning_overlay.topic.is_empty() and main.solar_jd==date and main.solar_rate==1.0 and body_positions()==points and guide.checkpoint()==saved)
	sample_table("original date")
	var clip: Rect2=panel.scroll.get_global_rect()
	if panel.scroll.get_v_scroll_bar().visible: clip.size.x-=panel.scroll.get_v_scroll_bar().size.x
	var columns_fit: bool=true
	for index: int in range(8):
		for cell: Label in [table.distances[index],table.speeds[index]]:
			var rect: Rect2=cell.get_global_rect()
			columns_fit=columns_fit and rect.position.x>=clip.position.x+1.0 and rect.end.x<=clip.end.x-1.0
	check("actual numerical columns fit the scroll viewport beside its bar",columns_fit)
	check("table identifies center conventions and real uncompressed units",table.source_note.text.contains("地月共同重心") and table.source_note.text.contains("行星与卫星共同重心") and table.source_note.text.contains("数值不随画面距离压缩改变"))
	await capture("compare-overview")
	for index: int in range(8):
		table.body_buttons[index].pressed.emit()
		await settle()
		var body: Node3D=main.coordinator.active_scene.get_meta("solar_bodies")[index].node
		check("real comparison row %d selects the same actual planet" % index,main.solar_follow==index and main.solar_orbit_focus==-1 and main._orbit_target.distance_to(body.position)<.001 and body_ids()==identities and main.solar_jd==date and main.solar_rate==1.0)
		selected.append(index)
		if index in [0,5]: await capture("compare-%s" % ["mercury" if index==0 else "saturn"])
	table.forward_button.pressed.emit()
	await settle()
	sample_table("explicit next day")
	check("explicit next day updates models without running world time",main.solar_jd==date+1.0 and main.solar_rate==1.0 and body_positions()!=points and body_ids()==identities and main.world.simulation_time_s==12.0)
	await capture("compare-next-date")
	table.back_button.pressed.emit()
	await settle()
	check("explicit previous day restores the original dated planet positions",main.solar_jd==date and body_positions()==points and main.solar_rate==1.0)
	var original_values: Array=table.entries.duplicate(true)
	main.set_solar_distance(true)
	await settle()
	sample_table("true display distance")
	check("display distance mode cannot scale the real numerical table",table.entries==original_values and main.solar_jd==date and main.solar_rate==1.0)
	await capture("compare-true-distance")
	table.overview_button.pressed.emit()
	await settle()
	check("actual overview control releases planet follow and keeps data date",main.solar_follow==-1 and main.solar_orbit_focus==-1 and main.solar_jd==date and table.entries==original_values)
	get_window().size=Vector2i(900,650)
	await settle()
	panel.scroll.scroll_vertical=0
	await settle()
	check("compact top keeps comparison date actions and tour return accessible",panel.get_global_rect().encloses(table.back_button.get_global_rect()) and panel.get_global_rect().encloses(table.forward_button.get_global_rect()) and panel.get_global_rect().encloses(panel.journey_return_button.get_global_rect()))
	await capture("compare-compact-top")
	panel.scroll.scroll_vertical=maxi(0,int(table.body_buttons[7].get_global_rect().end.y-panel.get_global_rect().end.y+16.0))
	await settle()
	check("compact scroll reveals all final-row data and the real link",panel.get_global_rect().encloses(table.body_buttons[7].get_global_rect()) and panel.get_global_rect().encloses(table.distances[7].get_global_rect()) and panel.get_global_rect().encloses(table.speeds[7].get_global_rect()))
	table.body_buttons[7].pressed.emit()
	await settle()
	check("visible compact Neptune link selects the same planet",main.solar_follow==7 and body_ids()==identities and main.solar_jd==date)
	await capture("compare-neptune-compact")
	get_window().size=Vector2i(1280,800)
	main.set_solar_date(Ephemeris.START_JD)
	await settle()
	sample_table("supported start date")
	check("supported start disables previous day while keeping next available",table.back_button.disabled and not table.forward_button.disabled)
	main.set_solar_date(Ephemeris.END_JD)
	await settle()
	sample_table("supported end date")
	check("supported end disables next day while keeping previous available",table.forward_button.disabled and not table.back_button.disabled)
	main.set_solar_date(date); main.set_solar_distance(false)
	panel.scroll.scroll_vertical=0
	await settle()
	panel.solar_compare_button.pressed.emit()
	await settle()
	check("actual collapse restores existing solar controls and keeps date",not table.visible and panel.size_compare_button.visible and main.solar_jd==date and main.solar_rate==1.0)
	panel.solar_compare_button.pressed.emit()
	await settle()
	panel.select_topic("mercury_orbit")
	await settle()
	check("selecting the existing lesson closes the numerical table",not table.visible and main.learning_overlay.topic=="mercury_orbit" and main.solar_jd==date)
	panel.solar_compare_button.pressed.emit()
	await settle()
	panel.journey_return_button.pressed.emit()
	await settle()
	check("existing tour return still restores the same ready station",guide.visible and guide.step==0 and guide.checkpoint()==saved and not panel.visible and not table.is_visible_in_tree() and main.learning_overlay.topic.is_empty())
	await capture("compare-tour-return")
	guide.pause_button.pressed.emit()
	if not await arrive("earth"):
		await finish(); return
	await settle()
	check("leaving solar system clears the temporary table display",not table.visible)
	main._open_guide()
	check("guide species and optional preference shape are unchanged",main.world_guide.route_buttons.size()==86 and main.world_guide.species_atlas.cards.size()==40 and guide.checkpoint().size()==6)
	check("final authority core date world time and rates are unchanged",main.world.get_instance_id()==authority and core_checkpoint()==baseline and main.world.simulation_time_s==12.0 and main.world.time_scale==2.0 and main.world.paused and main.solar_jd==date and main.solar_rate==1.0)
	observations={"samples":samples,"selected_rows":selected,"guide_actions":86,"species_count":40,"world_time_s":main.world.simulation_time_s,"world_time_scale":main.world.time_scale,"date_jd":main.solar_jd,"solar_rate":main.solar_rate,"date_unchanged_at_finish":main.solar_jd==date,"core_models_unchanged":core_checkpoint()==baseline,"authority_unchanged":main.world.get_instance_id()==authority,"comparison_excludes":["current_scale_id","local_habitat"],"window_screen":get_window().current_screen,"primary_screen":DisplayServer.get_primary_screen(),"screen_count":DisplayServer.get_screen_count(),"native_input_disabled":get_viewport().gui_disable_input}
	await finish()

func finish() -> void:
	var report: Dictionary={"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"ephemeris_accuracy_revalidated":false,"missing_cache_runtime_revalidated":false}
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SOLAR_COMPARISON_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
