extends "res://tests/integration/browse_suite.gd"
const Deadwood = preload("res://scripts/experience/deadwood_observation.gd")
const Compare = preload("res://tests/core/test_ecophysiology.gd")
const Science = preload("res://scripts/experience/science_reference.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world119-check="): directory=argument.trim_prefix("--world119-check=")
		if argument.begins_with("--deadwood-mode="): mode=argument.trim_prefix("--deadwood-mode=")
		if argument.begins_with("--world-dir="): save_directory=argument.trim_prefix("--world-dir=")
	if not directory.is_absolute_path() or not save_directory.is_absolute_path() or mode not in ["write","resume"] or save_directory==ProjectSettings.globalize_path("user://world"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	if mode=="resume":
		await resume_check()
		return
	if not await arrive("woodland"):
		await finish()
		return
	main.ground_light_preview=false
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="deadwood": action=button
	check("guide includes thirty-seven lessons and working decomposition entry",action!=null and main.world_guide.route_buttons.size()==37)
	if action!=null: action.pressed.emit()
	panel.deadwood_reset.pressed.emit()
	await settle()
	var plots: Array = stage.get_meta("deadwood_plots")
	check("new paired lesson preserves original three fungus targets",main._content_follow==14 and main.content_targets().size()==15 and main.content_targets()[11].node==stage.get_meta("fungus_targets")[0].node and main.content_targets()[13].node==stage.get_meta("fungus_targets")[2].node)
	check("both equal initial logs render with visible markers and controls",subject_visible(plots[0].root) and subject_visible(plots[1].root) and main.learning_overlay.last_visible_marks==3 and panel.deadwood_controls.visible and main.world.deadwood.wood==[100.,100.])
	check("decay materials are isolated per sample and existing fungus retained",plots[0].materials.size()==3 and plots[1].materials.size()==3 and plots[0].materials[0]!=plots[1].materials[0] and stage.get_meta("fungus_root").is_inside_tree())
	check("mechanism source is reachable and limits are explicit",Science.allows_url("woodland",Deadwood.Model.SOURCE) and panel.lesson_text.text.contains("不是克数") and panel.lesson_text.text.contains("CO₂"))
	await capture("deadwood-initial")
	await forward(100.)
	check("same world time drives independent moist and dry carbon stocks",absf(main.world.deadwood.wood[0]-100.*exp(-1.))<1.e-7 and main.world.deadwood.wood[1]==100.)
	check("visible material and all three bars follow authoritative stocks",absf(float(plots[0].materials[0].get_shader_parameter("remaining"))-exp(-1.))<1.e-6 and plots[0].bars[1].visible and plots[0].bars[2].visible and not plots[1].bars[1].visible)
	await capture("deadwood-moist")
	panel.deadwood_mode.item_selected.emit(0)
	var stock: float = main.world.deadwood.wood[0]
	await forward(30.)
	check("dry control stops further decomposition without restoring lost wood",main.world.deadwood.wood[0]==stock and panel.deadwood_mode.selected==0 and not plots[0].water.visible)
	panel.deadwood_mode.item_selected.emit(2)
	await forward(100.)
	check("waterlogged control slows loss and displays condition symbol",absf(main.world.deadwood.wood[0]-stock*exp(-.03))<1.e-7 and plots[0].water.visible and panel.deadwood_mode.selected==2)
	await capture("deadwood-waterlogged")
	panel.deadwood_mode.item_selected.emit(1)
	await forward(250.)
	check("rewetting continues late decay on same carbon ledger",main.world.deadwood.wood[0]<4. and main.world.deadwood.respired[0]>65. and main.world.deadwood.wood[1]==100.)
	await capture("deadwood-late")
	var frozen: Dictionary = main.world.deadwood.checkpoint()
	await settle()
	check("global pause freezes authoritative stocks and material state",main.world.deadwood.checkpoint()==frozen and absf(float(plots[0].materials[0].get_shader_parameter("remaining"))-frozen.wood[0]/100.)<1.e-6)
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	stage=main.coordinator.active_scene
	plots=stage.get_meta("deadwood_plots")
	check("return reconstructs same samples from retained state",main.world.deadwood.checkpoint()==frozen and plots[0].root.get_meta("stable_id")=="3dworld:teaching:deadwood:left")
	panel.show()
	panel.select_topic("deadwood")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact view keeps both samples controls and marks visible",subject_visible(plots[0].root) and subject_visible(plots[1].root) and panel.deadwood_controls.get_global_rect().end.y<panel.get_global_rect().end.y-12 and main.learning_overlay.last_visible_marks==3)
	await capture("deadwood-compact")
	main.save_button.pressed.emit()
	var loaded: Dictionary = Store.new(save_directory).load_session()
	check("real save button writes complete v10 world and current observation",loaded.status=="ok" and loaded.payload.world.version==10 and Compare.equivalent(loaded.payload.world.deadwood_decomposition,frozen))
	FileAccess.open(save_directory.path_join("deadwood-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"world":main.world.checkpoint()},"\t",true,true))
	await finish()

func resume_check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_directory.path_join("deadwood-expected.json")))
	var actual: Dictionary = main.world.checkpoint()
	var same: bool = main.world.current_scale_id=="woodland"
	for key: String in expected.world:
		if key!="local_habitat": same=same and Compare.equivalent(actual[key],expected.world[key])
	check("new release process restores all authoritative models and paused clock",same)
	var habitat: Dictionary = actual.local_habitat.duplicate(true)
	var continuation: Dictionary = habitat.events.pop_back()
	check("resume appends expected continuation record and preserves existing history",continuation.kind=="continued" and continuation.time_s==actual.simulation_time_s and Compare.equivalent(habitat,expected.world.local_habitat))
	main.explorer_panel.show()
	await settle()
	check("freshly opened panel exposes saved scene lesson",main.explorer_panel.select_topic("deadwood"))
	await settle()
	var plots: Array = main.coordinator.active_scene.get_meta("deadwood_plots")
	check("restored values reach scene material and control",absf(float(plots[0].materials[0].get_shader_parameter("remaining"))-expected.world.deadwood_decomposition.wood[0]/100.)<1.e-6 and main.explorer_panel.deadwood_mode.selected==1)
	var before: float = main.world.deadwood.wood[0]
	await forward(5.)
	check("resumed process continues decay from saved amount",absf(main.world.deadwood.wood[0]-before*exp(-.05))<1.e-7)
	var old_world: Dictionary = main.world.checkpoint()
	main.explorer_panel.deadwood_reset.pressed.emit()
	await settle()
	var new_world: Dictionary = main.world.checkpoint()
	old_world.erase("deadwood_decomposition")
	new_world.erase("deadwood_decomposition")
	check("local reset restores samples without resetting other world systems",Compare.equivalent(old_world,new_world) and main.world.deadwood.wood==[100.,100.] and float(plots[0].materials[0].get_shader_parameter("remaining"))==1.)
	await capture("deadwood-resumed-reset")
	await finish()
