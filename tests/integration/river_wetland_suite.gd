extends "res://tests/integration/land_lighting_suite.gd"
const Wetland = preload("res://scripts/experience/river_wetland_observation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

## Bounded real-Metal visual check; the app's ordinary save and performance paths are untouched.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world173-review="): directory=argument.trim_prefix("--world173-review=")
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
	get_window().size=Vector2i(1280,800)
	# macOS can briefly report the resized secondary window as unavailable.
	# Let it draw steadily before starting the first transition.
	var stable_since: int=Time.get_ticks_msec()
	var startup_deadline: int=stable_since+10000
	while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<startup_deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since=Time.get_ticks_msec()
	if not await arrive("woodland"):
		await finish()
		return
	await at_time(9.0)
	await settle()
	var stage: Node=main.coordinator.active_scene
	var data: Dictionary=stage.get_meta("river_wetland",{})
	check("woodland keeps existing actors and frogs",stage.get_meta("actors",[]).size()==20 and stage.get_meta("frogs",[]).size()==2)
	check("new riverbank has nine cattails and one real-scale darner",not data.is_empty() and data.plants.size()==9 and data.darner!=null)
	if data.is_empty():
		await finish()
		return
	var darner: Node3D=data.darner
	var stable_id: String=str(darner.get_meta("stable_id",""))
	var targets: Array[Dictionary]=main.content_targets()
	var overview_found: bool=false
	var darner_found: bool=false
	for target: Dictionary in targets:
		overview_found=overview_found or target.node==data.overview
		darner_found=darner_found or target.node==darner
	check("riverbank objects remain selectable after later content additions",overview_found and darner_found)
	check("both NPS source links available",Reference.allows_url("woodland",Wetland.CATTAIL_SOURCE) and Reference.allows_url("woodland",Wetland.DARNER_SOURCE))
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("wetland topic selects same riverbank",panel.select_topic("river_wetland") and main.learning_overlay.topic=="river_wetland" and main.world.simulation_time_s==9.)
	await settle()
	await capture("wetland-overview")
	check("cattail topic selects actual planted individual",panel.select_topic("cattail") and main.content_targets()[main._content_follow].node==data.plants[2])
	await settle()
	check("cattail blade and both spike sections visible in scene",data.plants[2].find_child("ReferenceBroadLeaf",true,false)!=null and data.plants[2].find_child("FemaleSeedSpike",true,false)!=null and data.plants[2].find_child("UpperMaleSpike",true,false)!=null)
	await capture("cattail-leaf-spike")
	check("dragonfly topic follows the same adult",panel.select_topic("green_darner") and main.content_targets()[main._content_follow].node==darner)
	await settle()
	check("near view retains true-scale four wings",data.wings.size()==4 and darner.scale.is_equal_approx(Vector3.ONE) and subject_visible(darner))
	var first_position: Vector3=darner.position
	await capture("darner-close")
	await at_time(13.5)
	await settle()
	check("host time moves same dragonfly along authored river route",darner.get_meta("stable_id","")==stable_id and darner.position.distance_to(first_position)>.45 and darner.position.distance_to(Wetland.darner_sample(13.5).position)<.0001)
	await capture("darner-moved")
	comparisons["wetland"]={"cattails":data.plants.size(),"darner_id":stable_id,"first_position":first_position,"later_position":darner.position,"world_time_s":main.world.simulation_time_s}
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var guide: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="river_wetland": guide=button
	check("riverbank guide entry remains after later content additions",guide!=null)
	if guide!=null: guide.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	check("guide returns to same world time and wetland lesson",main.world.current_scale_id=="woodland" and main.learning_overlay.topic=="river_wetland" and main.world.simulation_time_s==13.5 and main.coordinator.active_scene.get_meta("river_wetland",{}).plants.size()==9)
	await capture("wetland-guide-return")
	await finish()
