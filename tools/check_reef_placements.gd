extends SceneTree
## Validate the mode the runtime will actually use. A supported computed layout
## does not depend on obsolete animals recorded by the original full-stage bake.
const Data = preload("res://assets/data/reef/placements_v1.res")
const Builder = preload("res://scripts/experience/ocean_builder.gd")
const Ocean = preload("res://scenes/experience/ocean_stage.tscn")

static func inspect(stage: Node, data: Resource = Data) -> Dictionary:
	var failures: Array[String] = []
	var paths: Dictionary = {}
	for i: int in range(stage.asset_keys.size()):
		if i >= stage.asset_scenes.size() or stage.asset_scenes[i] == null:
			failures.append("Missing current scene asset: " + stage.asset_keys[i]); continue
		paths[stage.asset_keys[i]] = stage.asset_scenes[i].resource_path
	var layout: Array[Dictionary] = Builder.reef_layout()
	if layout.size() != 140: failures.append("Incomplete current placement recipe")
	var required: Dictionary = {"rock_low": true, "rock_high": true, "anemone_high": true, "anemone_low": true}
	for placement: Dictionary in layout:
		var key: String = "growth_rock" if placement.family == "rock" else str(placement.asset_key)
		required[key+"_high"]=true; required[key+"_low"]=true
	for key: String in required:
		if not paths.has(key) or not FileAccess.file_exists(paths.get(key,"")):
			failures.append("Missing placement dependency: " + key)
	var baked: bool = data.layout_version == Builder.PLACEMENT_VERSION and data.layout.size() == 140 and data.rubble_by_patch.size() == Builder.REEF_PATCHES.size()
	for key: String in data.asset_paths:
		if paths.get(key,"") != data.asset_paths[key]: baked=false
	var checked: int = 0
	if baked:
		# In cached mode geometry really must match the recorded inputs.
		for key: String in required:
			var path: String = str(paths.get(key,""))
			for source: String in [path,path+".import"]:
				var expected: String = str(data.source_sha256.get(source.trim_prefix("res://"),""))
				if expected.is_empty() or FileAccess.get_sha256(source) != expected:
					failures.append("Cached placement input changed: " + source)
				checked+=1
		for i: int in range(layout.size()):
			for key: String in ["family","asset_key","patch","foundation","basis","scale","footprint","tint","rejection_fallback"]:
				if layout[i].get(key) != data.layout[i].get(key): failures.append("Cached recipe differs: %d/%s" % [i,key])
			if not is_equal_approx(layout[i].position.x,data.layout[i].position.x) or not is_equal_approx(layout[i].position.z,data.layout[i].position.z):
				failures.append("Cached horizontal placement differs: " + str(i))
		var rubble: int = 0
		for group: Dictionary in data.rubble_by_patch: rubble+=group.transforms.size()
		if rubble != 216: failures.append("Incomplete cached rubble")
	return {"status":"passed" if failures.is_empty() else "failed","placement_mode":"baked" if baked else "computed",
		"current_asset_count":paths.size(),"placement_dependency_count":required.size(),"checked_cached_sources":checked,
		"scope":"Resource/recipe preflight. Computed mode is the existing runtime fallback and needs first-entry preparation; this is not a contact or performance revalidation.","failures":failures}

func _initialize() -> void:
	var stage: Node = Ocean.instantiate()
	var report: Dictionary = inspect(stage)
	stage.free()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 1 and args[0].is_absolute_path():
		FileAccess.open(args[0],FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
