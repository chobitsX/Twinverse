extends Control
## Screen-space annotations projected from the live scene; never takes input.
const School = preload("res://scripts/experience/school_observation.gd")
const Topics = preload("res://scripts/experience/learning_topics.gd")
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const Ruler = preload("res://scripts/experience/observation_ruler.gd")
var host: Node
var topic: String = ""
var branch: String = ""
var enabled: bool = true
var last_visible_marks: int = 0
var last_solar_labels: Array[Dictionary] = []
var last_season_labels: Array[Dictionary] = []
var last_solar_font_size: int = 0
var solar_reserved_rects: Array[Rect2] = []
var last_ruler: Dictionary = {}
var _solar_box: StyleBoxFlat

func configure(experience: Node) -> void:
	host = experience
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -1
	_solar_box = StyleBoxFlat.new()
	_solar_box.bg_color = Color(.055,.067,.084,.94)
	_solar_box.border_color = Color(.76,.83,.90,.14)
	_solar_box.set_border_width_all(1)
	_solar_box.set_corner_radius_all(5)

func select(id: String) -> void:
	topic = id
	branch = host.world.current_scale_id
	queue_redraw()

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		last_solar_labels = []
		last_season_labels = []
		last_solar_font_size = 0
		last_ruler = {}
	queue_redraw()

func _draw() -> void:
	last_ruler = {}
	last_visible_marks = 0
	last_solar_labels = []
	last_season_labels = []
	last_solar_font_size = 0
	solar_reserved_rects = []
	if host==null or not enabled or host.coordinator.is_busy(): return
	var season_rects: Array[Rect2] = []
	_draw_earth_season_labels(season_rects)
	if topic.is_empty() or host.world.current_scale_id!=branch:
		_draw_local_ruler(season_rects)
		return
	if topic=="school": School.draw_neighbors(self,host)
	var stage: Node = host.coordinator.active_scene
	var camera: Camera3D = stage.camera
	var marks: Array[Dictionary] = Topics.marks(host,topic)
	var points: Array[Vector2] = []
	var available: Array[bool] = []
	for mark: Dictionary in marks:
		points.append(local_point(camera.unproject_position(mark.at)))
		available.append(not camera.is_position_behind(mark.at))
	var left: float = host.explorer_panel.offset_right+16.0 if host.explorer_panel.visible else 24.0
	var font: Font = get_theme_default_font()
	var occupied: Array[Rect2] = season_rects.duplicate()
	if host.immersive_interface.context_panel.visible: occupied.append(local_rect(host.immersive_interface.context_panel.get_global_rect()))
	for i: int in range(marks.size()):
		if not available[i] or not Rect2(Vector2.ZERO,size).has_point(points[i]): continue
		var mark: Dictionary = marks[i]
		var p: Vector2 = points[i]
		var color: Color = Color(.51,.92,.83)
		if mark.has("link") and available[int(mark.link)]:
			draw_line(p,points[int(mark.link)],Color(.82,.83,.47,.75),2,true)
		var text: String = mark.label
		var width: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+20
		var at: Vector2 = p+Vector2(mark.offset)
		at.x = clampf(at.x,left,maxf(left,size.x-width-20))
		at.y = clampf(at.y,140.0,maxf(140,size.y-185))
		var rect: Rect2 = Rect2(at,Vector2(width,32))
		for previous: Rect2 in occupied:
			if rect.intersects(previous): rect.position.y = minf(previous.end.y+8,size.y-175)
		occupied.append(rect)
		draw_line(p,rect.get_center(),Color(.51,.92,.83,.8),1.5,true)
		draw_circle(p,4,color)
		draw_rect(rect,Color(.012,.037,.044,.95))
		draw_rect(rect,Color(.36,.70,.65,.65),false,1)
		draw_string(font,rect.position+Vector2(10,22),text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(.87,.98,.96))
		last_visible_marks += 1
	_draw_local_ruler(occupied)


func _draw_earth_season_labels(occupied: Array[Rect2]) -> void:
	if host.world.current_scale_id!="solar_system" or host.world_guide.visible or host.size_comparison.visible: return
	var stage: Node = host.coordinator.active_scene
	if not stage.has_meta("earth_season_orbit"): return
	var data: Dictionary = stage.get_meta("earth_season_orbit")
	if not data.active or not data.root.visible: return
	var camera: Camera3D = stage.camera
	var factor: float = .16 if host.solar_true_distance else 1.0
	var left: float = local_rect(host.explorer_panel.get_global_rect()).end.x+12.0 if host.explorer_panel.visible else 24.0
	var safe: Rect2 = Rect2(Vector2(left,120),Vector2(maxf(0,size.x-left-20),maxf(0,size.y-255)))
	var obstacles: Array[Rect2] = []
	for entry: Dictionary in data.samples:
		var center: Vector2 = local_point(camera.unproject_position(entry.node.global_position))
		var edge: Vector2 = local_point(camera.unproject_position(entry.node.global_position+camera.global_basis.x*.70*factor))
		var radius: float = center.distance_to(edge)+7.0
		obstacles.append(Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2.0))
	var font: Font = get_theme_default_font()
	for index: int in range(data.samples.size()):
		var entry: Dictionary = data.samples[index]
		var tip: Vector3 = entry.node.global_position+entry.pole*1.7*factor
		if camera.is_position_behind(tip): continue
		var point: Vector2 = local_point(camera.unproject_position(tip))
		var text: String = ["3月参考","6月参考","9月参考","12月参考"][index]+" · N"
		var dimensions: Vector2 = Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+20,30)
		var rect: Rect2 = _solar_name_slot(point,dimensions,0,safe,obstacles)
		if not rect.has_area(): continue
		obstacles.append(rect.grow(5))
		occupied.append(rect)
		var anchor: Vector2 = Vector2(clampf(point.x,rect.position.x,rect.end.x),clampf(point.y,rect.position.y,rect.end.y))
		draw_line(point,anchor,Color(.55,.96,.84,.8),1.25,true)
		draw_circle(point,2,Color(.55,.96,.84))
		draw_style_box(_solar_box,rect)
		draw_string(font,rect.position+Vector2(10,21),text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(.87,.98,.96))
		last_season_labels.append({"date_index":index,"rect":rect,"font_size":16,"text":text,"point":point})


func _draw_local_ruler(topic_rects: Array[Rect2]) -> void:
	if not Ruler.supported(host.world.current_scale_id): return
	if (is_instance_valid(host.world_guide) and host.world_guide.visible) or (is_instance_valid(host.size_comparison) and host.size_comparison.visible): return
	var stage: Node = host.coordinator.active_scene
	var measured: Dictionary = Ruler.measure(stage.camera, host._orbit_target, size)
	if measured.is_empty(): return
	var reserved: Array[Rect2] = topic_rects.duplicate()
	for control: Control in [host.explorer_panel, host.guided_journey, host.info_panel, host.observation_panel, host.sound_panel, host.science_badge]:
		if is_instance_valid(control) and control.is_visible_in_tree(): reserved.append(local_rect(control.get_global_rect()))
	var rect: Rect2 = Ruler.layout(size, reserved)
	if not rect.has_area(): return
	last_ruler = measured
	last_ruler["rect"] = rect
	var font: Font = get_theme_default_font()
	draw_style_box(_solar_box, rect)
	draw_string(font, rect.position + Vector2(12, 21), "观察中心 · 参考尺", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(.72, .88, .88))
	var start: Vector2 = rect.position + Vector2(12, 36)
	var finish: Vector2 = start + Vector2(float(measured.pixels), 0.0)
	var color: Color = Color(.51, .92, .83)
	draw_line(start, finish, color, 2.0, true)
	for tick: Vector2 in [start, (start + finish) * .5, finish]: draw_line(tick - Vector2(0, 4), tick + Vector2(0, 4), color, 1.5, true)
	draw_string(font, rect.position + Vector2(12, 62), str(measured.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(.87, .98, .96))


func _solar_name_slot(point: Vector2, dimensions: Vector2, angle: float, safe: Rect2, obstacles: Array[Rect2]) -> Rect2:
	# Nine possible names; bounded candidates, cached until projection/panels change.
	for distance: float in [32.0,56.0,84.0,116.0,156.0,204.0,256.0,324.0,416.0]:
		for turn: int in range(16):
			var offset: Vector2 = Vector2.from_angle(angle + float(turn)*TAU/16.0) * distance
			var rect: Rect2 = Rect2(point+offset-dimensions*.5,dimensions)
			if not safe.encloses(rect): continue
			var clear: bool = true
			for obstacle: Rect2 in obstacles:
				if rect.intersects(obstacle):
					clear = false
					break
			if clear: return rect
	return Rect2()


func local_point(camera_pixel: Vector2) -> Vector2:
	return get_global_transform().affine_inverse()*camera_pixel

func local_rect(physical: Rect2) -> Rect2:
	return Rect2(local_point(physical.position),physical.size/host.ui_scale)
