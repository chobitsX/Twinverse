extends "res://tests/integration/robin_motion_suite.gd"
const Deer = preload("res://scripts/experience/deer_skin_motion.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world105-check="): directory=argument.trim_prefix("--world105-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless" and DisplayServer.get_screen_count()==1:
		main._measurement_screen=get_window().current_screen
		get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("woodland"):
		await finish()
		return
	main.ground_light_preview=false
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	var herd: Array[Node3D] = []
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind=="deer": herd.append(actor.node)
	check("eight continuous-skinned does retain the woodland population",herd.size()==8 and main.content_targets().size()==8 and stage.get_meta("pollinators").size()==4)
	if herd.size()!=8 or not herd[0].has_meta("deer_skin"):
		check("imported doe skin exists",false)
		await finish()
		return
	var deer: Node3D = herd[0]
	var data: Dictionary = deer.get_meta("deer_skin")
	var coat: MeshInstance3D = deer.find_child("ContinuousCoat",true,false) as MeshInstance3D
	check("coat is a real imported skinned mesh with nineteen joints",coat!=null and coat.skin!=null and data.skeleton.get_bone_count()==19)
	var material: StandardMaterial3D = coat.mesh.surface_get_material(0) as StandardMaterial3D
	check("original coat pigment is enabled in engine",material!=null and material.vertex_color_use_as_albedo)
	check("existing deer lesson selects the actual animal",panel.select_topic("graze") and main._content_follow==0)
	await at_time(40.)
	check("alert muzzle and observation marks are visible",Deer.muzzle(deer).y-deer.position.y>1.1 and subject_visible(deer) and main.learning_overlay.last_visible_marks==3 and await visible_pixels(deer)>100)
	check("selected forehoof visibly renders instead of another foreground animal",await part_pixels(deer,Deer.point(deer,"ForeLHoof",Vector3(.368,.052,.153)))>15)
	await capture("doe-alert")
	await at_time(22.)
	var mouth: Vector3 = Deer.muzzle(deer)
	var height: float = mouth.y-stage.builder._height(mouth.x,mouth.z)
	check("feeding muzzle reaches local low vegetation without penetrating terrain",height>.025 and height<.25)
	check("feeding subject remains visible and labels follow mouth",subject_visible(deer) and main.learning_overlay.last_visible_marks==3 and await visible_pixels(deer)>100)
	print("DOE_NATIVE_MUZZLE_GROUND_M ",height)
	await capture("doe-feeding")
	var transform: Transform3D = deer.transform
	var head: Quaternion = data.skeleton.get_bone_pose_rotation(data.bones.Head.id)
	await settle()
	check("world pause freezes root and skin pose",deer.transform.is_equal_approx(transform) and head.is_equal_approx(data.skeleton.get_bone_pose_rotation(data.bones.Head.id)) and main.world.simulation_time_s==22.)
	await at_time(6.)
	transform=deer.transform
	var leg: Quaternion = data.skeleton.get_bone_pose_rotation(data.bones.ForeL.id)
	await capture("doe-walking")
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("one host clock advances root and limb skin together",main.world.simulation_time_s>6.1 and deer.position.distance_to(transform.origin)>.02 and not leg.is_equal_approx(data.skeleton.get_bone_pose_rotation(data.bones.ForeL.id)))
	await at_time(22.)
	transform=deer.transform
	head=data.skeleton.get_bone_pose_rotation(data.bones.Head.id)
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	deer=main.content_targets()[0].node
	data=deer.get_meta("deer_skin")
	check("return reconstructs stable doe identity and feeding pose",deer.get_meta("stable_id")=="3dworld:teaching:doe:0000" and deer.transform.is_equal_approx(transform) and head.is_equal_approx(data.skeleton.get_bone_pose_rotation(data.bones.Head.id)) and main.world.simulation_time_s==22.)
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="graze": action=button
	check("existing guide still enters deer observation",action!=null and main.world_guide.route_buttons.size()==22)
	if action!=null: action.pressed.emit()
	get_window().size=Vector2i(900,650)
	await at_time(22.)
	await settle()
	check("compact feeding view keeps animal and mark toggle visible",subject_visible(deer) and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-12 and main.learning_overlay.last_visible_marks==3)
	check("lesson states static summer and authored motion limits",panel.lesson_text.text.contains("固定夏毛") and panel.lesson_text.text.contains("生物力学"))
	await capture("doe-compact")
	await finish()

func visible_pixels(subject: Node3D) -> int:
	return await part_pixels(subject,subject.to_global(Vector3(0,1.,0)),Vector2i(35,30))

func part_pixels(subject: Node3D, point: Vector3, radius: Vector2i = Vector2i(12,12)) -> int:
	var stage: Node = main.coordinator.active_scene
	for i: int in range(3): await RenderingServer.frame_post_draw
	var before: Image = stage.viewport.get_texture().get_image()
	var center: Vector2i = Vector2i(stage.camera.unproject_position(point))
	subject.hide()
	for i: int in range(3): await RenderingServer.frame_post_draw
	var after: Image = stage.viewport.get_texture().get_image()
	subject.show()
	var count: int = 0
	for y: int in range(maxi(0,center.y-radius.y),mini(before.get_height(),center.y+radius.y+1)):
		for x: int in range(maxi(0,center.x-radius.x),mini(before.get_width(),center.x+radius.x+1)):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.05: count+=1
	for i: int in range(3): await RenderingServer.frame_post_draw
	print("DOE_VISIBLE_PIXELS ",count)
	return count
