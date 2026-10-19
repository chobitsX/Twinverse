extends Node3D
## M0-001 的可见启动场景；只有显式 --smoke-test 才执行检查并自动退出。

@onready var _status: Label = $HUD/Root/Status
@onready var _quit_button: Button = $HUD/Root/Quit


func _ready() -> void:
	$Camera3D.look_at(Vector3(0.0, 0.65, 0.0))
	get_tree().auto_accept_quit = false
	_quit_button.pressed.connect(_request_quit.bind("button"))
	var runtime: Dictionary = _runtime_info()
	_status.text = "Godot %s  ·  %s / %s  ·  %s" % [
		runtime.engine, runtime.method, runtime.driver, runtime.device,
	]
	print("BOOT_READY ", JSON.stringify(runtime))
	if OS.get_cmdline_user_args().has("--smoke-test"):
		_run_smoke_test.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit("window_close")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_quit("escape")


func _request_quit(reason: String) -> void:
	print("BOOT_QUIT ", reason)
	get_tree().quit()


func _runtime_info() -> Dictionary:
	return {
		"engine": Engine.get_version_info().string,
		"method": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"device": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"arm64": OS.has_feature("arm64"),
		"debug_build": OS.is_debug_build(),
		"window_size": str(DisplayServer.window_get_size()),
		"viewport_size": str(get_viewport().get_visible_rect().size),
	}


func _run_smoke_test() -> void:
	var runtime: Dictionary = _runtime_info()
	if runtime.display == "headless" or runtime.driver != "metal" \
			or runtime.method != "forward_plus" or not runtime.arm64:
		push_error("SMOKE_FAIL: requires a visible arm64 Forward+ / Metal runtime.")
		get_tree().quit(2)
		return

	# 等待实际绘制完成，不能把 headless 或仅进入主循环当成 GPU 渲染成功。
	for frame: int in range(60):
		await RenderingServer.frame_post_draw

	var screenshot: Image = get_viewport().get_texture().get_image()
	if screenshot.is_empty():
		push_error("SMOKE_FAIL: viewport image is empty.")
		get_tree().quit(3)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			var capture_path: String = argument.trim_prefix("--capture=")
			var result: Error = screenshot.save_png(capture_path)
			if result != OK:
				push_error("SMOKE_FAIL: capture failed with error %s." % result)
				get_tree().quit(4)
				return
	print("SMOKE_PASS ", JSON.stringify({
		"rendered_frames": 60,
		"image_size": str(screenshot.get_size()),
		"runtime": runtime,
	}))
	_request_quit("smoke_complete")
