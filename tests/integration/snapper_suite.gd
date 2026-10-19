extends "res://tests/integration/life_assets_suite.gd"
const Motion = preload("res://scripts/experience/snapper_motion.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world95-check="): directory = argument.trim_prefix("--world95-check=")
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
	if not await arrive("reef"):
		await finish()
		return
	await at_time(6.0)
	main._open_guide()
	var clicked: bool = false
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic")=="snapper":
			button.pressed.emit()
			clicked = true
			break
	for frame: int in range(4): await get_tree().process_frame
	check("guide opens snapper lesson and live representative",clicked and not main.world_guide.visible and main.explorer_panel._topic.get("id","")=="snapper" and main._content_follow==1)
	var stage: Node = main.coordinator.active_scene
	var leader: Node3D = main.content_targets()[1].node
	check("lesson keeps group in a wider standard view",stage.camera.position.distance_to(main._orbit_target)>2.2)
	check("source and demonstration boundaries visible",main.explorer_panel.lesson_source.visible and main.explorer_panel.lesson_text.text.contains("未模拟猎物捕获"))
	check("marine identities and counts preserved",stage.get_meta("marine_actors").size()==44 and stage.get_meta("marine_counts")["四带笛鲷"]==12 and leader.get_meta("stable_id")=="3dworld:teaching:marine:1:000")
	var grouped: float = leader.get_meta("group_distance_m")
	await capture("snapper-group-topic")
	await at_time(26.0)
	check("leader leaves group with displayed live distance",float(leader.get_meta("group_distance_m"))>grouped+.9 and Topics.readout(main,"snapper").contains("返回"))
	check("markers use current fish and actual group positions",Topics.marks(main,"snapper")[0].at==leader.position and Topics.marks(main,"snapper")[1].at==stage.get_meta("snapper_group_center"))
	await capture("snapper-inspection-turn")
	check("departing fish and group remain visible together",main.learning_overlay.last_visible_marks==2 and group_in_view(stage))
	var minimum_gap: float = INF
	var minimum_floor_clearance: float = INF
	var heading_valid: bool = true
	for t: float in [0.0,6.0,13.99,14.01,20.0,26.0,32.0,37.99,38.01,45.0,51.99,52.01]:
		await at_time(t)
		var fish: Array[Node3D] = []
		for actor: Dictionary in stage.get_meta("marine_actors"):
			if actor.kind==1: fish.append(actor.node)
		for i: int in range(fish.size()):
			var at: Vector3 = fish[i].position
			minimum_floor_clearance = minf(minimum_floor_clearance,at.y-stage.builder._terrain_height(stage,at.x,at.z))
			var tangent: Vector3 = (Motion.position_at(t+.01,i)-Motion.position_at(t-.01,i)).normalized()
			heading_valid = heading_valid and fish[i].basis.x.normalized().dot(tangent)>.99
			for j: int in range(i): minimum_gap = minf(minimum_gap,at.distance_to(fish[j].position))
	check("sampled fish keep body scale separation and terrain clearance",minimum_gap>.27 and minimum_floor_clearance>.20)
	check("actual body forward follows travel direction",heading_valid)
	var smooth_joins: bool = true
	for join: float in [14.0,38.0,52.0]:
		var left: Vector3 = Motion.position_at(join,0)-Motion.position_at(join-.01,0)
		var right: Vector3 = Motion.position_at(join+.01,0)-Motion.position_at(join,0)
		smooth_joins = smooth_joins and left.distance_to(right)<.0001
	check("departure return and loop boundaries have continuous velocity",smooth_joins)
	await at_time(45.0)
	check("leader rejoins the group",absf(float(leader.get_meta("group_distance_m"))-grouped)<.02 and str(leader.get_meta("activity")).contains("集群"))
	await capture("snapper-returned")
	main.world.set_paused(false)
	var before: Vector3 = leader.position
	var deadline: int = Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("existing world clock advances the school",leader.position.distance_to(before)>.003)
	before = leader.position
	for frame: int in range(4): await get_tree().process_frame
	check("pause freezes actual school",leader.position.is_equal_approx(before))
	if not await arrive("earth") or not await arrive("reef"):
		await finish()
		return
	check("reentry preserves representative pose at frozen world time",main.content_targets()[1].node.position.distance_to(before)<.001)
	main._open_guide()
	get_window().size = Vector2i(900,650)
	for frame: int in range(4): await get_tree().process_frame
	check("added guide route fits compact layout",main.world_guide.route_buttons.size()==15 and main.world_guide.panel.get_rect().end.x<=900 and main.world_guide.grid.columns==1)
	await capture("guide-marine-roles-compact")
	await finish()

func group_in_view(stage: Node) -> bool:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var left: float = main.explorer_panel.offset_right+24.0
	var visible_area: Rect2 = Rect2(Vector2(left,140),Vector2(viewport.x-left-24,viewport.y-280))
	for actor: Dictionary in stage.get_meta("marine_actors"):
		if actor.kind!=1: continue
		if stage.camera.is_position_behind(actor.node.position) or not visible_area.has_point(stage.camera.unproject_position(actor.node.position)): return false
	return true
