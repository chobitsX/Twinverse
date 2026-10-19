extends Control
## Presentation only. All actions delegate to the existing world/observer owner.
const UI = preload("res://scripts/experience/interface_theme.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")
const RATES: Array[float] = [.25,.5,1.0,2.0,4.0]
const ASTRONOMY_RATES: Array[float] = [0.0,1.0/24.0,1.0,10.0,15.0,30.0,100.0]
const Satellites = preload("res://scripts/core/natural_satellites.gd")
const SKY_RATES: Array[float] = [0.0,1.0/1440.0,1.0/240.0,1.0/24.0,.25,1.0]
const NAMES: Dictionary = {"reef":"海洋","woodland":"林地与河岸","desert":"索诺兰荒漠","city":"城市与人类","polar":"南极海岸","arctic":"北极海冰与夜空","night_sky":"阿塔卡马观星台"}
const TAGS: Dictionary = {
	"night_sky":"星表与日期方向 · 曝光增强",
	"universe":"宇宙结构与膨胀示意",
	"galaxy":"科学示意", "solar_system":"日期星历 · 显示放大", "earth":"地球影像 · 非实时天气",
	"atmosphere":"大气显示模型", "earth_moon":"天文参考模型", "jupiter_moons":"冻结星历 · 显示放大",
	"city":"合成教学街区", "woodland":"合成参考生境", "desert":"合成参考生境", "polar":"合成参考生境", "arctic":"海冰参考 · 极光演示",
	"pacific":"海洋教学场景", "reef":"参考生境 · 教学布局", "school":"行为参考模型", "fish":"形态参考 · 教学个体",
	"heart":"科学示意", "cardiomyocyte":"参考模型", "mitochondrion":"参考模型", "molecule":"科学示意", "atom":"科学示意"}
const SUBHEADS: Dictionary = {"universe":"大尺度宇宙 / 星系之间","galaxy":"宇宙 / 恒星家园","solar_system":"宇宙 / 行星世界","earth":"我们的星球","atmosphere":"地球 / 大气","pacific":"地球 / 珊瑚海","reef":"海洋 / 蜥蜴岛区域","school":"珊瑚礁 / 海葵与鱼","fish":"海洋生命 / 海葵双锯鱼","woodland":"地球 / 林地生态","city":"地球 / 人类与环境","desert":"地球 / 荒漠生命","polar":"地球 / 南极生命","arctic":"地球 / 北极海冰","heart":"生命 / 结构与循环","cardiomyocyte":"生命 / 细胞","mitochondrion":"生命 / 能量","molecule":"微观世界 / 分子","atom":"微观世界 / 原子","earth_moon":"地球 / 月球","jupiter_moons":"太阳系 / 木星","mars_moons":"太阳系 / 火星","saturn_moons":"太阳系 / 土星","uranus_moons":"太阳系 / 天王星","neptune_moons":"太阳系 / 海王星"}
const TITLES: Dictionary = {"pacific":"珊瑚海","fish":"海葵双锯鱼","school":"海葵与鱼","woodland":"林地与河岸","desert":"索诺兰荒漠","polar":"南极海岸","arctic":"北极海冰与夜空","earth_moon":"地球与月球","jupiter_moons":"木星与卫星","mars_moons":"火星与卫星","saturn_moons":"土星与卫星","uranus_moons":"天王星与卫星","neptune_moons":"海王星与卫星"}
var _astronomy_menu: bool = false
var _ground_menu: bool = false
var sky_credit: Label
var search_button: Button
var knowledge_button: Button
var host: Node
var header: PanelContainer
var header_row: HBoxContainer
var title_box: VBoxContainer
var gesture: Label
var source_button: Button
var transport: PanelContainer
var transport_space: Control
var rate_button: MenuButton
var menu_button: MenuButton
var context_panel: PanelContainer
var context_title: Label
var context_note: Label
var context_path: Label
var details_button: Button
var toast_age: float = 0.0
var last_message: String = ""
var context: Dictionary = {}
var top_gradient: TextureRect
var bottom_gradient: TextureRect

func configure(experience: Node) -> void:
	host = experience
	name = "ImmersiveInterface"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_gradient = _shade(false)
	bottom_gradient = _shade(true)
	header = PanelContainer.new()
	add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 0; header.offset_right = 0; header.offset_top = 0; header.offset_bottom = UI.HEADER_HEIGHT
	var top_style: StyleBoxFlat = UI.surface(Color(.035,.043,.056,.62),20,0)
	top_style.set_border_width_all(0); top_style.border_width_bottom = 1; top_style.shadow_size = 0
	top_style.content_margin_top = 10; top_style.content_margin_bottom = 10
	header.add_theme_stylebox_override("panel",top_style)
	header_row = HBoxContainer.new(); header_row.add_theme_constant_override("separation",10); header.add_child(header_row)
	var brand: Label = host._label("孪生宇宙",20)
	brand.custom_minimum_size.x = 114; header_row.add_child(brand)
	host.previous_button = UI.icon("back","返回上一级 · Backspace",host._navigate_relative.bind(-1))
	UI.flat_button(host.previous_button); header_row.add_child(host.previous_button)
	# NavigationBar is mounted here by host, before the tools.
	title_box = VBoxContainer.new(); add_child(title_box)
	title_box.add_theme_constant_override("separation",5)
	host.subtitle_label = host._scene_caption("",11,UI.MUTED); title_box.add_child(host.subtitle_label)
	host.title_label = host._scene_caption("",34); title_box.add_child(host.title_label)
	var editorial: SystemFont = SystemFont.new(); editorial.font_names = PackedStringArray(["Songti SC","PingFang SC"]); host.title_label.add_theme_font_override("font",editorial)
	gesture = host._scene_caption("",12,Color(.72,.76,.80)); title_box.add_child(gesture)
	source_button = host._button("",host._toggle_info)
	source_button.add_theme_font_size_override("font_size",16)
	UI.flat_button(source_button); title_box.add_child(source_button)
	source_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	host.message_label = host._scene_caption("",13)
	host.message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.message_label.clip_text = true
	add_child(host.message_label)
	context_panel = PanelContainer.new(); add_child(context_panel)
	var context_style: StyleBoxFlat = UI.surface(Color(.055,.075,.10,.94),18,12)
	context_panel.add_theme_stylebox_override("panel",context_style)
	var context_row: HBoxContainer = HBoxContainer.new(); context_row.add_theme_constant_override("separation",16); context_panel.add_child(context_row)
	var accent: ColorRect = ColorRect.new(); accent.color = UI.ACCENT; accent.custom_minimum_size = Vector2(2,58); context_row.add_child(accent)
	var column: VBoxContainer = VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation",5); context_row.add_child(column)
	context_title = host._label("",22); context_title.clip_text = true; context_title.add_theme_font_override("font",editorial); column.add_child(context_title)
	context_note = host._label("",12,Color(.73,.78,.82)); context_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(context_note)
	context_path = host._label("",11,UI.MUTED); context_path.clip_text = true; column.add_child(context_path)
	details_button = UI.icon("book","查看所选对象的知识",_show_details); context_row.add_child(details_button)
	transport_space = Control.new(); transport_space.custom_minimum_size.x = 208; context_row.add_child(transport_space)
	context_panel.hide()
	transport = PanelContainer.new(); add_child(transport)
	transport.add_theme_stylebox_override("panel",UI.surface(Color(.04,.055,.075,.9),4,22))
	var time_row: HBoxContainer = HBoxContainer.new(); time_row.add_theme_constant_override("separation",4); transport.add_child(time_row)
	host.pause_button = UI.icon("pause","暂停或继续世界时间 · Space",host._toggle_pause); UI.flat_button(host.pause_button); time_row.add_child(host.pause_button)
	rate_button = MenuButton.new(); rate_button.text = "1×"; rate_button.custom_minimum_size = Vector2(96,44); rate_button.tooltip_text = "世界时间倍率"; UI.flat_button(rate_button); time_row.add_child(rate_button)
	for value: float in RATES: rate_button.get_popup().add_radio_check_item(str(value)+"×")
	rate_button.get_popup().id_pressed.connect(_set_rate)
	host.time_label = host._label("",11,UI.MUTED); host.time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; host.time_label.custom_minimum_size.x = 118; time_row.add_child(host.time_label)
	# The resolved PingFang face does not expose tabular numerals on this Mac.
	# Use the system's actual monospace face and retain the UI Chinese fallback.
	var date_font: SystemFont=SystemFont.new()
	date_font.font_names=PackedStringArray(["Menlo","Monaco","monospace"])
	date_font.oversampling=host.ui_scale
	date_font.fallbacks=[host.hud.theme.default_font]
	host.time_label.add_theme_font_override("font",date_font)
	host.time_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	host.time_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	# Existing keyboard and state callers retain handles without redundant UI.
	for pair: Array in [["next_button","继续深入",host._advance_or_city_view],["save_button","保存世界",host.save_world.bind(true)],["quality_button","画质：流畅",host._toggle_render_quality]]:
		var handle: Button = host._button(pair[1],pair[2]); add_child(handle); handle.hide(); host.set(pair[0],handle)
	host.recovery_actions = HBoxContainer.new(); add_child(host.recovery_actions)
	host.retry_button = host._button("重试",host._retry_transition); host.recovery_actions.add_child(host.retry_button)
	host.recovery_actions.add_child(host._button("取消重试",host._dismiss_recovery)); host.recovery_actions.hide()
	host.context_label = host._label("",12); add_child(host.context_label); host.context_label.hide()
	sky_credit=host._scene_caption("ESA/Gaia/DPAC · A. Moitinho · CC BY-SA 3.0 IGO",9,UI.MUTED)
	sky_credit.theme=host.hud.theme
	sky_credit.mouse_filter=Control.MOUSE_FILTER_IGNORE; sky_credit.z_index=5; sky_credit.scale=Vector2.ONE*host.ui_scale
	host.hud.get_parent().add_child(sky_credit); sky_credit.hide()
	fit_window(host.ui_view_size())

func add_tools() -> void:
	search_button = UI.icon("search","搜索世界与观察主题",host._open_guide); UI.flat_button(search_button); header_row.add_child(search_button)
	knowledge_button = UI.icon("book","所选对象与观察主题",host._toggle_explorer); UI.flat_button(knowledge_button); header_row.add_child(knowledge_button)
	menu_button = MenuButton.new(); menu_button.text = "···"; menu_button.custom_minimum_size = Vector2(44,44); menu_button.tooltip_text = "观察工具与设置"; UI.flat_button(menu_button); header_row.add_child(menu_button)
	var popup: PopupMenu = menu_button.get_popup()
	for item: Array in [["科学说明与来源",0],["影响链与观察记录",1],["声音",2],["保存当前世界  ⌘S",3],["重置观察视角  R",4],["返回原观察位置",5],["回到地球",6],["回到银河系",7]]: popup.add_item(item[0],item[1])
	popup.add_separator()
	popup.add_radio_check_item("画质 · 清晰",8)
	popup.add_radio_check_item("画质 · 流畅（默认）",12)
	popup.add_radio_check_item("画质 · 节能",13)
	popup.add_separator()
	popup.add_check_item("减少运动",9); popup.add_check_item("纯净观察  F9",10)
	popup.add_separator(); popup.add_item("重播宇宙膨胀演示",11)
	popup.id_pressed.connect(_menu_action)
	popup.about_to_popup.connect(_refresh_menu)

func _shade(bottom: bool) -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(.01,.02,.035,.72),Color(.01,.02,.035,0)])
	var texture: GradientTexture2D = GradientTexture2D.new(); texture.gradient = gradient; texture.width = 8; texture.height = 128
	texture.fill_from = Vector2(0,1 if bottom else 0); texture.fill_to = Vector2(0,0 if bottom else 1)
	var rect: TextureRect = TextureRect.new(); rect.texture = texture; rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(rect); return rect

func fit_window(view_size: Vector2i) -> void:
	var date_font: SystemFont=host.time_label.get_theme_font("font") as SystemFont
	if date_font: date_font.oversampling=host.ui_scale
	var editorial: SystemFont=host.title_label.get_theme_font("font") as SystemFont
	if editorial: editorial.oversampling=host.ui_scale
	top_gradient.position = Vector2.ZERO; top_gradient.size = Vector2(view_size.x,150)
	bottom_gradient.position = Vector2(0,view_size.y-240); bottom_gradient.size = Vector2(view_size.x,240)
	title_box.position = Vector2(28,view_size.y-230); title_box.size = Vector2(maxf(160,minf(640,view_size.x-56)),190)
	context_panel.size = Vector2(view_size.x-48,128)
	context_panel.position = Vector2(24,view_size.y-156 if view_size.x>=1000 else view_size.y-214)
	host.message_label.position = Vector2(28,view_size.y-266); host.message_label.size = Vector2(view_size.x-56,26)
	host.recovery_actions.position = Vector2(28,view_size.y-318)
	# This credit remains outside the hideable HUD, including pure observation.
	sky_credit.scale=Vector2.ONE*host.ui_scale
	sky_credit.position=Vector2(24,view_size.y-28)*host.ui_scale; sky_credit.size=Vector2(view_size.x-48,26)
	if is_instance_valid(search_button):
		for pair: Array in [[search_button,"导览"],[knowledge_button,"知识"]]:
			pair[0].set("caption",pair[1] if view_size.x>=850 else "")
			pair[0].custom_minimum_size.x=90 if view_size.x>=850 else 44
			pair[0].queue_redraw()
	_layout_transport(view_size)

func _layout_transport(view_size: Vector2i) -> void:
	# Reserve a full timestamp, independent of ticking proportional characters.
	# Tabular digits keep every numerical column stationary within that slot.
	var text_width: float = ceilf(host.time_label.get_theme_font("font").get_string_size("2000-00-00 00:00 TDB",HORIZONTAL_ALIGNMENT_LEFT,-1,host.time_label.get_theme_font_size("font_size")).x)
	host.time_label.custom_minimum_size.x=text_width
	var rate_width: float = rate_button.get_combined_minimum_size().x
	var width: float = maxf(254,44+rate_width+text_width+32)
	transport_space.visible = view_size.x>=1000
	transport_space.custom_minimum_size.x = width+8
	transport.size = Vector2(width,52)
	transport.position = Vector2(view_size.x-width-42,view_size.y-116) if context_panel.visible and view_size.x>=1000 else Vector2((view_size.x-width)*.5,view_size.y-80)

func _set_rate(index: int) -> void:
	if index==100 and host.world.current_scale_id=="solar_system":
		host.set_solar_observation_auto(host.solar_manual_setting)
		return
	if host.world.current_scale_id=="night_sky":
		if index>=0 and index<SKY_RATES.size(): host.set_solar_rate(SKY_RATES[index])
		return
	if host.world.current_scale_id in ["solar_system","earth_moon"] or Satellites.is_system(host.world.current_scale_id):
		if index>=0 and index<ASTRONOMY_RATES.size(): host.set_solar_rate(ASTRONOMY_RATES[index])
		return
	var values: Array[float] = RATES
	if index < 0 or index >= values.size(): return
	host.world.set_time_scale(values[index]); host.world.record_observation("speed")

func _refresh_menu() -> void:
	var popup: PopupMenu = menu_button.get_popup()
	popup.set_item_disabled(popup.get_item_index(11),host.world.current_scale_id!="universe" or host.coordinator.is_busy())
	popup.set_item_disabled(popup.get_item_index(3),host.is_trial() or not host._persistence_enabled or (host._store!=null and host._store.protected))
	popup.set_item_disabled(popup.get_item_index(5),host.navigation_bar.origin.is_empty() or host.coordinator.is_busy())
	for pair: Array in [[8,host._render_ratio==1.0],[12,host._render_ratio==0.75],[13,host._render_ratio==0.5],[9,host._reduced_motion],[10,host.clean_observation.active]]: popup.set_item_checked(popup.get_item_index(pair[0]),pair[1])

func _menu_action(id: int) -> void:
	match id:
		11:
			if host.world.current_scale_id=="universe" and not host.coordinator.is_busy(): host.coordinator.active_scene.get_meta("cosmic_panorama").epoch = host.world.simulation_time_s
		0: host._toggle_info()
		1: host._toggle_observation()
		2: host.sound_panel.visible = not host.sound_panel.visible
		3: host.save_world(true)
		4: host._reset_observation_view()
		5: host.navigation_bar.return_to_origin()
		6: host.navigation_bar.jump("earth")
		7: host.navigation_bar.jump("galaxy")
		8: host._set_render_quality(1.0)
		12: host._set_render_quality(0.75)
		13: host._set_render_quality(0.5)
		9: host._toggle_reduced_motion()
		10: host.clean_observation.toggle()

func _context_data() -> Dictionary:
	var id: String = host.world.current_scale_id
	if id=="earth":
		var region: String = host.earth_entry_panel.selected
		if region.is_empty(): return {}
		return {"title":NAMES[region],"note":"Paranal参考方向 · 合成山地平台" if region=="night_sky" else "蜥蜴岛区域 · 礁区布局为教学设定" if region=="reef" else "合成教学场景 · 光照参考区域，非实地地址","path":"地球  ›  大气  ›  海面  ›  珊瑚礁" if region=="reef" else "地球  ›  "+NAMES[region]+"  ·  再点区域或双指靠近","region":region}
	var framing_stage: Node=host.coordinator.active_scene
	if host.SatelliteFraming.is_pair(framing_stage):
		var framing: Dictionary=host.SatelliteFraming.state(framing_stage)
		var pair: Dictionary=host.SatelliteFraming.subjects(framing_stage,int(framing.owner),str(framing.key))
		if not pair.is_empty(): return {"title":host.Ephemeris.NAMES[int(framing.owner)]+" · "+str(pair.label),"note":"透视同框 · 随行镜头 · 距离与半径同比","path":"拖动转入主体环绕 · 指向星体放大 · 拉远看轨道全景"}
	var choice: Dictionary = host.selected_spatial_choice()
	var topic: String = host.learning_overlay.topic
	if choice.is_empty() and topic.is_empty(): return {}
	var title: String = str(choice.get("label",""))
	var note: String = ""
	if id=="night_sky" and not choice.is_empty():
		var direction: Vector3=(choice.node.global_position-host.GroundSky.EYE).normalized()
		note="高度 %.1f° · 方位 %.1f°" % [rad_to_deg(asin(clampf(direction.y,-1,1))),fposmod(rad_to_deg(atan2(direction.x,-direction.z)),360.0)]
		if choice.has("vmag"): note+=" · 星等 %.2f" % float(choice.vmag)
		elif int(choice.get("body",-1))==8: note+=" · 受光 %.0f%%" % (host.Orientation.illumination(host.solar_jd)*100.0)
	elif id=="solar_system" and choice.has("planet"):
		var planet: int = int(choice.planet)
		note = host.Orientation.rotation_label(planet)+" · 公转 %.2f 年" % host.Ephemeris.PERIOD_YEARS[planet]
	elif id=="solar_system" and bool(choice.get("moon",false)):
		note = "公转 / 自转约27.3天 · 近景距离与半径同比"
	elif id=="solar_system" and bool(choice.get("sun",false)):
		note = "IAU参考自转约25.38天 · 非各纬度云气转速"
	elif Satellites.is_system(id) and not choice.is_empty():
		note = str(choice.node.get_meta("activity","同日期几何星历 · 距离与半径同比")).split("\n")[0]
	for item: Dictionary in Topics.for_scale(id):
		if str(item.id)==topic:
			if title.is_empty(): title = str(item.title)
			note = str(item.get("observe",item.get("description",""))).split("\n")[0]
			break
	if title.is_empty(): return {}
	var path: String = host.spatial_hint(choice) if not choice.is_empty() else "拖动环绕 · 双指靠近 · 查看知识"
	if id=="solar_system" and int(host.coordinator.active_scene.get_meta("solar_physical",{}).get("owner",-1))==2:
		path="左拖环绕 · 右拖环顾 · ☀ / ☾ 定位 · ⊕ 回地球"
		if bool(host.coordinator.active_scene.get_meta("solar_lookaround",false)): path="右拖环顾 · 双指光学缩放 · ⊕ 回地球近景"
	if is_instance_valid(host.SolarCloseup.subject(host)): path="拖动环绕 · 指向方位标记放大，点击飞近 · 拉远同框"
	if note.is_empty(): note = str(TAGS.get(id,"参考模型"))+" · "+str(host.Catalog.describe(id).label)
	return {"title":title,"note":note,"path":path,"topic":topic}

func _show_details() -> void:
	if context.has("region"):
		host._toggle_info()
		if host.info_panel.visible:
			var site: Dictionary = host.Sites.for_scale(str(context.region))
			host.info_label.text = "[b]"+context.title+"[/b]\n\n"+str(site.description)+"\n\n"+host.ScienceReference.text_for("earth")
	elif not str(context.get("topic","")).is_empty(): host.explorer_panel.open_topic(str(context.topic))
	else: host._toggle_explorer()

func refresh() -> void:
	if not is_instance_valid(host.coordinator.active_scene): return
	var id: String = host.world.current_scale_id
	host.subtitle_label.text = str(SUBHEADS.get(id,"孪生宇宙"))
	host.title_label.text = str(TITLES.get(id,host.Catalog.describe(id).label))
	context = _context_data()
	var unobstructed: bool = not host.coordinator.is_busy() and not host.explorer_panel.visible and not host.observation_panel.visible and not host.info_panel.visible and not host.guided_journey.visible and not host.world_guide.visible and not host.size_comparison.visible
	context_panel.visible = unobstructed and not context.is_empty()
	title_box.visible = unobstructed and context.is_empty()
	if context_panel.visible:
		context_title.text = context.title; context_note.text = context.note; context_path.text = context.path
		if id=="solar_system" and not host.SatelliteFraming.is_pair(host.coordinator.active_scene):
			context_note.text+="\n距离与半径同比 · 远距识别点非大小" if bool(host.coordinator.active_scene.get_meta("solar_physical_active",false)) else "\n全景示意 · 距离压缩、大小放大"
	gesture.text = "旋转地球 · 选择区域 · 双指靠近" if id=="earth" else "拖动环绕 · 点击对象 · 双指靠近"
	if id=="atmosphere": gesture.text = "观察大气弧面与云层 · 继续靠近海面"
	if id=="pacific": gesture.text = "观察海面与地平线 · 双指靠近珊瑚礁"
	if id=="night_sky":
		host.subtitle_label.text="地球 / 阿塔卡马高原 · 24.6°S"
		host.title_label.text="仰望星河"
		gesture.text="拖动环顾 · 点击亮星或月球 · 双指缩放视野"
	source_button.text = str(TAGS.get(id,"参考模型"))+"  ·  依据与边界"
	source_button.visible=id!="night_sky" or host.ui_view_size().x>=900
	if id=="night_sky" and not source_button.visible: host.subtitle_label.text+=" · 曝光增强"
	if id=="solar_system":
		source_button.text = "日期保持 · 位置星历 · 全景示意" if host.solar_rate==0 else "1小时 / 世界秒 · 全系统同倍率 · 全景示意" if host.solar_rate<1 else "%.0f天 / 世界秒 · 全系统同倍率 · 全景示意" % host.solar_rate
	elif id=="galaxy": source_button.text = "时间压缩 · 理想化转动示意 · 依据与边界"
	elif id=="night_sky": source_button.text="太阳高度 %.1f° · 星表方向 · 曝光增强" % float(host.coordinator.active_scene.get_meta("sun_elevation",0.0))
	sky_credit.visible=id=="night_sky" and host.coordinator.active_scene.get_meta("ground_sky",{}).get("credit",false)
	if id=="universe": gesture.text = "拖动环顾星系网络 · 点击中央银河 · 双指靠近"
	host.pause_button.set("symbol","play" if host.world.paused else "pause"); host.pause_button.queue_redraw()
	host.pause_button.tooltip_text = "继续世界时间 · Space" if host.world.paused else "暂停世界时间 · Space"
	var astronomy: bool = id in ["solar_system","earth_moon","night_sky"] or Satellites.is_system(id)
	var ground: bool=id=="night_sky"
	if astronomy!=_astronomy_menu or ground!=_ground_menu:
		_astronomy_menu = astronomy
		_ground_menu=ground
		rate_button.get_popup().clear()
		for label: String in (["日期保持","1分钟 / 世界秒","6分钟 / 世界秒","1小时 / 世界秒","6小时 / 世界秒","1天 / 世界秒"] if ground else ["日期保持","自转观察 · 1小时/秒","缓慢自转 · 1天/秒","公转全景 · 10天/秒","较快公转 · 15天/秒","快速公转 · 30天/秒","外行星 · 100天/秒"] if astronomy else ["0.25×","0.5×","1×","2×","4×"]): rate_button.get_popup().add_radio_check_item(label)
	var auto_item: int=rate_button.get_popup().get_item_index(100)
	if id=="solar_system" and auto_item<0:
		rate_button.get_popup().add_separator()
		rate_button.get_popup().add_check_item("近景自动慢放",100)
	elif id!="solar_system" and auto_item>=0:
		rate_button.get_popup().remove_item(auto_item)
		rate_button.get_popup().remove_item(auto_item-1)
	rate_button.text = ("日期保持" if host.solar_rate==0 else "1小时/秒" if host.solar_rate<1 else "%.0f天/秒" % host.solar_rate) if astronomy else str(host.world.time_scale)+"×"
	if ground: rate_button.text="日期保持" if host.solar_rate==0 else "%.0f分/秒" % (host.solar_rate*1440.0) if host.solar_rate<1.0/24.0 else "%.0f时/秒" % (host.solar_rate*24.0) if host.solar_rate<1.0 else "1天/秒"
	rate_button.tooltip_text = "太阳、八行星、月球的自转与公转共用此倍率。30天/秒下木星约72转/秒，画面会滤除无法分辨的自转细节；切到1小时/秒观察真实速度关系。天文推演不让生命跨年。" if astronomy else "世界时间倍率"
	if id=="solar_system":
		rate_button.tooltip_text="全系统共用此倍率。近景自动切至1小时/秒，返回全景恢复原倍率；手动调速或选择日期后保留选择，可在菜单重新开启近景自动慢放。太阳/水星等可选全局1天/秒观察。"
		rate_button.get_popup().set_item_checked(rate_button.get_popup().get_item_index(100),not host.solar_manual_setting)
	if ground: rate_button.tooltip_text="地球自转、星空、月球与行星沿用同一天文日期；1分钟/世界秒看缓慢升落，1小时/世界秒比较昼夜。"
	var values: Array[float] = SKY_RATES if ground else ASTRONOMY_RATES if astronomy else RATES
	for i: int in range(values.size()): rate_button.get_popup().set_item_checked(i,is_equal_approx(host.solar_rate if astronomy else host.world.time_scale,values[i]))
	host.time_label.text = host.Ephemeris.date_label(host.solar_jd) if astronomy else host.Ephemeris.date_label(host.solar_jd).split(" ")[0] if id in ["earth","earth_moon","jupiter_moons"] else "转动示意" if id=="galaxy" else "膨胀示意" if id=="universe" else "%.1f 秒" % host.world.simulation_time_s
	if astronomy and host.solar_rate<1.0:
		host.time_label.text=host.Orientation.timestamp(host.solar_jd).left(16)+" TDB"
	host.time_label.tooltip_text=host.Orientation.timestamp(host.solar_jd) if astronomy else ""
	_layout_transport(host.ui_view_size())

func blocks(point: Vector2) -> bool:
	for control: Control in [header,transport,context_panel]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return false

func _process(delta: float) -> void:
	if host==null: return
	refresh()
	if host.message_label.text!=last_message: last_message = host.message_label.text; toast_age = 0.0
	toast_age += delta
	var repeated_selection: bool=context_panel.visible and last_message.begins_with("正在观察 · ")
	host.message_label.visible = not repeated_selection and not last_message.is_empty() and (toast_age<5.0 or host.recovery_actions.visible)
