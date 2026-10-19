extends "res://tests/core/fixture.gd"

@export var preparation_frames: int = 3
@export var never_prepared: bool = false
var observed_frames: int = 0


func _process(_delta: float) -> void:
	observed_frames += 1


func is_prepared() -> bool:
	return not never_prepared and observed_frames >= preparation_frames
