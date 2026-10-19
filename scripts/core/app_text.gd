extends RefCounted
## Only presentation values are localized. Dictionary keys and numeric data stay intact.
## Cached by locale: no repeated deep copy when menus read a constant catalog.
static var source_depth: int = 0
static var _locale: String = ""
static var _cache: Dictionary = {}

static func text(source: String) -> String:
	if source_depth > 0: return source
	var translated: String = TranslationServer.translate(source)
	if translated != source or not source.contains("\n"): return translated
	# Metadata may join separately authored paragraphs. Translate whole messages first.
	var parts: PackedStringArray = source.split("\n\n")
	if parts.size() > 1:
		for index: int in range(parts.size()): parts[index] = text(parts[index])
		return "\n\n".join(parts)
	parts = source.split("\n")
	for index: int in range(parts.size()): parts[index] = str(TranslationServer.translate(parts[index]))
	return "\n".join(parts)

static func dictionary(source: Dictionary) -> Dictionary:
	return _localized(source)

static func array(source: Array) -> Array:
	return _localized(source)

static func strings(source: Array[String]) -> Array[String]:
	var result: Array[String] = []
	result.assign(_localized(source))
	return result

static func dictionaries(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_localized(source))
	return result

static func present_dictionaries(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_walk(source))
	return result

static func _localized(source: Variant) -> Variant:
	if source_depth > 0: return source
	var locale: String = TranslationServer.get_locale()
	if locale != _locale:
		_cache.clear()
		_locale = locale
	var key: int = hash(source)
	if _cache.has(key) and _cache[key].source == source: return _cache[key].value
	var value: Variant = _walk(source)
	_cache[key] = {"source":source,"value":value}
	return value

static func _walk(source: Variant) -> Variant:
	if source is String: return text(source)
	if source is Dictionary:
		var result: Dictionary = {}
		for key: Variant in source: result[key] = _walk(source[key])
		if source.has("label_message"): result["label"] = _render_message(source.label_message,true)
		return result
	if source is Array:
		var result: Array = []
		for item: Variant in source: result.append(_walk(item))
		return result
	return source

## Scientific metadata keeps its original string for existing readers/tests.
## The scene owns a small message description for correct runtime translation.
static func set_meta_text(node: Node, key: String, message: Variant) -> void:
	node.set_meta(key, _render_message(message, false))
	node.set_meta("_i18n_"+key, message)

static func meta_message(node: Node, key: String, fallback: Variant = "") -> Variant:
	return node.get_meta("_i18n_"+key, node.get_meta(key, fallback))

static func meta_text(node: Node, key: String, fallback: Variant = "") -> String:
	return _render_message(meta_message(node,key,fallback), true)

static func _render_message(message: Variant, translate: bool) -> String:
	if message is Dictionary and message.has("parts"):
		var parts: PackedStringArray = []
		for part: Variant in message.parts: parts.append(_render_message(part,translate))
		return "".join(parts)
	if message is Dictionary and message.has("format"):
		var template: String = text(str(message.format)) if translate else str(message.format)
		return template % (_walk(message.args) if translate else message.args)
	return text(str(message)) if translate else str(message)

static func format_text(template: String, values: Variant) -> String:
	return text(template) % _walk(values)
