extends Node3D

@export var reject_binding: bool = false
var bound_snapshot: Dictionary = {}
var bound_scale: String = ""


func bind_world(snapshot: Dictionary, scale_id: String) -> bool:
	bound_snapshot = snapshot.duplicate(true)
	bound_scale = scale_id
	return not reject_binding and snapshot.has("target_fish_id")
