extends "res://tests/integration/land_lighting_suite.gd"
const Fish = preload("res://scripts/experience/freshwater_fish_observation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")
const Woodland = preload("res://scripts/experience/woodland_environment.gd")

## Bounded no-save Metal check of one real shoreline/water-layer/individual/guide path.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world177-review="): directory=argument.trim_prefix("--world177-review=")
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
	var data: Dictionary=stage.get_meta("freshwater_school",{})
	check("existing woodland actors and riverbank remain",stage.get_meta("actors",[]).size()==20 and stage.get_meta("frogs",[]).size()==2 and stage.get_meta("river_wetland",{}).plants.size()==9)
	check("eight freshwater fish exist as distinct real-scale objects",not data.is_empty() and data.fish.size()==8 and data.fish[0].scale.is_equal_approx(Vector3.ONE))
	if data.is_empty():
		await finish()
		return
	check("both NPS freshwater references are available",Reference.allows_url("woodland",Fish.SOURCE) and Reference.allows_url("woodland",Fish.HABITAT_SOURCE))
	var targets: Array[Dictionary]=main.content_targets()
	check("three water-layer object choices appended",targets.size()>=3 and targets[-3].node==data.center and targets[-2].node==data.fish[0])
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("shoreline still opens with original surface animals",panel.select_topic("river_wetland") and main.learning_overlay.topic=="river_wetland")
	await settle()
	await capture("riverbank-surface")
	check("freshwater school opens same river underwater",panel.select_topic("freshwater_school") and main.learning_overlay.topic=="freshwater_school" and main.content_targets()[main._content_follow].node==data.center)
	await settle()
	check("underwater camera stays below surface and above bed",stage.camera.position.y<Woodland.WATER_Y-.05 and stage.camera.position.y>Woodland.height_at(stage.camera.position.x,stage.camera.position.z)+.12)
	await capture("freshwater-school-underwater")
	check("individual near view follows actual fish",panel.select_topic("golden_shiner") and main.content_targets()[main._content_follow].node==data.fish[0])
	await settle()
	check("actual fish anatomy visible beside lesson panel",subject_visible(data.fish[0]))
	await capture("golden-shiner-close")
	var first_id: String=data.fish[0].get_meta("stable_id","")
	var first_position: Vector3=data.fish[0].position
	await at_time(17.0)
	await settle()
	check("same fish moves with host world time",data.fish[0].get_meta("stable_id","")==first_id and data.fish[0].position.distance_to(first_position)>.35 and data.center.position.distance_to(Fish.center_sample(17.).position)<.00001)
	await capture("golden-shiner-moved")
	comparisons["freshwater"]={"fish_count":data.fish.size(),"first_position":first_position,"later_position":data.fish[0].position,"world_time_s":main.world.simulation_time_s,"water_surface_y":Woodland.WATER_Y}
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var guide: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="freshwater_school": guide=button
	check("two new freshwater guide entries",guide!=null and main.world_guide.route_buttons.size()==58)
	if guide!=null: guide.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	check("guide returns to same world time and actual school",main.world.current_scale_id=="woodland" and main.learning_overlay.topic=="freshwater_school" and main.world.simulation_time_s==17.0 and main.coordinator.active_scene.get_meta("freshwater_school",{}).fish.size()==8)
	await capture("freshwater-guide-return")
	await finish()
