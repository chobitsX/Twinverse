extends "res://tests/integration/land_lighting_suite.gd"
const Turtle = preload("res://scripts/experience/turtle_motion.gd")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world130-check="): directory=argument.trim_prefix("--world130-check=")
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
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("reef"):
		await finish()
		return
	var stage: Node = main.coordinator.active_scene
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="turtle_surface": action=button
	check("guide adds breathing route alongside existing 39",action!=null and main.world_guide.route_buttons.size()==40)
	if action!=null: action.pressed.emit()
	await at_time(8.)
	await settle()
	var turtle: Node3D = main.content_targets()[3].node
	check("guide follows same original turtle",main._content_follow==3 and main.explorer_panel._topic.get("id","")=="turtle_surface" and turtle.get_meta("stable_id")=="3dworld:teaching:marine:3:000")
	check("underwater readout explains next ascent without gas model claim",main.explorer_panel.lesson_readout.text.contains("上浮") and main.explorer_panel.lesson_text.text.contains("不是实测") and stage.is_underwater)
	check("animal counts remain unchanged",stage.get_meta("marine_actors").size()==44 and stage.get_meta("marine_counts")["绿海龟"]==1)
	await at_time(28.)
	await settle()
	check("ascent raises actual turtle through water",turtle.position.y>3. and str(turtle.get_meta("activity")).contains("上浮") and subject_visible(turtle))
	await capture("turtle-ascent")
	await at_time(36.)
	await settle()
	var nose: Vector3 = Turtle.nose_position(turtle)
	var surface: float = Turtle.Swell.height_at(Vector2(nose.x,nose.z),36.)
	check("actual nose clears local surface at breathing dwell",nose.y-surface>.025 and nose.y-surface<.09 and str(turtle.get_meta("activity")).contains("鼻端露出"))
	var water: MeshInstance3D = stage.world_root.get_node("OceanSurface")
	check("nose comparison uses actual water owner and shared clock",water.position.y==Turtle.Swell.MEAN_LEVEL and float(stage.get_meta("ocean_surface_material").get_shader_parameter("world_time"))==36.)
	check("surface view crosses into air and retains subject and marks",not stage.is_underwater and subject_visible(turtle) and main.learning_overlay.last_visible_marks==2)
	comparisons.surface={"actual_nose_air_gap_m":nose.y-surface,"water_mean_y":water.position.y,"camera_y":stage.camera.position.y}
	await capture("turtle-breathing-surface")
	var before: Transform3D = turtle.transform
	var head: Vector3 = turtle.get_meta("breathing_head").rotation
	await settle()
	check("pause freezes surface position and head",turtle.transform.is_equal_approx(before) and turtle.get_meta("breathing_head").rotation.is_equal_approx(head) and Turtle.nose_position(turtle).is_equal_approx(nose))
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact surface view retains turtle and marker controls",subject_visible(turtle) and main.learning_overlay.last_visible_marks==2 and main.explorer_panel.markers_toggle.get_global_rect().end.y<main.explorer_panel.get_global_rect().end.y)
	await capture("turtle-breathing-compact")
	await at_time(50.)
	await settle()
	check("descent returns camera and turtle underwater",turtle.position.y<4. and stage.is_underwater and str(turtle.get_meta("activity")).contains("下潜"))
	await capture("turtle-descent")
	await at_time(36.)
	await settle()
	before=turtle.transform
	nose=Turtle.nose_position(turtle)
	if not await arrive("earth") or not await arrive("reef"):
		await finish()
		return
	turtle=main.content_targets()[3].node
	check("reentry reconstructs original identity and breathing pose",main.world.simulation_time_s==36. and turtle.transform.is_equal_approx(before) and Turtle.nose_position(turtle).is_equal_approx(nose) and turtle.get_meta("stable_id")=="3dworld:teaching:marine:3:000")
	await finish()
