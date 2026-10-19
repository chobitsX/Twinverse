extends Control
## Sightline markers, not enlarged bodies. Hidden when the actual disc is readable.
const UI = preload("res://scripts/experience/interface_theme.gd")
const Closeup = preload("res://scripts/experience/solar_closeup.gd")
const GLYPHS: Array[String] = ["☿","♀","⊕","♂","♃","♄","♅","♆","☀","☾"]
var host: Node
var buttons: Dictionary = {}
var choices: Dictionary = {}
var leaders: Array[Vector4] = []
var marker_states: Dictionary = {}
var hovered_key: int = -1
var context_id: String = ""
const SHIFTS: Array[Vector2] = [Vector2.ZERO,Vector2(0,-42),Vector2(0,42),Vector2(-42,0),Vector2(42,0),Vector2(0,-84),Vector2(0,84),Vector2(-84,0),Vector2(84,0)]

func configure(experience: Node) -> void:
	host=experience; name="SolarContextCompass"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	hide()

static func choice_occluded(stage: Node, body: MeshInstance3D, limb_factor: float=1.015) -> bool:
	var primary: MeshInstance3D
	if stage.scale_id=="solar_system":
		var owner: int=int(stage.get_meta("solar_physical",{}).get("owner",-1))
		if owner>=0 and owner<8: primary=stage.get_meta("solar_bodies")[owner].node
		elif owner==8: primary=stage.world_root.get_node("Sun_AuthoredPhotosphere")
	elif stage.has_meta("natural_satellites"): primary=stage.get_meta("natural_satellites").planet
	elif stage.has_meta("lunar"): primary=stage.get_meta("lunar").earth
	if not is_instance_valid(primary) or body==primary: return false
	var sight: Vector3=body.global_position-stage.camera.global_position
	var offset: Vector3=primary.global_position-stage.camera.global_position
	var along: float=offset.dot(sight.normalized())
	return along>0.0 and along<sight.length() and (offset-sight.normalized()*along).length()<float(primary.mesh.radius)*primary.global_basis.get_scale().x*limb_factor

static func occluded(stage: Node, index: int) -> bool:
	var body: MeshInstance3D=stage.world_root.get_node("Sun_AuthoredPhotosphere") if index==8 else stage.get_meta("solar_moon").node if index==9 else stage.get_meta("solar_bodies")[index].node
	return choice_occluded(stage,body)

func _button(key: int) -> Button:
	if buttons.has(key): return buttons[key]
	var button: Button=Button.new()
	button.text=GLYPHS[key] if key<10 else "·"
	button.custom_minimum_size=Vector2(36,36)
	button.add_theme_font_size_override("font_size",21 if key<10 else 28)
	button.add_theme_color_override("font_color",Color(.92,.76,.47,.8) if key==8 else Color(.62,.79,.83,.65))
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover",UI.surface(Color(.035,.05,.065,.9),6,4))
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func() -> void:
		hovered_key=key
		if choices.has(key): host.optical_inspector.bearing_enter(choices[key],button.position+button.size*.5))
	button.mouse_exited.connect(func() -> void:
		if hovered_key==key:
			hovered_key=-1
			host.optical_inspector.bearing_exit())
	button.pressed.connect(func() -> void:
		if choices.has(key):
			host.optical_inspector.dismiss()
			Closeup.choose(host,choices[key]))
	add_child(button); buttons[key]=button
	return button

func collect(stage: Node) -> Dictionary:
	var result: Dictionary={}
	if stage.scale_id=="solar_system":
		for index: int in range(8):
			result[index]={"node":stage.get_meta("solar_bodies")[index].node,"label":host.Ephemeris.NAMES[index],"planet":index}
	var items: Array[Dictionary]=host.content_targets(false)
	for index: int in range(items.size()):
		var item: Dictionary=items[index]
		if not is_instance_valid(item.get("node")) or not item.node is MeshInstance3D or not item.node.mesh is SphereMesh or not item.node.visible: continue
		if stage.scale_id=="solar_system" and index>=2 and int(item.get("host_planet",-2))!=int(stage.get_meta("solar_physical",{}).get("owner",-1)): continue
		# Large catalogues remain available through the existing catalogue view.
		if stage.scale_id!="solar_system" and index>8: continue
		var choice: Dictionary=item.duplicate(); choice.index=index
		result[8+index if stage.scale_id=="solar_system" and index<2 else 10+index]=choice
	return result

func _process(delta: float) -> void:
	if host==null or not is_instance_valid(host.optical_inspector): return
	visible=host.optical_inspector.available()
	if not visible: return
	var stage: Node=host.coordinator.active_scene
	var primary: MeshInstance3D=Closeup.subject(host)
	var identity: String=str(stage.get_instance_id())+":"+str(primary.get_instance_id() if is_instance_valid(primary) else 0)
	if identity!=context_id:
		host.optical_inspector.dismiss()
		marker_states.clear(); hovered_key=-1; context_id=identity
		for button: Button in buttons.values(): button.hide()
	choices=collect(stage)
	leaders.clear()
	var size: Vector2=Vector2(host.ui_view_size())
	var frame: Rect2=host._solar_observation_frame()
	var area: Rect2=Rect2(frame.position*size,frame.size*size).grow(-22.0)
	if area.size.x<90.0 or area.size.y<90.0: hide(); return
	var placed: Array[Rect2]=[]
	var shown: Array[int]=[]
	for key: int in choices:
		var node: MeshInstance3D=choices[key].node
		var state: Dictionary=marker_states.get(key,{})
		var behind: bool=stage.camera.is_position_behind(node.global_position)
		# Different enter/leave thresholds prevent limb, edge and size chatter.
		var blocked: bool=choice_occluded(stage,node,1.025 if bool(state.get("blocked",false)) else 1.005)
		var projected: Vector2=stage.camera.unproject_position(node.global_position)/host.ui_scale
		if not projected.is_finite(): continue
		var outside: bool=behind or blocked or not area.grow(-4.0 if bool(state.get("outside",false)) else 4.0).has_point(projected)
		var radius: float=float(node.mesh.radius)*node.global_basis.get_scale().x
		var diameter: float=radius/maxf(.00001,stage.camera.global_position.distance_to(node.global_position))*float(stage.viewport.size.y)/(tan(deg_to_rad(stage.camera.fov*.5))*host.ui_scale)
		var was_shown: bool=buttons.has(key) and buttons[key].visible
		if not outside and (node==primary or diameter>(14.0 if was_shown else 10.0)): continue
		var anchor: Vector2=projected.clamp(area.position,area.end)
		if outside:
			var local: Vector3=stage.camera.to_local(node.global_position)
			var direction: Vector2=Vector2(local.x,-local.y).normalized() if behind else (projected-area.get_center()).normalized()
			if direction.length_squared()<.01: direction=Vector2.RIGHT
			var half: Vector2=area.size*.5
			var limit: float=minf(half.x/maxf(absf(direction.x),.00001),half.y/maxf(absf(direction.y),.00001))
			anchor=area.get_center()+direction*limit
		anchor=anchor.clamp(area.position,area.end)
		state.blocked=blocked; state.outside=outside; marker_states[key]=state
		if not place_marker(key,anchor,area,placed,delta): continue
		shown.append(key)
		var button: Button=buttons[key]
		state=marker_states[key]
		var center: Vector2=button.position+button.size*.5
		var line_anchor: Vector2=pixel_point(state.anchor)
		state.line=center.distance_to(line_anchor)>(16.0 if bool(state.get("line",false)) else 24.0)
		if state.line: leaders.append(Vector4(line_anchor.x,line_anchor.y,center.x,center.y))
		var tip: String=str(choices[key].label)+" · 指向放大，点击飞近"+("\n主视野中被遮挡" if blocked else "\n方位标记，不表示天体大小")
		if button.tooltip_text!=tip: button.tooltip_text=tip
	# Hiding and showing every frame also churns GUI hover, even when paused.
	for key: int in buttons:
		if key not in shown and buttons[key].visible: buttons[key].hide()
	queue_redraw()

func place_marker(key: int, anchor: Vector2, area: Rect2, placed: Array[Rect2], delta: float) -> bool:
	var button: Button=_button(key)
	button.size=Vector2(36,36)
	var state: Dictionary=marker_states.get(key,{})
	var offset: Vector2=state.get("offset",Vector2.ZERO)
	var destination: Vector2=anchor+offset
	var held: bool=hovered_key==key and state.has("center")
	if held:
		# Keep the hit target under the pointer; the leader still tracks its bearing.
		destination=Vector2(state.center).clamp(area.position,area.end)
	else:
		var candidate: Rect2=Rect2(destination-Vector2(18,18),button.size)
		var found: bool=state.has("center") and slot_free(candidate,area,placed,1.0)
		if not found:
			for shift: Vector2 in SHIFTS:
				candidate=Rect2(anchor-Vector2(18,18)+shift,button.size)
				if slot_free(candidate,area,placed,5.0):
					offset=shift; destination=anchor+shift; found=true; break
		if not found: return false
	# Reserve destinations, not in-flight positions, so easing cannot cause the
	# collision solver to change its mind again on the following frame.
	placed.append(Rect2(destination-Vector2(18,18),button.size))
	var center: Vector2=destination if held else smooth_point(state.get("center",destination),destination,delta)
	center=center.clamp(area.position,area.end)
	state.center=center; state.offset=offset
	state.anchor=smooth_point(state.get("anchor",anchor),anchor,delta)
	marker_states[key]=state
	button.position=pixel_point(center-Vector2(18,18))
	if not button.visible: button.show()
	return true

func slot_free(candidate: Rect2, area: Rect2, placed: Array[Rect2], margin: float) -> bool:
	# Edge intersections and Rect2 endpoints use different float32 arithmetic.
	# A fractional-pixel tolerance prevents an on-edge slot becoming "outside".
	if not area.grow(18.25).encloses(candidate): return false
	for occupied: Rect2 in placed:
		if candidate.grow(margin).intersects(occupied): return false
	return true

func smooth_point(previous: Vector2, target: Vector2, delta: float) -> Vector2:
	if previous.distance_to(target)<.3: return previous
	return previous.lerp(target,1.0-exp(-minf(delta,.2)/.08))

func pixel_point(point: Vector2) -> Vector2:
	return (point*host.ui_scale).round()/host.ui_scale

func _draw() -> void:
	for line: Vector4 in leaders: draw_line(Vector2(line.x,line.y),Vector2(line.z,line.w),Color(.6,.8,.85,.25),1.0,true)
