extends "res://tests/integration/observation_framing_suite.gd"
const Turtle = preload("res://scripts/experience/turtle_motion.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world107-check="): directory=argument.trim_prefix("--world107-check=")
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
	if DisplayServer.get_name()!="headless":
		var stable_since: int = Time.get_ticks_msec()
		var deadline: int = stable_since+10000
		while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since=Time.get_ticks_msec()
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	get_window().size=Vector2i(1280,720)
	if not await arrive("reef"):
		await finish()
		return
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="turtle": action=button
	check("new guide route exists alongside all existing routes",action!=null and main.world_guide.route_buttons.size()==23)
	if action!=null: action.pressed.emit()
	await at_time(1.4)
	var turtle: Node3D = main.content_targets()[3].node
	var front: Node3D = turtle.find_child("FlipperL",true,false)
	var hind: Node3D = turtle.find_child("HindFlipperL",true,false)
	check("guide selects actual turtle and opens the lesson",main._content_follow==3 and panel._topic.get("id","")=="turtle" and not main.world_guide.visible)
	check("marine identities and counts preserved",stage.get_meta("marine_actors").size()==44 and main.content_targets().size()==7 and turtle.get_meta("stable_id")=="3dworld:teaching:marine:3:000")
	check("four original flipper pivots and reference materials are loaded",front!=null and hind!=null and turtle.find_child("FlipperR",true,false)!=null and turtle.find_child("HindFlipperR",true,false)!=null and turtle.find_child("Carapace",true,false)!=null)
	check("lesson has motion reference and underwater demonstration limits",panel.lesson_source.visible and panel.lesson_text.text.contains("8秒") and panel.lesson_text.text.contains("上浮呼吸") and Reference.allows_url("reef",Turtle.SOURCE))
	check("raised foreflipper and three live marks remain observable",front.rotation.x<-.65 and subject_visible(turtle) and main.learning_overlay.last_visible_marks==3 and await visible_pixels(turtle)>100)
	await capture("turtle-raised-flippers")
	await at_time(3.2)
	check("foreflippers sweep inward while hind pair stays tucked",front.rotation.y<-.4 and hind.rotation.is_equal_approx(Turtle.sample(3.2).hind_left) and front.rotation.x>.7)
	check("swept body and actual mesh markers remain visible",subject_visible(turtle) and Turtle.marks(turtle).size()==3 and main.learning_overlay.last_visible_marks==3)
	await capture("turtle-sweep")
	await at_time(5.)
	var before: Transform3D = turtle.transform
	var fin: Vector3 = front.rotation
	await at_time(6.)
	check("gliding advances the body without beating the front flippers",turtle.position.distance_to(before.origin)>.05 and front.rotation.is_equal_approx(fin) and panel.lesson_readout.text.contains("滑行"))
	await capture("turtle-glide")
	before=turtle.transform
	await settle()
	check("paused world freezes the real root and fins",before.is_equal_approx(turtle.transform) and front.rotation.is_equal_approx(fin) and main.world.simulation_time_s==6.)
	await at_time(.6)
	before=turtle.transform
	fin=front.rotation
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("host clock advances travel and articulated motion together",main.world.simulation_time_s>.7 and turtle.position.distance_to(before.origin)>.01 and not front.rotation.is_equal_approx(fin))
	var clearance: float = INF
	for step: int in range(145):
		var at: Vector3 = Turtle.sample(step*.5).position
		clearance=minf(clearance,at.y-stage.builder._terrain_height(stage,at.x,at.z))
	check("authored route keeps body-scale clearance above terrain",clearance>.55)
	print("TURTLE_MINIMUM_TERRAIN_CLEARANCE_M ",clearance)
	await at_time(6.)
	before=turtle.transform
	fin=front.rotation
	if not await arrive("earth") or not await arrive("reef"):
		await finish()
		return
	turtle=main.content_targets()[3].node
	front=turtle.find_child("FlipperL",true,false)
	check("reentry restores the same turtle pose at the same time",turtle.get_meta("stable_id")=="3dworld:teaching:marine:3:000" and turtle.transform.is_equal_approx(before) and front.rotation.is_equal_approx(fin) and main.world.simulation_time_s==6.)
	panel.show()
	panel.select_topic("turtle")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact lesson keeps full subject and marker control clear",subject_visible(turtle) and main.learning_overlay.last_visible_marks==3 and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-12)
	await capture("turtle-compact")
	await finish()

func visible_pixels(subject: Node3D) -> int:
	var stage: Node = main.coordinator.active_scene
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var before: Image = stage.viewport.get_texture().get_image()
	var center: Vector2i = Vector2i(stage.camera.unproject_position(subject.position))
	subject.hide()
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var after: Image = stage.viewport.get_texture().get_image()
	subject.show()
	var count: int = 0
	for y: int in range(maxi(0,center.y-30),mini(before.get_height(),center.y+31)):
		for x: int in range(maxi(0,center.x-35),mini(before.get_width(),center.x+36)):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.05: count+=1
	for frame: int in range(3): await RenderingServer.frame_post_draw
	print("TURTLE_VISIBLE_PIXELS ",count)
	return count
