extends HBoxContainer
## Observation-only navigation. No world checkpoint or simulation rewind.
const Catalog = preload("res://scripts/core/scale_catalog.gd")
const UI = preload("res://scripts/experience/interface_theme.gd")
var host: Node
var path_scroll: ScrollContainer
var path_row: HBoxContainer
var path_buttons: Array[Button] = []
var earth_button: Button
var galaxy_button: Button
var return_button: Button
var origin: Dictionary = {}
var departure: Dictionary = {}
var pending_restore: Dictionary = {}
var _scale: String = ""

func configure(experience: Node) -> void:
	host=experience
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation",6)
	path_scroll=ScrollContainer.new()
	path_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	path_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	path_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	path_scroll.custom_minimum_size.y=44
	path_scroll.follow_focus=true
	path_scroll.resized.connect(_scroll_to_current)
	add_child(path_scroll)
	path_row=HBoxContainer.new(); path_scroll.add_child(path_row)
	earth_button=host._button("回地球",jump.bind("earth")); add_child(earth_button)
	galaxy_button=host._button("回银河",jump.bind("galaxy")); add_child(galaxy_button)
	return_button=UI.icon("return","返回原观察位置",return_to_origin); UI.flat_button(return_button); add_child(return_button)
	return_button.tooltip_text="返回上次成功跳转前的观察位置；世界时间继续，不倒放模拟。"
	UI.flat_button(earth_button); UI.flat_button(galaxy_button)
	earth_button.hide(); galaxy_button.hide()
	refresh()

func snapshot() -> Dictionary:
	var stage: Node=host.coordinator.active_scene
	var camera: Camera3D=stage.camera
	return {"scale":host.world.current_scale_id,"position":camera.position,"target":host._orbit_target,
		"up":camera.basis.y,"projection":camera.projection,"size":camera.size,"fov":camera.fov}

func departing() -> void:
	departure=snapshot()

func arrived() -> void:
	if not pending_restore.is_empty() and pending_restore.scale==host.world.current_scale_id:
		var stage: Node=host.coordinator.active_scene
		host.explorer_panel._process(0.0)
		host.explorer_panel.clear_topic()
		# A restored physical camera also owns its subject and near playback.
		# Dropping that subject here leaves a close Earth camera at overview speed.
		if stage.scale_id!="solar_system" or int(stage.get_meta("solar_physical",{}).get("owner",-1))<0:
			host.solar_follow=-1; host._content_follow=-1
		stage.camera.projection=int(pending_restore.projection)
		stage.camera.size=float(pending_restore.size); stage.camera.fov=float(pending_restore.fov)
		host._orbit_target=pending_restore.target
		stage.set_pose(pending_restore.position,pending_restore.target,pending_restore.up)
		host.message_label.text="已返回原观察位置 · 世界时间继续"
	if not departure.is_empty(): origin=departure.duplicate(true)
	departure.clear(); pending_restore.clear()
	refresh()

func cancelled() -> void:
	departure.clear(); pending_restore.clear()

func reset_history() -> void:
	origin.clear(); cancelled(); refresh()

func jump(id: String) -> void:
	if host.coordinator.is_busy() or not host.world.foreground or id==host.world.current_scale_id: return
	if not Catalog.contains(id): return
	host.guided_journey.hide(); host.explorer_panel.hide(); host.info_panel.hide(); host.observation_panel.hide()
	host._guide_visit.clear()
	host.navigate_to(id)

func return_to_origin() -> void:
	if origin.is_empty() or host.coordinator.is_busy() or not host.world.foreground: return
	pending_restore=origin.duplicate(true)
	jump(str(origin.scale))
	if not host.coordinator.is_busy(): pending_restore.clear()

func refresh() -> void:
	var id: String=host.world.current_scale_id
	if id!=_scale:
		_scale=id
		for child: Node in path_row.get_children():
			path_row.remove_child(child); child.queue_free()
		path_buttons.clear()
		for scale_id: String in host.observation_breadcrumb():
			if not path_buttons.is_empty(): path_row.add_child(host._label("/",12,UI.MUTED))
			var button: Button=host._button(str(Catalog.describe(scale_id).label),jump.bind(scale_id))
			UI.flat_button(button)
			button.add_theme_font_size_override("font_size",16)
			button.set_meta("scale",scale_id)
			if scale_id==id:
				button.add_theme_color_override("font_disabled_color",UI.TEXT)

			button.tooltip_text="当前位置" if scale_id==id else "返回 · "+button.text
			path_row.add_child(button); path_buttons.append(button)
		_scroll_to_current.call_deferred()
	var busy: bool=host.coordinator.is_busy() or not host.world.foreground
	for button: Button in path_buttons: button.disabled=busy or str(button.get_meta("scale"))==id
	earth_button.disabled=busy or id=="earth"
	galaxy_button.disabled=busy or id=="galaxy"
	return_button.disabled=busy or origin.is_empty()
	return_button.tooltip_text="返回 · "+str(Catalog.describe(str(origin.scale)).label)+"（原观察位置；不倒放世界时间）" if not origin.is_empty() else "成功跳转后可返回原观察位置"

func _scroll_to_current() -> void:
	# Container minimum sizes settle after the new path has been laid out.
	await get_tree().process_frame
	await get_tree().process_frame
	if not path_buttons.is_empty(): path_scroll.ensure_control_visible(path_buttons[-1])

func _process(_delta: float) -> void:
	refresh()
