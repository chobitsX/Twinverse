extends "res://tests/integration/land_lighting_suite.gd"
## One short real-window input check for pan, tracking, and standard views.

func mouse_button(point: Vector2, index: int, down: bool, shifted: bool=false) -> void:
	var event: InputEventMouseButton=InputEventMouseButton.new()
	event.position=point; event.global_position=point
	event.button_index=index; event.pressed=down; event.shift_pressed=shifted
	get_viewport().push_input(event,true)
	await get_tree().process_frame

func drag(point: Vector2, delta: Vector2, index: int, shifted: bool=false) -> void:
	await mouse_button(point,index,true,shifted)
	var event: InputEventMouseMotion=InputEventMouseMotion.new()
	event.position=point+delta; event.global_position=point+delta
	event.relative=delta; event.button_mask=1 << (index-1); event.shift_pressed=shifted
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	await mouse_button(point+delta,index,false,shifted)
	await settle()

func reset_key() -> void:
	var event: InputEventKey=InputEventKey.new()
	event.keycode=KEY_R; event.pressed=true
	get_viewport().push_input(event,true)
	await settle()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world152-check="): directory=argument.trim_prefix("--world152-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(150.).timeout.connect(func() -> void:
		push_error("Camera navigation diagnostic exceeded its bounded runtime")
		get_tree().quit(2))
	main=Experience.instantiate(); add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true; get_window().size=Vector2i(1280,800)
	if not await ready_stage(): await finish(); return
	main._reduced_motion=true; main.world.set_paused(true); main.set_solar_rate(0.)
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	if main.world.current_scale_id!="solar_system" and not await arrive("solar_system"):
		await finish(); return
	main.set_solar_rate(0.); main.follow_planet(2); await settle()
	var stage: Node=main.coordinator.active_scene
	var earth: Node3D=stage.get_meta("solar_bodies")[2].node
	var before: Vector2=stage.camera.unproject_position(earth.global_position)
	var basis: Basis=stage.camera.basis
	var time_before: float=main.world.simulation_time_s
	var authority: RefCounted=main.world
	await drag(Vector2(920,450),Vector2(58,-27),MOUSE_BUTTON_LEFT,true)
	var after: Vector2=stage.camera.unproject_position(earth.global_position)
	check("Shift+left pans the actual solar camera without rotating or selecting elsewhere",(after-before-Vector2(58,-27)).length()<3. and stage.camera.basis.is_equal_approx(basis) and main.solar_follow==2 and main._pan_offset.length()>.001)
	check("pan leaves shared world time and authority untouched",main.world==authority and main.world.simulation_time_s==time_before)
	var orbit_offset: Vector3=stage.camera.position-main._orbit_target
	var pan: Vector3=main._pan_offset
	main.set_solar_date(main.solar_jd+12.); await settle()
	check("moving planet retains temporary pan and viewing distance",main._orbit_target.is_equal_approx(Ephemeris.display_position(2,main.solar_jd,main.solar_true_distance)+pan) and (stage.camera.position-main._orbit_target).is_equal_approx(orbit_offset))
	await reset_key()
	check("R returns to selected planet's standard view",main.solar_follow==2 and main._pan_offset.is_zero_approx() and absf(stage.camera.position.distance_to(main._orbit_target)-1.7)<.02)
	await capture("solar-selected-standard")
	var target: Vector3=main._orbit_target
	basis=stage.camera.basis
	await drag(Vector2(910,440),Vector2(22,10),MOUSE_BUTTON_RIGHT)
	check("right drag still orbits the selected target",main._orbit_target.is_equal_approx(target) and not stage.camera.basis.is_equal_approx(basis))
	if not await arrive("city"):
		await finish(); return
	main.explorer_panel.show(); main.info_panel.hide(); await settle()
	stage=main.coordinator.active_scene
	var people: Array[Node3D]=[]
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind=="person": people.append(actor.node)
	var person_index: int=-1
	var person_path: String=""
	var targets: Array[Dictionary]=main.content_targets(false)
	for i: int in range(targets.size()):
		if str(targets[i].label).contains("行人"): person_index=i; break
	check("city has an actual person for camera observation",people.size()>1 and person_index>=0)
	if people.size()>1 and person_index>=0:
		var direct: Dictionary=targets[person_index].duplicate()
		direct.node=people[1]
		main.follow_content(person_index+1,direct); await settle()
		var person: Node3D=people[1]
		person_path=str(person.get_path())
		before=stage.camera.unproject_position(person.global_position+Vector3(0,.95,0))
		basis=stage.camera.basis
		await drag(Vector2(920,460),Vector2(-42,24),MOUSE_BUTTON_MIDDLE)
		after=stage.camera.unproject_position(person.global_position+Vector3(0,.95,0))
		check("middle drag pans while following the same individual",(after-before-Vector2(-42,24)).length()<4. and stage.camera.basis.is_equal_approx(basis) and main.content_targets()[main._content_follow].node==person)
		var standard: Button
		for node: Node in main.explorer_panel.find_children("*","Button",true,false):
			if node.text=="对象标准视角": standard=node; break
		check("object standard-view action is present",standard!=null)
		if standard!=null: standard.pressed.emit()
		await settle()
		check("object action returns to the same person",main._pan_offset.is_zero_approx() and main._content_follow==person_index and main.content_targets()[main._content_follow].node==person)
		await capture("city-person-standard")
	if not await arrive("earth_moon"):
		await finish(); return
	main.explorer_panel.show(); await settle()
	check("lunar lesson remains reachable",main.explorer_panel.select_topic("lunar_phases"))
	main.focus_lunar(true); await settle()
	stage=main.coordinator.active_scene
	var moon: Node3D=stage.get_meta("lunar").moon
	before=stage.camera.unproject_position(moon.global_position)
	await drag(Vector2(900,440),Vector2(31,-18),MOUSE_BUTTON_MIDDLE)
	after=stage.camera.unproject_position(moon.global_position)
	check("orthographic lunar view can pan without leaving the lesson",(after-before-Vector2(31,-18)).length()<3. and stage.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and main.lunar_observation_view=="earth")
	await reset_key()
	check("R restores the Earth-facing lunar view",main._pan_offset.is_zero_approx() and main.learning_overlay.topic=="lunar_phases" and main.lunar_observation_view=="earth" and stage.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
	comparisons.navigation={"solar_pan_px":Vector2(58,-27),"city_person":person_path,"lunar_projection":stage.camera.projection,"world_time_s":main.world.simulation_time_s}
	await capture("lunar-standard")
	await finish()
