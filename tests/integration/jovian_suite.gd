extends "res://tests/integration/deer_skin_suite.gd"
const Store = preload("res://scripts/core/world_store.gd")
const Compare = preload("res://tests/core/test_ecophysiology.gd")
var save_directory: String = ""
var mode: String = ""
const Jovian = preload("res://scripts/core/jovian_ephemeris.gd")
const JovianBuilder = preload("res://scripts/experience/jovian_builder.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world117-check="): directory=argument.trim_prefix("--world117-check=")
		if argument.begins_with("--world-dir="): save_directory=argument.trim_prefix("--world-dir=")
		if argument.begins_with("--jovian-mode="): mode=argument.trim_prefix("--jovian-mode=")
	var isolated: bool = save_directory.is_absolute_path() and save_directory!=ProjectSettings.globalize_path("user://world") and FileAccess.file_exists(save_directory.path_join("jovian-fixture.marker"))
	if not directory.is_absolute_path() or not ("--no-save" in OS.get_cmdline_user_args() or (isolated and mode in ["write","resume"])):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	# Only this bounded diagnostic permits an unfocused visible window.
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	get_window().size=Vector2i(1280,720)
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	if mode=="resume":
		await resume_check()
		return
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.EPOCH)
	if not await arrive("jupiter_moons"):
		await finish()
		return
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	var data: Dictionary = stage.get_meta("jovian")
	check("out-of-cache entry preserves date hides geometry and disables selection",main.solar_jd==Ephemeris.EPOCH and not data.root.visible and panel.object_picker.disabled and stage.get_meta("scientific_label").contains("当前日期无卫星位置"))
	main.set_solar_rate(1.)
	main.follow_content(2)
	check("unavailable dates cannot start misleading motion or close view",main.solar_rate==0 and main._content_follow==-1)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	await settle()
	check("reference date restores complete Jupiter catalogue and controls",data.valid and data.root.visible and not panel.object_picker.disabled and main.content_targets().size()==116 and not main.message_label.text.contains("缓存"))
	main.set_solar_distance(false)
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="jovian_periods": action=button
	check("guide route still opens Jovian period lesson",action!=null)
	if action!=null: action.pressed.emit()
	await settle()
	check("lesson connects shared date and scientific limits",panel._topic.get("id","")=="jovian_periods" and panel.lesson_text.text.contains("理想同步") and panel.lesson_readout.text.contains("1.769"))
	check("whole outer orbit clears overview panel without permanent names",subject_visible(data.bodies[3].orbit) and not data.bodies[3].label.visible and not panel.noon_button.visible)
	await capture("jovian-period-overview")
	var first: Vector3 = data.bodies[0].node.position
	var time: float = main.world.simulation_time_s
	var jd: float = main.solar_jd
	var world_before: Dictionary = main.world.checkpoint()
	main.set_solar_date(jd+.125)
	await settle()
	check("three-hour date change uses cached vectors without advancing world",data.bodies[0].node.position.distance_to(first)>2 and data.bodies[0].node.position.distance_to(Jovian.sample(0,jd+.125).world_km/JovianBuilder.RADIUS_KM)<.00001 and main.world.checkpoint()==world_before)
	var poses: Array[Transform3D] = []
	for body: Dictionary in data.bodies: poses.append(body.node.transform)
	await settle()
	check("paused world and date fix all four poses",main.world.simulation_time_s==time and data.bodies[0].node.transform.is_equal_approx(poses[0]) and data.bodies[3].node.transform.is_equal_approx(poses[3]))
	main.set_solar_distance(true)
	await settle()
	var size_correct: bool = true
	for i: int in range(4):
		size_correct=size_correct and data.bodies[i].node.position.is_equal_approx(poses[i].origin) and absf(data.bodies[i].node.basis.x.length()*5.-poses[i].basis.x.length())<.00001
	check("true size changes only radii and retains relative distances",size_correct and panel.mode.text.contains("真实大小"))
	main.set_solar_distance(false)
	panel.clear_topic()
	for i: int in range(5):
		panel.object_picker.item_selected.emit(i+1)
		await settle()
		var body: MeshInstance3D = main.content_targets()[i].node
		check("selected body %d fits beside explanation and visibly renders" % i,subject_visible(body) and await part_pixels(body,body.position,Vector2i(25,25))>100)
		if i>0:
			check("moon %d has its own map coverage and dated distance" % i,body.material_override.get_shader_parameter("surface_map").resource_path.ends_with(JovianBuilder.KEYS[i-1]+".jpg") and body.material_override.get_shader_parameter("has_coverage") and panel.activity.text.contains("距木星中心") and panel.species_source.visible and not panel.detail.text.contains("食性"))
		check("close view %d hides distant names and guide lines" % i,not data.bodies[0].label.visible and not data.bodies[1].label.visible and not data.bodies[3].orbit.visible)
		await capture("jovian-close-"+str(i))
	get_window().size=Vector2i(900,650)
	panel.select_topic("jovian_periods")
	await settle()
	main._reset_camera()
	await settle()
	check("compact overview retains entire outer trajectory",subject_visible(data.bodies[3].orbit))
	await capture("jovian-compact-overview")
	panel.clear_topic()
	panel.object_picker.item_selected.emit(2)
	await settle()
	check("compact moon view clears panel and near clipping",subject_visible(data.bodies[0].node) and stage.camera.near<.02)
	await capture("jovian-compact-io")
	main.set_solar_date(Jovian.END_JD-.0001)
	main.set_solar_rate(1.)
	main.world.set_paused(false)
	var deadline: int = Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true)
	check("one world clock stops astronomy exactly at cache end",main.world.simulation_time_s>time and main.solar_jd==Jovian.END_JD and main.solar_rate==0 and data.valid)
	main.set_solar_date(Ephemeris.EPOCH)
	check("out-of-range date control does not replace valid geometry",main.solar_jd==Jovian.END_JD)
	panel.date_epoch_button.pressed.emit()
	await settle()
	check("cache-start action uses valid first sample",main.solar_jd==Jovian.START_JD and data.valid)
	main.set_solar_date(Ephemeris.DEFAULT_JD+.125)
	main.set_solar_distance(true)
	main.follow_content(3)
	await settle()
	main._remember_view()
	check("observer records dated Jovian camera and true-size mode",main._views.jupiter_moons.astronomy.jd==main.solar_jd and main._views.jupiter_moons.astronomy.true_distance and main.WorldStore.valid_view(main._views.jupiter_moons))
	jd=main.solar_jd
	if not await arrive("solar_system") or not await arrive("jupiter_moons"):
		await finish()
		return
	check("return retains shared date and radius mode",main.solar_jd==jd and main.solar_true_distance and main.coordinator.active_scene.get_meta("jovian").valid)
	main._navigate_relative(-1)
	if not await ready_stage():
		await finish()
		return
	main.set_solar_date(Ephemeris.EPOCH)
	await settle()
	check("back returns solar system with its original wider date range",main.world.current_scale_id=="solar_system" and main.solar_jd==Ephemeris.EPOCH)
	if mode=="write":
		main.set_solar_date(Ephemeris.DEFAULT_JD+.125)
		if not await arrive("jupiter_moons"):
			await finish()
			return
		main.set_solar_distance(true)
		main.follow_content(3)
		await settle()
		main.save_button.pressed.emit()
		var saved: Dictionary = Store.new(save_directory).load_session()
		check("production save writes protective v9 with actual date and Jovian camera",saved.status=="ok" and saved.payload.world.version==9 and saved.payload.world.current_scale_id=="jupiter_moons" and saved.payload.observer.views.jupiter_moons.astronomy.jd==main.solar_jd)
		FileAccess.open(save_directory.path_join("jovian-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"world":main.world.checkpoint(),"view":saved.payload.observer.views.jupiter_moons},"\t",true,true))
	await finish()

func resume_check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_directory.path_join("jovian-expected.json")))
	var actual: Dictionary = main.world.checkpoint()
	var same: bool = main.world.current_scale_id=="jupiter_moons"
	for key: String in ["science","woodland_browse","urban_runoff","coral_symbiosis","simulation_time_s","paused","seed","accumulator_s"]:
		same=same and Compare.equivalent(actual[key],expected.world[key])
	check("new Release process restores Jovian branch and all authoritative models",same)
	check("resume records continuation without elapsed biological time",actual.local_habitat.events[-1].kind=="continued")
	var stage: Node = main.coordinator.active_scene
	await settle()
	check("reloaded astronomy retains exact date and true size",main.solar_jd==expected.view.astronomy.jd and main.solar_true_distance and stage.get_meta("jovian").valid)
	check("saved camera restores actual selected close field",stage.camera.position.distance_to(Store.vector(expected.view.position))<.0001 and main._orbit_target.distance_to(Store.vector(expected.view.target))<.0001)
	var body: MeshInstance3D = stage.get_meta("jovian").bodies[1].node
	check("resumed moon rebuilds from same cached date",body.position.distance_to(Jovian.sample(1,main.solar_jd).world_km/JovianBuilder.RADIUS_KM)<.00001)
	main.explorer_panel.show()
	main.follow_content(3)
	await settle()
	check("resumed panel selects visible same moon",subject_visible(body) and main._content_follow==2)
	await capture("jovian-resumed")
	await finish()
