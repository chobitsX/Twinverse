extends SceneTree
## Finite native-window checks. Never changes preferences or saves the world.
const Experience = preload("res://scenes/experience.tscn")
var main: Node
var records: Array[Dictionary] = []
var failures: Array[String] = []
var output: String = ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless" or not "--no-save" in OS.get_cmdline_user_args(): quit(2); return
	create_timer(25).timeout.connect(func() -> void: quit(2))
	root.unfocusable = true
	output = "res://docs/evidence/UI-DPI-287/source-screen-"+str(root.current_screen)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_node("AppLanguage").set_language("zh_CN",false)
	main = Experience.instantiate()
	root.add_child(main)
	main.world.set_paused(true)
	main._reduced_motion = true
	while not main.coordinator.active_scene.is_prepared(): await process_frame
	main.world_guide.hide()
	main.explorer_panel.hide()
	await capture("zh")
	root.get_node("AppLanguage").set_language("en",false)
	for index: int in range(3): await process_frame
	await capture("en")
	FileAccess.open(output.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"records":records,"failures":failures},"\t")+"\n")
	print("UI_DENSITY_CHECKS ",JSON.stringify({"records":records.size(),"failures":failures}))
	main._quit(0 if failures.is_empty() else 1,true)

func capture(locale: String) -> void:
	for index: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var lines: Array = []
	var source: String = "ObjC.import('CoreGraphics'); var rows=ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(1,0))); JSON.stringify(rows.filter(function(w){return w.kCGWindowOwnerPID==="+str(OS.get_process_id())+" && w.kCGWindowLayer===0;}).map(function(w){return {id:w.kCGWindowNumber,bounds:w.kCGWindowBounds};}));"
	var windows: Array = []
	if OS.get_name()=="macOS":
		OS.execute("/usr/bin/osascript",PackedStringArray(["-l","JavaScript","-e",source]),lines,true)
		var parsed: Variant = JSON.parse_string(str(lines[0])) if not lines.is_empty() else null
		if parsed is Array: windows.assign(parsed)
	var native_width: float = float(windows[0].bounds.Width) if not windows.is_empty() else 0.0
	var coordinate_density: float = root.size.x/native_width if native_width>0.0 else 0.0
	var header_points: float = main.immersive_interface.header.get_global_rect().size.y/coordinate_density if coordinate_density>0.0 else 0.0
	if OS.get_name()=="macOS":
		if not is_equal_approx(main.ui_scale,coordinate_density): failures.append(locale+": HUD/native point ratio differs")
		if absf(header_points-76.0)>0.1: failures.append(locale+": header no longer 76 native points")
	if main.hud.theme.default_font_size!=18: failures.append(locale+": body font changed")
	if not is_equal_approx(main.immersive_interface.menu_button.get_popup().content_scale_factor,main.ui_scale): failures.append(locale+": popup scale differs")
	var path: String = output.path_join(locale+".png")
	if root.get_texture().get_image().save_png(path)!=OK: failures.append(locale+": capture failed")
	# System capture shows the actual OS-sized window, not a scaled viewport image.
	if not windows.is_empty():
		OS.execute("/usr/sbin/screencapture",PackedStringArray(["-x","-l",str(int(windows[0].id)),ProjectSettings.globalize_path(output.path_join(locale+"-window.png"))]),[],true)
	records.append({"locale":locale,"screen":root.current_screen,"screen_density":DisplayServer.screen_get_scale(root.current_screen),"coordinate_density":coordinate_density,"ui_scale":main.ui_scale,"logical_size":str(main.ui_view_size()),"header_native_points":header_points,"body_font_points":main.hud.theme.default_font_size,"native_windows":windows,"viewport_pixels":str(root.get_texture().get_size())})
