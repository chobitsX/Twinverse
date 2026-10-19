extends "res://tests/integration/observation_framing_suite.gd"
const Reference = preload("res://scripts/experience/science_reference.gd")

## A short actual-Metal observation route. The static reference makes no
## claim about valve reaction, photosynthesis rate, or wild abundance.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world165-review="): directory=argument.trim_prefix("--world165-review=")
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
	var stable_since: int=Time.get_ticks_msec()
	var deadline: int=stable_since+10000
	while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since=Time.get_ticks_msec()
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	get_window().size=Vector2i(1280,720)
	if not await arrive("reef"):
		await finish()
		return
	var stage: Node=main.coordinator.active_scene
	var targets: Array[Dictionary]=main.content_targets()
	check("existing fish and marine actors remain present",stage.get_meta("marine_actors").size()==44 and targets.size()==15 and targets[11].node==stage.get_meta("target_node"))
	var root: Node3D=stage.get_meta("clam_root",null)
	check("original giant clam is an actual reef node",root!=null and root.is_inside_tree())
	if root==null:
		await finish()
		return
	var mantle: Node3D=root.find_child("MantleObservationAnchor",true,false) as Node3D
	var scutes: Node3D=root.find_child("ShellScuteObservationAnchor",true,false) as Node3D
	check("whole, scute, and mantle targets share one specimen",targets[12].node==root and targets[13].node.get_meta("clam_root")==root and targets[14].node.get_meta("clam_root")==root and targets[13].node.position.is_equal_approx(scutes.global_position) and targets[14].node.position.is_equal_approx(mantle.global_position) and root.get_meta("stable_id")=="3dworld:teaching:tridacna-maxima:0001")
	var outer: MeshInstance3D=root.find_child("OuterValveRight",true,false) as MeshInstance3D
	var tissue: MeshInstance3D=root.find_child("LightFacingMantle",true,false) as MeshInstance3D
	check("imported shells and pigmented mantle have authored geometry",outer!=null and tissue!=null and outer.mesh.get_faces().size()>1000 and tissue.mesh.get_faces().size()>1000)
	var shell_material: StandardMaterial3D=outer.get_active_material(0) as StandardMaterial3D
	var mantle_material: StandardMaterial3D=tissue.get_active_material(0) as StandardMaterial3D
	check("actual imported surfaces use authored vertex pigments",shell_material!=null and mantle_material!=null and shell_material.vertex_color_use_as_albedo and mantle_material.vertex_color_use_as_albedo)
	check("reference is planted in the same terrain",absf(root.position.y-stage.builder._terrain_height(stage,root.position.x,root.position.z))<.03)
	var original_time: float=main.world.simulation_time_s
	var original_pose: Transform3D=root.transform
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("whole-body topic reaches the imported specimen",panel.select_topic("giant_clam") and main._content_follow==12)
	await settle()
	check("whole-body view and two structure marks are observable",subject_visible(root) and main.learning_overlay.last_visible_marks==2)
	check("lesson exposes source and authored-versus-measured boundary",panel.lesson_source.visible and panel.lesson_text.text.contains("Tridacna maxima") and panel.lesson_text.text.contains("没有测量个体") and Reference.allows_url("reef",str(targets[12].source_url)))
	await capture("clam-whole")
	panel.object_picker.item_selected.emit(14)
	await settle()
	check("shell detail view stays on the same animal",main._content_follow==13 and stage.camera.unproject_position(scutes.global_position).x>panel.get_global_rect().end.x)
	await capture("clam-scutes")
	check("mantle topic selects the upward tissue",panel.select_topic("giant_clam_mantle") and main._content_follow==14)
	await settle()
	check("mantle is rendered in close view with both annotations",main.learning_overlay.last_visible_marks==2 and await part_pixels(root,mantle.global_position,Vector2i(24,20))>30)
	check("source and limit remain visible in the close lesson",panel.lesson_source.visible and panel.lesson_text.text.contains("不直接表示光合产量") and Reference.allows_url("reef",str(targets[14].source_url)))
	await capture("clam-mantle")
	check("static observation does not advance or duplicate world state",main.world.simulation_time_s==original_time and root.transform.is_equal_approx(original_pose) and main.world.checkpoint().version==14)
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="giant_clam_mantle": action=button
	check("guide offers both new reef routes",action!=null and main.world_guide.route_buttons.size()==46)
	if action!=null: action.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	await settle()
	stage=main.coordinator.active_scene
	check("guide returns to the same lesson and one world time",main.world.current_scale_id=="reef" and main.learning_overlay.topic=="giant_clam_mantle" and main.world.simulation_time_s==original_time and stage.get_meta("clam_root").get_meta("stable_id")=="3dworld:teaching:tridacna-maxima:0001")
	await capture("clam-guide-return")
	await finish()


func part_pixels(subject: Node3D, point: Vector3, radius: Vector2i) -> int:
	var stage: Node=main.coordinator.active_scene
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var before: Image=stage.viewport.get_texture().get_image()
	var center: Vector2i=Vector2i(stage.camera.unproject_position(point))
	subject.hide()
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var after: Image=stage.viewport.get_texture().get_image()
	subject.show()
	var changed: int=0
	for y: int in range(maxi(0,center.y-radius.y),mini(before.get_height(),center.y+radius.y+1)):
		for x: int in range(maxi(0,center.x-radius.x),mini(before.get_width(),center.x+radius.x+1)):
			var color: Color=before.get_pixel(x,y)
			var hidden: Color=after.get_pixel(x,y)
			if maxf(absf(color.r-hidden.r),maxf(absf(color.g-hidden.g),absf(color.b-hidden.b)))>.05: changed+=1
	for frame: int in range(3): await RenderingServer.frame_post_draw
	print("CLAM_VISIBLE_PIXELS ",changed)
	return changed
