extends "res://tests/integration/world_expansion_suite.gd"

const Polar = preload("res://scripts/experience/polar_builder.gd")
const Seasons = preload("res://scripts/experience/season_observation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")
const Krill = preload("res://scripts/experience/polar_krill.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")
const Relations = preload("res://scripts/experience/ecology_relations.gd")
var krill_observations: Dictionary = {}

## One bounded navigation, content and actual-frame check; no performance sampling.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world197-review="):
			directory = argument.trim_prefix("--world197-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless":
		main._measurement_screen = get_window().current_screen
		get_window().unfocusable = true
	get_window().size = Vector2i(1280, 800)
	get_tree().create_timer(75.0).timeout.connect(func() -> void:
		push_error("Polar coast short check exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await arrive("earth"):
		await finish()
		return
	var entries: Dictionary = main.earth_entry_panel.buttons
	check("Earth landing includes fifth synthetic polar choice",
		entries.size() == 5 and entries.has("polar") and entries.polar.text.contains("合成参考"))
	await capture("earth-polar-entry")
	(entries.polar as Button).pressed.emit()
	if not await ready_stage():
		await finish()
		return
	check("fifth Earth action arrives at polar coast", main.world.current_scale_id == "polar")
	var stage: Node = main.coordinator.active_scene
	var data: Dictionary = stage.get_meta("polar", {})
	check("coast has four adults from one original asset", data.get("birds", []).size() == 4)
	if data.is_empty():
		await finish()
		return
	var bird: Node3D = data.birds[0]
	check("adult near view has eye ring and flippers",
		bird.find_child("WhiteEyeRingL", true, false) != null and
		bird.find_child("WhiteEyeRingR", true, false) != null and
		bird.find_child("FlipperL", true, false) != null and
		bird.find_child("FlipperR", true, false) != null)
	var floes: int = 0
	for child: Node in stage.world_root.get_children():
		if child.name.begins_with("AuthoredIceFloe_"): floes += 1
	check("exposed coast and twelve ice floes share one scene",
		floes == 12 and stage.world_root.has_node("ExposedRockCoast") and
		stage.world_root.has_node("OpenSouthernOceanReference"))
	var targets: Array[Dictionary] = main.content_targets()
	check("original stable coast and penguin remain before three krill and two activity views", targets.size() == 7 and
		targets[0].node == data.overview and targets[1].node == bird and
		bird.get_meta("stable_id", "") == "3dworld:teaching:adelie-penguin:0000")
	await capture("polar-coast-overview")
	if "--ice-krill-221" in OS.get_cmdline_user_args():
		await _krill_checks(stage)
		await finish()
		return
	var panel: Node = main.explorer_panel
	panel.show()
	panel._process(0.0)
	check("coast topic follows actual coast", panel.select_topic("polar_coast") and main._content_follow == 0)
	await capture("polar-coast-lesson")
	check("penguin topic follows first actual adult", panel.select_topic("adelie_penguin") and main._content_follow == 1)
	await capture("adelie-penguin-near")
	var start: Vector3 = Polar.sample(0.0, 0).position
	var later: Vector3 = Polar.sample(8.0, 0).position
	check("original first pair still walks and fourth keeps static shape", later.distance_to(start) > .1 and
		Polar.sample(8.0, 3).position == Polar.sample(0.0, 3).position)
	main.world.simulation_time_s = 8.0
	for frame: int in range(3): await get_tree().process_frame
	check("paused world time resolves one penguin pose", bird.position.distance_to(later) < .001)
	var paused_pose: Vector3 = bird.position
	for frame: int in range(3): await get_tree().process_frame
	check("paused world time holds penguin pose", bird.position == paused_pose)
	check("guide and two science sources resolve", Reference.allows_url("polar", Polar.PENGUIN_SOURCE) and
		Reference.allows_url("polar", Polar.ICE_SOURCE) and _has_guide("polar_coast") and
		_has_guide("adelie_penguin") and _has_guide("season_light"))
	check("season topic chooses shared date control", panel.select_topic("season_light") and main.ground_light_preview)
	panel.select_season(1)
	for frame: int in range(3): await get_tree().process_frame
	var june: float = Seasons.sample(main.solar_jd, "polar").elevation
	panel.select_season(3)
	for frame: int in range(3): await get_tree().process_frame
	var december: float = Seasons.sample(main.solar_jd, "polar").elevation
	check("southern summer noon is brighter than winter noon", december > june + 30.0)
	check("changing date does not create seasonal animal or ice state",
		bird.position == paused_pose and floes == 12 and data.birds.size() == 4)
	await capture("polar-december-light")
	main.navigation_bar.earth_button.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	check("polar branch returns to visible Earth choices",
		main.world.current_scale_id == "earth" and main.earth_entry_panel.visible)
	await finish()

func _has_guide(id: String) -> bool:
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic", "") == id: return true
	return false

func _fits_view(stage: Node, mesh: MeshInstance3D, margin: float) -> bool:
	var box: AABB = mesh.get_aabb()
	var panel_end: float = main.explorer_panel.get_global_rect().end.x
	for corner: int in range(8):
		var point: Vector3 = mesh.to_global(box.get_endpoint(corner))
		if stage.camera.is_position_behind(point): return false
		var pixel: Vector2 = stage.camera.unproject_position(point)
		if pixel.x < panel_end + margin or pixel.x > get_window().size.x - margin: return false
		if pixel.y < 135.0 or pixel.y > get_window().size.y - 110.0: return false
	return true

func _krill_checks(stage: Node) -> void:
	var data: Dictionary = stage.get_meta("ice_krill", {})
	check("twelve real-size ice krill are actual nodes", data.get("animals", []).size() == 12)
	if data.is_empty(): return
	var animal: Node3D = data.animals[0]
	var eye: MeshInstance3D = animal.find_child("RoundEyeL", true, false) as MeshInstance3D
	var rostrum: MeshInstance3D = animal.find_child("AcuteRostrum", true, false) as MeshInstance3D
	var telson: MeshInstance3D = animal.find_child("Telson", true, false) as MeshInstance3D
	check("eyes rostrum abdomen swimming appendages and tail imported", eye != null and
		rostrum != null and telson != null and animal.find_child("RoundEyeR", true, false) != null and
		animal.find_child("Abdomen06", true, false) != null and data.pleopods[0].size() == 5 and
		data.pleopods[0].all(func(joint: Node3D) -> bool: return joint != null))
	if eye == null or rostrum == null or telson == null: return
	var span: float = rostrum.get_aabb().end.x - telson.get_aabb().position.x
	check("imported rostrum-to-telson span is 30 mm without enlarged instances", absf(span - .030) < .0001 and
		data.animals.all(func(item: Node3D) -> bool: return item.scale == Vector3.ONE))
	var clock: RefCounted = main.world
	var starting_time: float = main.world.simulation_time_s
	var bounded: bool = true
	for sample_step: int in range(53):
		for index: int in range(Krill.COUNT):
			var point: Vector3 = Krill.sample(float(sample_step) * .5, index).position
			bounded = bounded and point.y < -.40 and point.y > -.60 and point.distance_to(Krill.CENTRE) < .20
	check("authored small group remains underwater in bounded route samples", bounded)
	var panel: Node = main.explorer_panel
	panel.show()
	panel._process(0.0)
	check("habitat topic follows real group with underwater camera", panel.select_topic("ice_krill_habitat") and
		main._content_follow == 2 and stage.is_underwater and stage.camera.near <= .0011)
	await capture("ice-krill-group")
	check("adult topic selects same first animal", panel.select_topic("ice_krill") and
		main._content_follow == 3 and main.content_targets()[3].node == animal)
	await capture("ice-krill-adult")
	var shell: StandardMaterial3D = (animal.find_child("Carapace",true,false) as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	krill_observations["adult_camera"] = {"position":stage.camera.position,"near":stage.camera.near,
		"background_mode":stage.environment.background_mode,"background_color":stage.environment.background_color,
		"fill_energy":data.fill.light_energy,"surface_visible":stage.world_root.get_node("OpenSouthernOceanReference").visible,
		"far":stage.camera.far,"fog":stage.environment.fog_enabled,"sun_energy":stage.get_meta("daylight_sun").light_energy,
		"ambient_energy":stage.environment.ambient_light_energy,"camera_mask":stage.camera.cull_mask,
		"shell_alpha":shell.albedo_color.a,"shell_transparency":shell.transparency}
	check("shape view isolates same adult while companions keep world state", stage.camera.cull_mask == 2 and
		data.animals[1].visible and data.animals[1].position.distance_to(Krill.sample(main.world.simulation_time_s,1).position) < .00001)
	check("adult body and eyes fit beside the lesson panel", _fits_view(stage, rostrum, 12.0) and
		_fits_view(stage, telson, 12.0) and _fits_view(stage, eye, 12.0))
	var before: Vector3 = animal.position
	main.world.simulation_time_s = starting_time + 7.0
	for frame: int in range(3): await get_tree().process_frame
	check("shared world time changes krill pose without changing world authority", main.world == clock and
		animal.position.distance_to(before) > .003 and
		animal.position.distance_to(Krill.sample(starting_time + 7.0, 0).position) < .00001)
	var held: Transform3D = animal.transform
	var joint_pose: Transform3D = (data.pleopods[0][0] as Node3D).transform
	for frame: int in range(3): await get_tree().process_frame
	check("pause holds krill route and swimming appendages", animal.transform == held and
		(data.pleopods[0][0] as Node3D).transform == joint_pose)
	check("head topic keeps actual first krill and close focus", panel.select_topic("ice_krill_head") and
		main._content_follow == 4 and data.head_focus.position.distance_to(animal.to_global(Vector3(.0107,.001,.001))) < .00001)
	await capture("ice-krill-head")
	check("large eyes and rostrum fit head view beside lesson", _fits_view(stage, eye, 12.0) and _fits_view(stage, rostrum, 12.0))
	check("head markers match actual animal positions", Topics.marks(main,"ice_krill_head")[0].at.distance_to(
		animal.to_global(Vector3(.01135,.0011,.00157))) < .00001)
	get_window().size = Vector2i(900, 650)
	panel.select_topic("ice_krill")
	for frame: int in range(3): await get_tree().process_frame
	await capture("ice-krill-compact")
	check("compact adult keeps eyes and tail beside compact panel", _fits_view(stage, eye, 8.0) and _fits_view(stage, telson, 8.0))
	get_window().size = Vector2i(1280, 800)
	for frame: int in range(3): await get_tree().process_frame
	check("krill guide and scientific sources resolve", _has_guide("ice_krill_habitat") and _has_guide("ice_krill") and
		_has_guide("ice_krill_head") and Reference.allows_url("polar",Krill.SOURCE) and
		Reference.allows_url("polar",Krill.MORPHOLOGY_SOURCE) and Reference.allows_url("polar",Krill.FOOD_SOURCE))
	main._open_guide()
	main.world_guide.show_ecology(true)
	var map: Node = main.world_guide.ecology_map
	map.set_branch("polar")
	for frame: int in range(3): await get_tree().process_frame
	var relation: Dictionary = Relations.for_branch("polar")
	check("food relation names two actual species and distinguishes offshore krill", relation.edges.size() == 1 and
		map.nodes.has("krill") and map.nodes.has("penguin") and not map.nodes.krill.disabled and
		not map.nodes.penguin.disabled and relation.edges[0].note.contains("未模拟"))
	await capture("ice-krill-food-relation")
	map.nodes.krill.pressed.emit()
	if not await ready_stage(): return
	for frame: int in range(3): await get_tree().process_frame
	check("food graph enters actual krill near view", not main.world_guide.visible and main._content_follow == 3 and
		main.learning_overlay.topic == "ice_krill")
	panel.select_topic("adelie_penguin")
	check("return to penguin restores above-water camera", main._content_follow == 1 and not stage.is_underwater and
		is_equal_approx(stage.camera.near,.06) and stage.environment.background_mode == Environment.BG_SKY)
	main.world.simulation_time_s = starting_time
	for frame: int in range(3): await get_tree().process_frame
	krill_observations.merge({"body_span_m": span, "group_count": data.animals.size(), "world_time_held": main.world.paused,
		"guide_actions": main.world_guide.route_buttons.size(), "new_species": "Euphausia crystallorophias"})
	main.navigation_bar.earth_button.pressed.emit()
	if not await ready_stage(): return
	check("new underwater branch returns to Earth with same paused clock", main.world.current_scale_id == "earth" and
		main.world == clock and main.world.simulation_time_s == starting_time and main.world.paused)
	if not await arrive("polar"): return
	var restored: Dictionary = main.coordinator.active_scene.get_meta("ice_krill")
	check("returning to polar resolves same stable animal from world time", restored.animals[0].get_meta("stable_id") ==
		"3dworld:teaching:ice-krill:0000" and restored.animals[0].position.distance_to(Krill.sample(starting_time,0).position) < .00001)

func finish() -> void:
	var output: FileAccess = FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"debug":OS.is_debug_build(),
		"renderer":RenderingServer.get_current_rendering_driver_name(),"screen":get_window().current_screen,
		"primary":DisplayServer.get_primary_screen(),"performance_test":false,"window_activity_policy":"unfocusable_diagnostic",
		"last_transition":main.coordinator.latest_metrics,"krill_observations":krill_observations},"\t") + "\n")
	print("POLAR_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
