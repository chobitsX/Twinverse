extends SceneTree
## Bounded functional check of language refresh using the actual scene/HUD.
const Experience = preload("res://scenes/experience.tscn")
const Topics = preload("res://scripts/experience/learning_topics.gd")
var checks: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, passed: bool) -> void:
	checks.append({"case":label,"passed":passed})
	if not passed: failures.append(label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/evidence/I18N-001"))
	if not "--no-save" in OS.get_cmdline_user_args(): quit(2); return
	var language: Node = root.get_node("AppLanguage")
	var initial: String = "zh_CN"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--i18n-initial="): initial = argument.trim_prefix("--i18n-initial=")
	language.set_language(initial,false)
	create_timer(40).timeout.connect(func() -> void: quit(2))
	var previous_path: String = language.preference_path
	language.preference_path = "user://i18n-ui-%d.cfg" % OS.get_process_id()
	var main: Node = Experience.instantiate()
	root.add_child(main)
	main.world.set_paused(true)
	main.set_solar_rate(0.0)
	main.world_guide.hide()
	var deadline: int = Time.get_ticks_msec()+15000
	while not main.coordinator.active_scene.is_prepared() and Time.get_ticks_msec()<deadline:
		await process_frame
	_check("Scene ready",main.coordinator.active_scene.is_prepared())
	var selected_topic: String = ""
	var topics: Array[Dictionary] = Topics.for_scale(main.world.current_scale_id)
	if not topics.is_empty():
		selected_topic = str(topics[0].id)
		main.world.set_foreground(true)
		main.explorer_panel.open_topic(selected_topic)
	var marker_branch: String = main.learning_overlay.branch
	var world_id: int = main.world.get_instance_id()
	var stage_id: int = main.coordinator.active_scene.get_instance_id()
	var date: float = main.solar_jd
	var time: float = main.world.simulation_time_s
	var pose: Vector3 = main.coordinator.active_scene.camera.position
	main.world_guide.show()
	main.world_guide.search.text = "moon"
	main.immersive_interface._menu_action(22)
	await process_frame
	await process_frame
	_check("English catalog active",TranslationServer.translate("太阳系")=="Solar System")
	_check("Visible guide remains open",main.world_guide.visible)
	_check("Guide context retranslated",not main.world_guide.context.text.is_empty())
	_check("Marker branch retained",main.learning_overlay.branch==marker_branch)
	_check("Search retained",main.world_guide.search.text=="moon")
	_check("Same world and stage",main.world.get_instance_id()==world_id and main.coordinator.active_scene.get_instance_id()==stage_id)
	_check("Date and time retained",main.solar_jd==date and main.world.simulation_time_s==time)
	_check("Camera retained",main.coordinator.active_scene.camera.position.is_equal_approx(pose))
	_check("English navigation",main.world_guide.title.text=="Explore the world")
	if not selected_topic.is_empty():
		_check("Selected lesson retained in English",main.explorer_panel._topic.get("id","")==selected_topic and main.explorer_panel.topic_picker.selected>0 and not main.explorer_panel.lesson_text.text.is_empty())
		var han: RegEx = RegEx.new()
		han.compile("[\u3400-\u9fff]")
		_check("Selected lesson has no Chinese in English",han.search(main.explorer_panel.lesson_text.text)==null)
	if main.world.current_scale_id == "solar_system":
		_check("English object name",str(main.content_targets()[0].label)=="Sun")
	if main.coordinator.active_scene.has_meta("marine_actors"):
		var actor: Dictionary = main.coordinator.active_scene.get_meta("marine_actors")[0]
		_check("Scene metadata remains canonical",str(actor.label).contains("褐吊"))
		_check("English object presentation",str(main.content_targets()[0].label).contains("Brown tang"))
	main.immersive_interface._menu_action(21)
	await process_frame
	await process_frame
	_check("Chinese round trip",main.world_guide.title.text=="探索世界")
	if not selected_topic.is_empty():
		_check("Selected lesson retained in Chinese",main.explorer_panel._topic.get("id","")==selected_topic and main.explorer_panel.topic_picker.selected>0 and not main.explorer_panel.lesson_text.text.is_empty())
	if main.world.current_scale_id == "solar_system":
		_check("Chinese object name restored",str(main.content_targets()[0].label)=="太阳")
	if main.coordinator.active_scene.has_meta("marine_actors"):
		_check("Chinese object presentation restored",str(main.content_targets()[0].label).contains("褐吊"))
	_check("No world persistence",not main._persistence_enabled)
	var saved: ConfigFile = ConfigFile.new()
	_check("Menu persists Chinese preference",saved.load(language.preference_path)==OK and saved.get_value("interface","language")=="zh_CN")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(language.preference_path))
	language.preference_path = previous_path
	var file: FileAccess = FileAccess.open("res://docs/evidence/I18N-001/ui-smoke-final-"+main.world.current_scale_id+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scale":main.world.current_scale_id,"initial_locale":initial,"checks":checks,"failures":failures},"\t")+"\n")
	print("I18N UI smoke: %d checks, %d failures" % [checks.size(),failures.size()])
	main._quit(0 if failures.is_empty() else 1,true)
