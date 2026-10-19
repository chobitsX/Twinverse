extends "res://tests/integration/land_lighting_suite.gd"
const Sparrow = preload("res://scripts/experience/city_sparrow.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")

## Short actual-renderer view of the same bird, park walkers and source boundary.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world170-review="): directory=argument.trim_prefix("--world170-review=")
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
	if not await arrive("city"):
		await finish()
		return
	await at_time(10.)
	await settle()
	var stage: Node=main.coordinator.active_scene
	var birds: Array=stage.get_meta("city_sparrows",[])
	var actors: Array=stage.get_meta("actors",[])
	check("city retains 28 people, 12 cars, four sparrows and two ginkgos",actors.size()==40 and birds.size()==4 and stage.get_meta("city_ginkgos",[]).size()==2)
	if birds.size()!=4:
		await finish()
		return
	var bird: Node3D=birds[0]
	var quiet_position: Vector3=bird.position
	check("first bird has a quiet foraging interval beside the real west path",float(bird.get_meta("pedestrian_alert",1.))<.02 and float(bird.get_meta("nearest_pedestrian_m",0.))>Sparrow.ALERT_OUTER_M and bird.position.x<22.)
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("existing bird topic follows the first actual model",panel.select_topic("city_sparrow") and main._content_follow==7)
	await settle()
	check("near bird and source-aware distance lesson are visible",subject_visible(bird) and panel.lesson_readout.text.contains("最近公园行人") and panel.lesson_text.text.contains("作者教学参数") and panel.lesson_source.visible and Reference.allows_url("city",Sparrow.HUMAN_RESPONSE_SOURCE))
	await capture("bird-quiet-near")
	await at_time(6.)
	await settle()
	var walkers: Array[Vector3]=[]
	for index: int in range(26): walkers.append(actors[index].node.position)
	var expected: Dictionary=Sparrow.sample(6.,0,walkers)
	check("bird response uses the actual 26 walker positions and one world time",bird.position.distance_to(expected.position)<.002 and absf(float(bird.get_meta("nearest_pedestrian_m",0.))-float(expected.nearest_pedestrian_m))<.002)
	check("nearby pedestrian produces a strong bounded alert",float(bird.get_meta("nearest_pedestrian_m",0.))<Sparrow.ALERT_OUTER_M and float(bird.get_meta("pedestrian_alert",0.))>.75)
	check("active readout, activity and proximity marker explain the bounded response",str(bird.get_meta("activity","")).contains("警觉") and panel.lesson_readout.text.contains("警觉") and Topics.marks(main,"city_sparrow").size()==4)
	comparisons["quiet_position"]=[quiet_position.x,quiet_position.y,quiet_position.z]
	comparisons["alert_position"]=[bird.position.x,bird.position.y,bird.position.z]
	comparisons["alert_nearest_walker_m"]=bird.get_meta("nearest_pedestrian_m")
	await capture("bird-alert-near")
	stage.set_pose(Vector3(15.0,1.8,27.5),Vector3(18.6,.7,25.5))
	await settle()
	await capture("bird-and-pedestrian-context")
	await at_time(10.)
	await settle()
	check("paused world re-evaluates back to the same quiet bird pose",main.world.paused and bird.position.distance_to(quiet_position)<.002 and float(bird.get_meta("pedestrian_alert",1.))<.02)
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="city_sparrow": action=button
	check("guide retains the bird entry",action!=null and main.world_guide.route_buttons.size()==48)
	if action!=null: action.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	stage=main.coordinator.active_scene
	check("guide returns to the same quiet bird state at world time 10",main.world.current_scale_id=="city" and main.learning_overlay.topic=="city_sparrow" and main.world.simulation_time_s==10. and stage.get_meta("city_sparrows",[]).size()==4 and float(stage.get_meta("city_sparrows")[0].get_meta("pedestrian_alert",1.))<.02)
	await capture("bird-guide-return")
	await finish()
