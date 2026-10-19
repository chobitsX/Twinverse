extends "res://scripts/experience/experience.gd"
## Only the embedded asset diagnostic uses this subclass. Product availability
## handling stays unchanged; hidden SubViewports render without desktop focus.
func _sync_window_availability() -> void:
	if world!=null:world.set_foreground(true)
	Engine.max_fps=5
