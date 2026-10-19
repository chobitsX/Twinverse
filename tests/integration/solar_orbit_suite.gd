extends "res://tests/integration/land_lighting_suite.gd"
## Bounded real-window observation of the selected JPL orbit and equal-time aid.

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world157-check="): directory=argument.trim_prefix("--world157-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(150.).timeout.connect(func() -> void:
		push_error("Solar orbit diagnostic exceeded its bounded runtime")
		get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	get_window().size=Vector2i(1280,800)
	if not await ready_stage(): await finish(); return
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
	main.explorer_panel.body_picker.item_selected.emit(1)
	await settle()
	var aid: MultiMeshInstance3D=stage.world_root.get_node("SelectedOrbitEqualTime")
	check("planet selection highlights only its JPL orbit",main.solar_follow==0 and int(stage.get_meta("solar_focus_index"))==0 and bodies[0].orbit_material.albedo_color.r>.8 and bodies[1].orbit_material.albedo_color.r<.2)
	check("selected orbit has 12 visible equal-time markers",aid.visible and aid.multimesh.instance_count==12 and main.explorer_panel.orbit_view_button.visible)
	var near: float=aid.multimesh.get_instance_transform(0).origin.angle_to(aid.multimesh.get_instance_transform(1).origin)
	var far: float=aid.multimesh.get_instance_transform(6).origin.angle_to(aid.multimesh.get_instance_transform(7).origin)
	check("Mercury equal-time arc opens faster near the Sun",near/far>1.8)
	main.explorer_panel.orbit_view_button.pressed.emit()
	await settle()
	check("orbit action frames the selected ellipse",main.solar_orbit_focus==0 and main.solar_follow==-1 and subject_visible(bodies[0].orbit) and not stage.world_root.get_node("SolarCorona_Illustration").visible)
	check("planet remains at the shared observer date",bodies[0].node.position.distance_to(Ephemeris.display_position(0,main.solar_jd,false))<.00001 and main.world.simulation_time_s==world_time)
	await capture("mercury-orbit-equal-time")
	var original: Vector3=bodies[0].node.position
	main.set_solar_date(main.solar_jd+25.)
	await settle()
	check("date control moves the real planet and keeps orbit view",bodies[0].node.position.distance_to(original)>1.0 and main.solar_orbit_focus==0 and main.world.simulation_time_s==world_time)
	main.set_solar_distance(true)
	await settle()
	check("true AU distance rebuilds aid on common scale",main.solar_orbit_focus==0 and bool(aid.get_meta("true_distance")) and absf(bodies[0].node.position.length()/Ephemeris.position_au(0,main.solar_jd).length()-.55)<.00001)
	await capture("mercury-orbit-true-distance")
	main.set_solar_distance(false)
	main.explorer_panel.body_picker.item_selected.emit(3)
	await settle()
	main.explorer_panel.orbit_view_button.pressed.emit()
	await settle()
	check("Earth uses the same focus aid and panel explanation",main.solar_orbit_focus==2 and int(aid.get_meta("index"))==2 and bodies[2].orbit_material.albedo_color.r>.8 and bodies[0].orbit_material.albedo_color.r<.2 and main.explorer_panel.body_text.text.contains("不是12个未来日期"))
	await capture("earth-orbit-equal-time")
	var epoch: float=float(aid.get_meta("epoch"))
	main.set_solar_date(epoch+366.)
	await settle()
	check("reference ellipse and equal-time aid update together after one year",float(aid.get_meta("epoch"))==float(stage.get_meta("solar_orbit_epoch")) and float(aid.get_meta("epoch"))>epoch and aid.multimesh.instance_count==12)
	main.explorer_panel.orbit_view_button.pressed.emit()
	await settle()
	check("near-view action returns to the same selected planet",main.solar_follow==2 and main.solar_orbit_focus==-1 and not bool(stage.get_meta("solar_orbit_overview")))
	main.follow_planet(-1)
	await settle()
	check("overview clears focus aid without changing world time",main.solar_follow==-1 and main.solar_orbit_focus==-1 and not aid.visible and main.world.simulation_time_s==world_time)
	await finish()
