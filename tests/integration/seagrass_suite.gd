extends "res://tests/integration/deer_skin_suite.gd"
const Grass = preload("res://scripts/experience/seagrass_observation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world122-check="): directory=argument.trim_prefix("--world122-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
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
	main.world_guide.hide()
	main._reduced_motion=true
	main.world.set_paused(true)
	if not await arrive("reef"):
		await finish()
		return
	var stage: Node = main.coordinator.active_scene
	var root: Node3D = stage.get_meta("seagrass_root")
	var patch: MultiMeshInstance3D = stage.get_meta("seagrass_patch")
	var panel: Node = main.explorer_panel
	check("original plant meshes are imported alongside unchanged animal population",main.content_targets().size()==11 and stage.get_meta("marine_actors").size()==44 and patch.multimesh.instance_count==360 and root.get_meta("stable_id")=="3dworld:teaching:halophila-ovalis:reference")
	check("reference is full-size geometry with buried roots",root.scale.is_equal_approx(Vector3.ONE) and (root.find_child("HalophilaReference",true,false) as MeshInstance3D).get_aabb().size.y<.055 and absf(root.position.y-stage.builder._terrain_height(stage,root.position.x,root.position.z))<.00001)
	var grounded: bool = true
	for i: int in range(patch.multimesh.instance_count):
		var origin: Vector3 = patch.multimesh.get_instance_transform(i).origin
		grounded=grounded and absf(origin.y-stage.builder._terrain_height(stage,origin.x,origin.z))<.00001
	check("all field leaf pairs follow actual triangle terrain",grounded)
	panel.show()
	await settle()
	check("patch lesson selects real marine plant",panel.select_topic("seagrass") and main._content_follow==9)
	await settle()
	check("patch renders and reference remains inside observation area",subject_visible(root) and await part_pixels(root,root.position+Vector3(0,.021,0),Vector2i(18,18))>10 and main.learning_overlay.last_visible_marks==1)
	await capture("seagrass-patches")
	check("leaf topic selects same attached plant",panel.select_topic("seagrass_leaf") and main._content_follow==10)
	await settle()
	check("millimetre leaf visibly renders with all three annotations",leaf_visible(stage) and await part_pixels(root,Grass.point(stage,"LeafCentreAnchor"),Vector2i(18,18))>30 and main.learning_overlay.last_visible_marks==3)
	check("lesson explains dimensions ecological role and authored limits",panel.lesson_text.text.contains("18×9mm") and panel.lesson_text.text.contains("根茎埋在砂中") and Reference.allows_url("reef",Grass.SOURCE) and Reference.allows_url("reef",Grass.ECOLOGY_SOURCE))
	await capture("seagrass-leaf")
	await at_time(4.)
	var old_point: Vector3 = Grass.point(stage,"LeafCentreAnchor")
	var time_value: float = stage.get_meta("seagrass_material").get_shader_parameter("world_time")
	await settle()
	check("pause holds deformation and attached marks at same world time",time_value==4. and Grass.point(stage,"LeafCentreAnchor").is_equal_approx(old_point))
	await at_time(6.)
	check("one world time moves attached leaf and marker together",Grass.point(stage,"LeafCentreAnchor").distance_to(old_point)>.0001 and float(stage.get_meta("seagrass_material").get_shader_parameter("world_time"))==6.)
	panel.markers_toggle.set_pressed(false)
	await settle()
	check("leaf annotations can be hidden",main.learning_overlay.last_visible_marks==0)
	panel.markers_toggle.set_pressed(true)
	old_point=Grass.point(stage,"LeafCentreAnchor")
	var transform: Transform3D = root.transform
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="seagrass_leaf": action=button
	check("both plant guide entries coexist with previous routes",action!=null and main.world_guide.route_buttons.size()==39)
	if action!=null: action.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	stage=main.coordinator.active_scene
	root=stage.get_meta("seagrass_root")
	check("return recovers same root pose world phase and lesson",root.transform.is_equal_approx(transform) and Grass.point(stage,"LeafCentreAnchor").is_equal_approx(old_point) and main.world.simulation_time_s==6. and main.learning_overlay.topic=="seagrass_leaf")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact leaf and controls remain visible",leaf_visible(stage) and main.learning_overlay.last_visible_marks==3 and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y and await part_pixels(root,Grass.point(stage,"LeafCentreAnchor"),Vector2i(15,15))>20)
	await capture("seagrass-leaf-compact")
	await finish()

func leaf_visible(stage: Node) -> bool:
	var rect: Rect2 = Rect2(Vector2(main.explorer_panel.get_global_rect().end.x+8,80),Vector2(get_window().size.x-main.explorer_panel.get_global_rect().end.x-16,get_window().size.y-145))
	for name: String in ["LeafCentreAnchor","LeafMarginAnchor","PetioleAnchor"]:
		var at: Vector3 = Grass.point(stage,name)
		if stage.camera.is_position_behind(at) or not rect.has_point(stage.camera.unproject_position(at)): return false
	return true

func capture(label: String) -> void:
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var path: String = directory.path_join(label+".png")
	var status: Error = get_viewport().get_texture().get_image().save_png(path)
	print("SEAGRASS_CAPTURE ",path," status=",status," open_error=",FileAccess.get_open_error())
	check("capture "+label,status==OK)
	if status==OK: captures.append(label+".png")

func finish() -> void:
	var result: Dictionary = {"cases":cases,"failures":failures,"captures":captures,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"screen":get_window().current_screen,"performance_test":false}
	var file: FileAccess = FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	if file==null:
		print("SEAGRASS_REPORT_WRITE_FAILURE ",FileAccess.get_open_error()," ",JSON.stringify(result))
		main._quit(2)
		return
	file.store_string(JSON.stringify(result,"\t")+"\n")
	file.close()
	print("SEAGRASS_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
