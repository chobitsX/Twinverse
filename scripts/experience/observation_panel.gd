extends PanelContainer
const I18n = preload("res://scripts/core/app_text.gd")
## Reads the authority; following an event navigates the current world, never rewinds it.

const Catalog = preload("res://scripts/core/scale_catalog.gd")
const Habitat = preload("res://scripts/core/local_habitat.gd")
const OxygenPanel = preload("res://scripts/experience/oxygen_panel.gd")
var experience: Node
var status: Label
var journal: RichTextLabel
var trace: Control
var fish_button: Button
var restart_button: Button
var oxygen_view: VBoxContainer
var tabs: TabContainer
var _refresh_in_s: float = 0.0


class MovementTrace extends Control:
	var samples: Array[Dictionary] = []
	func _draw() -> void:
		var area: Rect2 = Rect2(8, 10, maxf(1, size.x - 16), maxf(1, size.y - 30))
		draw_rect(area, Color(0.05, 0.12, 0.14, 0.8))
		for i: int in range(1, 4):
			var y: float = area.position.y + area.size.y * float(i) / 4.0
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.3, 0.5, 0.5, 0.25))
		if samples.is_empty(): return
		var first: float = float(samples.front().time_s)
		var last: float = float(samples.back().time_s)
		var points: PackedVector2Array = []
		for sample: Dictionary in samples:
			var p: Array = sample.position_m
			var distance_mm: float = Vector3(p[0], p[1], p[2]).distance_to(Habitat.FISH_ORIGIN) * 1000.0
			points.append(Vector2(area.position.x + (float(sample.time_s) - first) / maxf(last - first, 1.0) * area.size.x,
				area.end.y - clampf(distance_mm / 25.0, 0.0, 1.0) * area.size.y))
		if points.size() > 1: draw_polyline(points, Color(0.45, 0.87, 0.8), 2.0, true)
		else: draw_circle(points[0], 3, Color(0.45, 0.87, 0.8))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(8, size.y - 2), "%.0f s" % first, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.75, 0.76))
		draw_string(font, Vector2(size.x - 72, size.y - 2), "%.0f s" % last, HORIZONTAL_ALIGNMENT_RIGHT, 64, 16, Color(0.6, 0.75, 0.76))


func configure(host: Node, style: StyleBoxFlat) -> void:
	experience = host
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -480; offset_right = -20; offset_top = 78; offset_bottom = -80
	add_theme_stylebox_override("panel", style)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	var page_scroll: ScrollContainer=ScrollContainer.new()
	page_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page_scroll)
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical=Control.SIZE_EXPAND_FILL
	page_scroll.add_child(rows)
	var heading: HBoxContainer = HBoxContainer.new()
	rows.add_child(heading)
	var title: Label = host._label(I18n.text("持续观察"), 21)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(host.InterfaceTheme.icon("close",I18n.text("关闭影响链与记录 · Esc"),hide))
	status = host._label("", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)
	var actions: HBoxContainer = HBoxContainer.new()
	rows.add_child(actions)
	fish_button = host._button(I18n.text("返回目标鱼"), host.observe_scale.bind("fish"))
	actions.add_child(fish_button)
	restart_button = host._button(I18n.text("从头试览"), host.toggle_trial)
	restart_button.tooltip_text = I18n.text("用相同种子从零开始临时试览；原世界保留，可随时返回。")
	actions.add_child(restart_button)
	tabs = TabContainer.new()
	tabs.custom_minimum_size.y=280
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(tabs)
	var oxygen_scroll: ScrollContainer = ScrollContainer.new()
	oxygen_scroll.name = I18n.text("礁区到 ATP")
	oxygen_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(oxygen_scroll)
	oxygen_view = OxygenPanel.new()
	oxygen_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oxygen_scroll.add_child(oxygen_view)
	oxygen_view.configure(host)
	var history_scroll: ScrollContainer = ScrollContainer.new()
	history_scroll.name = I18n.text("活动记录")
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(history_scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	history_scroll.add_child(rows)
	rows.add_child(host._label(I18n.text("目标鱼位移 · 0–25 mm · 行为示意"), 12))
	trace = MovementTrace.new()
	trace.custom_minimum_size.y = 100
	rows.add_child(trace)
	rows.add_child(host._label(I18n.text("近期记录 · 点击地点返回当前世界中的该处"), 12))
	journal = RichTextLabel.new()
	journal.bbcode_enabled = true
	journal.fit_content = true
	journal.scroll_active = false
	journal.meta_clicked.connect(func(meta: Variant) -> void:
		var scale_id: String = str(meta)
		if Catalog.contains(scale_id): experience.observe_scale(scale_id))
	rows.add_child(journal)
	var note: Label = host._label(I18n.text("轨迹由参考行为驱动；能量与健康为代理值。升级前的旧轨迹保持原记录，不补写过去的生理状态。"), 12)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(note)
	visibility_changed.connect(func() -> void: _refresh_in_s = 0.0)
	visible = false


func _process(delta: float) -> void:
	if not visible: return
	_refresh_in_s -= delta
	if _refresh_in_s > 0.0: return
	_refresh_in_s = 0.5
	refresh()


func refresh() -> void:
	oxygen_view.refresh()
	var world: RefCounted = experience.world
	var habitat: RefCounted = world.habitat
	var local: Dictionary = habitat.snapshot(world.simulation_time_s, world.current_scale_id)
	status.text = I18n.text((I18n.text("临时试览 · 原世界已保留\n") if experience.is_trial() else I18n.text("当前世界 · 同一条目标鱼\n")))
	status.text += I18n.text(I18n.text("海葵双锯鱼 0001 · 宿主附近活动\n蜥蜴岛局部礁区 · 世界时间 %.1f s\n已到访 %d 个尺度 · %d 条活动采样") % [world.simulation_time_s, habitat.visits.size(), habitat.samples.size()])
	if local.mode == "remote": status.text += I18n.text(I18n.text("\n目标鱼在当前画面外，活动继续"))
	fish_button.disabled = experience.coordinator.is_busy()
	restart_button.disabled = experience.coordinator.is_busy()
	restart_button.text = I18n.text(I18n.text("返回原世界") if experience.is_trial() else I18n.text("从头试览"))
	trace.samples.assign(habitat.samples)
	trace.queue_redraw()
	var lines: PackedStringArray = []
	var labels: Dictionary = {"started": I18n.text("开始观察"), "continued": I18n.text("继续观察"), "arrived": I18n.text("到达"), "paused": I18n.text("暂停"), "running": I18n.text("继续时间"), "speed": I18n.text("调整时间")}
	for index: int in range(habitat.events.size() - 1, maxi(-1, habitat.events.size() - 25), -1):
		var event: Dictionary = habitat.events[index]
		var suffix: String = " · %s×" % str(event.multiplier) if event.kind == "speed" else ""
		lines.append("[color=#99b6bb]%.1f s[/color]  %s · [url=%s]%s[/url]%s" % [event.time_s, labels[event.kind], event.scale_id, Catalog.describe(event.scale_id).label, suffix])
	journal.text = I18n.text("\n\n".join(lines) if not lines.is_empty() else I18n.text("开始观察后，这里会记录到访与时间操作。"))
