extends "res://tests/integration/land_lighting_suite.gd"
const Traffic = preload("res://scripts/core/city_traffic.gd")
const Park = preload("res://scripts/experience/city_walk_path.gd")
const Motion = preload("res://scripts/experience/life_asset_motion.gd")

func ankle(person: Node3D, key: String) -> Vector3:
	var skin: Dictionary = person.get_meta("human_skin")
	return skin.skeleton.to_global(skin.skeleton.get_bone_global_pose(skin.bones[key].id).origin)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world128-check="): directory=argument.trim_prefix("--world128-check=")
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
	if not await arrive("city"):
		await finish()
		return
	main.ground_light_preview=false
	main.explorer_panel.show()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var actors: Array = stage.get_meta("actors")
	var people: Array = stage.get_meta("crossing_people")
	check("city retains 28 people and 12 cars",actors.size()==40 and people.size()==2)
	check("crossing lesson available",main.explorer_panel.select_topic("crossing"))
	await at_time(32.)
	await settle()
	check("both people actually crossing",str(people[0].get_meta("activity")).contains("过街") and str(people[1].get_meta("activity")).contains("过街"))
	await capture("walking-intersection")
	main.explorer_panel.object_picker.item_selected.emit(6)
	await settle()
	check("close view follows the real person",main.content_targets()[main._content_follow].node==people[0] and subject_visible(people[0]))
	await capture("walking-person-a")
	var a: Vector3 = ankle(people[0],"FootL")
	var root_a: Vector3 = people[0].position
	await at_time(32.02)
	await settle()
	var b: Vector3 = ankle(people[0],"FootL")
	# At t=32 left foot is within stance under the actual traveled-distance phase.
	check("rendered skeleton keeps planted left ankle still while body advances",a.distance_to(b)<.0001 and people[0].position.distance_to(root_a)>.02)
	comparisons.crossing_stance={"ankle_drift_m":a.distance_to(b),"root_travel_m":people[0].position.distance_to(root_a),"delta_s":.02}
	var frozen: Vector3 = ankle(people[0],"FootR")
	await settle()
	check("pause freezes both body and skeleton",ankle(people[0],"FootR").is_equal_approx(frozen) and main.world.simulation_time_s==32.02)
	await at_time(32.3)
	await settle()
	await capture("walking-person-b")
	main.explorer_panel.object_picker.item_selected.emit(1)
	await at_time(47.6)
	await settle()
	var park_person: Node3D = actors[0].node
	check("park root uses smooth slowing itinerary",park_person.position.distance_to(Park.itinerary(47.6,0,26).position+Vector3(0,Motion.person_root_offset(.5),0))<.001)
	await at_time(48.)
	await settle()
	var standing: Vector3 = park_person.position
	var standing_ankle: Vector3 = ankle(park_person,"FootL")
	await at_time(51.)
	await settle()
	check("park rest holds body and planted ankle",park_person.position.is_equal_approx(standing) and ankle(park_person,"FootL").is_equal_approx(standing_ankle) and str(park_person.get_meta("activity")).contains("停留"))
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact resting person remains visible",subject_visible(park_person))
	await capture("park-rest-compact")
	if not await arrive("earth") or not await arrive("city"):
		await finish()
		return
	var returned: Node3D = main.coordinator.active_scene.get_meta("actors")[0].node
	check("return restores same time body and bone pose",main.world.simulation_time_s==51. and returned.position.is_equal_approx(standing) and ankle(returned,"FootL").is_equal_approx(standing_ankle))
	await finish()
