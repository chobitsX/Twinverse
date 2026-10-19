extends Node
## Stage-owned cloud integration target. Shares its World3D and authority camera.
## Linear HDR is composited before the main viewport's single tone-map pass.

const COMPOSITE: Shader = preload("res://shaders/cloud_composite.gdshader")
const CLOUD_LAYER: int = 1 << 19
const RESOLUTION_RATIO: float = 0.25

var viewport: SubViewport
var camera: Camera3D
var source_camera: Camera3D
var resolution_ratio: float = RESOLUTION_RATIO

func configure(stage: Node, volume: MeshInstance3D, ratio: float = RESOLUTION_RATIO, pass_name: String = "Cloud", priority: int = 30) -> void:
	resolution_ratio = ratio
	source_camera = stage.camera
	volume.layers = CLOUD_LAYER
	source_camera.cull_mask &= ~CLOUD_LAYER
	viewport = SubViewport.new()
	viewport.name = pass_name + "IntegrationViewport"
	viewport.world_3d = stage.viewport.find_world_3d()
	viewport.transparent_bg = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.gui_disable_input = true
	add_child(viewport)
	camera = Camera3D.new()
	camera.cull_mask = CLOUD_LAYER
	# The volume shader supplies its own sunlight and camera-to-cloud air.
	# No background, fog, exposure, glow or ACES may be applied a second time.
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	camera.environment = environment
	viewport.add_child(camera)
	camera.current = true
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = COMPOSITE
	material.render_priority = priority
	material.set_shader_parameter("cloud_texture", viewport.get_texture())
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(2, 2)
	var composite: MeshInstance3D = MeshInstance3D.new()
	composite.name = pass_name + "Composite"
	composite.mesh = mesh
	composite.material_override = material
	composite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	composite.extra_cull_margin = 16384.0
	source_camera.add_child(composite)
	resize(stage.viewport.size, stage.render_scale)
	sync_camera()
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)

func resize(output_size: Vector2i, render_scale: float) -> void:
	var size: Vector2i = Vector2i(Vector2(output_size) * render_scale * resolution_ratio)
	viewport.size = Vector2i(maxi(size.x, 8), maxi(size.y, 8))

func sync_camera() -> void:
	camera.global_transform = source_camera.global_transform
	camera.projection = source_camera.projection
	camera.fov = source_camera.fov
	camera.near = source_camera.near
	camera.far = source_camera.far
	camera.keep_aspect = source_camera.keep_aspect
	camera.frustum_offset = source_camera.frustum_offset
	camera.h_offset = source_camera.h_offset
	camera.v_offset = source_camera.v_offset
