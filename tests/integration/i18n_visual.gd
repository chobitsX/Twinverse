extends SceneTree
## Finite native captures. No OS input, user preference writes or world saves.
const Experience = preload("res://scenes/experience.tscn")
var main: Node
var output: String = "res://docs/evidence/I18N-001/visual-initial"
var records: Array[Dictionary] = []
var followup: bool = false
var focused: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless" or not "--no-save" in OS.get_cmdline_user_args(): quit(2); return
	focused = "--i18n-focused" in OS.get_cmdline_user_args()
	followup = "--i18n-followup" in OS.get_cmdline_user_args()
	if focused:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--scale="): output = "res://docs/evidence/I18N-001/visual-"+argument.trim_prefix("--scale=")
	if followup: output = "res://docs/evidence/I18N-001/visual-followup"
	create_timer(110 if followup else 65).timeout.connect(func() -> void: quit(2))
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	# Prefer an actual secondary display when available; never rearrange displays.
	var primary: int = DisplayServer.get_primary_screen()
	if DisplayServer.get_screen_count()>1:
		root.current_screen = 0 if primary!=0 else 1
	root.size = Vector2i(2560,1600)
	root.position = DisplayServer.screen_get_usable_rect(root.current_screen).position + (DisplayServer.screen_get_usable_rect(root.current_screen).size-root.size)/2
	root.get_node("AppLanguage").set_language("en",false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main = Experience.instantiate()
	root.add_child(main)
	main._measurement_screen = root.current_screen
	main._reduced_motion = true
	main.world.set_paused(true)
	main.set_solar_rate(0.0)
	main.world_guide.hide()
	var deadline: int = Time.get_ticks_msec()+30000
	while not main.coordinator.active_scene.is_prepared() and Time.get_ticks_msec()<deadline: await process_frame
	if focused:
		await capture("01-scene-en")
		main.world.set_foreground(true)
		var topic: String = {"reef":"coral_symbiosis","atom":"oxygen_atom","night_sky":"ground_sky"}.get(main.world.current_scale_id, "")
		if not topic.is_empty(): main.explorer_panel.open_topic(topic)
		await capture("02-knowledge-en")
		if main.world.current_scale_id=="reef":
			root.size = Vector2i(1560,1440)
			main._resize()
			await capture("02b-narrow-knowledge-en")
		root.get_node("AppLanguage").set_language("zh_CN",false)
		await capture("03-knowledge-zh")
		_finish(primary)
		return
	if followup:
		if not await _followup(): return
		_finish(primary)
		return
	await capture("01-solar-en")
	main.world_guide.open(false)
	await capture("02-guide-en")
	main.world_guide.hide()
	main.explorer_panel.show()
	await capture("03-knowledge-en")
	root.size = Vector2i(1560,1440)
	main._resize()
	await capture("04-narrow-knowledge-en")
	main.explorer_panel.hide()
	main.world_guide.open(false)
	await capture("05-narrow-guide-en")
	root.get_node("AppLanguage").set_language("zh_CN",false)
	await capture("06-narrow-guide-zh")
	_finish(primary)

func _finish(primary: int) -> void:
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify({"screen_count":DisplayServer.get_screen_count(),"primary":primary,"used":root.current_screen,"records":records},"\t")+"\n")
	print("I18N_NATIVE_CAPTURES ",records.size())
	main._quit(0,true)

func _followup() -> bool:
	main.explorer_panel.show()
	await capture("01-solar-knowledge-fixed-en")
	root.size = Vector2i(1560,1440)
	main._resize()
	main.explorer_panel.hide()
	main.world_guide.open(false)
	await capture("02-narrow-guide-fixed-en")
	root.size = Vector2i(2560,1600)
	main._resize()
	for scale_id: String in ["reef","night_sky","atom"]:
		main.world_guide.hide()
		main.explorer_panel.hide()
		main.world.set_foreground(true)
		main.navigate_to(scale_id)
		var deadline: int = Time.get_ticks_msec()+30000
		while (main.coordinator.is_busy() or main.world.current_scale_id!=scale_id) and Time.get_ticks_msec()<deadline: await process_frame
		if main.world.current_scale_id!=scale_id:
			push_error("I18N_NATIVE_STAGE_FAILED "+scale_id)
			main._quit(2,true)
			return false
		main.set_solar_rate(0.0)
		if scale_id=="reef": main.explorer_panel.open_topic("coral_symbiosis")
		if scale_id=="atom": main.explorer_panel.open_topic("oxygen_atom")
		await capture("03-"+scale_id+"-en")
	root.get_node("AppLanguage").set_language("zh_CN",false)
	await capture("04-atom-zh")
	return true

func capture(label: String) -> void:
	for frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = output.path_join(label+".png")
	var error: Error = image.save_png(path)
	var controls: Array[Dictionary] = []
	_scan(main.hud,controls)
	var untranslated: Array[String] = []
	var han: RegEx = RegEx.new()
	han.compile("[\u3400-\u9fff]")
	if TranslationServer.get_locale().begins_with("en"):
		for control: Dictionary in controls:
			if han.search(control.text)!=null: untranslated.append(control.text)
	records.append({"untranslated_visible":untranslated,"label":label,"path":path,"saved":error==OK,"pixels":str(image.get_size()),"ui_scale":main.ui_scale,"logical_view":str(main.ui_view_size()),"controls":controls})

func _scan(node: Node, controls: Array[Dictionary]) -> void:
	if node is Control and node.is_visible_in_tree():
		var text: String = ""
		if node is Label or node is Button or node is RichTextLabel: text = node.text
		if not text.is_empty():
			controls.append({"path":str(node.get_path()),"class":node.get_class(),"text":text,"size":str(node.size),"minimum":str(node.get_combined_minimum_size())})
	for child: Node in node.get_children(): _scan(child,controls)
