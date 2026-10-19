extends SceneTree
## Isolated preference files: do not change the user's language or world save.
const Language = preload("res://scripts/core/app_language.gd")
const Text = preload("res://scripts/core/app_text.gd")
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var path: String = "user://i18n-test-%d.cfg" % OS.get_process_id()

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, passed: bool) -> void:
	cases.append({"case":label,"passed":passed})
	if not passed: failures.append(label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/evidence/I18N-001"))
	for system_locale: String in ["zh", "zh_CN", "zh_TW", "zh-Hant-HK"]:
		_check("Chinese system: " + system_locale, Language.resolve_locale("auto",system_locale)=="zh_CN")
	for system_locale: String in ["en_US", "de_DE", "ja_JP", "", "fr"]:
		_check("English fallback: " + system_locale, Language.resolve_locale("auto",system_locale)=="en")
	_check("Explicit English overrides system",Language.resolve_locale("en","zh_CN")=="en")
	_check("Explicit Chinese overrides system",Language.resolve_locale("zh_CN","en_US")=="zh_CN")
	var service: Node = Language.new()
	service.preference_path = path
	root.add_child(service)
	_check("Select English",service.set_language("en")==OK)
	_check("Catalog translation",Text.text("太阳系")=="Solar System")
	_check("Unknown text stays intact",Text.text("J2000 · km")=="J2000 · km")
	_check("Formatted template",(Text.text("每世界秒 %s 天") % "10")=="10 days per world second")
	var original: Dictionary = {"id":"unchanged-id","name":"太阳系","value":42.25,"nested":["地球",7]}
	var localized: Dictionary = Text.dictionary(original)
	_check("Nested presentation translated",localized.name=="Solar System" and localized.nested[0]=="Earth")
	_check("IDs and numbers retained",localized.id==original.id and localized.value==42.25 and localized.nested[1]==7)
	_check("Source dictionary not mutated",original.name=="太阳系" and original.nested[0]=="地球")
	Text.source_depth += 1
	_check("Authoring scope retains source",Text.text("地球")=="地球" and Text.dictionary(original).name=="太阳系")
	Text.source_depth -= 1
	var metadata: Node = Node.new()
	Text.source_depth += 1
	Text.set_meta_text(metadata,"content_summary",{"parts":["海洋","\n",{"format":"每世界秒 %s 天","args":"10"}]})
	Text.source_depth -= 1
	var canonical: String = str(metadata.get_meta("content_summary"))
	_check("Composed metadata translates as messages",Text.meta_text(metadata,"content_summary")=="Ocean\n10 days per world second")
	_check("Metadata source stays a canonical String",canonical=="海洋\n每世界秒 10 天")
	service.free()
	var reopened: Node = Language.new()
	reopened.preference_path = path
	root.add_child(reopened)
	_check("Reopened preference persists",reopened.preference=="en" and reopened.active_locale=="en")
	_check("Chinese round trip",reopened.set_language("zh_CN")==OK and Text.text("太阳系")=="太阳系")
	_check("Locale invalidates presentation cache",Text.dictionary(original).name=="太阳系")
	_check("Metadata restores Chinese without changing source",Text.meta_text(metadata,"content_summary")==canonical)
	var valid_path: String = reopened.preference_path
	reopened.preference_path = "user://missing-language-parent-%d/preference.cfg" % OS.get_process_id()
	_check("Save failure retains language",reopened.set_language("en")!=OK and reopened.preference=="zh_CN")
	reopened.preference_path = valid_path
	_check("Invalid preference rejected",reopened.set_language("invalid")==ERR_INVALID_PARAMETER and reopened.preference=="zh_CN")
	_check("Preview switch does not persist",reopened.set_language("en",false)==OK)
	_check("Metadata re-renders after locale change",Text.meta_text(metadata,"content_summary")=="Ocean\n10 days per world second")
	metadata.free()
	reopened.free()
	var disk: ConfigFile = ConfigFile.new()
	_check("Saved Chinese remains after nonpersistent switch",disk.load(path)==OK and disk.get_value("interface","language")=="zh_CN")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var output: FileAccess = FileAccess.open("res://docs/evidence/I18N-001/language-service.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"cases":cases,"failures":failures},"\t")+"\n")
	print("I18N language service: %d checks, %d failures" % [cases.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
