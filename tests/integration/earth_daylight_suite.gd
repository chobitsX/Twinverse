extends "res://tests/integration/world_expansion_suite.gd"
const Daylight = preload("res://scripts/experience/earth_daylight.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Seasons = preload("res://scripts/experience/season_observation.gd")
const Store = preload("res://scripts/core/world_store.gd")
const Species = preload("res://scripts/experience/species_catalog.gd")
var samples: Array[Dictionary] = []
var settings: Array[Dictionary] = []
var observations: Dictionary = {}
var band_metrics: Array[Dictionary] = []

func color_error(actual: Color, expected: Color) -> float:
	return maxf(maxf(absf(actual.r-expected.r),absf(actual.g-expected.g)),maxf(absf(actual.b-expected.b),absf(actual.a-expected.a)))

func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen==DisplayServer.get_primary_screen(): continue
		if get_window().current_screen!=screen:
			var wanted: Vector2i = get_window().size
			get_window().current_screen = screen
			get_window().position = DisplayServer.screen_get_usable_rect(screen).position+Vector2i(30,30)
			get_window().size = wanted
		main._measurement_screen = screen
		break
	for frame: int in range(4): await get_tree().process_frame

func capture(label: String) -> void:
	await settle()
	var stage: Node = main.coordinator.active_scene
	settings.append({"view":label,"screen_count":DisplayServer.get_screen_count(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"window_size":[get_window().size.x,get_window().size.y]})
	samples.append({"view":label,"jd":main.solar_jd,"world_time_s":main.world.simulation_time_s,"rows":Daylight.rows(main.solar_jd),"sun":Store.components(Orientation.sun_ecef(main.solar_jd)),"camera_position":Store.components(stage.camera.position),"camera_target":Store.components(main._orbit_target),"h_offset":stage.camera.h_offset,"markers":main.learning_overlay.last_visible_marks,"actual_bands":band_metrics.duplicate(true)})
	await super.capture(label)

func controls_fit() -> bool:
	var panel: Node = main.explorer_panel
	var controls: Node = panel.earth_daylight_controls
	var clip: Rect2 = panel.scroll.get_global_rect().grow(.5)
	var clear: bool = controls.date_buttons.size()==4
	for control: Control in [panel.topic_picker,controls.date_label,controls.table,controls.exit_button]:
		clear=clear and control.is_visible_in_tree() and clip.encloses(control.get_global_rect())
	for button: Button in controls.date_buttons:
		clear=clear and button.is_visible_in_tree() and clip.encloses(button.get_global_rect())
	return clear

func globe_fits() -> bool:
	var camera: Camera3D = main.coordinator.active_scene.camera
	var left: float = main.explorer_panel.get_global_rect().end.x+10.0
	var safe: Rect2 = Rect2(Vector2(left,112),Vector2(get_window().size.x-left-20,get_window().size.y-230))
	for latitude: int in range(-90,91,10):
		for longitude: int in range(0,360,10):
			var point: Vector3 = Daylight.Sites.normal(latitude,longitude)*Daylight.RADIUS
			if camera.is_position_behind(point) or not safe.has_point(camera.unproject_position(point)): return false
	return true

func actual_bands_match() -> bool:
	band_metrics=[]
	var data: Dictionary = main.coordinator.active_scene.get_meta("earth_daylight")
	var sun: Vector3 = Orientation.sun_ecef(main.solar_jd)
	var clear: bool = data.bands.size()==5 and data.sun.is_equal_approx(sun) and data.jd==main.solar_jd
	for band: MeshInstance3D in data.bands:
		var vertices: PackedVector3Array = band.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = band.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		clear=clear and vertices.size()==Daylight.SEGMENTS*6 and colors.size()==vertices.size()
		var latitude: float = band.get_meta("latitude")
		var day_vertices: int = 0
		var worst_color: float = 0.0
		var worst_radius: float = 0.0
		for segment: int in range(Daylight.SEGMENTS):
			var midpoint: float = (float(segment)+.5)*360.0/Daylight.SEGMENTS
			var expected: Color = Daylight.DAY if Daylight.Sites.normal(latitude,midpoint).dot(sun)>=0.0 else Daylight.NIGHT
			for corner: int in range(6):
				var at: int = segment*6+corner
				worst_color=maxf(worst_color,color_error(colors[at],expected))
				worst_radius=maxf(worst_radius,absf(vertices[at].length()-Daylight.RADIUS))
				clear=clear and vertices[at].is_finite() and absf(vertices[at].length()-Daylight.RADIUS)<.00001 and color_error(colors[at],expected)<1.0/255.0+.0001
				if color_error(colors[at],Daylight.DAY)<1.0/255.0+.0001: day_vertices+=1
		var arc_hours: float = 24.0*day_vertices/vertices.size()
		clear=clear and absf(arc_hours-Orientation.latitude_daylight_hours(latitude,main.solar_jd))<.134
		var material: StandardMaterial3D = band.material_override as StandardMaterial3D
		clear=clear and material.vertex_color_use_as_albedo and material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED and not material.no_depth_test
		band_metrics.append({"latitude":latitude,"vertices":vertices.size(),"first_color":[colors[0].r,colors[0].g,colors[0].b,colors[0].a],"max_color_error":worst_color,"max_radius_error":worst_radius,"lit_arc_hours":arc_hours,"analytic_hours":Orientation.latitude_daylight_hours(latitude,main.solar_jd)})
	return clear

func authority_without_history(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	for key: String in ["events","samples","visits"]: result.local_habitat.erase(key)
	return result

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world237-review="): directory=argument.trim_prefix("--world237-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	main=Experience.instantiate()
	main.world.set_paused(true)
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage(): await finish(); return
	get_window().size=Vector2i(1280,800)
	main._audio.volume_db=-80.0
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world.simulation_time_s=12.0
	main.world.set_time_scale(2.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.set_solar_rate(1.0)
	main.world_guide.hide()
	main.explorer_panel.show()
	await settle()
	var stage: Node=main.coordinator.active_scene
	var panel: Node=main.explorer_panel
	var data: Dictionary=stage.get_meta("earth_daylight",{})
	check("original Earth initially has hidden five-band lesson and normal entrances",not data.is_empty() and not data.active and not data.root.visible and panel.earth_box.visible)
	var before: Dictionary=main.world.checkpoint()
	var authority: int=main.world.get_instance_id()
	check("same Earth theme is reachable from existing Explorer",panel.select_topic("earth_daylight"))
	await settle()
	check("entry does not mutate date playback or world checkpoint",main.solar_jd==Ephemeris.DEFAULT_JD and main.solar_rate==1.0 and main.world.checkpoint()==before)
	check("one original globe and actual five parallels use the same sunlight",data.active and data.root.visible and actual_bands_match() and stage.world_root.find_children("Earth_NASA_2004_01","MeshInstance3D",true,false).size()==1)
	var surface: ShaderMaterial=stage.materials[0]
	check("globe shader and displayed arcs share Earth-fixed sun",surface.get_shader_parameter("sun_direction").is_equal_approx(data.sun))
	check("wide controls whole globe and all five projected labels fit",controls_fit() and globe_fits() and main.learning_overlay.last_visible_marks==5 and not panel.earth_box.visible)
	var first_mesh: int=data.bands[0].mesh.get_instance_id()
	await settle()
	check("paused date reuses its actual geometry rather than rebuilding every frame",data.bands[0].mesh.get_instance_id()==first_mesh and main.world.simulation_time_s==12.0)
	for index: int in range(4):
		panel.earth_daylight_controls.date_buttons[index].pressed.emit()
		await settle()
		var rows: Array[Dictionary]=Daylight.rows(main.solar_jd)
		check("reference %d explicitly changes only shared date and stops date rate" % index,main.solar_jd==Seasons.preset(index,"earth") and main.solar_rate==0.0 and main.world.checkpoint()==before)
		check("reference %d actual coloured mesh and paired table agree" % index,actual_bands_match() and panel.earth_daylight_controls.values[2].text==Daylight.hours_text(float(rows[1].north)) and panel.earth_daylight_controls.values[5].text==Daylight.hours_text(float(rows[2].south)))
		await capture(["march-reference","june-reference","september-reference","december-reference"][index])
	panel.earth_daylight_controls.date_buttons[1].pressed.emit()
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact four dates table exit whole Earth and five labels remain usable",controls_fit() and globe_fits() and main.learning_overlay.last_visible_marks==5)
	await capture("june-compact")
	panel.markers_toggle.button_pressed=false
	await settle()
	check("real observation toggle hides bands and labels while table date and authority stay",not data.root.visible and main.learning_overlay.last_visible_marks==0 and panel.earth_daylight_controls.visible and main.world.checkpoint()==before)
	panel.markers_toggle.button_pressed=true
	await settle()
	check("real toggle restores the same five-band mesh",data.root.visible and actual_bands_match())
	stage.set_pose(stage.camera.position.rotated(Vector3.UP,.3)*1.1,Vector3.ZERO)
	main._reset_observation_view()
	await settle()
	check("normal observation reset restores lesson framing without date or time changes",globe_fits() and main.solar_jd==Seasons.preset(1,"earth") and main.world.checkpoint()==before)
	panel.select_earth_site(1)
	panel.earth_daylight_controls.exit_button.pressed.emit()
	await settle()
	var locator: Dictionary=stage.get_meta("earth_locator")
	check("exit returns original synthetic latitude and Earth entrances",not data.active and not data.root.visible and panel.earth_box.visible and locator.band.visible and not locator.marker.visible and locator.selection=="woodland" and main.learning_overlay.topic.is_empty())
	get_window().size=Vector2i(1280,800)
	await capture("earth-entrances")
	var route: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="earth_daylight": route=button
	check("one new guide route and forty species preserve existing content",route!=null and main.world_guide.route_buttons.size()==89 and Species.ENTRIES.size()==40)
	if route!=null: route.pressed.emit()
	await settle()
	check("actual guide action reopens same Earth lesson without setting a reference date",main.learning_overlay.topic=="earth_daylight" and data.active and main.solar_jd==Seasons.preset(1,"earth") and main.world.checkpoint()==before)
	main._remember_view()
	var view: Dictionary=main._views.earth
	check("original observer schema stores shared date and geographic camera only",view.has("astronomy") and float(view.astronomy.jd)==main.solar_jd and Store.vector(view.position).is_equal_approx(stage.camera.position) and Store.vector(view.target).is_equal_approx(main._orbit_target) and not view.has("earth_daylight"))
	var saved_camera: Vector3=stage.camera.position
	if not await arrive("woodland"): await finish(); return
	await settle()
	check("ordinary ground branch keeps existing four-stage monarch and no global bands",main.coordinator.active_scene.has_meta("monarch_life_stages") and main.coordinator.active_scene.get_meta("pollinators").size()==4 and main.world.get_instance_id()==authority)
	if not await arrive("earth"): await finish(); return
	await settle()
	stage=main.coordinator.active_scene
	check("Earth return restores original observer pose and same date without new lesson state",stage.camera.position.is_equal_approx(saved_camera) and not stage.get_meta("earth_daylight").active and main.solar_jd==Seasons.preset(1,"earth") and main.world.get_instance_id()==authority)
	check("all world models and paused seconds survive ordinary branch navigation",authority_without_history(main.world.checkpoint())==authority_without_history(before) and main.world.simulation_time_s==12.0 and main.world.paused and main.world.time_scale==2.0)
	check("returned lesson can reopen with same original scientific date",panel.select_topic("earth_daylight"))
	await capture("earth-return")
	check("resource budget and diagnostic-only input save boundaries hold",Engine.max_fps==5 and ProjectSettings.get_setting("application/run/max_fps")==30 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2 and main._render_ratio==.75 and not main._persistence_enabled and get_window().unfocusable and get_viewport().gui_disable_input)
	observations={"samples":samples,"capture_window_settings":settings,"world_time_s":main.world.simulation_time_s,"jd":main.solar_jd,"solar_rate":main.solar_rate,"paused":main.world.paused,"time_scale":main.world.time_scale,"guide_routes":89,"named_species":40,"max_fps":Engine.max_fps,"foreground_fps":30,"worker_pool_threads":2,"render_ratio":main._render_ratio,"audio_volume_db":main._audio.volume_db,"user_save_accessed":false,"save_schema_changed":false}
	await finish()

func finish() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false},"\t")+"\n")
	print("EARTH_DAYLIGHT237_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
