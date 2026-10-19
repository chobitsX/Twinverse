extends SceneTree
## Full static content providers, without constructing 3D scenes or advancing time.
const Catalog = preload("res://scripts/core/scale_catalog.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")
const Science = preload("res://scripts/experience/science_reference.gd")
const Species = preload("res://scripts/experience/species_catalog.gd")
const Relations = preload("res://scripts/experience/ecology_relations.gd")
const Text = preload("res://scripts/core/app_text.gd")
var failures: Array[String] = []
var checks: int = 0
var han: RegEx = RegEx.new()
func _initialize() -> void:
	_run.call_deferred()
func _check(label: String, value: bool) -> void:
	checks += 1
	if not value: failures.append(label)
func _no_han(value: Variant) -> bool:
	if value is String or value is StringName: return han.search(str(value))==null
	if value is Array:
		for item: Variant in value:
			if not _no_han(item): return false
	if value is Dictionary:
		for key: Variant in value:
			if not _no_han(value[key]): return false
	return true
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/evidence/I18N-001"))
	han.compile("[\u3400-\u9fff]")
	var language: Node = root.get_node("AppLanguage")
	language.set_language("zh_CN",false)
	var originals: Dictionary = {}
	for id: String in Catalog.SCALES: originals[id] = Topics.for_scale(id)
	language.set_language("en",false)
	var topics_checked: int = 0
	for id: String in Catalog.SCALES:
		var translated: Array[Dictionary] = Topics.for_scale(id)
		_check(id+" topic count retained",translated.size()==originals[id].size())
		_check(id+" all topic prose English",_no_han(translated))
		_check(id+" science notes English",_no_han(Science.describe(id)) and _no_han(Science.text_for(id)))
		for index: int in range(translated.size()):
			topics_checked += 1
			for field: String in ["id","follow","target_id","view_distance","source"]:
				_check(id+"/"+str(index)+" "+field+" invariant",translated[index].get(field)==originals[id][index].get(field))
	for branch: String in Relations.BRANCHES:
		_check(branch+" relationship text English",_no_han(Relations.for_branch(branch)))
	_check("All species prose English",_no_han(Text.dictionaries(Species.ENTRIES)))
	_check("Species stable IDs retained",Text.dictionaries(Species.ENTRIES).map(func(item: Dictionary) -> String: return item.id)==Species.ENTRIES.map(func(item: Dictionary) -> String: return item.id))
	var report: Dictionary = {"checks":checks,"topics":topics_checked,"scales":Catalog.SCALES.size(),"species":Species.ENTRIES.size(),"failures":failures,"scope":"all static content providers; not a replacement for dynamic/visual checks"}
	FileAccess.open("res://docs/evidence/I18N-001/content-providers.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("I18N_CONTENT_PROVIDERS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
