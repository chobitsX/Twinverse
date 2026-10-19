extends Control
## Read-only display of the world's evaluated local phase; no timer or model.
const Traffic = preload("res://scripts/core/city_traffic.gd")
var state: Dictionary = {}

func _init() -> void:
	custom_minimum_size=Vector2(0,24)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func present(value: Dictionary) -> void:
	state=value
	queue_redraw()

func _draw() -> void:
	if state.is_empty(): return
	var total: float=float(state.period_s)
	var clear: float=float(state.clear_end_s)
	var spans: Array[float]=[0.0,20.0,24.0,clear,total]
	var colors: Array[Color]=[Color(.18,.65,.38),Color(.33,.37,.42),Color(.18,.55,.76),Color(.33,.37,.42)]
	for index: int in range(4):
		var left: float=size.x*spans[index]/total
		var right: float=size.x*spans[index+1]/total
		draw_rect(Rect2(left,5,right-left-1,14),colors[index])
	var at: float=size.x*float(state.phase_s)/total
	draw_line(Vector2(at,1),Vector2(at,23),Color(.94,.97,1.0),2.0)
