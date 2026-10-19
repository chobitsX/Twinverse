extends "res://tests/integration/observation_framing_suite.gd"
const Robin = preload("res://scripts/experience/robin_motion.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world103-check="): directory = argument.trim_prefix("--world103-check=")
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
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var birds: Array[Node3D] = []
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind=="bird": birds.append(actor.node)
	check("twelve existing articulated robins remain in woodland",birds.size()==12 and birds[0].get_meta("life_joints").size()==6)
	if birds.size()!=12:
		await finish()
		return
	var bird: Node3D = birds[0]
	var joints: Dictionary = bird.get_meta("life_joints")
	var plant_bounds: Array[AABB] = []
	for index: int in range(2):
		var plant: Node3D = stage.get_meta("plant_targets")[index].node
		plant_bounds.append(world_bounds(plant).grow(.3))
	var clear_plants: bool = true
	var nearest: float = INF
	for step: int in range(241):
		var positions: Array[Vector3] = []
		for k: int in range(12):
			var at: Vector3 = Robin.sample(step*.2,k).position
			at.y += stage.builder._height(at.x,at.z)+.008
			positions.append(at)
			for bounds: AABB in plant_bounds: clear_plants = clear_plants and not bounds.has_point(at)
		for k: int in range(12):
			for j: int in range(k+1,12): nearest = minf(nearest,positions[k].distance_to(positions[j]))
	check("terrain-adjusted routes clear both reference plant bounds",clear_plants)
	check("terrain-adjusted bird routes keep body-sized spacing",nearest>.25)
	print("ROBIN_TERRAIN_ROUTE_MINIMUM_GAP ",nearest)
	check("bird lesson selects its actual representative",panel.select_topic("bird") and main._content_follow==1)
	await at_time(3.1)
	var position: Vector3 = bird.position
	var leg: Vector3 = joints.BirdLegL.rotation
	await at_time(3.2)
	check("ground locomotion advances with alternating feet",bird.position.distance_to(position)>.02 and not joints.BirdLegL.rotation.is_equal_approx(leg) and joints.BirdLegL.rotation.z*joints.BirdLegR.rotation.z<0)
	await at_time(5.7)
	check("stopped inspection bends and cocks the head",joints.BirdHead.rotation.z<-.7 and joints.BirdHead.rotation.x>.17 and joints.BirdLegL.rotation.z==0)
	check("ground subject and animated markers clear the panel",subject_visible(bird) and main.learning_overlay.last_visible_marks==3)
	check("ground bird visibly renders above the local ground cover",await visible_pixels(bird)>50)
	check("readout distinguishes ground action and scene height",panel.lesson_readout.text.contains("停步") and panel.lesson_readout.text.contains("0.00 m（场景尺度）"))
	await capture("robin-ground-inspection")
	await at_time(8.0)
	var turn: Basis = bird.basis
	await at_time(8.1)
	check("stationary turn changes heading smoothly",turn.x.dot(bird.basis.x)>.97 and not bird.basis.is_equal_approx(turn))
	await at_time(21.5)
	check("takeoff preparation unfolds wings before tucking feet",absf(joints.BirdWingL.rotation.y)<.5 and joints.BirdLegL.rotation.z==0 and float(bird.get_meta("height_above_ground_m"))==0)
	await at_time(29.0)
	check("airborne bird pitches with flight and tucks feet",bird.basis.x.y>.1 and joints.BirdLegL.rotation.z< -1.9 and float(bird.get_meta("height_above_ground_m"))>.5)
	check("flight close view and three markers remain visible",subject_visible(bird) and main.learning_overlay.last_visible_marks==3 and await visible_pixels(bird)>50)
	await capture("robin-flight")
	var transform: Transform3D = bird.transform
	var wing: Vector3 = joints.BirdWingL.rotation
	await settle()
	check("world pause freezes root and articulated wing",bird.transform.is_equal_approx(transform) and joints.BirdWingL.rotation.is_equal_approx(wing) and main.world.simulation_time_s==29)
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("ordinary world clock advances root and wing together",main.world.simulation_time_s>29.1 and bird.position.distance_to(transform.origin)>.02 and not joints.BirdWingL.rotation.is_equal_approx(wing))
	await at_time(45.0)
	check("landing extends feet before reaching the ground",joints.BirdLegL.rotation.z==0 and float(bird.get_meta("height_above_ground_m"))>0 and float(bird.get_meta("height_above_ground_m"))<.06 and panel.lesson_readout.text.contains("伸足"))
	await capture("robin-landing")
	await at_time(47.5)
	transform = bird.transform
	wing = joints.BirdWingL.rotation
	check("landed bird folds wings without a heading jump",absf(joints.BirdWingL.rotation.y+1.35)<.00001 and bird.basis.is_equal_approx(Basis.IDENTITY))
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	stage = main.coordinator.active_scene
	bird = main.content_targets()[1].node
	joints = bird.get_meta("life_joints")
	check("scene return reconstructs the same identity root and joints",bird.get_meta("stable_id")=="3dworld:teaching:robin:0000" and bird.transform.is_equal_approx(transform) and joints.BirdWingL.rotation.is_equal_approx(wing) and main.world.simulation_time_s==47.5)
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="bird": action=button
	check("existing guide enters the deeper bird lesson",action!=null and main.world_guide.route_buttons.size()==21)
	if action!=null: action.pressed.emit()
	get_window().size = Vector2i(900,650)
	await at_time(12.7)
	await settle()
	check("compact bird lesson preserves subject markers and controls",main.learning_overlay.topic=="bird" and subject_visible(bird) and main.learning_overlay.last_visible_marks==3 and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-12)
	check("lesson separates source-supported behavior from authored flight",panel.lesson_text.text.contains("作者设置") and panel.lesson_text.text.contains("不是实测飞行速度"))
	await capture("robin-compact")
	await finish()

func world_bounds(root: Node3D) -> AABB:
	var result: AABB
	var first: bool = true
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func visible_pixels(bird: Node3D) -> int:
	var stage: Node = main.coordinator.active_scene
	for i: int in range(3): await RenderingServer.frame_post_draw
	var before: Image = stage.viewport.get_texture().get_image()
	var center: Vector2i = Vector2i(stage.camera.unproject_position(bird.to_global(Vector3(0,.1,0))))
	bird.hide()
	for i: int in range(3): await RenderingServer.frame_post_draw
	var after: Image = stage.viewport.get_texture().get_image()
	bird.show()
	var count: int = 0
	for y: int in range(maxi(0,center.y-35),mini(before.get_height(),center.y+36)):
		for x: int in range(maxi(0,center.x-40),mini(before.get_width(),center.x+41)):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.05: count+=1
	for i: int in range(3): await RenderingServer.frame_post_draw
	print("ROBIN_VISIBLE_PIXELS ",count)
	return count
