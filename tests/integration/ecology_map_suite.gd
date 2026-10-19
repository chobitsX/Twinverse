extends "res://tests/integration/oxygen_atom_suite.gd"
const Relations = preload("res://scripts/experience/ecology_relations.gd")
func ready_scale(id: String) -> bool:
	var deadline: int=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if native: RenderingServer.force_draw(false,0.0)
		if main.coordinator!=null and main.coordinator.active_scene!=null and not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.current_scale_id==id and main.world.foreground: return true
	print("ECOLOGY_READY_TIMEOUT ",id," actual=",main.world.current_scale_id," phase=",main.coordinator.phase," foreground=",main.world.foreground)
	check("ready "+id,false)
	return false

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world137-check="): directory=argument.trim_prefix("--world137-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1100,800)
	if native: root.unfocusable=true
	main=Experience.instantiate(); root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("earth"): finish_ecology(); return
	main._reduced_motion=true; main.world.set_paused(true)
	var authority: RefCounted=main.world
	var time_before: float=main.world.simulation_time_s
	var science: Dictionary=main.world.science.snapshot()
	main._open_guide()
	main.world_guide.ecology_button.pressed.emit()
	await frames()
	var map: Node=main.world_guide.ecology_map
	check("ecology opens inside existing modal guide",map.visible and not main.world_guide.grid.visible and not main.world_guide.search.visible)
	for branch: String in Relations.BRANCHES:
		map.set_branch(branch)
		await frames()
		var valid: bool=true
		for item: Dictionary in map.data.nodes:
			if not str(item.topic).is_empty(): valid=valid and Topics.for_scale(branch).any(func(t: Dictionary) -> bool: return t.id==item.topic)
			else: valid=valid and map.nodes[item.id].disabled
		for edge: Dictionary in map.data.edges:
			valid=valid and map.nodes.has(edge.from) and map.nodes.has(edge.to) and str(edge.source).begins_with("https://")
		check(branch+" references actual lessons and disables absent objects",valid)
		for i: int in range(map.data.edges.size()):
			map.relation_picker.item_selected.emit(i)
			check(branch+" relation selection "+str(i),map.selected==i and map.explanation.text==map.data.edges[i].note)
		await capture("ecology-"+branch)
	map.set_branch("woodland")
	map.select_relation(1)
	check("larval relation links the implemented leaf reference",not map.nodes.larva.disabled and map.explanation.text.contains("未模拟叶片消耗"))
	root.size=Vector2i(900,650)
	await frames()
	main.world_guide.scroll.scroll_vertical=9999
	await frames()
	check("compact panel can scroll to explanation and source",main.world_guide.panel.get_global_rect().end.x<=900 and map.source_link.get_global_rect().end.y<=main.world_guide.scroll.get_global_rect().end.y+1 and map.source_link.get_global_rect().position.y>=main.world_guide.scroll.get_global_rect().position.y)
	await capture("ecology-compact-details")
	check("map browsing keeps authoritative time and physiology",main.world==authority and main.world.simulation_time_s==time_before and main.world.science.snapshot()==science)
	for route: Array in [["reef","seagrass","seagrass"],["woodland","fungus","fungus"],["desert","iguana","desert_iguana"]]:
		if not await ready_scale(main.world.current_scale_id): finish_ecology(); return
		main._open_guide(); main.world_guide.show_ecology(true)
		map.set_branch(route[0])
		print("ECOLOGY_VISIT ",route," foreground=",main.world.foreground," phase=",main.coordinator.phase)
		map.nodes[route[1]].pressed.emit()
		if not await ready_scale(route[0]): finish_ecology(); return
		await frames()
		check("graph navigates to real 3D topic "+route[2],not main.world_guide.visible and main.explorer_panel.visible and main.learning_overlay.topic==route[2] and main.world==authority)
	main._open_guide(); main.world_guide.show_ecology(true)
	var escape: InputEventKey=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	main._input(escape)
	check("Escape closes the graph without changing scene",not main.world_guide.visible and main.world.current_scale_id=="desert" and not main._shutting_down)
	main._open_guide()
	check("normal guide reopens all 41 existing routes",not map.visible and main.world_guide.grid.visible and visible_topics().size()==41)
	finish_ecology()

func finish_ecology() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"debug_build":OS.is_debug_build(),"native":native,"performance_test":false},"\t")+"\n")
	print("ECOLOGY_MAP_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
