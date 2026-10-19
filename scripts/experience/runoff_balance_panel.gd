extends VBoxContainer
## Four disjoint water compartments from the original equal-area experiment.
const Model = preload("res://scripts/core/urban_runoff.gd")
const KEYS: Array[String] = ["surface", "soil", "runoff", "drained"]
const COLORS: Array[Color] = [Color(.24,.67,.9),Color(.36,.77,.48),Color(1.,.68,.30),Color(.67,.69,1.)]
var header: Label
var bars: Array[WaterBar] = []
var amounts: Array[Array] = []
var last_values_l: Array[Array] = []
var total_l: float = 0.0

class WaterBar extends Control:
	var values_l: Array[float] = []
	var total_l: float = 0.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(.12,.20,.23))
		if total_l<=0.0: return
		var left: float = 0.0
		for index: int in range(values_l.size()):
			var width: float = size.x*values_l[index]/total_l
			draw_rect(Rect2(Vector2(left,0),Vector2(width,size.y)),COLORS[index])
			left+=width

func _init() -> void:
	add_theme_constant_override("separation",4)
	header=label("")
	add_child(header)
	for index: int in range(2):
		add_child(label("硬地 · 不入渗" if index==0 else "绿地 · 入渗是内部转移"))
		var bar: WaterBar = WaterBar.new()
		bar.custom_minimum_size.y=12
		bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bars.append(bar)
		var grid: GridContainer = GridContainer.new()
		grid.columns=2
		grid.add_theme_constant_override("h_separation",8)
		grid.add_theme_constant_override("v_separation",2)
		var row: Array[Label] = []
		for part: int in range(4):
			var value: Label=label("")
			value.add_theme_color_override("font_color",COLORS[part])
			value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			grid.add_child(value)
			row.append(value)
		add_child(grid)
		amounts.append(row)
	add_child(label("合计=降雨 · 占比非水深"))

func label(text: String) -> Label:
	var value: Label=Label.new()
	value.text=text
	value.add_theme_font_size_override("font_size",18)
	value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	value.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return value

func present(state: Dictionary) -> void:
	total_l=float(state.rain_mm)*Model.AREA_M2
	header.text="每区降雨 %.1f L · 示意 %.1f min" % [total_l,int(state.steps)*Model.STEP]
	if total_l==0.0: header.text+="\n尚无降雨 · 空条不表示百分比"
	last_values_l.clear()
	for index: int in range(2):
		var values: Array[float] = []
		for key: String in KEYS: values.append(float(state[key][index])*Model.AREA_M2)
		last_values_l.append(values.duplicate())
		bars[index].values_l=values
		bars[index].total_l=total_l
		bars[index].queue_redraw()
		for part: int in range(4):
			amounts[index][part].text="%s %.1f L" % [["地表暂存","土壤现存","累计径流","累计深排水"][part],values[part]]
