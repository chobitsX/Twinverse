extends VBoxContainer
const I18n = preload("res://scripts/core/app_text.gd")
## One observation window visits the original two animals through the existing host.
## This presentation owns no clock, animal, scene, experiment or save state.
const Sea = preload("res://scripts/experience/turtle_motion.gd")
const Land = preload("res://scripts/experience/box_turtle.gd")
const TOPICS: Array[String] = ["turtle_compare_sea", "turtle_compare_land"]
const SEA_ID: String = "3dworld:teaching:marine:3:000"
const ROUTES: Array[Dictionary] = [
	{"scale":"reef", "topic":"turtle_compare_sea", "label":"1 海洋绿海龟", "identity":SEA_ID},
	{"scale":"woodland", "topic":"turtle_compare_land", "label":"2 林地箱龟", "identity":Land.STABLE_ID},
]
var host: Node
var buttons: Array[Button] = []
var current_topic: String = ""

func setup(owner_host: Node) -> void:
	host = owner_host
	add_theme_constant_override("separation", 7)
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	for route: Dictionary in I18n.dictionaries(ROUTES):
		var button: Button = host._button(str(route.label), visit.bind(str(route.scale)))
		button.add_theme_font_size_override("font_size", 18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.set_meta("comparison_scale", route.scale)
		button.set_meta("comparison_topic", route.topic)
		row.add_child(button)
		buttons.append(button)
	var question: Label = host._label(I18n.text("先看四肢：水中划动与陆地支撑有何不同？\n镜头各自取景，画面大小不代表体长。"), 13)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size.x = 310
	add_child(question)
	hide()

func present(topic: String) -> void:
	current_topic = topic
	visible = topic in TOPICS
	_update_buttons()

func _process(_delta: float) -> void:
	if is_visible_in_tree(): _update_buttons()

func _update_buttons() -> void:
	if not is_instance_valid(host) or not is_instance_valid(host.coordinator): return
	for button: Button in buttons:
		var selected: bool = str(button.get_meta("comparison_topic")) == current_topic
		button.set_pressed_no_signal(selected)
		button.disabled = selected or host.coordinator.is_busy() or not host.world.foreground

func visit(scale_id: String) -> void:
	if not visible or host.coordinator.is_busy() or not host.world.foreground: return
	for route: Dictionary in I18n.dictionaries(ROUTES):
		if str(route.scale) == scale_id and str(route.topic) != current_topic:
			host.start_guide_visit(str(route.scale), str(route.topic), true)
			return

static func definition(scale_id: String) -> Dictionary:
	if scale_id == "reef":
		return {"id":TOPICS[0], "title":I18n.text("龟类四肢对照：海洋鳍状肢"), "follow":4,
			"target_id":SEA_ID, "view_distance":2.1,
			"observe":I18n.text("看同一只绿海龟的长前鳍状肢与短后鳍状肢，再到林地比较箱龟的有趾足。鳍状肢仍是龟的四肢，并非鱼鳍；绿海龟的鳍状肢也有爪。它是需上浮呼吸的爬行类。"),
			"limit":I18n.text("两端模型各自取景，不能按屏幕大小判断体长。独立背甲网格可读时显示模型轴向包络，生成整皮模型未作标本尺寸标定。原8秒划动/滑行与72秒路线为作者演示，不是实测泳速、呼吸交换、内部骨骼或水动力。"),
			"source":Sea.SPECIES_SOURCE}
	return {"id":TOPICS[1], "title":I18n.text("龟类四肢对照：林地有趾足"), "follow":0,
		"target_id":Land.STABLE_ID,
		"observe":I18n.text("看箱龟的高拱背甲与地面四足，后足有四趾，再回海洋比较绿海龟的鳍状肢。箱龟以陆地林地、林缘等环境为主，足略有蹼；有趾足不等于完全不能入水。"),
		"limit":I18n.text("两个原参考个体不增加物种，镜头各自取景。模型尺寸与40秒短步/停步为作者设置，不代表实测个体或同龄比较；静态腹甲未演示闭壳，也不求解进化、内部骨骼、步速或环境适应过程。"),
		"source":Land.SOURCE}

static func root_for(owner_host: Node, topic: String) -> Node3D:
	if topic not in TOPICS: return null
	var identity: String = SEA_ID if topic == TOPICS[0] else Land.STABLE_ID
	for target: Dictionary in owner_host.content_targets(false):
		var animal: Node3D = target.node
		if str(animal.get_meta("stable_id", "")) == identity: return animal
	return null

static func shell_length(root: Node3D, mesh_name: String) -> float:
	if not is_instance_valid(root): return NAN
	var shell: MeshInstance3D = root.find_child(mesh_name, true, false) as MeshInstance3D
	if not is_instance_valid(shell) or shell.mesh == null: return NAN
	var bound: AABB = shell.get_aabb()
	var first: float = INF
	var last: float = -INF
	for corner: int in range(8):
		var local: Vector3 = root.to_local(shell.to_global(bound.get_endpoint(corner)))
		first = minf(first, local.x)
		last = maxf(last, local.x)
	return (last-first)*root.global_basis.x.length()

static func readout(owner_host: Node, topic: String) -> String:
	var root: Node3D = root_for(owner_host, topic)
	if root == null: return I18n.text("等待当前动物观察就绪")
	var sea: bool = topic == TOPICS[0]
	var length: float = shell_length(root, "Carapace" if sea else "CarapaceDome")
	var size: String = I18n.text("生成形态参考 · 背甲标本尺寸未标定") if sea and root.has_meta("turtle_skin") else I18n.text("背甲长度暂不可读") if not is_finite(length) else I18n.text("本模型背甲长约 %.1f 厘米") % (length*100.)
	return "%s\n%s\n%s" % [I18n.text("绿海龟 · 海洋鳍状肢") if sea else I18n.text("东部箱龟 · 林地有趾足"), size, str(root.get_meta("activity", I18n.text("观察四肢形态")))]

static func marks(owner_host: Node, topic: String) -> Array[Dictionary]:
	var root: Node3D = root_for(owner_host, topic)
	if root == null: return []
	return Sea.marks(root) if topic == TOPICS[0] else Land.marks(owner_host, "box_turtle")
