extends "res://tests/integration/land_lighting_suite.gd"
const Ginkgo = preload("res://scripts/experience/city_ginkgo.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

## Actual Metal city/leaf observation, not growth or performance validation.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world169-review="): directory=argument.trim_prefix("--world169-review=")
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
	var trees: Array=stage.get_meta("city_ginkgos",[])
	var birds: Array=stage.get_meta("city_sparrows",[])
	var targets: Array[Dictionary]=main.content_targets()
	check("city keeps 28 people, 12 cars and four birds",stage.get_meta("actors").size()==40 and birds.size()==4)
	check("two planted ginkgos keep a visible park gap",trees.size()==2 and trees[0].global_position.distance_to(trees[1].global_position)>5.)
	if trees.size()!=2:
		await finish()
		return
	var identified: bool=true
	for index: int in range(2):
		identified=identified and trees[index].is_inside_tree() and trees[index].get_meta("stable_id")=="3dworld:teaching:city-ginkgo:%04d" % index
		identified=identified and trees[index].position.distance_to(Ginkgo.BASES[index])<.001
	check("two actual imported trees have stable authored places",identified)
	check("tree and its attached fan leaf have distinct observation targets",targets.size()==10 and targets[8].node==trees[0] and targets[9].source_url==Ginkgo.SOURCE)
	check("imported canopy and reference fan are present",trees[0].find_child("GinkgoFanCanopy",true,false)!=null and trees[0].find_child("ReferenceBilobedFanLeaf",true,false)!=null and trees[0].find_child("ReferenceDichotomousVeins",true,false)!=null)
	main.next_button.pressed.emit()
	await settle()
	await capture("ginkgo-park-context")
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("ginkgo lesson selects actual leaf on first tree",panel.select_topic("city_ginkgo_leaf") and main._content_follow==9)
	await settle()
	var detail: Node3D=targets[9].node
	var markers: Array=detail.get_meta("plant_markers",[])
	var reference_leaf: Node3D=trees[0].find_child("ReferenceBilobedFanLeaf",true,false) as Node3D
	check("close leaf and its two anatomy marks are visible",reference_leaf!=null and subject_visible(reference_leaf) and markers.size()==2)
	check("leaf explanation names source and unmodeled seasons",panel.lesson_source.visible and panel.lesson_text.text.contains("Ginkgo biloba") and panel.lesson_text.text.contains("季节物候") and Reference.allows_url("city",Ginkgo.SOURCE))
	await capture("ginkgo-fan-leaf")
	main.follow_content(9)
	await settle()
	check("whole planted tree can be observed beside same city",main._content_follow==8 and subject_visible(trees[0]) and stage.get_meta("actors").size()==40)
	await capture("ginkgo-whole-tree")
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="city_ginkgo_leaf": action=button
	check("world guide includes city planted tree",action!=null and main.world_guide.route_buttons.size()==48)
	if action!=null: action.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	check("guide returns to same leaf and world time",main.world.current_scale_id=="city" and main.learning_overlay.topic=="city_ginkgo_leaf" and main.world.simulation_time_s==9. and main.coordinator.active_scene.get_meta("city_ginkgos").size()==2)
	await capture("ginkgo-guide-return")
	await finish()
