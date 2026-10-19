extends Node
const I18n = preload("res://scripts/core/app_text.gd")
const LifeMaterials=preload("res://scripts/experience/life_asset_motion.gd")
## Each local scale owns one World3D and its render target; state arrives from the host.

const Habitat = preload("res://scripts/core/local_habitat.gd")
const RenderQuality = preload("res://scripts/experience/render_quality.gd")

@export var asset_keys: Array[String] = []
@export var asset_scenes: Array[PackedScene] = []
@export var texture_keys: Array[String] = []
@export var texture_assets: Array[Texture2D] = []
@export var builder: Script

var scale_id: String = "reef"
var world_snapshot: Dictionary = {}
var assets: Dictionary = {}
var textures: Dictionary = {}
var viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var environment: Environment
var presentation: TextureRect
var materials: Array[ShaderMaterial] = []
var animated_nodes: Array[Dictionary] = []
var animation_players: Array[AnimationPlayer] = []
var target_position: Vector3 = Vector3.ZERO
var target_radius: float = 0.08
var default_position: Vector3 = Vector3(0, 1, 3)
var default_target: Vector3 = Vector3.ZERO
var close_position: Vector3 = Vector3(0, 0, 1)
var semantic_size_m: float = 1.0
var is_underwater: bool = false
var render_scale: float = 1.0
var reduced_motion: bool = false
var _prepared: bool = false
var _age_frames: int = 0


func bind_world(snapshot: Dictionary, new_scale: String) -> bool:
	if not snapshot.has("target_fish_id") or not snapshot.has("simulation_time_s"):
		return false
	if asset_keys.size() != asset_scenes.size() or texture_keys.size() != texture_assets.size():
		push_error("Stage resource keys do not match exported resources: " + new_scale)
		return false
	var unique: Dictionary = {}
	for key: String in asset_keys:
		if key.is_empty() or unique.has(key): return false
		unique[key] = true
	unique.clear()
	for key: String in texture_keys:
		if key.is_empty() or unique.has(key): return false
		unique[key] = true
	for resource: Resource in asset_scenes:
		if resource == null: return false
	for resource: Resource in texture_assets:
		if resource == null: return false
	world_snapshot = snapshot.duplicate(true)
	scale_id = new_scale
	return builder != null and builder.has_method("build")


func _ready() -> void:
	for i: int in range(mini(asset_keys.size(), asset_scenes.size())):
		LifeMaterials.prepare_scene_materials(asset_scenes[i])
		assets[asset_keys[i]] = asset_scenes[i]
	for i: int in range(mini(texture_keys.size(), texture_assets.size())):
		textures[texture_keys[i]] = texture_assets[i]
	viewport = SubViewport.new()
	viewport.name = "LocalViewport"
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.positional_shadow_atlas_size = 2048
	add_child(viewport)
	world_root = Node3D.new()
	viewport.add_child(world_root)
	camera = Camera3D.new()
	camera.near = 0.01
	camera.far = 1000.0
	camera.fov = 52.0
	world_root.add_child(camera)
	camera.current = true
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.01, 0.025, 0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.52, 0.63)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var env_node: WorldEnvironment = WorldEnvironment.new()
	env_node.environment = environment
	world_root.add_child(env_node)
	presentation = TextureRect.new()
	presentation.texture = viewport.get_texture()
	presentation.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	presentation.stretch_mode = TextureRect.STRETCH_SCALE
	presentation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.modulate.a = 0.0
	add_child(presentation)
	set_view_size(Vector2i(get_viewport().get_texture().get_size()), float(get_window().get_meta("experience_render_ratio", 1.0)))
	reduced_motion = bool(get_window().get_meta("experience_reduced_motion", false))
	# Stage metadata is canonical source text; UI localizes copies when displayed.
	I18n.source_depth += 1
	builder.build(self)
	I18n.source_depth -= 1
	set_pose(default_position, default_target)
	set_world_time(float(world_snapshot.simulation_time_s))
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	_prepare_rendering.call_deferred()


func _prepare_rendering() -> void:
	if DisplayServer.get_name() == "headless":
		_prepared = true
		return
	# This UPDATE_ALWAYS viewport has now completed an actual render update.
	# Extra global frames are not evidence of additional resource readiness and
	# can discard a usable first image when initial rendering crosses the deadline.
	await RenderingServer.frame_post_draw
	_prepared = true


func is_prepared() -> bool:
	return _prepared


func set_view_size(pixel_size: Vector2i, ratio: float) -> void:
	render_scale = RenderQuality.effective_scale(pixel_size, ratio)
	if viewport != null:
		viewport.size = Vector2i(maxi(pixel_size.x, 1), maxi(pixel_size.y, 1))
		RenderQuality.apply(viewport, pixel_size, ratio)
		presentation.size = Vector2(pixel_size)
		if builder != null and builder.has_method("resize"):
			builder.resize(self)


func render_viewports() -> Array[Viewport]:
	var result: Array[Viewport] = [viewport]
	for key: String in ["cloud_render_pass", "galaxy_render_pass"]:
		if has_meta(key): result.append(get_meta(key).viewport)
	return result


func set_render_update_mode(mode: SubViewport.UpdateMode) -> void:
	viewport.render_target_update_mode = mode
	for key: String in ["cloud_render_pass", "galaxy_render_pass"]:
		if has_meta(key): get_meta(key).viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if mode == SubViewport.UPDATE_DISABLED else SubViewport.UPDATE_WHEN_VISIBLE


func set_opacity(value: float) -> void:
	if presentation != null:
		presentation.modulate.a = clampf(value, 0.0, 1.0)


func set_pose(position_value: Vector3, target_value: Vector3, up: Vector3 = Vector3.UP) -> void:
	set_meta("camera_look_target",target_value)
	camera.position = position_value
	var direction: Vector3 = target_value - position_value
	if direction.length_squared() > 0.0000000001:
		var safe_up: Vector3 = up.normalized()
		if absf(direction.normalized().dot(safe_up)) > 0.9999:
			safe_up = Vector3.FORWARD if absf(direction.normalized().z) < 0.9 else Vector3.RIGHT
		camera.look_at(target_value, safe_up)
	if builder.has_method("update_camera"):
		builder.update_camera(self)
	# A freely selected fish can be farther away than the old fixed 22 cm
	# focus plane. Keep the actual observation target sharp while orbiting/zooming.
	if scale_id == "fish" and camera.attributes is CameraAttributesPractical:
		camera.attributes.dof_blur_far_distance = position_value.distance_to(target_value) + .06


func set_reference_state(value: Dictionary) -> void:
	world_snapshot["science"] = value


func set_runoff_state(value: Dictionary) -> void:
	world_snapshot["urban_runoff"] = value


func set_browse_state(value: Dictionary) -> void:
	world_snapshot["woodland_browse"] = value


func set_deadwood_state(value: Dictionary) -> void:
	world_snapshot["deadwood_decomposition"] = value


func set_symbiosis_state(value: Dictionary) -> void:
	world_snapshot["coral_symbiosis"] = value


func set_city_traffic_state(value: Dictionary) -> void:
	world_snapshot["city_traffic"] = value


func set_world_time(value: float) -> void:
	var reference: Dictionary = world_snapshot.get("science", {})
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("world_time", value)
		if not reference.is_empty():
			material.set_shader_parameter("reference_beat", reference.beat_phase)
			material.set_shader_parameter("reference_flow", reference.swim_phase)
			material.set_shader_parameter("reference_enabled", true)
			if material.shader != null and material.shader.resource_path.contains("/fish_"):
				material.set_shader_parameter("world_time", reference.swim_phase / 0.4)
			if scale_id in ["cardiomyocyte", "mitochondrion"]:
				material.set_shader_parameter("world_time", reference.flux_phase)
	for item: Dictionary in animated_nodes:
		var node: Node3D = item.node
		if not is_instance_valid(node):
			continue
		var phase: float = value * float(item.get("speed", 1.0)) + float(item.get("phase", 0.0))
		match item.get("kind", "drift"):
			"target_fish":
				node.position = Habitat.FISH_ORIGIN + Vector3(reference.offset_x, reference.offset_y, reference.offset_z) if not reference.is_empty() else Habitat.fish_position(value)
			"habitat_companion":
				node.position = Habitat.companion_position(float(reference.swim_phase)) if not reference.is_empty() else Habitat.companion_position(value)
			"drift":
				node.position = item.origin + Vector3(sin(phase), sin(phase * 0.61) * 0.3, cos(phase) * 0.25) * float(item.get("amplitude", 0.01))
			"pulse":
				var beat: float = pow(maxf(sin(phase * TAU), 0.0), 5.0)
				node.scale = item.base_scale * (1.0 - beat * float(item.get("amplitude", 0.035)))
			"rotate":
				node.rotation.y = phase
	if builder.has_method("animate"):
		builder.animate(self, value)
	for player: AnimationPlayer in animation_players:
		var names: PackedStringArray = player.get_animation_list()
		for animation_name: String in names:
			if animation_name != "RESET":
				if player.current_animation != animation_name:
					player.play(animation_name)
				player.speed_scale = 0.0
				var animation_time: float = reference.swim_phase / 0.4 if not reference.is_empty() and scale_id in ["fish", "reef", "school"] else value
				player.seek(fposmod(animation_time, maxf(player.get_animation(animation_name).length, 0.01)), true)
				break


func asset_instance(key: String) -> Node3D:
	if not assets.has(key):
		push_error("Missing stage asset: " + key)
		return Node3D.new()
	var node: Node3D = assets[key].instantiate() as Node3D
	_collect_players(node)
	return node


func _collect_players(node: Node) -> void:
	if node is AnimationPlayer:
		animation_players.append(node)
	for child: Node in node.get_children():
		_collect_players(child)


func add_mesh(mesh: Mesh, material: Material, position_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position_value
	world_root.add_child(node)
	return node


func add_sun(rotation_value: Vector3, color: Color, energy: float) -> DirectionalLight3D:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = rotation_value
	sun.light_color = color
	sun.light_energy = energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 32.0
	world_root.add_child(sun)
	return sun


func target_screen_position() -> Vector2:
	return camera.unproject_position(target_position)


func entry_pose(source_id: String) -> Dictionary:
	if builder.has_method("entry_pose"):
		return builder.entry_pose(self, source_id)
	return {"position": default_position * 1.8, "target": default_target}


func exit_pose(target_id: String) -> Dictionary:
	if builder.has_method("exit_pose"):
		return builder.exit_pose(self, target_id)
	return {"position": close_position, "target": target_position}


func set_school_state(value: Dictionary) -> void:
	world_snapshot["schooling"]=value

func set_algal_state(value: Dictionary) -> void:
	world_snapshot["algal_grazing"]=value

func set_desert_seed_state(value: Dictionary) -> void:
	world_snapshot["desert_seed_transfer"]=value

func set_zooplankton_state(value: Dictionary) -> void:
	world_snapshot["zooplankton_lesson"]=value
