extends Control
## Read-only scale illustration. Owns no world state, date or orbit positions.
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const SUN_RADIUS_KM: float = 695700.0 # IAU 2015 B3 nominal conversion constant.
const PLANET_SOURCE: String = "https://ssd.jpl.nasa.gov/planets/phys_par.html"
const SUN_SOURCE: String = "https://www.iau.org/common/Uploaded%20files/IAUGA2015-Resolution-B3-recommended-nominal-conversion.pdf"
const COLOURS: Array[Color] = [Color(.54,.49,.43),Color(.88,.72,.44),Color(.14,.48,.78),Color(.77,.30,.12),Color(.81,.65,.45),Color(.84,.75,.53),Color(.42,.79,.84),Color(.18,.33,.79),Color(1.,.64,.13)]
var host: Node
var panel: PanelContainer
var picker: OptionButton
var ratio_text: Label
var boundary_text: Label
var viewport_container: SubViewportContainer
var viewport: SubViewport
var camera: Camera3D
var bodies: Array[MeshInstance3D] = []
var captions: Array[Label3D] = []
var selected: int = 4
var close_button: Button

static func radius_km(index: int) -> float:
	return SUN_RADIUS_KM if index==8 else Ephemeris.RADII_KM[index]

func configure(experience: Node, style: StyleBoxFlat) -> void:
	host=experience
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade: ColorRect=ColorRect.new()
	shade.color=Color(.018,.023,.031,.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	panel=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",style.duplicate())
	add_child(panel)
	var rows: VBoxContainer=VBoxContainer.new()
	rows.add_theme_constant_override("separation",12)
	var page_scroll: ScrollContainer=ScrollContainer.new()
	page_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(page_scroll)
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical=Control.SIZE_EXPAND_FILL
	page_scroll.add_child(rows)
	var heading: HBoxContainer=HBoxContainer.new()
	rows.add_child(heading)
	var title: Label=host._label("天体大小 · 同一比例",26)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button=host.InterfaceTheme.icon("close","返回观察 · Esc",close)
	heading.add_child(close_button)
	var controls: HBoxContainer=HBoxContainer.new()
	controls.add_theme_constant_override("separation",12)
	rows.add_child(controls)
	controls.add_child(host._label("对照天体",16))
	picker=OptionButton.new()
	picker.custom_minimum_size=Vector2(150,38)
	for label: String in Ephemeris.NAMES: picker.add_item(label)
	picker.add_item("太阳（名义半径）")
	picker.item_selected.connect(select_body)
	controls.add_child(picker)
	controls.add_child(host._label("参照：地球平均半径",15,Color(.60,.66,.72)))
	ratio_text=host._label("",18,Color(.85,.90,.92))
	ratio_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(ratio_text)
	viewport_container=SubViewportContainer.new()
	viewport_container.stretch=true
	viewport_container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport_container.size_flags_vertical=Control.SIZE_EXPAND_FILL
	viewport_container.custom_minimum_size.y=210
	rows.add_child(viewport_container)
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport_container.add_child(viewport)
	_build_geometry()
	boundary_text=host._label("",13,Color(.70,.82,.87))
	boundary_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(boundary_text)
	var sources: HFlowContainer=HFlowContainer.new()
	rows.add_child(sources)
	for entry: Array in [["JPL · 行星平均半径 ↗",PLANET_SOURCE],["IAU · 太阳名义半径 ↗",SUN_SOURCE]]:
		var link: LinkButton=LinkButton.new()
		link.text=entry[0]
		link.pressed.connect(OS.shell_open.bind(str(entry[1])))
		sources.add_child(link)
	visibility_changed.connect(func() -> void:
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED)
	fit_window(host.ui_view_size())
	select_body(selected)
	hide()

func _build_geometry() -> void:
	var environment: WorldEnvironment=WorldEnvironment.new()
	var settings: Environment=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color(.023,.029,.038)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color(.70,.81,.94)
	settings.ambient_light_energy=.65
	environment.environment=settings
	viewport.add_child(environment)
	var light: DirectionalLight3D=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-30,0)
	light.light_energy=1.25
	viewport.add_child(light)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=5.6
	camera.position=Vector3(0,0,10)
	viewport.add_child(camera)
	camera.current=true
	var sphere: SphereMesh=SphereMesh.new()
	sphere.radius=1.0
	sphere.height=2.0
	sphere.radial_segments=96
	sphere.rings=48
	for i: int in range(2):
		var body: MeshInstance3D=MeshInstance3D.new()
		body.mesh=sphere
		var material: StandardMaterial3D=StandardMaterial3D.new()
		material.roughness=.62
		body.material_override=material
		viewport.add_child(body)
		bodies.append(body)
		var caption: Label3D=Label3D.new()
		var font: SystemFont=SystemFont.new()
		font.font_names=PackedStringArray(["PingFang SC","Arial"])
		caption.font=font
		caption.font_size=48
		caption.pixel_size=.0045
		caption.position=Vector3(-2.2 if i==0 else 2.2,-2.1,.05)
		caption.modulate=Color(.78,.90,.96)
		viewport.add_child(caption)
		captions.append(caption)
	var baseline: MeshInstance3D=MeshInstance3D.new()
	var mesh: BoxMesh=BoxMesh.new()
	mesh.size=Vector3(8.2,.012,.012)
	baseline.mesh=mesh
	baseline.position=Vector3(0,-1.7,0)
	var material: StandardMaterial3D=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(.22,.42,.48)
	baseline.material_override=material
	viewport.add_child(baseline)

func select_body(index: int) -> void:
	if index<0 or index>8: return
	selected=index
	picker.select(index)
	var physical: Array[float]=[radius_km(index),radius_km(2)]
	var km_per_unit: float=maxf(physical[0],physical[1])/1.7
	var names: Array[String]=["太阳" if index==8 else Ephemeris.NAMES[index],"地球"]
	for i: int in range(2):
		var size: float=physical[i]/km_per_unit
		bodies[i].scale=Vector3.ONE*size
		bodies[i].position=Vector3(-2.2 if i==0 else 2.2,-1.7+size,0)
		bodies[i].material_override.albedo_color=COLOURS[index if i==0 else 2]
		captions[i].text="%s\n半径 %s km" % [names[i],str(physical[i])]
	ratio_text.text="%s的直径约为地球的 %.3f 倍" % [names[0],physical[0]/physical[1]]
	boundary_text.text="两球使用同一比例和正交视角；间距只是排布，不代表轨道距离。颜色仅作区分；行星用平均半径球体，不含扁率、星环或大气。"
	if index==8: boundary_text.text+="太阳采用IAU名义半径这一换算常数，不是精确实测太阳边界。"
	set_meta("km_per_unit",km_per_unit)

func fit_window(window_size: Vector2i) -> void:
	var width: float=minf(1120.,float(window_size.x)-48.)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=(window_size.x-width)*.5
	panel.offset_right=-panel.offset_left
	panel.offset_top=24
	panel.offset_bottom=-24

func _process(_delta: float) -> void:
	if visible and viewport_container.size.y>0:
		camera.size=maxf(5.6,9.0/(viewport_container.size.x/viewport_container.size.y))

func open() -> void:
	get_parent().move_child(self,-1)
	show()
	close_button.grab_focus()

func close() -> void:
	hide()
	if is_instance_valid(host.explorer_panel): host.explorer_panel.size_compare_button.grab_focus()
