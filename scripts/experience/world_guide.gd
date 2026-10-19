extends Control
const I18n = preload("res://scripts/core/app_text.gd")
## A view onto the existing navigation and lesson actions; owns no world state.
const Catalog = preload("res://scripts/core/scale_catalog.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")
const EcologyMap = preload("res://scripts/experience/ecology_map.gd")
const SpeciesAtlas = preload("res://scripts/experience/species_atlas.gd")
const ROUTES: Array[Dictionary] = [
	{"label":"01  /  太阳系", "question":"行星怎样绕太阳运行？", "detail":"选择行星，改变日期，对照轨道与距离。", "actions":[["宇宙结构全景","universe",""],["火星与两颗卫星","mars_moons",""],["木星完整卫星系统","jupiter_moons",""],["四大卫星的周期对照","jupiter_moons","jovian_periods"],["土星完整卫星系统","saturn_moons",""],["天王星卫星系统","uranus_moons",""],["海王星卫星系统","neptune_moons",""],["水星的快与慢","solar_system","mercury_orbit"],["观察轨道","solar_system",""],["太阳在银河哪里","galaxy","galactic_structure"]]},
	{"label":"02  /  地球与月球", "question":"昼夜、季节和月相怎样变化？", "detail":"比较两半球与不同纬度的昼长，以及受光面与地月位置。", "actions":[["地面仰望星河","night_sky",""],["地球两半球与纬度昼长","earth","earth_daylight"],["月相与同步旋转","earth_moon","lunar_phases"],["地月观察台","earth_moon",""],["地球全景","earth",""]]},
	{"label":"03  /  海洋生命", "question":"不同身体怎样适应海洋？", "detail":"从水层鱼群的浮游食物到砂底沉积物摄食，比较形态、活动与资源。", "actions":[["龟类四肢对照：海洋鳍状肢","reef","turtle_compare_sea"],["礁底日间章鱼的八腕","reef","day_octopus"],["章鱼同腕的双列吸盘","reef","day_octopus_suckers"],["黑海参：砂覆与露肤","reef","black_sea_cucumber"],["黑海参摄食端近看","reef","black_sea_cucumber_feeding"],["砗磲：壳与外套膜","reef","giant_clam"],["砗磲外套膜近看","reef","giant_clam_mantle"],["海洋开花植物","reef","seagrass"],["海草叶片近看","reef","seagrass_leaf"],["水层鱼群","reef","school"],["海龟与滑行","reef","turtle"],["海龟为何上浮","reef","turtle_surface"],["贴底的魟","reef","ray"],["食藻鱼","reef","algae"],["捕食性礁鱼","reef","snapper"],["长刺海胆","reef","urchin"],["珊瑚共生与热压力","reef","coral_symbiosis"],["珊瑚群体","reef","coral_colony"],["珊瑚虫近看","reef","coral_polyp"]]},
	{"label":"04  /  陆地生态", "question":"阳光与动物怎样塑造林地生活？", "detail":"比较林地、河岸的水上与水下生物，观察鹿、赤狐、箱龟、鸟、蝴蝶、牛蛙、两种淡水鱼、沉水植物和分解者。", "actions":[["龟类四肢对照：林地有趾足","woodland","turtle_compare_land"],["林地箱龟的背甲与有趾足","woodland","box_turtle"],["箱龟同一只的头部","woodland","box_turtle_head"],["林缘赤狐的身体与角色","woodland","red_fox"],["赤狐同一只的尖吻与尖耳","woodland","red_fox_head"],["枯木分解与水分","woodland","deadwood"],["枯木与云芝","woodland","fungus"],["河岸牛蛙","woodland","bullfrog"],["河岸香蒲与蜻蜓","woodland","river_wetland"],["宽叶香蒲的叶与花穗","woodland","cattail"],["绿纹蜻蜓的四翅","woodland","green_darner"],["两种淡水鱼与苦草同框","woodland","freshwater_habitats"],["水面之下的淡水鱼小群","woodland","freshwater_school"],["金色鲦的身体","woodland","golden_shiner"],["斑纹鳉的体侧横纹","woodland","banded_killifish"],["河床上的美洲苦草","woodland","wild_celery"],["美洲苦草的叶与走茎","woodland","wild_celery_leaf"],["取食与恢复","woodland","browse"],["植物与鹿","woodland","graze"],["鸟与飞行","woodland","bird"],["蝴蝶与花","woodland","monarch"],["帝王蝶的四个生命阶段：叶背卵","woodland","monarch_egg"],["帝王蝶悬挂的蛹","woodland","monarch_pupa"],["幼虫与乳草叶","woodland","monarch_larva"],["季节与日照","woodland","season_light"],["北美白橡的叶片","woodland","oak_leaf"],["白松的针叶","woodland","pine_needles"]]},
	{"label":"05  /  城市与人类", "question":"人类活动怎样联系阳光、雨水与公园生物？", "detail":"走近街区、屋顶、公园与池塘，比较硬地和绿地的雨水去向，以及树麻雀、帝王蝶与绿头鸭的不同生态角色。", "actions":[["街道人行道行人近看","city","street_walkers"],["城市池塘的雌雄绿头鸭","city","city_pond"],["绿头鸭雄鸟近看","city","city_mallard_drake"],["绿头鸭雌鸟近看","city","city_mallard_hen"],["城市种植片区的帝王蝶","city","city_monarch"],["城市种植片区的普通乳草","city","city_milkweed"],["城市公园的欧亚树麻雀","city","city_sparrow"],["城市公园的银杏扇叶","city","city_ginkgo_leaf"],["银杏的季节外观","city","city_ginkgo_season"],["公园树种：春花与秋色","city","city_park_trees"],["红枫的掌状裂叶","city","city_maple_leaf"],["东部紫荆的花","city","city_redbud_bloom"],["东部紫荆的心形叶","city","city_redbud_leaf"],["雨水与地表","city","runoff"],["行人过街","city","crossing"],["道路通行","city","traffic"],["屋顶受光","city","solar_roof"],["步行空间","city","street"]]},
	{"label":"06  /  极地海岸", "question":"南极海岸的冰、水与生物怎样相邻？", "detail":"从海岸走近企鹅，再进入近岸水下看3厘米冰磷虾及其食物联系，比较南北半球日照。", "actions":[["海冰旁的冰磷虾小群","polar","ice_krill_habitat"],["冰磷虾成体近看","polar","ice_krill"],["冰磷虾大眼与额剑","polar","ice_krill_head"],["南极海岸的冰缘与裸岩","polar","polar_coast"],["阿德利企鹅近看","polar","adelie_penguin"],["南极海岸的季节日照","polar","season_light"]]},
	{"label":"07  /  索诺兰荒漠", "question":"动植物怎样生活在荒漠灌丛？", "detail":"比较仙人掌、三齿拉瑞阿、牧豆树、Ocotillo与Brittlebush的株形，观察鬣蜥和袋鼠鼠；夜间可追踪有限教学种子。", "actions":[["沙漠鬣蜥与灌丛","desert","desert_iguana"],["仙人掌与刺座","desert","desert_cactus"],["灌木成对小叶","desert","desert_leaf"],["牧豆树与荚果","desert","desert_mesquite"],["Ocotillo多茎与花序","desert","desert_ocotillo"],["Ocotillo茎刺近看","desert","desert_ocotillo_spine"],["Ocotillo梢端红花","desert","desert_ocotillo_flower"],["Brittlebush灰白叶冠与黄花","desert","desert_brittlebush"],["Brittlebush灰白叶片","desert","desert_brittlebush_leaf"],["Brittlebush黄色花头","desert","desert_brittlebush_flower"],["袋鼠鼠夜间采种","desert","desert_rat"],["夏冬日照","desert","season_light"]]},
	{"label":"08  /  深入生命", "question":"一条鱼怎样把氧送到细胞？", "detail":"从目标鱼深入心脏、心肌与线粒体。", "actions":[["氧原子与轨道","atom","oxygen_atom"],["从目标鱼开始","fish",""],["心脏结构","heart",""]]}
]
var first_visit_view: bool = false
var host: Node
var panel: PanelContainer
var grid: GridContainer
var scroll: ScrollContainer
var context: Label
var search: LineEdit
var result_count: Label
var empty_results: Label
var cards: Array[Dictionary] = []
var journey_button: Button
var world_tour_button: Button
var resume_button: Button
var route_buttons: Array[Button] = []
var ecology_map: VBoxContainer
var ecology_button: Button
var species_atlas: VBoxContainer
var species_button: Button
var title: Label

func configure(experience: Node, style: StyleBoxFlat) -> void:
	host = experience
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(.025,.032,.045,.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	add_child(panel)
	var frame: StyleBoxFlat = style.duplicate()
	frame.bg_color = host.InterfaceTheme.INK
	panel.add_theme_stylebox_override("panel",frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	var page_scroll: ScrollContainer=ScrollContainer.new()
	page_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(page_scroll)
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.size_flags_vertical=Control.SIZE_EXPAND_FILL
	page_scroll.add_child(column)
	var heading: HBoxContainer = HBoxContainer.new()
	column.add_child(heading)
	title = host._label(I18n.text("探索世界"),28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	resume_button = host.InterfaceTheme.icon("close",I18n.text("返回观察 · Esc"),return_to_observation)
	heading.add_child(resume_button)
	context = host._label("",14,Color(.68,.84,.89))
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(context)
	var modes: HFlowContainer = HFlowContainer.new(); modes.add_theme_constant_override("h_separation",8); column.add_child(modes)
	world_tour_button=host._button(I18n.text("世界漫游"),func() -> void: host.guided_journey.open("world"))
	modes.add_child(world_tour_button)
	journey_button=host._button(I18n.text("跨尺度之旅"),func() -> void: host.guided_journey.open())
	modes.add_child(journey_button)
	ecology_button=host._button(I18n.text("生态关系"),func() -> void: show_ecology(not ecology_map.visible))
	modes.add_child(ecology_button)
	species_button=host._button(I18n.text("生命图鉴"),func() -> void: show_species(not species_atlas.visible))
	modes.add_child(species_button)
	search = LineEdit.new()
	search.placeholder_text = I18n.text("搜索主题：海龟、月相、城市……")
	search.clear_button_enabled = true
	search.custom_minimum_size.y = 44
	search.add_theme_font_size_override("font_size",18)
	search.text_changed.connect(_filter_routes)
	column.add_child(search)
	result_count = host._label("",13,Color(.68,.84,.89))
	column.add_child(result_count)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y=240
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	var pages: VBoxContainer=VBoxContainer.new()
	pages.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	pages.add_child(grid)
	ecology_map=EcologyMap.new()
	pages.add_child(ecology_map)
	ecology_map.configure(host)
	ecology_map.visit_requested.connect(host.start_guide_visit)
	ecology_map.hide()
	species_atlas = SpeciesAtlas.new()
	pages.add_child(species_atlas)
	species_atlas.configure(host, frame, scroll)
	species_atlas.visit_requested.connect(host.start_guide_visit)
	species_atlas.hide()
	for entry: Dictionary in I18n.dictionaries(ROUTES):
		var card: PanelContainer = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style: StyleBoxFlat = frame.duplicate()
		card_style.bg_color = Color(.09,.11,.145,1)
		card_style.content_margin_top = 12
		card_style.content_margin_bottom = 12
		card_style.content_margin_left = 16
		card_style.content_margin_right = 16
		card.add_theme_stylebox_override("panel",card_style)
		grid.add_child(card)
		var card_buttons: Array[Button] = []
		var content: VBoxContainer = VBoxContainer.new()
		content.add_theme_constant_override("separation",6)
		card.add_child(content)
		content.add_child(host._label(entry.label,12,Color(.48,.83,.81)))
		for item: Array in [[entry.question,18],[entry.detail,13]]:
			var text: Label = host._label(str(item[0]),int(item[1]))
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(text)
		var actions: HFlowContainer = HFlowContainer.new()
		var expand: Button = host._button(I18n.text("查看观察主题  ›"),func() -> void: actions.visible=not actions.visible)
		expand.add_theme_font_size_override("font_size",18); host.InterfaceTheme.flat_button(expand)
		expand.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		content.add_child(expand)
		content.add_child(actions); actions.hide()
		for action: Array in entry.actions:
			var button: Button = host._button(str(action[0]),host.start_guide_visit.bind(str(action[1]),str(action[2])))
			button.add_theme_font_size_override("font_size",18)
			button.set_meta("guide_scale",action[1])
			button.set_meta("guide_topic",action[2])
			actions.add_child(button)
			route_buttons.append(button)
			card_buttons.append(button)
			var lesson_title: String = ""
			for topic: Dictionary in Topics.for_scale(str(action[1])):
				if topic.id==action[2]: lesson_title=str(topic.title)
			button.set_meta("guide_search",("%s %s %s %s" % [entry.label,entry.question,action[0],lesson_title]).to_lower())
		cards.append({"node":card,"buttons":card_buttons,"actions":actions})
	empty_results = host._label(I18n.text("没有找到相关主题，试试物种、天体或场景名称。"),16)
	empty_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(empty_results)
	column.move_child(empty_results,result_count.get_index()+1)
	_filter_routes("")
	var note: Label = host._label(I18n.text("天文使用注明范围的近似模型；生态与城市含教学活动；生命内部为参考模型。各场景可查看依据与边界。"),12,Color(.65,.78,.83))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	fit_window(Vector2i(host.ui_view_size()))
	hide()

func fit_window(window_size: Vector2i) -> void:
	# Keep the longer English footer reachable without shrinking text.
	scroll.custom_minimum_size.y = minf(240,maxf(120,float(window_size.y)-520))
	var width: float = minf(1120,float(window_size.x)-48)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = (window_size.x-width)*.5
	panel.offset_right = -panel.offset_left
	panel.offset_top = 30
	panel.offset_bottom = -30
	grid.columns = 2 if window_size.x>=1000 else 1
	if is_instance_valid(species_atlas): species_atlas.fit_window(window_size.x)

func open(first_visit: bool = false) -> void:
	show_ecology(false)
	if is_instance_valid(host.guided_journey):
		journey_button.tooltip_text=host.guided_journey.entry_label("life")
		journey_button.text=I18n.text(journey_button.tooltip_text.split(" · ")[0])
		world_tour_button.tooltip_text=host.guided_journey.entry_label("world")
		world_tour_button.text=I18n.text(world_tour_button.tooltip_text.split(" · ")[0])
	refresh_context(first_visit)
	search.text = I18n.text("")
	_filter_routes("")
	scroll.scroll_vertical = 0
	show()
	resume_button.grab_focus()

func refresh_context(first_visit: bool) -> void:
	first_visit_view = first_visit
	var welcome: String = I18n.text("欢迎来到孪生宇宙。任选一个问题开始，世界会自动保存。") if host._persistence_enabled else I18n.text("欢迎来到孪生宇宙。任选一个问题开始；本次临时体验不保存进度。")
	context.text = I18n.text(welcome if first_visit else I18n.text("当前观察：%s。选择主题前往其他场景，或返回这里继续。") % Catalog.describe(host.world.current_scale_id).label)
	resume_button.text = I18n.text(I18n.text("返回世界漫游") if host.guided_journey.has_lesson_return() else I18n.text("先看看地球  Esc") if first_visit else I18n.text("返回当前观察  Esc"))

func return_to_observation() -> void:
	if host.guided_journey.has_lesson_return(): host.guided_journey.return_to_route()
	else: hide()

func show_ecology(enabled: bool) -> void:
	_show_page("ecology" if enabled else "topics")

func show_species(enabled: bool) -> void:
	_show_page("species" if enabled else "topics")
	if enabled: species_atlas.reset_filters()

func _show_page(page: String) -> void:
	var topics: bool = page == "topics"
	ecology_map.visible = page == "ecology"
	species_atlas.visible = page == "species"
	grid.visible = topics
	search.visible = topics
	result_count.visible = topics
	empty_results.visible = topics and _no_results()
	journey_button.visible = topics
	world_tour_button.visible = topics
	ecology_button.visible = page != "species"
	species_button.visible = page != "ecology"
	ecology_button.text = I18n.text(I18n.text("返回全部主题") if page == "ecology" else I18n.text("生态关系"))
	species_button.text = I18n.text(I18n.text("返回全部主题") if page == "species" else I18n.text("生命图鉴"))
	title.text = I18n.text(I18n.text("生命图鉴") if page == "species" else I18n.text("探索世界"))
	scroll.scroll_vertical=0

func _no_results() -> bool:
	for card: Dictionary in cards:
		if card.node.visible: return false
	return true

func _filter_routes(query: String) -> void:
	var terms: PackedStringArray = query.strip_edges().to_lower().replace("　"," ").split(" ",false)
	var matched: int = 0
	for card: Dictionary in cards:
		var visible_buttons: int = 0
		for button: Button in card.buttons:
			var searchable: String = button.get_meta("guide_search","")
			var matches: bool = true
			for term: String in terms:
				if not searchable.contains(term): matches=false
			button.visible=matches
			if matches: visible_buttons+=1
		card.node.visible=visible_buttons>0
		card.actions.visible=not terms.is_empty()
		matched+=visible_buttons
	result_count.text=I18n.text(I18n.text("%d 个观察主题 · 按问题探索") % route_buttons.size() if terms.is_empty() else I18n.text("找到 %d / %d 个入口") % [matched,route_buttons.size()])
	empty_results.visible=matched==0
	scroll.scroll_vertical=0
