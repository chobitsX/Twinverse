extends "res://tests/integration/life_assets_suite.gd"

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world98-check="): directory = argument.trim_prefix("--world98-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	if not await arrive("woodland"):
		await finish()
		return
	main.ground_light_preview = false
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	panel.show()
	for frame: int in range(3): await get_tree().process_frame
	var targets: Array[Dictionary] = main.content_targets()
	check("two plant species and attached closeups join existing animals",targets.size()==6 and targets[2].label.contains("Quercus alba") and targets[3].label.contains("Pinus strobus") and stage.get_meta("actors").size()==20)
	main.follow_content(3)
	check("oak roots meet actual terrain",absf(targets[2].node.position.y-stage.builder._height(12,-6))<.001)
	await capture("white-oak-young")
	main.follow_content(4)
	check("pine roots meet actual terrain",absf(targets[3].node.position.y-stage.builder._height(15,-6))<.001)
	await capture("white-pine-young")
	check("oak leaf topic selects its attached reference leaf",panel.select_topic("oak_leaf") and main._content_follow==4 and targets[4].node.position.is_equal_approx(targets[2].node.find_child("LeafObservationAnchor",true,false).global_position))
	await capture("white-oak-leaf")
	check("leaf markers and reference source present",main.learning_overlay.last_visible_marks==2 and panel.lesson_source.visible and panel.lesson_text.text.contains("18cm"))
	check("pine topic selects the five-needle reference bundle",panel.select_topic("pine_needles") and main._content_follow==5 and targets[5].node.position.is_equal_approx(targets[3].node.find_child("NeedleObservationAnchor",true,false).global_position))
	var needle_count: int = 0
	var sized: bool = true
	for i: int in range(1,6):
		var needle: MeshInstance3D = targets[3].node.find_child("ReferenceNeedle"+str(i),true,false) as MeshInstance3D
		if needle!=null:
			needle_count += 1
			sized = sized and needle.get_aabb().size.length()>.09 and needle.get_aabb().size.length()<.13
	check("actual reference geometry contains five needles at authored scale",needle_count==5 and sized)
	await capture("white-pine-needles")
	check("five needle tips and common base have attached marks",main.learning_overlay.last_visible_marks==6)
	var old_position: Vector3 = targets[5].node.position
	await at_time(4.0)
	var leaf_material: ShaderMaterial = targets[3].node.find_child("ReferenceNeedle1",true,false).get_surface_override_material(0)
	check("leaf flutter uses existing world time",absf(float(leaf_material.get_shader_parameter("world_time"))-4.0)<.001)
	for frame: int in range(4): await get_tree().process_frame
	check("pause keeps leaf time and observation anchors",absf(float(leaf_material.get_shader_parameter("world_time"))-4.0)<.001 and targets[5].node.position.is_equal_approx(old_position))
	panel.markers_toggle.set_pressed(false)
	for frame: int in range(3): await get_tree().process_frame
	check("plant annotations can be hidden",main.learning_overlay.last_visible_marks==0)
	panel.markers_toggle.set_pressed(true)
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var button: Button
	for route: Button in main.world_guide.route_buttons:
		if route.get_meta("guide_topic","")=="oak_leaf": button = route
	check("guide has actual plant lesson action",button!=null)
	if button!=null:
		button.pressed.emit()
		if not await ready_stage():
			await finish()
			return
		for frame: int in range(4): await get_tree().process_frame
		check("guide re-enters the leaf lesson with same world",main.world.current_scale_id=="woodland" and main.learning_overlay.topic=="oak_leaf" and main.world.simulation_time_s==4.0)
	get_window().size = Vector2i(900,650)
	for frame: int in range(4): await get_tree().process_frame
	check("compact plant topic selector stays reachable",panel.topic_picker.get_global_rect().end.y<panel.get_global_rect().end.y and panel.object_picker.visible)
	stage = main.coordinator.active_scene
	var oak: Node3D = main.content_targets()[2].node
	var mesh: MeshInstance3D = oak.find_child("ReferenceLeaf",true,false) as MeshInstance3D
	var visible_leaf: bool = true
	var leaf_vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in leaf_vertices:
		var point: Vector2 = stage.camera.unproject_position(mesh.to_global(vertex))
		visible_leaf = visible_leaf and point.x>panel.offset_right+8 and point.x<890 and point.y>90 and point.y<525
	check("compact leaf geometry clears the panel and screen edges",visible_leaf)
	await capture("plants-compact")
	await finish()
