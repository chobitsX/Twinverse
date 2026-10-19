extends "res://tests/integration/land_lighting_suite.gd"
## Brief visual/interaction check for the replacement environment, no performance run.
const Woodland = preload("res://scripts/experience/woodland_environment.gd")

func tree_snapshot(stage: Node) -> Array:
	var result: Array = []
	for node: Node in get_tree().get_nodes_in_group("woodland_background_trees"):
		if stage.world_root.is_ancestor_of(node): result.append({"at":node.position,"scale":node.scale,"angle":node.rotation.y,"variant":node.get_meta("canopy_variant")})
	return result

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world125-check="): directory=argument.trim_prefix("--world125-check=")
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
	main.explorer_panel.hide()
	if not await arrive("woodland"):
		await finish()
		return
	await at_time(22.)
	main.ground_light_preview=false
	main._reset_camera()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var trees: Array = tree_snapshot(stage)
	var layout: Dictionary = stage.get_meta("woodland_layout")
	check("new original canopy scenes loaded",stage.assets.broadleaf_a.resource_path.contains("woodland125") and stage.assets.broadleaf_b.resource_path.contains("woodland125"))
	var clear: bool = true
	for tree: Dictionary in trees:
		var at: Vector3 = tree.at
		clear=clear and Vector2(at.x,at.z).length()>18 and is_equal_approx(at.y,Woodland.height_at(at.x,at.z)) and at.y>Woodland.WATER_Y+.1 and not Woodland.Browse.reserved(at.x,at.z) and not Woodland.Fungi.reserved(at.x,at.z) and not Woodland.Deadwood.reserved(at.x,at.z)
	check("trees grounded on dry banks outside learning clearing and study plots",clear and trees.size()==int(layout.trees) and trees.size()>60)
	check("forest edge stays within baseline tree budget",trees.size()<=135)
	comparisons.layout=layout
	await capture("woodland-canopy-overview")
	stage.camera.position=Vector3(5,4,12)
	main._orbit_target=Vector3(-16,.3,-23)
	stage.camera.look_at(main._orbit_target)
	await capture("woodland-river-groves")
	main.explorer_panel.show()
	await settle()
	check("deer learning topic remains selectable",main.explorer_panel.select_topic("graze"))
	get_window().size=Vector2i(900,650)
	await settle()
	check("deer geometry remains beside compact panel",subject_visible(main.content_targets()[0].node))
	await capture("woodland-deer-compact")
	get_window().size=Vector2i(1280,720)
	main.explorer_panel.hide()
	main._reset_camera()
	await settle()
	var leaf: ShaderMaterial
	for material: ShaderMaterial in stage.materials:
		if material.shader.resource_path.ends_with("woodland_foliage.gdshader"): leaf=material
	check("canopy wind uses paused host time",leaf!=null and is_equal_approx(float(leaf.get_shader_parameter("world_time")),22.))
	var old_trees: Array = tree_snapshot(stage)
	await settle()
	check("pause keeps tree transforms stable",tree_snapshot(stage)==old_trees and main.world.simulation_time_s==22.)
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	stage=main.coordinator.active_scene
	check("return rebuilds same grove layout and world time",tree_snapshot(stage)==trees and stage.get_meta("woodland_layout")==layout and main.world.simulation_time_s==22.)
	await finish()
