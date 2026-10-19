extends VBoxContainer
## Temporary presentation state. The world, camera and panel state stay owned by host.
var host: Node
var active: bool=false
var exit_button: Button
var pause_button: Button
var location: Label

func fit_window(view_size: Vector2i) -> void:
	scale=Vector2.ONE*host.ui_scale
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position=Vector2(maxf(16,view_size.x-376),24)*host.ui_scale
	size=Vector2(352,0)

func configure(experience: Node, shared_theme: Theme) -> void:
	host=experience
	theme=shared_theme
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left=-330;offset_right=-24;offset_top=24
	add_theme_constant_override("separation",6)
	location=host._label("",13)
	location.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	add_child(location)
	var row: HBoxContainer=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_END
	add_child(row)
	exit_button=host.InterfaceTheme.icon("close","返回界面 · Esc / F9",set_active.bind(false))
	row.add_child(exit_button)
	pause_button=host.InterfaceTheme.icon("pause","暂停或继续世界时间 · Space",host._toggle_pause)
	row.add_child(pause_button)
	var hint: Label=host._label("拖动环绕 · 滚轮缩放 · F9 返回",12)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	fit_window(host.ui_view_size())
	hide()

func toggle() -> void:
	set_active(not active)

func set_active(value: bool) -> void:
	if value and (host.coordinator.is_busy() or not host.coordinator.recovery_state().is_empty() or host.world_guide.visible or host.size_comparison.visible): return
	active=value
	var focused: Control=get_viewport().gui_get_focus_owner()
	if focused!=null: focused.release_focus()
	host.hud.visible=not active
	visible=active
	refresh()

func refresh() -> void:
	location.text="观察 · "+str(host.Catalog.describe(host.world.current_scale_id).label)
	pause_button.set("symbol","play" if host.world.paused else "pause"); pause_button.queue_redraw()

func _process(_delta: float) -> void:
	if not active: return
	# A failed/programmatic transition must never strand recovery controls offscreen.
	if host.coordinator.is_busy() or not host.coordinator.recovery_state().is_empty():
		set_active(false)
		return
	refresh()
