extends "res://tests/integration/observation_framing_suite.gd"
const Kepler = preload("res://scripts/experience/kepler_observation.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world101-check="): directory = argument.trim_prefix("--world101-check=")
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
	if not await arrive("solar_system"):
		await finish()
		return
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	var world_time: float = main.world.simulation_time_s
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	check("Mercury lesson is available in the solar system",panel.select_topic("mercury_orbit"))
	await settle()
	var stage: Node = main.coordinator.active_scene
	var root: Node3D = stage.world_root.get_node("KeplerObservation")
	var bodies: Array = stage.get_meta("solar_bodies")
	var controls: Array[Node] = panel.kepler_controls.get_child(0).get_children()
	controls[0].pressed.emit()
	await settle()
	var near_start: Vector3 = bodies[0].node.position
	var jd: float = main.solar_jd
	check("actual phase button places existing Mercury at near arc start",near_start.distance_to(Ephemeris.display_vector(0,Kepler.sample(jd).arcs[0].points[0],false))<.00001)
	check("four projected labels and the two area meshes are visible",main.learning_overlay.last_visible_marks==4 and root.visible and root.get_child_count()==5 and panel.lesson_source.visible)
	check("area meshes share the camera world and render both colours",root.get_world_3d()==stage.camera.get_world_3d() and await areas_rendered(stage))
	check("fixed reference clears explanation and viewport",subject_visible(root))
	await capture("mercury-near-start")
	panel.kepler_advance.pressed.emit()
	await settle()
	var near_end: Vector3 = bodies[0].node.position
	check("advance button changes only astronomy date by eight days",absf(main.solar_jd-jd-8)<1e-8 and main.world.simulation_time_s==world_time and main.world.paused and main.solar_rate==0)
	var near_angle: float = near_start.angle_to(near_end)
	controls[1].pressed.emit()
	await settle()
	var far_start: Vector3 = bodies[0].node.position
	panel.kepler_advance.pressed.emit()
	await settle()
	var far_angle: float = far_start.angle_to(bodies[0].node.position)
	check("visible Mercury moves over twice the angle near the Sun",near_angle/far_angle>2.1)
	check("readout states angles and swept area with model boundary",panel.lesson_readout.text.contains("AU²") and panel.lesson_text.text.contains("固定参考椭圆") and panel.lesson_text.text.contains("不是精密"))
	await capture("mercury-far-end")
	main.set_solar_rate(1.0)
	var rate_origin: float = main.solar_jd
	await at_time(world_time+2.0)
	check("existing observer clock drives lesson planet",absf(main.solar_jd-rate_origin-2.0)<.00001 and bodies[0].node.position.distance_to(Ephemeris.display_position(0,main.solar_jd,false))<.000001)
	main.set_solar_rate(0.0)
	panel.markers_toggle.set_pressed(false)
	await settle()
	check("hiding aids hides both geometry and labels",not root.visible and main.learning_overlay.last_visible_marks==0)
	panel.markers_toggle.set_pressed(true)
	main.set_solar_distance(true)
	await settle()
	check("distance switch preserves lesson and one shared AU scale",main.learning_overlay.topic=="mercury_orbit" and absf(bodies[0].node.position.length()/Ephemeris.position_au(0,main.solar_jd).length()-.55)<.000001 and subject_visible(root))
	check("both areas remain visible at true distance",await areas_rendered(stage))
	await capture("mercury-true-distance")
	var before_basis: Basis = stage.camera.basis
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	main._unhandled_input(wheel)
	await settle()
	check("zoom preserves lesson camera orientation",stage.camera.basis.is_equal_approx(before_basis))
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	drag.relative = Vector2(2,1)
	main._unhandled_input(drag)
	await settle()
	check("small drag changes view without a roll jump",before_basis.y.dot(stage.camera.basis.y)>.999 and before_basis.z.dot(stage.camera.basis.z)>.999)
	panel.kepler_controls.get_child(1).get_child(1).pressed.emit()
	await settle()
	check("orbit overview returns to face-on plane",absf(stage.camera.basis.z.dot(before_basis.z))>.99999)
	main.set_solar_date(Ephemeris.END_JD)
	await settle()
	check("eight-day advance cannot silently truncate at model limit",panel.kepler_advance.disabled)
	controls[1].pressed.emit()
	await settle()
	check("far segment remains complete at date limit",not panel.kepler_advance.disabled and main.solar_jd+8<=Ephemeris.END_JD)
	main.set_solar_distance(false)
	main.follow_planet(5)
	await settle()
	check("ordinary follow clears lesson and restores solar presentation",main.learning_overlay.topic.is_empty() and not root.visible and stage.world_root.get_node("Sun_AuthoredPhotosphere").scale.is_equal_approx(Vector3.ONE) and stage.world_root.get_node("SolarCorona_Illustration").visible and main.solar_follow==5)
	panel.select_topic("mercury_orbit")
	main._reset_camera()
	await settle()
	check("reset leaves no hidden orbit tracking or camera offset",main.learning_overlay.topic.is_empty() and stage.camera.h_offset==0 and not root.visible)
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="mercury_orbit": action=button
	check("twentieth guide route uses the real lesson",action!=null and main.world_guide.route_buttons.size()==20)
	if action!=null:
		action.pressed.emit()
		if not await ready_stage():
			await finish()
			return
	await settle()
	get_window().size = Vector2i(900,650)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	panel.select_kepler_segment(false)
	await settle()
	root = main.coordinator.active_scene.world_root.get_node("KeplerObservation")
	check("compact guide return keeps orbit and all four buttons usable",main.learning_overlay.topic=="mercury_orbit" and subject_visible(root) and panel.kepler_controls.get_global_rect().end.y<panel.get_global_rect().end.y and main.world.simulation_time_s==world_time+2.0)
	await capture("mercury-compact")
	await finish()

func areas_rendered(stage: Node) -> bool:
	if DisplayServer.get_name()=="headless": return false
	for i: int in range(3): await RenderingServer.frame_post_draw
	var rendered: Image = stage.viewport.get_texture().get_image()
	var data: Dictionary = Kepler.cached_reference(stage,main.solar_jd)
	var near_point: Vector2 = stage.camera.unproject_position(Ephemeris.display_vector(0,data.peri*.55,main.solar_true_distance))
	var far_point: Vector2 = stage.camera.unproject_position(Ephemeris.display_vector(0,data.apo*.55,main.solar_true_distance))
	var near_color: Color = rendered.get_pixelv(Vector2i(near_point))
	var far_color: Color = rendered.get_pixelv(Vector2i(far_point))
	print("KEPLER_AREA_PIXELS ",near_color," ",far_color)
	return near_color.r>.1 and near_color.r>near_color.b*1.4 and far_color.b>.1 and far_color.b>far_color.r*1.4
