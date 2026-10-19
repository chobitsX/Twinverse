extends PanelContainer
const I18n = preload("res://scripts/core/app_text.gd")
## Authored exploration areas on the globe, never real habitat boundaries.
const Sites = preload("res://scripts/data/earth_sites.gd")
const Locator = preload("res://scripts/experience/earth_locator.gd")
const ORDER: Array[String] = ["reef", "woodland", "desert", "city", "polar", "arctic", "night_sky"]
const LABELS: Dictionary = {"reef":"海洋 · 蜥蜴岛区域", "woodland":"林地与河岸", "desert":"索诺兰荒漠", "city":"城市与人类", "polar":"南极海岸", "arctic":"北极海冰与夜空", "night_sky":"观星 · 阿塔卡马高原"}
const COLORS: Dictionary = {"reef":Color(.43,.70,.74), "woodland":Color(.49,.69,.54), "desert":Color(.77,.65,.47), "city":Color(.52,.65,.79), "polar":Color(.74,.80,.85), "arctic":Color(.48,.78,.73), "night_sky":Color(.67,.60,.88)}
# Longitude/latitude offsets from the existing reference. These are teaching
# interaction areas, not geographic survey, weather or species distributions.
const AREAS: Dictionary = {
	"arctic":[Vector2(-17,1),Vector2(-10,4),Vector2(3,4),Vector2(16,2),Vector2(18,-2),Vector2(5,-4),Vector2(-8,-3),Vector2(-18,-1)],
	"night_sky":[Vector2(-2.5,3),Vector2(.5,4),Vector2(2,1.5),Vector2(1,-3),Vector2(-2,-4),Vector2(-3,-1)],
	"reef":[Vector2(-1,2),Vector2(3,4),Vector2(6,3),Vector2(8,0),Vector2(9,-4),Vector2(7,-8),Vector2(4,-10),Vector2(2,-7),Vector2(1,-3),Vector2(-.8,-1)],
	"woodland":[Vector2(-5,2),Vector2(-2,4),Vector2(2,3.5),Vector2(5,1),Vector2(4,-2),Vector2(1,-4),Vector2(-3,-3),Vector2(-5,0)],
	"desert":[Vector2(-4,1),Vector2(-2,3),Vector2(1,4),Vector2(4,2),Vector2(3,-1),Vector2(1,-3),Vector2(-2,-4),Vector2(-4,-2)],
	"city":[Vector2(-3,1),Vector2(-1,2.5),Vector2(2,2),Vector2(3,-.5),Vector2(1.5,-2),Vector2(-1,-2.5),Vector2(-3,-1)],
	"polar":[Vector2(-12,1),Vector2(-7,2),Vector2(1,1.5),Vector2(10,0),Vector2(12,-2),Vector2(3,-4),Vector2(-5,-3),Vector2(-11,-1)],
}
const SURFACE_RADIUS: float = 3.028
const DRAG_DISTANCE: float = 6.0
var host: Node
var marker_stage: Node
var points: Dictionary = {}
var selected: String = ""
var hovered: String = ""
var caption: Label
# Read-only state handles retained for saved observers/diagnostics. The shared
# immersive interface owns the visible context strip instead of duplicating it.
var hint: PanelContainer
var card: PanelContainer
var card_title: Label
var card_kind: Label
var footnote: Label
var armed: bool = false
var dragged: bool = false
var pressed_at: Vector2 = Vector2.ZERO
var pressed_id: String = ""

func configure(experience: Node, _base_style: StyleBoxFlat) -> void:
	host = experience
	name = "EarthEntryPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = PanelContainer.new(); hint.hide(); add_child(hint)
	card = PanelContainer.new(); card.hide(); add_child(card)
	var state: VBoxContainer = VBoxContainer.new(); card.add_child(state)
	card_title = host._label("",18); state.add_child(card_title)
	card_kind = host._label("",12); state.add_child(card_kind)
	footnote = host._label("",11); state.add_child(footnote)
	hide()

func fit_window(_view_size: Vector2i) -> void:
	pass # Geographic areas are projected from the live camera, never 2D buttons.

func available() -> bool:
	return is_instance_valid(host.coordinator.active_scene) and host.world.current_scale_id=="earth" and not host.coordinator.is_busy() and host.world.foreground and not host.world_guide.visible and not host.size_comparison.visible and not host.guided_journey.visible and host.learning_overlay.topic!="earth_daylight"

func clear_selection() -> void:
	selected = ""; hovered = ""
	card.hide()
	host._refresh_city_view_button()

func select_region(id: String) -> void:
	if not available() or not ORDER.has(id): return
	selected = id
	host._earth_reference = id
	card_title.text = I18n.text(I18n.dictionary(LABELS)[id])
	card_kind.text = I18n.text(I18n.text("Paranal参考观星位置 · 合成山地平台") if id=="night_sky" else I18n.text("蜥蜴岛区域 · 场景布局为教学设定") if id=="reef" else I18n.text("光照参考区域 · 合成场景，非实地地址"))
	footnote.text = I18n.text(I18n.text("地球 → 大气 → 海面 → 珊瑚礁") if id=="reef" else I18n.text("再点区域或双指靠近进入 · 拉远返回"))
	host.message_label.text = I18n.text(I18n.text("已选 ")+str(I18n.dictionary(LABELS)[id])+I18n.text(" · 双指靠近探索"))
	host._refresh_city_view_button()
	refresh_points()

func enter_selected() -> void:
	if not is_instance_valid(host.coordinator.active_scene) or host.world.current_scale_id!="earth" or not ORDER.has(selected): return
	if host.coordinator.is_busy() or not host.world.foreground or host.world_guide.visible or host.size_comparison.visible: return
	host.guided_journey.hide(); host.explorer_panel.hide()
	host.observe_scale("atmosphere" if selected=="reef" else selected)

func _surface_point(site: Dictionary, offset: Vector2, radius: float = SURFACE_RADIUS) -> Vector3:
	return Sites.normal(float(site.lat)+offset.y,float(site.lon)+offset.x)*radius

func _triangle(vertices: PackedVector3Array, site: Dictionary, origin: Vector3, a: Vector2, b: Vector2, c: Vector2) -> void:
	# Subdivision follows the sphere; a flat large triangle would cut the Earth.
	const STEPS: int = 8
	for i: int in range(STEPS):
		for j: int in range(STEPS-i):
			var p: Vector2 = a+(b-a)*float(i)/STEPS+(c-a)*float(j)/STEPS
			var q: Vector2 = a+(b-a)*float(i+1)/STEPS+(c-a)*float(j)/STEPS
			var r: Vector2 = a+(b-a)*float(i)/STEPS+(c-a)*float(j+1)/STEPS
			for at: Vector2 in [p,q,r]: vertices.append(_surface_point(site,at)-origin)
			if i+j<STEPS-1:
				var t: Vector2 = a+(b-a)*float(i+1)/STEPS+(c-a)*float(j+1)/STEPS
				for at: Vector2 in [q,t,r]: vertices.append(_surface_point(site,at)-origin)

func _build_markers(stage: Node) -> void:
	if stage.has_meta("earth_entry_markers"): return
	var entries: Dictionary = {}
	for id: String in ORDER:
		var site: Dictionary = Sites.for_scale(id)
		var polygon: PackedVector2Array = PackedVector2Array(AREAS[id])
		var root: Node3D = Node3D.new(); root.name = "EarthExplorationArea_"+id
		root.position = Sites.normal(float(site.lat),float(site.lon))*SURFACE_RADIUS
		stage.world_root.add_child(root)
		var vertices: PackedVector3Array = []
		var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
		for i: int in range(0,indices.size(),3): _triangle(vertices,site,root.position,polygon[indices[i]],polygon[indices[i+1]],polygon[indices[i+2]])
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh: ArrayMesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(COLORS[id],.14); material.render_priority = 10
		var patch: MeshInstance3D = MeshInstance3D.new(); patch.mesh = mesh; patch.material_override = material
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(patch)
		var boundary_mesh: ImmediateMesh = ImmediateMesh.new(); boundary_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i: int in range(polygon.size()):
			var a: Vector2 = polygon[i]; var b: Vector2 = polygon[(i+1)%polygon.size()]
			var steps: int = maxi(2,int(ceil(a.distance_to(b)/.4)))
			for step: int in range(steps): boundary_mesh.surface_add_vertex(_surface_point(site,a.lerp(b,float(step)/steps),SURFACE_RADIUS+.002)-root.position)
		boundary_mesh.surface_add_vertex(_surface_point(site,polygon[0],SURFACE_RADIUS+.002)-root.position); boundary_mesh.surface_end()
		var border_material: StandardMaterial3D = material.duplicate() as StandardMaterial3D
		border_material.albedo_color = Color(COLORS[id],.38)
		var border: MeshInstance3D = MeshInstance3D.new(); border.mesh = boundary_mesh; border.material_override = border_material
		border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(border)
		var label: Label3D = Locator._label(stage,str(I18n.dictionary(LABELS)[id]).split(" · ")[0],COLORS[id])
		label.font_size = 16; label.outline_size = 2; label.modulate = Color(.88,.93,.95); label.hide()
		entries[id] = {"root":root,"material":material,"border_material":border_material,"label":label,"polygon":polygon,"site":site}
	stage.set_meta("earth_entry_markers",entries)

func _blocked(point: Vector2) -> bool:
	if host.immersive_interface.blocks(point): return true
	for control: Control in [host.info_panel,host.observation_panel,host.sound_panel,host.explorer_panel,host.guided_journey]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return false

func refresh_points() -> void:
	points.clear()
	if not is_instance_valid(host.coordinator.active_scene): return
	var stage: Node = host.coordinator.active_scene
	if stage.scale_id!="earth":
		if is_instance_valid(marker_stage) and marker_stage.has_meta("earth_entry_markers"):
			for entry: Dictionary in marker_stage.get_meta("earth_entry_markers").values(): entry.root.hide(); entry.label.hide()
		return
	marker_stage = stage; _build_markers(stage)
	var camera: Camera3D = stage.camera
	var physical: Vector2=host.get_viewport().get_visible_rect().size
	var safe: Rect2 = Rect2(Vector2(16,80)*host.ui_scale,physical-Vector2(32,168)*host.ui_scale)
	var named: String = selected if not selected.is_empty() else hovered
	for id: String in ORDER:
		var entry: Dictionary = stage.get_meta("earth_entry_markers")[id]
		var point: Vector3 = entry.root.global_position
		var front: bool = not camera.is_position_behind(point) and Locator.front_facing(point,camera.global_position)
		entry.root.visible = (host.world.current_scale_id=="earth" and not host.coordinator.is_busy() and host.learning_overlay.topic!="earth_daylight") or host.coordinator.is_busy() and not host._earth_flight.is_empty()
		entry.label.hide()
		entry.label.font_size=int(16*host.ui_scale)
		var emphasized: bool = id==named
		entry.material.albedo_color = Color(COLORS[id],.27 if emphasized else .12)
		entry.border_material.albedo_color = Color(COLORS[id],.78 if emphasized else .30)
		if not available() or not front: continue
		var pixel: Vector2 = camera.unproject_position(point)
		if not safe.has_point(pixel) or _blocked(pixel): continue
		points[id] = {"pixel":pixel,"world":point,"radius":16.0,"rect":Rect2(pixel-Vector2.ONE*16,Vector2.ONE*32)}
		if not emphasized or host.clean_observation.active: continue
		var depth: float = (point-camera.global_position).dot(-camera.global_basis.z)
		var units: float = 2.0*depth*tan(deg_to_rad(camera.fov)*.5)/maxf(1,float(stage.viewport.size.y))
		entry.label.pixel_size = units
		# The name is a read-only caption; the geographic area is the hit target.
		entry.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.label.position = point+camera.global_basis.y*units*25*host.ui_scale
		entry.label.visible = not _blocked(camera.unproject_position(entry.label.position))

func surface_coordinate(pixel: Vector2) -> Vector2:
	var stage: Node = host.coordinator.active_scene
	var camera: Camera3D = stage.camera
	var origin: Vector3 = stage.world_root.to_local(camera.project_ray_origin(pixel))
	var ray: Vector3 = (stage.world_root.global_basis.inverse()*camera.project_ray_normal(pixel)).normalized()
	var b: float = origin.dot(ray)
	var discriminant: float = b*b-origin.length_squared()+SURFACE_RADIUS*SURFACE_RADIUS
	if discriminant<0.0: return Vector2(INF,INF)
	var distance: float = -b-sqrt(discriminant)
	if distance<=0.0: return Vector2(INF,INF)
	var point: Vector3 = (origin+ray*distance).normalized()
	return Vector2(rad_to_deg(atan2(point.x,point.z)),rad_to_deg(asin(clampf(point.y,-1,1))))

func pick(pixel: Vector2) -> String:
	refresh_points()
	var physical: Vector2=host.get_viewport().get_visible_rect().size
	if not available() or _blocked(pixel) or not Rect2(Vector2(12,80)*host.ui_scale,physical-Vector2(24,168)*host.ui_scale).has_point(pixel): return ""
	var coordinate: Vector2 = surface_coordinate(pixel)
	if not coordinate.is_finite(): return ""
	for id: String in ORDER:
		var site: Dictionary = Sites.for_scale(id)
		var offset: Vector2 = Vector2(wrapf(coordinate.x-float(site.lon),-180,180),coordinate.y-float(site.lat))
		if Geometry2D.is_point_in_polygon(offset,PackedVector2Array(AREAS[id])): return id
	return ""

func pointer(event: InputEvent) -> bool:
	if not available(): armed = false; return false
	if event is InputEventMouseMotion:
		if event.button_mask==0: armed = false
		if armed and event.position.distance_to(pressed_at)>DRAG_DISTANCE: dragged = true
		if event.button_mask!=0: return armed and not dragged and event.button_mask==MOUSE_BUTTON_MASK_LEFT
		hovered = pick(event.position); return false
	if not event is InputEventMouseButton: return false
	if event.button_index!=MOUSE_BUTTON_LEFT or event.shift_pressed: return false
	if event.pressed:
		pressed_at = event.position; pressed_id = pick(event.position); armed = true; dragged = false
	else:
		var click: bool = armed and not dragged and event.position.distance_to(pressed_at)<=DRAG_DISTANCE
		armed = false
		if click:
			var id: String = pick(event.position)
			if id.is_empty(): clear_selection()
			elif id==pressed_id:
				if id==selected: enter_selected()
				else: select_region(id)
	return true

func _process(_delta: float) -> void:
	if host!=null: refresh_points()
