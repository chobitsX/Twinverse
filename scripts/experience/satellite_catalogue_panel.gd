extends VBoxContainer
const Model = preload("res://scripts/core/natural_satellites.gd")
const Builder = preload("res://scripts/experience/satellite_system_builder.gd")
var host: Node
var host_picker: OptionButton
var search: LineEdit
var picker: OptionButton
var information: Label
var observe: Button
var views: HFlowContainer
var heading: Label
var _host_id: String = "earth"
var _scale: String = ""
var _filtered: Array[Dictionary] = []
var _chosen: Dictionary = {}

func configure(experience: Node) -> void:
	host=experience
	add_theme_constant_override("separation",8)
	heading=host._label("天然卫星名录",20)
	add_child(heading)
	host_picker=OptionButton.new()
	host_picker.custom_minimum_size.y=44
	for id: String in Model.HOSTS:
		host_picker.add_item("%s · %d颗%s" % [Model.name(id),Model.count(id),"（矮行星补充）" if id=="pluto" else ""])
	host_picker.item_selected.connect(func(index: int) -> void:
		_host_id=Model.HOSTS[index]; search.text=""; _populate())
	add_child(host_picker)
	search=LineEdit.new()
	search.placeholder_text="按名字或临时编号搜索卫星"
	search.clear_button_enabled=true
	search.custom_minimum_size.y=44
	search.text_changed.connect(func(_text: String) -> void: _populate())
	add_child(search)
	picker=OptionButton.new()
	picker.custom_minimum_size.y=44
	picker.item_selected.connect(func(index: int) -> void:
		_chosen=_filtered[index-1] if index>0 and index<=_filtered.size() else {}
		_refresh_information())
	add_child(picker)
	information=host._label("",16)
	information.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(information)
	observe=host._button("进入卫星系统",_observe)
	add_child(observe)
	views=HFlowContainer.new()
	views.add_child(host._button("主要卫星近域",func() -> void: _view(false)))
	views.add_child(host._button("全部卫星全域",func() -> void: _view(true)))
	add_child(views)
	hide()

func present() -> void:
	var id: String = host.world.current_scale_id
	visible=id in ["solar_system","earth_moon"] or Model.is_system(id)
	if not visible: return
	if _scale!=id:
		_scale=id
		_host_id=Model.host_for_scale(id)
		if _host_id.is_empty():
			_host_id=Model.HOSTS[host.solar_follow] if id=="solar_system" and host.solar_follow>=0 else "earth"
		host_picker.selected=Model.HOSTS.find(_host_id)
		search.text=""
		_populate()
	_refresh_information()

func _populate() -> void:
	_filtered.clear(); _chosen={}; picker.clear()
	picker.add_item("选择卫星 · 完整名录")
	for item: Dictionary in Model.records(_host_id):
		var identity: String = str(item.display_name)+" "+str(item.get("provisional",""))
		if not search.text.is_empty() and not identity.to_lower().contains(search.text.to_lower()): continue
		_filtered.append(item)
		picker.add_item(str(item.display_name)+(" · 星历缺测" if item.get("ephemeris_status","") not in ["vectors","existing_lunar"] else ""))
	_refresh_information()

func _refresh_information() -> void:
	heading.text="%s天然卫星 · %d颗" % [Model.name(_host_id),Model.count(_host_id)]
	information.text=Model.description(_chosen) if not _chosen.is_empty() else "名录冻结于2026-10-13；八大行星共456颗已确认天然卫星。\n先选天体，再查看其资料或进入系统。"
	if Model.count(_host_id)==0: information.text=Model.name(_host_id)+"没有天然卫星。"
	if _host_id=="pluto": information.text+="\n冥王星为矮行星；5颗卫星另列名录，当前未接入3D系统。"
	var same_system: bool = Model.host_for_scale(host.world.current_scale_id)==_host_id
	var has_state: bool = _chosen.is_empty() or _chosen.get("ephemeris_status","")=="existing_lunar" or Model.has_state(_chosen,host.solar_jd)
	if not _chosen.is_empty() and not has_state: information.text+="\n当前日期缺少此卫星的可用位置。"
	observe.disabled=not Model.BRANCHES.has(_host_id) or (same_system and (not has_state or not Model.available(host.solar_jd) and _host_id!="earth"))
	observe.text="近看所选卫星" if same_system and not _chosen.is_empty() else "进入卫星系统"
	views.visible=same_system and Model.is_system(host.world.current_scale_id)

func _observe() -> void:
	var destination: String = str(Model.BRANCHES.get(_host_id,""))
	if destination.is_empty(): return
	if host.world.current_scale_id!=destination:
		host.observe_scale(destination)
		return
	if _chosen.is_empty():
		if _host_id=="earth": host._reset_camera()
		else: _view(false)
		return
	var targets: Array[Dictionary] = host.content_targets(false)
	for i: int in range(targets.size()):
		if str(targets[i].get("satellite_key",""))==str(_chosen.key) or _host_id=="earth" and i==1:
			host.explorer_panel.clear_topic()
			host.follow_content(i+1)
			return

func _view(outer: bool) -> void:
	if host.coordinator.is_busy() or not host.coordinator.active_scene.has_meta("natural_satellites"): return
	host._reset_camera()
	Builder.focus_system(host.coordinator.active_scene,outer)
	host._orbit_target=Vector3.ZERO
	host.message_label.text="全部卫星全域 · 点标仅用于识别，名字在指向时出现" if outer else "主要卫星近域 · 距离按行星半径同比缩放"
