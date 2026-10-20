extends "res://tests/core/test_world_store.gd"
## Real CLI startup with isolated fresh/saved sessions; no user world is read.
const ExperienceScene: PackedScene = preload("res://scenes/experience.tscn")

func _run() -> void:
	root.size=Vector2i(1280,800)
	var scenario: String = "fresh"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world-dir="): test_directory=arg.trim_prefix("--world-dir=")
		if arg.begins_with("--startup-case="): scenario=arg.trim_prefix("--startup-case=")
		if arg.begins_with("--startup-report="): report_path=arg.trim_prefix("--startup-report=")
	if not test_directory.is_absolute_path() or not "/.local/verification/startup-288/" in test_directory:
		quit(2); return
	var store: Store = Store.new(test_directory)
	_check("isolated session starts empty",store.load_session().status=="missing")
	var original: String = ""
	if scenario!="fresh":
		var saved: Dictionary=_payload(123.5)
		saved.world.current_scale_id="galaxy"
		saved.world.paused=true
		var view: Dictionary=saved.observer.views.fish.duplicate(true)
		saved.observer.views={"galaxy":view,"universe":{"position":[99.0,44.0,35.0],"target":[0.0,0.0,0.0],"up":[0.0,1.0,0.0],"cutaway":true,"heart_region":"","info_visible":false}}
		saved.observer.preferences.render_ratio=.5
		saved.observer.preferences.muted=true
		_check("legacy galaxy session saves",store.save_session(saved)=="ok")
		original=FileAccess.get_file_as_string(test_directory.path_join("current.json"))
	var main: Node=ExperienceScene.instantiate()
	root.add_child(main)
	var expected: String="earth" if scenario=="explicit" else "universe"
	_check("requested entry is installed",main._start_scale==expected and main.world.current_scale_id==expected and main.coordinator.active_scene.scale_id==expected)
	_check("guide does not cover the initial world",not main.world_guide.visible)
	_check("initial authority has the universe default",WorldState.new().current_scale_id=="universe")
	if scenario!="fresh":
		_check("world time remains frozen on resume",is_equal_approx(main.world.simulation_time_s,123.5) and main.world.paused)
		_check("quality and audio preferences survive",is_equal_approx(main._render_ratio,.5) and main._muted and is_equal_approx(main.soundscape.master,.2))
		_check("other observer views remain available",main._views.has("galaxy") and main._views.galaxy.position==[0.0,1.0,2.0])
		_check("opening does not rewrite the saved file",FileAccess.get_file_as_string(test_directory.path_join("current.json"))==original)
	if expected=="universe":
		var stage: Node=main.coordinator.active_scene
		_check("universe starts at its overview camera",stage.camera.position.is_equal_approx(stage.default_position) and main._orbit_target.is_equal_approx(stage.default_target))
	var file: FileAccess=FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scenario":scenario,"expected":expected,"cases":cases,"failures":failures,"user_world_accessed":false,"performance_test":false},"\t")+"\n");file.close()
	print("STARTUP_ENTRY_FINISHED ",scenario," ",failures)
	main._quit(0 if failures.is_empty() else 1)
