extends Node
## Finite native-engine checks of the frozen catalogue, positions and real entry paths.
const Experience = preload("res://scenes/experience.tscn")
const Model = preload("res://scripts/core/natural_satellites.gd")
const Builder = preload("res://scripts/experience/satellite_system_builder.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
var main: Node
var directory: String = ""
var cases: Array[Dictionary] = []
var failures: Array[String] = []
var captures: Array[String] = []
var measurements: Array[Dictionary] = []

func _ready() -> void:
	run.call_deferred()

func check(label: String, passed: bool) -> void:
	cases.append({"label":label,"passed":passed})
	if not passed: failures.append(label)
	print("SATELLITES273_CHECK ",label," ",passed)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--satellites273-output="): directory=argument.trim_prefix("--satellites273-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	data_checks()
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80.0
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide()
	main.set_solar_date(main.Ephemeris.DEFAULT_JD)
	main.set_solar_rate(1.0/24.0)
	var world_id: int = main.world.get_instance_id()
	var mapping: Dictionary = {3:"mars",4:"jupiter",5:"saturn",6:"uranus",7:"neptune"}
	for planet: int in mapping:
		main.follow_planet(planet)
		await settle()
		var solar: Node = main.coordinator.active_scene
		var projected: Vector2 = solar.camera.unproject_position(solar.get_meta("solar_bodies")[planet].node.position)
		var picked: Dictionary = main.object_pointer.pick(projected)
		check("solar planet remains picked in 3D "+str(planet),picked.get("planet",-1)==planet)
		main.enter_spatial_choice(picked)
		if not await ready_stage(): break
		var stage: Node = main.coordinator.active_scene
		var parent: String = str(mapping[planet])
		check("double-click destination "+parent,stage.scale_id==Model.BRANCHES[parent])
		if not stage.has_meta("natural_satellites"): break
		var data: Dictionary = stage.get_meta("natural_satellites")
		var covered: int = 0
		for item: Dictionary in Model.records(parent):
			if item.ephemeris_status=="vectors": covered+=1
		check("every cached identity has one selectable body "+parent,data.bodies.size()==covered and main.content_targets().size()==covered+1)
		var coherent: bool = true
		for body: Dictionary in data.bodies:
			var expected: Dictionary = Model.sample(body.record,main.solar_jd)
			coherent=coherent and expected.valid and body.node.position.distance_to(Model.world_position(expected,float(data.radius_km)))<.0005
		check("same-date real orbital positions "+parent,coherent and is_equal_approx(main.solar_rate,1.0/24.0))
		if parent=="saturn":
			var start_time: float = main.world.simulation_time_s
			var start_jd: float = main.solar_jd
			main._toggle_pause()
			var until: int = Time.get_ticks_msec()+3500
			while main.world.simulation_time_s-start_time<.6 and Time.get_ticks_msec()<until: await get_tree().process_frame
			main._toggle_pause(); main._update_exploration()
			var elapsed: float = main.world.simulation_time_s-start_time
			check("actual playback advances every moon by the shared rate",elapsed>0.0 and absf(main.solar_jd-start_jd-elapsed/24.0)<.000001)
			measurements.append({"kind":"native playback","elapsed_world_s":elapsed,"rate":main.solar_rate,"start_jd":start_jd,"end_jd":main.solar_jd,"foreground":main.world.foreground})
		check("reference planet uses same IAU date "+parent,data.planet.basis.is_equal_approx(Orientation.body_basis(planet,main.solar_jd)))
		main.immersive_interface.refresh()
		check("shared rate and date controls visible "+parent,main.immersive_interface.rate_button.text=="1小时/秒" and main.time_label.tooltip_text.ends_with("TDB"))
		var world_rate: float = main.world.time_scale
		main.immersive_interface.rate_button.get_popup().id_pressed.emit(2)
		check("actual satellite rate menu changes astronomy only "+parent,main.solar_rate==1.0 and main.world.time_scale==world_rate)
		main.immersive_interface.rate_button.get_popup().id_pressed.emit(1)
		main.explorer_panel.show(); main.explorer_panel._process(0.0)
		main.explorer_panel.observation_toggle.pressed.emit()
		var panel: Node = main.explorer_panel.satellite_catalogue
		panel.present()
		check("complete searchable identity catalogue "+parent,panel.is_visible_in_tree() and panel._filtered.size()==Model.count(parent) and panel.picker.item_count==Model.count(parent)+1)
		if parent=="saturn":
			panel.search.text="S/2009 S1"; panel._populate(); panel.picker.item_selected.emit(1)
			check("missing ephemeris remains searchable and cannot fake a close view",panel._filtered.size()==1 and panel.information.text.contains("不绘制猜测位置") and panel.observe.disabled)
			panel.search.text=""; panel._populate()
			await capture("saturn-catalogue")
		main.explorer_panel.hide(); main._reset_camera(); await settle()
		await capture(parent+"-inner")
		Builder.focus_system(stage,true); main._orbit_target=Vector3.ZERO; await settle()
		check("outer view reaches the complete radial extent "+parent,stage.camera.position.length()>float(data.extent)*2.0)
		if parent=="saturn": await capture("saturn-outer")
		main.follow_content(2); await settle()
		var moon: Node3D = main.content_targets()[1].node
		var close: Vector2 = stage.camera.unproject_position(moon.position)
		check("moon is picked and framed in 3D "+parent,main.object_pointer.pick(close).get("node")==moon and not stage.camera.is_position_behind(moon.position))
		if parent in ["mars","neptune"]: await capture(parent+"-close")
		main._remember_view()
		check("satellite observer save validates "+parent,main.WorldStore.valid_view(main._views[stage.scale_id]))
		var saved_camera: Transform3D = stage.camera.transform
		main._reset_camera(); main._apply_saved_view(stage)
		check("saved satellite close camera resumes "+parent,main._content_follow==1 and stage.camera.transform.is_equal_approx(saved_camera))
		var held_jd: float = main.solar_jd
		var before: Vector3 = moon.position
		main._update_exploration()
		check("pause retains date and satellite position "+parent,main.world.paused and main.solar_jd==held_jd and moon.position==before)
		main.set_solar_date(held_jd+.03); main._update_exploration()
		check("one date change moves moons while preserving clock "+parent,moon.position.distance_to(before)>0.0 and main.world.paused)
		var saved_offset: Vector3 = saved_camera.origin-before
		main._reset_camera(); main._apply_saved_view(stage)
		check("cross-date restore follows the same moved satellite "+parent,main._content_follow==1 and main._orbit_target.distance_to(moon.position)<.0005 and (stage.camera.position-moon.position).distance_to(saved_offset)<.0005)
		if parent=="saturn": await capture("saturn-date-restored")
		var kept_date: float = main.solar_jd
		main._solar_origin_jd=Model.END_JD+1.0; main.solar_jd=main._solar_origin_jd; main._update_exploration()
		main._apply_saved_view(stage)
		check("out-of-cache restoration does not follow a stale position "+parent,main._content_follow==-1 and not data.root.visible and str(moon.get_meta("activity")).contains("当前日期无卫星位置"))
		main._solar_origin_jd=kept_date; main.solar_jd=kept_date; main._update_exploration()
		if parent=="neptune":
			main.set_solar_date(Model.END_JD); main._update_exploration()
			main._solar_origin_time=main.world.simulation_time_s-1.0
			main._update_exploration()
			check("cache boundary stops without extrapolation",main.solar_jd==Model.END_JD and main.solar_rate==0.0)
		main.navigate_to("solar_system")
		if not await ready_stage(): break
		check("return keeps same shared World "+parent,main.world.current_scale_id=="solar_system" and main.world.get_instance_id()==world_id)
		main.set_solar_date(main.Ephemeris.DEFAULT_JD); main.set_solar_rate(1.0/24.0)
	check("no-save and short resource budget",not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func data_checks() -> void:
	var expected: Array[int] = [0,0,1,2,115,293,29,16,5]
	var keys: Dictionary = {}
	var available_count: int = 0
	var records: Dictionary = {}
	for i: int in range(Model.HOSTS.size()):
		var parent: String = Model.HOSTS[i]
		check("official frozen count "+parent,Model.count(parent)==expected[i])
		for item: Dictionary in Model.records(parent):
			keys[item.key]=true; records[item.key]=item
			if item.ephemeris_status=="vectors": available_count+=1
	check("all 461 identities are unique, planet total 456",keys.size()==461 and Model.catalogue().planet_total==456 and available_count==451)
	check("no extrapolation beyond satellite cache",not Model.available(Model.START_JD-.01) and not Model.available(Model.END_JD+.01))
	var holdouts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/satellites273/holdouts.json"))
	var maximum: float = 0.0
	var count_value: int = 0
	var valid: bool = true
	for item: Dictionary in holdouts.independent_excluded_states:
		for row: Array in item.rows:
			var state: Dictionary = Model.sample(records[item.key],float(row[0]))
			if not state.valid: valid=false; continue
			var error: float = 0.0
			for axis: int in range(3): error+=pow(float(state.position_km[axis])-float(row[axis+1]),2.0)
			error=sqrt(error); maximum=maxf(maximum,error); count_value+=1
			valid=valid and error<float(item.tolerance_km)
	check("all native double decodes match excluded Horizons states",valid and count_value==451*3)
	measurements.append({"kind":"excluded source-state validation","samples":count_value,"max_error_km":maximum,"tolerance":"max(2 km, a * 0.0001), separately per body"})

func ready_stage() -> bool:
	get_window().mode=Window.MODE_WINDOWED
	get_window().show()
	get_window().grab_focus.call_deferred()
	print("SATELLITES273_REQUEST_ACTIVATION")
	var until: int = Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<until:
		await get_tree().process_frame
		if is_instance_valid(main.coordinator.active_scene) and not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and DisplayServer.window_can_draw(): return true
	check("stage became drawable",false)
	print("SATELLITES273_WINDOW_UNAVAILABLE ",JSON.stringify({"visible":get_window().visible,"foreground":main.world.foreground,"can_draw":DisplayServer.window_can_draw(),"mode":get_window().mode,"phase":main.coordinator.phase,"scale":main.world.current_scale_id}))
	return false

func settle() -> void:
	for frame: int in range(3): await get_tree().process_frame
	main._update_exploration(); main.immersive_interface.refresh()

func capture(label: String) -> void:
	for frame: int in range(2): await RenderingServer.frame_post_draw
	var status: Error = get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
	check("capture "+label,status==OK)
	if status==OK: captures.append(label+".png")

func finish() -> void:
	var result: Dictionary = {"cases":cases,"failures":failures,"captures":captures,"measurements":measurements,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"physical_os_input_tested":false}
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("SATELLITES273_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
