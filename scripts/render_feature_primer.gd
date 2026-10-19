extends Node
const I18n = preload("res://scripts/core/app_text.gd")
## Register the sample's render features before loading its large model library.
## No world state, asset cache or parallel simulation belongs to this startup node.


func prepare() -> void:
	if DisplayServer.get_name() == "headless": return
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.018, 0.028, 0.05)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var label: Label = Label.new()
	label.text = I18n.text("正在准备世界")
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0.74, 0.84, 0.91)
	center.add_child(label)
	await RenderingServer.frame_post_draw
	var viewport: SubViewport = SubViewport.new()
	# SSAO's depth mip chain needs a real minimum size; a16px primer is invalid.
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 0, 3)
	viewport.add_child(camera)
	camera.current = true
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ssao_enabled = true
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.01
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(1, 1, 2)
	light.shadow_enabled = true
	light.omni_range = 8.0
	viewport.add_child(light)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.subsurf_scatter_enabled = true
	material.subsurf_scatter_strength = 0.1
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material
	var specimen: MeshInstance3D = MeshInstance3D.new()
	specimen.mesh = mesh
	viewport.add_child(specimen)
	await RenderingServer.frame_post_draw
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	print("RENDER_FEATURES_PRIMED ", JSON.stringify({"viewport_px": [128, 128], "msaa": 4,
		"features": ["normal_roughness", "separate_specular", "omni_shadow_cubemap", "volumetric_fog"]}))
	# Keep the loading overlay while the first real scale is being constructed.
