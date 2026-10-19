extends "res://tests/integration/land_lighting_suite.gd"
const Explorer = preload("res://scripts/experience/explorer_panel.gd")

## Actual Metal view: one topic must make the person-bird relation observable.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world171-review="): directory=argument.trim_prefix("--world171-review=")
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
	get_window().size=Vector2i(1280,800)
	if not await arrive("city"):
		await finish()
		return
	await at_time(6.)
	await settle()
	var stage: Node=main.coordinator.active_scene
	var birds: Array=stage.get_meta("city_sparrows",[])
	var actors: Array=stage.get_meta("actors",[])
	check("same city keeps four birds and 28 people plus 12 cars",birds.size()==4 and actors.size()==40)
	if birds.size()!=4 or actors.size()!=40:
		await finish()
		return
	var bird: Node3D=birds[0]
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("bird topic retains the actual selected animal",panel.select_topic("city_sparrow") and main._content_follow==7)
	await settle()
	var context_button: Button=panel.city_bird_controls.get_child(0)
	var close_button: Button=panel.city_bird_controls.get_child(1)
	check("two camera actions are visible near the live readout",context_button.is_visible_in_tree() and close_button.is_visible_in_tree() and context_button.get_global_rect().end.y<panel.get_global_rect().end.y)
	check("close view retains the real alert state",float(bird.get_meta("pedestrian_alert",0.))>.75 and subject_visible(bird))
	await capture("bird-alert-close")
	context_button.pressed.emit()
	await settle()
	check("context action retains bird target and paused world time",panel.city_bird_context_view and main._content_follow==7 and main.world.paused and main.world.simulation_time_s==6.)
	check("context camera uses the authored park relationship view",stage.camera.position.distance_to(Explorer.CITY_BIRD_CONTEXT_POSITION)<.002 and main._orbit_target.distance_to(Explorer.CITY_BIRD_CONTEXT_TARGET)<.002)
	var nearest: Dictionary=actual_nearest(bird,actors)
	check("readout and relationship marker use the rendered bird-to-walker distance",absf(float(bird.get_meta("nearest_pedestrian_m",0.))-float(nearest.distance))<.001 and bird.get_meta("nearest_pedestrian_at",Vector3.ZERO).distance_to(nearest.position)<.001 and panel.lesson_readout.text.contains("%.2f" % float(nearest.distance)))
	var person: Node3D=nearest.node
	var head: Vector3=person.global_position+Vector3(0,1.7,0)
	var foot: Vector3=person.global_position
	var bird_pixel: Vector2=stage.camera.unproject_position(bird.global_position+Vector3(0,.1,0))
	var head_pixel: Vector2=stage.camera.unproject_position(head)
	var foot_pixel: Vector2=stage.camera.unproject_position(foot)
	var side: float=panel.get_global_rect().end.x
	comparisons["context_pixels"]={"panel_right":side,"bird":[bird_pixel.x,bird_pixel.y],"person_head":[head_pixel.x,head_pixel.y],"person_foot":[foot_pixel.x,foot_pixel.y]}
	check("person and true-size bird appear to the right of the lesson panel",not stage.camera.is_position_behind(head) and not stage.camera.is_position_behind(bird.global_position) and bird_pixel.x>side+30. and bird_pixel.x<1240. and head_pixel.x>side+30. and head_pixel.x<1240. and head_pixel.y>100. and foot_pixel.y<750.)
	await capture("bird-and-person-context")
	await at_time(10.)
	await settle()
	nearest=actual_nearest(bird,actors)
	check("changing time updates the context without a second world clock",panel.city_bird_context_view and main.world.simulation_time_s==10. and float(bird.get_meta("pedestrian_alert",1.))<.02 and absf(float(bird.get_meta("nearest_pedestrian_m",0.))-float(nearest.distance))<.001)
	await capture("bird-and-person-quiet")
	close_button.pressed.emit()
	await settle()
	check("close action returns to the same bird and time",not panel.city_bird_context_view and main._content_follow==7 and main.world.simulation_time_s==10. and subject_visible(bird))
	await capture("bird-close-return")
	await finish()

func actual_nearest(bird: Node3D, actors: Array) -> Dictionary:
	var closest: float=INF
	var nearest_node: Node3D
	var at: Vector3=Vector3.ZERO
	for index: int in range(26):
		var node: Node3D=actors[index].node
		var distance: float=Vector2(bird.position.x-node.position.x,bird.position.z-node.position.z).length()
		if distance<closest:
			closest=distance
			nearest_node=node
			at=node.position
	return {"distance":closest,"position":at,"node":nearest_node}
