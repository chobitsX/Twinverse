extends "res://tests/integration/observation_framing_suite.gd"
const Polar = preload("res://scripts/experience/polar_builder.gd")
const Activity = preload("res://scripts/experience/adelie_activity.gd")
const Krill = preload("res://scripts/experience/polar_krill.gd")
var observations: Dictionary = {}
var pose_samples: Array[Dictionary] = []

func at_time(value: float) -> void:
	main.world.simulation_time_s=value
	await settle()

func core_checkpoint() -> Dictionary:
	var value: Dictionary=main.world.checkpoint()
	value.erase("current_scale_id"); value.erase("local_habitat")
	return value

func record_pose(label: String, bird: Node3D, data: Dictionary) -> void:
	pose_samples.append({"view":label,"world_time_s":main.world.simulation_time_s,
		"position":[bird.position.x,bird.position.y,bird.position.z],
		"activity":bird.get_meta("activity"),"swim":Polar.sample(main.world.simulation_time_s,2).swim,
		"flipper_angle":(data.activity_rig.flippers[0] as Node3D).rotation.x,
		"leg_angle":(data.activity_rig.legs[0] as Node3D).rotation.z,
		"follow":main._content_follow,"date_jd":main.solar_jd,
		"camera_underwater":main.coordinator.active_scene.is_underwater})

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world231-review="): directory=argument.trim_prefix("--world231-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size=Vector2i(1280,800)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	check("diagnostic cannot consume desktop focus or input",get_window().unfocusable and get_viewport().gui_disable_input)
	get_tree().create_timer(110.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage():
		await finish(); return
	main._audio.volume_db=-80.0
	main._reduced_motion=true
	main.world.set_paused(true); main.world.set_time_scale(2.0)
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.world_guide.hide()
	if not await arrive("polar"):
		await finish(); return
	main.ground_light_preview=false
	await at_time(12.0)
	var authority: int=main.world.get_instance_id()
	var date: float=main.solar_jd
	var baseline: Dictionary=main.world.checkpoint().duplicate(true)
	var core: Dictionary=core_checkpoint()
	var stage: Node=main.coordinator.active_scene
	var data: Dictionary=stage.get_meta("polar",{})
	check("actual polar scene keeps four penguins",data.get("birds",[]).size()==4)
	if data.is_empty():
		await finish(); return
	var bird: Node3D=data.birds[2]
	var rig: Dictionary=data.activity_rig
	var stable: String=str(bird.get_meta("stable_id",""))
	check("moving subject is original unscaled third adult",stable=="3dworld:teaching:adelie-penguin:0002" and bird.scale==Vector3.ONE)
	check("actual existing meshes form two flippers legs and tail",rig.flippers.size()==2 and rig.legs.size()==2 and (rig.flippers[0] as Node3D).get_child_count()==3 and (rig.flippers[1] as Node3D).get_child_count()==3 and (rig.legs[0] as Node3D).get_child_count()==5 and (rig.legs[1] as Node3D).get_child_count()==5 and (rig.tail as Node3D).get_child_count()==5 and rig.head==bird.find_child("HeadPivot",true,false))
	var old_first: Vector3=Polar.sample(12.0,0).position
	var fixed_last: Vector3=Polar.sample(12.0,3).position
	check("original first pair and static fourth keep their established poses",(data.birds[0] as Node3D).position.distance_to(old_first)<.001 and (data.birds[3] as Node3D).position==fixed_last)
	var targets: Array[Dictionary]=main.content_targets(false)
	check("old five observer indices remain before two appended activity views",targets.size()==7 and targets[0].node==data.overview and targets[1].node==data.birds[0] and targets[2].node==stage.get_meta("ice_krill").overview and targets[3].node==stage.get_meta("ice_krill").animals[0] and targets[4].node==stage.get_meta("ice_krill").head_focus and targets[5].node==data.activity_focus and targets[6].node==data.activity_overview)
	var floes: int=0
	for child: Node in stage.world_root.get_children():
		if child.name.begins_with("AuthoredIceFloe_"): floes+=1
	check("twelve floes and twelve krill remain in the same unchanged coast",floes==12 and stage.get_meta("ice_krill").animals.size()==12 and stage.world_root.has_node("ExposedRockCoast"))
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("original penguin topic defaults to same first adult",panel.select_topic("adelie_penguin") and main._content_follow==1 and main.solar_jd==date and main.world.simulation_time_s==12.0)
	await settle()
	check("actual three view buttons are visible before long explanation",panel.penguin_view_controls.is_visible_in_tree() and panel.penguin_view_controls.get_child_count()==3 and panel.penguin_view_controls.get_global_rect().end.y<=panel.lesson_text.get_global_rect().position.y)
	await capture("penguin-original-shape")
	var before_view: Dictionary=core_checkpoint()
	(panel.penguin_view_controls.get_child(1) as Button).pressed.emit()
	await settle()
	check("actual follow button selects third bird center without modifying world or date",main._content_follow==5 and core_checkpoint()==before_view and main.solar_jd==date and main.world.paused and main.solar_rate==0.0)
	check("follow center is transformed from the same actual body",data.activity_focus.position.distance_to(stage.world_root.to_local(bird.to_global(Vector3(0,.325,0))))<.0001 and main._orbit_target.distance_to(data.activity_focus.position)<.001)
	check("land phase stays upright on actual dry shore",absf(bird.rotation.z)<.001 and bird.position.z>Polar._shore_z(bird.position.x)+.2 and absf(bird.position.y-Polar._rock_height(bird.position.x,bird.position.z)+.011)<.001)
	await at_time(12.1)
	check("walking feet have opposite actual transforms",absf((rig.legs[0] as Node3D).rotation.z-(rig.legs[1] as Node3D).rotation.z)>.01)
	check("walking geometry remains observable beside lesson panel",subject_visible(bird))
	record_pose("walk",bird,data)
	await capture("penguin-walk")
	var first_foot: Transform3D=(rig.legs[0] as Node3D).transform
	await at_time(12.5)
	check("world time moves actual feet and the same walking adult",(rig.legs[0] as Node3D).transform!=first_foot and bird.position.distance_to(Polar.sample(12.0,2).position)>.01 and bird.get_meta("stable_id")==stable)
	await at_time(30.0)
	check("entry blends the same body from upright to horizontal",bird.rotation.z<-.8 and bird.rotation.z>-PI/2.0 and str(bird.get_meta("activity")).contains("入水"))
	record_pose("enter",bird,data)
	await capture("penguin-enter-water")
	await at_time(42.2)
	var swimming: Transform3D=bird.transform
	var flipper_a: Transform3D=(rig.flippers[0] as Node3D).transform
	var head_forward: Vector3=(rig.head as Node3D).global_basis.x.normalized()
	check("water phase is horizontal and bill faces the travel direction",absf(bird.rotation.z+PI/2.0)<.001 and head_forward.dot(bird.global_basis.y.normalized())>.98 and str(bird.get_meta("activity")).contains("划水"))
	check("swimmer is in open water at original waterline",bird.position.z<Polar._shore_z(bird.position.x)-.2 and bird.position.y>Activity.WATER_Y and bird.position.y<Activity.WATER_Y+.05 and not stage.is_underwater and stage.world_root.get_node("OpenSouthernOceanReference").visible)
	check("same swimmer and flippers fit the actual close frame",subject_visible(bird))
	record_pose("swim a",bird,data)
	await capture("penguin-swim-a")
	var paused_pose: Transform3D=bird.transform
	var paused_fin: Transform3D=(rig.flippers[0] as Node3D).transform
	for frame: int in range(5): await get_tree().process_frame
	check("pause holds body and actual flipper transform",bird.transform==paused_pose and (rig.flippers[0] as Node3D).transform==paused_fin)
	await at_time(42.2+1.0/2.8)
	check("different world phase actually reverses paired flipper stroke",(rig.flippers[0] as Node3D).transform!=flipper_a and (rig.flippers[0] as Node3D).rotation.x*(rig.flippers[1] as Node3D).rotation.x<0 and bird.transform!=swimming)
	record_pose("swim b",bird,data)
	await capture("penguin-swim-b")
	var repeated: Transform3D=bird.transform
	await at_time(42.2)
	check("explicit world-time rewind restores same body and fin pose",bird.transform.is_equal_approx(swimming) and (rig.flippers[0] as Node3D).transform.is_equal_approx(flipper_a) and not bird.transform.is_equal_approx(repeated))
	var before_live: Dictionary=main.world.checkpoint().duplicate(true)
	main.world.set_paused(false)
	for frame: int in range(5): await get_tree().process_frame
	main.world.set_paused(true)
	check("short actual clock continuation moves body and flippers",main.world.simulation_time_s>42.2 and bird.transform!=swimming and (rig.flippers[0] as Node3D).transform!=flipper_a)
	check("isolated diagnostic restores its own checkpoint after continuation",main.world.restore_checkpoint(before_live))
	await settle()
	check("same authority resolves restored phase without a second clock",main.world.get_instance_id()==authority and bird.transform.is_equal_approx(swimming) and (rig.flippers[0] as Node3D).transform.is_equal_approx(flipper_a))
	var route_valid: bool=true
	for time: float in [0.0,12.0,26.0,30.0,32.0,38.0,42.0,50.0,54.0,58.0,60.0,66.0,74.0,80.0]:
		var pose: Dictionary=Polar.sample(time,2)
		var point: Vector3=pose.position
		route_valid=route_valid and point.is_finite() and point.x>=3.599 and point.x<=8.801 and point.z>=-6.0 and point.z<=8.201
		if pose.swim==1.0: route_valid=route_valid and point.z<Polar._shore_z(point.x)-.2
		if pose.swim==0.0: route_valid=route_valid and point.z>Polar._shore_z(point.x)+.2
	check("bounded authored route respects dry shore and open water samples",route_valid)
	var p0: Dictionary=Polar.sample(0.0,2)
	var p80: Dictionary=Polar.sample(80.0,2)
	check("authored loop returns position and posture without teleport at wrap",p0.position==p80.position and absf(angle_difference(p0.heading,p80.heading))<.001 and Polar.sample(79.999,2).position.distance_to(p0.position)<.001)
	var before_overview: Dictionary=core_checkpoint()
	(panel.penguin_view_controls.get_child(2) as Button).pressed.emit()
	await settle()
	check("actual shore-water overview keeps phase and date",main._content_follow==6 and core_checkpoint()==before_overview and main.solar_jd==date and main._orbit_target.is_equal_approx(data.activity_overview.position))
	record_pose("route overview",bird,data)
	await capture("penguin-route-overview")
	(panel.penguin_view_controls.get_child(1) as Button).pressed.emit()
	await at_time(66.0)
	check("return phase rises upright and steps on the same actual coast",absf(bird.rotation.z)<.001 and str(bird.get_meta("activity")).contains("返回") and bird.position.z>Polar._shore_z(bird.position.x)+.2)
	record_pose("return",bird,data)
	await capture("penguin-return-land")
	get_window().size=Vector2i(900,650)
	await at_time(42.2)
	panel.scroll.scroll_vertical=0
	await settle()
	check("compact frame exposes all three actual view controls",panel.get_global_rect().encloses(panel.penguin_view_controls.get_global_rect()))
	check("compact swimmer remains fully observable",subject_visible(bird))
	record_pose("compact",bird,data)
	await capture("penguin-compact")
	panel.markers_toggle.toggled.emit(false)
	await settle()
	check("existing auxiliary toggle hides penguin learning markers",not main.learning_overlay.enabled)
	panel.markers_toggle.toggled.emit(true)
	await settle()
	check("same toggle restores current-body pointer",main.learning_overlay.enabled and Polar.Adelie.marks(main)[0].at==data.activity_focus.global_position)
	(panel.penguin_view_controls.get_child(0) as Button).pressed.emit()
	await settle()
	check("actual shape button returns original first adult at same time",main._content_follow==1 and main.world.simulation_time_s==42.2 and main.solar_jd==date)
	main.object_pointer.rebuild(stage)
	var pointer_entry: Dictionary=main.object_pointer.choices.get(bird.get_instance_id(),{})
	check("actual third-body mesh registry aliases the same observer",pointer_entry.get("node")==data.activity_focus and pointer_entry.get("index",-1)==5)
	(panel.penguin_view_controls.get_child(1) as Button).pressed.emit()
	await settle()
	var head_mesh: MeshInstance3D=bird.find_child("RoundHead",true,false) as MeshInstance3D
	var pixel: Vector2=stage.camera.unproject_position(head_mesh.to_global(head_mesh.get_aabb().get_center()))
	var picked: Dictionary=main.object_pointer.pick(pixel)
	check("actual triangle query hits visible swimmer and same body-center choice",not picked.is_empty() and picked.get("node")==data.activity_focus and picked.get("index",-1)==5)
	var pointer_core: Dictionary=core_checkpoint()
	main.object_pointer.activate(pixel)
	await settle()
	check("programmatic pointer activation follows same moving individual without changing world",main._content_follow==5 and main._direct_content.get("node")==data.activity_focus and main.learning_overlay.topic.is_empty() and core_checkpoint()==pointer_core and main.solar_jd==date)
	check("existing penguin lesson returns after direct model selection",panel.select_topic("adelie_penguin") and main._content_follow==1 and panel.penguin_view_controls.visible and core_checkpoint()==pointer_core)
	check("old krill topic still enters original small underwater group",panel.select_topic("ice_krill_habitat") and main._content_follow==2 and not panel.penguin_view_controls.visible)
	await settle()
	check("krill remains original twelve bodies with shared time",stage.is_underwater and stage.get_meta("ice_krill").animals.size()==12 and (stage.get_meta("ice_krill").animals[0] as Node3D).position.distance_to(Krill.sample(42.2,0).position)<.00001)
	if not await arrive("earth") or not await arrive("polar"):
		await finish(); return
	await settle()
	stage=main.coordinator.active_scene
	data=stage.get_meta("polar")
	check("return rebuilds same stable individual at same authoritative phase",main.world.get_instance_id()==authority and (data.birds[2] as Node3D).get_meta("stable_id")==stable and (data.birds[2] as Node3D).transform.is_equal_approx(swimming) and main.world.simulation_time_s==42.2)
	check("diagnostic final restoration preserves original core values",main.world.restore_checkpoint(baseline))
	main.set_solar_date(date)
	await settle()
	check("final core authority world time rates and date are preserved",core_checkpoint()==core and main.world.get_instance_id()==authority and main.world.simulation_time_s==12.0 and main.world.time_scale==2.0 and main.world.paused and main.solar_jd==date and main.solar_rate==0.0)
	main._open_guide()
	check("no species guide route or save shape is added",main.world_guide.route_buttons.size()==86 and main.world_guide.species_atlas.cards.size()==40 and main.guided_journey.checkpoint().size()==6)
	observations={"samples":pose_samples,"species_count":40,"guide_actions":86,"penguins":4,"krill":12,"floes":12,"old_target_indices_preserved":true,"original_asset_unchanged":true,"programmatic_pointer_mapping_checked":true,"world_time_s":main.world.simulation_time_s,"world_time_scale":main.world.time_scale,"date_jd":main.solar_jd,"solar_rate":main.solar_rate,"diagnostic_date_locked_for_pose_samples":true,"diagnostic_checkpoint_restored_after_short_continuation":true,"core_models_unchanged":core_checkpoint()==core,"authority_unchanged":main.world.get_instance_id()==authority,"comparison_excludes":["current_scale_id","local_habitat"],"window_screen":get_window().current_screen,"primary_screen":DisplayServer.get_primary_screen(),"screen_count":DisplayServer.get_screen_count(),"native_input_disabled":get_viewport().gui_disable_input,"fixed_reference_light_for_pose_samples":true}
	await finish()

func finish() -> void:
	var report: Dictionary={"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"wildlife_motion_calibrated":false,"hydrodynamics_or_predation_simulated":false}
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PENGUIN_ACTIVITY_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
