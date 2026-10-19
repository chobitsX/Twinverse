extends "res://tests/integration/robin_motion_suite.gd"
const Pollinators = preload("res://scripts/experience/pollinator_observation.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world104-check="): directory = argument.trim_prefix("--world104-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless" and DisplayServer.get_screen_count()==1:
		main._measurement_screen = get_window().current_screen
		get_window().unfocusable = true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("woodland"):
		await finish()
		return
	main.ground_light_preview = false
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	var actors: Array = stage.get_meta("pollinators",[])
	var plants: Array = stage.get_meta("milkweed_plants",[])
	check("four real insects and six flowering plants join existing woodland",actors.size()==4 and plants.size()==6 and main.content_targets().size()==8)
	if actors.size()!=4 or plants.size()!=6:
		await finish()
		return
	var actor: Dictionary = actors[0]
	var node: Node3D = actor.node
	check("imported butterfly retains four wing pivots and four walking legs",actor.joints.size()==11 and node.find_child("ReducedForeleg",true,false)!=null)
	var fore: MeshInstance3D = node.find_child("ForeWingSurfaceL",true,false) as MeshInstance3D
	var material: StandardMaterial3D = fore.mesh.surface_get_material(0) as StandardMaterial3D
	check("original wing pigment is a real imported texture",material!=null and material.albedo_texture!=null and material.albedo_texture.get_width()>=768)
	check("milkweed has actual leaves flowers and an attached nectar anchor",plants[0].find_child("MilkweedOppositeLeaves",true,false)!=null and plants[0].find_child("MilkweedFlowers",true,false)!=null and actor.anchor.is_inside_tree())
	var bounds: Array[AABB] = []
	for plant: Node3D in plants: bounds.append(world_bounds(plant).grow(.055))
	var clear_others: bool = true
	var nearest: float = INF
	for step: int in range(161):
		var positions: Array[Vector3] = []
		for k: int in range(4):
			var at: Vector3 = actors[k].anchor.global_position-actors[k].tip+Pollinators.sample(step*.25,k).position
			positions.append(at)
			for j: int in range(plants.size()):
				if j!=k: clear_others = clear_others and not bounds[j].has_point(at)
		for k: int in range(4):
			for j: int in range(k+1,4): nearest = minf(nearest,positions[k].distance_to(positions[j]))
	check("authored routes clear other milkweed plants",clear_others)
	check("four butterflies keep wing-sized route separation",nearest>.12)
	check("new topic follows the actual insect flower pair",panel.select_topic("monarch") and main._content_follow==6)
	await at_time(3.0)
	check("visiting mouth reaches the flower reference point",float(node.get_meta("flower_distance_m"))<.00001 and actor.joints.ProboscisExtended.visible and not actor.joints.ProboscisCoiled.visible)
	check("lesson labels and linked objects are visible",main.learning_overlay.last_visible_marks==3 and subject_visible(node) and await visible_pixels(node)>50)
	await capture("monarch-flower-visit")
	panel.object_picker.item_selected.emit(7)
	await settle()
	check("insect close view clears explanation and near clipping",main.learning_overlay.topic.is_empty() and subject_visible(node) and stage.camera.near<.09)
	await capture("monarch-close")
	var transform: Transform3D = node.transform
	var wing: Vector3 = actor.joints.ForeWingL.rotation
	await settle()
	check("paused visit keeps mouth root and wing fixed",node.transform.is_equal_approx(transform) and actor.joints.ForeWingL.rotation.is_equal_approx(wing) and main.world.simulation_time_s==3)
	panel.select_topic("monarch")
	await at_time(22.0)
	check("departure retracts mouth and leaves flower",actor.joints.ProboscisCoiled.visible and not actor.joints.ProboscisExtended.visible and float(node.get_meta("flower_distance_m"))>.3)
	check("moving pair view keeps butterfly visible",subject_visible(node) and flower_visible(actor.anchor.global_position) and main.learning_overlay.last_visible_marks==3 and await visible_pixels(node)>30)
	await capture("monarch-flight")
	transform=node.transform
	wing=actor.joints.ForeWingL.rotation
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("shared clock advances both trajectory and wing articulation",main.world.simulation_time_s>22.1 and node.position.distance_to(transform.origin)>.01 and not actor.joints.ForeWingL.rotation.is_equal_approx(wing))
	await at_time(3.0)
	transform=node.transform
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	stage=main.coordinator.active_scene
	actor=stage.get_meta("pollinators")[0]
	node=actor.node
	check("return reconstructs same insect identity and flower attachment",node.get_meta("stable_id")=="3dworld:teaching:monarch:0000" and node.transform.is_equal_approx(transform) and float(node.get_meta("flower_distance_m"))<.00001 and main.world.simulation_time_s==3)
	panel.show()
	panel.object_picker.item_selected.emit(8)
	await settle()
	check("whole milkweed is independently selectable",main._content_follow==7 and subject_visible(main.content_targets()[7].node))
	await capture("milkweed-reference")
	main.world_guide.open()
	var route: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="monarch": route=button
	check("twenty-second guide route opens the real flower lesson",route!=null and main.world_guide.route_buttons.size()==22)
	if route!=null: route.pressed.emit()
	get_window().size=Vector2i(900,650)
	await at_time(22.0)
	await settle()
	check("compact lesson keeps subject and mark control visible",main.learning_overlay.topic=="monarch" and subject_visible(node) and flower_visible(actor.anchor.global_position) and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-12)
	check("lesson separates adults larvae and unmodelled pollination",panel.lesson_text.text.contains("幼虫取食乳草叶片") and panel.lesson_text.text.contains("访花不等于已经完成授粉"))
	await capture("monarch-compact")
	await finish()


func flower_visible(at: Vector3) -> bool:
	var camera: Camera3D = main.coordinator.active_scene.camera
	for offset: Vector3 in [Vector3.ZERO,Vector3(.045,0,0),Vector3(-.045,0,0),Vector3(0,.045,0),Vector3(0,-.045,0),Vector3(0,0,.045),Vector3(0,0,-.045)]:
		var point: Vector2 = camera.unproject_position(at+offset)
		if camera.is_position_behind(at+offset) or point.x<main.explorer_panel.get_global_rect().end.x+8 or point.x>get_window().size.x-8 or point.y<90 or point.y>get_window().size.y-85: return false
	return true

func visible_pixels(subject: Node3D) -> int:
	var stage: Node = main.coordinator.active_scene
	var thorax: MeshInstance3D = subject.find_child("Thorax",true,false) as MeshInstance3D
	for i: int in range(3): await RenderingServer.frame_post_draw
	var before: Image = stage.viewport.get_texture().get_image()
	var center: Vector2i = Vector2i(stage.camera.unproject_position(thorax.to_global(thorax.get_aabb().get_center())))
	subject.hide()
	for i: int in range(3): await RenderingServer.frame_post_draw
	var after: Image = stage.viewport.get_texture().get_image()
	subject.show()
	var count: int = 0
	for y: int in range(maxi(0,center.y-35),mini(before.get_height(),center.y+36)):
		for x: int in range(maxi(0,center.x-40),mini(before.get_width(),center.x+41)):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.05: count+=1
	for i: int in range(3): await RenderingServer.frame_post_draw
	print("MONARCH_VISIBLE_PIXELS ",count)
	return count
