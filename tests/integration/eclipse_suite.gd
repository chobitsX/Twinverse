extends "res://tests/integration/ecology_map_suite.gd"
const Eclipse = preload("res://scripts/core/eclipse_geometry.gd")
var shadow_samples: Array[Dictionary]=[]
func frames() -> void:
	for frame: int in range(4): await get_tree().process_frame
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world141-check="): directory=arg.trim_prefix("--world141-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,800);root.unfocusable=true
	main=Experience.instantiate();root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("earth_moon"): finish_eclipse();return
	main._reduced_motion=true;main.world.set_paused(true);main.set_solar_rate(0.0);main.world_guide.hide()
	main.explorer_panel.show();await frames()
	check("existing lunar lesson exposes eclipse controls",main.explorer_panel.select_topic("lunar_phases"))
	await frames()
	var world_before: Dictionary=main.world.checkpoint()
	var panel: Node=main.explorer_panel
	panel.eclipse_lunar_button.pressed.emit();await frames()
	var stage: Node=main.coordinator.active_scene
	var data: Dictionary=stage.get_meta("lunar")
	check("lunar example sets shared date and Earth-facing camera",main.solar_jd==Eclipse.LUNAR_EXAMPLE_JD and main.lunar_observation_view=="earth")
	check("shader uses true Moon position despite compressed orbit",Vector3(data.moon.material_override.get_shader_parameter("eclipse_body_km")).distance_to(Eclipse.sample(main.solar_jd).moon_km)<.1 and data.moon.position.length()<10.)
	await capture("lunar-total")
	if native:
		var sample: Dictionary=shadow_comparison(data.moon.position,.17)
		shadow_samples.append(sample)
		check("lunar eclipse actually removes direct light in GPU image",sample.on<sample.off*.25 and sample.off>.05)
	main.set_solar_distance(true);await frames()
	check("physical shadow geometry unchanged by display distance toggle",data.moon.position.length()>50. and Vector3(data.moon.material_override.get_shader_parameter("eclipse_body_km")).distance_to(Eclipse.sample(main.solar_jd).moon_km)<.1)
	if native:
		var sample: Dictionary=shadow_comparison(data.moon.position,.17)
		shadow_samples.append(sample)
		check("true-distance close Moon remains eclipsed",sample.on<sample.off*.25)
	main.set_solar_distance(false)
	panel.eclipse_back_button.pressed.emit();panel.eclipse_back_button.pressed.emit();await frames()
	check("half-hour buttons change astronomical date only",absf(main.solar_jd-(Eclipse.LUNAR_EXAMPLE_JD-1./24.))<1.e-8 and main.world.checkpoint()==world_before)
	await capture("lunar-partial")
	panel.eclipse_solar_button.pressed.emit();await frames()
	check("solar example frames illuminated Earth and its real shadow",main.solar_jd==Eclipse.SOLAR_EXAMPLE_JD and main.lunar_observation_view=="shadow" and stage.camera.position.length()<5.)
	var state: Dictionary=stage.get_meta("eclipse_geometry")
	var at: Vector3=Eclipse.solar_axis_surface(state)/Eclipse.Orbit.RADII_KM[2]
	if native:
		var sample: Dictionary=shadow_comparison(at,.04)
		shadow_samples.append(sample)
		check("solar shadow is present in actual Earth/cloud/atmosphere image",sample.on<sample.off*.65 and sample.off>.025)
	await capture("solar-shadow")
	var old_moon: Vector3=data.moon.position
	panel.eclipse_forward_button.pressed.emit();await frames()
	check("date step updates Moon, sunlight uniforms and shadow viewpoint",data.moon.position.distance_to(old_moon)>.01 and Vector3(data.earth.material_override.get_shader_parameter("eclipse_blocker_km")).distance_to(Eclipse.sample(main.solar_jd).moon_km)<.1 and main.lunar_observation_view=="shadow")
	main.set_solar_distance(true);await frames()
	check("solar close viewpoint survives real-distance toggle",main.lunar_observation_view=="shadow" and stage.camera.position.length()<5. and data.moon.position.length()>50.)
	main.set_solar_distance(false)
	root.size=Vector2i(900,650);await frames()
	panel.scroll.ensure_control_visible(panel.eclipse_forward_button);await frames()
	check("compact lesson scroll exposes example and time controls",panel.scroll.get_global_rect().encloses(panel.eclipse_forward_button.get_global_rect()))
	await capture("eclipse-compact")
	panel.lunar_orbit_button.pressed.emit();await frames()
	check("orbit view and trajectory can be restored",main.lunar_observation_view=="orbit" and data.orbit.visible)
	check("eclipse controls keep sole world authority",main.world.checkpoint()==world_before)
	check("native resource limit remains active",not native or Engine.max_fps==5)
	var date_before_return: float=main.solar_jd
	main.start_guide_visit("earth","")
	if not await ready_scale("earth"): finish_eclipse();return
	var earth_has_no_lunar_override: bool=true
	for material: ShaderMaterial in main.coordinator.active_scene.materials:
		if material.get_shader_parameter("eclipse_enabled")==true: earth_has_no_lunar_override=false
	check("other Earth view does not inherit lunar-stage shadow coordinates",earth_has_no_lunar_override)
	main.start_guide_visit("earth_moon","lunar_phases")
	if not await ready_scale("earth_moon"): finish_eclipse();return
	await frames()
	var returned_world: Dictionary=main.world.checkpoint()
	var same_models: bool=true
	for key: String in world_before:
		# Scene arrivals legitimately add observation-history events.
		if key!="local_habitat": same_models=same_models and returned_world[key]==world_before[key]
	check("return retains shared date, models and eclipse uniforms",main.solar_jd==date_before_return and main.coordinator.active_scene.get_meta("eclipse_geometry").valid and same_models)
	finish_eclipse()
func shadow_comparison(at: Vector3, radius: float) -> Dictionary:
	var stage: Node=main.coordinator.active_scene
	RenderingServer.force_draw(false,0.0)
	var a: float=mean_light(stage,at,radius)
	var materials: Array[ShaderMaterial]=[]
	for material: ShaderMaterial in stage.materials:
		if material.get_shader_parameter("eclipse_enabled")==true:
			materials.append(material);material.set_shader_parameter("eclipse_enabled",false)
	RenderingServer.force_draw(false,0.0)
	var b: float=mean_light(stage,at,radius)
	for material: ShaderMaterial in materials: material.set_shader_parameter("eclipse_enabled",true)
	RenderingServer.force_draw(false,0.0)
	return {"jd":main.solar_jd,"on":a,"off":b,"display_true_distance":main.solar_true_distance}
func mean_light(stage: Node, at: Vector3, radius: float) -> float:
	var image: Image=stage.viewport.get_texture().get_image()
	var center: Vector2=stage.camera.unproject_position(at)
	var pixels: float=stage.camera.unproject_position(at+stage.camera.basis.x*radius).distance_to(center)
	var count: int=0;var light: float=0.0
	for y: int in range(maxi(0,int(center.y-pixels)),mini(image.get_height(),int(center.y+pixels))):
		for x: int in range(maxi(0,int(center.x-pixels)),mini(image.get_width(),int(center.x+pixels))):
			if Vector2(x,y).distance_to(center)>pixels:continue
			var colour: Color=image.get_pixel(x,y);light+=colour.get_luminance();count+=1
	return light/maxi(count,1)
func finish_eclipse() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"samples":shadow_samples,"native":native,"debug_build":OS.is_debug_build(),"performance_test":false},"\t")+"\n")
	print("ECLIPSE_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
