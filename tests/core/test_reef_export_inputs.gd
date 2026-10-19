extends SceneTree
const Check = preload("res://tools/check_reef_placements.gd")
func _initialize() -> void:
	var stage: Node=Check.Ocean.instantiate()
	var cases: Array[Dictionary]=[]
	for i: int in range(stage.asset_keys.size()):stage.assets[stage.asset_keys[i]]=stage.asset_scenes[i]
	var actual: Dictionary=Check.inspect(stage)
	cases.append({"case":"current resource set is valid and reports existing computed mode","passed":actual.failures.is_empty() and actual.placement_mode=="computed" and not Check.Builder._bake_matches(stage)})
	var index: int=stage.asset_keys.find("growth_rock_high")
	var original: PackedScene=stage.asset_scenes[index]
	stage.asset_scenes[index]=null
	cases.append({"case":"missing real placement geometry blocks export","passed":not Check.inspect(stage).failures.is_empty()})
	stage.asset_scenes[index]=original
	# Emulate a matching cache while retaining the verified original geometry.
	var data: Resource=Check.Data.duplicate(true)
	data.asset_paths.clear()
	for i: int in range(stage.asset_keys.size()):data.asset_paths[stage.asset_keys[i]]=stage.asset_scenes[i].resource_path
	var cached: Dictionary=Check.inspect(stage,data)
	cases.append({"case":"matching cache verifies active geometry and recipe","passed":cached.placement_mode=="baked" and cached.failures.is_empty() and cached.checked_cached_sources>0})
	data.source_sha256[original.resource_path.trim_prefix("res://")]='invalid'
	cases.append({"case":"changed cached geometry cannot silently pass","passed":not Check.inspect(stage,data).failures.is_empty()})
	stage.free()
	var passed: bool=true
	for item: Dictionary in cases:passed=passed and item.passed
	print(JSON.stringify({"cases":cases,"passed":passed}))
	quit(0 if passed else 1)
