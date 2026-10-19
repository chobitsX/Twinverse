extends "res://tests/integration/world_expansion_suite.gd"
const Reference = preload("res://scripts/experience/science_reference.gd")
const Catalog = preload("res://scripts/core/scale_catalog.gd")
func run() -> void:
	var current_content: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world93-check="): directory = argument.trim_prefix("--world93-check=")
		if argument.begins_with("--world106-check="):
			directory = argument.trim_prefix("--world106-check=")
			current_content = true
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless" and DisplayServer.get_screen_count()==1:
		main._measurement_screen=get_window().current_screen
		get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	if DisplayServer.get_name()!="headless":
		# Match the existing expansion runner's macOS startup visibility settling.
		var stable_since: int = Time.get_ticks_msec()
		var deadline: int = stable_since+10000
		while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since=Time.get_ticks_msec()
	main._reduced_motion = true
	main.world.set_paused(true)
	for id: String in Catalog.SCALES:
		var entry: Dictionary = Reference.describe(id)
		var valid: bool = not entry.kind.is_empty() and not entry.basis.is_empty() and not entry.limit.is_empty()
		if id!="galaxy": valid = valid and not entry.sources.is_empty()
		for source: Array in entry.sources: valid = valid and Reference.allows_url(id,source[1]) and str(source[1]).begins_with("https://")
		check(id+" has scope and matching reference links",valid)
	check("unlisted links are rejected",not Reference.allows_url("earth","https://example.invalid") and not Reference.allows_url("earth","javascript:alert(1)"))
	var observed_scales: Array[String] = ["solar_system","earth_moon","city","heart","atom"]
	if current_content: observed_scales.assign(["woodland","reef"])
	for id: String in observed_scales:
		if not await arrive(id):
			await finish()
			return
		main.world_guide.hide()
		main.explorer_panel.hide()
		main.info_panel.show()
		for frame: int in range(2): await get_tree().process_frame
		var text: String = main.info_label.get_parsed_text()
		check(id+" displays basis and limits",text.contains(Reference.describe(id).kind) and text.contains("适用边界") and text.contains("参考入口") and not text.contains("[url="))
		if current_content:
			var stage: Node = main.coordinator.active_scene
			if id=="woodland":
				check("six named woodland references match current selectable assets",main.content_targets().size()==9 and stage.get_meta("pollinators").size()==4 and stage.get_meta("milkweed_plants").size()==6 and text.contains("帝王蝶") and text.contains("普通乳草") and Reference.describe(id).sources.size()==7)
			else:
				check("marine references include live fish turtle ray and urchin",stage.get_meta("marine_actors").size()==44 and stage.get_meta("benthic_targets").size()==2 and text.contains("长刺海胆") and text.contains("绿海龟") and Reference.describe(id).sources.size()==13 and text.contains("Acropora millepora") and stage.get_meta("coral_targets").size()==2)
			await capture(id+"-science-overview")
			get_window().size=Vector2i(900,650)
			for frame: int in range(3): await get_tree().process_frame
			main.info_label.get_v_scroll_bar().value=main.info_label.get_v_scroll_bar().max_value
			for frame: int in range(3): await get_tree().process_frame
			check(id+" compact source panel stays inside viewport",main.info_panel.get_global_rect().position.x>=0 and main.info_panel.get_global_rect().end.y<650 and main.info_label.get_parsed_text().contains("参考入口"))
			await capture(id+"-science-sources-compact")
			get_window().size=Vector2i(1280,720)
			main.info_label.get_v_scroll_bar().value=0
		elif id in ["solar_system","atom"]: await capture(id+"-science-reference")
		if id=="heart":
			main._select_heart_region("ventricle")
			check("selected heart region retains provenance",main.info_label.text.contains(Reference.BODY_SOURCE) and main.info_label.text.contains("心室"))
		main.info_panel.hide()
	await finish()
