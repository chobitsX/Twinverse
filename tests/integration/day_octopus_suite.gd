extends "res://tests/integration/observation_framing_suite.gd"
const Octopus = preload("res://scripts/experience/day_octopus.gd")
const Science = preload("res://scripts/experience/science_reference.gd")
const Species = preload("res://scripts/experience/species_catalog.gd")
var observations: Dictionary = {}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world223-review="): directory = argument.trim_prefix("--world223-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size = Vector2i(1280,800)
	get_window().unfocusable = true
	# This diagnostic drives real control signals; desktop mouse/key events
	# must not alter its sequence or consume the user's work input.
	get_viewport().gui_disable_input = true
	check("diagnostic window ignores native input", get_viewport().gui_disable_input and get_window().unfocusable)
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	if not await ready_stage():
		await finish(); return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("reef"):
		await finish(); return
	var stage: Node = main.coordinator.active_scene
	var data: Dictionary = stage.get_meta("day_octopus", {})
	check("one named cephalopod is present in the real reef", not data.is_empty())
	if data.is_empty():
		await finish(); return
	var root: Node3D = data.root
	var targets: Array[Dictionary] = main.content_targets()
	var old_time: float = main.world.simulation_time_s
	var old_transform: Transform3D = root.transform
	var old_date: float = main.solar_jd
	check("two stable views keep the same unscaled specimen", targets.size() == 19 and targets[17].node == root and targets[18].node.get_meta("octopus_root") == root and root.scale.is_equal_approx(Vector3.ONE))
	check("eight continuous arms and two sucker rows per arm import", root.find_children("ContinuousArm*","MeshInstance3D",true,false).size() == 8 and root.find_children("DoubleSuckerRows*","MeshInstance3D",true,false).size() == 8)
	var mantle: MeshInstance3D = root.find_child("OvoidMantle12cm",true,false) as MeshInstance3D
	var web: MeshInstance3D = root.find_child("ShallowInterbrachialWeb",true,false) as MeshInstance3D
	var arm: MeshInstance3D = root.find_child("ContinuousArm00",true,false) as MeshInstance3D
	var cups: MeshInstance3D = root.find_child("DoubleSuckerRows00",true,false) as MeshInstance3D
	check("mantle remains twelve centimetres and shallow web is geometry", mantle != null and web != null and absf(mantle.mesh.get_aabb().size.x - .120) < .00001)
	if mantle == null or arm == null or cups == null:
		check("named arm and cup meshes are available for observation", false)
		await finish(); return
	var measured_mantle: float = mantle.mesh.get_aabb().size.x
	var arm_material: ShaderMaterial = arm.get_active_material(0) as ShaderMaterial
	var cup_material: ShaderMaterial = cups.get_active_material(0) as ShaderMaterial
	check("arm and cups share the same time deformation shader", arm_material != null and cup_material != null and arm_material.shader == cup_material.shader and stage.materials.has(arm_material) and stage.materials.has(cup_material))
	check("brown pigment and pale comparison are enabled on skin", bool(arm_material.get_shader_parameter("use_vertex_color")) and bool(arm_material.get_shader_parameter("skin_color_comparison")) and not bool(cup_material.get_shader_parameter("skin_color_comparison")))
	check("placement uses original terrain without moving old coral objects", absf(root.position.y-stage.builder._terrain_height(stage,root.position.x,root.position.z)) < .000001 and stage.get_meta("reef_placement_mode") == "baked" and stage.get_meta("clam_root",null) != null and stage.get_meta("holothuria_root",null) != null and targets[11].node == stage.get_meta("target_node"))
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	check("whole lesson selects the existing cephalopod", panel.select_topic("day_octopus") and main._content_follow == 17 and panel.octopus_controls.visible)
	await settle()
	check("whole animal stays outside explanation with both structure marks", subject_visible(root) and main.learning_overlay.last_visible_marks == 2)
	check("source and author limits are visible", panel.lesson_source.visible and panel.lesson_text.text.contains("Octopus cyanea") and panel.lesson_text.text.contains("448个") and panel.lesson_text.text.contains("不模拟环境识别") and Science.allows_url("reef",Octopus.SOURCE) and Science.allows_url("reef",Octopus.MORPHOLOGY_SOURCE))
	await capture("octopus-whole-brown")
	panel.octopus_controls.get_child(1).pressed.emit()
	await settle()
	check("pale reference changes same materials without changing world or pose", bool(stage.get_meta("day_octopus").pale) and float(arm_material.get_shader_parameter("pale_amount")) == 1.0 and main.world.simulation_time_s == old_time and root.transform.is_equal_approx(old_transform) and main.solar_jd == old_date)
	await capture("octopus-whole-pale")
	panel.octopus_controls.get_child(0).pressed.emit()
	await settle()
	check("brown reference can be restored explicitly", not bool(stage.get_meta("day_octopus").pale) and float(arm_material.get_shader_parameter("pale_amount")) == 0.0)
	check("close lesson selects same arm and its double cups", panel.select_topic("day_octopus_suckers") and main._content_follow == 18 and targets[18].node.get_meta("octopus_root") == root)
	await settle()
	var anchor: Vector3 = data.arm_view.position
	var image_point: Vector2 = stage.camera.unproject_position(anchor)
	check("actual cup anchor is visible beside explanation", panel.is_visible_in_tree() and image_point.x > panel.get_global_rect().end.x + 8 and image_point.x < get_window().size.x - 8 and image_point.y > 120 and image_point.y < 680 and main.learning_overlay.last_visible_marks >= 1)
	await capture("octopus-suckers")
	main.world.simulation_time_s = 4.0
	await settle()
	var moved: Vector3 = stage.get_meta("day_octopus").arm_view.position
	check("world seconds drive cup anchor and real mesh shader together", float(arm_material.get_shader_parameter("world_time")) == 4.0 and float(cup_material.get_shader_parameter("world_time")) == 4.0 and absf(moved.y-anchor.y) > .001 and root.transform.is_equal_approx(old_transform))
	await capture("octopus-suckers-time4")
	await settle()
	check("pause leaves actual reference pose and shader time unchanged", main.world.paused and main.world.simulation_time_s == 4.0 and stage.get_meta("day_octopus").arm_view.position.is_equal_approx(moved) and float(cup_material.get_shader_parameter("world_time")) == 4.0)
	main.world.simulation_time_s = old_time
	await settle()
	check("returning to same world second restores same arm reference", stage.get_meta("day_octopus").arm_view.position.is_equal_approx(anchor))
	get_window().size = Vector2i(900,650)
	panel.select_topic("day_octopus")
	await settle()
	check("compact whole animal and two color controls are usable", panel.is_visible_in_tree() and subject_visible(root) and panel.octopus_controls.get_global_rect().end.y < panel.get_global_rect().end.y and panel.octopus_controls.get_global_rect().end.x < 900)
	await capture("octopus-compact")
	get_window().size = Vector2i(1280,800)
	if not await arrive("earth"):
		await finish(); return
	main._open_guide()
	main.world_guide.species_button.pressed.emit()
	await settle()
	var atlas: Node = main.world_guide.species_atlas
	atlas.search.text = "OCTOPUS CYANEA"
	atlas.search.text_changed.emit(atlas.search.text)
	await settle()
	check("atlas lists forty species once and finds the new scientific name", Species.ENTRIES.size() == 40 and atlas.cards.size() == 40 and atlas.visible_ids() == ["cyanea"])
	check("guide preserves eight groups and current lesson actions", main.world_guide.route_buttons.size() == 86 and main.world_guide.cards.size() == 8)
	await capture("octopus-atlas")
	for card: Dictionary in atlas.cards:
		if card.entry.id == "cyanea": card.button.pressed.emit(); break
	if not await ready_stage():
		await finish(); return
	await settle()
	stage = main.coordinator.active_scene
	check("atlas action enters actual octopus and keeps world authority", main.world.current_scale_id == "reef" and main.learning_overlay.topic == "day_octopus" and stage.get_meta("day_octopus").root.get_meta("stable_id") == "3dworld:teaching:octopus-cyanea:0000" and main.world.simulation_time_s == old_time and main.solar_jd == old_date)
	await capture("octopus-atlas-visit")
	if not await arrive("earth"):
		await finish(); return
	main._open_guide()
	var guide_action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic", "") == "day_octopus_suckers": guide_action = button
	check("guide exposes direct same-arm observation", guide_action != null)
	if guide_action != null: guide_action.pressed.emit()
	if not await ready_stage():
		await finish(); return
	await settle()
	check("guide same-arm visit uses actual model and paused time", main.world.current_scale_id == "reef" and main.learning_overlay.topic == "day_octopus_suckers" and main.world.simulation_time_s == old_time)
	if not await arrive("earth"):
		await finish(); return
	check("normal return clears local color controls and keeps time", not panel.octopus_controls.visible and main.world.simulation_time_s == old_time)
	observations = {"species_count":40,"guide_actions":86,"arms":8,"author_suckers":448,
		"mantle_length_m":measured_mantle,
		"world_time_s":old_time,"body_pose_unchanged":true,"color_is_view_comparison":true,
		"native_input_disabled":get_viewport().gui_disable_input,"screen_count":DisplayServer.get_screen_count(),
		"window_screen":get_window().current_screen,"primary_screen":DisplayServer.get_primary_screen()}
	await finish()

func finish() -> void:
	var report: Dictionary = {"cases":cases,"failures":failures,"captures":captures,
		"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"performance_test":false,"native_ime_tested":false}
	var file: FileAccess = FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("OCTOPUS_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
