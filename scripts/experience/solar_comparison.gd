extends VBoxContainer
## One dated view of existing heliocentric data; owns no simulation state.
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const LightTravel = preload("res://scripts/core/solar_light_travel.gd")
var host: Node
var date_text: Label
var back_button: Button
var forward_button: Button
var overview_button: Button
var body_buttons: Array[LinkButton] = []
var distances: Array[Label] = []
var speeds: Array[Label] = []
var light_times: Array[Label] = []
var light_reference: Label
var source_note: Label
var entries: Array[Dictionary] = []
var date_jd: float = INF

func configure(experience: Node) -> void:
	host=experience
	add_theme_constant_override("separation",7)
	date_text=host._label("",13,Color(.60,.93,.82))
	add_child(date_text)
	var controls: HFlowContainer=HFlowContainer.new()
	controls.add_theme_constant_override("separation",5)
	back_button=host._button("−1天",step_date.bind(-1.0))
	forward_button=host._button("+1天",step_date.bind(1.0))
	overview_button=host._button("太阳系全景",select_body.bind(-1))
	for button: Button in [back_button,forward_button,overview_button]:
		button.add_theme_font_size_override("font_size",18)
		controls.add_child(button)
	add_child(controls)
	light_reference=host._label("光走1 AU ≈ 8分19秒 · 单程",12,Color(.60,.93,.82))
	light_reference.tooltip_text="固定单位参考；每行按当前日期太阳中心至对应质心距离÷真空光速。"
	add_child(light_reference)
	var grid: GridContainer=GridContainer.new()
	grid.columns=4
	grid.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	grid.custom_minimum_size.x=280
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",2)
	for title: String in ["行星", "日心距离\nAU", "几何速率\nkm/s", "单程光时\n分钟"]:
		var label: Label=host._label(title,12)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if title!="行星" else HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(label)
	for index: int in range(Ephemeris.NAMES.size()):
		var button: LinkButton=LinkButton.new()
		button.text=Ephemeris.NAMES[index]+" →"
		button.add_theme_font_size_override("font_size",18)
		button.custom_minimum_size=Vector2(76,44)
		button.pressed.connect(select_body.bind(index))
		button.tooltip_text="观察同一日期的"+Ephemeris.NAMES[index]
		body_buttons.append(button)
		grid.add_child(button)
		var distance: Label=host._label("",14)
		var speed: Label=host._label("",14)
		var light_time: Label=host._label("",14)
		for label: Label in [distance,speed,light_time]:
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			grid.add_child(label)
		distances.append(distance); speeds.append(speed); light_times.append(light_time)
	var table_scroll: ScrollContainer=ScrollContainer.new()
	table_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	table_scroll.custom_minimum_size.y=370
	add_child(table_scroll)
	table_scroll.add_child(grid)
	source_note=host._label("",12,Color(.70,.80,.84))
	source_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	source_note.custom_minimum_size.x=300
	add_child(source_note)
	hide()

func select_body(index: int) -> void:
	if host.coordinator.is_busy() or not host.world.foreground or host.world.current_scale_id!="solar_system": return
	host.follow_planet(index)

func step_date(days: float) -> void:
	if host.coordinator.is_busy() or not host.world.foreground or host.world.current_scale_id!="solar_system": return
	host.set_solar_date(clampf(host.solar_jd+days,Ephemeris.START_JD,Ephemeris.END_JD))

func _process(_delta: float) -> void:
	if host==null: return
	if host.world.current_scale_id!="solar_system":
		hide()
		return
	if not is_visible_in_tree() or host.coordinator.is_busy(): return
	if date_jd!=host.solar_jd: _refresh_values()
	back_button.disabled=host.solar_jd<=Ephemeris.START_JD or not host.world.foreground
	forward_button.disabled=host.solar_jd>=Ephemeris.END_JD or not host.world.foreground
	var selected: int=host.solar_follow if host.solar_follow>=0 else host.solar_orbit_focus
	for index: int in range(body_buttons.size()):
		body_buttons[index].add_theme_color_override("font_color",Color(.60,.94,.80) if index==selected else Color(.85,.93,.96))

func _refresh_values() -> void:
	date_jd=host.solar_jd
	date_text.text=Orientation.timestamp(date_jd)
	entries.clear()
	var all_cached: bool=true
	for index: int in range(Ephemeris.NAMES.size()):
		var cached: Vector3=Ephemeris.De440.position_au(index,date_jd)
		var position: Vector3=cached if cached.is_finite() else Ephemeris.position_au(index,date_jd)
		var speed: float=Ephemeris.speed_km_s(index,date_jd)
		var distance: float=position.length() if position.is_finite() else INF
		var distance_source: String="de440" if cached.is_finite() else "approximate"
		var light: Dictionary=LightTravel.row(distance,distance_source)
		all_cached=all_cached and cached.is_finite() and is_finite(speed)
		distances[index].text=("%.3f" % distance)+( "*" if not cached.is_finite() else "") if is_finite(distance) else "—"
		speeds[index].text="%.2f" % speed if is_finite(speed) else "—"
		light_times[index].text=light.text
		light_times[index].tooltip_text="当天日心距离÷真空光速；单程几何参考，未算传播中天体移动。"
		entries.append({"index":index,"name":Ephemeris.NAMES[index],"jd":date_jd,"distance_au":distance,"speed_km_s":speed,"distance_source":distance_source,"speed_source":"de440" if is_finite(speed) else "unavailable","light_seconds":light.seconds,"light_minutes":light.minutes,"light_source":light.source})
	source_note.text=("DE440离线日心数据 · 1800–2050 TDB" if all_cached else "部分缓存不可用：带*距离/光时取近似椭圆；缺失值显示—")+"\n地球对应地月共同重心；木星及以外对应行星与卫星共同重心。\n数值不随画面距离压缩改变。点行星可走近观察。\n光时按当天太阳中心到表中质心的距离÷真空光速估算；单程，未算传播中移动、光线弯曲或地面视位置。\n光速：BIPM SI；AU：IAU 2012 B2。依据见科学说明。"
