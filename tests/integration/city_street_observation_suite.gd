extends "res://tests/integration/observation_framing_suite.gd"
const StreetRoutes = preload("res://scripts/experience/city_street_walk_path.gd")
const NamedLife = preload("res://scripts/experience/species_catalog.gd")
var observations: Dictionary = {}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world224-review="): directory = argument.trim_prefix("--world224-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size = Vector2i(1280,800)
	get_window().unfocusable = true
	# Drive actual controls and pointer methods without consuming desktop input.
	get_viewport().gui_disable_input = true
	check("diagnostic ignores native desktop input", get_window().unfocusable and get_viewport().gui_disable_input)
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	if not await ready_stage():
		await finish(); return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("city"):
		await finish(); return
	await at_time(9.0)
	var old_date: float = main.solar_jd
	var stage: Node = main.coordinator.active_scene
	var walkers: Array = stage.get_meta("street_walkers", [])
	var entries: Array[Dictionary] = stage.get_meta("street_walker_targets", [])
	check("six existing walkers become six observation entries", walkers.size() == 6 and entries.size() == 6)
	if walkers.size() != 6 or entries.size() != 6:
		await finish(); return
	var original_people: int = 0
	var cars: int = 0
	for actor: Dictionary in stage.get_meta("actors", []):
		if actor.kind == "person": original_people += 1
		if actor.kind == "car": cars += 1
	check("original population and car roots are preserved", original_people == 28 and cars == 12 and stage.get_meta("actors", []).size() == 40)
	var target_indices: Array[int] = []
	var unique_ids: Dictionary = {}
	var existing_roots: bool = true
	var targets: Array[Dictionary] = main.content_targets(false)
	for index: int in range(6):
		var root: Node3D = walkers[index]
		var identity: String = str(root.get_meta("stable_id", ""))
		unique_ids[identity] = true
		existing_roots = existing_roots and identity == "3dworld:teaching:street-walker:%04d" % index and entries[index].node == root and root.get_parent() == stage.world_root and root.has_meta("human_skin")
		for slot: int in range(targets.size()):
			if targets[slot].node == root: target_indices.append(slot); break
	check("entries point to original skinned roots and unique stable ids", existing_roots and unique_ids.size() == 6)
	check("all six individual menu slots follow existing city entries", target_indices.size() == 6 and target_indices[0] == targets.size()-6 and target_indices[5] == targets.size()-1)
	if target_indices.size() != 6:
		await finish(); return
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	var labels_match: bool = panel.object_picker.item_count == targets.size()+1
	for index: int in range(6):
		labels_match = labels_match and panel.object_picker.get_item_text(target_indices[index]+1) == "街道人行道行人 %d" % (index+1)
	check("actual object menu exposes six distinct numbered people", labels_match)
	var pointer: Node = main.object_pointer
	pointer.rebuild(stage)
	var registered: bool = true
	for index: int in range(6):
		var root: Node3D = walkers[index]
		var choice: Dictionary = pointer.choices.get(root.get_instance_id(), {})
		registered = registered and choice.get("node") == root and choice.get("index", -1) == target_indices[index]
	check("real picker registers every original street person", registered)
	panel.hide()
	main._reset_camera()
	main.next_button.pressed.emit()
	main.next_button.pressed.emit()
	await settle()
	check("existing street view and paused world second remain available", main._city_street_view and not main._city_people_view and main.world.simulation_time_s == 9.0)
	await capture("street-overview")
	var visible_pick: Dictionary = {}
	for root: Node3D in walkers:
		for height: float in [.9,1.35,.5]:
			var world_point: Vector3 = root.global_position+Vector3(0,height,0)
			var point: Vector2 = stage.camera.unproject_position(world_point)
			if stage.camera.is_position_behind(world_point) or not Rect2(24,150,1232,570).has_point(point): continue
			var choice: Dictionary = pointer.pick(point)
			if choice.get("node") == root:
				visible_pick = {"point":point,"node":root,"id":root.get_meta("stable_id"),"index":choice.index}
				break
		if not visible_pick.is_empty(): break
	check("real visible street geometry picks its original person", not visible_pick.is_empty())
	var picked_identity: String = ""
	if not visible_pick.is_empty():
		picked_identity = str(visible_pick.id)
		var press: InputEventMouseButton = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = visible_pick.point
		press.pressed = true
		var release: InputEventMouseButton = press.duplicate()
		release.pressed = false
		pointer.pointer(press)
		pointer.pointer(release)
		await settle()
		check("pointer press release selects same root without copying it", main.content_targets()[main._content_follow].node == visible_pick.node and main._content_follow == visible_pick.index and main._direct_content.get("node") == visible_pick.node and panel.visible)
		var expected_offset: Vector3 = visible_pick.node.basis.orthonormalized()*Vector3(entries[0].view_offset_local)
		check("pointer close view uses current heading independent of stature", (stage.camera.position-main._orbit_target).is_equal_approx(expected_offset))
		check("picked person's actual body clears explanation", subject_visible(visible_pick.node))
		await capture("street-pointer-person")
	check("new lesson follows the first existing street person", panel.select_topic("street_walkers") and main._content_follow == target_indices[0] and main.learning_overlay.topic == "street_walkers")
	await settle()
	var first: Node3D = walkers[0]
	var first_pose: Transform3D = first.transform
	var same_root: int = first.get_instance_id()
	var skin: Dictionary = first.get_meta("human_skin")
	var knee_pose: Quaternion = skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id)
	check("lesson gives synthetic limits and hides unused marker control", panel._topic.observe.contains("六位") and panel._topic.limit.contains("避让") and panel._topic.limit.contains("现实人口") and panel.is_visible_in_tree() and not panel.markers_toggle.visible)
	check("first person fits beside the real lesson panel", subject_visible(first))
	await capture("street-person-lesson")
	await settle()
	check("pause preserves original root and actual knee pose", first.get_instance_id() == same_root and first.transform.is_equal_approx(first_pose) and skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id).is_equal_approx(knee_pose) and main.world.paused and main.world.simulation_time_s == 9.0)
	var camera_offset: Vector3 = stage.camera.position-main._orbit_target
	await at_time(13.0)
	await settle()
	var moved_pose: Dictionary = StreetRoutes.sample(13.0,0)
	check("same authoritative seconds move original route and knee", first.get_instance_id() == same_root and absf(first.position.x-moved_pose.position.x) < .0001 and absf(first.position.z-moved_pose.position.z) < .0001 and first.position.distance_to(first_pose.origin) > 3.0 and not skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id).is_equal_approx(knee_pose))
	check("camera follows the same moving body at constant offset", main.content_targets()[main._content_follow].node == first and main._orbit_target.is_equal_approx(first.position+Vector3(0,.95,0)) and (stage.camera.position-main._orbit_target).is_equal_approx(camera_offset))
	await at_time(9.0)
	await settle()
	check("return to same second restores original body and knee", first.transform.is_equal_approx(first_pose) and skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id).is_equal_approx(knee_pose) and main.solar_jd == old_date)
	panel.object_picker.item_selected.emit(target_indices[2]+1)
	await settle()
	var second: Node3D = walkers[2]
	check("real menu changes body and selection message together", main.content_targets()[main._content_follow].node == second and main._direct_content.is_empty() and main.learning_overlay.topic.is_empty() and second.get_meta("appearance_variant") != first.get_meta("appearance_variant") and main.message_label.text.contains("街道人行道行人 3"))
	check("second actual body remains clear beside menu", subject_visible(second))
	await capture("street-second-person")
	get_window().size = Vector2i(900,650)
	panel.select_topic("street_walkers")
	await settle()
	check("compact window keeps full body and lesson usable", panel.is_visible_in_tree() and subject_visible(first) and panel.get_global_rect().end.x < 900 and panel.topic_picker.get_global_rect().end.y < panel.get_global_rect().end.y)
	await capture("street-person-compact")
	get_window().size = Vector2i(1280,800)
	if not await arrive("earth"):
		await finish(); return
	check("return clears street selection with same world authority", main._content_follow == -1 and main._direct_content.is_empty() and main.world.simulation_time_s == 9.0 and main.solar_jd == old_date)
	main._open_guide()
	await settle()
	var guide_action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic", "") == "street_walkers": guide_action = button; break
	check("guide exposes actual street action and current species count", guide_action != null and main.world_guide.route_buttons.size() == 86 and main.world_guide.cards.size() == 8 and NamedLife.ENTRIES.size() == 40 and main.world_guide.species_atlas.cards.size() == 40)
	if guide_action != null: guide_action.pressed.emit()
	if not await ready_stage():
		await finish(); return
	await settle()
	stage = main.coordinator.active_scene
	check("actual guide button enters the same authored person identity", main.world.current_scale_id == "city" and main.learning_overlay.topic == "street_walkers" and main.content_targets()[main._content_follow].node.get_meta("stable_id") == "3dworld:teaching:street-walker:0000" and main.world.simulation_time_s == 9.0 and main.solar_jd == old_date)
	await capture("street-guide-visit")
	observations = {"street_people":walkers.size(),"original_people":original_people,"total_people":original_people+walkers.size(),"cars":cars,"species_count":NamedLife.ENTRIES.size(),"guide_actions":main.world_guide.route_buttons.size(),"unique_street_ids":unique_ids.keys(),"picked_identity":picked_identity,"menu_indices":target_indices,"native_input_disabled":get_viewport().gui_disable_input,"screen_count":DisplayServer.get_screen_count(),"window_screen":get_window().current_screen,"primary_screen":DisplayServer.get_primary_screen(),"world_time_s":main.world.simulation_time_s,"routes_unchanged":true}
	if not await arrive("earth"):
		await finish(); return
	check("guide return keeps time and clears local person observation", main.learning_overlay.topic.is_empty() and main._content_follow == -1 and main.world.simulation_time_s == 9.0)
	await finish()

func finish() -> void:
	var report: Dictionary = {"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false}
	var file: FileAccess = FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("STREET_OBSERVATION_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
