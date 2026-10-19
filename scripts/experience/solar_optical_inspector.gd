extends PanelContainer
const I18n = preload("res://scripts/core/app_text.gd")
## One small, on-demand optical rendering of the selected existing body. Meshes
## and textures are shared, poses/materials are read from the authoritative scene.
## This World3D is a render sandbox only: no simulation, animation player or clock.
const UI = preload("res://scripts/experience/interface_theme.gd")
const Closeup = preload("res://scripts/experience/solar_closeup.gd")
var host: Node
var choice: Dictionary = {}
var bearing_choice: Dictionary = {}
var bearing_anchor: Vector2
var keep_alive: float = 0.0
var cooldown: float = 0.0
var source_stage: Node
var sources: Array[MeshInstance3D] = []
var proxies: Array[MeshInstance3D] = []
var uniform_names: Array[Array] = []
var lens: SubViewport
var lens_root: Node3D
var lens_camera: Camera3D
var lens_environment: WorldEnvironment
var picture: TextureRect
var caption: Label
var detail: Label
var fly_button: Button
var frame_button: Button
var sampled_jd: float = -INF
var sampled_basis: Basis
var sampled_direction: Vector3 = Vector3.INF
var render_count: int = 0
var popup_anchor: Vector2

func configure(experience: Node) -> void:
	host=experience; name="SolarOpticalInspector"
	add_theme_stylebox_override("panel",UI.surface(Color(.025,.035,.048,.98),12,14))
	custom_minimum_size=Vector2(238,0)
	var column: VBoxContainer=VBoxContainer.new(); column.add_theme_constant_override("separation",8); add_child(column)
	caption=host._label("",20); caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(caption)
	picture=TextureRect.new(); picture.custom_minimum_size=Vector2(210,158)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_child(picture)
	detail=host._label(I18n.text("光学放大 · 同一时刻与视向"),14); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(detail)
	fly_button=host._button(I18n.text("飞近观察"),fly); column.add_child(fly_button)
	frame_button=host._button(I18n.text("与卫星同框"),frame_pair); column.add_child(frame_button)
	hide()

func available() -> bool:
	if not is_instance_valid(host) or not is_instance_valid(host.coordinator.active_scene): return false
	var stage: Node=host.coordinator.active_scene
	return host.world.foreground and not host.coordinator.is_busy() and (stage.scale_id=="solar_system" and int(stage.get_meta("solar_physical",{}).get("owner",-1))>=0 or stage.scale_id=="earth_moon" or stage.has_meta("natural_satellites")) and not host.world_guide.visible and not host.size_comparison.visible and not host.info_panel.visible and not host.explorer_panel.visible and not host.observation_panel.visible and not host.guided_journey.visible and not host.clean_observation.active

func bearing_enter(item: Dictionary, anchor: Vector2) -> void:
	bearing_choice=item; bearing_anchor=anchor; keep_alive=.35
	if available(): present(item,anchor)

func bearing_exit() -> void:
	bearing_choice={}; keep_alive=.35

func dismiss() -> void:
	hide(); choice={}; bearing_choice={}; keep_alive=0.0
	if is_instance_valid(lens): lens.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _process(delta: float) -> void:
	if not available(): dismiss(); return
	if source_stage!=null and source_stage!=host.coordinator.active_scene: dismiss(); source_stage=null
	var pointer: Vector2=get_global_mouse_position()
	var item: Dictionary=host.object_pointer.hovered
	if not bearing_choice.is_empty():
		present(bearing_choice,bearing_anchor)
	elif not item.is_empty() and item.get("node") is MeshInstance3D and item.node.mesh is SphereMesh:
		# The main subject already has a full-size view. Keep its surface clear.
		if item.node!=Closeup.subject(host): present(item,pointer/host.ui_scale)
		elif not get_global_rect().grow(14.0).has_point(pointer): dismiss()
	elif visible and get_global_rect().grow(14.0).has_point(pointer): keep_alive=.35
	else:
		keep_alive-=delta
		if keep_alive<=0.0: dismiss(); return
	if not visible: return
	fit_popup()
	host.object_pointer.tooltip.hide()
	cooldown-=delta
	if cooldown<=0.0:
		cooldown=.1
		update_optics()

func present(item: Dictionary, anchor: Vector2) -> void:
	if not is_instance_valid(item.get("node")) or not item.node.mesh is SphereMesh: return
	if float(item.node.mesh.radius)<=0.0: return
	var same: bool=visible and choice.get("node")==item.node and source_stage==host.coordinator.active_scene
	choice=item.duplicate(); source_stage=host.coordinator.active_scene
	keep_alive=.35
	if not same:
		popup_anchor=anchor
		build_proxy()
		caption.text=I18n.text(str(item.get("label",item.node.name)))
		var selected: MeshInstance3D=Closeup.subject(host)
		fly_button.visible=selected!=item.node
		var owner: int=int(item.get("planet",item.get("host_planet",2 if bool(item.get("moon",false)) else -1)))
		frame_button.visible=(source_stage.scale_id=="solar_system" and owner>=2 and owner==int(source_stage.get_meta("solar_physical",{}).get("owner",-2))) or source_stage.has_meta("natural_satellites") or source_stage.scale_id=="earth_moon"
		frame_button.text=I18n.text(I18n.text("与行星同框") if item.has("satellite_key") or bool(item.get("moon",false)) else I18n.text("与卫星同框"))
		show(); reset_size(); sampled_jd=-INF; update_optics()
		fit_popup.call_deferred()

func fit_popup() -> void:
	# Wrapped labels settle their minimum height after the container has width.
	# Shrink again then, rather than retaining the initial one-letter-per-line box.
	size=Vector2(238.0,get_combined_minimum_size().y)
	var bounds: Vector2=Vector2(host.ui_view_size())
	var left: float=popup_anchor.x+22.0
	if left+size.x>bounds.x-16.0: left=popup_anchor.x-size.x-22.0
	position=Vector2(clampf(left,12.0,maxf(12.0,bounds.x-size.x-12.0)),clampf(popup_anchor.y-55.0,88.0,maxf(88.0,bounds.y-size.y-32.0)))

func _ensure_lens() -> void:
	if is_instance_valid(lens): return
	lens=SubViewport.new(); lens.name="OpticalRenderOnly"
	lens.size=Vector2i(256,192); lens.own_world_3d=true
	lens.render_target_update_mode=SubViewport.UPDATE_DISABLED
	lens.msaa_3d=Viewport.MSAA_2X; lens.positional_shadow_atlas_size=0
	add_child(lens)
	lens_root=Node3D.new(); lens.add_child(lens_root)
	lens_camera=Camera3D.new(); lens_root.add_child(lens_camera); lens_camera.current=true
	lens_environment=WorldEnvironment.new(); lens_root.add_child(lens_environment)
	picture.texture=lens.get_texture()

func build_proxy() -> void:
	_ensure_lens()
	for proxy: MeshInstance3D in proxies: proxy.free()
	proxies.clear(); sources.clear(); uniform_names.clear()
	var body: MeshInstance3D=choice.node
	sources.append(body)
	if choice.has("planet") and source_stage.scale_id=="solar_system":
		for extra: MeshInstance3D in source_stage.get_meta("solar_bodies")[int(choice.planet)].extras: sources.append(extra)
	elif source_stage.has_meta("natural_satellites") and int(choice.get("index",-1))==0:
		var system: Dictionary=source_stage.get_meta("natural_satellites")
		if is_instance_valid(system.get("rings")): sources.append(system.rings)
	for source: MeshInstance3D in sources:
		var proxy: MeshInstance3D=MeshInstance3D.new()
		proxy.name="Optical_"+str(source.name); proxy.mesh=source.mesh
		proxy.material_override=source.material_override.duplicate(false)
		proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens_root.add_child(proxy); proxies.append(proxy)
		var names: Array=[]
		if proxy.material_override is ShaderMaterial:
			for uniform: Dictionary in proxy.material_override.shader.get_shader_uniform_list(): names.append(str(uniform.name))
		uniform_names.append(names)
	var environment: Environment=source_stage.environment.duplicate(false)
	environment.background_mode=Environment.BG_COLOR; environment.background_color=Color(.014,.02,.029)
	environment.glow_enabled=false; environment.volumetric_fog_enabled=false
	lens_environment.environment=environment

func update_optics() -> void:
	if choice.is_empty() or not is_instance_valid(choice.get("node")) or not is_instance_valid(source_stage): dismiss(); return
	var body: MeshInstance3D=choice.node
	var direction: Vector3=(source_stage.camera.global_position-body.global_position).normalized()
	if host.solar_jd==sampled_jd and body.global_basis.is_equal_approx(sampled_basis) and direction.is_equal_approx(sampled_direction): return
	var unit: float=maxf(.000000001,body.global_basis.get_scale().x)
	var radius: float=float(body.mesh.radius)
	for index: int in range(proxies.size()):
		var source: MeshInstance3D=sources[index]
		var proxy: MeshInstance3D=proxies[index]
		proxy.basis=source.global_basis.scaled(Vector3.ONE/unit)
		proxy.position=(source.global_position-body.global_position)/unit
		var material: ShaderMaterial=proxy.material_override as ShaderMaterial
		var original: ShaderMaterial=source.material_override as ShaderMaterial
		if material!=null and original!=null:
			for field: String in uniform_names[index]: material.set_shader_parameter(field,original.get_shader_parameter(field))
			for field: String in ["planet_center","body_center","eclipse_display_center"]:
				if field in uniform_names[index]: material.set_shader_parameter(field,Vector3.ZERO)
			if "eclipse_km_per_unit" in uniform_names[index]: material.set_shader_parameter("eclipse_km_per_unit",float(original.get_shader_parameter("eclipse_km_per_unit"))*unit)
			if "planet_radius" in uniform_names[index]: material.set_shader_parameter("planet_radius",radius)
			if "atmosphere_radius" in uniform_names[index]: material.set_shader_parameter("atmosphere_radius",float(source.mesh.radius))
			if "km_per_unit" in uniform_names[index]: material.set_shader_parameter("km_per_unit",host.Ephemeris.RADII_KM[2]/radius)
			if "ring_inner" in uniform_names[index] and int(choice.get("planet",-1))==5:
				material.set_shader_parameter("ring_inner",radius*1.24); material.set_shader_parameter("ring_outer",radius*2.25)
	var rings: bool=int(choice.get("planet",-1))==5 or (source_stage.has_meta("natural_satellites") and int(source_stage.get_meta("natural_satellites").index)==5 and int(choice.get("index",-1))==0)
	var bound: float=radius*(2.25 if rings else 1.04)
	lens_camera.fov=32.0
	lens_camera.near=maxf(.00001,radius*.04); lens_camera.far=maxf(1.0,bound*30.0)
	lens_camera.position=direction*bound/ sin(deg_to_rad(lens_camera.fov*.5)) *1.08
	var up: Vector3=source_stage.camera.global_basis.y
	if absf(direction.dot(up))>.98: up=Vector3.RIGHT if absf(direction.x)<.9 else Vector3.UP
	lens_camera.look_at(Vector3.ZERO,up)
	var hidden: bool=host.SolarContextCompass.choice_occluded(source_stage,body)
	detail.text=I18n.text(I18n.text("独立放大 · 主视野中被遮挡") if hidden else I18n.text("光学放大 · 同一时刻与视向"))
	sampled_jd=host.solar_jd; sampled_basis=body.global_basis; sampled_direction=direction
	lens.render_target_update_mode=SubViewport.UPDATE_ONCE; render_count+=1

func fly() -> void:
	var selected: Dictionary=choice.duplicate(); dismiss()
	Closeup.choose(host,selected)

func frame_pair() -> void:
	var selected: Dictionary=choice.duplicate(); dismiss()
	var stage: Node=host.coordinator.active_scene
	var owner: int=int(selected.get("planet",selected.get("host_planet",stage.get_meta("natural_satellites",{}).get("index",2))))
	host.frame_satellite_system(owner,str(selected.get("satellite_key","")))
