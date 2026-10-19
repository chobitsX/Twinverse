extends PanelContainer
const I18n = preload("res://scripts/core/app_text.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")
const Seasons = preload("res://scripts/experience/season_observation.gd")
const Sites = preload("res://scripts/data/earth_sites.gd")
const BRANCHES: Array = [["宇宙结构","universe"],["银河系","galaxy"],["太阳系","solar_system"],["火星与卫星","mars_moons"],["木星与卫星","jupiter_moons"],["土星与卫星","saturn_moons"],["天王星与卫星","uranus_moons"],["海王星与卫星","neptune_moons"],["地球全景","earth"],["地面观星","night_sky"],["地月与季节","earth_moon"],["海洋生命","reef"],["陆地生态","woodland"],["索诺兰荒漠","desert"],["南极海岸","polar"],["北极海冰与夜空","arctic"],["城市与人类","city"],["生命内部","fish"]]
const Satellites = preload("res://scripts/core/natural_satellites.gd")
const SatellitePanel = preload("res://scripts/experience/satellite_catalogue_panel.gd")
var satellite_catalogue: SatellitePanel
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const RATES: Array[float] = [0.0,1.0/24.0,1.0,10.0,30.0,100.0]
const CITY_BIRD_CONTEXT_POSITION: Vector3 = Vector3(12.5,2.3,28.5)
const CITY_BIRD_CONTEXT_TARGET: Vector3 = Vector3(17.0,.9,25.5)
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const SolarComparison = preload("res://scripts/experience/solar_comparison.gd")
const TrafficPhaseStrip = preload("res://scripts/experience/traffic_phase_strip.gd")
const RunoffBalancePanel = preload("res://scripts/experience/runoff_balance_panel.gd")
var runoff_balance: RunoffBalancePanel
const EarthSeasonPanel = preload("res://scripts/experience/earth_season_panel.gd")
var earth_season_controls: EarthSeasonPanel
var earth_season_toggle: Button
const EarthDaylightPanel = preload("res://scripts/experience/earth_daylight_panel.gd")
const TurtleComparison = preload("res://scripts/experience/turtle_comparison.gd")
var earth_daylight_controls: EarthDaylightPanel
var polar_globe_button: Button
var turtle_comparison_controls: TurtleComparison
var galactic_controls: HFlowContainer
var galactic_top_button: Button
var galactic_side_button: Button
var galactic_enter_button: Button
var lunar_day_button: Button
var eclipse_solar_button: Button
var eclipse_lunar_button: Button
var eclipse_back_button: Button
var eclipse_forward_button: Button
var lunar_controls: VBoxContainer
var lunar_phase_buttons: Array[Button] = []
var lunar_earth_button: Button
var lunar_orbit_button: Button
var school_controls: VBoxContainer
var algae_controls: VBoxContainer
var algae_enabled: CheckButton
var algae_adaptive: CheckButton
var algae_reset: Button
var school_alignment: CheckButton
var school_turn: Button
var school_reset: Button
var zooplankton_reset: Button
var deadwood_controls: HFlowContainer
var deadwood_mode: OptionButton
var deadwood_reset: Button
var runoff_controls: HFlowContainer
var runoff_rain: CheckButton
var runoff_reset: Button
var traffic_controls: VBoxContainer
var traffic_profile_buttons: Array[Button] = []
var traffic_reset: Button
var traffic_strip: TrafficPhaseStrip
var traffic_hint: Label
var browse_controls: HFlowContainer
var browse_protect: CheckButton
var browse_reset: Button
var branch_picker: OptionButton
var _column: VBoxContainer
var observation_toggle: Button
var observation_body: VBoxContainer
var science_body: VBoxContainer
var current_title: Label
var selection_heading: Label
var selection_title: Label
var summary_text: Label
var summary_hint: Label
var _observation_open: bool = false
var _science_open: bool = false
var heading: Label
var earth_box: VBoxContainer
var earth_picker: OptionButton
var earth_detail: Label
var earth_focus: Button
var earth_enter: Button
var topic_picker: OptionButton
var atom_box: VBoxContainer
var atom_picker: OptionButton
var atom_section: CheckButton
var atom_note: Label
var topic_box: VBoxContainer
var activity: Label
var lesson_text: Label
var coral_controls: HFlowContainer
var coral_heat: CheckButton
var coral_reset: Button
var lesson_readout: Label
var lesson_source: LinkButton
var lesson_controls: HFlowContainer
var kepler_controls: VBoxContainer
var kepler_advance: Button
var monarch_stage_hint: Label
var monarch_controls: HFlowContainer
var city_bird_controls: HFlowContainer
var city_bird_context_view: bool = false
var ginkgo_controls: HFlowContainer
var park_tree_controls: VBoxContainer
var season_controls: HFlowContainer
var polar_sky_controls: HFlowContainer
var octopus_controls: HFlowContainer
var rat_night_button: Button
var rat_reset_button: Button
var rat_view_controls: HFlowContainer
var penguin_view_controls: HFlowContainer
var markers_toggle: CheckButton
var solar_toggle: Button
var details_toggle: Button
var scroll: ScrollContainer
var _topics: Array[Dictionary] = []
var _topic: Dictionary = {}
var _astro_open: bool = false
var _restoring_language: bool = false
var host: Node
var detail: Label
var solar: VBoxContainer
var date_text: Label
var body_text: Label
var body_picker: OptionButton
var orbit_view_button: Button
var orbit_source_hint: Label
var solar_plane_controls: HFlowContainer
var solar_top_button: Button
var solar_side_button: Button
var solar_plane_hint: Label
var object_picker: OptionButton
var object_box: VBoxContainer
var date_epoch_button: Button
var noon_button: Button
var date_slider: HSlider
var size_compare_button: Button
var mode: CheckButton
var rate_picker: OptionButton
var themes: VBoxContainer
var ground_mode: CheckButton
var source_text: Label
var species_source: LinkButton
var _species_url: String = ""
var _updating: bool = false
var _scale: String = ""
var journey_return_button: Button
var solar_compare_button: Button
var solar_comparison: VBoxContainer

func configure(experience: Node, style: StyleBoxFlat) -> void:
	host = experience
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	fit_window(host.ui_view_size())
	add_theme_stylebox_override("panel",style)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	_column = column
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",9)
	scroll.add_child(column)
	var header_row: HBoxContainer = HBoxContainer.new(); column.add_child(header_row)
	heading = host._label(I18n.text("观察与知识"),22); heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header_row.add_child(heading)
	header_row.add_child(host.InterfaceTheme.icon("close",I18n.text("关闭知识面板 · Esc"),hide))
	journey_return_button=host._button(I18n.text("返回世界漫游"),func() -> void: host.guided_journey.return_to_route())
	journey_return_button.hide()
	column.add_child(journey_return_button)
	solar_compare_button=host._button(I18n.text("行星距离、速率与光时 ▸"),toggle_solar_comparison)
	solar_compare_button.hide()
	column.add_child(solar_compare_button)
	solar_comparison=SolarComparison.new()
	solar_comparison.configure(host)
	column.add_child(solar_comparison)
	size_compare_button=host._button(I18n.text("天体大小 · 同比例比较"),func() -> void: host.open_size_comparison())
	size_compare_button.visible=false
	column.add_child(size_compare_button)
	branch_picker = OptionButton.new()
	branch_picker.custom_minimum_size.y = 44
	for item: Array in I18n.array(BRANCHES): branch_picker.add_item(I18n.text("前往 · ")+str(item[0]))
	branch_picker.item_selected.connect(func(index: int) -> void: host.observe_scale(I18n.array(BRANCHES)[index][1]))
	column.add_child(branch_picker)
	earth_season_toggle = host._button(I18n.text("地球公转与季节 ▸"),toggle_earth_season)
	column.add_child(earth_season_toggle)
	earth_season_controls = EarthSeasonPanel.new()
	earth_season_controls.configure(host)
	column.add_child(earth_season_controls)
	earth_box = VBoxContainer.new()
	earth_box.add_theme_constant_override("separation",8)
	column.add_child(earth_box)
	earth_box.add_child(host._label(I18n.text("地球上的观察入口"),19))
	earth_picker = OptionButton.new()
	earth_picker.custom_minimum_size.y = 44
	for site: Dictionary in I18n.dictionaries(Sites.SITES): earth_picker.add_item(site.label)
	earth_picker.item_selected.connect(select_earth_site)
	earth_box.add_child(earth_picker)
	earth_detail = _text("")
	earth_box.add_child(earth_detail)
	var earth_actions: HFlowContainer = HFlowContainer.new()
	earth_box.add_child(earth_actions)
	earth_focus = host._button(I18n.text("定位参考"),func() -> void: host.focus_earth_reference(str(I18n.dictionaries(Sites.SITES)[earth_picker.selected].scale)))
	earth_enter = host._button(I18n.text("进入所选场景"),func() -> void: host.observe_scale(str(I18n.dictionaries(Sites.SITES)[earth_picker.selected].scale)))
	earth_actions.add_child(earth_focus)
	earth_actions.add_child(earth_enter)
	satellite_catalogue=SatellitePanel.new()
	column.add_child(satellite_catalogue)
	satellite_catalogue.configure(host)
	object_box = VBoxContainer.new()
	object_box.add_theme_constant_override("separation",7)
	column.add_child(object_box)
	object_box.add_child(host._label(I18n.text("观察对象"),16))
	object_picker = OptionButton.new()
	object_picker.custom_minimum_size.y = 44
	object_box.add_child(object_picker)
	object_picker.item_selected.connect(func(index: int) -> void:
		clear_topic()
		host.follow_content(index))
	activity = _text("")
	object_box.add_child(activity)
	var object_actions: HFlowContainer = HFlowContainer.new()
	object_box.add_child(object_actions)
	object_actions.add_child(host._button(I18n.text("回到全景"),func() -> void:
		clear_topic()
		host._reset_camera()))
	object_actions.add_child(host._button(I18n.text("对象标准视角"),func() -> void: host._reset_observation_view()))
	species_source = LinkButton.new()
	species_source.text = I18n.text(I18n.text("物种资料 ↗"))
	species_source.add_theme_font_size_override("font_size",18)
	species_source.pressed.connect(func() -> void:
		if not _species_url.is_empty(): OS.shell_open(_species_url))
	object_actions.add_child(species_source)
	atom_box=VBoxContainer.new()
	column.add_child(atom_box)
	atom_box.add_child(host._label(I18n.text("氧原子 · 组成与轨道"),19))
	atom_box.add_child(_text(I18n.text("中性氧：8质子 / 8电子\n氧-16示例：8中子\n基态电子组态：1s² 2s² 2p⁴")))
	atom_picker=OptionButton.new()
	for label: String in host.Oxygen.LABELS: atom_picker.add_item(label)
	atom_picker.item_selected.connect(func(index: int) -> void: host.select_atom_view(index,atom_section.button_pressed))
	atom_box.add_child(atom_picker)
	atom_section=CheckButton.new()
	atom_section.text=I18n.text(I18n.text("查看中心剖面"))
	atom_section.toggled.connect(func(value: bool) -> void: host.select_atom_view(atom_picker.selected,value))
	atom_box.add_child(atom_section)
	atom_note=_text("")
	atom_box.add_child(atom_note)
	atom_box.add_child(_text(I18n.text("这是孤立原子参考，不是从O₂中实际拆出一个原子；原子轨道不等同分子轨道。云的尺寸、颜色与亮度为显示设置。")))
	atom_box.hide()
	topic_box = VBoxContainer.new()
	topic_box.add_theme_constant_override("separation",7)
	column.add_child(topic_box)
	topic_box.add_child(host._label(I18n.text("观察主题"),16))
	topic_picker = OptionButton.new()
	topic_picker.custom_minimum_size.y = 44
	topic_picker.item_selected.connect(_activate_topic)
	topic_box.add_child(topic_picker)
	earth_daylight_controls = EarthDaylightPanel.new()
	earth_daylight_controls.configure(host)
	topic_box.add_child(earth_daylight_controls)
	lesson_readout = _text("")
	lesson_readout.add_theme_color_override("font_color",Color(.60,.93,.82))
	topic_box.add_child(lesson_readout)
	lesson_text = _text("")
	topic_box.add_child(lesson_text)
	markers_toggle = CheckButton.new()
	markers_toggle.text = I18n.text(I18n.text("显示观察标记"))
	markers_toggle.button_pressed = true
	markers_toggle.toggled.connect(func(value: bool) -> void: host.learning_overlay.enabled = value)
	topic_box.add_child(markers_toggle)
	lesson_controls = HFlowContainer.new()
	lesson_controls.add_child(host._button(I18n.text("−3小时"),func() -> void: host.set_solar_date(host.solar_jd-.125)))
	lesson_controls.add_child(host._button(I18n.text("+3小时"),func() -> void: host.set_solar_date(host.solar_jd+.125)))
	noon_button=host._button(I18n.text("近似正午"),_local_noon)
	lesson_controls.add_child(noon_button)
	topic_box.add_child(lesson_controls)
	turtle_comparison_controls = TurtleComparison.new()
	turtle_comparison_controls.setup(host)
	topic_box.add_child(turtle_comparison_controls)
	monarch_controls = HFlowContainer.new()
	for stage_index: int in range(Topics.MonarchStages.TOPICS.size()):
		var topic_id: String=Topics.MonarchStages.TOPICS[stage_index]
		var button: Button=host._button(I18n.strings(Topics.MonarchStages.LABELS)[stage_index],select_topic.bind(topic_id))
		button.toggle_mode=true
		button.set_meta("monarch_topic",topic_id)
		monarch_controls.add_child(button)
	topic_box.add_child(monarch_controls)
	topic_box.move_child(monarch_controls,3)
	monarch_stage_hint=_text(I18n.text("卵 → 幼虫 → 蛹 → 成虫\n同种阶段参考 · 切换不推进发育"))
	topic_box.add_child(monarch_stage_hint)
	city_bird_controls=HFlowContainer.new()
	city_bird_controls.add_child(host._button(I18n.text("同时看行人与鸟"),focus_city_bird_context))
	city_bird_controls.add_child(host._button(I18n.text("近看树麻雀"),focus_city_bird_close))
	topic_box.add_child(city_bird_controls)
	topic_box.move_child(city_bird_controls,3)
	ginkgo_controls=HFlowContainer.new()
	ginkgo_controls.add_child(host._button(I18n.text("夏季绿叶"),func() -> void: select_ginkgo_season("2026-06-21")))
	ginkgo_controls.add_child(host._button(I18n.text("深秋金黄"),func() -> void: select_ginkgo_season("2026-10-28")))
	ginkgo_controls.add_child(host._button(I18n.text("冬季枝形"),func() -> void: select_ginkgo_season("2026-12-22")))
	topic_box.add_child(ginkgo_controls)
	topic_box.move_child(ginkgo_controls,3)
	park_tree_controls=VBoxContainer.new()
	var park_spring_summer: HFlowContainer=HFlowContainer.new()
	park_spring_summer.add_child(host._button(I18n.text("春季花"),func() -> void: select_city_tree_date("2026-04-15")))
	park_spring_summer.add_child(host._button(I18n.text("夏季绿叶"),func() -> void: select_city_tree_date("2026-06-21")))
	park_tree_controls.add_child(park_spring_summer)
	var park_autumn_winter: HFlowContainer=HFlowContainer.new()
	park_autumn_winter.add_child(host._button(I18n.text("深秋异色"),func() -> void: select_city_tree_date("2026-10-28")))
	park_autumn_winter.add_child(host._button(I18n.text("冬季枝形"),func() -> void: select_city_tree_date("2026-12-22")))
	park_tree_controls.add_child(park_autumn_winter)
	topic_box.add_child(park_tree_controls)
	topic_box.move_child(park_tree_controls,3)
	season_controls = HFlowContainer.new()
	season_controls.add_child(host._button(I18n.text("6月 · 正午"),func() -> void: select_season(1)))
	season_controls.add_child(host._button(I18n.text("12月 · 正午"),func() -> void: select_season(3)))
	topic_box.add_child(season_controls)
	polar_sky_controls = HFlowContainer.new()
	polar_sky_controls.add_child(host._button(I18n.text("冬季午夜 · 极光演示"),func() -> void: select_polar_sky(true)))
	polar_sky_controls.add_child(host._button(I18n.text("夏季正午 · 冰雪"),func() -> void: select_polar_sky(false)))
	polar_sky_controls.hide()
	topic_box.add_child(polar_sky_controls)
	polar_globe_button = host._button(I18n.text("从地球看同日期受光面"),view_polar_from_earth)
	polar_globe_button.add_theme_font_size_override("font_size",14)
	polar_globe_button.tooltip_text = I18n.text("返回原地球和南极教学光照参考点，保留日期、速率与世界暂停。")
	polar_globe_button.hide()
	topic_box.add_child(polar_globe_button)
	octopus_controls = HFlowContainer.new()
	octopus_controls.add_child(host._button(I18n.text("褐斑体色"), func() -> void: Topics.Octopus.set_pale(host, false)))
	octopus_controls.add_child(host._button(I18n.text("较浅体色"), func() -> void: Topics.Octopus.set_pale(host, true)))
	topic_box.add_child(octopus_controls)
	topic_box.move_child(octopus_controls, 3)
	rat_night_button=host._button(I18n.text("切至当地夜间观察"),_local_night)
	topic_box.add_child(rat_night_button)
	rat_night_button.hide()
	rat_reset_button=host._button(I18n.text("重置8枚教学种子"),func() -> void: host.world.reset_desert_seed_transfer())
	topic_box.add_child(rat_reset_button)
	rat_reset_button.hide()
	rat_view_controls=HFlowContainer.new()
	rat_view_controls.add_child(host._button(I18n.text("跟随袋鼠鼠"),func() -> void: focus_rat_view(true)))
	rat_view_controls.add_child(host._button(I18n.text("种子与洞口全景"),func() -> void: focus_rat_view(false)))
	topic_box.add_child(rat_view_controls)
	rat_view_controls.hide()
	penguin_view_controls=HFlowContainer.new()
	penguin_view_controls.add_child(host._button(I18n.text("形态近看"),func() -> void: focus_penguin_view(0)))
	penguin_view_controls.add_child(host._button(I18n.text("跟随往返"),func() -> void: focus_penguin_view(1)))
	penguin_view_controls.add_child(host._button(I18n.text("岸水全景"),func() -> void: focus_penguin_view(2)))
	topic_box.add_child(penguin_view_controls)
	topic_box.move_child(penguin_view_controls,3)
	penguin_view_controls.hide()
	traffic_controls=VBoxContainer.new()
	var traffic_choices: HFlowContainer=HFlowContainer.new()
	for profile: int in range(2):
		var button: Button=host._button(I18n.text("16秒过街") if profile==0 else I18n.text("24秒过街"),select_traffic_profile.bind(profile))
		button.toggle_mode=true
		traffic_profile_buttons.append(button)
		traffic_choices.add_child(button)
	traffic_reset=host._button(I18n.text("重启路口"),reset_traffic)
	traffic_choices.add_child(traffic_reset)
	traffic_controls.add_child(traffic_choices)
	traffic_strip=TrafficPhaseStrip.new()
	traffic_controls.add_child(traffic_strip)
	traffic_hint=_text(I18n.text("绿：横向 · 蓝：纵向/行人 · 灰：清空\n选择会重启路口；用下方时间控件继续观察。"))
	traffic_controls.add_child(traffic_hint)
	topic_box.add_child(traffic_controls)
	topic_box.move_child(traffic_controls,3)
	traffic_controls.hide()
	lesson_source = LinkButton.new()
	lesson_source.text = I18n.text(I18n.text("主题依据 ↗"))
	lesson_source.add_theme_font_size_override("font_size",18)
	lesson_source.pressed.connect(func() -> void:
		var url: String = _topic.get("source","")
		if not url.is_empty(): OS.shell_open(url))
	topic_box.add_child(lesson_source)
	topic_box.move_child(lesson_controls,3)
	topic_box.move_child(season_controls,4)
	topic_box.move_child(markers_toggle,5)
	topic_box.move_child(rat_night_button,3)
	topic_box.move_child(rat_reset_button,4)
	topic_box.move_child(rat_view_controls,5)
	kepler_controls = VBoxContainer.new()
	var kepler_row: HFlowContainer = HFlowContainer.new()
	kepler_row.add_child(host._button(I18n.text("近日段起点"),select_kepler_segment.bind(false)))
	kepler_row.add_child(host._button(I18n.text("远日段起点"),select_kepler_segment.bind(true)))
	kepler_controls.add_child(kepler_row)
	var kepler_actions: HFlowContainer = HFlowContainer.new()
	kepler_advance = host._button(I18n.text("前进8天"),advance_kepler)
	kepler_actions.add_child(kepler_advance)
	kepler_actions.add_child(host._button(I18n.text("轨道全貌"),func() -> void: host.focus_kepler()))
	kepler_controls.add_child(kepler_actions)
	topic_box.add_child(kepler_controls)
	topic_box.move_child(kepler_controls,3)
	browse_controls=HFlowContainer.new()
	browse_protect=CheckButton.new()
	browse_protect.text=I18n.text(I18n.text("保护左样方"))
	browse_protect.toggled.connect(func(value: bool) -> void: host.world.set_browse_protected(value))
	browse_controls.add_child(browse_protect)
	browse_reset=host._button(I18n.text("重置对比"),func() -> void: host.world.reset_browse())
	browse_controls.add_child(browse_reset)
	topic_box.add_child(browse_controls)
	topic_box.move_child(browse_controls,3)
	school_controls=VBoxContainer.new()
	school_alignment=CheckButton.new()
	school_alignment.text=I18n.text(I18n.text("邻居方向对齐"))
	school_alignment.toggled.connect(func(value: bool) -> void: host.world.set_school_alignment(value))
	school_controls.add_child(school_alignment)
	var school_buttons: HFlowContainer = HFlowContainer.new()
	school_turn=host._button(I18n.text("代表鱼转向"),func() -> void: host.world.perturb_school())
	school_reset=host._button(I18n.text("重置鱼群"),func() -> void: host.world.reset_school())
	school_buttons.add_child(school_turn)
	school_buttons.add_child(school_reset)
	school_controls.add_child(school_buttons)
	zooplankton_reset=host._button(I18n.text("重置水层教学单位"),func() -> void: host.world.reset_zooplankton_lesson())
	school_controls.add_child(zooplankton_reset)
	topic_box.add_child(school_controls)
	topic_box.move_child(school_controls,3)
	algae_controls=VBoxContainer.new()
	algae_enabled=CheckButton.new()
	algae_enabled.text=I18n.text(I18n.text("允许刮食 · 教学对照"))
	algae_enabled.toggled.connect(func(value: bool) -> void: host.world.set_algae_enabled(value))
	algae_controls.add_child(algae_enabled)
	algae_adaptive=CheckButton.new()
	algae_adaptive.text=I18n.text(I18n.text("下一轮按藻量与占用选点"))
	algae_adaptive.toggled.connect(func(value: bool) -> void: host.world.set_algae_adaptive(value))
	algae_controls.add_child(algae_adaptive)
	algae_reset=host._button(I18n.text("重置六处藻毯"),func() -> void: host.world.reset_algal_grazing())
	algae_controls.add_child(algae_reset)
	topic_box.add_child(algae_controls)
	topic_box.move_child(algae_controls,3)
	deadwood_controls=HFlowContainer.new()
	deadwood_mode=OptionButton.new()
	for text: String in [I18n.text("左：干燥"),I18n.text("左：湿润"),I18n.text("左：浸水")]: deadwood_mode.add_item(text)
	deadwood_mode.item_selected.connect(func(index: int) -> void: host.world.set_deadwood_mode(index))
	deadwood_controls.add_child(deadwood_mode)
	deadwood_reset=host._button(I18n.text("重新对比"),func() -> void: host.world.reset_deadwood())
	deadwood_controls.add_child(deadwood_reset)
	topic_box.add_child(deadwood_controls)
	topic_box.move_child(deadwood_controls,3)
	runoff_controls=HFlowContainer.new()
	runoff_rain=CheckButton.new()
	runoff_rain.text=I18n.text(I18n.text("降雨"))
	runoff_rain.toggled.connect(func(value: bool) -> void: host.world.set_runoff_rain(value))
	runoff_controls.add_child(runoff_rain)
	runoff_reset=host._button(I18n.text("重置雨水"),func() -> void: host.world.reset_runoff())
	runoff_controls.add_child(runoff_reset)
	topic_box.add_child(runoff_controls)
	topic_box.move_child(runoff_controls,3)
	runoff_balance=RunoffBalancePanel.new()
	topic_box.add_child(runoff_balance)
	runoff_balance.hide()
	coral_controls=HFlowContainer.new()
	coral_heat=CheckButton.new()
	coral_heat.text=I18n.text(I18n.text("热压力示意"))
	coral_heat.toggled.connect(func(value: bool) -> void: host.world.set_coral_heat(value))
	coral_controls.add_child(coral_heat)
	coral_reset=host._button(I18n.text("重置共生"),func() -> void: host.world.reset_coral_symbiosis())
	coral_controls.add_child(coral_reset)
	topic_box.add_child(coral_controls)
	topic_box.move_child(coral_controls,3)
	galactic_controls=HFlowContainer.new()
	galactic_top_button=host._button(I18n.text("俯视星盘"),func() -> void: Topics.Galactic.focus(host,false))
	galactic_side_button=host._button(I18n.text("侧视星盘"),func() -> void: Topics.Galactic.focus(host,true))
	galactic_enter_button=host._button(I18n.text("进入太阳系"),func() -> void: host._navigate_relative(1))
	galactic_controls.add_child(galactic_top_button)
	galactic_controls.add_child(galactic_side_button)
	galactic_controls.add_child(galactic_enter_button)
	topic_box.add_child(galactic_controls)
	topic_box.move_child(galactic_controls,3)
	lunar_controls=VBoxContainer.new()
	var lunar_phases: HFlowContainer = HFlowContainer.new()
	for quarter: int in range(4):
		var phase_button: Button = host._button([I18n.text("新月"),I18n.text("上弦"),I18n.text("满月"),I18n.text("下弦")][quarter],select_lunar_phase.bind(quarter))
		lunar_phase_buttons.append(phase_button)
		lunar_phases.add_child(phase_button)
	lunar_controls.add_child(lunar_phases)
	var lunar_views: HFlowContainer = HFlowContainer.new()
	lunar_earth_button=host._button(I18n.text("沿地球方向近看"),func() -> void: host.focus_lunar(true))
	lunar_orbit_button=host._button(I18n.text("轨道全景"),func() -> void: host.focus_lunar(false))
	lunar_views.add_child(lunar_earth_button)
	lunar_views.add_child(lunar_orbit_button)
	lunar_controls.add_child(lunar_views)
	lunar_day_button=host._button(I18n.text("前进一天 · 观察天平动"),func() -> void: host.set_solar_rate(0.0); host.set_solar_date(minf(host.Ephemeris.END_JD,host.solar_jd+1.)))
	lunar_controls.add_child(lunar_day_button)
	var eclipse_examples: HFlowContainer=HFlowContainer.new()
	eclipse_solar_button=host._button(I18n.text("日食示例"),select_eclipse_example.bind(false))
	eclipse_lunar_button=host._button(I18n.text("月食示例"),select_eclipse_example.bind(true))
	eclipse_examples.add_child(eclipse_solar_button)
	eclipse_examples.add_child(eclipse_lunar_button)
	lunar_controls.add_child(eclipse_examples)
	var eclipse_time: HFlowContainer=HFlowContainer.new()
	eclipse_back_button=host._button(I18n.text("−30分钟"),step_eclipse.bind(-1.0/48.0))
	eclipse_forward_button=host._button(I18n.text("+30分钟"),step_eclipse.bind(1.0/48.0))
	eclipse_time.add_child(eclipse_back_button)
	eclipse_time.add_child(eclipse_forward_button)
	lunar_controls.add_child(eclipse_time)
	topic_box.add_child(lunar_controls)
	topic_box.move_child(lunar_controls,3)
	solar_toggle = host._button(I18n.text("天文参数与日期 ▸"),func() -> void: _astro_open = not _astro_open)
	column.add_child(solar_toggle)
	solar = VBoxContainer.new()
	solar.add_theme_constant_override("separation",8)
	column.add_child(solar)
	solar.add_child(host._label(I18n.text("天文观察台"),21))
	date_text = _text("")
	solar.add_child(date_text)
	date_slider = HSlider.new()
	date_slider.min_value = Ephemeris.START_JD
	date_slider.max_value = Ephemeris.END_JD
	date_slider.step = 1.0
	date_slider.value = host.solar_jd
	solar.add_child(date_slider)
	date_slider.value_changed.connect(func(value: float) -> void:
		if not _updating: host.set_solar_date(value))
	var row: HFlowContainer = HFlowContainer.new()
	solar.add_child(row)
	date_epoch_button=host._button("J2000",func() -> void: host.set_solar_date(Ephemeris.EPOCH))
	row.add_child(date_epoch_button)
	row.add_child(host._button("2026-09-16",func() -> void: host.set_solar_date(Ephemeris.DEFAULT_JD)))
	rate_picker = OptionButton.new()
	for label: String in [I18n.text("日期暂停"),I18n.text("1小时 / 世界秒"),I18n.text("1天 / 世界秒"),I18n.text("10天 / 世界秒"),I18n.text("30天 / 世界秒"),I18n.text("100天 / 世界秒")]: rate_picker.add_item(label)
	rate_picker.selected = 0
	solar.add_child(rate_picker)
	rate_picker.item_selected.connect(func(index: int) -> void: host.set_solar_rate(RATES[index]))
	mode = CheckButton.new()
	mode.text = I18n.text(I18n.text("轨道距离同比"))
	mode.tooltip_text=I18n.text("轨道距离同比，天体半径各自放大；地月全景局部放大。")
	solar.add_child(mode)
	mode.toggled.connect(func(value: bool) -> void:
		if not _updating: host.set_solar_distance(value))
	body_picker = OptionButton.new()
	body_picker.add_item(I18n.text("太阳系全景"))
	for body: String in I18n.strings(Ephemeris.NAMES): body_picker.add_item(body)
	column.add_child(body_picker)
	column.move_child(body_picker,2)
	body_picker.item_selected.connect(func(index: int) -> void: host.follow_planet(index-1))
	orbit_view_button=host._button(I18n.text("查看所选轨道"),func() -> void:
		if host.solar_orbit_focus>=0 and not host.solar_plane_view.is_empty(): host.focus_planet_orbit(host.solar_orbit_focus)
		elif host.solar_orbit_focus>=0: host.follow_planet(host.solar_orbit_focus)
		elif host.solar_follow>=0: host.focus_planet_orbit(host.solar_follow))
	solar_plane_controls=HFlowContainer.new()
	solar_top_button=host._button(I18n.text("黄道俯视"),func() -> void: host.focus_solar_plane(false))
	solar_side_button=host._button(I18n.text("黄道侧视"),func() -> void: host.focus_solar_plane(true))
	solar_plane_controls.add_child(solar_top_button)
	solar_plane_controls.add_child(solar_side_button)
	solar_plane_controls.add_child(orbit_view_button)
	column.add_child(solar_plane_controls)
	column.move_child(solar_plane_controls,3)
	solar_plane_hint=_text("")
	column.add_child(solar_plane_hint)
	column.move_child(solar_plane_hint,4)
	orbit_source_hint = _text(I18n.text("青实线：DE440日期轨迹 · 橙虚线：近似教学椭圆"))
	solar.add_child(orbit_source_hint)
	solar.move_child(orbit_source_hint,3)
	body_text = _text("")
	solar.add_child(body_text)
	themes = VBoxContainer.new()
	solar.add_child(themes)
	var controls: HFlowContainer = HFlowContainer.new()
	themes.add_child(controls)
	controls.add_child(host._button(I18n.text("−6小时"),func() -> void: host.set_solar_date(host.solar_jd-0.25)))
	controls.add_child(host._button(I18n.text("+6小时"),func() -> void: host.set_solar_date(host.solar_jd+0.25)))
	themes.add_child(host._button(I18n.text("观察昼夜 · 1小时/秒"),func() -> void: host.set_solar_rate(1.0/24.0)))
	var seasons: GridContainer = GridContainer.new()
	seasons.columns = 2
	themes.add_child(seasons)
	for index: int in range(4):
		var season_index: int = index
		seasons.add_child(host._button([I18n.text("春分附近"),I18n.text("夏至附近"),I18n.text("秋分附近"),I18n.text("冬至附近")][index],func() -> void: select_season(season_index)))
	ground_mode = CheckButton.new()
	ground_mode.text = I18n.text(I18n.text("日期驱动地面光照"))
	themes.add_child(ground_mode)
	ground_mode.toggled.connect(func(value: bool) -> void: host.ground_light_preview = value)
	source_text = _text("")
	solar.add_child(source_text)
	details_toggle = host._button(I18n.text("科学说明  ›"),func() -> void: _science_open = not _science_open; _present_sections())
	column.add_child(details_toggle)
	detail = _text("")
	detail.visible = false
	column.add_child(detail)
	_build_readable_layout(column)
	host.InterfaceTheme.wrap_panel_labels(self)
	visible = false

func _text(value: String) -> Label:
	var label: Label = host._label(value,18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _process(_delta: float) -> void:
	if not visible or host.coordinator.is_busy(): return
	journey_return_button.visible=host.guided_journey.has_lesson_return()
	journey_return_button.text=I18n.text(I18n.text("返回漫游 · 第%d站") % (host.guided_journey.step+1))
	var stage: Node = host.coordinator.active_scene
	atom_box.visible=host.world.current_scale_id=="atom"
	if atom_box.visible:
		var atom: Dictionary=stage.get_meta("oxygen_atom")
		atom_picker.select(int(atom.mode))
		atom_section.disabled=int(atom.mode)==4
		atom_section.set_pressed_no_signal(bool(atom.section))
		atom_note.text=I18n.text(host.Oxygen.NOTES[int(atom.mode)])
	earth_season_toggle.visible = host.world.current_scale_id=="solar_system"
	earth_season_toggle.text = I18n.text(I18n.text("退出季节参考 ▾") if earth_season_controls.visible else I18n.text("地球公转与季节 ▸"))
	if earth_season_controls.visible: earth_season_controls.present()
	solar_compare_button.visible=host.world.current_scale_id=="solar_system" and not earth_season_controls.visible
	solar_compare_button.text=I18n.text(I18n.text("收起行星对照 ▾") if solar_comparison.visible else I18n.text("行星距离、速率与光时 ▸"))
	size_compare_button.visible=host.world.current_scale_id=="solar_system" and not solar_comparison.visible and not earth_season_controls.visible
	galactic_controls.visible=_topic.get("id","")=="galactic_structure"
	lunar_controls.visible=_topic.get("id","")=="lunar_phases"
	lunar_day_button.disabled=host.solar_jd>=host.Ephemeris.END_JD
	school_controls.visible=_topic.get("id","")=="school"
	algae_controls.visible=_topic.get("id","")=="algae"
	if algae_controls.visible:
		algae_enabled.set_pressed_no_signal(host.world.algal_grazing.enabled)
		algae_adaptive.set_pressed_no_signal(host.world.algal_grazing.adaptive)
	if school_controls.visible: school_alignment.set_pressed_no_signal(host.world.schooling.alignment)
	deadwood_controls.visible=_topic.get("id","")=="deadwood"
	if deadwood_controls.visible: deadwood_mode.select(host.world.deadwood.left_mode)
	runoff_controls.visible=_topic.get("id","")=="runoff"
	if runoff_controls.visible: runoff_rain.set_pressed_no_signal(host.world.runoff.raining)
	runoff_balance.visible=runoff_controls.visible
	if runoff_balance.visible:
		runoff_balance.present(host.world.runoff.snapshot())
		lesson_readout.hide()
	traffic_controls.visible=_topic.get("id","") in ["crossing","traffic"]
	if traffic_controls.visible:
		for profile: int in range(traffic_profile_buttons.size()):
			traffic_profile_buttons[profile].set_pressed_no_signal(host.world.city_traffic.profile==profile)
		traffic_strip.present(host.world.city_traffic.snapshot(host.world.simulation_time_s))
	browse_controls.visible=_topic.get("id","")=="browse"
	if browse_controls.visible: browse_protect.set_pressed_no_signal(host.world.browse.protected_left)
	var id: String = host.world.current_scale_id
	satellite_catalogue.present()
	heading.show()
	branch_picker.hide()
	species_source.text=I18n.text(I18n.text("天体资料 ↗") if Satellites.is_system(id) else I18n.text("物种资料 ↗"))
	earth_box.visible = id=="earth" and _topic.get("id","")!="earth_daylight"
	if earth_daylight_controls.visible: earth_daylight_controls.present()
	if earth_box.visible:
		var site: Dictionary = Sites.for_scale(host._earth_reference)
		earth_detail.text = I18n.text(str(site.description))
		if site.kind=="regional": earth_detail.text = I18n.text(I18n.text("14.6667°S / 145.4667°E · 区域参考\n")+earth_detail.text)
		earth_focus.text = I18n.text(I18n.text("定位海洋区域") if site.kind=="regional" else I18n.text("查看参考纬度"))
	solar_toggle.visible = Satellites.is_system(id) or id in ["solar_system","earth","earth_moon","city","woodland","desert","polar","arctic","jupiter_moons","night_sky"]
	solar.visible = solar_toggle.visible and _astro_open
	solar_toggle.text = I18n.text(I18n.text("天文参数与日期 ▾") if _astro_open else I18n.text("天文参数与日期 ▸"))
	body_picker.visible = id=="solar_system" and not earth_season_controls.visible
	orbit_view_button.visible = id=="solar_system" and not earth_season_controls.visible and (host.solar_follow>=0 or host.solar_orbit_focus>=0)
	orbit_view_button.text = I18n.text(I18n.text("所选轨道正视") if host.solar_orbit_focus>=0 and not host.solar_plane_view.is_empty() else I18n.text("返回行星近看") if host.solar_orbit_focus>=0 else I18n.text("查看所选轨道"))
	solar_plane_controls.visible=id=="solar_system" and not earth_season_controls.visible
	solar_plane_hint.visible=solar_plane_controls.visible
	solar_plane_hint.text=I18n.text(I18n.text("共同参照：J2000黄道；保持原轨道倾角。"))
	if host.solar_plane_view=="side": solar_plane_hint.text+=I18n.text(I18n.text("\n侧视预置沿固定方向；画面斜率不等于倾角。"))
	elif host.solar_plane_view=="top": solar_plane_hint.text+=I18n.text(I18n.text("\n俯视预置从黄道北面观察；拖动可改变镜头。"))
	orbit_source_hint.visible = orbit_view_button.visible
	orbit_source_hint.text = I18n.text(I18n.text("青实线：DE440日期轨迹 · 橙虚线：近似教学椭圆") if Ephemeris.position_source()=="DE440离线行星位置" else I18n.text("离线星历缺失：仅显示近似教学椭圆"))
	mode.visible = Satellites.is_system(id) or id in ["solar_system","earth_moon","jupiter_moons"]
	mode.disabled=Satellites.is_system(id) or id=="earth_moon"
	mode.tooltip_text=I18n.text("近景的宿主、轨道和卫星半径采用同一长度比例；小天体识别点不代表大小。") if Satellites.is_system(id) else I18n.text("全景轨道可切为AU距离同比；进入近景后，宿主与卫星距离和半径始终同比。")
	mode.text = I18n.text(I18n.text("距离与半径同比（识别点非大小）") if Satellites.is_system(id) else I18n.text("地月距离与半径同比") if id=="earth_moon" else I18n.text("轨道距离同比"))
	themes.visible = id!="solar_system"
	ground_mode.visible = Satellites.is_system(id) or id in ["city","woodland","desert","polar","arctic"]
	if id != _scale:
		_scale = id
		_astro_open = false
		_observation_open = false
		_science_open = false
		for index: int in range(I18n.array(BRANCHES).size()):
			if I18n.array(BRANCHES)[index][1]==id: branch_picker.selected = index
		_topics = I18n.dictionaries(Topics.for_scale(id))
		topic_picker.clear()
		topic_picker.add_item(I18n.text("选择一个主题开始观察"))
		for item: Dictionary in _topics: topic_picker.add_item(item.title)
		topic_box.visible = not _topics.is_empty()
		if _restoring_language: _clear_topic_presentation()
		else: clear_topic()
		detail.visible = false
		scroll.scroll_vertical = 0
		var science: Dictionary=host.ScienceReference.describe(id)
		detail.text = I18n.text(I18n.meta_text(stage,"content_summary",science.kind))
		if id in ["earth","atmosphere"]: detail.text+=I18n.text("\n"+str(science.basis)+"\n"+str(science.limit))
		if id in ["reef","school","fish","pacific"]:
			detail.text = I18n.text(I18n.meta_text(stage,"content_summary",I18n.text("海葵鱼保留礁区到ATP参考模型；新增背景生物不共享其生理数值。")))
		object_picker.clear()
		object_picker.add_item(I18n.text("选择并跟随代表对象"))
		for entry: Dictionary in host.content_targets(): object_picker.add_item(entry.label)
		object_box.visible = object_picker.item_count>1 and not Satellites.is_system(id)
	species_source.visible = false
	object_picker.disabled = Satellites.is_system(id) and not Satellites.available(host.solar_jd)
	var current_targets: Array[Dictionary]=host.content_targets()
	if object_picker.item_count==current_targets.size()+1:
		for index: int in range(current_targets.size()):
			if object_picker.get_item_text(index+1)!=str(current_targets[index].label): object_picker.set_item_text(index+1,current_targets[index].label)
	if object_picker.item_count>host._content_follow+1: object_picker.selected = host._content_follow+1
	activity.text = I18n.text(I18n.text("选择对象可近看，拖动环绕，滚轮调整距离。"))
	if (Satellites.is_system(id) or id in ["woodland","city","desert","polar","arctic","reef","school","fish","pacific"]) and stage.has_meta("content_summary"):
		detail.text = I18n.text(I18n.meta_text(stage,"content_summary"))
		var targets: Array[Dictionary] = host.content_targets()
		var selected: int = object_picker.selected-1
		if selected>=0 and selected<targets.size():
			activity.text = I18n.text(str(targets[selected].node.get_meta("activity",I18n.text("观察结构与空间"))))
			detail.text += I18n.text("\n"+str(targets[selected].get("role","")))
			_species_url = str(targets[selected].get("source_url",""))
			species_source.visible = not _species_url.is_empty()
			if not Satellites.is_system(id):
				detail.text += I18n.text(I18n.text("\n形态与食性参考资料；运动是作者设定的教学示意。") if species_source.visible else I18n.text("\n合成形态与作者设定活动；未作物种或社会模型标定。"))
	object_box.visible = object_picker.item_count>1 and not Satellites.is_system(id)
	# Active time/relationship lessons take priority over duplicate object details.
	noon_button.visible=_topic.get("id","")!="jovian_periods"
	coral_controls.visible=_topic.get("id","")=="coral_symbiosis"
	if coral_controls.visible: coral_heat.set_pressed_no_signal(host.world.symbiosis.heated)
	var priority_topic: bool = _topic.get("id","") in ["galactic_structure","day_octopus","day_octopus_suckers","black_sea_cucumber","black_sea_cucumber_feeding","giant_clam","giant_clam_mantle","algae","school","deadwood","jovian_periods","desert_iguana","desert_cactus","desert_leaf","desert_ocotillo","desert_ocotillo_spine","desert_ocotillo_flower","desert_brittlebush","desert_brittlebush_leaf","desert_brittlebush_flower","desert_rat","polar_coast","polar_aurora","arctic_ice","adelie_penguin","ice_krill_habitat","ice_krill","ice_krill_head","fungus","coral_symbiosis","bullfrog","river_wetland","cattail","green_darner","freshwater_school","golden_shiner","wild_celery","wild_celery_leaf","lunar_phases","season_light","solar_roof","crossing","traffic","street_walkers","city_sparrow","city_monarch","city_milkweed","city_pond","city_mallard_drake","city_mallard_hen","city_ginkgo_season","city_park_trees","city_maple_leaf","city_redbud_bloom","city_redbud_leaf","bird","monarch","monarch_larva","graze","turtle","turtle_surface","browse","coral_colony","coral_polyp","runoff"]
	priority_topic = priority_topic or _topic.get("id","") in ["freshwater_habitats","banded_killifish_shoal","banded_killifish"]
	priority_topic = priority_topic or _topic.get("id","") in ["red_fox","red_fox_head"]
	priority_topic = priority_topic or _topic.get("id","") in Topics.MonarchStages.TOPICS
	priority_topic = priority_topic or _topic.get("id","")=="earth_daylight"
	priority_topic = priority_topic or _topic.get("id","") in Topics.TurtleComparison.TOPICS
	if monarch_controls.visible:
		for button: Button in monarch_controls.get_children():
			button.set_pressed_no_signal(button.get_meta("monarch_topic")==_topic.get("id",""))
	if priority_topic and object_box.get_index()<topic_box.get_index():
		topic_box.get_parent().move_child(topic_box,object_box.get_index())
	elif not priority_topic and object_box.get_index()>topic_box.get_index():
		object_box.get_parent().move_child(object_box,topic_box.get_index())
	if not _topic.is_empty(): lesson_readout.text = I18n.text(Topics.readout(host,str(_topic.id)))
	kepler_advance.disabled = host.solar_jd+Topics.Kepler.DAYS>Ephemeris.END_JD
	if solar.visible:
		_updating = true
		date_text.text = I18n.text(Orientation.timestamp(host.solar_jd)+I18n.text("\n观察推演：")+host.InterfaceTheme.astronomy_rate(host.solar_rate))
		date_slider.min_value=Satellites.START_JD if Satellites.is_system(id) else Ephemeris.START_JD
		date_slider.max_value=Satellites.END_JD if Satellites.is_system(id) else Ephemeris.END_JD
		date_slider.step=1./24. if Satellites.is_system(id) else 1.
		date_epoch_button.text=I18n.text("J2000")
		date_slider.set_value_no_signal(host.solar_jd)
		mode.set_pressed_no_signal(true if Satellites.is_system(id) or id=="earth_moon" else host.solar_true_distance)
		for index: int in range(RATES.size()):
			if absf(RATES[index]-float(host.solar_rate))<1e-12: rate_picker.selected = index
		ground_mode.set_pressed_no_signal(host.ground_light_preview)
		var i: int = host.solar_follow if host.solar_follow>=0 else host.solar_orbit_focus
		body_picker.selected = i+1
		if id=="solar_system" and i>=0:
			var el: Array[float] = Ephemeris.elements(i,host.solar_jd)
			var speed: float = Ephemeris.speed_km_s(i,host.solar_jd)
			var speed_line: String = I18n.text("DE440日心几何速率 %.2f km/s") % speed if is_finite(speed) else I18n.text("DE440速度数据不可用")
			if i==2: speed_line += I18n.text("（地月质心）")
			elif i>=4: speed_line += I18n.text("（行星系统质心）")
			var short_speed: String = I18n.text("日心 %.2f km/s") % speed if is_finite(speed) else I18n.text("速度数据不可用")
			if i==2: short_speed += I18n.text(" · 地月质心")
			elif i>=4: short_speed += I18n.text(" · 系统质心")
			orbit_source_hint.text += I18n.text("\n%s · %s" % [I18n.strings(Ephemeris.NAMES)[i],short_speed])
			body_text.text = I18n.text(I18n.text("%s · 距太阳 %.3f AU\n%s\n平均半径 %s km · 公转 %.3f 年\n偏心率 %.4f · 倾角 %.3f°") % [I18n.strings(Ephemeris.NAMES)[i],Ephemeris.position_au(i,host.solar_jd).length(),speed_line,str(Ephemeris.RADII_KM[i]),Ephemeris.PERIOD_YEARS[i],el[1],el[2]])
			body_text.text += I18n.text(I18n.text("\n%s · 轴倾角 %.2f°\n%s") % [Orientation.rotation_label(i),Orientation.obliquity_deg(i,host.solar_jd),I18n.text("逆向自转（相对轨道角动量）") if Orientation.obliquity_deg(i,host.solar_jd)>90.0 else I18n.text("顺向自转")])
			body_text.text += I18n.text(I18n.text("\n自转、公转和月球均使用同一天文日期/倍率；快进纹理模糊不改变姿态或转速。切至1小时/秒看自转。"))
			if i>=4: body_text.text += I18n.text(I18n.text("\nIAU参考旋转系统：木星/土星不是固体表面，云带各纬度可有不同转速。"))
			body_text.text += I18n.text(I18n.text("\n橙线：所选轨道；12个橙点：同一行星每隔约 %.1f 天的等时位置，不是额外天体。近日点 %.3f AU · 远日点 %.3f AU。") % [Ephemeris.PERIOD_YEARS[i]*365.25/12.0,el[0]*(1.0-el[1]),el[0]*(1.0+el[1])])
			body_text.text += I18n.text(I18n.text("\n青实线为DE440缓存在当前日期附近一个名义周期的采样轨迹；橙虚线与等时点使用冻结的Table 1近似椭圆。当前行星球体：%s。等时点不是12个未来日期的精密星历。") % I18n.text(Ephemeris.position_source()))
			if host.solar_orbit_focus>=0:
				var orbit_view_name: String=I18n.text("共同黄道侧视") if host.solar_plane_view=="side" else I18n.text("共同黄道俯视") if host.solar_plane_view=="top" else I18n.text("所选轨道正视")
				body_text.text += I18n.text(I18n.text("\n%s；其他行星球体缩小、标签隐藏，轨道保留。日期变化时行星沿同一星历移动，参考椭圆按年份更新。") % orbit_view_name)
			body_text.text += I18n.text(I18n.text("\n天然卫星 %d颗；%s") % [Satellites.count(Satellites.HOSTS[i]),I18n.text("没有天然卫星") if i<2 else I18n.text("双击行星进入卫星系统（地球进入地表，月球另有地月视图）")])
			if i == 0: body_text.text += I18n.text(I18n.text("\n表面：MESSENGER灰度历史拼图；极区保留拼接痕迹，非真彩色/实时影像。"))
			elif i == 3: body_text.text += I18n.text(I18n.text("\n表面：Viking / USGS历史着色拼图；颜色经过处理，非实时地表/天气。"))
		elif id=="night_sky": body_text.text=I18n.text(Topics.readout(host,"ground_sky"))
		elif Satellites.is_system(id): body_text.text=I18n.text(host.SatelliteBuilder.readout(host))
		elif id=="solar_system":
			var choice: Dictionary=host.selected_spatial_choice()
			body_text.text = I18n.text(I18n.text("太阳、八行星和月球的自转/公转共用同一日期与倍率。\n快进会模糊自转细节；1小时/秒看自转，全景默认10天/秒看公转。\n全景为距离压缩、大小放大的示意。近景宿主与卫星的距离、半径同比；远方天体保持真实方向和视大小，识别点不代表大小。"))
			if bool(choice.get("moon",false)):
				body_text.text = I18n.text(I18n.text("月球 · 地球的天然卫星\n绕地球恒星周期约27.32天 · 自转约27.32天\n月相周期约29.53天，与恒星周期不同。\n月距约 %.0f km · 同步自转仍有天平动\n全景月距压缩；选中月球后以真实距离和大小比例观察。\n自转、公转和行星共享同一日期与倍率。") % Orientation.moon_position_km(host.solar_jd).length())
			elif bool(choice.get("sun",false)):
				body_text.text = I18n.text(I18n.text("太阳 · 太阳系的恒星\nIAU参考自转周期约25.38天，读取同一天文日期与倍率。\n太阳各纬度可有不同旋转速度；当前参考系不是流体差速模拟。"))
		else:
			var declination: float = rad_to_deg(asin(Orientation.sun_ecef(host.solar_jd).y))
			body_text.text = I18n.text(I18n.text("太阳直射纬度 %.2f°\n北纬35°昼长 %.1f h · 南纬35° %.1f h\n轴倾角使两半球季节相反；昼长不计折射。") % [declination,Orientation.latitude_daylight_hours(35,host.solar_jd),Orientation.latitude_daylight_hours(-35,host.solar_jd)])
			if id=="earth_moon":
				body_text.text = I18n.text(I18n.text("月距约 %.0f km · 地面所见受光比例 %.0f%%\n地月半径比 1 : 0.273 · %s\n") % [Orientation.moon_position_km(host.solar_jd).length(),Orientation.illumination(host.solar_jd)*100.0,I18n.text("距离与平均半径同比")] + body_text.text)
			if id in ["woodland","city","desert","polar","arctic"]:
				var ground_site: Dictionary = Sites.for_scale(id)
				body_text.text = I18n.text(I18n.text("太阳直射纬度 %.2f°\n参考纬度 %s · 昼长 %.1f h\n昼长不计折射或地形遮挡。") % [declination,Sites.latitude_label(float(ground_site.lat)),Orientation.latitude_daylight_hours(ground_site.lat,host.solar_jd)])
				body_text.text += I18n.text(I18n.text("\n合成场景光照参考：%s / %.0f°%s。%s\n%s") % [Sites.latitude_label(float(ground_site.lat)),absf(ground_site.lon),"W" if ground_site.lon<0 else "E",(I18n.text("太阳高度 %.1f°") % float(stage.get_meta("sun_elevation",0.0)) if host.ground_light_preview else I18n.text("当前为固定展示光照")),I18n.text("城市银杏会按作者日历改变叶色与叶量；其他植被未接入物候。") if id=="city" else I18n.text("极地海冰、企鹅和冰磷虾不随日期预测；季节按钮只改变光照。") if id=="polar" else I18n.text("季节按钮对齐近似太阳正午，仅改变光照。")])
		source_text.text = I18n.text(Ephemeris.position_source() + I18n.text("（1800–2050 TDB）；选中行星的青实线为DE440一名义周期采样折线，橙虚线/等时点另用JPL Table 1近似椭圆。IAU自转模型不含地球实时定向参数。月球位置为ERFA/Meeus摄动近似，月面朝向采用NAIF IAU_MOON，不预测日月食。\n推演日期用于观察、可选地面光照及城市银杏作者季节外观；不推进礁区生理多年。"))
		if id=="solar_system" and i>=0: source_text.text += I18n.text(I18n.text("\n所选速度是同一DE440日心缓存位置对TDB日期的导数，不是沿Table 1橙虚线求值；地球使用地月质心，木/土/天/海使用行星系统质心。缺失缓存时不显示速度。"))
		if id=="night_sky": source_text.text=I18n.text(host.ScienceReference.text_for("night_sky"))
		if Satellites.is_system(id): source_text.text=I18n.text(I18n.text("JPL Horizons行星中心几何矢量 · 2026-09-01—12-01 TDB；日期范围外不外推。名录冻结于2026-10-13，缺测条目仍可查。距离同比，已知半径默认×5；中性球/识别点标不是真实表面。伽利略四卫星沿用USGS历史拼图及理想同步姿态。"))
		_updating = false
	_present_summary()
	_present_sections()
	fit_window(host.ui_view_size())

func _divider() -> Control:
	var line: ColorRect = ColorRect.new()
	line.color = Color(.55,.65,.72,.24)
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _build_readable_layout(column: VBoxContainer) -> void:
	# Reuse the actual lesson controls and callbacks; only presentation changes.
	var advanced: Array[Node] = []
	for child: Node in column.get_children():
		if child not in [column.get_child(0),journey_return_button,solar_toggle,solar,details_toggle,detail]: advanced.append(child)
	var summary: VBoxContainer = VBoxContainer.new()
	summary.add_theme_constant_override("separation",14)
	column.add_child(summary); column.move_child(summary,2)
	summary.add_child(host._label(I18n.text("当前观察"),16,host.InterfaceTheme.MUTED))
	current_title=host._label("",30); current_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; summary.add_child(current_title)
	summary.add_child(_divider())
	selection_heading=host._label(I18n.text("已选对象"),16,host.InterfaceTheme.MUTED); summary.add_child(selection_heading)
	selection_title=host._label("",26); selection_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; summary.add_child(selection_title)
	summary_text=_text(""); summary.add_child(summary_text)
	summary_hint=_text(""); summary_hint.add_theme_color_override("font_color",host.InterfaceTheme.ACCENT); summary.add_child(summary_hint)
	summary.add_child(_divider())
	observation_toggle=host._button(I18n.text("观察主题  ›"),func() -> void: _observation_open=not _observation_open; _present_sections())
	observation_toggle.alignment=HORIZONTAL_ALIGNMENT_LEFT
	observation_toggle.custom_minimum_size.y=52
	column.add_child(observation_toggle)
	observation_body=VBoxContainer.new(); observation_body.add_theme_constant_override("separation",12); column.add_child(observation_body)
	for child: Node in advanced: child.reparent(observation_body)
	column.move_child(details_toggle,-1)
	details_toggle.alignment=HORIZONTAL_ALIGNMENT_LEFT; details_toggle.custom_minimum_size.y=52
	science_body=VBoxContainer.new(); science_body.add_theme_constant_override("separation",14); column.add_child(science_body)
	detail.reparent(science_body); solar_toggle.reparent(science_body); solar.reparent(science_body)
	science_body.add_child(host._button(I18n.text("完整说明与来源  ›"),host._toggle_info))
	branch_picker.hide()
	_present_sections()

func _present_summary() -> void:
	var id: String=host.world.current_scale_id
	current_title.text=I18n.text(str(host.Catalog.describe(id).label))
	var data: Dictionary=host.immersive_interface._context_data()
	var selected: bool=not data.is_empty()
	selection_heading.visible=selected; selection_title.visible=selected
	selection_heading.text=I18n.text(I18n.text("已选区域") if id=="earth" else I18n.text("已选对象 / 主题"))
	selection_title.text=I18n.text(str(data.get("title","")))
	if id=="earth":
		var region: String=str(data.get("region",""))
		summary_text.text=I18n.text("在地面仰望星河。
夜空随共同日期变化。" if region=="night_sky" else str(data.get("note","转动地球，发现不同地域的生命与环境。")))
		summary_hint.text=I18n.text(I18n.text("点选地球区域，\n再次点击或双指靠近进入。"))
	elif selected:
		var note: String=str(_topic.get("description",data.get("note","")))
		summary_text.text=I18n.text(note.left(88)+"…" if note.length()>88 else note)
		summary_hint.text=I18n.text(str(data.get("path",I18n.text("拖动环绕 · 双指靠近"))))
	else:
		summary_text.text=I18n.text(str(host.immersive_interface.TAGS.get(id,I18n.text("科学参考场景"))))
		summary_hint.text=I18n.text("拖动环顾，直接点选3D对象。
展开主题，比较现象与科学依据。")

func _present_sections() -> void:
	summary_text.visible=not _observation_open and not _science_open
	summary_hint.visible=not _observation_open and not _science_open
	observation_body.visible=_observation_open
	var section: String = I18n.text("卫星名录与观察") if Satellites.is_system(host.world.current_scale_id) else I18n.text("观察主题")
	observation_toggle.text=I18n.text(section+("  ⌄" if _observation_open else "  ›"))
	science_body.visible=_science_open
	detail.visible=_science_open
	details_toggle.text=I18n.text(I18n.text("科学说明  ⌄") if _science_open else I18n.text("科学说明  ›"))

func fit_window(window_size: Vector2i) -> void:
	var margin: float=24 if window_size.x>=850 else 16
	var width: float=minf(380,float(window_size.x)-margin*2)
	offset_left=margin; offset_top=92; offset_right=margin+width
	var height: float=320
	if is_instance_valid(_column):
		var frame: StyleBox=get_theme_stylebox("panel")
		height=_column.get_combined_minimum_size().y+frame.get_margin(SIDE_TOP)+frame.get_margin(SIDE_BOTTOM)
	var available: float=maxf(100,float(window_size.y)-92-88)
	offset_bottom=92+minf(height,available)

func clear_topic() -> void:
	earth_season_controls.close()
	host.end_lunar_close_view()
	if is_instance_valid(host.coordinator) and is_instance_valid(host.coordinator.active_scene):
		Topics.EarthDaylight.set_active(host.coordinator.active_scene,false)
	_clear_topic_presentation()
	if is_instance_valid(host.learning_overlay): host.learning_overlay.select("")

func _clear_topic_presentation() -> void:
	earth_daylight_controls.hide()
	polar_globe_button.hide()
	turtle_comparison_controls.present("")
	topic_box.get_child(0).show()
	_topic = {}
	topic_picker.selected = 0
	lesson_readout.text = I18n.text("")
	lesson_text.text = I18n.text("")
	lesson_text.hide()
	lesson_readout.hide()
	markers_toggle.hide()
	lesson_controls.hide()
	season_controls.hide()
	polar_sky_controls.hide()
	octopus_controls.hide()
	rat_night_button.hide()
	rat_reset_button.hide()
	rat_view_controls.hide()
	penguin_view_controls.hide()
	traffic_controls.hide()
	monarch_controls.hide()
	monarch_stage_hint.hide()
	city_bird_controls.hide()
	ginkgo_controls.hide()
	park_tree_controls.hide()
	city_bird_context_view=false
	kepler_controls.hide()
	browse_controls.hide()
	galactic_controls.hide()
	lunar_controls.hide()
	school_controls.hide()
	algae_controls.hide()
	deadwood_controls.hide()
	runoff_controls.hide()
	runoff_balance.hide()
	coral_controls.hide()
	lesson_source.hide()


func select_earth_site(index: int) -> void:
	if index<0 or index>=I18n.dictionaries(Sites.SITES).size() or host.world.current_scale_id!="earth": return
	earth_picker.selected = index
	host._earth_reference = str(I18n.dictionaries(Sites.SITES)[index].scale)

func toggle_solar_comparison() -> void:
	if host.world.current_scale_id!="solar_system" or host.coordinator.is_busy() or not host.world.foreground: return
	solar_comparison.visible=not solar_comparison.visible
	if solar_comparison.visible:
		clear_topic()
		host.follow_planet(-1)
		_astro_open=false
		scroll.scroll_vertical=0

func open_topic(id: String) -> bool:
	if host.coordinator.is_busy() or not host.world.foreground: return false
	show()
	# A hidden panel has not refreshed its topic registry after a scene change.
	_process(0.0)
	return select_topic(id)

func select_topic(id: String, preserve_date: bool = false) -> bool:
	for index: int in range(_topics.size()):
		if _topics[index].id==id:
			topic_picker.selected = index+1
			_activate_topic(index+1,preserve_date)
			return true
	return false

func _activate_topic(index: int, preserve_date: bool = false) -> void:
	if index<=0 or index>_topics.size():
		clear_topic()
		return
	solar_comparison.hide()
	_topic = _topics[index-1]
	_observation_open=true
	_present_sections()
	Topics.EarthDaylight.set_active(host.coordinator.active_scene,_topic.id=="earth_daylight")
	city_bird_context_view=false
	if _topic.id=="earth_daylight":
		Topics.EarthDaylight.set_polar_reference(host.coordinator.active_scene,false)
		Topics.EarthDaylight.focus(host)
		_astro_open=false
	elif _topic.id=="galactic_structure":
		Topics.Galactic.focus(host,false)
		_astro_open=false
	elif _topic.id=="lunar_phases":
		host.focus_lunar(false)
		_astro_open=false
	elif _topic.id=="mercury_orbit":
		host.focus_kepler()
		_astro_open = false
	else:
		var following: int=int(_topic.follow)
		if _topic.has("target_id"):
			var targets: Array[Dictionary]=host.content_targets()
			for i: int in range(targets.size()):
				if targets[i].node.get_meta("stable_id","")==_topic.target_id: following=i+1; break
		host.follow_content(following)
	if _topic.has("view_distance"):
		var stage: Node = host.coordinator.active_scene
		var direction: Vector3 = (stage.camera.position-host._orbit_target).normalized()
		stage.set_pose(host._orbit_target+direction*float(_topic.view_distance),host._orbit_target)
	host.learning_overlay.select(str(_topic.id))
	_present_topic()
	if season_controls.visible or polar_sky_controls.visible: host.ground_light_preview = true
	if _topic.id=="season_light" and not preserve_date: _local_noon()

func _present_topic() -> void:
	lesson_readout.show()
	if _topic.id=="runoff":
		topic_box.move_child(runoff_controls,2)
		topic_box.move_child(runoff_balance,3)
		runoff_balance.show()
		lesson_readout.hide()
	earth_daylight_controls.visible = _topic.id=="earth_daylight"
	topic_box.get_child(0).visible = not earth_daylight_controls.visible
	if earth_daylight_controls.visible:
		topic_box.move_child(earth_daylight_controls,2)
		earth_daylight_controls.present()
		lesson_readout.hide()
	lesson_text.show()
	markers_toggle.visible = _topic.id not in ["season_light","jovian_periods","city_ginkgo_season","city_park_trees","street_walkers"]
	lesson_text.text = I18n.text(str(_topic.observe)+"\n"+str(_topic.limit))
	lesson_source.visible = not str(_topic.source).is_empty()
	kepler_controls.visible = _topic.id=="mercury_orbit"
	lesson_controls.visible = _topic.id in ["solar_roof","season_light","jovian_periods"]
	turtle_comparison_controls.present(str(_topic.id))
	if turtle_comparison_controls.visible: topic_box.move_child(turtle_comparison_controls,2)
	monarch_controls.visible = _topic.id in Topics.MonarchStages.TOPICS
	monarch_stage_hint.visible=monarch_controls.visible
	if monarch_controls.visible:
		topic_box.move_child(monarch_controls,2)
		topic_box.move_child(monarch_stage_hint,3)
	city_bird_controls.visible = _topic.id=="city_sparrow"
	ginkgo_controls.visible = _topic.id=="city_ginkgo_season" or _topic.id=="city_ginkgo_leaf"
	park_tree_controls.visible = _topic.id in ["city_park_trees","city_maple_leaf","city_redbud_bloom","city_redbud_leaf"]
	season_controls.visible = _topic.id in ["solar_roof","season_light"]
	polar_sky_controls.visible = _topic.id=="polar_aurora" and host.world.current_scale_id in ["polar","arctic"]
	if polar_sky_controls.visible:
		topic_box.move_child(polar_sky_controls,2)
	polar_globe_button.visible = _topic.id=="season_light" and host.world.current_scale_id=="polar"
	if polar_globe_button.visible:
		topic_box.move_child(polar_globe_button,2)
		topic_box.move_child(lesson_controls,3)
		topic_box.move_child(season_controls,4)
	octopus_controls.visible = _topic.id in ["day_octopus", "day_octopus_suckers"]
	rat_night_button.visible = _topic.id=="desert_rat"
	rat_reset_button.visible = _topic.id=="desert_rat"
	rat_view_controls.visible = _topic.id=="desert_rat"
	penguin_view_controls.visible = _topic.id=="adelie_penguin"
	traffic_controls.visible = _topic.id in ["crossing","traffic"]
	if traffic_controls.visible: topic_box.move_child(traffic_controls,2)

func restore_localized_topic(topic_id: String) -> void:
	var was_visible: bool = visible
	show()
	_restoring_language = true
	_process(0.0)
	_restoring_language = false
	for index: int in range(_topics.size()):
		if str(_topics[index].id) == topic_id:
			_topic = _topics[index]
			topic_picker.select(index+1)
			_present_topic()
			break
	visible = was_visible

func view_polar_from_earth() -> void:
	if host.coordinator.is_busy() or not host.world.foreground or host.world.current_scale_id!="polar" or _topic.get("id","")!="season_light": return
	host.start_guide_visit("earth","earth_daylight",true,true)

func select_traffic_profile(profile: int) -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="city" or not _topic.get("id","") in ["crossing","traffic"]: return
	if host.world.set_city_traffic_profile(profile):
		host.message_label.text=I18n.text(I18n.text("路口从等待阶段重启；世界时间与其他实验继续保持。"))

func reset_traffic() -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="city" or not _topic.get("id","") in ["crossing","traffic"]: return
	host.world.reset_city_traffic()
	host.message_label.text=I18n.text(I18n.text("已重启本路口；用下方时间控件继续观察。"))

func focus_penguin_view(mode: int) -> void:
	if host.coordinator.is_busy() or not host.world.foreground or host.world.current_scale_id!="polar" or _topic.get("id","")!="adelie_penguin": return
	var data: Dictionary=host.coordinator.active_scene.get_meta("polar",{})
	if data.is_empty() or mode<0 or mode>2: return
	var target: Node3D=data.birds[0] if mode==0 else data.activity_focus if mode==1 else data.activity_overview
	var targets: Array[Dictionary]=host.content_targets(false)
	for index: int in range(targets.size()):
		if targets[index].node==target:
			host.follow_content(index+1)
			return

func focus_rat_view(close_view: bool) -> void:
	if host.world.current_scale_id!="desert" or _topic.get("id","")!="desert_rat": return
	var stage: Node=host.coordinator.active_scene
	var target: Node3D=stage.get_meta("kangaroo_rat" if close_view else "kangaroo_rat_route_observer",null)
	if target==null: return
	var targets: Array[Dictionary]=host.content_targets()
	for index: int in range(targets.size()):
		if targets[index].node==target:
			host.follow_content(index+1)
			return

func focus_city_bird_context() -> void:
	if host.world.current_scale_id!="city" or _topic.get("id","")!="city_sparrow": return
	city_bird_context_view=true
	host._pan_offset=Vector3.ZERO
	host._orbit_target=CITY_BIRD_CONTEXT_TARGET
	host.coordinator.active_scene.set_pose(CITY_BIRD_CONTEXT_POSITION,CITY_BIRD_CONTEXT_TARGET)

func focus_city_bird_close() -> void:
	if host.world.current_scale_id!="city" or _topic.get("id","")!="city_sparrow": return
	city_bird_context_view=false
	host.follow_content(8)

func select_ginkgo_season(date: String) -> void:
	select_city_tree_date(date)

func select_city_tree_date(date: String) -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="city" or not _topic.get("id","") in ["city_ginkgo_season","city_ginkgo_leaf","city_park_trees","city_maple_leaf","city_redbud_bloom","city_redbud_leaf"]: return
	var site: Dictionary = Sites.for_scale("city")
	host.set_solar_rate(0.0)
	host.set_solar_date(Seasons.noon(Seasons.date_jd(date),float(site.lon)))
	host.ground_light_preview=true

func _local_noon() -> void:
	if not host.world.current_scale_id in ["woodland","city","desert","polar","arctic"]: return
	var site: Dictionary = Sites.for_scale(host.world.current_scale_id)
	host.set_solar_rate(0.0)
	host.set_solar_date(Seasons.noon(host.solar_jd,float(site.lon)))
	host.ground_light_preview = true

func _local_night() -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="desert" or _topic.get("id","")!="desert_rat": return
	var site: Dictionary=Sites.for_scale("desert")
	var latitude: float=float(site.lat)
	var longitude: float=float(site.lon)
	var night_threshold: float=sin(deg_to_rad(-8.0))
	var selected: float=host.solar_jd
	if Orientation.local_sun(selected,latitude,longitude).y>=night_threshold:
		var found: bool=false
		for step: int in range(1,49):
			var candidate: float=host.solar_jd+float(step)/48.0
			if candidate>Ephemeris.END_JD: break
			if Orientation.local_sun(candidate,latitude,longitude).y<night_threshold:
				selected=candidate
				found=true
				break
		if not found:
			for step: int in range(1,49):
				var candidate: float=host.solar_jd-float(step)/48.0
				if candidate<Ephemeris.START_JD: break
				if Orientation.local_sun(candidate,latitude,longitude).y<night_threshold:
					selected=candidate
					found=true
					break
		if not found: return
	host.set_solar_rate(0.0)
	host.set_solar_date(selected)
	host.ground_light_preview=true

func select_season(index: int) -> void:
	if host.coordinator.is_busy(): return
	host.set_solar_rate(0.0)
	host.set_solar_date(Seasons.preset(index,host.world.current_scale_id))
	if host.world.current_scale_id in ["woodland","city","desert","polar","arctic"]: host.ground_light_preview = true

func select_polar_sky(night: bool) -> void:
	if host.coordinator.is_busy() or not host.world.foreground or not host.world.current_scale_id in ["polar","arctic"] or _topic.get("id","")!="polar_aurora": return
	var north: bool = host.world.current_scale_id=="arctic"
	var season: int = (3 if north else 1) if night else (1 if north else 3)
	var date: float = Seasons.preset(season,host.world.current_scale_id)
	if night: date -= .5
	host.set_solar_rate(0.0)
	host.set_solar_date(date)
	host.ground_light_preview = true
	host.message_label.text = I18n.text(I18n.text("冬季午夜参考 · 极光为作者演示，非当日预报") if night else I18n.text("夏季正午参考 · 同日期太阳方向"))

func select_kepler_segment(far: bool) -> void:
	if host.coordinator.is_busy() or _topic.get("id","")!="mercury_orbit": return
	host.set_solar_rate(0.0)
	host.set_solar_date(Topics.Kepler.segment_start(host.solar_jd,far))

func advance_kepler() -> void:
	if host.coordinator.is_busy() or _topic.get("id","")!="mercury_orbit" or host.solar_jd+Topics.Kepler.DAYS>Ephemeris.END_JD: return
	host.set_solar_rate(0.0)
	host.set_solar_date(host.solar_jd+Topics.Kepler.DAYS)

func select_lunar_phase(quarter: int) -> void:
	if host.coordinator.is_busy() or _topic.get("id","")!="lunar_phases": return
	var next: float = Topics.Lunar.Phase.next_phase(host.solar_jd,quarter)
	if not is_finite(next):
		host.message_label.text=I18n.text(I18n.text("已到近似模型日期边界；请在天文参数里选择较早日期"))
		return
	host.set_solar_rate(0.0)
	host.set_solar_date(next)

func select_eclipse_example(lunar: bool) -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="earth_moon": return
	host.set_solar_rate(0.0)
	host.set_solar_date(Topics.Lunar.Eclipse.LUNAR_EXAMPLE_JD if lunar else Topics.Lunar.Eclipse.SOLAR_EXAMPLE_JD)
	if lunar: host.focus_lunar(true)
	else: host.focus_eclipse_earth()
	host.message_label.text=I18n.text(I18n.text("示例日期附近的近似遮光几何；±30分钟观察影子变化，不作食时/路径预报"))

func step_eclipse(days: float) -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="earth_moon": return
	host.set_solar_rate(0.0)
	host.set_solar_date(clampf(host.solar_jd+days,host.Ephemeris.START_JD,host.Ephemeris.END_JD))
	if host.lunar_observation_view=="shadow": host.focus_eclipse_earth()

func toggle_earth_season() -> void:
	if host.coordinator.is_busy() or host.world.current_scale_id!="solar_system" or not host.world.foreground: return
	if earth_season_controls.visible:
		earth_season_controls.close()
		host.follow_planet(-1)
	else:
		clear_topic()
		solar_comparison.hide()
		_astro_open=false
		earth_season_controls.open()
	scroll.scroll_vertical=0
