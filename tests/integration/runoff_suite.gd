extends "res://tests/integration/observation_framing_suite.gd"
const Runoff = preload("res://scripts/experience/runoff_observation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")
const Store = preload("res://scripts/core/world_store.gd")
var mode: String = ""
var save_directory: String = ""

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world110-check="): directory=argument.trim_prefix("--world110-check=")
		if argument.begins_with("--runoff-mode="): mode=argument.trim_prefix("--runoff-mode=")
		if argument.begins_with("--world-dir="): save_directory=argument.trim_prefix("--world-dir=")
	if not directory.is_absolute_path() or not save_directory.is_absolute_path() or mode not in ["write","resume"] or save_directory==ProjectSettings.globalize_path("user://world"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless" and DisplayServer.get_screen_count()==1:
		main._measurement_screen=get_window().current_screen
		get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	if DisplayServer.get_name()!="headless":
		var stable_since: int = Time.get_ticks_msec()
		var deadline: int = stable_since+10000
		while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since=Time.get_ticks_msec()
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	get_window().size=Vector2i(1280,720)
	if mode=="resume":
		await resume_check()
		return
	if not await arrive("city"):
		await finish()
		return
	main.ground_light_preview=false
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="runoff": action=button
	check("twenty-seven guide routes include urban rainfall",action!=null and main.world_guide.route_buttons.size()==27)
	if action!=null: action.pressed.emit()
	panel.runoff_reset.pressed.emit()
	await settle()
	var plots: Array = stage.get_meta("runoff_plots")
	check("new lesson selects paired surfaces without changing people or cars",main._content_follow==6 and main.content_targets().size()==7 and stage.get_meta("actors").size()==40 and plots.size()==2 and panel._topic.get("id","")=="runoff")
	check("dry initial model renders no rain flow or soil water",main.world.runoff.rain_mm==0. and visible_count(plots[0].drops)==0 and visible_count(plots[0].flow)==0 and not plots[1].storage.visible)
	check("both equal area surfaces and three labels fit beside panel",subject_visible(plots[0].root) and subject_visible(plots[1].root) and main.learning_overlay.last_visible_marks==3)
	check("lesson identifies acceleration and uncalibrated hydrology",panel.lesson_text.text.contains("1世界秒") and panel.lesson_text.text.contains("不是实际滴数或水深") and Reference.describe("city").sources.size()==3 and Reference.allows_url("city",Runoff.Model.SOURCE))
	await capture("runoff-dry-surfaces")
	panel.runoff_rain.set_pressed_no_signal(true)
	panel.runoff_rain.toggled.emit(true)
	await forward(15.)
	check("rain control supplies identical rain to both real surfaces",main.world.runoff.raining and absf(main.world.runoff.rain_mm*9.-81.)<.000001 and visible_count(plots[0].drops)==32 and visible_count(plots[1].drops)==32)
	check("hard surface releases flow while green surface initially absorbs rain",main.world.runoff.runoff[0]>8. and main.world.runoff.runoff[1]==0. and visible_count(plots[0].flow)==10 and visible_count(plots[1].flow)==0 and visible_count(plots[1].soaking)==8 and plots[1].storage.visible)
	check("early soil storage is visibly partial",plots[1].storage.scale.y>50. and plots[1].storage.scale.y<60. and not plots[0].storage.visible)
	check("soil storage section actually renders in front of vegetation",await soil_section_pixels(plots[1].storage))
	await capture("runoff-rain-infiltration")
	await forward(30.)
	check("finite soil storage fills and actual green runoff symbols appear",absf(main.world.runoff.soil[1]-12.)<.000001 and main.world.runoff.runoff[1]>10. and visible_count(plots[1].flow)==10 and plots[1].storage.scale.y>69.)
	check("both captured balances account for rain without double counting infiltration",balanced())
	await capture("runoff-saturated-green")
	var drop: Vector3 = plots[0].drops[0].position
	var frozen: Dictionary = main.world.runoff.checkpoint()
	await settle()
	check("pause freezes rainfall positions and all water stores",main.world.runoff.checkpoint()==frozen and plots[0].drops[0].position.is_equal_approx(drop))
	var rain: float = main.world.runoff.rain_mm
	var previous: float = main.world.runoff.surface[1]
	panel.runoff_rain.set_pressed_no_signal(false)
	panel.runoff_rain.toggled.emit(false)
	await forward(2.)
	check("turning rain off stops falling drops while existing water continues draining",main.world.runoff.rain_mm==rain and main.world.runoff.surface[1]<previous and visible_count(plots[0].drops)==0 and visible_count(plots[1].drops)==0 and visible_count(plots[1].flow)>0 and balanced())
	frozen=main.world.runoff.checkpoint()
	if not await arrive("earth") or not await arrive("city"):
		await finish()
		return
	stage=main.coordinator.active_scene
	plots=stage.get_meta("runoff_plots")
	check("leaving and returning preserves rain choice and every water ledger",main.world.runoff.checkpoint()==frozen and plots[1].storage.visible)
	panel.show()
	panel.select_topic("runoff")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact comparison keeps both plots controls and labels observable",subject_visible(plots[0].root) and subject_visible(plots[1].root) and panel.runoff_controls.get_global_rect().end.y<panel.get_global_rect().end.y-12 and main.learning_overlay.last_visible_marks==3)
	await capture("runoff-stopped-compact")
	main.save_button.pressed.emit()
	var store: Store = Store.new(save_directory)
	var loaded: Dictionary = store.load_session()
	check("production save writes v6 hydrology and existing browse state to isolated files",loaded.status=="ok" and loaded.payload.world.version==6 and not loaded.payload.world.urban_runoff.raining and absf(loaded.payload.world.urban_runoff.rain_mm-rain)<1.e-9 and loaded.payload.world.has("woodland_browse"))
	FileAccess.open(save_directory.path_join("runoff-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"time":main.world.simulation_time_s,"runoff":main.world.runoff.checkpoint(),"browse":main.world.browse.checkpoint()},"\t",true,true))
	await finish()

func forward(seconds: float) -> void:
	main.world.simulation_time_s+=seconds
	main.world.snapshot()
	await settle()

func visible_count(nodes: Array) -> int:
	var result: int = 0
	for node: Node3D in nodes:
		if node.is_visible_in_tree(): result+=1
	return result

func balanced() -> bool:
	var state: Dictionary = main.world.runoff.checkpoint()
	for i: int in range(2):
		if absf(state.rain_mm-state.surface[i]-state.soil[i]-state.runoff[i]-state.drained[i])>1.e-8: return false
	return true

func resume_check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_directory.path_join("runoff-expected.json")))
	check("new process restores city and exact paused world time",main.world.current_scale_id=="city" and main.world.paused and main.world.simulation_time_s==expected.time)
	var state: Dictionary = main.world.runoff.checkpoint()
	var exact: bool = not state.raining and state.steps==expected.runoff.steps and absf(state.rain_mm-expected.runoff.rain_mm)<1.e-9
	for key: String in ["surface","soil","infiltrated","runoff","drained","last_infiltration","last_runoff"]:
		for i: int in range(2): exact=exact and absf(state[key][i]-expected.runoff[key][i])<1.e-9
	check("new process restores every water store and flow without offline catchup",exact)
	check("new model leaves saved woodland consumption intact",absf(main.world.browse.stock[0]-expected.browse.stock[0])<1.e-9 and main.world.browse.steps==expected.browse.steps)
	var stage: Node = main.coordinator.active_scene
	main.explorer_panel.show()
	await settle()
	main.explorer_panel.select_topic("runoff")
	await settle()
	var plots: Array = stage.get_meta("runoff_plots")
	check("restored surface and soil section match saved rain-off state",plots[1].storage.visible and visible_count(plots[1].drops)==0 and main.explorer_panel._topic.get("id","")=="runoff")
	var rain: float = state.rain_mm
	var drained: float = state.drained[1]
	await forward(5.)
	check("restored water continues draining from the saved ledger",main.world.runoff.drained[1]>drained and main.world.runoff.rain_mm==rain and balanced())
	await capture("runoff-resumed-drainage")
	await finish()

func soil_section_pixels(section: MeshInstance3D) -> bool:
	var stage: Node = main.coordinator.active_scene
	main.set_process(false)
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var shown: Image = stage.viewport.get_texture().get_image()
	var center: Vector2i = Vector2i(stage.camera.unproject_position(section.global_position))
	section.hide()
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var hidden: Image = stage.viewport.get_texture().get_image()
	section.show()
	var pixels: int = 0
	for y: int in range(maxi(0,center.y-5),mini(shown.get_height(),center.y+6)):
		for x: int in range(maxi(0,center.x-10),mini(shown.get_width(),center.x+11)):
			var a: Color = shown.get_pixel(x,y)
			var b: Color = hidden.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.04: pixels+=1
	main.set_process(true)
	await settle()
	print("SOIL_SECTION_PIXELS ",pixels)
	return pixels>=8
