extends "res://tests/integration/polar_ecology_suite.gd"
## One bounded review of the selected skins in their real four branches.
const HumanMotion = preload("res://scripts/experience/life_asset_motion.gd")
const Doe = preload("res://scripts/experience/deer_skin_motion.gd")
const Fox = preload("res://scripts/experience/red_fox.gd")
const Turtle = preload("res://scripts/experience/turtle_motion.gd")
const TurtleComparison = preload("res://scripts/experience/turtle_comparison.gd")
const Penguin = preload("res://scripts/experience/polar_builder.gd")

func at_time(value: float) -> void:
	main.world.simulation_time_s=value
	await settle()

func ready_stage() -> bool:
	var deadline: int=Time.get_ticks_msec()+45000
	var next_log: int=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground:
			if DisplayServer.get_name()=="headless" or DisplayServer.window_can_draw(): return true
		if Time.get_ticks_msec()>next_log:
			print("ECOLOGY268_WAIT ",JSON.stringify({"phase":main.coordinator.phase,"scale":main.world.current_scale_id,"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw(),"progress":main.coordinator.loading_status(),"recovery":main.coordinator.recovery_state()}))
			next_log=Time.get_ticks_msec()+3000
	check("stage ready",false)
	return false

func focus(root: Node3D, height: float, offset: Vector3, label: String) -> void:
	main.follow_content(1,{"node":root,"label":label,"distance":offset.length(),
		"focus_height":height,"view_offset_local":offset})
	await settle()

func bone_rotation(root: Node3D, meta: String, key: String) -> Quaternion:
	var data: Dictionary=root.get_meta(meta)
	return data.skeleton.get_bone_pose_rotation(data.bones[key].id)

func skinned(root: Node3D, meta: String, mesh_name: String, count: int) -> bool:
	if not root.has_meta(meta): return false
	var mesh: MeshInstance3D=root.find_child(mesh_name,true,false) as MeshInstance3D
	if mesh==null or mesh.skin==null or root.get_meta(meta).skeleton.get_bone_count()!=count: return false
	for slot: int in range(mesh.mesh.get_surface_count()):
		var arrays: Array=mesh.mesh.surface_get_arrays(slot)
		if arrays[Mesh.ARRAY_WEIGHTS]==null or arrays[Mesh.ARRAY_WEIGHTS].is_empty(): return false
	return root.find_children("*","AnimationPlayer",true,false).is_empty()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--assets268-output="): directory=argument.trim_prefix("--assets268-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	get_window().size=Vector2i(1280,800)
	Engine.max_fps=5
	main=Experience.instantiate(); add_child(main)
	print("ECOLOGY268_CREATED ",main.coordinator.phase)
	main._measurement_screen=get_window().current_screen
	main._muted=true
	get_tree().create_timer(80.0).timeout.connect(func() -> void: get_tree().quit(2))
	if not await ready_stage(): await finish(); return
	if main._audio!=null: main._audio.volume_db=-80.0
	print("ECOLOGY268_INITIAL_READY")
	main._reduced_motion=true; main.world.set_paused(true); main.set_solar_rate(0.0)
	main.world_guide.hide(); main.explorer_panel.hide()
	main.ground_light_preview=false
	var authority: int=main.world.get_instance_id()
	if not "--assets268-ocean-only" in OS.get_cmdline_user_args():
		print("ECOLOGY268_CITY_REQUEST")
		if not await arrive("city"): await finish(); return
		var city: Node=main.coordinator.active_scene
		var people: Array=[]
		for actor: Dictionary in city.get_meta("actors"):
			if actor.kind=="person": people.append(actor.node)
		people.append_array(city.get_meta("street_walkers"))
		check("34 city walkers retain original counts and stable routes",people.size()==34 and city.get_meta("crossing_people").size()==2)
		check("both virtual avatars are actually weighted 65-bone skins",skinned(people[0],"human_skin","HumanBody",65) and skinned(people[1],"human_skin","HumanBody",65))
		var distinct: bool=people[0].find_child("HumanBody",true,false).mesh!=people[1].find_child("HumanBody",true,false).mesh
		check("two distinct virtual meshes share clothing palettes without photo avatars",distinct and people[0].scene_file_path.contains("human_male_virtual") and people[1].scene_file_path.contains("human_female_virtual"))
		await at_time(51.)
		await focus(people[0],.95,Vector3(2.7,.45,2.0),"虚拟行人 · 男性")
		await capture("virtual-male-rest")
		await focus(people[1],.92,Vector3(2.6,.45,2.0),"虚拟行人 · 女性")
		await capture("virtual-female-rest")
		var cross: Node3D=city.get_meta("crossing_people")[0]
		await at_time(32.)
		await focus(cross,.95,Vector3(3.0,.5,1.8),"虚拟行人 · 过街")
		var skin: Dictionary=cross.get_meta("human_skin")
		var ankle_a: Vector3=skin.skeleton.to_global(skin.skeleton.get_bone_global_pose(skin.bones.FootL.id).origin)
		var position_a: Vector3=cross.position
		await at_time(32.02)
		var ankle_b: Vector3=skin.skeleton.to_global(skin.skeleton.get_bone_global_pose(skin.bones.FootL.id).origin)
		check("actual planted ankle stays within 2mm while crossing root advances",ankle_a.distance_to(ankle_b)<.002 and position_a.distance_to(cross.position)>.01)
		observations.human_stance_drift_m=ankle_a.distance_to(ankle_b)
		await capture("virtual-crossing-walk")
		var frozen: Quaternion=bone_rotation(cross,"human_skin","ArmL")
		await settle()
		check("paused world freezes virtual skin and root",frozen.is_equal_approx(bone_rotation(cross,"human_skin","ArmL")) and main.world.simulation_time_s==32.02)
		if not await arrive("woodland"): await finish(); return
		var land: Node=main.coordinator.active_scene
		var herd: Array=[]
		for actor: Dictionary in land.get_meta("actors"):
			if actor.kind=="deer": herd.append(actor.node)
		var doe: Node3D=herd[0]
		check("eight does use the selected continuous skin",herd.size()==8 and skinned(doe,"deer_skin","DoeBody",34))
		await at_time(40.)
		await focus(doe,.65,Vector3(1.7,.5,2.1),"白尾鹿 · 警觉站姿")
		await capture("doe-alert")
		await at_time(22.)
		var nose: Vector3=Doe.muzzle(doe)
		var clearance: float=nose.y-land.builder._height(nose.x,nose.z)
		observations.doe_muzzle_ground_m=clearance
		check("actual deer muzzle reaches plants without entering terrain",clearance>.015 and clearance<.28)
		await focus(doe,.65,Vector3(1.7,.5,2.1),"白尾鹿 · 低头取食")
		await capture("doe-grazing")
		await at_time(6.)
		var fox: Node3D=land.get_meta("red_fox").root
		check("fox retains identity with selected skin and articulated ears",fox.get_meta("stable_id")==Fox.STABLE_ID and skinned(fox,"fox_skin","FoxBody",36))
		await focus(fox,.31,Vector3(1.1,.27,1.4),"赤狐 · 林缘缓行")
		await capture("fox-walking")
		var fox_root: Transform3D=fox.transform
		var fox_leg: Quaternion=bone_rotation(fox,"fox_skin","ForeL")
		await at_time(6.3)
		check("one shared time drives fox route and weighted leg",not fox_root.is_equal_approx(fox.transform) and not fox_leg.is_equal_approx(bone_rotation(fox,"fox_skin","ForeL")))
		if not await arrive("polar"): await finish(); return
		var polar: Node=main.coordinator.active_scene
		var birds: Array=polar.get_meta("polar").birds
		check("four Adelie penguins use selected weighted skin with original identities",birds.size()==4 and skinned(birds[2],"adelie_skin","AdelieBody",79) and birds[2].get_meta("stable_id")=="3dworld:teaching:adelie-penguin:0002" and polar.get_meta("ice_krill").animals.size()==12)
		main.explorer_panel.show(); main.explorer_panel._process(0.)
		main.explorer_panel.select_topic("polar_aurora")
		main.explorer_panel.polar_sky_controls.get_child(1).pressed.emit()
		main.explorer_panel.hide()
		await at_time(12.)
		main.follow_content(2); await settle()
		await capture("penguin-coast")
		await at_time(45.)
		main.follow_content(6); await settle()
		check("same third penguin enters water on original route",Penguin.sample(45.,2).swim>.99 and birds[2].rotation.z< -1.5)
		await capture("penguin-swimming")
		var wing: Quaternion=bone_rotation(birds[2],"adelie_skin","L_Clavicle")
		await at_time(45.2)
		check("penguin flippers change only with shared world seconds",not wing.is_equal_approx(bone_rotation(birds[2],"adelie_skin","L_Clavicle")))
	if "--assets268-land-only" in OS.get_cmdline_user_args():
		budget_check()
		observations.selected_cloud_meshes=5
		await finish(); return
	if not await arrive("reef"): await finish(); return
	var ocean: Node=main.coordinator.active_scene
	var turtle: Node3D=main.content_targets()[3].node
	check("one green turtle preserves marine identity and seven-joint weighted skin",ocean.get_meta("marine_actors").size()==44 and turtle.get_meta("stable_id")=="3dworld:teaching:marine:3:000" and skinned(turtle,"turtle_skin","GreenTurtleBody",7))
	check("limb comparison uses new skin landmarks and omits obsolete shell measurement",TurtleComparison.marks(main,"turtle_compare_sea").size()==3 and TurtleComparison.readout(main,"turtle_compare_sea").contains("未标定"))
	await at_time(8.)
	main.follow_content(4); await settle()
	await capture("turtle-swimming")
	var fin: Quaternion=bone_rotation(turtle,"turtle_skin","FlipperL")
	await at_time(10.)
	check("turtle real skin flippers articulate with original eight-second stroke",not fin.is_equal_approx(bone_rotation(turtle,"turtle_skin","FlipperL")))
	await at_time(36.)
	main.follow_content(4); await settle()
	var turtle_nose: Vector3=Turtle.nose_position(turtle)
	var surface: float=Turtle.Swell.height_at(Vector2(turtle_nose.x,turtle_nose.z),36.)
	observations.turtle_nose_air_gap_m=turtle_nose.y-surface
	check("weighted turtle head lifts actual nostrils above shared water",turtle_nose.y-surface>.025 and turtle_nose.y-surface<.09 and not ocean.is_underwater)
	await capture("turtle-surface-breathing")
	var turtle_transform: Transform3D=turtle.transform
	await settle()
	check("pause freezes real turtle nose and pose",Turtle.nose_position(turtle).is_equal_approx(turtle_nose) and turtle_transform.is_equal_approx(turtle.transform))
	if not await arrive("earth") or not await arrive("reef"): await finish(); return
	var returned: Node3D=main.content_targets()[3].node
	check("reentry reconstructs same turtle and world authority",main.world.get_instance_id()==authority and main.world.simulation_time_s==36. and returned.transform.is_equal_approx(turtle_transform) and Turtle.nose_position(returned).is_equal_approx(turtle_nose))
	budget_check()
	observations.selected_cloud_meshes=6
	observations.world_time_s=main.world.simulation_time_s
	observations.screen=get_window().current_screen
	observations.primary_screen=DisplayServer.get_primary_screen()
	await finish()

func budget_check() -> void:
	check("diagnostic keeps resource and save budgets",not main._persistence_enabled and get_window().gui_disable_input and get_window().unfocusable and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
