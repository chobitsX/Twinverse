extends "res://tests/integration/world_expansion_suite.gd"
## Bounded native check of the new authored desert shrub and existing paths.
const ScienceReference = preload("res://scripts/experience/science_reference.gd")
const Desert = preload("res://scripts/experience/desert_builder.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world203-review="):
			directory = argument.trim_prefix("--world203-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	get_window().unfocusable = true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await arrive("desert"):
		await finish()
		return
	main._reset_camera()
	for frame: int in range(4): await get_tree().process_frame
	var stage: Node = main.coordinator.active_scene
	var targets: Array[Dictionary] = main.content_targets()
	var hero: Node3D = stage.get_meta("desert_brittlebush",null)
	var count: int = 0
	for child: Node in stage.world_root.get_children():
		var id: String = str(child.get_meta("stable_id",""))
		if id.begins_with("3dworld:teaching:brittlebush:") and id.trim_prefix("3dworld:teaching:brittlebush:").is_valid_int():
			count += 1
	check("eight authored shrubs join existing desert plants",hero!=null and count==8 and stage.get_meta("desert_brittlebush_count",0)==8 and stage.get_meta("desert_ocotillo_count",0)==6 and stage.get_meta("desert_mesquite_count",0)==4)
	if hero==null or targets.size()!=17:
		check("three same-plant views extend existing targets",false)
		await finish()
		return
	var leaves: MeshInstance3D = hero.find_child("BrittlebushOvalDiamondLeafCrown",true,false) as MeshInstance3D
	var petals: MeshInstance3D = hero.find_child("BrittlebushYellowRayFlorets",true,false) as MeshInstance3D
	var stalks: MeshInstance3D = hero.find_child("BrittlebushTallFlowerStalks",true,false) as MeshInstance3D
	var leaf_anchor: Node3D = hero.find_child("BrittlebushLeafAnchor",true,false) as Node3D
	var flower_anchor: Node3D = hero.find_child("BrittlebushFlowerAnchor",true,false) as Node3D
	check("imported gray leaves raised flower stalks and yellow rays",leaves!=null and petals!=null and stalks!=null and leaf_anchor!=null and flower_anchor!=null)
	if leaves==null or petals==null or stalks==null or leaf_anchor==null or flower_anchor==null:
		await finish()
		return
	check("actual geometry and pigment survive import",leaves.mesh.get_faces().size()>1000 and petals.mesh.get_faces().size()>100 and (leaves.get_active_material(0) as StandardMaterial3D).vertex_color_use_as_albedo)
	check("new views point to one rooted individual",targets[14].node==hero and targets[15].node.get_meta("reference_root")==hero and targets[16].node.get_meta("reference_root")==hero and targets[15].node.get_meta("stable_id")=="3dworld:teaching:brittlebush:leaf" and targets[16].node.get_meta("stable_id")=="3dworld:teaching:brittlebush:flower")
	await capture("brittlebush-desert-overview")
	var paused_time: float = main.world.simulation_time_s
	main.explorer_panel.show()
	main.explorer_panel._process(0.0)
	check("whole plant topic follows the actual shrub",main.explorer_panel.select_topic("desert_brittlebush") and main._content_follow==14)
	await capture("brittlebush-whole")
	check("leaf topic follows the same rooted plant",main.explorer_panel.select_topic("desert_brittlebush_leaf") and main._content_follow==15 and main._orbit_target.distance_to(leaf_anchor.global_position)<.001)
	await capture("brittlebush-leaf")
	check("flower topic follows same plant with undated bloom boundary",main.explorer_panel.select_topic("desert_brittlebush_flower") and main._content_follow==16 and main._orbit_target.distance_to(flower_anchor.global_position)<.001 and main.explorer_panel.lesson_text.text.contains("静态开花"))
	await capture("brittlebush-flower")
	var guide_topics: Dictionary = {}
	for button: Button in main.world_guide.route_buttons:
		guide_topics[str(button.get_meta("guide_topic",""))] = true
	check("guide and science connect plant and two near views",guide_topics.has("desert_brittlebush") and guide_topics.has("desert_brittlebush_leaf") and guide_topics.has("desert_brittlebush_flower") and ScienceReference.allows_url("desert",Desert.BRITTLEBUSH_SOURCE) and ScienceReference.allows_url("desert",Desert.BRITTLEBUSH_ECOLOGY_SOURCE))
	check("new plant uses existing paused world time",main.world.paused and main.world.simulation_time_s==paused_time)
	if not await arrive("earth") or not await arrive("desert"):
		await finish()
		return
	stage = main.coordinator.active_scene
	check("Earth return rebuilds shrub and original animal",stage.get_meta("desert_brittlebush_count",0)==8 and stage.has_meta("kangaroo_rat") and main.world.simulation_time_s==paused_time)
	await finish()
