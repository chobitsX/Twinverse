extends RefCounted
## A synthetic Antarctic coastal cross-section. No mapped ice or wildlife state.
const Forms = preload("res://scripts/experience/life_forms.gd")
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Sites = preload("res://scripts/data/earth_sites.gd")
const Krill = preload("res://scripts/experience/polar_krill.gd")
const Adelie = preload("res://scripts/experience/adelie_activity.gd")
const PolarEnvironment = preload("res://scripts/experience/polar_environment.gd")
const ROCK_COLOR = preload("res://assets/textures/woodland89/rock_surface_diff_1k.jpg")
const ROCK_NORMAL = preload("res://assets/textures/woodland89/rock_surface_nor_gl_1k.jpg")
const ROCK_ARM = preload("res://assets/textures/woodland89/rock_surface_arm_1k.jpg")
const WATER_SHADER = preload("res://shaders/polar_water_197.gdshader")

const PENGUIN_SOURCE: String = "https://www.antarctica.gov.au/about-antarctica/animals/penguins/adelie-penguin/"
const ICE_SOURCE: String = "https://nsidc.org/learn/parts-cryosphere/sea-ice/science-sea-ice"
const PENGUIN_COUNT: int = 4

static func _west_headland(x: float) -> float:
	return smoothstep(-41.0, -30.0, x) * (1.0 - smoothstep(-21.0, -10.0, x))

static func _east_headland(x: float) -> float:
	return smoothstep(16.0, 27.0, x) * (1.0 - smoothstep(42.0, 51.0, x))

static func _rock_height(x: float, z: float) -> float:
	var inland: float = smoothstep(3.0, 35.0, z)
	var base: float = (.13 + .16 * sin(.12 * x + .4) * cos(.19 * z)
		+ .09 * sin(.48 * x + .31 * z) + inland * (.55 + .55 * sin(.075 * x + .38) * sin(.13 * z)))
	var shore_distance: float = z - _shore_z(x)
	var west_depth: float = (z + 10.0) / 17.0
	var east_depth: float = (z + 2.0) / 13.0
	var coastal_relief: float = smoothstep(0.0, 6.0, shore_distance) * (
		2.1 * _west_headland(x) * exp(-west_depth * west_depth)
		+ .85 * _east_headland(x) * exp(-east_depth * east_depth))
	return maxf(.035, base + coastal_relief)

static func _shore_z(x: float) -> float:
	return (-3.0 + 2.2 * sin(.115 * x + .4) + .9 * sin(.36 * x)
		- 19.0 * _west_headland(x) - 7.0 * _east_headland(x))

static func _box(stage: Node, name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = Forms.mesh(stage.world_root, mesh, material, at)
	node.name = name
	return node

static func _ice_floe(stage: Node, index: int, x: float, z: float, radius: float, material: Material) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Vector3 = Vector3(x, .41 + .025 * float(index % 3), z)
	var count: int = 15
	var rim: Array[Vector3] = []
	var inner: Array[Vector3] = []
	for k: int in range(count):
		var angle: float = TAU * float(k) / float(count)
		var r: float = radius * (1.0 + .25 * sin(float(index * 11 + k * 7)))
		var tilt: float = float(index % 5) * .29
		var tip: Vector3 = Vector3(x + r * cos(angle + tilt), .20 + .045 * sin(float(index * 5 + k * 3)),
			z + r * (.72 + .09 * float(index % 3)) * sin(angle + tilt))
		rim.append(tip)
		inner.append(top.lerp(tip, .56) + Vector3(0, .055 * sin(float(index * 3 + k * 2)), 0))
	for k: int in range(count):
		var next: int = (k + 1) % count
		for point: Vector3 in [top, inner[k], inner[next]]:
			surface.set_color(Color(.67, .78, .81) if point == top else Color(.59, .73, .78))
			surface.add_vertex(point)
		for point: Vector3 in [inner[k], rim[k], rim[next], inner[k], rim[next], inner[next]]:
			surface.set_color(Color(.59, .73, .78) if point.y > .29 else Color(.40, .59, .67))
			surface.add_vertex(point)
		var lower_a: Vector3 = rim[k] - Vector3(0, .46 + .035 * float(k % 3), 0)
		var lower_b: Vector3 = rim[next] - Vector3(0, .46 + .035 * float(next % 3), 0)
		for point: Vector3 in [rim[k], lower_a, rim[next], rim[next], lower_a, lower_b]:
			surface.set_color(Color(.20, .37, .46) if point.y < .0 else Color(.31, .50, .58))
			surface.add_vertex(point)
	surface.generate_normals()
	var floe: MeshInstance3D = stage.add_mesh(surface.commit(), material)
	floe.name = "AuthoredIceFloe_%02d" % index

static func _coast(stage: Node, rock: Material) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi: int in range(28):
		for xi: int in range(60):
			var x: float = -51.0 + float(xi) * 1.7
			var z: float = float(zi) * 1.6
			for offset: Vector2 in [Vector2.ZERO, Vector2(1.7, 0), Vector2(0, 1.6),
					Vector2(1.7, 0), Vector2(1.7, 1.6), Vector2(0, 1.6)]:
				var px: float = x + offset.x
				var pz: float = _shore_z(px) + z + offset.y
				surface.add_vertex(Vector3(px, _rock_height(px, pz), pz))
	surface.generate_normals()
	stage.add_mesh(surface.commit(), rock).name = "ExposedRockCoast"
	var stone_mesh: SphereMesh = SphereMesh.new()
	stone_mesh.radius = 1.0
	stone_mesh.height = 2.0
	stone_mesh.radial_segments = 8
	stone_mesh.rings = 5
	for k: int in range(62):
		var x: float = -46.0 + float((k * 37) % 92)
		var z: float = 4.0 + float((k * 23) % 37)
		var size: float = .34 + .15 * float(k % 6)
		var boulder: MeshInstance3D = stage.add_mesh(stone_mesh, rock,
			Vector3(x, _rock_height(x, z) + size * .23, z))
		boulder.name = "ShoreStone_%02d" % k
		boulder.scale = Vector3(size, size * (.38 + .08 * float(k % 3)), size * (.77 + .14 * float(k % 4)))
		boulder.rotation.y = float(k) * .49

static func sample(time: float, index: int) -> Dictionary:
	if index == 2:
		var motion: Dictionary = Adelie.sample(time, _shore_z(Adelie.LAND_HOME.x), _shore_z(Adelie.EXIT_X))
		var point: Vector3 = motion.position
		point.y = lerpf(_rock_height(point.x, point.z)-.011,
			Adelie.SURFACE_ROOT_Y+.008*sin(TAU*time/2.8), motion.swim)
		motion.position = point
		return motion
	var homes: Array[Vector2] = [Vector2(-5.5, 7.5), Vector2(-1.3, 4.8),
		Vector2(3.6, 8.2), Vector2(7.2, 5.7)]
	var home: Vector2 = homes[index]
	var phase: float = TAU * time / 34.0 + float(index) * 1.37
	var travel: float = 0.0 if index >= 2 else .42
	var x: float = home.x + travel * sin(phase)
	var z: float = home.y + travel * .48 * cos(phase)
	return {"position": Vector3(x, _rock_height(x, z), z),
		"heading": -.24 + .24 * cos(phase) if index < 2 else float(index) * .68,
		"head_bob": .035 * sin(phase * 2.0) if index < 2 else 0.0}

static func build(stage: Node) -> void:
	if stage.scale_id == "arctic":
		_build_arctic(stage)
		return
	stage.semantic_size_m = 180.0
	stage.camera.near = .06
	stage.camera.far = 900.0
	stage.camera.fov = 48.0
	stage.default_position = Vector3(11, 5.5, 18)
	stage.default_target = Vector3(0, .8, -16)
	stage.target_position = Vector3(0, .5, 4)
	stage.close_position = Vector3(3.5, 2.0, 7)
	stage.environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(.18, .34, .50)
	sky_mat.sky_horizon_color = Color(.67, .79, .84)
	sky_mat.ground_horizon_color = Color(.51, .64, .68)
	sky_mat.ground_bottom_color = Color(.16, .26, .32)
	sky.sky_material = sky_mat
	stage.environment.sky = sky
	stage.environment.ambient_light_color = Color(.77, .86, .93)
	stage.environment.ambient_light_energy = .63
	stage.environment.ssao_enabled = true
	stage.environment.ssao_radius = 1.2
	stage.environment.ssao_intensity = .8
	stage.environment.fog_enabled = true
	stage.environment.fog_density = .0008
	stage.environment.fog_sky_affect = .14
	stage.environment.fog_light_color = Color(.63, .75, .81)
	var sun: DirectionalLight3D = stage.add_sun(Vector3(-26, -35, 0), Color(.89, .94, 1.0), 1.35)
	sun.layers = 7
	sun.light_cull_mask = 7
	sun.directional_shadow_max_distance = 145.0
	# Near-horizon direct energy must not turn the procedural sky's sun disc black.
	# Both render lights follow the same existing direction; neither owns a clock.
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	var sky_sun: DirectionalLight3D = DirectionalLight3D.new()
	sky_sun.name = "PolarSkySun"
	sky_sun.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	sky_sun.shadow_enabled = false
	sky_sun.light_color = sun.light_color
	stage.world_root.add_child(sky_sun)
	stage.set_meta("daylight_sun", sun)
	stage.set_meta("daylight_sky_sun", sky_sun)
	var water: ShaderMaterial = ShaderMaterial.new()
	water.shader = WATER_SHADER
	stage.materials.append(water)
	var rock: StandardMaterial3D = Forms.material(Color(.48, .57, .65), .92)
	rock.albedo_texture = ROCK_COLOR
	rock.normal_enabled = true
	rock.normal_texture = ROCK_NORMAL
	rock.normal_scale = .8
	rock.roughness_texture = ROCK_ARM
	rock.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	rock.uv1_triplanar = true
	rock.uv1_world_triplanar = true
	rock.uv1_scale = Vector3.ONE * .24
	var ice: ShaderMaterial = ShaderMaterial.new()
	ice.shader = PolarEnvironment.ICE
	stage.materials.append(ice)
	# A surface rather than a solid water slab allows real-size underwater observation.
	var water_plane: PlaneMesh = PlaneMesh.new()
	water_plane.size = Vector2(1000, 503)
	Forms.mesh(stage.world_root, water_plane, water, Vector3(0, -.10, -251)).name = "OpenSouthernOceanReference"
	_coast(stage, rock)
	var ice_edges: Array[Vector4] = []
	for k: int in range(12):
		var x: float = -43.0 + float((k * 29) % 86)
		var z: float = -8.0 - float((k * 17) % 58)
		if k == 7:
			# Keep the broad teaching floe in open water beside the new western headland.
			x = -2.0
			z = -21.0
		var radius: float = 2.8 + float(k % 4) * 1.2
		_ice_floe(stage, k, x, z, radius, ice)
		ice_edges.append(Vector4(x, z, radius, radius * .8))
	ice_edges.append(Vector4(24, -65, 12, 8))
	ice_edges.append(Vector4(-31, -103, 17, 10))
	water.set_shader_parameter("ice_edges", ice_edges)
	PolarEnvironment.build(stage, ice)
	var birds: Array[Node3D] = []
	var heads: Array[Node3D] = []
	var bird_rigs: Array[Dictionary] = []
	for k: int in range(PENGUIN_COUNT):
		var bird: Node3D = stage.assets.adelie_penguin.instantiate()
		LifeMotion.prepare_materials(bird)
		bird.name = "AdeliePenguin_%02d" % k
		bird.set_meta("stable_id", "3dworld:teaching:adelie-penguin:%04d" % k)
		stage.world_root.add_child(bird)
		birds.append(bird)
		heads.append(bird.find_child("HeadPivot", true, false) as Node3D)
		bird_rigs.append(Adelie.prepare(bird))
	var overview: Node3D = Node3D.new()
	overview.name = "PolarCoastOverview"
	overview.position = Vector3(0, .8, -4)
	overview.set_meta("stable_id", "3dworld:teaching:polar-coast:overview")
	stage.world_root.add_child(overview)
	var activity_focus: Node3D = Node3D.new()
	activity_focus.name = "AdelieActivityFocus"
	activity_focus.set_meta("stable_id", "3dworld:teaching:adelie-penguin:activity-focus")
	stage.world_root.add_child(activity_focus)
	var activity_overview: Node3D = Node3D.new()
	activity_overview.name = "AdelieActivityOverview"
	activity_overview.position = Vector3(6.2, .3, 1.8)
	activity_overview.set_meta("stable_id", "3dworld:teaching:adelie-penguin:activity-overview")
	stage.world_root.add_child(activity_overview)
	stage.set_meta("polar", {"overview": overview, "birds": birds, "heads": heads,
		"bird_rigs": bird_rigs, "activity_rig": bird_rigs[2], "activity_focus": activity_focus, "activity_overview": activity_overview})
	var targets: Array[Dictionary] = [
		{"node": overview, "label": "南极海岸 · 裸岩、海水与海冰", "role": "合成教学剖面：裸岩陆岸、海面和不规则海冰可在同一画面比较。冰块范围不是当日卫星观测。", "source_url": ICE_SOURCE, "distance": 22.0, "view_offset": Vector3(9, 5, 16)},
		{"node": birds[0], "label": "阿德利企鹅 · Pygoscelis adeliae", "role": "约70厘米成年形态参考：黑背白腹、白色眼环、短喙和鳍状翼。四只为作者布局，不表示繁殖群或追踪数据。", "source_url": PENGUIN_SOURCE, "distance": 1.55, "min_distance": .8, "focus_height": .35, "view_offset": Vector3(1.3, .75, 1.6)},
	]
	targets.append_array(Krill.build(stage))
	targets.append({"node": activity_focus, "label": "阿德利企鹅 · 同一只岸水往返", "role": "跟随原第3只的身体中心，比较迈足、入水和水平鳍划水。80世界秒循环是作者演示，不是实测游速、潜水或取食。", "source_url": PENGUIN_SOURCE, "distance": 1.7, "min_distance": .8, "view_offset": Vector3(1.3, .55, 1.6)})
	targets.append({"node": activity_overview, "label": "阿德利企鹅 · 岸与水的往返全景", "role": "同一只企鹅在原海岸与海面间的有限作者路线；数量、岸位和活动不表示野外追踪、繁殖或捕食。", "source_url": PENGUIN_SOURCE, "distance": 14.0, "min_distance": 8.0, "view_offset": Vector3(6, 4.5, 11)})
	var sky_overview: Node3D = Node3D.new()
	sky_overview.name = "AntarcticSkyOverview"
	sky_overview.position = Vector3(0, 45, -125)
	sky_overview.set_meta("stable_id", "3dworld:teaching:antarctic-sky:overview")
	stage.world_root.add_child(sky_overview)
	targets.append({"node":sky_overview, "label":"南极夜空与极光演示", "role":"共同日期星位，光幕为作者示意，非当日预报。", "source_url":PolarEnvironment.AURORA_SOURCE, "distance":150.0, "min_distance":50.0, "view_offset":Vector3(0, -39, 140)})
	stage.set_meta("polar_targets", targets)
	stage.set_meta("scientific_label", "南极海岸 · 合成教学参考\n66.5°S用于同日期日照与星位；冰川/浮冰为作者布局，极光为暗夜演示，非实测地址、当日冰缘或天气。")
	stage.set_meta("content_summary", "南极海岸参考：裸岩、海水和12块作者海冰 · 4只阿德利企鹅 · 12只同种冰磷虾\n企鹅主题可比较原第3只的迈足、入水、鳍划水与上岸，或进入原近岸水下看约3厘米磷虾。冰磷虾是企鹅近岸食物的一种，场景未模拟捕食。海冰、数量和80秒往返为作者设置；太阳读取共同日期，动物活动读取唯一世界时间。")
	animate(stage, float(stage.world_snapshot.simulation_time_s))

static func _build_arctic(stage: Node) -> void:
	stage.semantic_size_m = 800.0
	stage.camera.near = .06
	stage.camera.far = 900.0
	stage.camera.fov = 55.0
	stage.default_position = Vector3(6, 6.5, 17)
	stage.default_target = Vector3(0, .2, -24)
	stage.target_position = Vector3(0, .5, -25)
	stage.close_position = Vector3(5, 4, 5)
	stage.environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky.sky_material = sky_material
	stage.environment.sky = sky
	stage.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	stage.environment.ambient_light_color = Color(.77, .86, .93)
	stage.environment.ambient_light_energy = .63
	stage.environment.fog_enabled = true
	stage.environment.fog_density = .0008
	stage.environment.fog_sky_affect = .14
	stage.environment.fog_light_color = Color(.63, .75, .81)
	var sun: DirectionalLight3D = stage.add_sun(Vector3(-26, -35, 0), Color(.89, .94, 1.0), 1.35)
	sun.layers = 7
	sun.light_cull_mask = 7
	sun.directional_shadow_max_distance = 145.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	var sky_sun: DirectionalLight3D = DirectionalLight3D.new()
	sky_sun.name = "PolarSkySun"
	sky_sun.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	sky_sun.shadow_enabled = false
	sky_sun.light_color = sun.light_color
	stage.world_root.add_child(sky_sun)
	stage.set_meta("daylight_sun", sun)
	stage.set_meta("daylight_sky_sun", sky_sun)
	var water: ShaderMaterial = ShaderMaterial.new()
	water.shader = WATER_SHADER
	water.set_shader_parameter("authored_coast", false)
	var ice_edges: Array[Vector4] = [Vector4(0, 24, 29, 19), Vector4(-27, -29, 22, 27), Vector4(28, -54, 20, 33)]
	for index: int in range(8):
		ice_edges.append(Vector4(-62.0 + index * 16.0, -130.0 - float((index * 17) % 74),
			(2.6 + float(index % 3)) * 3.0, (1.8 + float(index % 3)) * 3.0))
	ice_edges.resize(14)
	water.set_shader_parameter("ice_edges", ice_edges)
	stage.materials.append(water)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(1000, 1000)
	Forms.mesh(stage.world_root, plane, water, Vector3(0, -.10, 0)).name = "OpenArcticOceanReference"
	var ice: ShaderMaterial = ShaderMaterial.new()
	ice.shader = PolarEnvironment.ICE
	stage.materials.append(ice)
	PolarEnvironment.build(stage, ice, true)
	var overview: Node3D = Node3D.new()
	overview.name = "ArcticSeaIceOverview"
	overview.position = Vector3(0, 1, -15)
	overview.set_meta("stable_id", "3dworld:teaching:arctic-sea-ice:overview")
	stage.world_root.add_child(overview)
	var aurora: Node3D = Node3D.new()
	aurora.name = "ArcticSkyOverview"
	aurora.position = Vector3(0, 55, -155)
	aurora.set_meta("stable_id", "3dworld:teaching:arctic-sky:overview")
	stage.world_root.add_child(aurora)
	stage.set_meta("polar_targets", [
		{"node":overview, "label":"北冰洋海冰与开阔水面", "distance":52.0, "min_distance":18.0, "view_offset":Vector3(9, 8, 36), "source_url":PolarEnvironment.POLES_SOURCE, "role":"固定海冰参考 · 78°N日照"},
		{"node":aurora, "label":"北极夜空与极光演示", "distance":210.0, "min_distance":50.0, "view_offset":Vector3(0, -49, 185), "source_url":PolarEnvironment.AURORA_SOURCE, "role":"同日期星位 · 极光为作者演示"}])
	stage.set_meta("content_summary", "北冰洋合成海冰观察点：积雪、蓝冰断面、开阔水面与冰脊。78°N/0°仅用于日照和星位；极光光幕为作者演示，暗夜可见，不是当日预测。没有南极企鹅或大陆冰川。")
	stage.set_meta("scientific_label", "北极海冰合成参考 · 同日期日照与J2000星表\n海冰形体/覆盖、纹理、波纹与极光强度均为作者展示，不是天气、融冻或极光预报。")
	stage.set_meta("local_unit_m", 1.0)
	stage.set_meta("daylight_enabled", false)
	set_daylight(stage, 2451545.0, false)
	update_camera(stage)


static func animate(stage: Node, time: float) -> void:
	if stage.scale_id == "arctic":
		return
	if not stage.has_meta("polar"): return
	var data: Dictionary = stage.get_meta("polar")
	for k: int in range(PENGUIN_COUNT):
		var bird: Node3D = data.birds[k]
		var pose: Dictionary = sample(time, k)
		bird.position = pose.position
		if k == 2:
			Adelie.apply(bird, data.activity_rig, pose, time)
			bird.set_meta("activity", pose.activity)
			continue
		bird.rotation.y = pose.heading
		if (data.bird_rigs[k] as Dictionary).get("continuous_skin", false):
			var idle_pose: Dictionary = pose.duplicate()
			idle_pose.swim = 0.0
			idle_pose.walk = .20 if k < 2 else 0.0
			Adelie.apply(bird, data.bird_rigs[k], idle_pose, time)
		var head: Node3D = data.heads[k]
		if head != null: head.rotation.z = pose.head_bob
		bird.set_meta("activity", "沿裸岩短步" if k < 2 else "形态观察")
	data.activity_focus.position = stage.world_root.to_local((data.birds[2] as Node3D).to_global(Vector3(0, .325, 0)))
	Krill.animate(stage, time)

static func update_camera(stage: Node) -> void:
	var underwater: bool = stage.camera.position.y < -.10
	stage.is_underwater = underwater
	PolarEnvironment.update_camera(stage, underwater)
	stage.camera.near = .001 if underwater else .06
	stage.camera.far = maxf(12.0, stage.camera.position.distance_to(Krill.CENTRE) + .30) if underwater else 900.0
	var shape_view: bool = underwater and stage.camera.position.distance_to(Krill.CENTRE) < .14
	stage.camera.cull_mask = 2 if shape_view else 7
	stage.environment.background_mode = Environment.BG_COLOR if underwater else Environment.BG_SKY
	stage.environment.background_color = Color(.09, .22, .28)
	stage.environment.fog_density = .045 if underwater else .0008
	stage.environment.fog_enabled = not underwater
	var night: float = float(stage.get_meta("polar_environment").night) if stage.has_meta("polar_environment") else 0.0
	stage.environment.fog_light_color = Color(.06, .18, .23) if underwater else Color(.63, .75, .81).lerp(Color(.02, .035, .065), night)
	stage.camera.environment = stage.environment
	stage.world_root.get_node("OpenArcticOceanReference" if stage.scale_id == "arctic" else "OpenSouthernOceanReference").visible = not underwater
	if stage.has_meta("ice_krill"):
		(stage.get_meta("ice_krill").fill as OmniLight3D).visible = underwater

static func set_daylight(stage: Node, jd: float, enabled: bool) -> void:
	var sun: DirectionalLight3D = stage.get_meta("daylight_sun")
	var site: Dictionary = Sites.for_scale(stage.scale_id)
	var direction: Vector3 = Orientation.local_sun(jd, site.lat, site.lon) if enabled else Vector3(.48, .72, .50).normalized()
	sun.look_at_from_position(direction * 100.0, Vector3.ZERO, Vector3.FORWARD if absf(direction.y) > .99 else Vector3.UP)
	sun.light_energy = 1.35 if not enabled else maxf(.0, direction.y) * 1.8
	var sky_sun: DirectionalLight3D = stage.get_meta("daylight_sky_sun")
	sky_sun.transform = sun.transform
	sky_sun.visible = not enabled or direction.y > 0.0
	# Authored sky-disc brightness, independent of surface illuminance; no refraction model.
	sky_sun.light_energy = 1.35
	# Match the existing land view's authored day/night blend, using the same sun direction.
	# This color band is presentation, not a physical twilight or weather calculation.
	var night: float = 1.0 - smoothstep(-.12, .15, direction.y) if enabled else 0.0
	var sky: ProceduralSkyMaterial = stage.environment.sky.sky_material
	sky.sky_top_color = Color(.18, .34, .50).lerp(Color(.002, .005, .014), night)
	sky.sky_horizon_color = Color(.67, .79, .84).lerp(Color(.025, .035, .06), night)
	sky.ground_horizon_color = Color(.51, .64, .68).lerp(Color(.025, .035, .06), night)
	sky.ground_bottom_color = Color(.16, .26, .32).lerp(Color(.008, .012, .018), night)
	stage.environment.fog_light_color = Color(.06, .18, .23) if stage.is_underwater else Color(.63, .75, .81).lerp(Color(.02, .035, .065), night)
	stage.environment.ambient_light_energy = .63 if not enabled else .18 + .45 * smoothstep(-.1, .2, direction.y)
	stage.environment.ambient_light_color = Color(.77, .86, .93).lerp(Color(.36, .48, .65), night)
	if stage.is_underwater:
		sun.light_energy *= .25
		stage.environment.ambient_light_energy *= .45
		# Preserve the original neutral underwater inspection fill at night.
		stage.environment.ambient_light_color = Color(.77, .86, .93)
	stage.set_meta("sun_elevation", rad_to_deg(asin(clampf(direction.y, -1.0, 1.0))))
	PolarEnvironment.set_daylight(stage, jd, site, float(stage.get_meta("sun_elevation")), enabled)

static func entry_pose(stage: Node, _source: String) -> Dictionary:
	return {"position": stage.default_position * 1.3, "target": stage.default_target}

static func exit_pose(stage: Node, _target: String) -> Dictionary:
	return {"position": stage.default_position * 1.4, "target": stage.default_target}
