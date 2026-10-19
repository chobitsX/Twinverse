extends "res://tests/integration/deer_skin_suite.gd"
const School = preload("res://scripts/core/schooling.gd")
const Store = preload("res://scripts/core/world_store.gd")
const Compare = preload("res://tests/core/test_ecophysiology.gd")
var mode: String = ""
var save_directory: String = ""
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world120-check="): directory=argument.trim_prefix("--world120-check=")
		if argument.begins_with("--school-mode="): mode=argument.trim_prefix("--school-mode=")
		if argument.begins_with("--world-dir="): save_directory=argument.trim_prefix("--world-dir=")
	if not directory.is_absolute_path() or not save_directory.is_absolute_path() or mode not in ["write","resume"] or save_directory==ProjectSettings.globalize_path("user://world"):
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
	if mode=="resume":
		await resume_check()
		return
	if not await arrive("reef"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="school": action=button
	check("existing guide reaches school without inventing new species or routes",action!=null and main.world_guide.route_buttons.size()==37)
	if action!=null: action.pressed.emit()
	var panel: Node = main.explorer_panel
	panel.school_reset.pressed.emit()
	await settle()
	var fish: Array[Node3D] = school_nodes()
	check("all twenty-four existing identities read same world school state",fish.size()==24 and fish[0].get_meta("stable_id")=="3dworld:teaching:marine:2:000" and positions_match(fish))
	check("entire initial group and three annotations fit beside controls",all_visible(fish) and main.learning_overlay.last_visible_marks==3 and panel.school_controls.visible)
	check("actual representative body pixels render",await part_pixels(fish[0],fish[0].position,Vector2i(14,14))>12)
	await capture("school-initial")
	var old_direction: Vector3 = main.world.schooling.velocities[0]
	panel.school_turn.pressed.emit()
	await settle()
	check("turn control changes representative heading without teleporting",main.world.schooling.velocities[0].distance_to(old_direction)>.1 and positions_match(fish))
	await forward(2.)
	check("local model moves real bodies and produces observed neighbours",positions_match(fish) and main.world.schooling.neighbors(0).size()>0 and all_visible(fish))
	await capture("school-neighbour-turn")
	panel.school_alignment.toggled.emit(false)
	await forward(8.)
	check("alignment toggle updates authoritative rule and lesson control",not main.world.schooling.alignment and not panel.school_alignment.button_pressed and panel.lesson_readout.text.contains("最近两鱼"))
	await capture("school-alignment-off")
	var minimum: float = INF
	var clear: bool = true
	for i: int in range(10):
		await forward(.5)
		minimum=minf(minimum,main.world.schooling.metrics().minimum_distance)
		for node: Node3D in fish:
			clear=clear and node.position.y-main.coordinator.active_scene.builder._terrain_height(main.coordinator.active_scene,node.position.x,node.position.z)>.1
	check("sampled visible school clears rendered seabed and avoids centre overlap",clear and minimum>.045)
	var frozen: Dictionary = main.world.schooling.checkpoint()
	await settle()
	check("pause keeps positions and velocities unchanged",main.world.schooling.checkpoint()==frozen and positions_match(fish))
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("normal host time advances visible local rules",main.world.schooling.steps>frozen.steps and not Compare.equivalent(main.world.schooling.checkpoint().positions,frozen.positions))
	panel.school_alignment.toggled.emit(true)
	await forward(4.)
	frozen=main.world.schooling.checkpoint()
	if not await arrive("earth") or not await arrive("reef"):
		await finish()
		return
	fish=school_nodes()
	check("scene return reconstructs same individual state",main.world.schooling.checkpoint()==frozen and positions_match(fish))
	panel.show()
	await settle()
	panel.select_topic("school")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact school retains all fish markers and reachable controls",all_visible(fish) and main.learning_overlay.last_visible_marks==3 and panel.school_controls.get_global_rect().end.y<panel.get_global_rect().end.y-12)
	await capture("school-compact")
	check("lesson labels local rules and authored perception limits",panel.lesson_text.text.contains("300°") and panel.lesson_text.text.contains("非该物种实测"))
	main.save_button.pressed.emit()
	var loaded: Dictionary = Store.new(save_directory).load_session()
	check("production save contains v11 individual positions velocities and switch",loaded.status=="ok" and loaded.payload.world.version==11 and Compare.equivalent(loaded.payload.world.schooling,main.world.schooling.checkpoint()))
	FileAccess.open(save_directory.path_join("school-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"world":main.world.checkpoint()},"\t",true,true))
	await finish()

func school_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for actor: Dictionary in main.coordinator.active_scene.get_meta("marine_actors"):
		if actor.kind==2: result.append(actor.node)
	return result
func all_visible(fish: Array[Node3D]) -> bool:
	for node: Node3D in fish:
		if not subject_visible(node): return false
	return true
func positions_match(fish: Array[Node3D]) -> bool:
	for i: int in range(fish.size()):
		if fish[i].position.distance_to(main.world.schooling.positions[i])>.00001: return false
		var direction: Vector3 = main.world.schooling.velocities[i].normalized()
		if direction.length()>.01 and fish[i].basis.x.normalized().dot(direction)<.999: return false
	return true
func forward(seconds: float) -> void:
	main.world.simulation_time_s+=seconds
	main.world.snapshot()
	await settle()
func resume_check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_directory.path_join("school-expected.json")))
	var actual: Dictionary = main.world.checkpoint()
	var same: bool = main.world.current_scale_id=="reef"
	for key: String in expected.world:
		if key!="local_habitat": same=same and Compare.equivalent(actual[key],expected.world[key])
	check("new process restores all scientific models and paused trajectories",same)
	var habitat: Dictionary = actual.local_habitat.duplicate(true)
	var continuation: Dictionary = habitat.events.pop_back()
	check("new process adds only expected continuation history",continuation.kind=="continued" and Compare.equivalent(habitat,expected.world.local_habitat))
	main.explorer_panel.show()
	await settle()
	check("restored scene exposes school lesson",main.explorer_panel.select_topic("school"))
	await settle()
	check("saved trajectories appear in actual scene",positions_match(school_nodes()) and main.explorer_panel.school_alignment.button_pressed==main.world.schooling.alignment)
	var reference: School = School.new()
	reference.restore(expected.world.schooling)
	reference.advance_to(main.world.simulation_time_s+1.)
	await forward(1.)
	check("resumed next second matches uninterrupted rules",Compare.equivalent(main.world.schooling.checkpoint(),reference.checkpoint()))
	await capture("school-resumed")
	await finish()
