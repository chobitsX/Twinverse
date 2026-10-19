extends "res://tests/integration/land_lighting_suite.gd"
const Celery = preload("res://scripts/experience/wild_celery_observation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")
const Woodland = preload("res://scripts/experience/woodland_environment.gd")

## Bounded no-save Metal check of one real fish/riverbed/plant/guide path.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world178-review="): directory=argument.trim_prefix("--world178-review=")
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
	var data: Dictionary=stage.get_meta("wild_celery",{})
	var fish: Dictionary=stage.get_meta("freshwater_school",{})
	check("twenty clumps and original eight fish share actual river",not data.is_empty() and data.clumps.size()==20 and not fish.is_empty() and fish.fish.size()==8)
	if data.is_empty() or fish.is_empty():
		await finish()
		return
	check("existing shore animals remain",stage.get_meta("frogs",[]).size()==2 and stage.get_meta("river_wetland",{}).plants.size()==9)
	check("USGS plant source available",Reference.allows_url("woodland",Celery.SOURCE))
	var targets: Array[Dictionary]=main.content_targets()
	check("plant whole and leaf are real object choices",targets.size()>=2 and targets[-2].node==data.first and targets[-1].node==data.leaf)
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("original freshwater school topic still opens",panel.select_topic("freshwater_school") and main.learning_overlay.topic=="freshwater_school")
	await settle()
	await capture("fish-school-and-riverbed")
	check("same riverbed plant topic opens",panel.select_topic("wild_celery") and main.learning_overlay.topic=="wild_celery" and main.content_targets()[main._content_follow].node==data.first)
	await settle()
	check("whole clump visible underwater",subject_visible(data.first) and stage.camera.position.y<Woodland.WATER_Y-.05)
	await capture("wild-celery-clump")
	check("same clump leaf detail opens",panel.select_topic("wild_celery_leaf") and main.learning_overlay.topic=="wild_celery_leaf" and main.content_targets()[main._content_follow].node==data.leaf)
	await settle()
	var leaf_point: Vector2=stage.camera.unproject_position(data.leaf.global_position)
	check("leaf detail sits inside usable view",not stage.camera.is_position_behind(data.leaf.global_position) and leaf_point.x>panel.get_global_rect().end.x+8 and leaf_point.x<get_window().size.x-8 and leaf_point.y>80 and leaf_point.y<get_window().size.y-60)
	check("three actual plant structure markers",Celery.marks(main,"wild_celery_leaf").size()==3)
	await capture("wild-celery-leaf")
	var first_angle: float=data.first.rotation.z
	await at_time(17.0)
	await settle()
	check("same plant uses host world time",absf(data.first.rotation.z-first_angle)>.005 and main.world.simulation_time_s==17.0 and fish.fish.size()==8)
	await capture("wild-celery-leaf-moved")
	comparisons["wild_celery"]={"clumps":data.clumps.size(),"first_rotation_z":first_angle,"later_rotation_z":data.first.rotation.z,"fish":fish.fish.size(),"world_time_s":main.world.simulation_time_s}
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var guide: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="wild_celery": guide=button
	check("two plant guide entries included",guide!=null and main.world_guide.route_buttons.size()==60)
	if guide!=null: guide.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	check("plant guide returns to same world and actual clumps",main.world.current_scale_id=="woodland" and main.learning_overlay.topic=="wild_celery" and main.world.simulation_time_s==17.0 and main.coordinator.active_scene.get_meta("wild_celery",{}).clumps.size()==20)
	await capture("wild-celery-guide-return")
	await finish()
