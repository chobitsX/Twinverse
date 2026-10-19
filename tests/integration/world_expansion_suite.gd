extends Node
const Experience = preload("res://scenes/experience.tscn")
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
var main: Node
var directory: String
var cases: Array[Dictionary] = []
var failures: Array[String] = []
var captures: Array[String] = []
func _ready() -> void: run.call_deferred()
func check(label: String, passed: bool) -> void:
	cases.append({"name":label,"passed":passed})
	if not passed: failures.append(label)
	print("EXPANSION_CASE ",label," ",passed)
func ready_stage() -> bool:
	var deadline: int = Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground:
			if DisplayServer.get_name()=="headless" or DisplayServer.window_can_draw(): return true
	check("stage ready",false)
	return false
func arrive(id: String) -> bool:
	main.observe_scale(id)
	if not await ready_stage(): return false
	check("arrive "+id,main.world.current_scale_id==id)
	return main.world.current_scale_id==id
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var status: Error = get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
	check("capture "+label,status==OK)
	captures.append(label+".png")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world84-check="): directory = argument.trim_prefix("--world84-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		push_error("Expansion check needs absolute evidence directory and --no-save")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if not await ready_stage():
		await finish()
		return
	if DisplayServer.get_name()!="headless":
		# macOS activation/occlusion notifications can arrive after the first
		# rendered frame. Start automated input after a stable visible interval.
		var stable_since: int = Time.get_ticks_msec()
		var startup_deadline: int = stable_since+10000
		while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<startup_deadline:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since = Time.get_ticks_msec()
	main._reduced_motion = true
	main.world.set_paused(true)
	if "--world84-marine" in OS.get_cmdline_user_args():
		await capture("city-start")
		await marine()
		return
	if not await arrive("solar_system"):
		await finish()
		return
	main.explorer_panel.show()
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	await get_tree().process_frame
	await capture("solar-observatory")
	var stage: Node = main.coordinator.active_scene
	var bodies: Array = stage.get_meta("solar_bodies")
	var start: Vector3 = bodies[0].node.position
	main.set_solar_date(Ephemeris.DEFAULT_JD+20)
	await get_tree().process_frame
	await get_tree().process_frame
	check("Mercury advances on ellipse",start.distance_to(bodies[0].node.position)>1.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.explorer_panel.hide()
	main.follow_planet(5)
	await capture("saturn-follow")
	var offset: Vector3 = stage.camera.position-main._orbit_target
	main.set_solar_date(Ephemeris.DEFAULT_JD+30)
	await get_tree().process_frame
	await get_tree().process_frame
	check("planet follow keeps camera offset",(stage.camera.position-main._orbit_target).distance_to(offset)<0.001)
	main.set_solar_distance(true)
	await get_tree().process_frame
	await get_tree().process_frame
	check("common AU distance scale",absf(bodies[7].node.position.length()/Ephemeris.position_au(7,main.solar_jd).length()-0.55)<0.0001)
	await capture("solar-true-distance")
	main.set_solar_distance(false)
	main.set_solar_date(Ephemeris.END_JD)
	main.set_solar_rate(100.0)
	main.world.simulation_time_s += 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	check("ephemeris range stops",main.solar_rate==0.0 and main.solar_jd==Ephemeris.END_JD)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	if not await arrive("earth"):
		await finish()
		return
	if not await arrive("woodland"):
		await finish()
		return
	main.explorer_panel.show()
	await capture("woodland-overview")
	check("land animals present",main.coordinator.active_scene.get_meta("actors").size()==20)
	main.explorer_panel.hide()
	main.follow_content(1)
	await capture("woodland-deer")
	main._navigate_relative(-1)
	if not await ready_stage():
		await finish()
		return
	check("branch returns to earth",main.world.current_scale_id=="earth")
	if not await arrive("city"):
		await finish()
		return
	main.explorer_panel.show()
	await capture("city-overview")
	check("people and vehicles",main.coordinator.active_scene.get_meta("actors").size()==40)
	main.explorer_panel.hide()
	main.follow_content(1)
	await capture("city-person")
	await marine()

func marine() -> void:
	if not await arrive("reef"):
		await finish()
		return
	main.explorer_panel.show()
	await capture("reef-diversity")
	check("five marine morphotypes",main.coordinator.active_scene.get_meta("marine_actors").size()==44)
	main.explorer_panel.hide()
	main.follow_content(4)
	await capture("marine-turtle")
	var target: Node3D = main.content_targets()[3].node
	var old: Vector3 = target.position
	main.world.set_paused(false)
	var limit: int = Time.get_ticks_msec()+1200
	while Time.get_ticks_msec()<limit: await get_tree().process_frame
	main.world.set_paused(true)
	check("world time drives marine motion",target.position.distance_to(old)>0.005)
	if not await arrive("solar_system"):
		await finish()
		return
	main.set_solar_rate(10.0)
	main._remember_view()
	check("observer date records",main._views.solar_system.has("astronomy"))
	await finish()
func finish() -> void:
	var output: FileAccess = FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"performance_test":false,"window_activity_policy":"visible_diagnostic" if main._measurement_screen>=0 else "focused","last_transition":main.coordinator.latest_metrics},"\t")+"\n")
	print("EXPANSION_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
