extends "res://tests/integration/world_expansion_suite.gd"
const Comparison = preload("res://scripts/experience/turtle_comparison.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")
const Box = preload("res://scripts/experience/box_turtle.gd")
const Species = preload("res://scripts/experience/species_catalog.gd")
const Store = preload("res://scripts/core/world_store.gd")
var samples: Array[Dictionary] = []
var settings: Array[Dictionary] = []
var observations: Dictionary = {}
var authority: int = -1
var initial_date: float = 0.
var resources_unchanged: bool = false

func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen == DisplayServer.get_primary_screen(): continue
		if get_window().current_screen != screen:
			var wanted: Vector2i = get_window().size
			get_window().current_screen = screen
			get_window().position = DisplayServer.screen_get_usable_rect(screen).position+Vector2i(30,30)
			get_window().size = wanted
		main._measurement_screen = screen
		break
	for frame: int in range(4): await get_tree().process_frame

func unchanged_clock() -> bool:
	return main.world.get_instance_id() == authority and main.world.paused and main.world.simulation_time_s == 5. and main.world.time_scale == 2. and main.solar_jd == initial_date and main.solar_rate == 0.

func visit_ready(scale_id: String, topic: String) -> bool:
	if not await ready_stage(): return false
	await settle()
	var good: bool = main.world.current_scale_id == scale_id and str(main.explorer_panel._topic.get("id", "")) == topic and main._guide_visit.is_empty()
	check("actual visit arrives "+scale_id+" / "+topic, good)
	return good

func scientific_checkpoint() -> Dictionary:
	var value: Dictionary = main.world.checkpoint()
	var selected: Dictionary = {}
	for key: String in ["version", "model_version", "data_version", "target_fish_id", "seed", "science", "woodland_browse", "urban_runoff", "coral_symbiosis", "deadwood_decomposition", "algal_grazing", "desert_seed_transfer", "zooplankton_lesson", "city_traffic"]:
		selected[key] = value[key]
	return selected.duplicate(true)

func controls_fit() -> bool:
	var panel: Node = main.explorer_panel
	var area: Rect2 = panel.scroll.get_global_rect()
	if not panel.visible or not panel.turtle_comparison_controls.visible or main.world_guide.visible: return false
	for button: Button in panel.turtle_comparison_controls.buttons:
		if not area.encloses(button.get_global_rect()) or button.get_global_rect().size.x < 90.: return false
	return area.encloses(panel.turtle_comparison_controls.get_global_rect())

func root_now() -> Node3D:
	var topic: String = Comparison.TOPICS[0] if main.world.current_scale_id == "reef" else Comparison.TOPICS[1]
	return Comparison.root_for(main, topic)

func independent_length(root: Node3D) -> float:
	var name: String = "Carapace" if main.world.current_scale_id == "reef" else "CarapaceDome"
	var shell: MeshInstance3D = root.find_child(name, true, false) as MeshInstance3D
	var vertices: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var axis: Vector3 = root.global_basis.x.normalized()
	var low: float = INF
	var high: float = -INF
	for vertex: Vector3 in vertices:
		var coordinate: float = (shell.to_global(vertex)-root.global_position).dot(axis)
		low = minf(low, coordinate)
		high = maxf(high, coordinate)
	return high-low

func subject_fits(root: Node3D) -> bool:
	var points: PackedVector3Array = PackedVector3Array()
	if main.world.current_scale_id == "reef":
		for name: String in ["Carapace", "Head", "FlipperLSurface", "FlipperRSurface", "HindFlipperLSurface", "HindFlipperRSurface"]:
			var mesh: MeshInstance3D = root.find_child(name, true, false) as MeshInstance3D
			if mesh == null: continue
			for corner: int in range(8): points.append(mesh.to_global(mesh.get_aabb().get_endpoint(corner)))
	else:
		var shell: MeshInstance3D = root.find_child("CarapaceDome", true, false) as MeshInstance3D
		var vertices: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i: int in range(0, vertices.size(), 12): points.append(shell.to_global(vertices[i]))
		var skin: Dictionary = root.get_meta("turtle_skin")
		for key: String in Box.KEYS:
			var soles: PackedVector3Array = skin.soles[key]
			for i: int in range(0, soles.size(), 16): points.append(Box.point(root, key+"Paw", soles[i]))
		points.append(Box.point(root, "Head", Vector3(.110,.025,0)))
	var camera: Camera3D = main.coordinator.active_scene.camera
	var count: int = 0
	var good: bool = not main.world_guide.visible and main.explorer_panel.visible
	var bound: Rect2
	for point: Vector3 in points:
		var pixel: Vector2 = camera.unproject_position(point)
		bound = Rect2(pixel,Vector2.ZERO) if count == 0 else bound.expand(pixel)
		good = good and not camera.is_position_behind(point) and pixel.x > main.explorer_panel.get_global_rect().end.x+8 and pixel.x < get_window().size.x-8 and pixel.y > 85 and pixel.y < get_window().size.y-60
		count += 1
	root.set_meta("comparison_projected_bounds", {"x":bound.position.x,"y":bound.position.y,"width":bound.size.x,"height":bound.size.y,"points":count})
	return good and count > 20 and bound.size.x > 150.

func capture(label: String) -> void:
	await settle()
	var root: Node3D = root_now()
	var stage: Node = main.coordinator.active_scene
	var topic: String = str(main.explorer_panel._topic.get("id", ""))
	var length: float = Comparison.shell_length(root, "Carapace" if stage.scale_id == "reef" else "CarapaceDome")
	settings.append({"view":label,"screen_count":DisplayServer.get_screen_count(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"window_size":[get_window().size.x,get_window().size.y]})
	samples.append({"view":label,"scale":stage.scale_id,"topic":topic,"identity":root.get_meta("stable_id"),"world_time_s":main.world.simulation_time_s,"jd":main.solar_jd,"paused":main.world.paused,"time_scale":main.world.time_scale,"root_position":Store.components(root.position),"root_scale":Store.components(root.scale),"root_heading":root.rotation.y,"shell_length_m":length,"independent_vertex_length_m":independent_length(root),"camera_position":Store.components(stage.camera.position),"camera_target":Store.components(main._orbit_target),"projected_bounds":root.get_meta("comparison_projected_bounds",{}),"marks":main.learning_overlay.last_visible_marks,"comparison_visible":main.explorer_panel.turtle_comparison_controls.visible,"readout":main.explorer_panel.lesson_readout.text})
	await super.capture(label)
	write_report("running")

func write_report(status: String) -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":status,"cases":cases,"failures":failures,"captures":captures,"samples":samples,"observations":observations,"capture_window_settings":settings,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"new_persistence_or_dynamics_tested":false}, "  ")+"\n")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world239-review="): directory = argument.trim_prefix("--world239-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	main = Experience.instantiate()
	main.world.set_paused(true)
	add_child(main)
	main._measurement_screen = get_window().current_screen
	if not await ready_stage(): await finish(); return
	get_window().size = Vector2i(1280,800)
	main._audio.volume_db = -80.0
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world.set_time_scale(2.)
	main.world.simulation_time_s = 5.
	main.set_solar_rate(0.)
	await settle()
	authority = main.world.get_instance_id()
	initial_date = main.solar_jd
	var panel: Node = main.explorer_panel
	var widget: Node = panel.turtle_comparison_controls
	main._open_guide()
	main.world_guide.search.text = "龟类四肢"
	await settle()
	var actions: Dictionary = {}
	for button: Button in main.world_guide.route_buttons:
		if str(button.get_meta("guide_topic", "")) in Comparison.TOPICS: actions[str(button.get_meta("guide_topic"))] = button
	check("two real searchable guide actions reach the original turtle species",actions.size() == 2 and main.world_guide.route_buttons.size() == 93)
	if actions.size() != 2: await finish(); return
	actions[Comparison.TOPICS[0]].pressed.emit()
	if not await visit_ready("reef",Comparison.TOPICS[0]): await finish(); return
	var sea: Node3D = root_now()
	var original_pose: Transform3D = sea.transform
	var original_fin: Vector3 = sea.find_child("FlipperL",true,false).rotation
	var original_scale: Vector3 = sea.scale
	var resource_state: Dictionary = scientific_checkpoint()
	check("sea comparison follows original stable turtle and preserves the one paused clock",sea.get_meta("stable_id") == Comparison.SEA_ID and main.content_targets()[main._content_follow].node == sea and unchanged_clock())
	check("actual sea length agrees with all original shell vertices",absf(Comparison.shell_length(sea,"Carapace")-independent_length(sea)) < .00001 and independent_length(sea) > .3)
	check("wide sea limbs three marks two buttons and length readout are observable",subject_fits(sea) and main.learning_overlay.last_visible_marks == 3 and controls_fit() and panel.lesson_readout.text.contains("本模型背甲"))
	await capture("sea-limbs")
	widget.buttons[1].pressed.emit()
	if not await visit_ready("woodland",Comparison.TOPICS[1]): await finish(); return
	var land: Node3D = root_now()
	var land_pose: Transform3D = land.transform
	check("land button visits original box turtle without date pause time or authority change",land.get_meta("stable_id") == Box.STABLE_ID and main.content_targets()[main._content_follow].node == land and unchanged_clock())
	check("actual box length and original size agree with shell vertices",absf(Comparison.shell_length(land,"CarapaceDome")-.14) < .00001 and absf(Comparison.shell_length(land,"CarapaceDome")-independent_length(land)) < .00001 and land.scale == Vector3.ONE)
	check("wide land limbs two marks and paired comparison controls are clear",subject_fits(land) and main.learning_overlay.last_visible_marks == 2 and controls_fit())
	check("original woodland actors pollinators fox and life stages remain",main.coordinator.active_scene.get_meta("actors").size() == 20 and main.coordinator.active_scene.get_meta("pollinators").size() == 4 and main.coordinator.active_scene.has_meta("red_fox") and main.coordinator.active_scene.has_meta("monarch_life_stages"))
	await capture("land-limbs")
	widget.buttons[0].pressed.emit()
	if not await visit_ready("reef",Comparison.TOPICS[0]): await finish(); return
	sea = root_now()
	check("return selects original sea identity pose fin and scale at the same instant",sea.transform.is_equal_approx(original_pose) and sea.find_child("FlipperL",true,false).rotation.is_equal_approx(original_fin) and sea.scale == original_scale and unchanged_clock())
	resources_unchanged = scientific_checkpoint() == resource_state
	check("read-only comparison never resets existing scientific or local experiment state",resources_unchanged)
	check("current species button is selected and disabled while other is available",widget.buttons[0].button_pressed and widget.buttons[0].disabled and not widget.buttons[1].disabled)
	check("sources remain actual NOAA and Smithsonian species links",str(Topics.TurtleComparison.definition("reef").source) == Topics.Turtle.SPECIES_SOURCE and str(Topics.TurtleComparison.definition("woodland").source) == Box.SOURCE)
	check("returned sea subject and original labels remain clear",subject_fits(sea) and controls_fit() and main.learning_overlay.last_visible_marks == 3)
	await capture("sea-return")
	get_window().size = Vector2i(900,650)
	await settle()
	widget.buttons[1].pressed.emit()
	if not await visit_ready("woodland",Comparison.TOPICS[1]): await finish(); return
	land = root_now()
	check("compact land preserves same animal pose clock and usable two buttons",land.transform.is_equal_approx(land_pose) and unchanged_clock() and subject_fits(land) and controls_fit())
	await capture("land-compact")
	widget.buttons[0].pressed.emit()
	if not await visit_ready("reef",Comparison.TOPICS[0]): await finish(); return
	sea = root_now()
	check("compact sea preserves original size time and visible limbs controls",sea.scale == original_scale and unchanged_clock() and subject_fits(sea) and controls_fit())
	await capture("sea-compact")
	panel.markers_toggle.set_pressed_no_signal(false)
	panel.markers_toggle.toggled.emit(false)
	await settle()
	check("existing marker control hides comparison labels without changing animal",main.learning_overlay.last_visible_marks == 0 and unchanged_clock())
	panel.markers_toggle.set_pressed_no_signal(true)
	panel.markers_toggle.toggled.emit(true)
	await settle()
	check("existing marker control restores actual mesh labels",main.learning_overlay.last_visible_marks == 3)
	widget.buttons[1].pressed.emit()
	check("comparison uses the existing cancellable transition",main.coordinator.is_busy())
	main.coordinator.cancel("turtle_comparison_diagnostic")
	if not await ready_stage(): await finish(); return
	panel.show()
	await settle()
	check("cancel holds prior sea scene and clears pending visit without changing clock",main.world.current_scale_id == "reef" and main._guide_visit.is_empty() and str(panel._topic.id) == Comparison.TOPICS[0] and unchanged_clock())
	check("cancelled observation can still use original comparison controls",subject_fits(root_now()) and controls_fit())
	await capture("compare-cancel")
	get_window().size = Vector2i(1280,800)
	await settle()
	var journey: Node = main.guided_journey
	journey.restore({"version":1,"step":0,"started":false,"completed":false,"active_route":"world","world_tour":{"version":1,"step":2,"started":true,"completed":false}})
	journey.open("world")
	await settle()
	journey.lesson_button.pressed.emit()
	if not await visit_ready("reef",str(journey.WORLD_LESSONS[2].topic)): await finish(); return
	check("existing world tour lesson return remains available",journey.has_lesson_return() and journey.step == 2)
	check("comparison remains reachable from existing tour lesson",panel.select_topic(Comparison.TOPICS[0],true))
	await settle()
	widget.buttons[1].pressed.emit()
	if not await visit_ready("woodland",Comparison.TOPICS[1]): await finish(); return
	check("cross habitat comparison retains the original tour return and station",journey.has_lesson_return() and journey.step == 2 and panel.journey_return_button.visible and unchanged_clock())
	check("tour return button and new land controls are usable",controls_fit() and panel.scroll.get_global_rect().encloses(panel.journey_return_button.get_global_rect()) and subject_fits(root_now()))
	await capture("tour-land")
	panel.journey_return_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	await settle()
	check("real return restores original third tour station without advancing progress",journey.visible and journey.step == 2 and main.world.current_scale_id == "reef" and not journey.has_lesson_return() and unchanged_clock())
	journey.hide()
	panel.show()
	await settle()
	check("original standalone turtle lesson remains selectable",panel.select_topic("turtle",true))
	await settle()
	check("original lesson hides comparison controls and retains original turtle marks",not widget.visible and main.learning_overlay.last_visible_marks == 3 and subject_fits(root_now()) and unchanged_clock())
	await capture("original-turtle")
	check("original atlas species count and named entry identities remain",Species.ENTRIES.size() == 41 and Species.ENTRIES.filter(func(entry: Dictionary) -> bool: return str(entry.id) in ["mydas","carolina"]).size() == 2)
	var continued: Node3D = root_now()
	var before: Vector3 = continued.position
	main.world.set_paused(false)
	await get_tree().create_timer(.7).timeout
	main.world.set_paused(true)
	await settle()
	check("explicit continuation advances original host clock and animal together",main.world.simulation_time_s > 5. and main.world.simulation_time_s < 8. and not continued.position.is_equal_approx(before) and main.world.get_instance_id() == authority and main.solar_jd == initial_date)
	check("diagnostic resource input and user save boundaries hold",Engine.max_fps == 5 and ProjectSettings.get_setting("application/run/max_fps") == 30 and ProjectSettings.get_setting("threading/worker_pool/max_threads") == 2 and main._render_ratio == .75 and not main._persistence_enabled and get_window().unfocusable and get_viewport().gui_disable_input)
	observations = {"samples":samples,"capture_window_settings":settings,"named_species":Species.ENTRIES.size(),"guide_routes":main.world_guide.route_buttons.size(),"paused":main.world.paused,"time_scale":main.world.time_scale,"jd":main.solar_jd,"world_time_s":main.world.simulation_time_s,"max_fps":Engine.max_fps,"foreground_fps":30,"worker_pool_threads":2,"render_ratio":main._render_ratio,"audio_volume_db":main._audio.volume_db,"one_original_world":main.world.get_instance_id() == authority,"original_resource_state_unchanged_during_comparison":resources_unchanged,"user_save_accessed":false,"save_schema_changed":false}
	await finish()

func finish() -> void:
	write_report("completed")
	print("TURTLE_COMPARISON_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	main._quit(0 if failures.is_empty() else 1)
