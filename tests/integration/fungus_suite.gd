extends "res://tests/integration/frog_suite.gd"
const Fungi = preload("res://scripts/experience/fungus_observation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world114-check="): directory=argument.trim_prefix("--world114-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
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
	var stable: int = Time.get_ticks_msec()
	var deadline: int = stable+10000
	while Time.get_ticks_msec()-stable<2000 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw(): stable=Time.get_ticks_msec()
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	get_window().size=Vector2i(1280,720)
	if not await arrive("woodland"):
		await finish()
		return
	main.ground_light_preview=false
	var stage: Node = main.coordinator.active_scene
	var root: Node3D = stage.get_meta("fungus_root")
	var panel: Node = main.explorer_panel
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="fungus": action=button
	check("thirty-first route reaches new deadwood and fungus lesson",action!=null and main.world_guide.route_buttons.size()==31)
	if action!=null: action.pressed.emit()
	await settle()
	check("new views append without shifting frog or browse references",main.content_targets().size()==14 and main._content_follow==11 and main.content_targets()[9].node==stage.get_meta("frogs")[0] and main.content_targets()[8].node==stage.get_meta("browse_targets")[0].node)
	var bodies: int = 0
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		for slot: int in range(node.mesh.get_surface_count()):
			if node.get_surface_override_material(slot)==stage.get_meta("fungus_pore_material"): bodies+=1
	check("eleven actual fruiting bodies retain separate pore surfaces",bodies==11)
	check("same log and attached fruiting bodies visible beside lesson",subject_visible(root) and main.learning_overlay.last_visible_marks==2)
	check("lesson explains hidden hyphae and distinguishes fungi from plants",panel.lesson_text.text.contains("木内菌丝") and panel.lesson_text.text.contains("不是整株植物") and panel.lesson_text.text.contains("未模拟") and Reference.allows_url("woodland",Fungi.SOURCE))
	await capture("fungus-deadwood")
	var hero: MeshInstance3D = root.find_child("ReferenceCap",true,false) as MeshInstance3D
	panel.object_picker.item_selected.emit(13)
	await settle()
	check("upper view focuses same attached cap and clears topic markers",main._content_follow==12 and main.learning_overlay.topic.is_empty() and main.content_targets()[12].node.get_meta("fungus_root")==root and subject_visible(hero))
	check("cap band area is actually rendered",await part_pixels(hero,root.find_child("CapBandAnchor",true,false).global_position,Vector2i(24,24))>150)
	await capture("fungus-cap-bands")
	panel.object_picker.item_selected.emit(14)
	await settle()
	check("underside close view keeps same scale and reachable camera clipping",main._content_follow==13 and main.content_targets()[13].node.get_meta("fungus_root")==root and root.scale.is_equal_approx(Vector3.ONE) and stage.camera.near<.01)
	for i: int in range(12):
		var wheel: InputEventMouseButton = InputEventMouseButton.new()
		wheel.button_index=MOUSE_BUTTON_WHEEL_UP
		wheel.pressed=true
		main._unhandled_input(wheel)
	await settle()
	check("wheel reaches pore detail without scaling or clipping the object",absf(stage.camera.position.distance_to(main._orbit_target)-.045)<.001 and stage.camera.near<.005 and root.scale.is_equal_approx(Vector3.ONE))
	var pixels: int = await pore_pixels(stage)
	check("actual underside pores visible at close range",pixels>100)
	print("FUNGI_PORE_CHANGED_PIXELS ",pixels)
	await capture("fungus-pore-surface")
	var pose: Transform3D = root.transform
	var time: float = main.world.simulation_time_s
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	root=main.coordinator.active_scene.get_meta("fungus_root")
	check("reentry retains reference identity placement and paused world",root.get_meta("stable_id")=="3dworld:teaching:trametes-versicolor:deadwood01" and root.transform.is_equal_approx(pose) and main.world.simulation_time_s==time)
	panel.show();panel.select_topic("fungus")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact lesson leaves deadwood marks and toggle usable",subject_visible(root) and main.learning_overlay.last_visible_marks==2 and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-12)
	check("all three views remain accessible through object selector",panel.object_picker.item_count==15)
	await capture("fungus-compact")
	await finish()

func pore_pixels(stage: Node) -> int:
	var material: ShaderMaterial = stage.get_meta("fungus_pore_material")
	main.set_process(false)
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var shown: Image = stage.viewport.get_texture().get_image()
	material.set_shader_parameter("show_pores",false)
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var hidden: Image = stage.viewport.get_texture().get_image()
	material.set_shader_parameter("show_pores",true)
	var pixels: int = 0
	for y: int in range(100,shown.get_height()-100):
		for x: int in range(450,shown.get_width()-50):
			if hidden.get_pixel(x,y).get_luminance()-shown.get_pixel(x,y).get_luminance()>.035: pixels+=1
	main.set_process(true)
	await settle()
	return pixels
