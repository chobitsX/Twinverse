extends "res://tests/integration/observation_framing_suite.gd"
const ScienceReference = preload("res://scripts/experience/science_reference.gd")

## Bounded native observation of one real-scale reef-floor individual.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world184-review="): directory=argument.trim_prefix("--world184-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless":
		main._measurement_screen=get_window().current_screen
		get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	get_window().size=Vector2i(1000,720)
	if not await arrive("reef"):
		await finish()
		return
	var stage: Node=main.coordinator.active_scene
	var targets: Array[Dictionary]=main.content_targets()
	var root: Node3D=stage.get_meta("holothuria_root",null)
	check("new species is a real reef-floor node",root!=null and root.is_inside_tree() and targets.size()==17)
	if root==null:
		await finish()
		return
	check("existing coral layout remains baked and other marine targets remain",stage.get_meta("reef_placement_mode")=="baked" and stage.get_meta("clam_root",null)!=null and targets[11].node==stage.get_meta("target_node"))
	var skin: MeshInstance3D=root.find_child("PliableBlackBody",true,false) as MeshInstance3D
	var veil: MeshInstance3D=root.find_child("ThinSandVeilWithTwoExposedRows",true,false) as MeshInstance3D
	var tentacle: MeshInstance3D=root.find_child("FeedingTentacle00",true,false) as MeshInstance3D
	check("imported continuous body, sparse sand, and short tentacles",skin!=null and veil!=null and tentacle!=null and skin.mesh.get_faces().size()>4000 and veil.mesh.get_faces().size()>1000)
	var skin_material: StandardMaterial3D=skin.get_active_material(0) as StandardMaterial3D
	var sand_material: StandardMaterial3D=veil.get_active_material(0) as StandardMaterial3D
	check("actual body and sand pigment render",skin_material!=null and sand_material!=null and skin_material.vertex_color_use_as_albedo and sand_material.vertex_color_use_as_albedo)
	check("reference is unscaled and planted in the same terrain",root.scale.is_equal_approx(Vector3.ONE) and absf(root.position.y-stage.builder._terrain_height(stage,root.position.x,root.position.z))<.01)
	var feeding: Node3D=root.find_child("FeedingEndObservationAnchor",true,false) as Node3D
	check("two stable views belong to the same specimen",targets[15].node==root and targets[16].node.get_meta("holothuria_root")==root and targets[16].node.position.is_equal_approx(feeding.global_position) and root.get_meta("stable_id")=="3dworld:teaching:holothuria-atra:0001")
	var old_time: float=main.world.simulation_time_s
	var old_pose: Transform3D=root.transform
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("whole-body lesson selects the actual individual",panel.select_topic("black_sea_cucumber") and main._content_follow==15)
	await settle()
	check("real-scale whole body and two anatomy labels fit the view",subject_visible(root) and main.learning_overlay.last_visible_marks==2)
	check("species lesson states source and simulation limit",panel.lesson_source.visible and panel.lesson_text.text.contains("Holothuria atra") and panel.lesson_text.text.contains("没有模拟处理量") and ScienceReference.allows_url("reef",str(targets[15].source_url)))
	await capture("holothuria-whole")
	check("feeding lesson keeps the same animal",panel.select_topic("black_sea_cucumber_feeding") and main._content_follow==16)
	await settle()
	check("feeding end is on screen with both anatomy labels",stage.camera.unproject_position(feeding.global_position).x>panel.get_global_rect().end.x and main.learning_overlay.last_visible_marks==2)
	check("close lesson labels author tentacles and valid source",panel.lesson_text.text.contains("12个短触手") and ScienceReference.allows_url("reef",str(targets[16].source_url)))
	await capture("holothuria-feeding")
	check("observation does not advance or duplicate world state",main.world.simulation_time_s==old_time and root.transform.is_equal_approx(old_pose) and main.world.checkpoint().version==14)
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="black_sea_cucumber_feeding": action=button
	check("guide includes the benthic lesson route",action!=null and main.world_guide.route_buttons.size()>=64)
	if action!=null: action.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	stage=main.coordinator.active_scene
	check("guide returns to the same specimen and one world time",main.world.current_scale_id=="reef" and main.learning_overlay.topic=="black_sea_cucumber_feeding" and main.world.simulation_time_s==old_time and stage.get_meta("holothuria_root").get_meta("stable_id")=="3dworld:teaching:holothuria-atra:0001")
	await capture("holothuria-guide-return")
	await finish()
