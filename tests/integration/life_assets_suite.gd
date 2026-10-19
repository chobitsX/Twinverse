extends "res://tests/integration/world_expansion_suite.gd"
## Short native content/interaction check, isolated from user saves; no performance run.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world86-check="): directory = argument.trim_prefix("--world86-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if not await ready_stage():
		await finish()
		return
	if DisplayServer.get_name()!="headless":
		var stable_since: int = Time.get_ticks_msec()
		var limit: int = stable_since+10000
		while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<limit:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since = Time.get_ticks_msec()
	main._reduced_motion = true
	main.world.set_paused(true)
	if "--world86-marine" in OS.get_cmdline_user_args():
		await marine_assets()
		return
	if not await arrive("woodland"):
		await finish()
		return
	main.explorer_panel.hide()
	await at_time(3.0)
	await capture("woodland-overview")
	var stage: Node = main.coordinator.active_scene
	var deer: Node3D = stage.get_meta("actors")[0].node
	check("deer imported articulated asset",deer.has_meta("life_joints") and deer.get_meta("life_joints").size()==10)
	check("forest actual leaves and ground cover",stage.world_root.find_child("CrownLeaves",true,false)!=null and stage.world_root.get_node_or_null("Understory")!=null)
	main.follow_content(1)
	await capture("deer-walking")
	var old_position: Vector3 = deer.position
	await at_time(22.0)
	var grazing_position: Vector3 = deer.position
	check("deer moves then grazes",old_position.distance_to(grazing_position)>0.4 and str(deer.get_meta("activity")).contains("取食"))
	check("grazing lowers head",deer.get_meta("life_joints").HeadPivot.rotation.z < -1.0)
	await capture("deer-grazing")
	await at_time(30.0)
	check("feeding animal stays at food patch",deer.position.distance_to(grazing_position)<0.001)
	await at_time(42.0)
	check("deer looks up",absf(deer.get_meta("life_joints").HeadPivot.rotation.z)<0.1)
	await capture("deer-alert")
	var return_position: Vector3 = deer.position
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	stage = main.coordinator.active_scene
	deer = stage.get_meta("actors")[0].node
	check("return keeps deterministic pose",deer.position.distance_to(return_position)<0.001)
	if not await arrive("city"):
		await finish()
		return
	main.explorer_panel.hide()
	await at_time(9.0)
	await capture("city-overview")
	stage = main.coordinator.active_scene
	var person: Node3D = stage.get_meta("actors")[0].node
	check("person articulated asset",person.has_meta("life_joints") and person.get_meta("life_joints").size()==8)
	main.follow_content(1)
	await capture("person-walking")
	old_position = person.position
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+1200
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("host clock moves pedestrians",person.position.distance_to(old_position)>0.1)
	old_position = person.position
	for frame: int in range(6): await get_tree().process_frame
	check("pause stops pedestrian",person.position.distance_to(old_position)<0.0001)
	await at_time(112.0)
	check("pedestrian rests between loops",str(person.get_meta("activity")).contains("停留"))
	var nearest_rest: float = INF
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind=="person" and actor.node!=person and str(actor.node.get_meta("activity")).contains("停留"):
			nearest_rest = minf(nearest_rest,actor.node.position.distance_to(person.position))
	check("resting pedestrians use distinct stopping places",nearest_rest>0.8)
	main.explorer_panel.show()
	await capture("person-resting-observer")
	main._navigate_relative(-1)
	if not await ready_stage():
		await finish()
		return
	check("city returns to Earth",main.world.current_scale_id=="earth")
	await marine_assets()

func marine_assets() -> void:
	if not await arrive("reef"):
		await finish()
		return
	main.explorer_panel.hide()
	await at_time(3.0)
	await capture("reef-diversity")
	var stage: Node = main.coordinator.active_scene
	var targets: Array[Dictionary] = main.content_targets()
	check("marine species selectable",targets.size()>=5 and str(targets[0].label).contains("Zebrasoma") and str(targets[1].label).contains("Lutjanus") and str(targets[2].label).contains("Chromis") and str(targets[3].label).contains("Chelonia") and str(targets[4].label).contains("Taeniura"))
	for index: int in range(4):
		main.follow_content(index+1)
		await capture(["brown-tang","bluestriped-snapper","blue-green-chromis","green-turtle"][index])
	main.follow_content(4)
	for pose: Dictionary in [{"time":1.4,"name":"turtle-raised"},{"time":3.2,"name":"turtle-sweep"},{"time":6.0,"name":"turtle-glide"}]:
		await at_time(pose.time)
		await capture(pose.name)
	main.follow_content(1)
	await at_time(19.0)
	check("tang feeds near authored substrate",str(targets[0].node.get_meta("activity")).contains("刮食"))
	await capture("tang-feeding")
	var turtle: Dictionary = stage.get_meta("marine_actors")[42]
	check("turtle has four articulated flippers",turtle.fins.size()==4 and turtle.fins.FlipperL!=null)
	main.follow_content(4)
	var old: Vector3 = targets[3].node.position
	var old_fin: float = turtle.fins.FlipperL.rotation.x
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+1200
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("turtle swims and paddles with world time",targets[3].node.position.distance_to(old)>0.01 and absf(turtle.fins.FlipperL.rotation.x-old_fin)>0.01)
	old = targets[3].node.position
	for frame: int in range(6): await get_tree().process_frame
	check("pause stops marine motion",targets[3].node.position.distance_to(old)<0.0001)
	main.explorer_panel.show()
	main.explorer_panel.object_picker.selected = 4
	await get_tree().process_frame
	check("species reference is available",main.explorer_panel.species_source.visible and main.explorer_panel._species_url=="https://www.fisheries.noaa.gov/species/green-turtle")
	await capture("marine-observer")
	await finish()

func at_time(seconds: float) -> void:
	main.world.simulation_time_s = seconds
	for frame: int in range(3): await get_tree().process_frame
