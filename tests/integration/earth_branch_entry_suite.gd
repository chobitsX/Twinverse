extends "res://tests/integration/world_expansion_suite.gd"

## The visible Earth landing choices use the existing authoritative navigation.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world189-review="):
			directory = argument.trim_prefix("--world189-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	# Automated observation must keep drawing if another app owns keyboard focus,
	# including on a single-screen Mac. The existing budget then caps it at 5 FPS.
	if DisplayServer.get_name() != "headless":
		main._measurement_screen = get_window().current_screen
		get_window().unfocusable = true
	get_window().size = Vector2i(1280, 800)
	get_tree().create_timer(100.).timeout.connect(func() -> void:
		push_error("Earth branch entry short check exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	var stable_since: int = Time.get_ticks_msec()
	var startup_deadline: int = stable_since + 10000
	while Time.get_ticks_msec() - stable_since < 2000 and Time.get_ticks_msec() < startup_deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw():
			stable_since = Time.get_ticks_msec()
	if not await arrive("earth"):
		await finish()
		return
	var panel: PanelContainer = main.earth_entry_panel
	var entries: Dictionary = panel.buttons
	var all_branches: bool = entries.size() == 5
	for id: String in ["reef","woodland","desert","city","polar"]: all_branches = all_branches and entries.has(id)
	check("Earth landing shows five distinct branch actions", panel.visible and all_branches)
	var semantics: bool = entries.reef.text.contains("蜥蜴岛区域") and entries.woodland.text.contains("合成") and entries.desert.text.contains("参考生境") and entries.city.text.contains("合成") and entries.polar.text.contains("合成参考")
	check("regional reef and synthetic branches are distinguished", semantics)
	for frame: int in range(4): await get_tree().process_frame
	await capture("earth-five-branches")
	var time_before: float = main.world.simulation_time_s
	for id: String in ["reef","woodland","desert","city","polar"]:
		(entries[id] as Button).pressed.emit()
		if not await ready_stage():
			await finish()
			return
		check("Earth action arrives at " + id, main.world.current_scale_id == id and not panel.visible)
		main.navigation_bar.earth_button.pressed.emit()
		if not await ready_stage():
			await finish()
			return
		check(id + " returns to visible Earth choice", main.world.current_scale_id == "earth" and panel.visible)
	get_window().size = Vector2i(900, 650)
	for frame: int in range(5): await get_tree().process_frame
	var rect: Rect2 = panel.get_global_rect()
	check("compact Earth choice stays clear of background title", rect.position.x >= 16.0 and rect.end.x <= 900.0 and rect.position.y >= 150.0 and rect.end.y < 465.0)
	await capture("earth-five-branches-compact")
	main.clean_observation.set_active(true)
	check("clean observation hides Earth actions with HUD", not panel.is_visible_in_tree())
	main.clean_observation.set_active(false)
	check("returning from clean observation restores Earth actions", panel.is_visible_in_tree())
	check("branch navigation preserves paused authoritative time", main.world.paused and main.world.simulation_time_s == time_before)
	await finish()
