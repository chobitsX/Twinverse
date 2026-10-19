extends "res://tests/integration/land_lighting_suite.gd"
## Bounded Metal comparison of a selected DE440 sampled path and teaching ellipse.

func distance_to_path(path: MeshInstance3D, point: Vector3) -> float:
	var vertices: PackedVector3Array = path.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var nearest: float = INF
	for segment: int in range(vertices.size()-1):
		var a: Vector3=vertices[segment]
		var edge: Vector3=vertices[segment+1]-a
		var fraction: float=clampf((point-a).dot(edge)/edge.length_squared(),0.0,1.0)
		nearest=minf(nearest,point.distance_to(a+fraction*edge))
	return nearest

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world180-review="): directory=argument.trim_prefix("--world180-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(150.).timeout.connect(func() -> void:
		push_error("DE440 trajectory diagnostic exceeded its bounded runtime")
		get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	get_window().size=Vector2i(1280,800)
	if not await ready_stage(): await finish(); return
	var stable_since: int=Time.get_ticks_msec()
	var startup_deadline: int=stable_since+10000
	while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<startup_deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since=Time.get_ticks_msec()
	if Time.get_ticks_msec()-stable_since<2000:
		check("initial Metal window remains drawable",false)
		await finish(); return
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
	check("unselected solar overview has no extra trajectory",stage.world_root.get_node_or_null("SelectedDE440Trajectory")==null)
	main.explorer_panel.body_picker.item_selected.emit(6)
	await settle()
	var path: MeshInstance3D=stage.world_root.get_node("SelectedDE440Trajectory")
	check("Saturn selection creates one DE440 sampled path",path.visible and int(path.get_meta("index"))==5 and path.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==257)
	check("current Saturn is on its sampled date path",distance_to_path(path,bodies[5].node.position)<.01)
	check("visible hint separates cyan DE440 and orange teaching ellipse",main.explorer_panel.orbit_source_hint.visible and main.explorer_panel.orbit_source_hint.text.contains("DE440") and main.explorer_panel.orbit_source_hint.text.contains("近似教学椭圆") and bodies[5].orbit.visible)
	check("selected teaching ellipse uses dash pairs while DE440 path remains continuous",bodies[5].orbit.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==128 and path.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==257)
	main.explorer_panel.orbit_view_button.pressed.emit()
	await settle()
	var aid: MultiMeshInstance3D=stage.world_root.get_node("SelectedOrbitEqualTime")
	check("orbit view shows both paths and the unchanged twelve teaching points",main.solar_orbit_focus==5 and path.visible and aid.visible and aid.multimesh.instance_count==12)
	await capture("saturn-de440-and-teaching-orbit")
	var old_epoch: float=float(path.get_meta("epoch"))
	main.set_solar_date(2418673.34)
	await settle()
	check("historic date rebuilds DE440 path around real Saturn",float(path.get_meta("epoch"))!=old_epoch and distance_to_path(path,bodies[5].node.position)<.01 and main.world.simulation_time_s==world_time)
	await capture("saturn-historic-two-paths")
	main.set_solar_distance(true)
	await settle()
	check("true distance rebuilds the same DE440 path",bool(path.get_meta("true_distance")) and distance_to_path(path,bodies[5].node.position)<.01)
	await capture("saturn-true-distance-two-paths")
	main.explorer_panel.body_picker.item_selected.emit(1)
	await settle()
	main.explorer_panel.orbit_view_button.pressed.emit()
	await settle()
	check("Mercury reuses selected path node with its own date window",main.solar_orbit_focus==0 and int(path.get_meta("index"))==0 and distance_to_path(path,bodies[0].node.position)<.01)
	await capture("mercury-de440-and-teaching-orbit")
	var science: Dictionary=ScienceReference.describe("solar_system")
	check("science explanation distinguishes sampled and approximate lines",str(science.basis).contains("青实线") and str(science.basis).contains("橙虚线") and str(science.limit).contains("折线"))
	main.follow_planet(-1)
	await settle()
	check("overview restores ordinary orbits and hides selected path",not path.visible and bodies[0].orbit.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==257 and main.solar_follow==-1 and main.world.simulation_time_s==world_time)
	await finish()
