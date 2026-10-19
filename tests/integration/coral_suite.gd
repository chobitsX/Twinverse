extends "res://tests/integration/observation_framing_suite.gd"
const Coral = preload("res://scripts/experience/coral_observation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world109-check="): directory=argument.trim_prefix("--world109-check=")
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
	var guide_routes: Dictionary = {}
	main.world_guide.open()
	for button: Button in main.world_guide.route_buttons: guide_routes[button.get_meta("guide_topic","")]=button
	check("twenty-six guide routes include colony and attached polyp",guide_routes.has("coral_colony") and guide_routes.has("coral_polyp") and main.world_guide.route_buttons.size()==26)
	guide_routes.coral_colony.pressed.emit()
	await at_time(8.)
	var targets: Array[Dictionary] = main.content_targets()
	var root: Node3D = targets[7].node
	var detail: Node3D = targets[8].node
	var hero: Node3D = root.find_child("HeroPolyp",true,false)
	var tentacles: Array = stage.get_meta("coral_tentacles")
	check("one colony two views join preserved marine animals",targets.size()==9 and stage.get_meta("marine_actors").size()==44 and detail.get_meta("coral_root")==root and root.scale.is_equal_approx(Vector3.ONE))
	check("guide opens the actual colony and its two annotations",main._content_follow==7 and panel._topic.get("id","")=="coral_colony" and main.learning_overlay.last_visible_marks==2 and not main.world_guide.visible)
	check("colony geometry and source stay clear of the panel",subject_visible(root) and panel.lesson_source.visible)
	check("real colony contains branch tissue cups and attached mouth",root.find_child("ColonyTissue",true,false)!=null and root.find_child("CoralliteCups",true,false)!=null and hero.find_child("HeroMouth",true,false)!=null and tentacles.size()==12)
	check("total marine references and allowed sources include coral",Reference.describe("reef").basis.contains("八种") and Reference.describe("reef").sources.size()==13 and Reference.allows_url("reef",Coral.SOURCE) and Reference.allows_url("reef",Coral.SYMBIOSIS_SOURCE) and Reference.allows_url("reef",Coral.MORPHOLOGY_SOURCE))
	await capture("coral-colony")
	check("lesson selects the attached millimetre scale polyp",panel.select_topic("coral_polyp") and main._content_follow==8 and detail.position.distance_to(hero.global_position)<.001)
	await settle()
	var roots: Array[Vector3] = []
	var transforms: Array[Transform3D] = []
	for joint: Node3D in tentacles:
		roots.append(joint.global_position)
		transforms.append(joint.transform)
	check("close camera shows real polyp and three structure annotations",subject_visible(hero) and main.learning_overlay.last_visible_marks==3 and stage.camera.near<.001 and await visible_pixels(hero)>100)
	check("lesson explains symbiosis without claiming cell simulation",panel.lesson_text.text.contains("共生藻") and panel.lesson_text.text.contains("模型未放大") and panel.lesson_text.text.contains("未模拟摄食"))
	await capture("coral-attached-polyp")
	await at_time(10.)
	var moved: bool = false
	var anchored: bool = true
	for i: int in range(tentacles.size()):
		moved=moved or not tentacles[i].transform.is_equal_approx(transforms[i])
		anchored=anchored and tentacles[i].global_position.distance_to(roots[i])<.000001
	check("world time bends tentacles while their attachments stay fixed",moved and anchored and root.scale.is_equal_approx(Vector3.ONE))
	var frozen: Transform3D = tentacles[0].transform
	await settle()
	check("pause freezes actual polyp geometry",tentacles[0].transform.is_equal_approx(frozen) and main.world.simulation_time_s==10.)
	var before: float = stage.camera.position.distance_to(main._orbit_target)
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	main._unhandled_input(wheel)
	await settle()
	check("zoom continues closer without jumping to the old 25cm floor",stage.camera.position.distance_to(main._orbit_target)<before and stage.camera.position.distance_to(main._orbit_target)>=.0109 and subject_visible(hero))
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	main._unhandled_input(wheel)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.button_mask=MOUSE_BUTTON_MASK_RIGHT;drag.relative=Vector2(12,-4)
	main._unhandled_input(drag)
	await settle()
	check("orbit retains the attached structure and legible marks",subject_visible(hero) and main.learning_overlay.last_visible_marks==3)
	await capture("coral-polyp-orbit")
	panel.markers_toggle.set_pressed(false)
	await settle()
	check("polyp labels can be hidden",main.learning_overlay.last_visible_marks==0)
	panel.markers_toggle.set_pressed(true)
	panel.select_topic("coral_colony")
	await settle()
	check("returning to colony restores ordinary ocean near plane",stage.camera.near>.007 and subject_visible(root))
	if not await arrive("earth") or not await arrive("reef"):
		await finish()
		return
	stage=main.coordinator.active_scene
	root=main.content_targets()[7].node
	hero=root.find_child("HeroPolyp",true,false)
	check("reentry preserves identity and pose from the same clock",root.get_meta("stable_id")=="3dworld:teaching:acropora-millepora:0001" and stage.get_meta("coral_tentacles")[0].transform.is_equal_approx(frozen) and main.world.simulation_time_s==10.)
	panel.show()
	panel.select_topic("coral_polyp")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact polyp lesson keeps full anatomy and marker control clear",subject_visible(hero) and main.learning_overlay.last_visible_marks==3 and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-10)
	await capture("coral-polyp-compact")
	await finish()

func visible_pixels(subject: Node3D) -> int:
	var stage: Node = main.coordinator.active_scene
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var before: Image = stage.viewport.get_texture().get_image()
	var center: Vector2i = Vector2i(stage.camera.unproject_position(subject.global_position))
	subject.hide()
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var after: Image = stage.viewport.get_texture().get_image()
	subject.show()
	var count: int = 0
	for y: int in range(maxi(0,center.y-30),mini(before.get_height(),center.y+31)):
		for x: int in range(maxi(0,center.x-35),mini(before.get_width(),center.x+36)):
			var a: Color = before.get_pixel(x,y);var b: Color = after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.05: count+=1
	for frame: int in range(3): await RenderingServer.frame_post_draw
	print("CORAL_POLYP_VISIBLE_PIXELS ",count)
	return count
