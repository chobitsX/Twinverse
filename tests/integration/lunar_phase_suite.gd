extends "res://tests/integration/observation_framing_suite.gd"
const Phase = preload("res://scripts/core/lunar_phase.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world111-check="): directory=argument.trim_prefix("--world111-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless" and DisplayServer.get_screen_count()==1:
		main._measurement_screen=get_window().current_screen
		get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	if DisplayServer.get_name()!="headless":
		var stable: int = Time.get_ticks_msec()
		var deadline: int = stable+10000
		while Time.get_ticks_msec()-stable<2000 and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable=Time.get_ticks_msec()
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	get_window().size=Vector2i(1280,720)
	if not await arrive("earth_moon"):
		await finish()
		return
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.set_solar_distance(false)
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="lunar_phases": action=button
	check("twenty-eight routes include actual lunar lesson",action!=null and main.world_guide.route_buttons.size()==28)
	if action!=null: action.pressed.emit()
	await settle()
	var panel: Node = main.explorer_panel
	var stage: Node = main.coordinator.active_scene
	var lunar: Dictionary = stage.get_meta("lunar")
	check("guide opens same dated Earth Moon scene and overview",panel._topic.get("id","")=="lunar_phases" and main.lunar_observation_view=="orbit" and main.learning_overlay.last_visible_marks==3 and main.content_targets().size()==2)
	check("source and all limitations are available",Reference.allows_url("earth_moon",Phase.SOURCE) and panel.lesson_text.text.contains("不是实测月相时刻") and panel.lesson_text.text.contains("光学/物理天平动"))
	var original: Dictionary = main.world.checkpoint()
	panel.lunar_phase_buttons[0].pressed.emit()
	await settle()
	panel.lunar_earth_button.pressed.emit()
	await settle()
	check("new phase comes from shared mean orbit with unchanged world",main.world.checkpoint()==original and Orientation.illumination(main.solar_jd)<.003 and aligned(lunar.moon))
	check("same real Moon with LROC map fits beside the explanation",lunar.moon.material_override.get_shader_parameter("moon_map").get_width()==2048 and subject_visible(lunar.moon))
	var dark: Dictionary = await light_sample(lunar.moon)
	await capture("lunar-new-earth-direction")
	panel.lunar_phase_buttons[1].pressed.emit()
	await settle()
	var first: Dictionary = await light_sample(lunar.moon)
	check("first quarter changes actual lighting while keeping Earth direction",absf(Orientation.illumination(main.solar_jd)-.5)<.001 and aligned(lunar.moon) and first.mean>dark.mean*2 and absf(first.left-first.right)>.02 and absf(first.lit_fraction-.5)<.06)
	await capture("lunar-first-quarter")
	panel.lunar_phase_buttons[2].pressed.emit()
	await settle()
	var full: Dictionary = await light_sample(lunar.moon)
	check("full Moon renders a visibly brighter same-face disk",Orientation.illumination(main.solar_jd)>.997 and full.mean>dark.mean*5 and full.mean>first.mean and aligned(lunar.moon))
	await capture("lunar-full-moon")
	var time: float = main.world.simulation_time_s
	var date: float = main.solar_jd
	var pose: Transform3D = lunar.moon.transform
	await settle()
	check("paused date freezes actual geometry and pose",main.world.simulation_time_s==time and main.solar_jd==date and lunar.moon.transform.is_equal_approx(pose))
	panel.lunar_phase_buttons[3].pressed.emit()
	await settle()
	var last: Dictionary = await light_sample(lunar.moon)
	check("opposite quarter lights opposite half in actual rendering",absf(Orientation.illumination(main.solar_jd)-.5)<.001 and absf(last.lit_fraction-.5)<.06 and (first.left-first.right)*(last.left-last.right)<-.0004 and aligned(lunar.moon))
	panel.lunar_orbit_button.pressed.emit()
	await settle()
	check("overview keeps physical bodies orbit and explanatory directions visible",subject_visible(lunar.earth) and subject_visible(lunar.moon) and subject_visible(lunar.orbit) and main.learning_overlay.last_visible_marks==3)
	await capture("lunar-orbit-context")
	var compressed_distance: float = lunar.moon.position.length()
	main.set_solar_distance(true)
	await settle()
	check("real distance changes only display geometry and retains lesson",main.learning_overlay.topic=="lunar_phases" and main.lunar_observation_view=="orbit" and lunar.moon.position.length()>compressed_distance*7 and subject_visible(lunar.earth) and subject_visible(lunar.moon))
	main.set_solar_distance(false)
	panel.lunar_earth_button.pressed.emit()
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact view keeps Moon and all lesson actions visible",subject_visible(lunar.moon) and panel.lunar_controls.get_global_rect().end.y<panel.get_global_rect().end.y-12 and main.learning_overlay.last_visible_marks==1)
	await capture("lunar-last-quarter-compact")
	var zoom: InputEventMouseButton = InputEventMouseButton.new()
	zoom.button_index=MOUSE_BUTTON_WHEEL_UP
	zoom.pressed=true
	var size: float = stage.camera.size
	main._unhandled_input(zoom)
	await settle()
	check("zoom preserves Earth line and does not enter the Moon",aligned(lunar.moon) and stage.camera.size<size and stage.camera.size>=.70 and stage.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.button_mask=MOUSE_BUTTON_MASK_RIGHT
	drag.relative=Vector2(55,-12)
	main._unhandled_input(drag)
	await settle()
	check("orbit input releases locked direction and describes free view",main.lunar_observation_view=="free" and panel.lesson_readout.text.contains("自由环绕") and not aligned(lunar.moon))
	panel.lunar_earth_button.pressed.emit()
	await settle()
	check("explicit view action returns to same face",aligned(lunar.moon))
	main._remember_view()
	check("existing saved view records date and camera without new world state",main.WorldStore.vector(main._views.earth_moon.target).distance_to(lunar.moon.position)<.00001 and main._views.earth_moon.astronomy.jd==main.solar_jd and main.world.checkpoint()==original)
	var equivalent_distance: float = stage.camera.size/(2.0*tan(deg_to_rad(stage.camera.fov*.5)))
	check("saved perspective pose keeps the orthographic field of view",absf(main.WorldStore.vector(main._views.earth_moon.position).distance_to(lunar.moon.position)-equivalent_distance)<.00001)
	main.navigate_to("earth")
	main.coordinator.cancel("lunar_close_projection_check")
	if not await ready_stage():
		await finish()
		return
	check("cancelled exit returns with a consistent free perspective mode",main.world.current_scale_id=="earth_moon" and main.lunar_observation_view=="free" and stage.camera.projection==Camera3D.PROJECTION_PERSPECTIVE)
	panel.lunar_earth_button.pressed.emit()
	await settle()
	date=main.solar_jd
	if not await arrive("earth") or not await arrive("earth_moon"):
		await finish()
		return
	check("leaving and returning retains observer date and world state",main.solar_jd==date and main.world.checkpoint().science==original.science and main.world.simulation_time_s==time)
	FileAccess.open(directory.path_join("light-samples.json"),FileAccess.WRITE).store_string(JSON.stringify({"new":dark,"first":first,"full":full,"last":last},"\t")+"\n")
	await finish()

func aligned(moon: Node3D) -> bool:
	var camera: Camera3D = main.coordinator.active_scene.camera
	return camera.basis.z.dot(-moon.position.normalized())>.99999

func light_sample(moon: MeshInstance3D) -> Dictionary:
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var stage: Node = main.coordinator.active_scene
	var camera: Camera3D = stage.camera
	var picture: Image = stage.viewport.get_texture().get_image()
	var center: Vector2 = camera.unproject_position(moon.position)
	var radius: float = camera.unproject_position(moon.position+camera.basis.x*.273).distance_to(center)*.68
	var sums: Array[float] = [0.,0.]
	var counts: Array[int] = [0,0]
	var lit: int = 0
	for y: int in range(maxi(0,int(center.y-radius)),mini(picture.get_height(),int(center.y+radius))):
		for x: int in range(maxi(0,int(center.x-radius)),mini(picture.get_width(),int(center.x+radius))):
			if Vector2(x,y).distance_to(center)>radius: continue
			var colour: Color = picture.get_pixel(x,y)
			var side: int = 0 if x<center.x else 1
			var value: float = .2126*colour.r+.7152*colour.g+.0722*colour.b
			sums[side]+=value
			if value>.025: lit+=1
			counts[side]+=1
	return {"left":sums[0]/maxi(1,counts[0]),"right":sums[1]/maxi(1,counts[1]),"mean":(sums[0]+sums[1])/maxi(1,counts[0]+counts[1]),"pixels":counts[0]+counts[1],"lit_fraction":float(lit)/maxi(1,counts[0]+counts[1])}
