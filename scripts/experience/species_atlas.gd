extends VBoxContainer
## Browses existing model visits; no additional world or 3D viewport.
signal visit_requested(scale_id: String, topic_id: String)
const Species = preload("res://scripts/experience/species_catalog.gd")
var host: Node
var owner_scroll: ScrollContainer
var area_filter: OptionButton
var kind_filter: OptionButton
var search: LineEdit
var reset_button: Button
var count: Label
var empty: Label
var grid: GridContainer
var cards: Array[Dictionary] = []
var area_ids: Array[String] = [""]
var kind_ids: Array[String] = [""]

func configure(experience: Node, style: StyleBoxFlat, scroller: ScrollContainer) -> void:
	host = experience
	owner_scroll = scroller
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var intro: Label = host._label("%d种具名教学参考 · 从形态走近不同生境" % Species.ENTRIES.size(), 19)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	var note: Label = host._label("每种选一个代表入口。雌雄、幼虫、多只个体和跨场景复用只列一次；真菌单列，人物与未鉴种背景不计种。", 13, Color(.68, .84, .89))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	var filters: HFlowContainer = HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	filters.add_theme_constant_override("v_separation", 8)
	add_child(filters)
	area_filter = OptionButton.new()
	area_filter.custom_minimum_size = Vector2(180, 40)
	area_filter.add_item("所有入口场景")
	for area_id: String in Species.AREAS:
		area_ids.append(area_id)
		area_filter.add_item(Species.AREAS[area_id])
	area_filter.item_selected.connect(func(_index: int) -> void: _apply_filters())
	filters.add_child(area_filter)
	kind_filter = OptionButton.new()
	kind_filter.custom_minimum_size = Vector2(185, 40)
	kind_filter.add_item("所有类群")
	for kind_id: String in Species.KINDS:
		kind_ids.append(kind_id)
		kind_filter.add_item(Species.KINDS[kind_id])
	kind_filter.item_selected.connect(func(_index: int) -> void: _apply_filters())
	filters.add_child(kind_filter)
	search = LineEdit.new()
	search.custom_minimum_size = Vector2(270, 40)
	search.placeholder_text = "中文名或科学名，如 银杏 / Ginkgo"
	search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size",18)
	search.text_changed.connect(func(_query: String) -> void: _apply_filters())
	filters.add_child(search)
	reset_button = host._button("重置筛选", reset_filters)
	filters.add_child(reset_button)
	count = host._label("", 13, Color(.48, .83, .81))
	add_child(count)
	empty = host._label("没有匹配的参考。清空名称，或重置场景与类群筛选。", 16)
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(empty)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	for entry: Dictionary in Species.ENTRIES:
		var card: PanelContainer = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var frame: StyleBoxFlat = style.duplicate()
		frame.bg_color = Color(.09, .11, .145, 1)
		frame.content_margin_top = 12
		frame.content_margin_bottom = 12
		frame.content_margin_left = 16
		frame.content_margin_right = 16
		card.add_theme_stylebox_override("panel", frame)
		grid.add_child(card)
		var body: VBoxContainer = VBoxContainer.new()
		body.add_theme_constant_override("separation", 6)
		card.add_child(body)
		body.add_child(host._label("%s · %s入口" % [Species.KINDS[entry.kind], Species.AREAS[Species.area(entry)]], 12, Color(.48, .83, .81)))
		for item: Array in [[entry.name, 20], [entry.scientific, 13], [entry.detail, 13]]:
			var label: Label = host._label(str(item[0]), int(item[1]))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(label)
		var button: Button = host._button(str(entry.view) + "  →", func() -> void: visit_requested.emit(str(entry.scale), str(entry.topic)))
		button.add_theme_font_size_override("font_size",18)
		button.set_meta("species_id", entry.id)
		body.add_child(button)
		cards.append({"node":card, "button":button, "entry":entry})
	reset_filters()
	fit_window(int(host.ui_view_size().x))

func fit_window(width: int) -> void:
	grid.columns = 3 if width >= 1000 else 2 if width >= 740 else 1

func reset_filters() -> void:
	area_filter.select(0)
	kind_filter.select(0)
	search.text = ""
	_apply_filters()

func _apply_filters() -> void:
	var area_id: String = area_ids[area_filter.selected]
	var kind_id: String = kind_ids[kind_filter.selected]
	var terms: PackedStringArray = search.text.strip_edges().to_lower().replace("　", " ").split(" ", false)
	var matched: int = 0
	for card: Dictionary in cards:
		var entry: Dictionary = card.entry
		var matches: bool = (area_id.is_empty() or Species.area(entry) == area_id) and (kind_id.is_empty() or entry.kind == kind_id)
		var value: String = Species.searchable(entry)
		for term: String in terms:
			if not value.contains(term): matches = false
		card.node.visible = matches
		if matches: matched += 1
	count.text = "显示 %d / %d 种 · 入口场景用于导航，不表示自然分布" % [matched, Species.ENTRIES.size()]
	empty.visible = matched == 0
	owner_scroll.scroll_vertical = 0

func visible_ids() -> Array[String]:
	var result: Array[String] = []
	for card: Dictionary in cards:
		if card.node.visible: result.append(str(card.entry.id))
	return result
