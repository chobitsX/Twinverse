extends Node
## Presentation budget only: never change world time or the simulation timestep.
const FOREGROUND_FPS: int = 30
const BACKGROUND_FPS: int = 5
var _requested_cap: int = FOREGROUND_FPS

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Respect a stricter --max-fps supplied by a preview/diagnostic launcher.
	if Engine.max_fps > 0: _requested_cap = mini(Engine.max_fps, FOREGROUND_FPS)
	_apply_limit()

func _process(_delta: float) -> void:
	_apply_limit()

func _apply_limit() -> void:
	var active: bool = DisplayServer.get_name() == "headless" or (DisplayServer.window_can_draw() and get_window().has_focus() and not get_window().unfocusable)
	var limit: int = _requested_cap if active else mini(_requested_cap, BACKGROUND_FPS)
	if Engine.max_fps != limit:
		Engine.max_fps = limit
		print("RESOURCE_BUDGET ", limit, " FPS")
