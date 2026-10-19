extends "res://tests/integration/ecology_map_suite.gd"
const Algae = preload("res://scripts/core/algal_grazing.gd")
const Store = preload("res://scripts/core/world_store.gd")
const Compare = preload("res://tests/core/test_ecophysiology.gd")
var mode: String=""
var save_directory: String=""
var contact_samples: Array[Dictionary]=[]
var recovery_events: Array[Dictionary]=[]

func ready_scale(id: String) -> bool:
	var deadline: int=Time.get_ticks_msec()+90000
	var retried: bool=false
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if native: RenderingServer.force_draw(false,0.0)
		if main.coordinator==null or main.coordinator.active_scene==null: continue
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.current_scale_id==id and main.world.foreground: return true
		var recovery: Dictionary=main.coordinator.recovery_state()
		if not retried and recovery.get("target","")==id and bool(recovery.get("ready",false)) and main.world.foreground:
			recovery_events.append(recovery)
			check("failed transition keeps source and exposes usable retry",main.world.current_scale_id!=id and main.coordinator.active_scene.is_prepared() and not main.retry_button.disabled)
			print("ALGAE_RETRY ",JSON.stringify(recovery))
			main.retry_button.pressed.emit()
			retried=true
	print("ALGAE_READY_TIMEOUT ",id," actual=",main.world.current_scale_id," phase=",main.coordinator.phase)
	check("ready "+id,false)
	return false

func frames() -> void:
	for frame: int in range(6):
		await get_tree().process_frame
		if native: RenderingServer.force_draw(false,0.0)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world138-check="): directory=argument.trim_prefix("--world138-check=")
		if argument.begins_with("--algae-mode="): mode=argument.trim_prefix("--algae-mode=")
		if argument.begins_with("--world-dir="): save_directory=argument.trim_prefix("--world-dir=")
	if not directory.is_absolute_path() or not save_directory.is_absolute_path() or mode not in ["write","resume"] or save_directory==ProjectSettings.globalize_path("user://world"):
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,800)
	if native: root.unfocusable=true
	main=Experience.instantiate(); root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("reef"): finish_algae(); return
	main._reduced_motion=true; main.world.set_paused(true); main.world_guide.hide()
	if mode=="resume": await resume_check(); return
	main._open_guide()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="algae": action=button
	check("existing algae route still uses the same 41-topic guide",action!=null and main.world_guide.route_buttons.size()==41)
	if action==null: finish_algae(); return
	action.pressed.emit()
	await frames()
	var panel: Node=main.explorer_panel
	panel.algae_reset.pressed.emit()
	await frames()
	check("guide opens real algae controls and representative labels",panel.visible and panel.algae_controls.visible and main.learning_overlay.topic=="algae" and main.learning_overlay.last_visible_marks==2)
	check("six existing fish and six actual materials share world state",fish_nodes().size()==6 and visuals_match())
	await capture("algae-initial")
	var frozen: Dictionary=main.world.algal_grazing.checkpoint()
	var poses: Array[Transform3D]=[]
	for node: Node3D in fish_nodes(): poses.append(node.transform)
	await frames()
	var pose_frozen: bool=true
	var paused_fish: Array[Node3D]=fish_nodes()
	for i: int in range(6): pose_frozen=pose_frozen and paused_fish[i].transform.is_equal_approx(poses[i])
	check("paused scene freezes resource state and body pose",main.world.algal_grazing.checkpoint()==frozen and pose_frozen and visuals_match())
	await forward(18.)
	var fish: Array[Node3D]=fish_nodes()
	var patches: Array=main.coordinator.active_scene.get_meta("feeding_patches")
	var contact_count: int=0
	var contact_ok: bool=true
	for node: Node3D in fish:
		if float(node.get_meta("grazing_approach"))<.9999: continue
		contact_count+=1
		var patch: int=int(node.get_meta("grazing_target"))
		var mouth: Vector3=node.transform*Vector3(.468,-.075,0)
		var relative: Vector3=mouth-(patches[patch]-Vector3(0,.06,0))
		var ellipse: float=pow(relative.x/.125,2)+pow(relative.y/.06,2)+pow(relative.z/.105,2)
		contact_ok=contact_ok and ellipse>.95 and ellipse<1.08 and relative.y>0
		contact_samples.append({"fish":node.get_meta("stable_id"),"patch":patch,"ellipsoid_equation":ellipse,"mouth":[mouth.x,mouth.y,mouth.z]})
	check("actual transformed mouths meet upper rock surface while consuming",contact_count>=2 and contact_ok and main.world.algal_grazing.eaten[0]>0.)
	check("consumption changes rendered stock and resource readout",main.world.algal_grazing.stock[0]<Algae.INITIAL[0] and visuals_match() and panel.lesson_readout.text.contains("累计摄食") and panel.lesson_text.text.contains("未按褐吊标定"))
	check("six patch centres fit beside lesson panel",patches_visible())
	await capture("algae-grazing")
	await forward(77.)
	check("resource-driven next visit changes actual fish targets",main.world.algal_grazing.targets!=[0,1,2,3,4,5] and visuals_match())
	await capture("algae-next-visit")
	panel.algae_adaptive.toggled.emit(false)
	await forward(32.)
	check("choice toggle returns all next visits to original patches",main.world.algal_grazing.targets==[0,1,2,3,4,5] and not panel.algae_adaptive.button_pressed and visuals_match())
	frozen=main.world.algal_grazing.checkpoint()
	panel.algae_enabled.toggled.emit(false)
	await forward(12.)
	check("grazing-off control freezes removals and allows all patches to recover",main.world.algal_grazing.eaten==frozen.eaten and all_greater(main.world.algal_grazing.stock,frozen.stock) and not panel.algae_enabled.button_pressed and visuals_match())
	check("disabled fish visibly disengage from patches",fish_nodes().all(func(n: Node3D) -> bool: return float(n.get_meta("grazing_approach"))<.001))
	await capture("algae-recovery")
	var authority: RefCounted=main.world
	if not await visit("earth"): finish_algae(); return
	await forward(3.)
	frozen=main.world.algal_grazing.checkpoint()
	if not await visit("reef","algae"): finish_algae(); return
	check("off-scene recovery and rebuilt rocks preserve same world state",main.world==authority and main.world.algal_grazing.checkpoint()==frozen and visuals_match())
	root.size=Vector2i(900,650)
	await frames()
	panel.scroll.ensure_control_visible(panel.algae_reset)
	await frames()
	var clip: Rect2=panel.scroll.get_global_rect()
	check("compact panel can scroll to all three model controls",clip.encloses(panel.algae_enabled.get_global_rect()) and clip.encloses(panel.algae_adaptive.get_global_rect()) and clip.encloses(panel.algae_reset.get_global_rect()))
	await capture("algae-compact-controls")
	panel.algae_enabled.toggled.emit(true); panel.algae_adaptive.toggled.emit(true)
	await forward(2.)
	main.save_button.pressed.emit()
	var loaded: Dictionary=Store.new(save_directory).load_session()
	check("production save writes v12 resource state and choices",loaded.status=="ok" and loaded.payload.world.version==12 and Compare.equivalent(loaded.payload.world.algal_grazing,main.world.algal_grazing.checkpoint()))
	FileAccess.open(save_directory.path_join("algae-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"world":main.world.checkpoint()},"\t",true,true))
	finish_algae()

func patches_visible() -> bool:
	var stage: Node=main.coordinator.active_scene
	var size: Vector2=root.get_visible_rect().size
	var left: float=main.explorer_panel.get_global_rect().end.x+20.
	for point: Vector3 in stage.get_meta("feeding_patches"):
		var screen: Vector2=stage.camera.unproject_position(point)
		if stage.camera.is_position_behind(point) or screen.x<left or screen.x>size.x-24. or screen.y<120. or screen.y>size.y-130.: return false
	return true

func fish_nodes() -> Array[Node3D]:
	var result: Array[Node3D]=[]
	for actor: Dictionary in main.coordinator.active_scene.get_meta("marine_actors"):
		if actor.kind==0: result.append(actor.node)
	return result
func visuals_match() -> bool:
	var data: Dictionary=main.world.algal_grazing.checkpoint()
	var stage: Node=main.coordinator.active_scene
	var materials: Array=stage.get_meta("algal_materials")
	var fish: Array[Node3D]=fish_nodes()
	if materials.size()!=6 or fish.size()!=6: return false
	for i: int in range(6):
		if absf(float(materials[i].get_shader_parameter("stock_fraction"))-data.stock[i]/100.)>.00001: return false
		if int(fish[i].get_meta("grazing_target"))!=int(data.targets[i]): return false
	return true
func all_greater(current: Array, previous: Array) -> bool:
	for i: int in range(current.size()):
		if current[i]<=previous[i]: return false
	return true
func forward(seconds: float) -> void:
	main.world.simulation_time_s+=seconds
	main.world.snapshot()
	await frames()
func visit(id: String, topic: String="") -> bool:
	if not await ready_scale(main.world.current_scale_id): return false
	main.start_guide_visit(id,topic)
	if not await ready_scale(id): return false
	await frames()
	return true
func resume_check() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(save_directory.path_join("algae-expected.json")))
	var actual: Dictionary=main.world.checkpoint()
	var same: bool=main.world.current_scale_id=="reef"
	for key: String in expected.world:
		if key!="local_habitat": same=same and Compare.equivalent(actual[key],expected.world[key])
	check("new process restores all models with paused resource history",same)
	var habitat: Dictionary=actual.local_habitat.duplicate(true)
	var continuation: Dictionary=habitat.events.pop_back()
	check("restore adds only normal continuation observation",continuation.kind=="continued" and Compare.equivalent(habitat,expected.world.local_habitat))
	main.explorer_panel.show(); await frames()
	check("restored algae topic is selectable",main.explorer_panel.select_topic("algae"))
	await frames()
	check("restored resources drive actual rock materials and choices",visuals_match() and main.explorer_panel.algae_enabled.button_pressed and main.explorer_panel.algae_adaptive.button_pressed)
	var reference: Algae=Algae.new(); reference.restore(expected.world.algal_grazing)
	reference.advance_to(main.world.simulation_time_s+1.)
	await forward(1.)
	check("resumed next second equals uninterrupted resource simulation",Compare.equivalent(reference.checkpoint(),main.world.algal_grazing.checkpoint()) and visuals_match())
	await capture("algae-resumed")
	finish_algae()
func finish_algae() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"contacts":contact_samples,"recovery_events":recovery_events,"native":native,"debug_build":OS.is_debug_build(),"mode":mode,"performance_test":false},"\t")+"\n")
	print("ALGAL_GRAZING_FINISHED ",mode," ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
