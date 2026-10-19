extends "res://tests/integration/runoff_suite.gd"
const Coral = preload("res://scripts/experience/coral_observation.gd")
const Compare = preload("res://tests/core/test_ecophysiology.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world113-check="): directory=argument.trim_prefix("--world113-check=")
		if argument.begins_with("--symbiosis-mode="): mode=argument.trim_prefix("--symbiosis-mode=")
		if argument.begins_with("--world-dir="): save_directory=argument.trim_prefix("--world-dir=")
	if not directory.is_absolute_path() or not save_directory.is_absolute_path() or mode not in ["write","resume"] or save_directory==ProjectSettings.globalize_path("user://world"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless" and DisplayServer.get_screen_count()==1:
		main._measurement_screen=get_window().current_screen
		get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	if DisplayServer.get_name()!="headless":
		var stable: int = Time.get_ticks_msec()
		var deadline: int = stable+10000
		while Time.get_ticks_msec()-stable<2000 and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable=Time.get_ticks_msec()
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	get_window().size=Vector2i(1280,720)
	if mode=="resume":
		await resume_check()
		return
	check("native v6 migration starts no invented symbiosis history",main.world.symbiosis.started_at_s==main.world.simulation_time_s and main.world.symbiosis.steps==0 and main.world.symbiosis.symbiont==1 and not main.world.symbiosis.heated and main.world.runoff.rain_mm>0)
	if not await arrive("reef"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="coral_symbiosis": action=button
	check("thirtieth route opens real coral symbiosis",action!=null and main.world_guide.route_buttons.size()==30)
	if action!=null: action.pressed.emit()
	var panel: Node = main.explorer_panel
	var stage: Node = main.coordinator.active_scene
	var colony: Node3D = stage.get_meta("coral_root")
	await settle()
	check("same original colony and attached polyp retain target indices",main._content_follow==7 and main.content_targets()[7].node==colony and main.content_targets()[8].node.get_meta("coral_root")==colony)
	check("live tissue materials read initial full relative stock",materials_match(stage,1.) and stage.get_meta("coral_tissue_materials").size()>=4)
	check("colony and relationship marks clear the explanation panel",subject_visible(colony) and main.learning_overlay.last_visible_marks==2)
	check("sources and limits separate bleaching from mortality",panel.lesson_text.text.contains("现实不保证恢复") and panel.lesson_text.text.contains("死亡预测") and Reference.allows_url("reef",Coral.Symbiosis.SOURCE))
	await capture("symbiosis-reference-colony")
	var image_before: Image = await scene_image(stage)
	panel.coral_heat.set_pressed_no_signal(true)
	panel.coral_heat.toggled.emit(true)
	await forward(80.)
	var depleted: float = main.world.symbiosis.symbiont
	check("heat control gradually reduces authoritative relative algae",main.world.symbiosis.heated and depleted<.12 and depleted>0 and main.world.symbiosis.stress>.99)
	check("same colony materials reflect depleted state without replacing mesh",materials_match(stage,depleted) and stage.get_meta("coral_root")==colony)
	var image_after: Image = await scene_image(stage)
	var changed: int = 0
	for y: int in range(180,510):
		for x: int in range(500,1150):
			var a: Color = image_before.get_pixel(x,y)
			var b: Color = image_after.get_pixel(x,y)
			if b.get_luminance()-a.get_luminance()>.09: changed+=1
	check("rendered colony visibly lightens with shared state",changed>400)
	print("CORAL_LIGHTENED_PIXELS ",changed)
	await capture("symbiosis-stressed-colony")
	var frozen: Dictionary = main.world.symbiosis.checkpoint()
	await settle()
	check("global pause freezes every symbiosis stock and flux",frozen==main.world.symbiosis.checkpoint())
	panel.select_topic("coral_polyp")
	await settle()
	check("attached living polyp shares colour and remains present",main._content_follow==8 and materials_match(stage,depleted) and stage.get_meta("coral_tentacles").size()==12 and stage.camera.near<.001)
	await capture("symbiosis-pale-polyp")
	panel.select_topic("coral_symbiosis")
	panel.coral_heat.set_pressed_no_signal(false)
	panel.coral_heat.toggled.emit(false)
	await forward(1.)
	check("relief keeps residual stress instead of instant recovery",not main.world.symbiosis.heated and main.world.symbiosis.symbiont<=depleted and main.world.symbiosis.stress>.8)
	await forward(139.)
	check("surviving teaching case recovers gradually in the same material",main.world.symbiosis.symbiont>.6 and main.world.symbiosis.symbiont<.9 and materials_match(stage,main.world.symbiosis.symbiont))
	frozen=main.world.symbiosis.checkpoint()
	if not await arrive("earth") or not await arrive("reef"):
		await finish()
		return
	stage=main.coordinator.active_scene
	colony=stage.get_meta("coral_root")
	check("scene reentry preserves shared proxy and original colony identity",frozen==main.world.symbiosis.checkpoint() and colony.get_meta("stable_id")=="3dworld:teaching:acropora-millepora:0001" and materials_match(stage,frozen.symbiont))
	panel.show();panel.select_topic("coral_symbiosis")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact lesson keeps colony heat and reset controls visible",subject_visible(colony) and panel.coral_controls.get_global_rect().end.y<panel.get_global_rect().end.y-12 and main.learning_overlay.last_visible_marks==2)
	await capture("symbiosis-recovery-compact")
	main.save_button.pressed.emit()
	var store: Store = Store.new(save_directory)
	var loaded: Dictionary = store.load_session()
	check("production v7 save includes symbiosis and existing city water",loaded.status=="ok" and loaded.payload.world.version==7 and Compare.equivalent(loaded.payload.world.coral_symbiosis,main.world.symbiosis.checkpoint()) and loaded.payload.world.urban_runoff.rain_mm>0)
	FileAccess.open(save_directory.path_join("symbiosis-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"time":main.world.simulation_time_s,"symbiosis":main.world.symbiosis.checkpoint(),"runoff":main.world.runoff.checkpoint(),"browse":main.world.browse.checkpoint()},"\t",true,true))
	await finish()

func materials_match(stage: Node, value: float) -> bool:
	var materials: Array = stage.get_meta("coral_tissue_materials",[])
	if materials.is_empty(): return false
	for material: ShaderMaterial in materials:
		if absf(float(material.get_shader_parameter("symbiont_proxy"))-value)>.000001: return false
	return true

func scene_image(stage: Node) -> Image:
	for i: int in range(3): await RenderingServer.frame_post_draw
	return stage.viewport.get_texture().get_image()

func resume_check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_directory.path_join("symbiosis-expected.json")))
	check("second process restores same paused reef time",main.world.current_scale_id=="reef" and main.world.paused and main.world.simulation_time_s==expected.time)
	check("symbiosis restored without offline catchup",Compare.equivalent(main.world.symbiosis.checkpoint(),expected.symbiosis))
	check("old browse and city water history remain intact",Compare.equivalent(main.world.browse.checkpoint(),expected.browse) and Compare.equivalent(main.world.runoff.checkpoint(),expected.runoff))
	main.explorer_panel.show();main.explorer_panel.select_topic("coral_symbiosis")
	await settle()
	check("restored material uses saved relative algae",materials_match(main.coordinator.active_scene,main.world.symbiosis.symbiont))
	var before: float = main.world.symbiosis.symbiont
	await forward(10.)
	check("recovered world continues from saved stock",main.world.symbiosis.symbiont>before and main.world.symbiosis.symbiont<1)
	await capture("symbiosis-resumed")
	await finish()
