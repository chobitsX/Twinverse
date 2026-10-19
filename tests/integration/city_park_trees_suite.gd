extends "res://tests/integration/land_lighting_suite.gd"
const ParkTrees = preload("res://scripts/experience/city_park_trees.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")
const Runoff = preload("res://scripts/experience/runoff_observation.gd")

## One bounded Metal look at real trees, season buttons, near views and guide return.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world175-review="): directory=argument.trim_prefix("--world175-review=")
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
	if not await arrive("city"):
		await finish()
		return
	await at_time(9.)
	await settle()
	var stage: Node=main.coordinator.active_scene
	var trees: Dictionary=stage.get_meta("city_park_trees",{})
	check("existing city population and planted species remain",stage.get_meta("actors",[]).size()==40 and stage.get_meta("city_sparrows",[]).size()==4 and stage.get_meta("city_ginkgos",[]).size()==2)
	check("new maple and redbud are actual separate scene trees",trees.size()==7 and trees.maple!=null and trees.redbud!=null)
	if trees.size()!=7:
		await finish()
		return
	check("both university references available",Reference.allows_url("city",ParkTrees.SOURCE_MAPLE) and Reference.allows_url("city",ParkTrees.SOURCE_REDBUD))
	check("park trunks clear existing runoff platforms",not Runoff.reserved(trees.maple.position.x,trees.maple.position.z) and not Runoff.reserved(trees.redbud.position.x,trees.redbud.position.z))
	var targets: Array[Dictionary]=main.content_targets()
	check("six new object choices append after prior city indices",targets.size()==16 and targets[8].node==stage.get_meta("city_ginkgos",[])[0] and targets[10].node==stage.get_meta("city_park_tree_targets",[])[0].node and targets[15].node==stage.get_meta("city_park_tree_targets",[])[5].node)
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("park comparison selects same two planted trees",panel.select_topic("city_park_trees") and main._content_follow==10 and main.learning_overlay.topic=="city_park_trees")
	check("four date buttons and source visible",panel.park_tree_controls.visible and panel.park_tree_controls.get_child_count()==2 and panel.lesson_source.visible)
	await _date_button(panel,0,0)
	check("spring redbud flowers before its leaves",ParkTrees.phase(main.solar_jd)=="spring" and trees.redbud_flowers[0].visible and not trees.redbud_leaves[0].visible and trees.maple_leaves[0].visible and main.world.simulation_time_s==9.)
	check("both planted trees fit beside comparison panel",subject_visible(trees.maple) and subject_visible(trees.redbud))
	await capture("park-spring-overview")
	check("spring flower topic follows actual branch",panel.select_topic("city_redbud_bloom") and main.content_targets()[main._content_follow].node==stage.get_meta("city_park_tree_targets",[])[4].node and trees.redbud_flowers[1].visible)
	await settle()
	check("spring reference flower appears in close view",subject_visible(trees.redbud_flowers[1]))
	await capture("redbud-bloom-close")
	check("redbud heart topic can select same tree",panel.select_topic("city_redbud_leaf") and main.content_targets()[main._content_follow].node.get_meta("plant_root",null)==trees.redbud)
	await _date_button(panel,0,1)
	check("summer has two leaf forms and no flower display",ParkTrees.phase(main.solar_jd)=="summer" and trees.maple_leaves[0].visible and trees.redbud_leaves[0].visible and not trees.redbud_flowers[0].visible)
	check("heart-shaped reference leaf appears in close view",subject_visible(trees.redbud_leaves[1]))
	await capture("redbud-heart-summer")
	check("maple leaf topic follows actual attached leaf",panel.select_topic("city_maple_leaf") and main.content_targets()[main._content_follow].node.get_meta("plant_root",null)==trees.maple)
	await settle()
	check("lobed reference leaf appears in close view",subject_visible(trees.maple_leaves[1]))
	await capture("maple-lobes-summer")
	panel.select_topic("city_park_trees")
	await _date_button(panel,1,0)
	check("autumn distinguishes red and gold on same date",ParkTrees.phase(main.solar_jd)=="autumn" and trees.maple_leaves[0].get_surface_override_material(0)!=null and trees.redbud_leaves[0].get_surface_override_material(0)!=null and stage.get_meta("city_ginkgo_phase","")=="gold")
	await capture("park-autumn-overview")
	await _date_button(panel,1,1)
	check("winter keeps both trunks and hides leaves flowers",ParkTrees.phase(main.solar_jd)=="winter" and not trees.maple_leaves[0].visible and not trees.redbud_leaves[0].visible and not trees.redbud_flowers[0].visible and trees.maple.find_child("MapleTrunkAndBranches",true,false).visible and trees.redbud.find_child("RedbudTrunkAndBranches",true,false).visible)
	await capture("park-winter-overview")
	comparisons["park_trees"]={"maple_id":trees.maple.get_meta("stable_id",""),"redbud_id":trees.redbud.get_meta("stable_id",""),"world_time_s":main.world.simulation_time_s,"dates":["2026-04-15","2026-06-21","2026-10-28","2026-12-22"]}
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="city_park_trees": action=button
	check("four new city tree guide entries available",action!=null and main.world_guide.route_buttons.size()==56)
	if action!=null: action.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	check("guide returns to same time and tree lesson",main.world.current_scale_id=="city" and main.learning_overlay.topic=="city_park_trees" and main.world.simulation_time_s==9. and main.coordinator.active_scene.has_meta("city_park_trees"))
	await capture("park-guide-return")
	await finish()

func _date_button(panel: Node,row: int,index: int) -> void:
	var line: HBoxContainer=panel.park_tree_controls.get_child(row) as HBoxContainer
	(line.get_child(index) as Button).pressed.emit()
	await settle()
