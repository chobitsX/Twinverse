extends PanelContainer
## Optional observation guidance. Never advances, rewinds or resets world state.
const Catalog = preload("res://scripts/core/scale_catalog.gd")
const WORLD_ROUTE: Array[String] = ["solar_system", "earth", "atmosphere", "reef", "woodland", "desert", "city", "polar", "earth"]
const WORLD_LESSONS: Array[Dictionary] = [
	{"label":"观察水星的快与慢","scale":"solar_system","topic":"mercury_orbit"},
	{"label":"比较地月月相","scale":"earth_moon","topic":"lunar_phases"},
	{"label":"自由观察大气与云层","scale":"atmosphere","topic":""},
	{"label":"观察食藻鱼与资源","scale":"reef","topic":"algae"},
	{"label":"比较鹿取食与植被恢复","scale":"woodland","topic":"browse"},
	{"label":"观察袋鼠鼠与种子","scale":"desert","topic":"desert_rat"},
	{"label":"观察行人与车辆通行","scale":"city","topic":"crossing"},
	{"label":"比较两半球日照","scale":"polar","topic":"season_light"},
	{"label":"浏览生命图鉴","scale":"earth","topic":""},
]
const WORLD_PROMPTS: Dictionary = {
	"solar_system": ["从太阳系看运行规律", "看八行星与轨道；对象 / 主题可比较日期、速率和显示距离。", "行星位置有日期依据；球体放大，默认距离压缩。"],
	"earth": ["一个星球，五类观察场景", "先观察地球大气，再依次看海洋、林地、荒漠、城市和南极海岸。", "礁区有区域参考；地面分支是合成教学场景。"],
	"atmosphere": ["穿过地球大气", "观察地球弧面、云层与地平线，再进入海洋生命场景。自由探索时可继续靠近海面。", "大气散射与云体为观察显示模型，不是当前天气。"],
	"reef": ["海洋：形态与生活空间", "环顾鱼、珊瑚与海草；对象 / 主题可走近章鱼、海参和目标鱼。", "布局与数量是作者设置；局部反馈不代表完整食物网。"],
	"woodland": ["林地：从树冠到河面之下", "看林缘、鹿群与河湾；对象 / 主题可近看赤狐和两种淡水鱼。", "形态有资料参考；路线、节律和河段是作者设置。"],
	"desert": ["荒漠：植物与干沟", "看多种灌木和合成干沟；对象 / 主题可近看鬣蜥、袋鼠鼠和花。", "固定花序不表示当前花期，地形不是实测或实时水文。"],
	"city": ["城市：人与共同生活的生物", "看街区与公园；“走近人群”可看行人，主题可进入鸟和池塘。", "人物、交通与季节外观是教学设置，不预测真实城市。"],
	"polar": ["南极：冰、陆与海", "看海岸与海冰；对象 / 主题可走近企鹅和真实量级的冰磷虾。", "海冰与生物布局固定；日期只改变教学光照。"],
}
const PROMPTS: Dictionary = {
	"galaxy": ["从银河到一个生命世界", "拖动观察旋臂和尘带，再沿太阳系入口缩小尺度。", "银河形态是结构示意，并非实测恒星目录。"],
	"solar_system": ["轨道上的地球", "观察行星轨道的形状与倾角；需要比较日期时，可暂时打开对象 / 主题。", "轨道显示经过缩放，天体各自放大；不是实际大小比例。"],
	"earth": ["一个星球，多种环境", "转动地球，看陆地、海洋与昼夜分界。继续靠近可先看大气；海洋地标沿大气、海面进入礁区。其他地域地标可进入当地场景。", "地表和云层是不同日期的历史合成，不是当前天气。"],
	"atmosphere": ["穿过大气", "观察地球弧面、云层和地平线；下一步进入海面。", "大气与云体为观察显示模型。"],
	"pacific": ["从海面到水下", "观察波浪与光线，继续深入同一条礁区路径。", "海面为程序化波浪；不代表实时海况。"],
	"reef": ["在礁区找到生命", "环顾鱼、珊瑚与海草。下一步沿目标鱼群进入一个有持续状态的个体。", "合成礁区并非实测物种分布；背景动物没有共用目标鱼的生理参数。"],
	"school": ["从群体找到个体", "观察目标附近的鱼，再近看同一个目标个体。", "场景数量是作者设置，不是现实种群调查。"],
	"fish": ["氧怎样进入生命链", "观察鱼的外部形态；影响链 / 记录可查看当前参考状态，然后进入心脏。", "目标鱼身份保持不变，生理参数仍为未标定参考模型。"],
	"heart": ["循环的方向", "观察静脉窦、心房、心室与动脉球；可使用剖开与区域选择。", "一般硬骨鱼结构参考，不是目标鱼扫描；颗粒不对应实测流速。"],
	"cardiomyocyte": ["从器官到细胞", "观察心肌细胞内部的空间关系，再进入线粒体。", "内部结构为跨物种参考示意；仍读取同一目标鱼的参考状态。"],
	"mitochondrion": ["能量供需的连接", "观察线粒体膜与嵴，并从影响链查看氧输送、利用和ATP供需的关系。", "膜与颗粒用于解释模型，不是逐分子动力学或实测计数。"],
	"molecule": ["氧分子的结构符号", "观察O₂由两个氧原子组成；下一步比较原子层的解释方式。", "模型状态关联解释，不追踪每个真实分子。"],
	"atom": ["到达解释层，再回看整体", "从对象 / 主题比较氧的1s、2s、2p参考云形，再查看放大的原子核，然后沿原路返回。", "氧的组态为1s² 2s² 2p⁴；云形为类氢参考，不是氧原子或O₂精确电子密度。"],
}
var host: Node
var step: int = 0
var started: bool = false
var completed: bool = false
var pending: int = -1
var route_id: String = "life"
var _life_route: Array[String] = []
var _saved_progress: Dictionary = {}
var _column: VBoxContainer
var _framing_factor: float = 1.0
var _last_width: float = 0.0
var route: Array[String] = []
var progress: Label
var heading: Label
var description: Label
var boundary: Label
var status: Label
var advance_button: Button
var previous_button: Button
var skip_button: Button
var restart_button: Button
var pause_button: Button
var lesson_button: Button
var _lesson_visit: bool = false

func configure(experience: Node, style: StyleBoxFlat) -> void:
	host=experience
	_life_route=Catalog.EXPLORATION_PATH.duplicate()
	var back: Array[String]=Catalog.EXPLORATION_PATH.slice(0,-1)
	back.reverse()
	_life_route.append_array(back)
	route=_life_route.duplicate()
	add_theme_stylebox_override("panel",style.duplicate())
	var column: VBoxContainer=VBoxContainer.new()
	_column=column
	column.add_theme_constant_override("separation",10)
	var scroller: ScrollContainer=ScrollContainer.new()
	scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroller)
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroller.add_child(column)
	progress=host._label("",13,Color(.59,.77,.81)); column.add_child(progress)
	heading=host._label("",21); heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(heading)
	description=_text(column,16)
	boundary=_text(column,13)
	boundary.add_theme_color_override("font_color",Color(.69,.78,.82))
	status=_text(column,13)
	lesson_button=host._button("",visit_lesson); column.add_child(lesson_button)
	lesson_button.tooltip_text="进入已有观察主题，随后可返回本漫游站；不会自动播放、设置日期或重置实验。"
	advance_button=host._button("",advance); column.add_child(advance_button)
	var row: HFlowContainer=HFlowContainer.new(); column.add_child(row)
	previous_button=host._button("上一步",func() -> void: request_step(step-1)); row.add_child(previous_button)
	skip_button=host._button("跳过这步",func() -> void: request_step(step+1)); row.add_child(skip_button)
	pause_button=host._button("暂停引导",suspend); row.add_child(pause_button)
	restart_button=host._button("从头重播（保留世界）",restart); column.add_child(restart_button)
	restart_button.tooltip_text="只重播观察路线，不重置世界、时间或存档。"
	fit_window(host.ui_view_size())
	hide()

func _text(parent: Node, font_size: int) -> Label:
	var label: Label=host._label("",font_size)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func fit_window(window_size: Vector2i) -> void:
	position=Vector2(24,92)
	var frame: StyleBox=get_theme_stylebox("panel")
	var height: float=_column.get_combined_minimum_size().y+frame.get_margin(SIDE_TOP)+frame.get_margin(SIDE_BOTTOM)
	size=Vector2(minf(380.,float(window_size.x)-48.),minf(height,maxf(120,window_size.y-180)))
	_column.add_theme_constant_override("separation",12)
	heading.add_theme_font_size_override("font_size",24)
	description.add_theme_font_size_override("font_size",18)
	boundary.add_theme_font_size_override("font_size",16)
	status.add_theme_font_size_override("font_size",16)

func _current_progress() -> Dictionary:
	var value: Dictionary = {"version":1,"step":step,"started":started,"completed":completed}
	if route_id == "world": value["route_revision"] = 2
	return value

func progress_for(key: String) -> Dictionary:
	var value: Dictionary = _current_progress() if key == route_id else _saved_progress.get(key,{"version":1,"step":0,"started":false,"completed":false}).duplicate(true)
	if key == "world": value["route_revision"] = 2
	return value

func checkpoint() -> Dictionary:
	# The v1 root keeps the original route readable by existing applications.
	var value: Dictionary=progress_for("life")
	value["active_route"]=route_id
	value["world_tour"]=progress_for("world")
	return value

func _valid_progress(value: Variant, length: int) -> bool:
	if not value is Dictionary or value.get("version")!=1: return false
	if not value.get("step") is float and not value.get("step") is int: return false
	var number: float=float(value.step)
	if not is_finite(number) or number!=floor(number) or number<0 or number>=length: return false
	if not value.get("started") is bool or not value.get("completed") is bool: return false
	return not value.completed or (value.started and int(number)==length-1)

func _select_route(key: String) -> void:
	_lesson_visit=false
	_saved_progress[route_id]=_current_progress()
	route_id=key
	route=WORLD_ROUTE.duplicate() if key=="world" else _life_route.duplicate()
	var value: Dictionary=_saved_progress.get(key,{"step":0,"started":false,"completed":false})
	step=int(value.step); started=bool(value.started); completed=bool(value.completed)
	pending=-1

func restore(value: Variant) -> void:
	# Malformed optional guide preferences must not discard an otherwise valid world.
	if not _valid_progress(value,_life_route.size()): return
	_lesson_visit=false
	_saved_progress["life"]={"version":1,"step":int(value.step),"started":value.started,"completed":value.completed}
	var world_value: Dictionary = _restore_world_progress(value.get("world_tour"))
	var has_world: bool = not world_value.is_empty()
	_saved_progress["world"]=world_value.duplicate(true) if has_world else {"version":1,"step":0,"started":false,"completed":false}
	route_id="world" if value.get("active_route")=="world" and has_world else "life"
	route=WORLD_ROUTE.duplicate() if route_id=="world" else _life_route.duplicate()
	var selected: Dictionary=_saved_progress[route_id]
	step=int(selected.step); started=bool(selected.started); completed=bool(selected.completed)
	pending=-1
	hide() # Reopening a saved world never forces the guide over the restored view.

func _restore_world_progress(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var revision: Variant = value.get("route_revision", 1)
	if not (revision is int or revision is float): return {}
	# JSON numbers are floats; Array membership compares Variant types.
	if float(revision) != 1.0 and float(revision) != 2.0: return {}
	if not _valid_progress(value, 8 if int(revision) == 1 else WORLD_ROUTE.size()): return {}
	var result: Dictionary = value.duplicate(true)
	# Insert the atmosphere before the original reef stop without moving a
	# saved observer to a different place or changing the original life route.
	if int(revision) == 1 and int(result.step) >= 2: result["step"] = int(result.step) + 1
	result["route_revision"] = 2
	return result

func entry_label(key: String) -> String:
	var value: Dictionary=progress_for(key)
	var title: String="世界漫游" if key=="world" else "跨尺度引导"
	if value.completed: return title+" · 查看已完成路线 / 重播"
	if value.started: return "继续%s · 第%d步" % [title,int(value.step)+1]
	return "世界漫游 · 太阳系与地球五分支" if key=="world" else "跨尺度引导 · 从银河到原子再返回"

func open(key: String="life") -> void:
	if host.coordinator.is_busy() or not host.world.foreground: return
	if key not in ["life","world"]: return
	_select_route(key)
	host.world_guide.hide(); host.explorer_panel.hide(); host.info_panel.hide(); host.observation_panel.hide()
	host._guide_visit.clear()
	show()
	if not started: request_step(0)
	else: _fit_observation(true)
	refresh()

func restart() -> void:
	if host.coordinator.is_busy(): return
	request_step(0)

func suspend() -> void:
	_lesson_visit=false
	pending=-1
	if host.coordinator.is_busy(): host.coordinator.cancel("guided_journey_paused")
	hide()
	host.save_world(false)

func request_step(index: int) -> void:
	if index<0 or index>=route.size() or host.coordinator.is_busy() or not host.world.foreground: return
	_lesson_visit=false
	pending=index
	host.observe_scale(route[index])
	refresh()

func advance() -> void:
	if pending>=0 or host.coordinator.is_busy(): return
	if host.world.current_scale_id!=route[step]:
		request_step(step)
	elif step<route.size()-1:
		request_step(step+1)
	else:
		completed=true
		host.save_world(false)
		refresh()

func visit_lesson() -> void:
	if route_id!="world" or not visible or not started or completed or pending>=0 or host.coordinator.is_busy() or not host.world.foreground: return
	_lesson_visit=true
	hide()
	if step==route.size()-1:
		host._open_guide()
		host.world_guide.show_species(true)
	else:
		var entry: Dictionary=WORLD_LESSONS[step]
		host.start_guide_visit(str(entry.scale),str(entry.topic),true)

func has_lesson_return() -> bool:
	return _lesson_visit and route_id=="world" and started and not completed and not visible

func return_to_route() -> void:
	if not has_lesson_return() or host.coordinator.is_busy() or not host.world.foreground: return
	host.explorer_panel.clear_topic()
	host.world_guide.hide(); host.explorer_panel.hide(); host.info_panel.hide(); host.observation_panel.hide()
	host._guide_visit.clear()
	show()
	request_step(step)
	refresh()

func _process(_delta: float) -> void:
	if host==null or not is_instance_valid(host.coordinator.active_scene): return
	if pending>=0 and not host.coordinator.is_busy():
		if host.world.current_scale_id==route[pending] and host.coordinator.active_scene.is_prepared():
			step=pending; started=true; completed=false
			pending=-1
			_fit_observation(true)
			host.save_world(false)
		else: pending=-1 # cancelled/failed transition does not commit guide progress
	if visible:
		if not host.coordinator.is_busy() and _last_width!=host.get_viewport().get_visible_rect().size.x: _fit_observation(false)
		refresh()

func _fit_observation(reset: bool) -> void:
	var stage: Node=host.coordinator.active_scene
	if reset:
		host._reset_camera()
		_framing_factor=1.0
	var width: float=host.get_viewport().get_visible_rect().size.x
	var factor: float=clampf(width/maxf(240.,width-get_global_rect().end.x-16.),1.0,2.0)
	var offset: Vector3=stage.camera.position-host._orbit_target
	stage.set_pose(host._orbit_target+offset*(factor/_framing_factor),host._orbit_target,stage.camera.basis.y)
	_framing_factor=factor
	_last_width=width

func refresh() -> void:
	var scale_id: String=route[step]
	var returning: bool=route_id=="life" and step>=Catalog.EXPLORATION_PATH.size()
	if route_id=="world":
		progress.text="可选世界漫游 · %d / %d" % [step+1,route.size()]
		heading.text="回看地球，继续自由探索" if step==route.size()-1 else WORLD_PROMPTS[scale_id][0]
		description.text="五类场景已沿同一世界访问。继续自由观察，或从世界导览进入具体主题。" if step==route.size()-1 else WORLD_PROMPTS[scale_id][1]
		boundary.text=WORLD_PROMPTS[scale_id][2]
	else:
		progress.text="可选跨尺度引导 · %d / %d · %s" % [step+1,route.size(),"返回宏观" if returning else "逐层深入"]
		heading.text=str(Catalog.describe(scale_id).label) if returning else PROMPTS[scale_id][0]
		description.text="逐层放大观察范围，回看%s。原来的目标鱼与参考状态仍沿同一世界时间持续。" % Catalog.describe(scale_id).label if returning else PROMPTS[scale_id][1]
		boundary.text=PROMPTS[scale_id][2]
	var busy: bool=host.coordinator.is_busy() or pending>=0
	lesson_button.visible=route_id=="world" and not completed
	lesson_button.text=WORLD_LESSONS[step].label if route_id=="world" else ""
	lesson_button.disabled=busy or not started
	status.text="正在前往下一观察点；Esc可暂停引导。" if busy else "路线已结束。可自由探索，或从头重播。" if completed else "可以自由环绕；暂停引导不会暂停世界。"
	advance_button.text="返回这一步" if host.world.current_scale_id!=scale_id else "结束路线" if step==route.size()-1 else "下一步 · "+str(Catalog.describe(route[step+1]).label)
	advance_button.disabled=busy or completed
	previous_button.disabled=busy or step==0
	skip_button.disabled=busy or step==route.size()-1
	restart_button.disabled=busy

	fit_window(host.ui_view_size())
