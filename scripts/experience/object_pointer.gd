extends Control
const I18n = preload("res://scripts/core/app_text.gd")
## Pointer access to existing observation targets. No physics world or render pass.
const SUPPORTED: Array[String] = ["mars_moons","saturn_moons","uranus_moons","neptune_moons","night_sky","universe","galaxy","solar_system","atmosphere","earth_moon","jupiter_moons","reef","school","fish","heart","cardiomyocyte","mitochondrion","molecule","pacific","woodland","city","desert","polar"]
const DRAG_DISTANCE: float = 6.0
const HOVER_INTERVAL: float = .16
var host: Node
var stage: Node
var choices: Dictionary = {}
var surfaces: Array[Dictionary] = []
var batches: Array[MultiMeshInstance3D] = []
var selectable_batches: Array[MultiMeshInstance3D] = []
var triangles: Dictionary = {}
var hovered: Dictionary = {}
var cursor: Vector2 = Vector2.ZERO
var pending: bool = false
var cooldown: float = 0.0
var pressed_at: Vector2 = Vector2.ZERO
var armed: bool = false
var dragged: bool = false
var tooltip: Label
var hover_node_position: Vector3
var hover_camera: Transform3D
var last_choice: Dictionary = {}
var last_click: Vector2
var last_click_operated: bool = false

func configure(experience: Node) -> void:
	host=experience
	theme=host.hud.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	tooltip=host._label("",14)
	tooltip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat=StyleBoxFlat.new()
	style.bg_color=Color(.055,.067,.084,.96)
	style.border_color=Color(.76,.83,.90,.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left=12; style.content_margin_right=12
	style.content_margin_top=8; style.content_margin_bottom=8
	tooltip.add_theme_stylebox_override("normal",style)
	add_child(tooltip)
	tooltip.hide()
	fit_ui_scale()

func fit_ui_scale() -> void:
	# The pointer stays in camera pixels; its caption is rendered in logical points.
	if not is_instance_valid(tooltip): return
	tooltip.scale=Vector2.ONE*host.ui_scale

func available() -> bool:
	return is_instance_valid(host.coordinator.active_scene) and host.world.current_scale_id in SUPPORTED and not host.coordinator.is_busy() and host.world.foreground and not host.world_guide.visible and not host.size_comparison.visible

func clear_hover() -> void:
	# pick() returns a registry entry. Drop the view reference, not its contents.
	hovered={}
	if is_instance_valid(tooltip): tooltip.hide()
	queue_redraw()

func pointer(event: InputEvent) -> bool:
	if not available():
		armed=false; clear_hover(); return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.shift_pressed:
		armed=false; clear_hover(); return false
	if event is InputEventMouseMotion:
		cursor=event.position
		if event.button_mask==0: armed=false
		if armed and cursor.distance_to(pressed_at)>DRAG_DISTANCE: dragged=true
		if event.button_mask!=0:
			clear_hover()
			return armed and not dragged and event.button_mask==MOUSE_BUTTON_MASK_LEFT
		pending=true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			# The first click can move the camera. Resolve the second half against
			# that same object, not whatever is now behind the original pixel.
			if event.double_click and stage==host.coordinator.active_scene and not last_choice.is_empty() and event.position.distance_to(last_click)<=DRAG_DISTANCE:
				armed=false; clear_hover()
				if not last_choice.has("action") or not last_click_operated: enter_choice(last_choice)
				last_click_operated=last_choice.has("action")
				return true
			pressed_at=event.position; armed=true; dragged=false
			clear_hover()
		else:
			var click: bool=armed and not dragged and event.position.distance_to(pressed_at)<=DRAG_DISTANCE
			armed=false
			if click: activate(event.position)
		return true
	return false

func _process(delta: float) -> void:
	if host==null: return
	if not surfaces.is_empty() and (not is_instance_valid(stage) or stage!=host.coordinator.active_scene):
		clear_index()
	cooldown=maxf(0.,cooldown-delta)
	if not available() or get_viewport().gui_get_hovered_control()!=null:
		clear_hover(); pending=false; return
	if armed: return
	# Recheck a moving hovered body at the same bounded interval. An untouched
	# static scene needs no further queries, and empty hover stays idle.
	if not pending:
		if not hovered.is_empty() and (not is_instance_valid(hovered.node) or not hovered.node.global_position.is_equal_approx(hover_node_position) or not host.coordinator.active_scene.camera.global_transform.is_equal_approx(hover_camera)):
			pending=true
		else: return
	if cooldown>0.: return
	pending=false; cooldown=HOVER_INTERVAL
	hovered=pick(cursor)
	tooltip.visible=not hovered.is_empty() and (not host.clean_observation.active or host.world.current_scale_id in ["solar_system","night_sky"])
	if tooltip.visible:
		hover_node_position=hovered.node.global_position
		hover_camera=stage.camera.global_transform
		tooltip.text=I18n.text(str(hovered.label) if host.world.current_scale_id in ["solar_system","night_sky"] else str(hovered.label)+I18n.text("\n点击近看 · ")+host.spatial_hint(hovered))
		tooltip.reset_size()
		var gap: float=12*host.ui_scale
		var dimensions: Vector2=tooltip.size*host.ui_scale
		tooltip.position=Vector2(clampf(cursor.x+18*host.ui_scale,gap,maxf(gap,size.x-dimensions.x-gap)),clampf(cursor.y+20*host.ui_scale,gap,maxf(gap,size.y-dimensions.y-gap)))
	queue_redraw()

func enter_choice(choice: Dictionary) -> void:
	if not available(): return
	host.enter_spatial_choice(choice)

func _draw() -> void:
	pass # The OS pointer and concise caption provide feedback without a reticle.

func activate(point: Vector2) -> void:
	var choice: Dictionary=pick(point)
	last_choice=choice; last_click=point; last_click_operated=false
	clear_hover()
	if choice.is_empty():
		host._clear_observation_selection()
		return
	# A first click frames the experiment; subsequent physical control clicks
	# operate the existing world state without resetting the user's camera.
	if choice.has("action") and host._content_follow==int(choice.index) and host.learning_overlay.topic==str(choice.topic):
		host._direct_content=choice.duplicate()
		host.perform_spatial_action(str(choice.action))
		last_click_operated=true
		return
	host.explorer_panel.hide()
	host.explorer_panel.clear_topic()
	if choice.has("region"): stage.builder.select_region(stage, str(choice.region))
	if choice.has("planet"):
		host.follow_planet(int(choice.planet),host.SatelliteFraming.is_pair(stage) and int(host.SatelliteFraming.state(stage).owner)==int(choice.planet))
	else:
		host.follow_content(int(choice.index)+1,choice)
	if choice.has("topic"):
		host.learning_overlay.select(str(choice.topic))
		host.message_label.text=I18n.text(I18n.text("正在观察 · ")+str(choice.label)+" · "+str(choice.get("spatial_hint",host.spatial_hint(choice))))
		return
	host.message_label.text=I18n.text("" if host.SatelliteFraming.is_pair(stage) else I18n.text("正在观察 · ")+str(choice.label)+" · "+host.spatial_hint(choice))

func clear_index() -> void:
	stage=null; choices.clear(); surfaces.clear(); batches.clear(); selectable_batches.clear(); triangles.clear()
	last_choice={}; last_click_operated=false
	clear_hover()

func rebuild(current: Node) -> void:
	clear_index(); stage=current
	if stage.scale_id=="night_sky": return # Directional picking; no terrain triangle cache.
	if stage.has_meta("solar_bodies"):
		var bodies: Array=stage.get_meta("solar_bodies")
		var targets: Array[Dictionary]=host.content_targets(false)
		for i: int in range(targets.size()):
			var item: Dictionary=targets[i].duplicate()
			item.index=i
			choices[item.node.get_instance_id()]=item
			for alias: Node3D in item.get("pick_nodes",[]): choices[alias.get_instance_id()]=item
		for i: int in range(bodies.size()):
			var destination: String = host.spatial_destination({"planet":i})
			choices[bodies[i].node.get_instance_id()]={"node":bodies[i].node,"label":I18n.strings(host.Ephemeris.NAMES)[i],"planet":i,"destination":destination,"primary":not destination.is_empty()}
			for alias: Node3D in bodies[i].get("pick_nodes",[]): choices[alias.get_instance_id()]=choices[bodies[i].node.get_instance_id()]
	else:
		var targets: Array[Dictionary]=host.content_targets(false)
		for i: int in range(targets.size()):
			var item: Dictionary=targets[i].duplicate()
			item.index=i
			if not choices.has(item.node.get_instance_id()): choices[item.node.get_instance_id()]=item
			if is_instance_valid(item.get("cutaway_node")): choices[item.cutaway_node.get_instance_id()]=item
			for alias: Node3D in item.get("pick_nodes",[]):
				choices[alias.get_instance_id()]=item
		for control: Dictionary in stage.get_meta("spatial_controls",[]):
			var observer: Dictionary = choices.get(control.observer.get_instance_id(),{})
			if observer.is_empty(): continue
			var item: Dictionary = observer.duplicate()
			item.merge(control,true)
			# The camera follows the original comparison anchor; picking still
			# intersects the control's actual visible mesh descendants.
			item.node=control.observer
			choices[control.node.get_instance_id()]=item
		if stage.scale_id == "cardiomyocyte" and not targets.is_empty():
			for node: Node in stage.world_root.find_children("SelectedMito*", "MeshInstance3D", true, false):
				var item: Dictionary = targets[0].duplicate()
				item.index = 0
				choices[node.get_instance_id()] = item
		# Keep the menu's representative slots but follow the clicked individual.
		for key: String in ["actors","marine_actors"]:
			var actors: Array=stage.get_meta(key,[])
			var by_kind: Dictionary={}
			for actor: Dictionary in actors:
				if choices.has(actor.node.get_instance_id()): by_kind[actor.kind]=choices[actor.node.get_instance_id()]
			for actor: Dictionary in actors:
				if not by_kind.has(actor.kind): continue
				var item: Dictionary=by_kind[actor.kind].duplicate()
				item.node=actor.node
				item.label=actor.label
				choices[actor.node.get_instance_id()]=item
		# The moving third penguin uses an independent body-center observer.
		# Its actual mesh ancestors must select that same existing observer.
		if stage.scale_id=="polar" and stage.has_meta("polar"):
			var polar: Dictionary=stage.get_meta("polar")
			if polar.has("activity_focus"):
				var focus: Node3D=polar.activity_focus
				var penguin: Node3D=polar.birds[2]
				var entry: Dictionary=choices.get(focus.get_instance_id(),{})
				if not entry.is_empty(): choices[penguin.get_instance_id()]=entry
		# All near buildings share the existing architectural observation slots.
		if stage.scale_id=="city":
			for building: Node in stage.world_root.find_children("CityBuilding_*","Node3D",true,false):
				var category: int=building.get_meta("architecture_category",1)
				for i: int in range(targets.size()):
					if targets[i].node.has_meta("architecture_category") and int(targets[i].node.get_meta("architecture_category"))==(0 if category==0 else 1):
						var item: Dictionary=targets[i].duplicate()
						item.node=building; item.index=i
						item.label=[I18n.text("临街商铺 · 建筑观察"),I18n.text("住宅 · 建筑观察"),I18n.text("办公楼 · 建筑观察")][category]
						if category==2: item.view_offset=Vector3(-25,16,28); item.focus_height=12.
						choices[building.get_instance_id()]=item
						break
	# Static, CPU-positioned references may opt into actual triangles. Their
	# colony-wide bounds would otherwise hide attached millimetre structures.
	for node: Node in stage.world_root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D=node as MeshInstance3D
		if mesh.mesh==null: continue
		var owner_choice: Dictionary={}
		var ancestor: Node=mesh
		while ancestor!=null and ancestor!=stage.world_root:
			if choices.has(ancestor.get_instance_id()):
				owner_choice=choices[ancestor.get_instance_id()]; break
			ancestor=ancestor.get_parent()
		surfaces.append({"node":mesh,"choice":owner_choice,"bounds":mesh.mesh.get_aabb(),"opaque":opaque(mesh),"animated":mesh.skin!=null or not owner_choice.is_empty() and not owner_choice.has("planet") and stage.scale_id in ["reef","school","fish","pacific"] and not bool(owner_choice.get("precise_pick",false))})
	for node: Node in stage.world_root.find_children("*","MultiMeshInstance3D",true,false):
		if node.name=="ContextBuildings": batches.append(node)
		elif choices.has(node.get_instance_id()): selectable_batches.append(node)

static func opaque(mesh: MeshInstance3D) -> bool:
	if mesh.transparency>.05: return false
	for i: int in range(mesh.mesh.get_surface_count()):
		var material: Material=mesh.get_active_material(i)
		if material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: return false
		if material is ShaderMaterial and material.shader!=null and material.shader.code.contains("ALPHA"): return false
	return true

func pick(point: Vector2) -> Dictionary:
	if not available(): return {}
	var current: Node=host.coordinator.active_scene
	if current!=stage: rebuild(current)
	if stage.scale_id=="night_sky": return stage.builder.pick(stage,point)
	if stage.has_meta("natural_satellites") and not stage.get_meta("natural_satellites").get("valid",false): return {}
	if stage.has_meta("jovian") and not stage.get_meta("jovian").get("valid",false): return {}
	var camera: Camera3D=stage.camera
	var origin: Vector3=camera.project_ray_origin(point)
	var end: Vector3=origin+camera.project_ray_normal(point)*camera.far
	var closest: float=INF
	var selected: Dictionary={}
	for item: Dictionary in surfaces:
		if item.choice.is_empty(): continue
		var hit: Variant=surface_hit(item,origin,end)
		if hit is Vector3:
			var distance: float=origin.distance_to(hit)
			if distance<closest:
				closest=distance; selected=item.choice
	# Only the two existing O₂ symbols use selectable instancing. Density
	# decorations keep their original batches and are never expanded to actors.
	for batch: MultiMeshInstance3D in selectable_batches:
		if not batch.is_visible_in_tree(): continue
		for index: int in range(batch.multimesh.instance_count):
			var transform: Transform3D = batch.global_transform * batch.multimesh.get_instance_transform(index)
			var inverse: Transform3D = transform.affine_inverse()
			var mesh: Mesh = batch.multimesh.mesh
			if not mesh.get_aabb().intersects_segment(inverse * origin, inverse * end) is Vector3: continue
			var id: int = mesh.get_instance_id()
			if not triangles.has(id): triangles[id] = mesh.generate_triangle_mesh()
			var tree: TriangleMesh = triangles[id]
			if tree == null: continue
			var hit: Dictionary = tree.intersect_segment(inverse * origin, inverse * end)
			if hit.is_empty(): continue
			var distance: float = origin.distance_to(transform * hit.position)
			if distance < closest:
				closest = distance
				selected = choices[batch.get_instance_id()].duplicate()
				selected.focus_position = stage.world_root.to_local(transform.origin)
	if selected.is_empty(): return {}
	var limit: Vector3=origin+(end-origin).normalized()*maxf(0.,closest-.002)
	for item: Dictionary in surfaces:
		if not item.choice.is_empty() or not item.opaque: continue
		if surface_hit(item,origin,limit) is Vector3: return {}
	for batch: MultiMeshInstance3D in batches:
		if not batch.is_visible_in_tree(): continue
		var box: AABB=batch.multimesh.mesh.get_aabb()
		for i: int in range(batch.multimesh.instance_count):
			var inverse: Transform3D=(batch.global_transform*batch.multimesh.get_instance_transform(i)).affine_inverse()
			if box.intersects_segment(inverse*origin,inverse*limit) is Vector3: return {}
	return selected

func surface_hit(item: Dictionary, origin: Vector3, end: Vector3) -> Variant:
	var node: MeshInstance3D=item.node
	if not is_instance_valid(node) or not node.is_visible_in_tree() or node.transparency>.95: return null
	var inverse: Transform3D=node.global_transform.affine_inverse()
	var a: Vector3=inverse*origin
	var b: Vector3=inverse*end
	var bounds: AABB=item.bounds
	if item.animated: bounds=bounds.grow(bounds.size.length()*.035)
	var box_hit: Variant=bounds.intersects_segment(a,b)
	if not box_hit is Vector3: return null
	# Tiny, physically scaled celestial spheres can fall below TriangleMesh's
	# triangle-area tolerance. Intersect that same analytic sphere without a
	# screen-size pick enlargement or a distant segment's precision loss.
	if node.mesh is SphereMesh and (item.choice.has("satellite_key") or item.choice.has("planet") or bool(item.choice.get("moon",false))):
		var direction: Vector3=(b-a).normalized()
		var along: float=-a.dot(direction)
		var nearest: Vector3=a+direction*along
		var r: float=node.mesh.radius
		var discriminant: float=r*r-nearest.length_squared()
		if discriminant<0.0: return null
		var t: float=along-sqrt(discriminant)
		if t<0.0: t=along+sqrt(discriminant)
		return node.global_transform*(a+direction*t) if t>=0.0 and t<=(b-a).length() else null
	# Skinned/GPU-deformed actors use a forgiving bound, never bake or read back
	# animated vertices. Static geometry uses a lazily built shared triangle BVH.
	if item.animated: return node.global_transform*box_hit
	var id: int=node.mesh.get_instance_id()
	if not triangles.has(id): triangles[id]=node.mesh.generate_triangle_mesh()
	var tree: TriangleMesh=triangles[id]
	if tree==null: return null
	var hit: Dictionary=tree.intersect_segment(a,b)
	return node.global_transform*hit.position if not hit.is_empty() else null
