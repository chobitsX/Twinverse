extends VBoxContainer
const Reference = preload("res://scripts/experience/earth_season_orbit.gd")
const Seasons = preload("res://scripts/experience/season_observation.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
var host: Node
var date_buttons: Array[Button] = []
var earth_button: Button
var distance: CheckButton
var readout: Label
var _view_size: Vector2i = Vector2i.ZERO

func configure(experience: Node) -> void:
	host = experience
	add_theme_constant_override("separation",5)
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	for index: int in range(4):
		var button: Button = host._button(["3月","6月","9月","12月"][index],choose_date.bind(index))
		button.add_theme_font_size_override("font_size",18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		date_buttons.append(button)
	readout = host._label("",13)
	add_child(readout)
	distance = CheckButton.new()
	distance.text = "轨道距离同比 · 天体仍放大"
	distance.add_theme_font_size_override("font_size",18)
	distance.toggled.connect(func(value: bool) -> void:
		if _available():
			host.set_solar_distance(value)
			_frame())
	add_child(distance)
	earth_button = host._button("进入同日期地球昼长",enter_earth)
	add_child(earth_button)
	var note: Label = host._label("四日期参考副本 · 北轴/太阳方向\n地球大小与轴长为观察符号，倾角沿原模型。",12)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 300
	add_child(note)
	hide()

func _available() -> bool:
	return visible and host.world.current_scale_id=="solar_system" and host.world.foreground and not host.coordinator.is_busy()

func open() -> void:
	show()
	_frame()
	Reference.set_active(host.coordinator.active_scene,true)
	present()

func close() -> void:
	hide()
	if host.coordinator.active_scene.has_meta("earth_season_orbit"):
		Reference.set_active(host.coordinator.active_scene,false)

func choose_date(index: int) -> void:
	if not _available(): return
	host.set_solar_rate(0.0)
	host.set_solar_date(Seasons.preset(index,"earth"))
	_frame()
	present()

func enter_earth() -> void:
	if _available(): host.start_guide_visit("earth","earth_daylight",true)

func _frame() -> void:
	host.focus_planet_orbit(2)
	var stage: Node = host.coordinator.active_scene
	var distance_m: float = stage.camera.position.length()*1.18
	stage.set_pose(Vector3(0,1,.65).normalized()*distance_m,Vector3.ZERO,Vector3.UP)
	_view_size = host.get_window().size

func present() -> void:
	if _view_size!=host.get_window().size: _frame()
	distance.set_pressed_no_signal(host.solar_true_distance)
	readout.text = Orientation.timestamp(host.solar_jd)+"\n北纬35° / 南纬35° · 几何昼长"
	for index: int in range(4):
		var jd: float = Seasons.preset(index,"earth")
		readout.text += "\n%s  %.1f / %.1f h · %.3f AU" % [["3月","6月","9月","12月"][index],Orientation.latitude_daylight_hours(35,jd),Orientation.latitude_daylight_hours(-35,jd),Orbit.position_au(2,jd).length()]
	readout.text += "\n两半球向阳与昼长互换；未模拟温度/天气。"
	earth_button.disabled = not host.world.foreground or host.coordinator.is_busy()
