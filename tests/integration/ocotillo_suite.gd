extends "res://tests/integration/world_expansion_suite.gd"

## One short visual and navigation check of the new authored desert plant.
const ScienceReference = preload("res://scripts/experience/science_reference.gd")
const Desert = preload("res://scripts/experience/desert_builder.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world192-review="):
			directory = argument.trim_prefix("--world192-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless" and get_window().current_screen != DisplayServer.get_primary_screen():
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
	for frame: int in range(4): await get_tree().process_frame
	main._reset_camera()
	var stage: Node = main.coordinator.active_scene
	var targets: Array[Dictionary] = main.content_targets()
	var hero: Node3D = stage.get_meta("desert_ocotillo",null)
	var count: int = 0
	var cactus_count: int = 0
	var shrub_count: int = 0
	for child: Node in stage.world_root.get_children():
		var id: String = str(child.get_meta("stable_id",""))
		if id.begins_with("3dworld:teaching:ocotillo:") and id.trim_prefix("3dworld:teaching:ocotillo:").is_valid_int(): count += 1
		if id.begins_with("3dworld:teaching:saguaro:"): cactus_count += 1
		if id.begins_with("3dworld:teaching:creosote_bush:"): shrub_count += 1
	check("six ocotillo join original plants and animal views",hero!=null and count==6 and cactus_count==9 and shrub_count==64 and stage.get_meta("desert_mesquite_count",0)==4 and targets.size()==14)
	if hero==null or targets.size()!=14:
		await finish()
		return
	var stems: MeshInstance3D = hero.find_child("OcotilloSeparateAscendingCaneStems",true,false) as MeshInstance3D
	var spines: MeshInstance3D = hero.find_child("OcotilloStemThorns",true,false) as MeshInstance3D
	var flowers: MeshInstance3D = hero.find_child("OcotilloTipFlowers",true,false) as MeshInstance3D
	var spine_anchor: Node3D = hero.find_child("OcotilloSpineAnchor",true,false) as Node3D
	var flower_anchor: Node3D = hero.find_child("OcotilloFlowerAnchor",true,false) as Node3D
	check("imported stems spines flowers and same-plant anchors",stems!=null and spines!=null and flowers!=null and spine_anchor!=null and flower_anchor!=null)
	if stems==null or spines==null or flowers==null or spine_anchor==null or flower_anchor==null:
		await finish()
		return
	check("actual mesh and vertex pigment are available",stems.mesh.get_faces().size()>1000 and spines.mesh.get_faces().size()>1000 and flowers.mesh.get_faces().size()>100 and (flowers.get_active_material(0) as StandardMaterial3D).vertex_color_use_as_albedo)
	check("stable near views resolve on the hero",targets[11].node==hero and targets[12].node.get_meta("reference_root")==hero and targets[13].node.get_meta("reference_root")==hero and targets[12].node.get_meta("stable_id")=="3dworld:teaching:ocotillo:spine" and targets[13].node.get_meta("stable_id")=="3dworld:teaching:ocotillo:flower")
	await capture("ocotillo-desert-overview")
	var time_before: float = main.world.simulation_time_s
	main.explorer_panel.show()
	main.explorer_panel._process(0.0)
	check("whole-plant topic follows the actual root",main.explorer_panel.select_topic("desert_ocotillo") and main._content_follow==11)
	await capture("ocotillo-whole")
	check("spine topic follows the same rooted plant",main.explorer_panel.select_topic("desert_ocotillo_spine") and main._content_follow==12 and main._orbit_target.distance_to(spine_anchor.global_position)<.001)
	await capture("ocotillo-spine")
	check("flower topic follows same plant without weather claim",main.explorer_panel.select_topic("desert_ocotillo_flower") and main._content_follow==13 and main._orbit_target.distance_to(flower_anchor.global_position)<.001 and main.explorer_panel.lesson_text.text.contains("不根据观察日期"))
	await capture("ocotillo-flower")
	var guide_found: bool = false
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="desert_ocotillo": guide_found=true
	check("guide and science link the new species",guide_found and ScienceReference.allows_url("desert",Desert.OCOTILLO_SOURCE) and ScienceReference.allows_url("desert",Desert.OCOTILLO_ECOLOGY_SOURCE))
	check("observation keeps one paused world time",main.world.paused and main.world.simulation_time_s==time_before)
	await finish()
