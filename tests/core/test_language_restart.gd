extends SceneTree
## Three separate engine processes exercise the real autoload startup path.
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, value: bool) -> void:
	if not value: failures.append(label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/evidence/I18N-001"))
	var mode: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--restart-mode="): mode = argument.trim_prefix("--restart-mode=")
	var service: Node = root.get_node("AppLanguage")
	_check("isolated no-save config", "--no-save" in OS.get_cmdline_user_args() and service.preference_path.contains("i18n-restart-"))
	if not failures.is_empty(): quit(2); return
	match mode:
		"write-en":
			_check("save English",service.set_language("en")==OK)
		"read-en-write-zh":
			_check("English survived process restart",service.preference=="en" and service.active_locale=="en")
			_check("English actual translation",str(TranslationServer.translate("太阳系"))=="Solar System")
			_check("save Chinese",service.set_language("zh_CN")==OK)
		"read-zh":
			_check("Chinese survived process restart",service.preference=="zh_CN" and service.active_locale=="zh_CN")
			_check("Chinese actual translation",str(TranslationServer.translate("太阳系"))=="太阳系")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(service.preference_path))
		_:
			failures.append("unknown restart mode")
	var report: Dictionary = {"mode":mode,"pid":OS.get_process_id(),"preference":service.preference,"locale":service.active_locale,"failures":failures}
	FileAccess.open("res://docs/evidence/I18N-001/restart-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("LANGUAGE_RESTART ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
