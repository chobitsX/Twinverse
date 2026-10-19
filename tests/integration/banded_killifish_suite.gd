extends "res://tests/integration/land_lighting_suite.gd"
const Killifish = preload("res://scripts/experience/banded_killifish_observation.gd")
const Woodland = preload("res://scripts/experience/woodland_environment.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

## Bounded no-save Metal check of two actual species and the shared riverbed.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world181-review="): directory=argument.trim_prefix("--world181-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	get_window().size=Vector2i(1280,800)
	get_tree().create_timer(150.).timeout.connect(func() -> void:
		push_error("Banded killifish short check exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage(): await finish(); return
	var stable_since: int=Time.get_ticks_msec()
	var startup_deadline: int=stable_since+10000
	while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<startup_deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since=Time.get_ticks_msec()
	if Time.get_ticks_msec()-stable_since<2000:
		check("initial Metal window remains drawable",false)
		await finish(); return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("woodland"): await finish(); return
	await at_time(9.)
	await settle()
	var stage: Node=main.coordinator.active_scene
	var killifish: Dictionary=stage.get_meta("banded_killifish",{})
	var shiner: Dictionary=stage.get_meta("freshwater_school",{})
	var celery: Dictionary=stage.get_meta("wild_celery",{})
	check("two freshwater species and riverbed plants instantiated",not killifish.is_empty() and killifish.fish.size()==6 and shiner.fish.size()==8 and celery.clumps.size()==20)
	if killifish.is_empty(): await finish(); return
	check("original shore animals remain",stage.get_meta("frogs",[]).size()==2 and stage.get_meta("river_wetland",{}).plants.size()==9)
	check("NPS habitat source available in science panel",Reference.allows_url("woodland",Killifish.SOURCE))
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("combined topic follows real comparison target",panel.select_topic("freshwater_habitats") and main.learning_overlay.topic=="freshwater_habitats" and main.content_targets()[main._content_follow].node==killifish.comparison)
	await settle()
	check("comparison camera is underwater and above actual bed",stage.camera.position.y<Woodland.WATER_Y-.04 and stage.camera.position.y>Woodland.height_at(stage.camera.position.x,stage.camera.position.z)+.15)
	await capture("two-fish-and-celery")
	check("banded shoal topic follows actual fish group",panel.select_topic("banded_killifish_shoal") and main.content_targets()[main._content_follow].node==killifish.shoal)
	await settle()
	check("shallow group is visible under river surface",subject_visible(killifish.fish[0]) and killifish.fish[0].position.y>shiner.fish[0].position.y+.15)
	await capture("banded-killifish-shoal")
	check("individual topic follows actual first fish",panel.select_topic("banded_killifish") and main.content_targets()[main._content_follow].node==killifish.fish[0])
	await settle()
	check("near view shows actual body and three anatomy markers",subject_visible(killifish.fish[0]) and Killifish.marks(main,"banded_killifish").size()==3)
	await capture("banded-killifish-bars")
	var first_id: String=killifish.fish[0].get_meta("stable_id","")
	var first_position: Vector3=killifish.fish[0].position
	await at_time(17.)
	await settle()
	check("same fish and host world time persist while swimming",main.world.simulation_time_s==17. and killifish.fish[0].get_meta("stable_id","")==first_id and killifish.fish[0].position.distance_to(first_position)>.09 and killifish.shoal.position.distance_to(Killifish.center_sample(17.))<.0001)
	await capture("banded-killifish-moved")
	main.world_guide.open()
	var guide: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="freshwater_habitats": guide=button
	check("two new river guide entries are reachable",guide!=null and main.world_guide.route_buttons.size()==62)
	if guide!=null: guide.pressed.emit()
	await settle()
	check("guide returns to same time and real river fish",main.world.current_scale_id=="woodland" and main.learning_overlay.topic=="freshwater_habitats" and main.world.simulation_time_s==17. and main.coordinator.active_scene.get_meta("banded_killifish",{}).fish.size()==6)
	await capture("two-fish-guide-return")
	await finish()
