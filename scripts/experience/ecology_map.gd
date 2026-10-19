extends VBoxContainer
const I18n = preload("res://scripts/core/app_text.gd")
const Relations = preload("res://scripts/experience/ecology_relations.gd")
signal visit_requested(scale_id: String, topic_id: String)
var host: Node
var branch_picker: OptionButton
var relation_picker: OptionButton
var graph: Control
var explanation: Label
var source_link: LinkButton
var branch: String = "reef"
var data: Dictionary
var selected: int = 0
var nodes: Dictionary = {}

func configure(experience: Node) -> void:
	host=experience
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	var intro: Label=host._label(I18n.text("食物 / 资源 → 利用它的生物"),20)
	add_child(intro)
	var note: Label=host._label(I18n.text("箭头指向消费者或分解者。连线表示资料支持的关系，不是此刻发生的摄食，也不是完整食物网。点击有三维入口的节点继续观察。"),14)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	branch_picker=OptionButton.new()
	for label: String in I18n.strings(Relations.LABELS): branch_picker.add_item(label)
	branch_picker.item_selected.connect(func(index: int) -> void: set_branch(Relations.BRANCHES[index]))
	add_child(branch_picker)
	relation_picker=OptionButton.new()
	relation_picker.item_selected.connect(select_relation)
	add_child(relation_picker)
	graph=Control.new()
	graph.custom_minimum_size.y=288
	graph.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	graph.draw.connect(_draw_relations)
	graph.resized.connect(_layout_nodes)
	add_child(graph)
	explanation=host._label("",15)
	explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(explanation)
	source_link=LinkButton.new()
	source_link.text=I18n.text(I18n.text("本条关系的资料依据 ↗"))
	source_link.pressed.connect(func() -> void: OS.shell_open(str(data.edges[selected].source)))
	add_child(source_link)
	set_branch("reef")

func set_branch(id: String) -> void:
	if not id in Relations.BRANCHES: return
	branch=id
	branch_picker.select(Relations.BRANCHES.find(id))
	data=Relations.for_branch(id)
	var last_row: int=0
	for item: Dictionary in data.nodes: last_row=maxi(last_row,int(item.row))
	graph.custom_minimum_size.y=84+last_row*68
	for child: Node in graph.get_children():
		graph.remove_child(child)
		child.queue_free()
	nodes.clear()
	for item: Dictionary in data.nodes:
		var button: Button=host._button(str(item.label),_visit.bind(str(item.topic)))
		button.add_theme_font_size_override("font_size",14)
		button.add_theme_color_override("font_disabled_color",Color(.66,.78,.81))
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.disabled=str(item.topic).is_empty()
		button.tooltip_text=I18n.text("仅作关系解释，尚无对应三维对象") if button.disabled else I18n.text("进入相关三维观察")
		button.set_meta("ecology_node",item.id)
		graph.add_child(button)
		nodes[item.id]=button
	relation_picker.clear()
	for relation: Dictionary in data.edges: relation_picker.add_item(str(relation.title))
	select_relation(0)
	_layout_nodes()

func select_relation(index: int) -> void:
	if index<0 or index>=data.edges.size(): return
	selected=index
	relation_picker.select(index)
	explanation.text=I18n.text(str(data.edges[index].note))
	for id: String in nodes:
		nodes[id].modulate=Color(1,1,1) if id in [data.edges[index].from,data.edges[index].to] else Color(.67,.75,.78)
	graph.queue_redraw()

func _visit(topic: String) -> void:
	if not topic.is_empty(): visit_requested.emit(branch,topic)

func _layout_nodes() -> void:
	if data.is_empty(): return
	var width: float=maxf(1,graph.size.x)
	for item: Dictionary in data.nodes:
		var button: Button=nodes[item.id]
		button.position=Vector2(width*.64 if item.consumer else 0,12+float(item.row)*68)
		button.size=Vector2(width*.36,54)
	graph.queue_redraw()

func _draw_relations() -> void:
	if data.is_empty(): return
	for i: int in range(data.edges.size()):
		var relation: Dictionary=data.edges[i]
		var a: Button=nodes[relation.from]
		var b: Button=nodes[relation.to]
		var start: Vector2=a.position+Vector2(a.size.x,a.size.y*.5)
		var end: Vector2=b.position+Vector2(-5,b.size.y*.5)
		var color: Color=Color(.43,.94,.77) if i==selected else Color(.18,.38,.40)
		graph.draw_line(start,end,color,3 if i==selected else 1.5,true)
		var direction: Vector2=(end-start).normalized()
		var side: Vector2=direction.orthogonal()*4
		graph.draw_colored_polygon(PackedVector2Array([end,end-direction*10+side,end-direction*10-side]),color)
