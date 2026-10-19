extends "res://tests/integration/deer_skin_suite.gd"
const RobinSkin = preload("res://scripts/experience/robin_skin_motion.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world118-check="): directory=argument.trim_prefix("--world118-check=")
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
	if not await arrive("woodland"):
		await finish()
		return
	main.ground_light_preview=false
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	var birds: Array[Node3D] = []
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind=="bird": birds.append(actor.node)
	check("existing twelve robins use the new rig without changing population",birds.size()==12 and birds[0].has_meta("robin_skin"))
	if birds.size()!=12 or not birds[0].has_meta("robin_skin"):
		await finish()
		return
	var bird: Node3D = birds[0]
	var data: Dictionary = bird.get_meta("robin_skin")
	var body: MeshInstance3D = bird.find_child("RobinSkin",true,false) as MeshInstance3D
	check("actual release imports continuous skin and seventeen articulated bones",body!=null and body.skin!=null and data.skeleton.get_bone_count()==17)
	check("existing bird topic selects the same stable representative",panel.select_topic("bird") and main._content_follow==1 and bird.get_meta("stable_id")=="3dworld:teaching:robin:0000")
	await at_time(0.)
	check("standing posed geometry and all three attached marks are visible",posed_visible(bird) and main.learning_overlay.last_visible_marks==3)
	check("body and actual left foot render above the habitat",await part_pixels(bird,bird.to_global(Vector3(.01,.12,0)),Vector2i(35,30))>100 and await part_pixels(bird,RobinSkin.point(bird,"FootL",Vector3(.012,.003,.015)),Vector2i(10,10))>5)
	await capture("robin-standing")
	var minimum: float = INF
	var maximum_standing: float = -INF
	for t: float in [0.,3.1,3.2,5.7,12.7,21.5,47.5]:
		await at_time(t)
		for key: String in ["FootL","FootR"]:
			var p: Vector3 = RobinSkin.point(bird,key,Vector3(.014,.002,.015 if key=="FootL" else -.015))
			var clearance: float = p.y-stage.builder._height(p.x,p.z)
			minimum=minf(minimum,clearance)
			if t in [0.,5.7,12.7,21.5,47.5]:maximum_standing=maxf(maximum_standing,clearance)
	check("sampled toes clear local terrain and standing feet stay close",minimum>=-.001 and maximum_standing<.012)
	print("ROBIN118_TERRAIN_CLEARANCE ",minimum," ",maximum_standing)
	await at_time(5.7)
	check("inspection visibly deforms the head neck and markers together",posed_visible(bird) and main.learning_overlay.last_visible_marks==3 and panel.lesson_readout.text.contains("停步"))
	await capture("robin-inspection")
	await at_time(29.)
	check("flight skin stays in frame with extended layered wings",posed_visible(bird) and main.learning_overlay.last_visible_marks==3 and float(bird.get_meta("height_above_ground_m"))>.5)
	check("flight body and wing pixels actually render",await part_pixels(bird,bird.to_global(Vector3(0,.12,0)),Vector2i(35,30))>80 and await part_pixels(bird,RobinSkin.point(bird,"WingLHand",Vector3(-.04,.12,.15)),Vector2i(10,10))>5)
	await capture("robin-flight")
	var transform: Transform3D = bird.transform
	var wing: Quaternion = data.skeleton.get_bone_pose_rotation(data.bones.WingL.id)
	await settle()
	check("pause freezes root and skin pose on the same world time",bird.transform.is_equal_approx(transform) and wing.is_equal_approx(data.skeleton.get_bone_pose_rotation(data.bones.WingL.id)) and main.world.simulation_time_s==29.)
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("ordinary host clock advances both route and skin",main.world.simulation_time_s>29.1 and bird.position.distance_to(transform.origin)>.02 and not wing.is_equal_approx(data.skeleton.get_bone_pose_rotation(data.bones.WingL.id)))
	await at_time(45.)
	check("landing extends feet while retaining a visible subject",float(bird.get_meta("height_above_ground_m"))<.06 and panel.lesson_readout.text.contains("伸足") and posed_visible(bird))
	await capture("robin-landing")
	await at_time(47.5)
	transform=bird.transform
	wing=data.skeleton.get_bone_pose_rotation(data.bones.WingL.id)
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	bird=main.content_targets()[1].node
	data=bird.get_meta("robin_skin")
	check("scene return reconstructs stable identity root and folded pose",bird.get_meta("stable_id")=="3dworld:teaching:robin:0000" and bird.transform.is_equal_approx(transform) and wing.is_equal_approx(data.skeleton.get_bone_pose_rotation(data.bones.WingL.id)))
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="bird": action=button
	check("existing guide still exposes all thirty-six topics",action!=null and main.world_guide.route_buttons.size()==36)
	if action!=null:action.pressed.emit()
	get_window().size=Vector2i(900,650)
	await at_time(12.7)
	await settle()
	check("compact observation keeps posed bird markers and controls visible",posed_visible(bird) and main.learning_overlay.last_visible_marks==3 and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-12)
	check("lesson identifies the adult reference and authored anatomy limits",panel.lesson_text.text.contains("成鸟雄性") and panel.lesson_text.text.contains("未标定个体解剖") and panel.lesson_text.text.contains("不是实测飞行速度"))
	await capture("robin-compact")
	await finish()

func posed_visible(subject: Node3D) -> bool:
	var camera: Camera3D = main.coordinator.active_scene.camera
	var count: int = 0
	var bounds: Rect2
	var clear: bool = true
	for child: Node in subject.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		var skeleton: Skeleton3D = mesh.get_node(mesh.skeleton) as Skeleton3D
		var transforms: Array[Transform3D] = []
		for bind: int in range(mesh.skin.get_bind_count()):
			var id: int = mesh.skin.get_bind_bone(bind)
			if id<0:id=skeleton.find_bone(mesh.skin.get_bind_name(bind))
			transforms.append(skeleton.global_transform*skeleton.get_bone_global_pose(id)*mesh.skin.get_bind_pose(bind))
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var stride: int = 8 if mesh.mesh.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
			for index: int in range(vertices.size()):
				var world: Vector3 = Vector3.ZERO
				for n: int in range(stride):world+=(transforms[bones[index*stride+n]]*vertices[index])*weights[index*stride+n]
				var point: Vector2 = camera.unproject_position(world)
				bounds=Rect2(point,Vector2.ZERO) if count==0 else bounds.expand(point)
				count+=1
				clear=clear and world.is_finite() and not camera.is_position_behind(world) and point.x>main.explorer_panel.get_global_rect().end.x+8 and point.x<get_window().size.x-8 and point.y>80 and point.y<get_window().size.y-60
	print("ROBIN118_POSED_BOUNDS ",bounds," vertices=",count)
	return count>0 and clear
