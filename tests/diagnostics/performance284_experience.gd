extends "res://tests/diagnostics/ecology269_experience.gd"
## Visual comparison only; bounded 5 FPS and no-save enforced by the suite.
func _path_for(id: String) -> String:
	if "--performance284-legacy-resources" in OS.get_cmdline_user_args():
		return "res://scenes/experience/%s_stage.tscn" % STAGE_PATHS.get(id, "ocean")
	return super._path_for(id)
