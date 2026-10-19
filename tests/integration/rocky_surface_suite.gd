extends "res://tests/integration/solar_size_suite.gd"
const Science = preload("res://scripts/experience/science_reference.gd")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world133-check="): directory=argument.trim_prefix("--world133-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,720)
	if native: root.unfocusable=true
	main=Experience.instantiate()
	root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("solar_system"):
		finish_rocky()
		return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.set_solar_rate(0.)
	main.world_guide.hide()
	main.explorer_panel.show()
	var stage: Node=main.coordinator.active_scene
	for i: int in [0,3]:
		var key: String="mercury" if i==0 else "mars"
		main.follow_planet(i)
		await frames()
		var body: Dictionary=stage.get_meta("solar_bodies")[i]
		var map: Texture2D=body.material.get_shader_parameter("planet_map")
		check(key+" actual historical surface bound",body.material.get_shader_parameter("has_planet_map") and map==stage.textures[key] and map.resource_path.ends_with("rocky133/"+key+".png"))
		check(key+" decoded texture resolution",map.get_size()==(Vector2(1024,512) if i==0 else Vector2(4096,2048)))
		var polar: Variant=body.material.get_shader_parameter("map_polar_limit")
		var ring: Variant=body.material.get_shader_parameter("ring_outer")
		check(key+" no polar fill or artificial ring shadow",(polar==null or polar==0.) and (ring==null or ring==0.))
		check(key+" selected observation reports source limits",main.explorer_panel.body_text.text.contains("历史") and main.explorer_panel.body_text.text.contains("MESSENGER" if i==0 else "Viking"))
		check(key+" initial camera observes lit hemisphere",(stage.camera.position-body.node.position).normalized().dot(-body.node.position.normalized())>0.5)
		check(key+" camera stays outside Sun",stage.camera.position.length()>1.65)
		var before: Basis=body.node.basis
		await capture(key+"-surface")
		main.set_solar_date(main.solar_jd+10.)
		await frames()
		check(key+" map follows existing IAU rotation",not before.is_equal_approx(body.node.basis) and body.node.basis.is_equal_approx(main.Orientation.body_basis(i,main.solar_jd)))
		check(key+" existing orbital position retained",body.node.position.is_equal_approx(main.Ephemeris.display_position(i,main.solar_jd,false)))
		if i==3:
			root.size=Vector2i(900,650)
			await frames()
			await capture("mars-compact-after-date")
	# Exercise Sun clearance in both display scales; analytic perihelion bound is recorded separately.
	main.set_solar_date(main.Ephemeris.DEFAULT_JD)
	for real_distance: bool in [false,true]:
		main.set_solar_distance(real_distance)
		await frames()
		main.follow_planet(0)
		await frames()
		check("camera clearance mode "+str(real_distance),stage.camera.position.length()>(1.65*0.035 if real_distance else 1.65))
	main.follow_planet(-1)
	main.set_solar_distance(true)
	await frames()
	check("true-distance orbit view remains usable",main.solar_true_distance and stage.get_meta("solar_true_distance") and main.solar_follow==-1)
	var info: Dictionary=Science.describe("solar_system")
	check("science panel names image processing and source links",info.basis.contains("着色") and info.limit.contains("三维地形") and info.sources.size()==6)
	main.observe_scale("earth")
	if await ready_scale("earth"): check("return to Earth",main.world.current_scale_id=="earth")
	finish_rocky()
func finish_rocky() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"debug_build":OS.is_debug_build(),"native":native,"performance_test":false},"\t")+"\n")
	print("ROCKY_SURFACE_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
