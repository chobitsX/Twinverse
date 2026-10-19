extends "res://tests/integration/ecology_map_suite.gd"
const Galactic = preload("res://scripts/experience/galactic_observation.gd")
func frames() -> void:
	for i: int in range(4): await get_tree().process_frame
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world142-check="): directory=arg.trim_prefix("--world142-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,800);root.unfocusable=true
	main=Experience.instantiate();root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("galaxy"): finish_galactic();return
	main.world.set_paused(true);main._reduced_motion=true
	var authority: RefCounted=main.world
	var time: float=main.world.simulation_time_s
	main._open_guide();main.world_guide.search.text="银河"
	var button: Button
	for entry: Button in main.world_guide.route_buttons:
		if entry.get_meta("guide_topic","")=="galactic_structure": button=entry
	check("existing route now exposes a searchable galactic lesson",button!=null and button.visible and main.world_guide.route_buttons.size()==41)
	if button==null:finish_galactic();return
	button.pressed.emit();await frames()
	var panel: Node=main.explorer_panel
	var stage: Node=main.coordinator.active_scene
	var data: Dictionary=stage.get_meta("galactic_observation")
	check("lesson selects its actual view controls",main.learning_overlay.topic=="galactic_structure" and panel.galactic_controls.visible)
	check("branch picker identifies the current galaxy rather than a different scale",panel.BRANCHES[panel.branch_picker.selected][1]=="galaxy")
	var anchor: Node3D=stage.world_root.get_node("SolarSystemSemanticAnchor")
	check("solar marker and navigation target share referenced distance",anchor.position.is_equal_approx(stage.target_position) and absf(anchor.position.length()*Galactic.LY_PER_UNIT-26000.)<.01)
	var radius_line: MeshInstance3D=data.lines[0]
	var vertices: PackedVector3Array=radius_line.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check("visible distance line ends at the real semantic anchor",vertices.size()==2 and vertices[0]==Vector3.ZERO and vertices[1].is_equal_approx(anchor.position))
	var rim: PackedVector3Array=data.lines[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check("reference ring and semantic extent use same length scale",rim.size()==129 and absf(rim[0].length()*2.*Galactic.LY_PER_UNIT-100000.)<.01 and is_equal_approx(stage.semantic_size_m,100000.*Galactic.LIGHT_YEAR_M))
	check("top view is finite and looks down onto the disc",stage.camera.basis.is_finite() and stage.camera.basis.z.dot(Vector3.UP)>.9999)
	check("galaxy and Sun fit beside lesson panel",fits_disc(stage))
	await capture("galaxy-top")
	panel.galactic_side_button.pressed.emit();await frames()
	check("side view shows a genuinely different three-dimensional direction",stage.camera.basis.z.dot(Vector3.BACK)>.9999 and fits_disc(stage))
	await capture("galaxy-side")
	panel.markers_toggle.toggled.emit(false);await frames()
	check("marker toggle hides geometry as well as labels",not data.lines[0].visible and not data.lines[1].visible and not main.learning_overlay.enabled)
	panel.markers_toggle.toggled.emit(true);await frames()
	root.size=Vector2i(900,650);await frames()
	panel.galactic_top_button.pressed.emit();await frames()
	panel.scroll.ensure_control_visible(panel.galactic_controls);await frames()
	check("small window keeps all controls and disc accessible",panel.scroll.get_global_rect().encloses(panel.galactic_controls.get_global_rect()) and fits_disc(stage))
	await capture("galaxy-compact")
	panel.galactic_enter_button.pressed.emit()
	if not await ready_scale("solar_system"): finish_galactic();return
	check("solar anchor enters actual solar system using same world",main.world==authority and main.world.simulation_time_s==time and main.coordinator.active_scene.has_meta("solar_bodies"))
	main.start_guide_visit("galaxy","galactic_structure")
	if not await ready_scale("galaxy"): finish_galactic();return
	await frames()
	check("return restores galactic topic and same referenced anchor",main.learning_overlay.topic=="galactic_structure" and main.coordinator.active_scene.target_position.is_equal_approx(Galactic.sun_position()) and main.world==authority and main.world.simulation_time_s==time)
	check("native diagnostic still honours background frame cap",not native or Engine.max_fps==5)
	finish_galactic()
func fits_disc(stage: Node) -> bool:
	var size: Vector2=stage.viewport.size
	var panel: Rect2=main.explorer_panel.get_global_rect()
	var available_left: float=panel.end.x*size.x/root.size.x
	for point: Vector3 in [Vector3(15,0,0),Vector3(-15,0,0),Vector3(0,0,15),Vector3(0,0,-15),stage.target_position]:
		var p: Vector2=stage.camera.unproject_position(point)
		if stage.camera.is_position_behind(point) or p.x<available_left+8. or p.x>size.x-8. or p.y<80.*size.y/root.size.y or p.y>size.y-80.*size.y/root.size.y:return false
	return true
func finish_galactic() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"native":native,"debug_build":OS.is_debug_build(),"performance_test":false},"\t")+"\n")
	print("GALACTIC_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
