extends "res://tests/integration/solar_size_suite.gd"
const Oxygen = preload("res://scripts/core/oxygen_atom.gd")
func ready_scale(id: String) -> bool:
	var deadline: int=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if native: RenderingServer.force_draw(false,0.0)
		if main.coordinator!=null and main.coordinator.active_scene!=null and not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.current_scale_id==id and main.world.foreground: return true
	print("OXYGEN_READY_TIMEOUT ",id," actual=",main.world.current_scale_id," phase=",main.coordinator.phase," foreground=",main.world.foreground)
	check("ready "+id,false)
	return false
func select_view(mode: int, section: bool=false) -> void:
	main.explorer_panel.atom_picker.select(mode)
	main.explorer_panel.atom_picker.item_selected.emit(mode)
	main.explorer_panel.atom_section.toggled.emit(section)
	await frames()
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world136-check="): directory=argument.trim_prefix("--world136-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(900,650)
	if native: root.unfocusable=true
	main=Experience.instantiate(); root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("molecule"): finish_atom(); return
	main.coordinator.transition_cancelled.connect(func(request_id: int,reason: String) -> void: print("OXYGEN_CANCEL ",request_id," ",reason))
	main.coordinator.intent_accepted.connect(func(request_id: int,target: String) -> void: print("OXYGEN_INTENT ",request_id," ",target))
	main._reduced_motion=true; main.world.set_paused(true)
	main.world_guide.hide()
	var authority: RefCounted=main.world
	var checkpoint: Dictionary=main.world.science.snapshot()
	var time_before: float=main.world.simulation_time_s
	check("O2 molecule remains the parent context",main.Catalog.relative("atom",-1)=="molecule")
	main._navigate_relative(1)
	if not await ready_scale("atom"): finish_atom(); return
	main.explorer_panel.show()
	await frames()
	check("oxygen lesson is selectable after O2 arrival",main.explorer_panel.select_topic("oxygen_atom"))
	await select_view(0)
	var stage: Node=main.coordinator.active_scene
	var data: Dictionary=stage.get_meta("oxygen_atom")
	check("neutral oxygen has explanatory label and five real controls",main.science_badge.text.contains("1s² 2s² 2p⁴") and main.explorer_panel.atom_picker.item_count==5 and main.explorer_panel.atom_box.visible)
	check("default is reference density with hidden enlarged nucleus",data.cloud.visible and not data.nucleus.visible and data.volume.get_shader_parameter("orbital_mode")==0)
	check("nucleus has exactly 8 protons and 8 neutrons",data.nucleus.get_children().filter(func(n: Node) -> bool: return n.get_meta("nucleon")=="proton").size()==8 and data.nucleus.get_children().filter(func(n: Node) -> bool: return n.get_meta("nucleon")=="neutron").size()==8)
	await capture("oxygen-composition")
	await select_view(1)
	check("1s switch changes rendering without changing oxygen count",int(data.mode)==1 and data.volume.get_shader_parameter("orbital_mode")==1 and main.explorer_panel.atom_note.text.contains("球对称"))
	await select_view(2,true)
	check("2s section selects the actual shader plane",int(data.mode)==2 and bool(data.volume.get_shader_parameter("section_view")) and main.explorer_panel.atom_note.text.contains("暗环"))
	await capture("oxygen-2s-section")
	if native:
		var img: Image=root.get_texture().get_image()
		var low: float=luminance_at(stage,img,Vector3(2*Oxygen.SCALE,0,0))
		var inner: float=luminance_at(stage,img,Vector3(Oxygen.SCALE,0,0))
		var outer: float=luminance_at(stage,img,Vector3(4*Oxygen.SCALE,0,0))
		check("rendered 2s radial node darker than both neighboring regions",low<inner*.6 and low<outer*.8)
		print("OXYGEN_GPU_SECTION ",JSON.stringify({"node":low,"inner":inner,"outer":outer}))
	await select_view(3,false)
	check("2p selects a single two-lobe reference without particle orbits",int(data.mode)==3 and not bool(data.volume.get_shader_parameter("section_view")) and main.explorer_panel.atom_note.text.contains("同一个轨道"))
	await capture("oxygen-2p")
	await select_view(4)
	check("nuclear magnification hides cloud and labels scale boundary",data.nucleus.visible and not data.cloud.visible and not data.marker.visible and main.explorer_panel.atom_section.disabled and main.explorer_panel.atom_note.text.contains("8个质子、8个中子") and main.message_label.text.contains("不与电子云同比例"))
	await capture("oxygen16-nucleus")
	main.select_atom_view(99)
	check("invalid selection leaves the real view unchanged",int(data.mode)==4)
	check("view controls preserve authority time and reference physiology",main.world==authority and main.world.simulation_time_s==time_before and main.world.science.snapshot()==checkpoint)
	check("native panel controls fit narrow viewport",main.explorer_panel.atom_picker.get_global_rect().end.x<900 and main.explorer_panel.atom_section.get_global_rect().end.y<650)
	var escape: InputEventKey=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	main._input(escape); main._input(escape)
	await frames()
	check("Escape closes panel then clears atom view without quitting",main.world.current_scale_id=="atom" and int(data.mode)==0 and not main._shutting_down)
	if not await ready_scale("atom"): finish_atom(); return
	print("OXYGEN_RETURN_REQUEST ",main.world.foreground," ",main.coordinator.phase," ",main.Catalog.relative(main.world.current_scale_id,-1))
	main._navigate_relative(-1)
	print("OXYGEN_RETURN_AFTER ",main.world.foreground," ",main.coordinator.phase)
	if not await ready_scale("molecule"): finish_atom(); return
	check("return to O2 keeps the same world",main.world==authority and main.world.simulation_time_s==time_before)
	main.world_guide.open(false)
	main.world_guide.search.text="氧原子"
	main.world_guide.search.text_changed.emit("氧原子")
	await frames()
	check("world guide search exposes the actual oxygen route",visible_topics()==["oxygen_atom"] and main.world_guide.route_buttons.size()==41)
	for button: Button in main.world_guide.route_buttons:
		if str(button.get_meta("guide_topic"))=="oxygen_atom":
			button.pressed.emit()
			break
	if not await ready_scale("atom"): finish_atom(); return
	await frames()
	check("searched guide route opens oxygen lesson in the same world",main.explorer_panel.visible and main.learning_overlay.topic=="oxygen_atom" and main.world==authority and main.world.simulation_time_s==time_before)
	finish_atom()
func luminance_at(stage: Node, img: Image, point: Vector3) -> float:
	var pixel: Vector2i=Vector2i(stage.camera.unproject_position(point))
	var c: Color=img.get_pixelv(pixel)
	return .2126*c.r+.7152*c.g+.0722*c.b
func finish_atom() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"native":native,"debug_build":OS.is_debug_build(),"performance_test":false},"\t")+"\n")
	print("OXYGEN_ATOM_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
