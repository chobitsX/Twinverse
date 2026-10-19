extends "res://tests/integration/observation_framing_suite.gd"
const Browse = preload("res://scripts/experience/browse_observation.gd")
const Store = preload("res://scripts/core/world_store.gd")
var mode: String = ""
var save_directory: String = ""

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world108-check="): directory=argument.trim_prefix("--world108-check=")
		if argument.begins_with("--browse-mode="): mode=argument.trim_prefix("--browse-mode=")
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
	if not await arrive("woodland"):
		await finish()
		return
	main.ground_light_preview=false
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="browse": action=button
	check("twenty-four guide routes include the paired plot lesson",action!=null and main.world_guide.route_buttons.size()==24)
	if action!=null: action.pressed.emit()
	panel.browse_reset.pressed.emit()
	await settle()
	check("lesson selects real paired plots and retains existing species",main._content_follow==8 and main.content_targets().size()==9 and stage.get_meta("actors").size()==20 and stage.get_meta("pollinators").size()==4)
	var plots: Array = stage.get_meta("browse_plots")
	check("equal initial stocks reach real leaf geometry",main.world.browse.stock[0]==70. and main.world.browse.stock[1]==70. and absf(leaf_area(plots[0])-leaf_area(plots[1]))<.00001 and plots[0].leaves.size()==144)
	check("both plots and their live labels fit beside the panel",subject_visible(plots[0].root) and subject_visible(plots[1].root) and subject_visible(forager(stage)) and main.learning_overlay.last_visible_marks==2)
	await capture("browse-initial")
	await forward(60.)
	var doe: Node3D = forager(stage)
	check("one actual doe consumes the open plot while protected plot recovers",main.world.browse.eaten[0]>0 and main.world.browse.eaten[1]==0 and main.world.browse.stock[0]<40. and main.world.browse.stock[1]>85. and float(doe.get_meta("grazing"))>.7)
	check("lower stock visibly reduces real leaf surfaces",leaf_area(plots[0])<leaf_area(plots[1])*.5)
	check("protection mesh matches access state",not plots[0].cage.visible and plots[1].cage.visible)
	await capture("browse-open-versus-protected")
	var eaten: float = main.world.browse.eaten[0]
	var stock: float = main.world.browse.stock[0]
	panel.browse_protect.set_pressed_no_signal(true)
	panel.browse_protect.toggled.emit(true)
	await forward(2.)
	check("protect control stops intake raises head and closes the plot",main.world.browse.protected_left and main.world.browse.eaten[0]==eaten and float(doe.get_meta("grazing"))<.02 and plots[0].cage.visible)
	await forward(40.)
	check("the same depleted plot recovers without an automatic reset",main.world.browse.stock[0]>stock+20. and main.world.browse.eaten[0]==eaten and leaf_area(plots[0])>10.)
	await capture("browse-recovering")
	var frozen: Dictionary = main.world.browse.checkpoint()
	var head: Vector3 = main.coordinator.active_scene.get_meta("browse_plots")[0].leaves[0].scale
	await settle()
	check("pause freezes plot state and leaf geometry",main.world.browse.checkpoint()==frozen and plots[0].leaves[0].scale==head)
	if not await arrive("earth") or not await arrive("woodland"):
		await finish()
		return
	stage=main.coordinator.active_scene
	plots=stage.get_meta("browse_plots")
	check("scene reentry preserves consumed stock protection and ledger",main.world.browse.checkpoint()==frozen and plots[0].cage.visible)
	panel.show()
	panel.select_topic("browse")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact comparison keeps both plots and controls observable",subject_visible(plots[0].root) and subject_visible(plots[1].root) and subject_visible(forager(stage)) and panel.browse_controls.get_global_rect().end.y<panel.get_global_rect().end.y-12 and main.learning_overlay.last_visible_marks==2)
	await capture("browse-compact")
	main.save_button.pressed.emit()
	var store: Store = Store.new(save_directory)
	var loaded: Dictionary = store.load_session()
	check("production save button writes v5 browse stocks in isolated directory",loaded.status=="ok" and loaded.payload.world.version==5 and loaded.payload.world.woodland_browse.protected_left and absf(loaded.payload.world.woodland_browse.stock[0]-main.world.browse.stock[0])<1.e-9)
	FileAccess.open(save_directory.path_join("browse-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"time":main.world.simulation_time_s,"browse":main.world.browse.checkpoint()},"\t",true,true))
	await finish()

func forward(seconds: float) -> void:
	# Deterministic state sampling, not a wall-time or performance run.
	main.world.simulation_time_s+=seconds
	main.world.snapshot()
	await settle()

func forager(stage: Node) -> Node3D:
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind=="deer" and actor.index==7: return actor.node
	return null

func leaf_area(plot: Dictionary) -> float:
	var total: float = 0.
	for leaf: Node3D in plot.leaves: total+=leaf.scale.x*leaf.scale.x
	return total

func resume_check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_directory.path_join("browse-expected.json")))
	check("new release process restores woodland scale and paused time",main.world.current_scale_id=="woodland" and main.world.paused and main.world.simulation_time_s==expected.time)
	var state: Dictionary = main.world.browse.checkpoint()
	var exact: bool = state.protected_left==expected.browse.protected_left and state.steps==expected.browse.steps and absf(state.grazing-expected.browse.grazing)<1.e-10
	for key: String in ["stock","grown","eaten"]:
		for i: int in range(2): exact=exact and absf(state[key][i]-expected.browse[key][i])<1.e-9
	check("new process restores stocks fluxes and access without offline catchup",exact)
	var stage: Node = main.coordinator.active_scene
	main.explorer_panel.show()
	main.explorer_panel.select_topic("browse")
	await settle()
	check("restored scene renders protected plots and raised doe",stage.get_meta("browse_plots")[0].cage.visible and float(forager(stage).get_meta("grazing"))<.02)
	var before: float = main.world.browse.stock[0]
	await forward(4.)
	check("restored model continues recovery from saved depleted stock",main.world.browse.stock[0]>before and main.world.browse.stock[0]<main.world.browse.stock[1])
	await capture("browse-resumed")
	await finish()
