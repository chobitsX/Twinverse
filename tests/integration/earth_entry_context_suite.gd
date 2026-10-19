extends "res://tests/integration/earth_spatial_entry_suite.gd"
## Exercise actual host keyboard/button routing with a selected spatial region.
var original_authority: int = 0
var original_date: float = 0.0
var original_core: Dictionary = {}

func enter_key() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	main._input(event)

func city_requested() -> bool:
	return main.coordinator.is_busy() and main.coordinator._target_id == "city"

func return_earth() -> bool:
	main.navigation_bar.earth_button.pressed.emit()
	return await ready_stage() and main.world.current_scale_id == "earth"

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world250-entry-check="): directory = argument.trim_prefix("--world250-entry-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	get_tree().create_timer(95).timeout.connect(func() -> void: get_tree().quit(2))
	get_window().size = Vector2i(1280, 800)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless": main._measurement_screen = get_window().current_screen
	if is_instance_valid(main._audio): main._audio.volume_db = -80
	main._reduced_motion = true
	main.world.set_paused(true)
	main._refresh_observation_controls()
	main.set_solar_rate(0)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await ready_stage(): await finish(); return
	await pose_region("city")
	original_authority = main.world.get_instance_id()
	original_date = main.solar_jd
	original_core = core_checkpoint()
	var panel: Node = main.earth_entry_panel
	click(panel.points.city.rect.get_center())
	check("visible city marker selects the geographic destination", panel.selected == "city" and panel.available())
	main.clean_observation.set_active(true)
	check("clean view hides marker picking and keeps the destination", not panel.available() and panel.selected == "city")
	await capture("clean-selected-earth")
	enter_key()
	check("Enter from clean view requests the selected city", city_requested())
	if not city_requested(): await finish(); return
	var request: int = main.coordinator._request_id
	enter_key()
	check("busy entry does not replace the in-flight request", main.coordinator._request_id == request)
	if not await ready_stage(): await finish(); return
	check("clean entry arrives and restores the normal interface", main.world.current_scale_id == "city" and not main.clean_observation.active and main.hud.visible)
	await capture("city-from-clean-entry")
	check("clean entry preserves the paused world and date", main.world.get_instance_id() == original_authority and core_checkpoint() == original_core and main.solar_jd == original_date)
	check("return from clean entry reaches Earth", await return_earth())
	panel.refresh_points()
	main.explorer_panel.show()
	check("explorer hides picking while the selected region remains", not panel.available() and panel.selected == "city")
	main.next_button.pressed.emit()
	check("bottom action from explorer requests the selected city", city_requested())
	if not city_requested(): await finish(); return
	check("regional entry closes the old Earth explorer", not main.explorer_panel.visible)
	main.coordinator.cancel("entry_context_short_check")
	if not await ready_stage(): await finish(); return
	check("cancel restores Earth and the selected destination", main.world.current_scale_id == "earth" and panel.selected == "city" and main.scene_host.get_child_count() == 1)
	main.explorer_panel.show()
	enter_key()
	check("Enter from explorer follows the selected region", city_requested())
	if not city_requested(): await finish(); return
	if not await ready_stage(): await finish(); return
	check("explorer keyboard entry arrives with the same world", main.world.current_scale_id == "city" and main.world.get_instance_id() == original_authority)
	check("return from explorer entry reaches Earth", await return_earth())
	await settle()
	main.world_guide.show()
	request = main.coordinator._request_id
	enter_key()
	check("guide owns Enter and prevents a hidden region jump", main.coordinator._request_id == request and not main.coordinator.is_busy())
	main.world_guide.hide()
	main.world.set_foreground(false)
	enter_key()
	check("background entry does not start navigation", main.coordinator._request_id == request and not main.coordinator.is_busy())
	main.world.set_foreground(true)
	panel.clear_selection()
	enter_key()
	check("unselected Enter keeps the original atmosphere route", main.coordinator.is_busy() and main.coordinator._target_id == "atmosphere")
	if not await ready_stage(): await finish(); return
	check("original atmosphere entry remains reachable", main.world.current_scale_id == "atmosphere")
	check("return from atmosphere reaches Earth", await return_earth())
	check("all entry contexts preserve core state date and authority", main.world.get_instance_id() == original_authority and main.world.paused and core_checkpoint() == original_core and main.solar_jd == original_date)
	await capture("earth-context-restored")
	await finish()

func finish() -> void:
	var observations: Dictionary = {"world_id":main.world.get_instance_id(),"original_world_id":original_authority,"date_jd":main.solar_jd,"original_date_jd":original_date,"paused":main.world.paused,"scale":main.world.current_scale_id,"persistence_enabled":main._persistence_enabled,"audio_volume_db":main._audio.volume_db if is_instance_valid(main._audio) else null,"native_input_disabled":get_viewport().gui_disable_input,"unfocusable":get_window().unfocusable}
	FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"display":DisplayServer.get_name(),"performance_test":false,"native_os_input_tested":false,"observations":observations,"frames":frame_records}, "\t"))
	print("ENTRY_CONTEXT_FINISHED ", failures)
	main._quit(0 if failures.is_empty() else 1)
