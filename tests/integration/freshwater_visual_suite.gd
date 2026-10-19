extends "res://tests/integration/land_lighting_suite.gd"
const Shiner = preload("res://scripts/experience/freshwater_fish_observation.gd")
const Killifish = preload("res://scripts/experience/banded_killifish_observation.gd")

## One bounded, no-save Metal visit of the actual two-species river scene.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world185-review="): directory=argument.trim_prefix("--world185-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	get_window().size=Vector2i(1280,800)
	get_tree().create_timer(130.).timeout.connect(func() -> void:
		push_error("Freshwater visual short check exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage(): await finish(); return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("woodland"): await finish(); return
	await at_time(9.)
	await settle()
	var stage: Node=main.coordinator.active_scene
	var shiner: Dictionary=stage.get_meta("freshwater_school",{})
	var killifish: Dictionary=stage.get_meta("banded_killifish",{})
	check("both species keep their 8 and 6 actual instances",not shiner.is_empty() and not killifish.is_empty() and shiner.fish.size()==8 and killifish.fish.size()==6)
	if shiner.is_empty() or killifish.is_empty(): await finish(); return
	check("both fish replace segmented shell and separate head with one body",
		shiner.fish[0].find_child("ContinuousBody",true,false)!=null
		and killifish.fish[0].find_child("ContinuousBody",true,false)!=null
		and shiner.fish[0].find_child("Head",true,false)==null
		and killifish.fish[0].find_child("Head",true,false)==null)
	check("tail pivots and anatomy anchors survive the asset replacement",
		shiner.fish[0].find_child("TailPivot",true,false)!=null
		and shiner.fish[0].find_child("ShinerEyeAnchor",true,false)!=null
		and killifish.fish[0].find_child("TailPivot",true,false)!=null
		and killifish.fish[0].find_child("KillifishBandAnchor",true,false)!=null)
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("shared river topic retains the real two-species target",
		panel.select_topic("freshwater_habitats")
		and main.content_targets()[main._content_follow].node==killifish.comparison)
	await settle()
	check("two real fish groups remain visible underwater",subject_visible(shiner.fish[0]) and subject_visible(killifish.fish[0]))
	await capture("two-species-river")
	check("shiner close-view selects an actual fish",panel.select_topic("golden_shiner") and main.content_targets()[main._content_follow].node==shiner.fish[0])
	await settle()
	check("shiner continuous body is visible",subject_visible(shiner.fish[0]))
	await capture("shiner-close")
	check("killifish close-view selects an actual fish",panel.select_topic("banded_killifish") and main.content_targets()[main._content_follow].node==killifish.fish[0])
	await settle()
	check("killifish bars remain identifiable with actual marker anchors",
		subject_visible(killifish.fish[0]) and Killifish.marks(main,"banded_killifish").size()==3)
	await capture("killifish-close")
	var shiner_position: Vector3=shiner.fish[0].position
	var killifish_position: Vector3=killifish.fish[0].position
	var shiner_id: String=shiner.fish[0].get_meta("stable_id","")
	var killifish_id: String=killifish.fish[0].get_meta("stable_id","")
	await at_time(17.)
	await settle()
	check("one authoritative world time still moves both stable fish",
		main.world.simulation_time_s==17.
		and shiner.fish[0].get_meta("stable_id","")==shiner_id
		and killifish.fish[0].get_meta("stable_id","")==killifish_id
		and shiner.fish[0].position.distance_to(shiner_position)>.35
		and killifish.fish[0].position.distance_to(killifish_position)>.09
		and shiner.center.position.distance_to(Shiner.center_sample(17.).position)<.00001
		and killifish.shoal.position.distance_to(Killifish.center_sample(17.))<.0001)
	await finish()
