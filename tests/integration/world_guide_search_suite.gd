extends Node
const Experience = preload("res://scenes/experience.tscn")
const Topics = preload("res://scripts/experience/learning_topics.gd")
var main: Node
var cases: Array[Dictionary] = []
var failures: Array[String] = []
var native: bool = DisplayServer.get_name()!="headless"
var captures: Array[String] = []
var directory: String = ""
var root: Window
func _ready() -> void:
	root=get_tree().root
	call_deferred("run")
func check(label: String, passed: bool) -> void:
	cases.append({"name":label,"passed":passed})
	if not passed: failures.append(label)
	FileAccess.open(directory.path_join("progress.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures},"\t")+"\n")
func visible_topics() -> Array[String]:
	var result: Array[String] = []
	for button: Button in main.world_guide.route_buttons:
		if button.is_visible_in_tree(): result.append(button.get_meta("guide_topic"))
	return result
func query(value: String) -> void:
	main.world_guide.search.text=value
	main.world_guide.search.text_changed.emit(value)
	for frame: int in range(3): await get_tree().process_frame
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world131-check="): directory=argument.trim_prefix("--world131-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(900,650)
	if native: root.unfocusable=true
	main=Experience.instantiate()
	root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	var deadline: int=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if main.coordinator!=null and main.coordinator.active_scene!=null and main.coordinator.active_scene.is_prepared(): break
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.open(true)
	await query("")
	check("all 41 registered actions retain registered scale and topic",visible_topics().size()==41)
	var registered: bool=true
	for button: Button in main.world_guide.route_buttons:
		var scale_id: String=button.get_meta("guide_scale")
		var topic_id: String=button.get_meta("guide_topic")
		registered=registered and main.Catalog.contains(scale_id)
		if not topic_id.is_empty(): registered=registered and Topics.for_scale(scale_id).any(func(t: Dictionary) -> bool: return t.id==topic_id)
	check("all actual route targets resolve",registered)
	check("no-save welcome reports temporary session",main.world_guide.context.text.contains("不保存进度") and not main.world_guide.context.text.contains("自动保存"))
	await capture("guide-all-compact")
	await query("海龟")
	check("Chinese animal query finds two distinct turtle lessons",visible_topics()==["turtle","turtle_surface"])
	await capture("guide-turtle-search")
	await query("呼吸")
	check("lesson title finds breathing even when button uses surfacing",visible_topics()==["turtle_surface"])
	await query("城市")
	check("category query retains all five city actions",visible_topics()==["runoff","crossing","traffic","solar_roof","street"])
	await query("海洋　海龟")
	check("multiple full-width separated terms narrow within category",visible_topics()==["turtle","turtle_surface"])
	await query("不存在的内容")
	check("empty result has visible recovery hint",visible_topics().is_empty() and main.world_guide.empty_results.visible and main.world_guide.result_count.text.contains("0 / 41"))
	await capture("guide-no-results")
	await query("")
	check("clearing restores every route and all seven cards",visible_topics().size()==41 and main.world_guide.cards.all(func(c: Dictionary) -> bool: return c.node.visible) and not main.world_guide.empty_results.visible)
	check("compact guide and search remain within viewport",main.world_guide.grid.columns==1 and main.world_guide.panel.get_global_rect().end.y<=650 and main.world_guide.search.get_global_rect().end.x<=900 and main.world_guide.search.get_global_rect().size.y>=40)
	await query("月相")
	var before: float=main.world.simulation_time_s
	var event: InputEventKey=InputEventKey.new()
	event.keycode=KEY_SPACE
	event.pressed=true
	main.world_guide.search.grab_focus()
	main._input(event)
	check("guide text input leaves world pause and time unchanged",main.world.paused and main.world.simulation_time_s==before)
	for button: Button in main.world_guide.route_buttons:
		if button.is_visible_in_tree() and button.get_meta("guide_topic")=="lunar_phases":
			button.pressed.emit()
			break
	deadline=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if main.world.current_scale_id=="earth_moon" and not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared(): break
	for frame: int in range(4): await get_tree().process_frame
	check("filtered button still enters real lunar lesson",main.world.current_scale_id=="earth_moon" and not main.world_guide.visible and main.explorer_panel._topic.get("id","")=="lunar_phases")
	main.world_guide.open()
	await get_tree().process_frame
	check("reopening restores full overview",main.world_guide.search.text.is_empty() and visible_topics().size()==41)
	if native:
		root.size=Vector2i(1280,720)
		for frame: int in range(4): await get_tree().process_frame
		await capture("guide-all-wide")
	var report: Dictionary={"cases":cases,"failures":failures,"mode":"native rendering with real experience and GUI signals" if native else "headless real experience and GUI signals; not native IME input", "native_ime_tested":false, "debug_build":OS.is_debug_build(), "captures":captures,"performance_test":false}
	FileAccess.open(directory.path_join("search-native.json" if native else "search-functional.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("GUIDE_SEARCH_FUNCTIONAL ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	if not native: return
	for frame: int in range(4):
		await get_tree().process_frame
		RenderingServer.force_draw(false,0.0)
	var path: String=directory.path_join(label+".png")
	var error: Error=root.get_texture().get_image().save_png(path)
	check("capture "+label,error==OK)
	if error==OK: captures.append(path)
