extends "res://tests/integration/world_expansion_suite.gd"
const Species = preload("res://scripts/experience/species_catalog.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")
var atlas: Node
var visits: Array[Dictionary] = []
var paused_time: float = 0.0

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world222-review="): directory = argument.trim_prefix("--world222-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size = Vector2i(1280, 800)
	if DisplayServer.get_name() != "headless": get_window().unfocusable = true
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless": main._measurement_screen = get_window().current_screen
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	if not await arrive("earth"):
		await finish()
		return
	paused_time = main.world.simulation_time_s
	var camera: Transform3D = main.coordinator.active_scene.camera.transform
	main._open_guide()
	main.world_guide.species_button.pressed.emit()
	atlas = main.world_guide.species_atlas
	await settle()
	check("atlas opens without moving camera or world clock", atlas.visible and main.world_guide.visible and main.world.paused and main.world.simulation_time_s == paused_time and main.coordinator.active_scene.camera.transform.is_equal_approx(camera))
	check("all 40 unique named references have one card", Species.ENTRIES.size() == 40 and atlas.cards.size() == 40 and atlas.visible_ids().size() == 40)
	var identities: Dictionary = {}
	var names: Dictionary = {}
	var valid: bool = true
	var kinds: Dictionary = {}
	for entry: Dictionary in Species.ENTRIES:
		identities[entry.id] = true
		names[entry.scientific] = true
		kinds[entry.kind] = int(kinds.get(entry.kind, 0)) + 1
		valid = valid and main.Catalog.contains(str(entry.scale)) and Species.AREAS.has(Species.area(entry)) and Species.KINDS.has(entry.kind)
		if not str(entry.topic).is_empty():
			valid = valid and Topics.for_scale(str(entry.scale)).any(func(topic: Dictionary) -> bool: return topic.id == entry.topic)
	check("scientific names and species identities do not duplicate", identities.size() == 40 and names.size() == 40)
	check("all atlas destinations use registered scenes and lessons", valid)
	check("fungus stays separate from fourteen plants and animal groups", kinds.get("fungus") == 1 and kinds.get("plant") == 14 and kinds.get("fish") == 7 and kinds.get("bird") == 4 and kinds.get("invertebrate") == 6)
	check("main atlas shows three scrollable columns", atlas.grid.columns == 3 and _frame_fits())
	await capture("atlas-overview")
	await filter("", "invertebrate", "")
	check("invertebrate view includes krill coral echinoderms and clam", atlas.visible_ids() == ["setosum", "maxima", "atra", "cyanea", "millepora", "crystallorophias"])
	await capture("atlas-invertebrates")
	await filter("", "", "EUPHAUSIA　CRYSTALLOROPHIAS")
	check("Latin name search ignores case and full-width space", atlas.visible_ids() == ["crystallorophias"])
	await capture("atlas-scientific-search")
	await filter("city", "plant", "银杏")
	check("scene class and Chinese name intersect", atlas.visible_ids() == ["biloba"])
	await filter("", "fungus", "")
	check("fungus filter finds the existing Trametes reference", atlas.visible_ids() == ["versicolor"])
	await filter("polar", "plant", "")
	check("empty intersection has visible recovery and zero count", atlas.visible_ids().is_empty() and atlas.empty.visible and atlas.count.text.contains("0 / 40"))
	await capture("atlas-no-results")
	atlas.reset_button.pressed.emit()
	await settle()
	check("reset clears all filters and restores every species", atlas.visible_ids().size() == 40 and atlas.search.text.is_empty() and atlas.area_filter.selected == 0 and atlas.kind_filter.selected == 0 and not atlas.empty.visible)
	get_window().size = Vector2i(900, 650)
	await settle()
	check("compact atlas keeps two columns filters and frame within viewport", atlas.grid.columns == 2 and _frame_fits() and atlas.search.get_global_rect().end.x <= 900 and atlas.search.get_global_rect().size.y >= 40)
	await capture("atlas-compact")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	atlas.search.grab_focus()
	main._input(key)
	check("atlas text input does not toggle pause or advance time", main.world.paused and main.world.simulation_time_s == paused_time)
	key.keycode = KEY_ESCAPE
	main._input(key)
	check("Escape returns to same observation without quitting", not main.world_guide.visible and not main._shutting_down and main.coordinator.active_scene.camera.transform.is_equal_approx(camera))
	get_window().size = Vector2i(1280, 800)
	await settle()
	main._open_guide()
	check("reopening guide restores all 86 topic actions", main.world_guide.grid.visible and not atlas.visible and main.world_guide.route_buttons.size() == 86 and main.world_guide.route_buttons.all(func(button: Button) -> bool: return button.visible))
	main.world_guide.species_button.pressed.emit()
	main.world_guide.species_button.pressed.emit()
	check("atlas return restores original question cards", main.world_guide.grid.visible and not atlas.visible and main.world_guide.search.visible and main.world_guide.cards.size() == 8)
	main.world_guide.show_ecology(true)
	check("ecology and atlas modes remain mutually exclusive", main.world_guide.ecology_map.visible and not atlas.visible and not main.world_guide.grid.visible)
	main.world_guide.ecology_button.pressed.emit()
	check("ecology return restores topics and atlas entry", main.world_guide.grid.visible and main.world_guide.species_button.visible and main.world_guide.ecology_button.visible)
	await capture("atlas-return-themes")
	for visit: Array in [["maxima", "atlas-reef-clam"], ["versicolor", "atlas-woodland-fungus"], ["gigantea", "atlas-desert-cactus"], ["platyrhynchos", "atlas-city-mallard"], ["crystallorophias", "atlas-polar-krill"], ["percula", "atlas-target-fish"]]:
		if not await visit_species(str(visit[0]), str(visit[1])):
			await finish()
			return
	check("representative visits preserve paused world authority", main.world.paused and main.world.simulation_time_s == paused_time and visits.size() == 6)
	main.observe_scale("earth")
	if not await ready_stage():
		await finish()
		return
	check("atlas visits return to Earth choices", main.world.current_scale_id == "earth" and main.earth_entry_panel.visible)
	await finish()

func settle() -> void:
	for frame: int in range(3): await get_tree().process_frame

func filter(area: String, kind: String, query: String) -> void:
	atlas.area_filter.select(atlas.area_ids.find(area))
	atlas.kind_filter.select(atlas.kind_ids.find(kind))
	atlas.search.text = query
	atlas.search.text_changed.emit(query)
	await settle()

func _frame_fits() -> bool:
	var rect: Rect2 = main.world_guide.panel.get_global_rect()
	return rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= get_window().size.x and rect.end.y <= get_window().size.y

func visit_species(id: String, image_name: String) -> bool:
	main._open_guide()
	main.world_guide.species_button.pressed.emit()
	var entry: Dictionary = {}
	for card: Dictionary in atlas.cards:
		if card.entry.id == id:
			entry = card.entry
			card.button.pressed.emit()
			break
	if entry.is_empty() or not await ready_stage(): return false
	await settle()
	var topic: String = str(entry.topic)
	var arrived: bool = main.world.current_scale_id == entry.scale and not main.world_guide.visible and main.explorer_panel.visible
	check("species button enters " + id + " actual scene", arrived)
	if not topic.is_empty():
		var targets: Array[Dictionary] = main.content_targets()
		var selected: int = main._content_follow
		var actual: bool = main.explorer_panel._topic.get("id", "") == topic and selected >= 0 and selected < targets.size() and is_instance_valid(targets[selected].node)
		check("species button selects " + id + " actual model lesson", actual)
		arrived = arrived and actual
	visits.append({"species":id, "scale":main.world.current_scale_id, "topic":main.explorer_panel._topic.get("id", ""), "follow":main._content_follow, "world_time_s":main.world.simulation_time_s})
	await capture(image_name)
	return arrived

func finish() -> void:
	var report: Dictionary = {"cases":cases, "failures":failures, "captures":captures, "representative_visits":visits, "debug":OS.is_debug_build(), "renderer":RenderingServer.get_current_rendering_driver_name(), "species_count":Species.ENTRIES.size(), "guide_actions":main.world_guide.route_buttons.size() if is_instance_valid(main) else 0, "native_ime_tested":false, "performance_test":false}
	FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("ATLAS_FINISHED ", cases.size(), " ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
