extends "res://tests/integration/life_assets_suite.gd"
## A short check of changed content and controls, on the actual native renderer.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world87-check="): directory = argument.trim_prefix("--world87-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if not await ready_stage():
		await finish()
		return
	if DisplayServer.get_name()!="headless":
		var stable_since: int = Time.get_ticks_msec()
		var limit: int = stable_since+10000
		while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<limit:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since = Time.get_ticks_msec()
	main._reduced_motion = true
	main.world.set_paused(true)
	if not await arrive("woodland"):
		await finish()
		return
	main.explorer_panel.hide()
	await at_time(3.0)
	await capture("woodland-overview")
	var stage: Node = main.coordinator.active_scene
	var bird: Node3D = stage.get_meta("actors")[8].node
	check("robin has feathered joint hierarchy",bird.get_meta("life_joints",{}).size()==6 and bird.find_child("Primary",true,false)!=null)
	main.follow_content(2)
	await capture("robin-ground")
	check("small bird has its own follow height",absf(main._orbit_target.y-bird.position.y-.10)<.001)
	await at_time(33.0)
	check("bird flies above terrain",bird.position.y-stage.builder._height(bird.position.x,bird.position.z)>2 and str(bird.get_meta("activity")).contains("飞行"))
	await capture("robin-flight")
	var old_wing: Vector3 = bird.get_meta("life_joints").BirdWingL.rotation
	for frame: int in range(5): await get_tree().process_frame
	check("pause stops wings",bird.get_meta("life_joints").BirdWingL.rotation.distance_to(old_wing)<.0001)
	main.explorer_panel.show()
	await get_tree().process_frame
	check("bird source available",main.explorer_panel.species_source.visible and main.explorer_panel._species_url.contains("American_Robin"))
	await at_time(47.0)
	check("bird lands",bird.position.y-stage.builder._height(bird.position.x,bird.position.z)<.015)
	main.explorer_panel.hide()
	var return_bird: Vector3 = bird.position
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	check("bird returns at same world time",main.coordinator.active_scene.get_meta("actors")[8].node.position.distance_to(return_bird)<.001)
	if not await arrive("city"):
		await finish()
		return
	stage = main.coordinator.active_scene
	await at_time(9.0)
	await capture("city-overview")
	var types: Dictionary = stage.get_meta("building_counts",{})
	check("three built architectural types",types.get("shops",0)>0 and types.get("homes",0)>0 and types.get("offices",0)>0)
	check("urban observation targets",main.content_targets().size()==4 and stage.get_meta("street_furniture",{}).get("benches",0)==8)
	main.follow_content(3)
	await capture("street-shops")
	main.follow_content(4)
	await capture("residential-roof")
	main.follow_content(2)
	await at_time(39.0)
	await capture("car-waiting")
	var car: Node3D = stage.get_meta("actors")[28].node
	check("car has four actual wheels",car.get_meta("wheels",[]).size()==4)
	check("waiting car behind crossing",car.position.x+2.12 < -12.9)
	var old_car: Vector3 = car.position
	var old_wheel: float = car.get_meta("wheels")[0].rotation.z
	await at_time(42.0)
	check("waiting car and wheels stop",car.position.distance_to(old_car)<.001 and absf(car.get_meta("wheels")[0].rotation.z-old_wheel)<.001)
	await at_time(49.0)
	check("green phase moves car and wheels",car.position.distance_to(old_car)>1 and absf(car.get_meta("wheels")[0].rotation.z-old_wheel)>.1)
	main.follow_content(1)
	await capture("person-park")
	main._reset_camera()
	main.ground_light_preview = true
	main.set_solar_date(Ephemeris.DEFAULT_JD+.33)
	await get_tree().process_frame
	await capture("city-daylight")
	for fraction: float in [0.0,.25,.5,.75]:
		if stage.builder.Orientation.local_sun(Ephemeris.DEFAULT_JD+fraction,35.0,120.0).y < -.3:
			main.set_solar_date(Ephemeris.DEFAULT_JD+fraction)
			break
	await get_tree().process_frame
	await get_tree().process_frame
	check("night lighting responds to observer date",float(stage.get_meta("sun_elevation"))<0 and stage.get_meta("night_lamps")[0].light.light_energy>1.0)
	await capture("city-night")
	main.ground_light_preview = false
	if not await arrive("reef"):
		await finish()
		return
	stage = main.coordinator.active_scene
	await at_time(3.0)
	main.follow_content(3)
	await capture("school-volume")
	main.follow_content(5)
	await capture("bluespotted-ray")
	var ray: Dictionary = stage.get_meta("marine_actors")[43]
	check("ray is named and has source",ray.source_url.ends_with("/2030") and str(ray.label).contains("Taeniura"))
	check("continuous ray disc uses wave shader",ray.node.find_child("RayDisc",true,false)!=null and ray.meshes.size()>0 and ray.meshes[0].get_surface_override_material(0) is ShaderMaterial)
	check("ray clear of sampled sand",ray.node.position.y-stage.builder._terrain_height(stage,ray.node.position.x,ray.node.position.z)>.075)
	var old_ray: Vector3 = ray.node.position
	var old_phase: float = ray.meshes[0].get_instance_shader_parameter("swim_phase")
	for frame: int in range(5): await get_tree().process_frame
	check("pause stops ray path and fin wave",ray.node.position.distance_to(old_ray)<.0001 and is_equal_approx(ray.meshes[0].get_instance_shader_parameter("swim_phase"),old_phase))
	await at_time(4.0)
	check("world time advances ray path and wave",ray.node.position.distance_to(old_ray)>.015 and absf(ray.meshes[0].get_instance_shader_parameter("swim_phase")-old_phase)>1.0)
	main.explorer_panel.show()
	await get_tree().process_frame
	check("ray source link visible",main.explorer_panel.species_source.visible and main.explorer_panel._species_url.ends_with("/2030"))
	await capture("ray-observer")
	await finish()
