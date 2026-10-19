extends "res://tests/integration/land_lighting_suite.gd"
const Sparrow = preload("res://scripts/experience/city_sparrow.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

## Short city observation on the actual renderer; no population or performance test.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world168-review="): directory=argument.trim_prefix("--world168-review=")
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
	await at_time(9.)
	await settle()
	var stage: Node=main.coordinator.active_scene
	var birds: Array=stage.get_meta("city_sparrows",[])
	var targets: Array[Dictionary]=main.content_targets()
	check("city retains 28 people and 12 cars beside four wild bird references",stage.get_meta("actors").size()==40 and birds.size()==4)
	if birds.size()!=4:
		await finish()
		return
	var rooted: bool=true
	for index: int in range(4):
		rooted=rooted and birds[index].is_inside_tree() and birds[index].position.distance_to(Sparrow.sample(9.,index).position)<.001 and birds[index].get_meta("stable_id")=="3dworld:teaching:tree-sparrow:%04d" % index
	check("four actual imported models use one world time and stable identities",rooted)
	var bird: Node3D=birds[0]
	check("species view targets actual first bird",targets.size()==8 and targets[7].node==bird and targets[7].source_url==Sparrow.SOURCE)
	check("imported identification colors have separate geometry",bird.find_child("ChestnutCap",true,false)!=null and bird.find_child("BlackCheekSpotL",true,false)!=null and bird.find_child("ShortConicalUpperBill",true,false)!=null)
	main.next_button.pressed.emit()
	await settle()
	await capture("sparrow-park-context")
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("bird topic selects the real bird",panel.select_topic("city_sparrow") and main._content_follow==7)
	await settle()
	check("small bird is visible in close observation",subject_visible(bird))
	check("lesson states source and authored limits",panel.lesson_source.visible and panel.lesson_text.text.contains("Passer montanus") and panel.lesson_text.text.contains("没有真实食物") and Reference.allows_url("city",Sparrow.SOURCE))
	await capture("sparrow-close")
	var before: Vector3=bird.position
	await at_time(10.5)
	await settle()
	check("world time moves bird locally without changing city actors",bird.position.distance_to(before)>.1 and bird.position.distance_to(Sparrow.sample(10.5,0).position)<.001 and stage.get_meta("actors").size()==40)
	await capture("sparrow-next-hop")
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="city_sparrow": action=button
	check("world guide includes new city bird",action!=null and main.world_guide.route_buttons.size()==47)
	if action!=null: action.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	check("guide returns to city bird on the same world clock",main.world.current_scale_id=="city" and main.learning_overlay.topic=="city_sparrow" and main.world.simulation_time_s==10.5 and main.coordinator.active_scene.get_meta("city_sparrows").size()==4)
	await capture("sparrow-guide-return")
	await finish()
