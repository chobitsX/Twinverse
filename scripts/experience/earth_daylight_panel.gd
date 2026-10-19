extends VBoxContainer
const I18n = preload("res://scripts/core/app_text.gd")
const Daylight = preload("res://scripts/experience/earth_daylight.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Seasons = preload("res://scripts/experience/season_observation.gd")
var host: Node
var date_buttons: Array[Button] = []
var date_label: Label
var table: GridContainer
var values: Array[Label] = []
var exit_button: Button
var reference_button: Button
var coast_button: Button
var reference_label: Label
var _date: float = INF

func configure(experience: Node) -> void:
	host = experience
	add_theme_constant_override("separation",4)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation",5)
	add_child(buttons)
	for index: int in range(Seasons.DATES.size()):
		var button: Button = host._button([I18n.text("3月参考"),I18n.text("6月参考"),I18n.text("9月参考"),I18n.text("12月参考")][index],choose_date.bind(index))
		button.add_theme_font_size_override("font_size",18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		_compact_button(button)
		buttons.add_child(button)
		date_buttons.append(button)
	date_label = _label("",13)
	add_child(date_label)
	var legend: Label = _label(I18n.text("暖线受光 / 蓝线背光 · 几何昼长"),13)
	legend.add_theme_color_override("font_color",Color(.76,.86,.94))
	add_child(legend)
	table = GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation",8)
	table.add_theme_constant_override("v_separation",1)
	add_child(table)
	for heading: String in [I18n.text("纬度"),I18n.text("北半球 / 小时"),I18n.text("南半球 / 小时")]:
		table.add_child(_label(heading,13))
	for latitude: float in Daylight.PAIRS:
		table.add_child(_label(I18n.text("赤道") if latitude==0.0 else "%d°" % latitude,15))
		for side: int in range(2):
			var value: Label = _label("",15)
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			table.add_child(value)
			values.append(value)
	var reference_row: HBoxContainer = HBoxContainer.new()
	reference_row.add_theme_constant_override("separation",5)
	add_child(reference_row)
	reference_button = host._button(I18n.text("地球参考点"),focus_polar)
	reference_button.toggle_mode = true
	coast_button = host._button(I18n.text("到南极海岸"),visit_polar)
	coast_button.tooltip_text = I18n.text("保留同一观察日期和速率，到原海岸看随日期变化的日照。")
	exit_button = host._button(I18n.text("返回地球观察入口"),leave)
	for button: Button in [reference_button,coast_button,exit_button]:
		button.add_theme_font_size_override("font_size",18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_compact_button(button)
		reference_row.add_child(button)
	reference_label = _label("",13)
	add_child(reference_label)
	hide()

func _compact_button(button: Button) -> void:
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var style: StyleBox = host.explorer_panel.get_theme_stylebox(state,"Button").duplicate()
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		button.add_theme_stylebox_override(state,style)

func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = I18n.text(text)
	label.add_theme_font_size_override("font_size",host.InterfaceTheme.readable_size(font_size))
	return label

func present() -> void:
	var data: Dictionary = host.coordinator.active_scene.get_meta("earth_daylight",{})
	reference_button.set_pressed_no_signal(bool(data.get("polar_reference",false)))
	for button: Button in [reference_button,coast_button]:
		button.disabled = host.coordinator.is_busy() or not host.world.foreground
	if _date==host.solar_jd: return
	_date = host.solar_jd
	date_label.text = I18n.text(Orientation.timestamp(_date))
	var rows: Array[Dictionary] = Daylight.rows(_date)
	for index: int in range(rows.size()):
		values[index*2].text = I18n.text(Daylight.hours_text(float(rows[index].north)))
		values[index*2+1].text = I18n.text(Daylight.hours_text(float(rows[index].south)))
	for index: int in range(date_buttons.size()):
		date_buttons[index].set_pressed_no_signal(absf(_date-Seasons.preset(index,"earth"))<1e-8)
	var local: Dictionary = Seasons.sample(_date,"polar")
	reference_label.text = I18n.text(I18n.text("66.5°S / 0° · 教学光照参考\n太阳高度 %.1f° · 几何昼长 %.1f h") % [local.elevation,local.daylight])

func focus_polar() -> void:
	if not _can_visit(): return
	Daylight.focus_polar(host)
	present()

func visit_polar() -> void:
	if not _can_visit(): return
	host.start_guide_visit("polar","season_light",true)

func _can_visit() -> bool:
	return not host.coordinator.is_busy() and host.world.foreground and host.world.current_scale_id=="earth" and host.learning_overlay.topic=="earth_daylight"

func choose_date(index: int) -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="earth" or host.learning_overlay.topic!="earth_daylight": return
	host.set_solar_rate(0.0)
	host.set_solar_date(Seasons.preset(index,"earth"))
	present()

func leave() -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="earth": return
	host.explorer_panel.clear_topic()
	host._reset_camera()
	host.explorer_panel.scroll.scroll_vertical = 0
