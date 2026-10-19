extends "res://tests/integration/solar_orbit_suite.gd"
## Bounded Metal view of the actual DE440 planet and separately labeled teaching ellipse.

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world179-review="): directory=argument.trim_prefix("--world179-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(150.).timeout.connect(func() -> void:
		push_error("DE440 diagnostic exceeded its bounded runtime")
		get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	get_window().size=Vector2i(1280,800)
	if not await ready_stage(): await finish(); return
	# macOS may briefly report a new Metal window as non-drawable after the
	# first frame. Wait for a short stable interval before requesting a scale.
	var stable_since: int=Time.get_ticks_msec()
	var startup_deadline: int=stable_since+10000
	while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<startup_deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw():
			stable_since=Time.get_ticks_msec()
	if Time.get_ticks_msec()-stable_since<2000:
		check("initial Metal window remains drawable",false)
		await finish()
		return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.set_solar_rate(0.)
	main.world_guide.hide()
	main.explorer_panel.show()
	if main.world.current_scale_id!="solar_system" and not await arrive("solar_system"):
		await finish(); return
	await settle()
	var stage: Node=main.coordinator.active_scene
	var bodies: Array=stage.get_meta("solar_bodies")
	var world_time: float=main.world.simulation_time_s
	check("eight real planet objects share one date",bodies.size()==8 and main.solar_jd==Ephemeris.DEFAULT_JD)
	check("DE440 data is the active position source",Ephemeris.position_source()=="DE440离线行星位置" and str(stage.get_meta("scientific_label")).contains("DE440"))
	var science: Dictionary=ScienceReference.describe("solar_system")
	check("science panel separates DE440 and approximate ellipse",str(science.basis).contains("DE440") and str(science.basis).contains("Table 1") and str(science.limit).contains("橙线"))
	var all_positions: bool=true
	for index: int in range(8):
		all_positions=all_positions and bodies[index].node.position.distance_to(Ephemeris.display_position(index,main.solar_jd,false))<0.00001
	check("rendered eight bodies follow cached positions",all_positions)
	var speeds_valid: bool=true
	for index: int in range(8):
		speeds_valid=speeds_valid and is_finite(Ephemeris.speed_km_s(index,main.solar_jd))
	check("eight speeds use the same supported DE440 date",speeds_valid and Ephemeris.speed_km_s(0,main.solar_jd)>Ephemeris.speed_km_s(2,main.solar_jd) and Ephemeris.speed_km_s(2,main.solar_jd)>Ephemeris.speed_km_s(5,main.solar_jd))
	check("held-out Earth and Saturn speeds match direct SPK samples",absf(Ephemeris.speed_km_s(2,2461299.814159)-29.6234011)<.02 and absf(Ephemeris.speed_km_s(5,2451545.12345)-10.0319395)<.02)
	await capture("de440-solar-overview")
	main.explorer_panel.body_picker.item_selected.emit(6)
	await settle()
	main.explorer_panel.orbit_view_button.pressed.emit()
	await settle()
	var aid: MultiMeshInstance3D=stage.world_root.get_node("SelectedOrbitEqualTime")
	check("Saturn orbit remains observable with teaching aid",main.solar_orbit_focus==5 and aid.visible and aid.multimesh.instance_count==12)
	check("observer text distinguishes planet and ellipse",main.explorer_panel.body_text.text.contains("DE440") and main.explorer_panel.body_text.text.contains("近似椭圆"))
	check("selected planet shows same-date geometric speed and barycenter boundary",main.explorer_panel.body_text.text.contains("%.2f km/s" % Ephemeris.speed_km_s(5,main.solar_jd)) and main.explorer_panel.orbit_source_hint.text.contains("%.2f km/s" % Ephemeris.speed_km_s(5,main.solar_jd)) and main.explorer_panel.orbit_source_hint.text.contains("系统质心") and main.explorer_panel.source_text.text.contains("TDB日期的导数"))
	await capture("de440-saturn-orbit")
	main.set_solar_date(2418673.34)
	await settle()
	var real: Vector3=Ephemeris.position_au(5,main.solar_jd)
	var reference: Vector3=Vector3(8.522303558140269,3.7617637565466606,-0.4043932032233415)
	var old: Vector3=Ephemeris.approximate_position_au(5,main.solar_jd)
	check("historic Saturn matches frozen DE440 vector",real.distance_to(reference)<0.00001 and real.distance_to(old)>0.02)
	check("historic body follows cache without changing world time",bodies[5].node.position.distance_to(Ephemeris.display_position(5,main.solar_jd,false))<0.00001 and main.world.simulation_time_s==world_time)
	check("historic date refreshes the selected speed without advancing world time",main.explorer_panel.orbit_source_hint.text.contains("%.2f km/s" % Ephemeris.speed_km_s(5,main.solar_jd)) and is_finite(Ephemeris.speed_km_s(5,main.solar_jd)) and main.world.simulation_time_s==world_time)
	await capture("de440-saturn-historic")
	main.set_solar_distance(true)
	await settle()
	check("true distance mode uses cached AU vector",absf(bodies[5].node.position.length()/real.length()-.55)<0.00001 and bool(aid.get_meta("true_distance")))
	main.explorer_panel.orbit_view_button.pressed.emit()
	await settle()
	check("near view returns to the same Saturn",main.solar_follow==5 and main.solar_orbit_focus==-1 and not bool(stage.get_meta("solar_orbit_overview")))
	await finish()
