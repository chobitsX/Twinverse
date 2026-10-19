extends VBoxContainer
## Whole-chain view. Changes inputs through WorldState; all displayed values are snapshots.
const Model = preload("res://scripts/core/ecophysiology.gd")
var experience: Node
var values: Label
var explanation: Label
var ecosystem: Label
var events: RichTextLabel
var water_trace: Control
var uptake_trace: Control
var atp_trace: Control
var details: RichTextLabel
var budgets: Label
var reef_button: Button
var fish_button: Button
var scenario: OptionButton
var links: Array[Button] = []


class ChainTrace extends Control:
	var samples: Array[Dictionary] = []
	var field: String = "water_percent"
	var maximum: float = 110.0
	var tint: Color = Color(0.39, 0.81, 0.95)
	func _draw() -> void:
		var area: Rect2 = Rect2(50, 10, maxf(1, size.x - 58), maxf(1, size.y - 30))
		var font: Font = ThemeDB.fallback_font
		draw_rect(area, Color(0.04, 0.10, 0.14, 0.85))
		for fraction: float in [0.0, 0.5, 1.0]:
			var y: float = area.end.y - area.size.y * fraction
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.5, 0.65, 0.7, 0.22))
			draw_string(font, Vector2(0, y + 4), str(fraction * maximum), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.58, 0.71, 0.76))
		if samples.is_empty(): return
		var first: float = float(samples.front().time_s)
		var last: float = float(samples.back().time_s)
		var previous: Vector2
		var previous_time: float = -100.0
		for sample: Dictionary in samples:
			var point: Vector2 = Vector2(area.position.x + (float(sample.time_s) - first) / maxf(last - first, 1.0) * area.size.x,
				area.end.y - clampf(float(sample[field]) / maximum, 0.0, 1.0) * area.size.y)
			if float(sample.time_s) - previous_time <= 7.5: draw_line(previous, point, tint, 2.0, true)
			else: draw_circle(point, 2.0, tint)
			previous = point
			previous_time = float(sample.time_s)
		draw_circle(previous, 3.0, tint)
		draw_string(font, Vector2(area.position.x, size.y - 2), "%.0f s" % first, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.75, 0.8))
		draw_string(font, Vector2(area.end.x - 75, size.y - 2), "%.0f s" % last, HORIZONTAL_ALIGNMENT_RIGHT, 75, 16, Color(0.6, 0.75, 0.8))


func configure(host: Node) -> void:
	experience = host
	add_theme_constant_override("separation", 10)
	var badge: Label = _label("完整参考模型 · 物种参数尚待标定", 14)
	badge.modulate = Color(1.0, 0.83, 0.54)
	add_child(badge)
	add_child(_label("改变环境，沿同一条鱼看到 ATP 的变化。\n所有情境均为教学设定；可用 4× 时间观察。", 13))
	scenario = OptionButton.new()
	for key: String in Model.MODES: scenario.add_item(Model.LABELS[key])
	scenario.item_selected.connect(func(index: int) -> void:
		experience.world.set_scenario(Model.MODES[index])
		refresh())
	scenario.tooltip_text = "切换只影响接下来的输入，保留同一条鱼与历史；暂停时需继续时间。"
	add_child(scenario)
	values = _label("", 17)
	add_child(values)
	var actions: GridContainer = GridContainer.new()
	actions.columns = 3
	actions.add_theme_constant_override("h_separation", 6)
	add_child(actions)
	for pair: Array in [["礁区", "reef"], ["目标鱼", "fish"], ["心脏", "heart"], ["心肌细胞", "cardiomyocyte"], ["线粒体", "mitochondrion"], ["分子/原子", "molecule"]]:
		var button: Button = host._button(pair[0], host.observe_scale.bind(pair[1]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		links.append(button)
		actions.add_child(button)
	reef_button = links[0]
	fish_button = links[1]
	add_child(_label("水中氧 · 基线标尺 %（固定温盐换算）", 12))
	water_trace = _trace("water_percent", 110.0, Color(0.39, 0.81, 0.95))
	add_child(_label("心肌细胞氧 · 0–1 代理（非血氧饱和度）", 12))
	uptake_trace = _trace("cell_oxygen", 1.0, Color(0.98, 0.65, 0.46))
	add_child(_label("ATP 储备 · 0–20 ref_ATP（参考单位）", 12))
	atp_trace = _trace("atp", 20.0, Color(0.57, 0.88, 0.62))
	explanation = _label("", 14)
	add_child(explanation)
	ecosystem = _label("", 13)
	add_child(ecosystem)
	events = _rich()
	add_child(events)
	events.meta_clicked.connect(func(meta: Variant) -> void:
		if str(meta) in ["reef", "fish", "heart", "mitochondrion"]: experience.observe_scale(str(meta)))
	add_child(host._button("依据、假设与收支", func() -> void: details.visible = not details.visible; budgets.visible = details.visible))
	details = _rich()
	details.text = "[b]数值如何读[/b]\n当前80 mm海葵双锯鱼未做物种标定。ref_O、ref_ATP、ref_E是独立参考单位，不能换算真实耗氧、ATP浓度或焦耳。心律为相对值，非实测BPM；健康为压力代理。\n\n[b]环境[/b]\nWOA23全年历史边界：26.762°C、盐度35.156、氧204.543 µmol/kg。基线101.886%空气饱和度仅用于固定标尺，升温没有求解氧溶解度。太阳几何是参考日期的解析余弦，非辐照度。流速、营养盐和局部误差未知。\n\n[b]全链与设定时延[/b]\n水体交换12 s → 鳃摄氧4 s → 循环代理8 s / 心律10 s → 细胞氧12 s → ATP积累。时间常数不是总延迟或物种测量。\nATP生产受氧分配、底物代理和ADP反馈约束；消耗随心肌负荷增加。ATP+ADP=20；氧化通量受供氧预算限制。只建氧化磷酸化，糖酵解/乳酸/pH等未知。\n\n[b]全部作者参考参数[/b]\n氧阈值25%，心肌分配4%，ATP/氧参考换算5，Q10=2；温度45 s、生产者120 s、珊瑚180 s、压力90 s。正常/低氧/食物/风险/遮光/升温是可控情境。黄金周期300 s：边界氧在40–100 s降低、100–190 s维持6%基线、190–260 s恢复。\n\n[b]画面与科学边界[/b]\n鱼摆动、心跳和线粒体过程读取参考状态；粒子和相位为示意。分子/原子保留结构解释，环境变化不会改变原子结构。珊瑚代理不表示真实白化，参考系统不预测死亡。\n\n[b]原始研究 / 数据[/b]"
	for source: Dictionary in Model.SOURCES:
		details.text += "\n[url=%s]%s ↗[/url]\n%s\n" % [source.url, source.title, source.basis]
	details.text += "\n[b]验证边界[/b]\n数值步长和收支检查不代表生理误差或置信区间。物种实验校准另行进行。旧世界从升级时开始全链记录，原v3氧历史单独保留。"
	details.meta_clicked.connect(func(meta: Variant) -> void:
		for source: Dictionary in Model.SOURCES:
			if str(meta) == source.url: OS.shell_open(str(meta)))
	details.hide()
	add_child(details)
	budgets = _label("", 12)
	budgets.hide()
	add_child(budgets)


func _trace(field: String, maximum: float, tint: Color) -> Control:
	var trace: ChainTrace = ChainTrace.new()
	trace.field = field
	trace.maximum = maximum
	trace.tint = tint
	trace.custom_minimum_size.y = 110
	add_child(trace)
	return trace


func _rich() -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", 18)
	return label


func _label(text: String, font_size: int) -> Label:
	var label: Label = experience._label(text, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func refresh() -> void:
	var model: RefCounted = experience.world.science
	var s: Dictionary = model.snapshot()
	scenario.select(Model.MODES.find(s.mode))
	values.text = "水中氧  %.1f µmol/kg  ·  %.1f%%\n%s · 摄氧 %.3f ref_O/s\n心律 %.2f× · 细胞氧 %.2f / 1\nATP %.2f / 20 · 供给 %.3f / 需求 %.3f" % [s.water, s.water_percent, Model.BEHAVIORS[s.behavior], s.gill, s.heart_rate, s.cell_oxygen, s.atp, s.synthesis, s.demand]
	for trace: Control in [water_trace, uptake_trace, atp_trace]:
		trace.samples.assign(model.samples)
		trace.queue_redraw()
	var direction: String = "ATP 储备增加" if s.synthesis > s.consumption + 0.00001 else ("ATP 储备减少" if s.synthesis < s.consumption - 0.00001 else "ATP 收支接近平衡")
	explanation.text = "%s：供给 %.3f − 消耗 %.3f = %+.3f ref_ATP/s。\n未满足需求 %.3f ref_ATP/s；储备偏低与实际缺供分别记录。\n供氧链：摄氧 %.3f → 循环 %.2f → 细胞 %.2f。\n设定响应：水体12 s / 鳃4 s / 循环8 s / 心律10 s / 细胞12 s。" % [direction, s.synthesis, s.consumption, s.synthesis - s.consumption, s.deficit, s.gill, s.blood, s.cell_oxygen]
	explanation.text += "\n20/30%%阈值敏感性：鳃能力 %.3f–%.3f ref_O/s（非置信区间）。" % [1.5 * minf(s.water_percent / 30.0, 1.0), 1.5 * minf(s.water_percent / 20.0, 1.0)]
	if experience.world.paused: explanation.text = "时间已暂停；继续后应用当前情境。\n" + explanation.text
	if not str(s.error).is_empty(): explanation.text = "模型停止：%s。请保留当前存档。" % s.error
	ecosystem.text = "礁区与个体 · 参考代理\n水温 %.2f°C · 光照 %.2f / 1\n珊瑚栖息地 %.2f · 生产者 %.2f\n食物 %.2f ref_food · 风险 %.2f\n能量 %.1f / 100 ref_E · 健康 %.2f / 1\n伴鱼 0002 · %s · 两鱼耗氧合计 %.3f ref_O/s\n食物斑块在宿主右侧；风险时向左回避。" % [s.temperature, s.light, s.coral, s.producer, s.food, s.risk, s.energy, s.health, Model.BEHAVIORS[s.companion_behavior], s.gill + s.companion_gill]
	var lines: PackedStringArray = []
	var labels: Dictionary = {"scenario": "改变情境", "behavior": "行为改变", "oxygen_low": "循环供氧下降", "oxygen_recovered": "循环供氧恢复", "atp_low": "ATP储备低于15", "atp_recovered": "ATP储备回升至15"}
	for index: int in range(model.events.size() - 1, maxi(-1, model.events.size() - 7), -1):
		var event: Dictionary = model.events[index]
		lines.append("%.1f s  [url=%s]%s · %s[/url]\n氧 %.1f%% → 细胞 %.2f → ATP %.2f\n供给/需求 %.3f / %.3f；活动 %.2f / 风险 %.2f" % [event.time_s, event.scale_id, labels[event.kind], Model.LABELS[event.mode] if event.kind == "scenario" else Model.BEHAVIORS[event.behavior], event.water_percent, event.cell_oxygen, event.atp, event.synthesis, event.demand, event.activity, event.risk])
	events.text = "[b]因果记录 · 点击查看当前所在环节[/b]\n" + ("\n\n".join(lines) if not lines.is_empty() else "时间推进后记录变化。")
	budgets.text = "当前收支 / 每秒\n水氧：交换 %+.5f + 生产 %.5f − 呼吸 %.5f − 鱼 %.5f µmol/kg/s\n食物：%.5f − %.5f ref_food/s\n能量：%.5f − %.5f − 溢出 %.5f ref_E/s\n心肌氧：使用 %.5f ≤ 分配 %.5f ≤ 全鱼 %.5f ref_O/s\nATP+ADP = %.8f ref_ATP\n残差（水/食物/能量/ATP）：%s / %s / %s / %s\n全链开始于 %.1f s · 保留旧氧采样 %d 条" % [s.exchange, s.photo, s.respiration, s.fish_sink, s.food_growth, s.food_eaten, s.energy_intake, s.energy_cost, s.energy_overflow, s.oxygen_use, s.oxygen_supply, s.gill, s.atp + s.adp, _residual(s.water_error), _residual(s.food_error), _residual(s.energy_error), _residual(s.atp_error), s.started_at_s, s.legacy_samples]
	for button: Button in links: button.disabled = experience.coordinator.is_busy()


func _residual(value: float) -> String:
	if absf(value) < 1.0e-30: return "0"
	var exponent: int = int(floor(log(absf(value)) / log(10.0)))
	return "%.1f×10^%d" % [value / pow(10.0, exponent), exponent]
