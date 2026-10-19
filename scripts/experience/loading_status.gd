extends PanelContainer
const I18n = preload("res://scripts/core/app_text.gd")
## Shows the real coordinator phase without inventing a completion clock.
var host: Node
var heading: Label
var phase_label: Label
var resource_bar: ProgressBar
var cancel_button: Button

func configure(experience: Node, style: StyleBoxFlat) -> void:
	host=experience
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left=-190;offset_right=190;offset_top=92
	add_theme_stylebox_override("panel",style)
	var column: VBoxContainer=VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	add_child(column)
	heading=host._label("",17)
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	phase_label=host._label("",13)
	column.add_child(phase_label)
	resource_bar=ProgressBar.new()
	resource_bar.custom_minimum_size.y=8
	resource_bar.show_percentage=false
	column.add_child(resource_bar)
	cancel_button=host._button(I18n.text("留在当前场景"),_cancel)
	cancel_button.tooltip_text=I18n.text("取消这次进入；已开始的资源读取可能仍需在后台完成，不会重复启动加载。")
	column.add_child(cancel_button)
	hide()

func _cancel() -> void:
	host.coordinator.cancel("user_cancelled")
	refresh()

func refresh() -> void:
	var status: Dictionary=host.coordinator.loading_status()
	visible=bool(status.cancellable) and not host._spatial_authoring_visible()
	if not visible:return
	heading.text=I18n.text(I18n.text("正在进入 · ")+str(host.Catalog.describe(str(status.target)).label))
	resource_bar.hide()
	match int(status.phase):
		host.Coordinator.Phase.LOADING:
			var fraction: float=float(status.resource_fraction)
			phase_label.text=I18n.text(I18n.text("正在读取资源…") if fraction<0. else I18n.text("资源读取 %.0f%% · 随后准备场景") % (fraction*100.))
			resource_bar.visible=fraction>=0.
			resource_bar.value=maxf(0.,fraction)*100.
		host.Coordinator.Phase.PREPARING:
			phase_label.text=I18n.text(I18n.text("正在准备观察内容…"))
		host.Coordinator.Phase.AUTHORING:
			phase_label.text=I18n.text(I18n.text("正在靠近…"))

func _process(_delta: float) -> void:
	refresh()
