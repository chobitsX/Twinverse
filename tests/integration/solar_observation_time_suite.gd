extends "res://tests/integration/solar_visual_suite.gd"
## Short actual-engine exercise of automatic playback and explicit ownership.
var earth_transition_samples: Array[Dictionary] = []
var earth_transition_rate: float = 0.0
var earth_transition_jd: float = 0.0
var earth_transition_time: float = 0.0

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solar266-output="): directory=argument.trim_prefix("--solar266-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(75).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide()
	if "--earth272-only" in OS.get_cmdline_user_args():
		await earth_transition_checks()
		await finish(); return
	var world_id: int=main.world.get_instance_id()
	var ui: Node=main.immersive_interface
	var stage: Node=main.coordinator.active_scene
	var initial_rate: float=main.solar_rate
	prepare_auto()
	var initial_jd: float=main.solar_jd
	var hover: InputEventMouseMotion=InputEventMouseMotion.new()
	hover.position=stage.camera.unproject_position(stage.get_meta("solar_bodies")[4].node.position)
	main.object_pointer.pointer(hover); main.object_pointer._process(.2)
	check("hover does not change the shared rate or date",initial_rate==10.0 and main.solar_rate==10.0 and main.solar_jd==initial_jd and main._solar_close_playback.is_empty() and ui.rate_button.text=="10天/秒" and ui.rate_button.get_popup().is_item_checked(ui.ASTRONOMY_RATES.find(10.0)))
	for index: int in range(8):
		main.follow_planet(index)
		check("planet close keeps one hour rate and original return for "+str(index),is_equal_approx(main.solar_rate,1.0/24.0) and main._solar_close_playback.rate==10.0 and main._solar_close_playback.target==index and main.solar_jd==initial_jd and main.world.paused)
	main.follow_content(1)
	check("Sun close uses the same global slow rate",is_equal_approx(main.solar_rate,1.0/24.0) and main._solar_close_playback.target==8 and main._solar_close_playback.rate==10.0)
	main.follow_content(2)
	check("Moon close preserves the first return rate",is_equal_approx(main.solar_rate,1.0/24.0) and main._solar_close_playback.target==9 and main._solar_close_playback.rate==10.0)
	main.follow_planet(-1)
	check("return overview restores ten days without resuming pause or rewinding",main.solar_rate==10.0 and main.solar_jd==initial_jd and main._solar_close_playback.is_empty() and main.world.paused and main.solar_demo_auto)
	main.follow_planet(4)
	await settle()
	check("existing card identifies near slow motion",ui.context_note.text.contains("近景慢放") and ui.rate_button.text=="1小时/秒" and ui.rate_button.get_popup().is_item_checked(ui.rate_button.get_popup().get_item_index(100)))
	if not await drawable_window(): await finish(); return
	main._toggle_pause()
	var start_time: float=main.world.simulation_time_s
	var start_jd: float=main.solar_jd
	await advance_for(.8)
	main._toggle_pause(); await settle()
	var elapsed: float=main.world.simulation_time_s-start_time
	check("actual playback advances the one shared date at near rate",elapsed>0.0 and absf(main.solar_jd-start_jd-elapsed/24.0)<.000001)
	check("all ten scientific bodies agree with that moving date",same_date())
	measurements.append({"kind":"actual near playback","rate":main.solar_rate,"elapsed_world_s":elapsed,"start_jd":start_jd,"jd":main.solar_jd,"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw()})
	await capture("jupiter-near-slow")
	var paused_jd: float=main.solar_jd
	var camera: Transform3D=stage.camera.transform
	main._zoom_camera(stage,1.05); main._pan_camera(stage,Vector2(10,-3))
	await settle()
	check("paused detail allows camera input while date stays frozen",main.world.paused and main.solar_jd==paused_jd and not stage.camera.transform.is_equal_approx(camera))
	await saved_close()
	main._reset_camera(); await settle()
	check("saved close can return to the original global rate",main.solar_rate==10.0 and main.world.paused and main.solar_jd==paused_jd)
	if not await drawable_window(): await finish(); return
	main._toggle_pause(); start_time=main.world.simulation_time_s; start_jd=main.solar_jd
	await advance_for(.6)
	main._toggle_pause(); await settle()
	elapsed=main.world.simulation_time_s-start_time
	check("returned overview advances continuously at original rate",elapsed>0.0 and absf(main.solar_jd-start_jd-elapsed*10.0)<.00001 and same_date())
	measurements.append({"kind":"actual return playback","rate":main.solar_rate,"elapsed_world_s":elapsed,"start_jd":start_jd,"jd":main.solar_jd})
	await capture("overview-restored-rate")
	prepare_auto(100.0); main.follow_planet(5); main.focus_planet_orbit(5)
	check("orbit overview restores the entered rate rather than the default",main.solar_rate==100.0 and main._solar_close_playback.is_empty())
	prepare_auto(); main.follow_planet(5); main.focus_solar_plane(true)
	check("side view also leaves temporary slow playback",main.solar_rate==10.0 and main._solar_close_playback.is_empty())
	prepare_auto(); main.follow_planet(0); main.focus_kepler()
	check("orbit lesson leaves temporary slow playback",main.solar_rate==10.0 and main._solar_close_playback.is_empty())
	prepare_auto(); main.follow_planet(5)
	ui._set_rate(2); main.follow_planet(4); main._reset_camera()
	check("manual one day menu rate survives switching and returning",main.solar_rate==1.0 and main.solar_manual_setting and main._solar_close_playback.is_empty())
	main.follow_content(1); await settle()
	check("one day is selectable for slow Sun rotation",main.solar_rate==1.0 and ui.rate_button.text=="1天/秒" and not ui.rate_button.get_popup().is_item_checked(ui.rate_button.get_popup().get_item_index(100)))
	await capture("sun-manual-one-day")
	ui._set_rate(100)
	check("menu can explicitly reenable automatic near playback",is_equal_approx(main.solar_rate,1.0/24.0) and main._solar_close_playback.rate==1.0 and not main.solar_manual_setting)
	main.set_solar_observation_auto(true)
	check("reenabling automatic playback is idempotent",main._solar_close_playback.rate==1.0)
	main._reset_camera()
	check("reenabled automatic playback returns to user's prior one day",main.solar_rate==1.0)
	ui._set_rate(ui.ASTRONOMY_RATES.find(30.0)); main.follow_planet(4)
	check("explicit fast rate is preserved even on the next selection",main.solar_rate==30.0 and main._solar_close_playback.is_empty())
	ui._set_rate(100)
	check("explicit auto menu can adopt that fast rate and slow the whole system",is_equal_approx(main.solar_rate,1.0/24.0) and main._solar_close_playback.rate==30.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD+12.0); main._reset_camera()
	check("manual date cancels stale return and keeps the chosen date",main.solar_jd==Ephemeris.DEFAULT_JD+12.0 and is_equal_approx(main.solar_rate,1.0/24.0) and main._solar_close_playback.is_empty())
	main.set_solar_rate(0.0); main.follow_content(2); main._reset_camera()
	check("explicit date hold is never restarted by close or return",main.solar_rate==0.0 and main._solar_close_playback.is_empty() and main.world.paused)
	prepare_auto(); main.follow_planet(4); ui._set_rate(100); main._reset_camera()
	check("disabling automatic mode keeps current rate as manual choice",is_equal_approx(main.solar_rate,1.0/24.0) and main.solar_manual_setting and main._solar_close_playback.is_empty())
	prepare_auto(); main.follow_planet(5)
	get_window().size=Vector2i(1280,880); await settle(); main.follow_planet(5); await settle()
	check("near slow card and transport remain inside narrow window",Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).encloses(ui.context_panel.get_global_rect()) and Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).encloses(ui.transport.get_global_rect()) and ui.context_note.text.contains("近景慢放"))
	await capture("saturn-narrow-slow")
	get_window().size=Vector2i(2560,1600); await settle()
	var current_jd: float=main.solar_jd
	if await arrive("earth_moon"):
		check("leaving solar close clears temporary return and keeps the date",main._solar_close_playback.is_empty() and main.solar_rate==10.0 and main.solar_jd==current_jd and main.world.paused)
		check("other astronomy menu has no solar automatic checkbox",ui.rate_button.get_popup().get_item_index(100)<0)
	if await arrive("solar_system"):
		check("return from another scale offers the single solar checkbox",ui.rate_button.get_popup().get_item_index(100)>=0 and main.solar_jd==current_jd)
	check("single World and no user save remain",main.world.get_instance_id()==world_id and main.world.paused and not main._persistence_enabled)
	check("short probe keeps five FPS and two worker budget",Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func prepare_auto(rate: float=10.0) -> void:
	main._reset_camera(); main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.solar_manual_setting=false; main.solar_demo_auto=rate==10.0
	main._set_solar_playback_rate(rate)
	main._update_exploration(); main.immersive_interface.refresh()

func drawable_window() -> bool:
	var window: Window=get_window()
	window.unfocusable=false
	window.mode=Window.MODE_WINDOWED
	window.size=Vector2i(2560,1600)
	window.position=DisplayServer.screen_get_usable_rect(window.current_screen).position+Vector2i(30,30)
	window.show(); window.grab_focus.call_deferred()
	print("SOLAR266_REQUEST_ACTIVATION")
	var deadline: int=Time.get_ticks_msec()+7000
	var stable: int=0
	while stable<4 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		stable=stable+1 if DisplayServer.window_can_draw() and main.world.foreground else 0
	var state: Dictionary={"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw(),"focused":window.has_focus(),"mode":window.mode,"visible":window.visible,"position":str(window.position),"size":str(window.size)}
	FileAccess.open(directory.path_join("window.json"),FileAccess.WRITE).store_string(JSON.stringify(state,"\t")+"\n")
	print("SOLAR266_WINDOW_READY ",JSON.stringify(state))
	check("diagnostic window actually drawable before motion and input",stable>=4)
	return stable>=4

func advance_for(seconds: float) -> void:
	var until: float=main.world.simulation_time_s+seconds
	var deadline: int=Time.get_ticks_msec()+4000
	while main.world.simulation_time_s<until and Time.get_ticks_msec()<deadline: await get_tree().process_frame

func same_date() -> bool:
	var stage: Node=main.coordinator.active_scene
	var coherent: bool=stage.world_root.get_node("Sun_AuthoredPhotosphere").basis.orthonormalized().is_equal_approx(Orientation.sun_basis(main.solar_jd))
	for index: int in range(8):
		var body: MeshInstance3D=stage.get_meta("solar_bodies")[index].node
		coherent=coherent and body.position.is_equal_approx(Ephemeris.display_position(index,main.solar_jd,main.solar_true_distance)) and body.basis.orthonormalized().is_equal_approx(Orientation.body_basis(index,main.solar_jd))
	var moon: Dictionary=stage.get_meta("solar_moon")
	return coherent and moon.node.basis.orthonormalized().is_equal_approx(Orientation.moon_basis(main.solar_jd)) and absf(float(moon.jd)-main.solar_jd)<1e-10

func saved_close() -> void:
	main._remember_view()
	var view: Dictionary=main._views.solar_system.duplicate(true)
	check("automatic close view validates for existing save system",main.WorldStore.valid_view(view) and view.astronomy.close_playback.target==4)
	var preferences: Dictionary={"render_ratio":main._render_ratio,"reduced_motion":main._reduced_motion,"muted":main._muted}
	for key: String in ["master","environment_volume","music_volume","effects_volume"]: preferences[key]=float(main.soundscape.get(key))
	var fixture: RefCounted=main.WorldStore.new(directory.path_join("fixture-session"))
	var opened: Dictionary=fixture.load_session()
	check("save fixture is a new isolated session",opened.status=="missing")
	var status: String=fixture.save_session({"world":main.world.checkpoint(),"observer":{"views":main._views.duplicate(true),"preferences":preferences}})
	var loaded: Dictionary=fixture.load_session()
	check("isolated actual save and load retains automatic return setting",status=="ok" and loaded.status=="ok" and loaded.payload.observer.views.solar_system.astronomy.close_playback.rate==10.0)
	if status!="ok" or loaded.status!="ok": return
	main._views=loaded.payload.observer.views.duplicate(true)
	var date: float=main.solar_jd
	var camera: Transform3D=main.coordinator.active_scene.camera.transform
	main._restore_solar_view(); main._follow_scale=""; main._update_ui(); main._apply_saved_view(main.coordinator.active_scene); main._update_exploration()
	check("restored automatic close keeps target camera date and original return",main.solar_follow==4 and absf(main.solar_jd-date)<1e-8 and is_equal_approx(main.solar_rate,1.0/24.0) and main._solar_close_playback.rate==10.0 and main.coordinator.active_scene.camera.transform.is_equal_approx(camera))
	var legacy: Dictionary=view.duplicate(true); legacy.astronomy.erase("close_playback")
	check("older astronomy view remains valid",main.WorldStore.valid_view(legacy))
	var invalid: Dictionary=view.duplicate(true); invalid.astronomy.close_playback.target=9.5
	check("invalid fractional close target is rejected",not main.WorldStore.valid_view(invalid))
	invalid=view.duplicate(true); invalid.astronomy.close_playback.rate=-30.0
	check("invalid return rate is rejected",not main.WorldStore.valid_view(invalid))
	invalid=view.duplicate(true); invalid.astronomy.manual=true
	check("automatic return cannot masquerade as manual choice",not main.WorldStore.valid_view(invalid))


func earth_transition_sample(_request: int, progress: float) -> void:
	if not is_instance_valid(main._outgoing) or not is_instance_valid(main._incoming): return
	var solar: Node = main._outgoing if main._outgoing.scale_id=="solar_system" else main._incoming
	var earth: Node = main._incoming if main._incoming.scale_id=="earth" else main._outgoing
	if solar.scale_id!="solar_system" or earth.scale_id!="earth": return
	var body: MeshInstance3D = solar.get_meta("solar_bodies")[2].node
	var radius: float = float(body.mesh.radius)*absf(body.scale.x)
	var rotation: Basis = Orientation.body_basis(2,main.solar_jd)
	var error: float = 0.0
	for point: Vector3 in [Vector3.ZERO,Vector3(3,0,0),Vector3(0,3,0),Vector3(0,0,3)]:
		var projected: Vector2 = solar.camera.unproject_position(body.position+rotation*point*(radius/3.0))
		error=maxf(error,projected.distance_to(earth.camera.unproject_position(point)))
	earth_transition_samples.append({"progress":progress,"rate":main.solar_rate,"jd":main.solar_jd,"world_time":main.world.simulation_time_s,
		"date_error_days":absf(main.solar_jd-earth_transition_jd-(main.world.simulation_time_s-earth_transition_time)*earth_transition_rate),
		"projection_error_px":error,"outside_radius":solar.camera.position.distance_to(body.position)/radius,
		"solar_camera_ecef":var_to_str(rotation.transposed()*(solar.camera.position-body.position)*(3.0/radius)),
		"earth_camera":var_to_str(earth.camera.position),"solar_pose_same_date":body.basis.orthonormalized().is_equal_approx(rotation),
		"earth_sun_same_date":Vector3(earth.materials[0].get_shader_parameter("sun_direction")).is_equal_approx(Orientation.sun_ecef(main.solar_jd))})


func earth_transition_fly(target: String, label: String, expected_rate: float, double_click: bool=false, cancelled: bool=false) -> void:
	earth_transition_samples.clear()
	earth_transition_rate=expected_rate; earth_transition_jd=main.solar_jd; earth_transition_time=main.world.simulation_time_s
	if double_click:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.double_click=true
		event.position=main.object_pointer.last_click
		check(label+" actual 3D double-click accepts the transition",main.object_pointer.pointer(event) and main.coordinator.is_busy())
	else: main.navigate_to(target)
	check(label+" request preserves the active common rate",is_equal_approx(main.solar_rate,expected_rate))
	var deadline: int = Time.get_ticks_msec()+16000
	var captured: bool = false
	while main.coordinator.is_busy() and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not earth_transition_samples.is_empty():
			var sample: Dictionary = earth_transition_samples.back()
			if cancelled and float(sample.progress)>.25:
				main.coordinator.cancel("earth272_short_cancel")
				break
			if not captured and float(sample.progress)>=.42 and float(sample.progress)<=.58:
				await RenderingServer.frame_post_draw
				var status: Error = get_viewport().get_texture().get_image().save_png(directory.path_join(label+"-boundary.png"))
				check(label+" real transition frame saved",status==OK)
				captures.append(label+"-boundary.png"); captured=true
	var continuous: bool = not earth_transition_samples.is_empty()
	var aligned: bool = false
	var outside: bool = true
	var same: bool = true
	var max_error: float = 0.0
	for sample: Dictionary in earth_transition_samples:
		continuous=continuous and is_equal_approx(float(sample.rate),expected_rate) and float(sample.date_error_days)<.000001
		outside=outside and float(sample.outside_radius)>1.05
		same=same and bool(sample.solar_pose_same_date) and bool(sample.earth_sun_same_date)
		if float(sample.progress)>=.42 and float(sample.progress)<=.58:
			aligned=true; max_error=maxf(max_error,float(sample.projection_error_px))
	check(label+" playback stays continuous at the intended shared rate",continuous)
	check(label+" both scenes use the same date and physical orientation",same)
	check(label+" camera stays outside the Earth surface",outside)
	if not cancelled: check(label+" both globe and geographic landmarks align through the blend",aligned and max_error<.5)
	check(label+" reaches the intended scene without a stuck transition",not main.coordinator.is_busy() and main.world.current_scale_id==("solar_system" if cancelled else target))
	measurements.append({"kind":"earth272 "+label,"expected_rate":expected_rate,"max_blend_error_px":max_error,"samples":earth_transition_samples.duplicate(true),"cancelled":cancelled})
	main.world.set_paused(true)
	await settle()


func earth_transition_prepare(manual: bool=false) -> void:
	prepare_auto()
	main._reduced_motion=false
	if manual: main.set_solar_rate(30.0)
	main.follow_planet(2); main._update_solar_camera(2.0)
	await settle()
	var stage: Node = main.coordinator.active_scene
	var earth: MeshInstance3D = stage.get_meta("solar_bodies")[2].node
	var radius: float = float(earth.mesh.radius)*absf(earth.scale.x)
	var point: Vector2 = stage.camera.unproject_position(earth.position)
	# A nearby Moon can correctly occlude the disk center. Click an exposed
	# part of the actual Earth instead of assuming its center ray is clear.
	for offset: Vector3 in [Vector3.ZERO,stage.camera.basis.x*radius*.5,-stage.camera.basis.x*radius*.5,stage.camera.basis.y*radius*.5,-stage.camera.basis.y*radius*.5]:
		var candidate: Vector2 = stage.camera.unproject_position(earth.position+offset)
		if main.object_pointer.pick(candidate).get("planet",-1)==2:
			point=candidate; break
	main.object_pointer.activate(point)
	main._update_solar_camera(2.0)
	await settle()
	check("Earth near is selected by the real 3D picker",main.object_pointer.last_choice.get("planet",-1)==2 and main.solar_follow==2)
	measurements.append({"kind":"earth272 pick preparation","manual":manual,"pixel":str(point),"picked_label":str(main.object_pointer.last_choice.get("label","")),"picked_planet":main.object_pointer.last_choice.get("planet",-1),"solar_follow":main.solar_follow,"jd":main.solar_jd,"rate":main.solar_rate})
	main.world.set_paused(false)


func earth_transition_checks() -> void:
	if not await drawable_window(): return
	var world_id: int = main.world.get_instance_id()
	main.coordinator.authoring_progress.connect(earth_transition_sample)
	await earth_transition_prepare()
	await earth_transition_fly("earth","auto-enter",1.0/24.0,true)
	check("arrival ends temporary close playback using Earth observation policy",main._solar_close_playback.is_empty() and main.solar_rate==0.0 and main.solar_demo_auto)
	if "--earth272-reproduce-only" in OS.get_cmdline_user_args(): return
	if main.world.current_scale_id!="earth": return
	main.world.set_paused(false)
	await earth_transition_fly("solar_system","auto-return",0.0)
	check("return to solar restores default overview playback",main.solar_rate==10.0 and main.solar_demo_auto)
	await earth_transition_prepare()
	await earth_transition_fly("earth","cancel-enter",1.0/24.0,true,true)
	check("cancel retains the chosen Earth near playback and return preference",is_equal_approx(main.solar_rate,1.0/24.0) and not main._solar_close_playback.is_empty() and main._solar_close_playback.rate==10.0 and main.solar_follow==2)
	main._reset_camera()
	check("cancelled near still returns to ten days per second",main.solar_rate==10.0 and main._solar_close_playback.is_empty())
	await earth_transition_prepare(true)
	await earth_transition_fly("earth","manual-enter",30.0,true)
	check("explicit fast playback survives Earth arrival",main.solar_rate==30.0 and main.solar_manual_setting and not main.solar_demo_auto)
	main.world.set_paused(false)
	await earth_transition_fly("solar_system","manual-return",30.0)
	check("explicit fast playback survives the return",main.solar_rate==30.0 and main.solar_manual_setting and main._solar_close_playback.is_empty())
	main.set_solar_rate(0.0); main.world.set_paused(true); main._reduced_motion=true
	var jd: float=main.solar_jd
	if await arrive("earth") and await arrive("solar_system"):
		check("reduced motion keeps paused date and explicit hold",main.solar_jd==jd and main.world.paused and main.solar_rate==0.0)
	check("Earth transitions retain one World no save and resource budget",main.world.get_instance_id()==world_id and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
