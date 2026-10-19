extends Node
## App-level presentation preference. Never enters a world checkpoint.
signal language_changed(locale: String)
const CATALOG_PATH: String = "res://localization/en.json"
const PREFERENCE_PATH: String = "user://language.cfg"
const SUPPORTED: Array[String] = ["auto", "zh_CN", "en"]
var preference: String = "auto"
var active_locale: String = "en"
var preference_path: String = PREFERENCE_PATH
var _chinese: Translation
var _english: Translation

func _enter_tree() -> void:
	_chinese = Translation.new()
	_chinese.locale = "zh_CN"
	_english = Translation.new()
	_english.locale = "en"
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if catalog is Dictionary:
		for source: String in catalog:
			if catalog[source] is String and not str(catalog[source]).is_empty():
				_english.add_message(source, str(catalog[source]))
				_chinese.add_message(source, source)
	else:
		push_error("Invalid local translation catalog: " + CATALOG_PATH)
	TranslationServer.add_translation(_english)
	TranslationServer.add_translation(_chinese)
	# Explicit isolated config for no-save diagnostics, including exported-app checks.
	if "--no-save" in OS.get_cmdline_user_args():
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--language-config="):
				preference_path = argument.trim_prefix("--language-config=")
	var config: ConfigFile = ConfigFile.new()
	if config.load(preference_path) == OK:
		var saved: String = str(config.get_value("interface", "language", "auto"))
		if saved in SUPPORTED: preference = saved
	# Non-persistent diagnostic override, independent of world save protection.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--language="):
			var value: String = argument.trim_prefix("--language=")
			if value in SUPPORTED: preference = value
	_apply()

static func resolve_locale(value: String, system_locale: String) -> String:
	if value == "zh_CN" or value == "en": return value
	return "zh_CN" if system_locale.replace("-", "_").to_lower().begins_with("zh") else "en"

func set_language(value: String, persist: bool = true) -> Error:
	if value not in SUPPORTED: return ERR_INVALID_PARAMETER
	if persist:
		var config: ConfigFile = ConfigFile.new()
		config.set_value("interface", "language", value)
		var error: Error = config.save(preference_path)
		if error != OK: return error
	preference = value
	_apply()
	language_changed.emit(active_locale)
	return OK

func _apply() -> void:
	active_locale = resolve_locale(preference, OS.get_locale())
	TranslationServer.set_locale(active_locale)

func _exit_tree() -> void:
	TranslationServer.remove_translation(_english)
	TranslationServer.remove_translation(_chinese)
