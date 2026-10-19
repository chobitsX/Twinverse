extends "res://tests/integration/solar_orbit_views_suite.gd"
const Activity = preload("res://scripts/experience/sea_cucumber_activity.gd")
const Science = preload("res://scripts/experience/science_reference.gd")
const Cucumber = preload("res://scripts/experience/black_sea_cucumber_observation.gd")
var phase_samples: Array[Dictionary] = []

func tips(root: Node3D) -> Array[Vector3]:
	var values: Array[Vector3] = []
	for joint: Dictionary in root.get_meta("authored_feeding_joints"):
		var node: MeshInstance3D = joint.tip
		values.append(node.to_global(node.get_aabb().get_center()))
	return values

func visible_point(point: Vector3) -> bool:
	var camera: Camera3D = main.coordinator.active_scene.camera
	var at: Vector2 = camera.unproject_position(point)
	return not camera.is_position_behind(point) and at.x>main.explorer_panel.get_global_rect().end.x+8 and at.x<get_window().size.x-12 and at.y>120 and at.y<get_window().size.y-130

func sample(label: String, root: Node3D) -> void:
	var good: bool = true
	var coordinates: Array = []
	for joint: Dictionary in root.get_meta("authored_feeding_joints"):
		good = good and joint.pivot.position.is_equal_approx(joint.base) and joint.arm.get_parent()==joint.pivot and joint.tip.get_parent()==joint.pivot
	for point: Vector3 in tips(root):
		good = good and point.is_finite() and visible_point(point)
		coordinates.append([point.x,point.y,point.z])
	check(label+" twelve actual tentacles stay attached and visible",good and coordinates.size()==12)
	phase_samples.append({"view":label,"world_time_s":main.world.simulation_time_s,"tips":coordinates,"phase_label":Activity.phase_label(main.world.simulation_time_s)})

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world247-review="): directory=argument.trim_prefix("--world247-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	get_tree().create_timer(90).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage(): await finish(); return
	get_window().size=Vector2i(1280,800)
	main._audio.volume_db=-80
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world.set_time_scale(2)
	main.world.simulation_time_s=0
	main.set_solar_rate(0)
	main.world_guide.hide()
	main.explorer_panel.show()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var root: Node3D = stage.get_meta("holothuria_root")
	var body_pose: Transform3D = root.transform
	var identity: int = root.get_instance_id()
	var world_id: int = main.world.get_instance_id()
	var checkpoint: Dictionary = main.world.checkpoint()
	Activity.animate(stage,6)
	check("derived oral pose writes no authoritative checkpoint",main.world.checkpoint()==checkpoint)
	Activity.animate(stage,0)
	var panel: Node = main.explorer_panel
	check("original whole lesson and individual remain available",panel.select_topic("black_sea_cucumber") and root.get_meta("stable_id")=="3dworld:teaching:holothuria-atra:0001")
	await settle()
	check("whole view keeps fixed original body and pigment",root.transform.is_equal_approx(body_pose) and root.scale.is_equal_approx(Vector3.ONE) and stage.get_meta("reef_placement_mode")=="baked")
	await capture("cucumber-whole")
	check("actual oral lesson targets the same individual",panel.select_topic("black_sea_cucumber_feeding"))
	await settle()
	var start: Array[Vector3] = tips(root)
	sample("cucumber-extended",root)
	check("oral readout explains author cycle and pause",panel.lesson_readout.text.contains("12秒循环为作者设置") and panel.lesson_readout.text.contains("已暂停") and panel.lesson_text.text.contains("没有颗粒抓取"))
	check("activity primary source belongs to original reef science panel",panel.lesson_source.visible and panel._topic.source==Cucumber.ACTIVITY_SOURCE and Science.allows_url("reef",Cucumber.ACTIVITY_SOURCE))
	await capture("cucumber-extended")
	main.world.simulation_time_s=6
	await settle()
	var inward: Array[Vector3] = tips(root)
	var moved: int = 0
	for index: int in range(12):
		if start[index].distance_to(inward[index])>.001: moved+=1
	check("actual world seconds move ten staggered tips and keep symmetric midpoints",moved==10 and start[3].distance_to(inward[3])<1e-6 and start[9].distance_to(inward[9])<1e-6 and root.transform.is_equal_approx(body_pose))
	sample("cucumber-retracted",root)
	await capture("cucumber-retracted")
	get_window().size=Vector2i(900,650)
	await settle()
	sample("cucumber-compact",root)
	check("compact lesson readout and title fit",panel.scroll.get_global_rect().grow(.5).encloses(panel.lesson_readout.get_global_rect()))
	await capture("cucumber-compact")
	get_window().size=Vector2i(1280,800)
	main.world.simulation_time_s=12
	await settle()
	var repeat: Array[Vector3] = tips(root)
	var closed: bool = true
	for index: int in range(12): closed = closed and start[index].distance_to(repeat[index])<1e-6
	check("cycle boundary restores same authored mesh pose",closed and root.get_instance_id()==identity)
	sample("cucumber-cycle-return",root)
	await capture("cucumber-cycle-return")
	var paused_pose: Array[Vector3] = tips(root)
	await settle()
	check("original pause keeps actual tips stationary",tips(root)==paused_pose and main.world.simulation_time_s==12)
	main.world.set_paused(false)
	await settle()
	main.world.set_paused(true)
	await settle()
	check("original continue advances world and oral pose",main.world.simulation_time_s>12 and tips(root)!=paused_pose and root.transform.is_equal_approx(body_pose))
	var time: float = main.world.simulation_time_s
	if not await arrive("earth"): await finish(); return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="black_sea_cucumber_feeding": action=button
	check("original guide still owns the oral entry",action!=null and main.world_guide.route_buttons.size()==93)
	if action!=null: action.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	stage=main.coordinator.active_scene
	root=stage.get_meta("holothuria_root")
	var restored: Array[Vector3] = tips(root)
	Activity.animate(stage,time)
	check("guide returns to original stable animal and same world seconds",main.learning_overlay.topic=="black_sea_cucumber_feeding" and main.world.get_instance_id()==world_id and main.world.simulation_time_s==time and root.get_meta("stable_id")=="3dworld:teaching:holothuria-atra:0001" and tips(root)==restored)
	await capture("cucumber-guide-return")
	check("two worker no-save diagnostic budget remains",int(ProjectSettings.get_setting("threading/worker_pool/max_threads"))==2 and Engine.max_fps==5 and not main._persistence_enabled and main._render_ratio==.75 and get_window().unfocusable and get_viewport().gui_disable_input)
	observations={"samples":phase_samples,"world_time_s":time,"short_continue_advanced":time>12,"paused":main.world.paused,"time_scale":main.world.time_scale,"date_jd":main.solar_jd,"solar_rate":main.solar_rate,"original_body_fixed":true,"named_species":41,"guide_routes":93,"cycle_s":12,"author_tentacles":12,"authority_unchanged":main.world.get_instance_id()==world_id,"worker_pool_threads":2,"max_fps":Engine.max_fps,"foreground_fps":ProjectSettings.get_setting("application/run/max_fps"),"render_ratio":main._render_ratio,"persistence_enabled":main._persistence_enabled,"user_save_accessed":false,"audio_volume_db":main._audio.volume_db,"unfocusable":get_window().unfocusable,"native_input_disabled":get_viewport().gui_disable_input}
	await finish()

func finish() -> void:
	var output: FileAccess = FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"status":"completed","cases":cases,"failures":failures,"captures":captures,"observations":observations,"capture_window_settings":view_settings,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false},"  ")+"\n")
	output.close()
	print("SEA_CUCUMBER247_FINISHED ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
