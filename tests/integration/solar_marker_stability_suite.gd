extends "res://tests/integration/solar_closeup_suite.gd"
## Reproduce marker churn while paused and playing; verify only UI is stabilized.
var visibility_events: int = 0

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--markers282-output="): directory=argument.trim_prefix("--markers282-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(65.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80.0
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	main.set_solar_date(2461372.541666667) # 2026-11-28 01:00 TDB, reported view.
	prepare_auto(); main.follow_planet(2,true); await settle()
	if not await interaction_ready(): await finish(); return
	var compass: Control=main.hud.get_node("SolarContextCompass")
	var stage: Node=main.coordinator.active_scene
	var identity: int=main.world.get_instance_id()
	for button: Button in compass.buttons.values():
		button.visibility_changed.connect(func() -> void: visibility_events+=1)
	visibility_events=0
	var before: Dictionary=positions(compass)
	var date: float=main.solar_jd
	for frame: int in range(8): await get_tree().process_frame
	check("paused markers never hide and reappear each frame",visibility_events==0)
	check("paused marker positions settle without continuous drift",largest_motion(before,positions(compass))<1.0)
	measurements.append({"kind":"paused markers","visibility_events":visibility_events,"max_shift_px":largest_motion(before,positions(compass))})
	var initial: Array[Transform3D]=[]
	for item: Dictionary in stage.get_meta("solar_bodies"): initial.append(item.node.transform)
	for frame: int in range(6): compass._process(1.0/30.0)
	var unchanged: bool=main.solar_jd==date
	for index: int in range(8): unchanged=unchanged and initial[index].is_equal_approx(stage.get_meta("solar_bodies")[index].node.transform)
	check("marker updates leave all body transforms and date unchanged",unchanged)
	if "--markers282-baseline" in OS.get_cmdline_user_args(): await finish(); return
	# A subpixel change at a crowded label boundary must not cause a 42px flip.
	if compass.has_method("place_marker"):
		var fixture: Control=main.SolarContextCompass.new(); fixture.configure(main); add_child(fixture)
		var area: Rect2=Rect2(20,20,500,300)
		var occupied: Array[Rect2]=[Rect2(182,142,36,36)]
		var previous: Vector2
		var largest_step: float=0.0
		for index: int in range(20):
			var point: Vector2=Vector2(239.0+(.12 if index%2 else -.12),160)
			fixture.place_marker(4,point,area,occupied.duplicate(),1.0/30.0)
			var now: Vector2=fixture.buttons[4].position
			if index>0: largest_step=maxf(largest_step,now.distance_to(previous))
			previous=now
		check("crowded subpixel boundary cannot alternate large placement slots",largest_step<2.0)
		measurements.append({"kind":"crowded marker boundary","max_step_logical_px":largest_step})
		fixture.marker_states.clear()
		largest_step=0.0
		for index: int in range(20):
			var empty_slots: Array[Rect2]=[]
			fixture.place_marker(4,Vector2(area.end.x+(.00003 if index%2 else -.00003),160),area,empty_slots,1.0/30.0)
			var now: Vector2=fixture.buttons[4].position
			if index>0: largest_step=maxf(largest_step,now.distance_to(previous))
			previous=now
		check("screen-edge rounding never forces a different placement slot",largest_step<1.0)
		fixture.queue_free()
	else: check("marker layout has a stable placement path",false)
	# Real live World playback on the three close views the user requested.
	for owner: int in [2,4,5]:
		main.follow_planet(owner,true); await settle()
		for frame: int in range(4): await get_tree().process_frame
		visibility_events=0; before=positions(compass)
		var world_time: float=main.world.simulation_time_s
		var start_jd: float=main.solar_jd
		var max_step: float=0.0
		var max_far_step: float=0.0
		var previous_steps: Dictionary={}
		var reversals: Dictionary={}
		var trace: Array[Dictionary]=[]
		main.world.set_paused(false)
		for frame: int in range(12):
			await get_tree().process_frame
			var now: Dictionary=positions(compass)
			var row: Dictionary={}
			for key: int in before:
				if not now.has(key): continue
				var step: Vector2=Vector2(now[key])-Vector2(before[key])
				if key<10: max_far_step=maxf(max_far_step,step.length())
				var prior: Vector2=previous_steps.get(key,Vector2.ZERO)
				if step.length()>2.0 and prior.length()>2.0 and step.normalized().dot(prior.normalized())<-.25:
					reversals[key]=int(reversals.get(key,0))+1
				previous_steps[key]=step
				row[key]=str(now[key])
			trace.append(row)
			max_step=maxf(max_step,largest_motion(before,now)); before=now
		main.world.set_paused(true)
		check(str(owner)+" live markers stay present without flicker",visibility_events==0)
		check(str(owner)+" distant planetary bearings have no abrupt jumps",max_far_step<8.0)
		# Nearby moons can move tens of pixels at 1 hour/s. Preserve that real
		# travel; reject repeated direction flips, not their physical speed.
		var max_reversals: int=0
		for count_value: int in reversals.values(): max_reversals=maxi(max_reversals,count_value)
		check(str(owner)+" moving satellites do not ping-pong between label positions",max_reversals<=1)
		check(str(owner)+" real motion keeps the shared one-hour clock",main.world.simulation_time_s>world_time and absf(main.solar_jd-start_jd-(main.world.simulation_time_s-world_time)/24.0)<.000001)
		measurements.append({"kind":"live markers","owner":owner,"visibility_events":visibility_events,"max_step_logical_px":max_step,"max_far_planet_step_logical_px":max_far_step,"direction_reversals":reversals,"trace":trace,"world_seconds":main.world.simulation_time_s-world_time,"date_days":main.solar_jd-start_jd})
		await capture("stable-markers-"+str(owner))
	main.follow_planet(2,true); await settle()
	var button: Button=compass.buttons[9]
	check("Moon bearing remains available",button.visible)
	button.mouse_entered.emit(); await get_tree().process_frame
	var held: Vector2=button.position
	main.world.set_paused(false)
	for frame: int in range(5): await get_tree().process_frame
	main.world.set_paused(true)
	check("hovered marker stays under the pointer while the Moon moves",button.position.distance_to(held)<.01)
	check("hover keeps the same optical target available",main.optical_inspector.visible and main.optical_inspector.choice.get("node")==stage.get_meta("solar_moon").node)
	await capture("stable-moon-optics")
	button.mouse_exited.emit(); button.pressed.emit(); await settle()
	check("stable marker still selects the actual Moon",main._content_follow==1 and Closeup.subject(main)==stage.get_meta("solar_moon").node)
	main.follow_planet(5,true); await settle()
	var old: Dictionary=positions(compass)
	left_drag(Vector2(90,-35)); await settle()
	for frame: int in range(4): await get_tree().process_frame
	check("camera orbit updates bearings instead of freezing them",largest_motion(old,positions(compass))>5.0)
	check("drag leaves a substantial selected Saturn",screen_disc(stage,Closeup.subject(main)).z/float(stage.viewport.size.y)>.18)
	main._reset_camera(); await settle()
	check("overview has no leftover near markers or optical card",not compass.visible and not main.optical_inspector.visible)
	check("one World, no-save and original resource budget",main.world.get_instance_id()==identity and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func positions(compass: Control) -> Dictionary:
	var result: Dictionary={}
	for key: int in compass.buttons:
		if compass.buttons[key].visible: result[key]=compass.buttons[key].position
	return result

func largest_motion(before: Dictionary, after: Dictionary) -> float:
	var largest: float=0.0
	for key: int in before:
		if after.has(key): largest=maxf(largest,Vector2(before[key]).distance_to(after[key]))
	return largest
