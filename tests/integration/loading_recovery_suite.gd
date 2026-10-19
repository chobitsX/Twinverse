extends "res://tests/integration/ecophysiology_suite.gd"
## Controlled visible-response deadline fault with actual production scenes/UI.
## This does not reproduce or identify the historical cold-load root cause.
const Store = preload("res://scripts/core/world_store.gd")
var save_directory: String

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world121-check="): directory=arg.trim_prefix("--world121-check=")
		if arg.begins_with("--world-dir="): save_directory=arg.trim_prefix("--world-dir=")
	if not directory.is_absolute_path() or not save_directory.is_absolute_path() or save_directory==ProjectSettings.globalize_path("user://world"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	output=directory.path_join("report.json")
	mode="controlled_recovery_121"
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	main.world.set_paused(true)
	main._reduced_motion=true
	main.world_guide.hide()
	var original: Node = main.coordinator.active_scene
	var original_pose: Transform3D = original.camera.transform
	var before: Dictionary = main.world.checkpoint()
	check("starts in real Earth scene with isolated persistence",main.world.current_scale_id=="earth" and main._persistence_enabled)
	await inject_deadline()
	check("failure preserves original world and camera",main.coordinator.active_scene==original and main.world.checkpoint()==before and original.camera.transform.is_equal_approx(original_pose))
	check("waiting is explicit and retry disabled",main.recovery_actions.visible and main.retry_button.disabled and main.message_label.text.contains("仍在加载"))
	check("same guide topic is preserved for retry",main._recovery_guide=={"scale":"earth_moon","topic":"lunar_phases"})
	await capture("recovery-waiting")
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.button_mask=MOUSE_BUTTON_MASK_LEFT
	drag.relative=Vector2(18,4)
	main._unhandled_input(drag)
	check("original world remains orbitable while draining",not original.camera.transform.is_equal_approx(original_pose))
	var saved: String = main.save_world(true)
	var loaded: Dictionary = Store.new(save_directory).load_session()
	check("save during recovery preserves original scale and paused models",saved=="ok" and loaded.status=="ok" and loaded.payload.world.current_scale_id=="earth" and equivalent(loaded.payload.world.schooling,before.schooling) and loaded.payload.world.paused)
	(main.recovery_actions.get_child(1) as Button).pressed.emit()
	check("cancel button clears retry topic while worker remains quarantined",not main.recovery_actions.visible and main._recovery_guide.is_empty() and main.coordinator.is_busy())
	main.coordinator._poll_draining()
	main.coordinator.set_process(true)
	if not await ready_stage():
		await finish()
		return
	check("cancelled drain releases extra resource without changing world",main.coordinator._retained_scene==null and main.world.current_scale_id=="earth")
	await inject_deadline()
	main.coordinator._poll_draining()
	main.coordinator.set_process(true)
	if not await ready_stage():
		await finish()
		return
	check("completion enables actual retry button and keeps one resource",main.recovery_actions.visible and not main.retry_button.disabled and main.coordinator._retained_scene!=null)
	get_window().size=Vector2i(900,650)
	for frame: int in range(4): await get_tree().process_frame
	var rect: Rect2 = main.retry_button.get_global_rect()
	check("compact retry and cancel are inside viewport and above navigation",get_viewport().get_visible_rect().encloses(main.recovery_actions.get_global_rect()) and rect.end.y<=main.previous_button.get_global_rect().position.y)
	await capture("recovery-ready-compact")
	main.retry_button.pressed.emit()
	check("retry consumes banner and reuses cached path",not main.recovery_actions.visible and main.coordinator._cache_at_request)
	if not await ready_stage():
		await finish()
		return
	for frame: int in range(4): await get_tree().process_frame
	check("retry arrives at requested scale and original learning topic",main.world.current_scale_id=="earth_moon" and main.learning_overlay.topic=="lunar_phases" and main.explorer_panel.visible)
	check("retry retains one world clock and one live stage",main.world.simulation_time_s==before.simulation_time_s and main.scene_host.get_child_count()==1 and main.coordinator._retained_scene==null)
	await capture("recovery-topic-restored")
	loaded=Store.new(save_directory).load_session()
	check("normal arrival saves committed target",loaded.status=="ok" and loaded.payload.world.current_scale_id=="earth_moon")
	await finish()

func inject_deadline() -> void:
	# Pause polling, not the actual ResourceLoader. Suppress only the test's
	# presentation acknowledgement after real frames, then use production timeout.
	main.coordinator.set_process(false)
	main.start_guide_visit("earth_moon","lunar_phases")
	for frame: int in range(4): await get_tree().process_frame
	main.coordinator._first_response_us=0
	main.coordinator._timeout_ms=1
	main.coordinator._intent_us=Time.get_ticks_usec()-2000
	main.coordinator._poll_loading()
	check("controlled missing acknowledgement enters production timeout",main.coordinator.latest_metrics.reason=="resource_timeout" and main.coordinator.phase==main.Coordinator.Phase.DRAINING)

func capture(name_value: String) -> void:
	for frame: int in range(3): await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name_value+".png"))
