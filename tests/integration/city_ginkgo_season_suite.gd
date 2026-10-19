extends "res://tests/integration/land_lighting_suite.gd"
const Ginkgo = preload("res://scripts/experience/city_ginkgo.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

## Bounded Metal check of the same two trees at three illustrative dates.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world172-review="): directory=argument.trim_prefix("--world172-review=")
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
	check("same two ginkgo trees and existing city actors",trees.size()==2 and stage.get_meta("actors",[]).size()==40 and stage.get_meta("city_sparrows",[]).size()==4)
	if trees.size()!=2:
		await finish()
		return
	var identity: Array[String]=[]
	for tree: Node3D in trees: identity.append(str(tree.get_meta("stable_id","")))
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("new topic follows the planted tree",panel.select_topic("city_ginkgo_season") and main._content_follow==8)
	await settle()
	check("three season buttons and source are available",panel.ginkgo_controls.visible and panel.ginkgo_controls.get_child_count()==3 and panel.lesson_source.visible and Reference.allows_url("city",Ginkgo.SOURCE))
	var samples: Array[Dictionary]=[
		{"index":0,"phase":"green","image":"ginkgo-summer"},
		{"index":1,"phase":"gold","image":"ginkgo-autumn"},
		{"index":2,"phase":"bare","image":"ginkgo-winter"}]
	for sample: Dictionary in samples:
		var button: Button=panel.ginkgo_controls.get_child(int(sample.index)) as Button
		button.pressed.emit()
		await settle()
		var phase: String=str(sample.phase)
		check("button selects expected date phase "+phase,Ginkgo.season(main.solar_jd)==phase and stage.get_meta("city_ginkgo_phase","")==phase and main.ground_light_preview)
		var match_parts: bool=true
		for tree: Node3D in trees:
			var parts: Array=tree.get_meta("ginkgo_leaf_parts",[])
			match_parts=match_parts and parts.size()==3 and tree.find_child("GinkgoTrunkAndBranches",true,false).visible
			for leaf: MeshInstance3D in parts:
				match_parts=match_parts and leaf.visible==(phase!="bare") and (leaf.get_surface_override_material(0)!=null)==(phase=="gold")
		check("both original trees visibly match "+phase,match_parts and main.world.simulation_time_s==9.)
		await capture(str(sample.image))
	comparisons["ginkgo_phases"]={"world_time_s":main.world.simulation_time_s,"stable_ids":identity,"dates":["2026-06-21","2026-10-28","2026-12-22"]}
	check("winter leaf detail explains absent attached leaf",str(stage.get_meta("city_ginkgo_targets",[])[1].node.get_meta("activity","")).contains("落叶期"))
	check("leaf topic keeps same tree as a reference",panel.select_topic("city_ginkgo_leaf") and main._content_follow==9 and panel.ginkgo_controls.visible)
	(panel.ginkgo_controls.get_child(0) as Button).pressed.emit()
	await settle()
	var leaf: Node3D=trees[0].find_child("ReferenceBilobedFanLeaf",true,false) as Node3D
	check("summer button restores visible attached fan",leaf!=null and leaf.visible and subject_visible(leaf) and Ginkgo.season(main.solar_jd)=="green")
	await capture("ginkgo-leaf-restored")
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="city_ginkgo_season": action=button
	check("guide has new city season route",action!=null and main.world_guide.route_buttons.size()==49)
	if action!=null: action.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	check("guide returns to same world time and ginkgo lesson",main.world.current_scale_id=="city" and main.learning_overlay.topic=="city_ginkgo_season" and main.world.simulation_time_s==9. and main.coordinator.active_scene.get_meta("city_ginkgos",[]).size()==2)
	await capture("ginkgo-guide-return")
	await finish()
