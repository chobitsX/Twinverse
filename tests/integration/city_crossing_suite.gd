extends "res://tests/integration/observation_framing_suite.gd"
const Traffic = preload("res://scripts/core/city_traffic.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world102-check="): directory = argument.trim_prefix("--world102-check=")
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
	if not await arrive("city"):
		await finish()
		return
	main.ground_light_preview = false
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var actors: Array = stage.get_meta("actors")
	var people: Array = stage.get_meta("crossing_people")
	check("two existing people join crossing without changing population",actors.size()==40 and people.size()==2 and main.content_targets().size()==6 and people[0].has_meta("human_skin"))
	if not stage.has_meta("pedestrian_signals") or main.content_targets().size()!=6:
		await finish()
		return
	check("crossing lesson follows a stable intersection viewpoint",panel.select_topic("crossing") and main._content_follow==4)
	await at_time(4.0)
	await settle()
	var root: Node3D = stage.world_root.get_node("WestPedestrianCrossing")
	check("corner ramps and signals belong to the rendered city",root.get_world_3d()==stage.camera.get_world_3d() and stage.get_meta("pedestrian_signals").size()==2)
	var ramp: MeshInstance3D = root.get_node("CurbRampSouth")
	var arrays: Array = ramp.mesh.surface_get_arrays(0)
	var ramp_up: bool = true
	for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: ramp_up = ramp_up and normal.y>.98
	check("ramp joins the lower road and raised corner",ramp_up and absf(ramp.get_aabb().position.y-.04)<.00001 and absf(ramp.get_aabb().end.y-.16)<.00001)
	check("waiting people and readout match the visible signal",str(people[0].get_meta("activity")).contains("等待") and stage.get_meta("pedestrian_signals")[0].label.text.contains("等待") and panel.lesson_readout.text.contains("横向车辆通行"))
	check("intersection and both waiting people clear the explanation",subject_visible(root) and subject_visible(people[0]) and subject_visible(people[1]) and main.learning_overlay.last_visible_marks==3)
	check("both waiting people actually render beyond foreground buildings",await person_visible_pixels(people[0]) and await person_visible_pixels(people[1]))
	await capture("crossing-wait")
	await at_time(25.0)
	await settle()
	check("start interval visibly permits the waiting pedestrians",stage.get_meta("pedestrian_signals")[0].label.text.contains("通行") and str(people[0].get_meta("activity")).contains("过街"))
	await at_time(32.0)
	await settle()
	check("crossing uses the same world time and directional lanes",absf(people[0].position.z)<.01 and people[1].position.z>0 and absf(people[0].position.x-people[1].position.x)>1.1 and panel.lesson_readout.text.contains("新到者等待"))
	var waiting_cars: int = 0
	var bounds_valid: bool = true
	for actor: Dictionary in actors:
		if actor.kind!="car": continue
		var car: Node3D = actor.node
		if actor.index<6 and car.visible and str(car.get_meta("activity")).contains("等待"): waiting_cars+=1
		var bounds: AABB = imported_bounds(car)
		bounds_valid = bounds_valid and maxf(absf(bounds.position.x),absf(bounds.end.x))<2.5 and maxf(absf(bounds.position.z),absf(bounds.end.z))<1.05
	check("three horizontal vehicles wait while pedestrians cross",waiting_cars==3)
	check("imported vehicle dimensions fit checked conservative envelopes",bounds_valid)
	var signals: Array = stage.get_meta("signals")
	check("perpendicular vehicle signal shares the traffic phase",signals[0].red.emission.r>.9 and signals[0].green.emission==Color.BLACK and signals[1].green.emission.g>.9)
	await capture("crossing-in-progress")
	panel.object_picker.item_selected.emit(6)
	await settle()
	check("representative crosser can be followed closely",main._content_follow==5 and main.learning_overlay.topic.is_empty() and subject_visible(people[0]))
	await capture("crossing-person")
	var skin: Dictionary = people[0].get_meta("human_skin")
	var knee: Quaternion = skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id)
	var position: Vector3 = people[0].position
	await settle()
	check("pause freezes crossing roots and bone pose",people[0].position.is_equal_approx(position) and knee.is_equal_approx(skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id)) and main.world.simulation_time_s==32)
	await at_time(32.3)
	check("world advance moves root and deforms walking knee",people[0].position.distance_to(position)>.25 and knee.angle_to(skin.skeleton.get_bone_pose_rotation(skin.bones.LegLKnee.id))>.01)
	await at_time(44.0)
	check("arrival leaves both pedestrians behind the curb",absf(people[0].position.z)>8 and absf(people[1].position.z)>8 and str(people[0].get_meta("activity")).contains("到达"))
	position = people[0].position
	if not await arrive("earth") or not await arrive("city"):
		await finish()
		return
	await settle()
	stage = main.coordinator.active_scene
	people = stage.get_meta("crossing_people")
	check("scene return preserves identity position and shared time",people[0].get_meta("stable_id")=="3dworld:teaching:crossing-person:0000" and people[0].position.distance_to(position)<.00001 and main.world.simulation_time_s==44)
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="crossing": action=button
	check("twenty-first guide route enters the real crossing lesson",action!=null and main.world_guide.route_buttons.size()==21)
	if action!=null: action.pressed.emit()
	await settle()
	get_window().size = Vector2i(900,650)
	await at_time(32.0)
	await settle()
	check("compact view keeps crossing and both people observable",main.learning_overlay.topic=="crossing" and subject_visible(stage.world_root.get_node("WestPedestrianCrossing")) and subject_visible(people[0]) and subject_visible(people[1]) and panel.topic_picker.get_global_rect().end.y<panel.get_global_rect().end.y)
	await capture("crossing-compact")
	check("lesson states authored rules and physical limits",panel.lesson_text.text.contains("作者规则") and panel.lesson_text.text.contains("只有直行车"))
	await finish()

func imported_bounds(root: Node3D) -> AABB:
	var bounds: AABB
	var first: bool = true
	for item: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = item as MeshInstance3D
		var local: Transform3D = root.global_transform.affine_inverse()*mesh.global_transform
		var item_bounds: AABB = local*mesh.get_aabb()
		bounds = item_bounds if first else bounds.merge(item_bounds)
		first = false
	return bounds

func person_visible_pixels(person: Node3D) -> bool:
	var stage: Node = main.coordinator.active_scene
	for i: int in range(3): await RenderingServer.frame_post_draw
	var with_person: Image = stage.viewport.get_texture().get_image()
	var center: Vector2i = Vector2i(stage.camera.unproject_position(person.position+Vector3(0,1.2,0)))
	person.hide()
	for i: int in range(3): await RenderingServer.frame_post_draw
	var without_person: Image = stage.viewport.get_texture().get_image()
	person.show()
	var visible_pixels: int = 0
	for y: int in range(maxi(0,center.y-5),mini(with_person.get_height(),center.y+6)):
		for x: int in range(maxi(0,center.x-4),mini(with_person.get_width(),center.x+5)):
			var a: Color = with_person.get_pixel(x,y)
			var b: Color = without_person.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.05: visible_pixels+=1
	for i: int in range(3): await RenderingServer.frame_post_draw
	print("CROSSING_VISIBLE_TORSO_PIXELS ",visible_pixels)
	return visible_pixels>=4
