extends "res://tests/integration/satellite_coverage_suite.gd"
## Finite regression of user orbit/pan/zoom, opaque Sun and shared near playback.
const Solar = preload("res://scripts/experience/solar_satellite_view.gd")
const USER_JD: float = 2461786.5 # 2028-01-16 TDB, the user's reported date.

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--solar276-output="): directory=argument.trim_prefix("--solar276-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(75.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80.0
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	var identity: int = main.world.get_instance_id()
	var stage: Node = main.coordinator.active_scene
	main.set_solar_date(USER_JD); main._update_exploration()
	prepare_auto()
	var planet: MeshInstance3D = stage.get_meta("solar_bodies")[4].node
	var radius: float = Solar.radius(stage,4)
	var radial: Vector3 = planet.position.normalized()
	var side: Vector3 = radial.cross(Vector3.UP).normalized()
	# An ordinary Sun-centered orbit passes near independently enlarged Jupiter.
	# It must not silently remove the Sun or all the other overview planets.
	stage.set_pose((radial.rotated(Vector3.UP,.70)+Vector3.UP*.13).normalized()*(planet.position.length()+radius*15.0),Vector3.ZERO)
	main._orbit_target=Vector3.ZERO
	drag(Vector2(8.0,-3.0))
	await settle()
	check("Sun-centered free orbit retains opaque visible Sun",sun_visible(stage))
	check("free orbit keeps all eight overview planets",overview_visible(stage))
	await sun_pixels(stage,"sun-centred-drag")
	await capture("sun-centred-drag")
	# Same distance criterion, but the nearby giant is completely off screen.
	prepare_auto()
	stage.set_pose(planet.position+radial*radius+side*radius*4.0,Vector3.ZERO)
	main._orbit_target=Vector3.ZERO
	drag(Vector2(.1,0.0))
	await settle()
	var point: Vector2 = stage.camera.unproject_position(planet.position)
	check("offscreen fixture is outside the actual viewport",not Rect2(Vector2.ZERO,Vector2(stage.viewport.size)).has_point(point))
	check("offscreen planet cannot reveal its satellite context",not stage.get_meta("solar_satellite_systems")[4].root.visible)
	check("offscreen planet cannot hide Sun or alter overview rate",sun_visible(stage) and main.solar_rate==10.0 and main._solar_close_playback.is_empty())
	await sun_pixels(stage,"offscreen-planet")
	await capture("offscreen-planet")
	prepare_auto()
	main._orbit_target=planet.position
	stage.set_pose(planet.position+(Vector3(.6,.4,1.0).normalized()*radius*30.0),planet.position)
	var before_jd: float = main.solar_jd
	var before_time: float = main.world.simulation_time_s
	var magnify: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	magnify.factor=2.0; magnify.position=get_viewport().get_visible_rect().size*.5
	main._unhandled_input(magnify)
	await settle()
	check("unselected natural zoom reveals major moons",main.solar_follow<0 and main._content_follow<0 and stage.get_meta("solar_satellite_systems")[4].root.visible)
	check("natural approach slows the one whole system",is_equal_approx(main.solar_rate,1.0/24.0) and float(main._solar_close_playback.get("rate",-1.0))==10.0)
	check("paused natural approach never changes date or World time",main.world.paused and main.solar_jd==before_jd and main.world.simulation_time_s==before_time)
	drag(Vector2(160.0,24.0)); await settle()
	check("drag within near system retains shared slow rate",is_equal_approx(main.solar_rate,1.0/24.0))
	await capture("natural-near-drag")
	var start_jd: float = main.solar_jd
	var start_time: float = main.world.simulation_time_s
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+3000
	while main.world.simulation_time_s-start_time<.6 and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true); main._update_exploration()
	var elapsed: float = main.world.simulation_time_s-start_time
	check("natural near playback advances one date at one hour per second",elapsed>0.0 and absf(main.solar_jd-start_jd-elapsed/24.0)<.000001)
	var same_date: bool = true
	for body: Dictionary in stage.get_meta("solar_satellite_systems")[4].bodies:
		var state: Dictionary = Model.sample(body.record,main.solar_jd)
		var position: Vector3 = planet.position+Model.world_position(state,main.Ephemeris.RADII_KM[4])*radius
		same_date=same_date and body.node.position.distance_to(position)<.0005
	check("all four visible major moons agree with the same date",same_date)
	measurements.append({"kind":"natural playback","elapsed_world_s":elapsed,"date_delta_days":main.solar_jd-start_jd,"rate_days_s":main.solar_rate})
	main._remember_view()
	var saved: Dictionary = main._views.solar_system.duplicate(true)
	check("natural slow ownership validates for existing saves",main.WorldStore.valid_view(saved) and bool(saved.astronomy.close_playback.get("context",false)))
	var invalid: Dictionary = saved.duplicate(true)
	invalid.solar_exploring="yes"
	check("save rejects a nonboolean camera exploration flag",not main.WorldStore.valid_view(invalid))
	invalid=saved.duplicate(true)
	invalid.astronomy.close_playback.context="yes"
	check("save rejects a nonboolean natural ownership flag",not main.WorldStore.valid_view(invalid))
	invalid=saved.duplicate(true); invalid.astronomy.close_playback.target=8
	check("save rejects natural ownership outside five satellite hosts",not main.WorldStore.valid_view(invalid))
	var camera: Transform3D = stage.camera.transform
	main._solar_close_playback.clear(); main._follow_scale=""
	main._restore_solar_view(); main._update_ui(); main._apply_saved_view(stage); main._update_exploration()
	check("restore keeps free camera rather than selecting a planet",main.solar_follow<0 and main._content_follow<0 and stage.camera.transform.is_equal_approx(camera) and bool(main._solar_close_playback.get("context",false)))
	magnify.factor=1.0/1.5
	main._unhandled_input(magnify); await settle()
	check("small retreat within exit margin does not flap playback",is_equal_approx(main.solar_rate,1.0/24.0))
	main._unhandled_input(magnify); await settle()
	check("pulling away restores previous overview rate without restarting pause",main.solar_rate==10.0 and main._solar_close_playback.is_empty() and main.world.paused)
	check("pulling away restores opaque Sun and all overview planets",sun_visible(stage) and overview_visible(stage))
	await capture("drag-return-overview")
	main.set_solar_rate(30.0)
	main._orbit_target=planet.position
	stage.set_pose(planet.position+Vector3(.6,.4,1.0).normalized()*radius*15.0,planet.position)
	drag(Vector2(18.0,6.0)); await settle()
	check("explicit fast rate remains the user's choice",main.solar_rate==30.0 and main.solar_manual_setting and main._solar_close_playback.is_empty())
	main.set_solar_rate(0.0); await settle()
	check("explicit hold never restarts on a natural approach",main.solar_rate==0.0 and main._solar_close_playback.is_empty())
	prepare_auto(); main.follow_planet(4); await settle()
	check("selected planet near view retains Sun and all eight planets",sun_visible(stage) and overview_visible(stage) and stage.world_root.get_node("SolarCorona_Illustration").visible)
	main._reset_camera(); await settle()
	check("return from selection restores opaque Sun and corona together",sun_visible(stage) and stage.world_root.get_node("SolarCorona_Illustration").visible)
	check("preset overview does not reenter natural slow playback",main.solar_rate==10.0 and main._solar_close_playback.is_empty() and not bool(stage.get_meta("solar_camera_exploring",true)))
	check("single World no user save and short resource limits",main.world.get_instance_id()==identity and not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func prepare_auto() -> void:
	main._reset_camera()
	main.solar_manual_setting=false; main.solar_demo_auto=true
	main._set_solar_playback_rate(10.0)
	main._update_exploration()

func drag(relative: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask=MOUSE_BUTTON_MASK_RIGHT
	event.position=get_viewport().get_visible_rect().size*.5
	event.relative=relative
	main._unhandled_input(event)

func sun_visible(stage: Node) -> bool:
	var sun: MeshInstance3D = stage.world_root.get_node("Sun_AuthoredPhotosphere")
	return sun.is_visible_in_tree() and sun.transparency==0.0

func overview_visible(stage: Node) -> bool:
	for body: Dictionary in stage.get_meta("solar_bodies"):
		if not body.node.is_visible_in_tree() or body.node.transparency!=0.0: return false
	return true

func sun_pixels(stage: Node, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = stage.viewport.get_texture().get_image()
	var projected: Vector2 = stage.camera.unproject_position(Vector3.ZERO)
	var brightness: float = 0.0
	var samples: int = 0
	for x: int in range(-2,3):
		for y: int in range(-2,3):
			var pixel: Vector2i = Vector2i(projected)+Vector2i(x*3,y*3)
			if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel): continue
			var c: Color = image.get_pixelv(pixel)
			brightness+=(c.r+c.g+c.b)/3.0; samples+=1
	if samples>0: brightness/=samples
	var sun: MeshInstance3D = stage.world_root.get_node("Sun_AuthoredPhotosphere")
	measurements.append({"kind":"Sun rendered centre","label":label,"mean_rgb":brightness,"samples":samples,"sun_visible":sun.visible,"sun_transparency":sun.transparency,"local_context":stage.get_meta("solar_local_context",-1),"camera_position":str(stage.camera.position)})
	check("actual Sun centre is luminous after "+label,samples==25 and brightness>.2)
