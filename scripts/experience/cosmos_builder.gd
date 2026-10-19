extends RefCounted
const EarthSeasonOrbit = preload("res://scripts/experience/earth_season_orbit.gd")
const EarthRegionFlight = preload("res://scripts/experience/earth_region_flight.gd")
## Stage 0 local-coordinate visual prototypes. No second authoritative clock.

const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Eclipse = preload("res://scripts/core/eclipse_geometry.gd")
const Galactic = preload("res://scripts/experience/galactic_observation.gd")
const Cosmic = preload("res://scripts/experience/cosmic_panorama.gd")
const Sites = preload("res://scripts/data/earth_sites.gd")
const EarthLocator = preload("res://scripts/experience/earth_locator.gd")
const EarthDaylight = preload("res://scripts/experience/earth_daylight.gd")
const MOON_SHADER: Shader = preload("res://shaders/moon_surface.gdshader")
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const SolarSatellites = preload("res://scripts/experience/solar_satellite_view.gd")
const SolarPhysical = preload("res://scripts/experience/solar_physical_context.gd")

const EARTH_RADIUS_KM: float = 6371.0
const EARTH_LOCAL_RADIUS: float = 3.0
const SOLAR_OVERVIEW_POSITION: Vector3 = Vector3(14.0,21.0,38.0)*1.18
const LIZARD_LAT: float = Sites.REEF_LAT
const LIZARD_LON: float = Sites.REEF_LON
const SURFACE_SHADER: Shader = preload("res://shaders/earth_surface.gdshader")
const AIR_SHADER: Shader = preload("res://shaders/earth_atmosphere.gdshader")
const CLOUD_SHADER: Shader = preload("res://shaders/earth_clouds.gdshader")
const VOLUME_SHADER: Shader = preload("res://shaders/earth_cloud_raymarch.gdshader")
const CloudRenderPass: Script = preload("res://scripts/experience/cloud_render_pass.gd")
const SUN_SHADER: Shader = preload("res://shaders/solar_photosphere.gdshader")
const CORONA_SHADER: Shader = preload("res://shaders/solar_corona.gdshader")
const PLANET_SHADER: Shader = preload("res://shaders/solar_planet.gdshader")
const RING_SHADER: Shader = preload("res://shaders/saturn_rings.gdshader")
const GALAXY_SHADER: Shader = preload("res://shaders/galaxy_volume.gdshader")
const STAR_SHADER: Shader = preload("res://shaders/stellar_point.gdshader")
const GALACTIC_STAR_SHADER: Shader = preload("res://shaders/galactic_stars.gdshader")
const CLOUD_SHAPE: Texture3D = preload("res://assets/textures/cosmos/cloud_shape_v1.res")


static func anchor_basis() -> Basis:
	var latitude: float = deg_to_rad(LIZARD_LAT)
	var longitude: float = deg_to_rad(LIZARD_LON)
	var up: Vector3 = Vector3(cos(latitude)*sin(longitude), sin(latitude), cos(latitude)*cos(longitude))
	var east: Vector3 = Vector3(cos(longitude), 0, -sin(longitude))
	var north: Vector3 = Vector3(-sin(latitude)*sin(longitude), cos(latitude), -sin(latitude)*cos(longitude))
	return Basis(east, up, -north)


static func build(stage: Node) -> void:
	stage.environment.background_color = Color(0.0008, 0.0012, 0.003)
	stage.environment.ambient_light_energy = 0.03
	stage.environment.tonemap_exposure = 1.0
	stage.environment.glow_enabled = true
	stage.environment.glow_intensity = 0.14
	stage.set_meta("scientific_category", "frozen_earth_map_and_procedural_visualization")
	stage.set_meta("geographic_anchor", {"name": "Lizard Island regional anchor", "lat": LIZARD_LAT, "lon": LIZARD_LON})
	match stage.scale_id:
		"universe": Cosmic.build(stage)
		"galaxy": _galaxy(stage)
		"solar_system": _solar(stage)
		"earth": _earth(stage)
		"earth_moon": _earth_moon(stage)
		"atmosphere": _atmosphere(stage)
		_: push_error("Unsupported cosmos scale: " + str(stage.scale_id))


static func _sphere(radius: float, segments: int = 128, rings: int = 64) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


static func _material(stage: Node, shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	stage.materials.append(material)
	return material


static func _sun_ecef() -> Vector3:
	var basis: Basis = anchor_basis()
	return (basis.y * 0.80 + basis.x * 0.55 - basis.z * 0.24).normalized()


static func _earth_material(stage: Node, transform: Basis, center: Vector3, sun: Vector3) -> ShaderMaterial:
	var material: ShaderMaterial = _material(stage, SURFACE_SHADER)
	material.set_shader_parameter("earth_map", stage.textures.earth_bmng)
	material.set_shader_parameter("cloud_map", stage.textures.earth_clouds)
	material.set_shader_parameter("ecef_from_local", transform)
	material.set_shader_parameter("planet_center", center)
	material.set_shader_parameter("sun_direction", sun)
	return material


static func _air(stage: Node, radius: float, center: Vector3, sun: Vector3) -> void:
	var material: ShaderMaterial = _material(stage, AIR_SHADER)
	var outer_radius: float = radius * (1.0 + 100.0 / EARTH_RADIUS_KM)
	material.render_priority = 20
	material.set_shader_parameter("planet_radius", radius)
	material.set_shader_parameter("atmosphere_radius", outer_radius)
	material.set_shader_parameter("km_per_unit", EARTH_RADIUS_KM / radius)
	material.set_shader_parameter("composite_local_air", stage.scale_id == "atmosphere")
	material.set_shader_parameter("planet_center", center)
	material.set_shader_parameter("sun_direction", sun)
	var shell: MeshInstance3D = stage.add_mesh(_sphere(outer_radius), material, center)
	shell.name = "SingleScatteringAtmosphere"
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _earth(stage: Node) -> void:
	var normal: Vector3 = anchor_basis().y
	var east: Vector3 = anchor_basis().x
	var sun: Vector3 = _sun_ecef()
	stage.camera.near = 0.0003
	stage.camera.far = 800.0
	stage.semantic_size_m = EARTH_RADIUS_KM * 2000.0
	stage.target_position = normal * EARTH_LOCAL_RADIUS
	stage.target_radius = 0.03
	stage.default_target = Vector3.ZERO
	stage.default_position = normal * 8.0 - east * 4.6 + anchor_basis().z * 1.1
	stage.close_position = normal * (EARTH_LOCAL_RADIUS + 0.025) + east * 0.006
	stage.set_meta("local_unit_m", EARTH_RADIUS_KM * 1000.0 / EARTH_LOCAL_RADIUS)
	var globe_mesh: SphereMesh = _sphere(EARTH_LOCAL_RADIUS, 192, 96)
	var globe: MeshInstance3D = stage.add_mesh(globe_mesh, _earth_material(stage, Basis.IDENTITY, Vector3.ZERO, sun))
	globe.name = "Earth_NASA_2004_01"
	for layer: int in range(3):
		var clouds: ShaderMaterial = _material(stage, CLOUD_SHADER)
		clouds.render_priority = 5 + layer
		clouds.set_shader_parameter("sun_direction", sun)
		clouds.set_shader_parameter("cloud_map", stage.textures.earth_clouds)
		clouds.set_shader_parameter("layer_offset", float(layer))
		clouds.set_shader_parameter("layer_opacity", 0.68 if layer == 0 else 0.20)
		# Matching faces stay outside the surface even at the lowest 2 km shell.
		# A coarser sphere can intersect the finer opaque globe between vertices.
		var cloud: MeshInstance3D = stage.add_mesh(globe_mesh, clouds)
		cloud.scale = Vector3.ONE * (1.0 + (2.0 + layer * 2.0) / EARTH_RADIUS_KM)
		cloud.name = "OrbitalCloudLayer_%d" % layer
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_air(stage, EARTH_LOCAL_RADIUS, Vector3.ZERO, sun)
	_stars(stage, 900, 65.0, 150.0, false)
	stage.set_meta("scientific_label", "NASA 冻结地表与云层合成 · 非当前天气\n地表 2004-01；云层来自 2002 年发布的 MODIS 多日合成，非同一天观测。")
	EarthLocator.build(stage)
	EarthDaylight.build(stage)


static func _atmosphere(stage: Node) -> void:
	var basis: Basis = anchor_basis()
	var center: Vector3 = Vector3(0, -EARTH_RADIUS_KM, 0)
	var sun: Vector3 = basis.inverse() * _sun_ecef()
	stage.camera.near = 0.002
	stage.camera.far = 16000.0
	stage.camera.fov = 58.0
	stage.semantic_size_m = 200000.0
	stage.target_position = Vector3.ZERO
	stage.target_radius = 0.15
	stage.default_position = Vector3(0, 32.0, 85.0)
	stage.default_target = Vector3(0, -26, -110)
	stage.close_position = Vector3(0, 0.008, 0.022)
	stage.set_meta("local_unit_m", 1000.0)
	var surface: ShaderMaterial = _earth_material(stage, basis, center, sun)
	surface.set_shader_parameter("local_water_reflection", 1.0)
	stage.add_mesh(_sphere(EARTH_RADIUS_KM, 192, 96), surface, center).name = "CurvedEarthFarSurface"
	stage.add_mesh(_curved_patch(), surface).name = "LizardTangentPatch"
	_air(stage, EARTH_RADIUS_KM, center, sun)
	# Air is integrated by the atmosphere shell; cloud pixels integrate only
	# camera-to-cloud air, then composite in front of that far-air/background.
	stage.environment.volumetric_fog_enabled = false
	var cloud_material: ShaderMaterial = _material(stage, VOLUME_SHADER)
	cloud_material.render_priority = 30
	cloud_material.set_shader_parameter("sun_direction", sun)
	cloud_material.set_shader_parameter("shape_noise", CLOUD_SHAPE)
	var cloud_box: BoxMesh = BoxMesh.new()
	cloud_box.size = Vector3(1300, 81, 1300)
	var volume: MeshInstance3D = stage.add_mesh(cloud_box, cloud_material, Vector3(0, -29.5, 0))
	volume.name = "LocalCumulusVolume_Procedural"
	volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cloud_pass: Node = CloudRenderPass.new()
	stage.add_child(cloud_pass)
	cloud_pass.configure(stage, volume)
	stage.set_meta("cloud_render_pass", cloud_pass)
	stage.environment.ambient_light_energy = 0.34
	stage.environment.ambient_light_color = Color(0.51,0.66,0.84)
	stage.set_meta("scientific_label", "地球大气 · 观察弧面、云层与地平线\n继续靠近进入海面 · 拉远返回地球\n大气散射与云体为显示模型，非当前天气。")


static func update_camera(stage: Node) -> void:
	EarthLocator.update(stage)
	SolarPhysical.update_camera(stage)
	SolarSatellites.update_camera(stage)
	for key: String in ["cloud_render_pass", "galaxy_render_pass"]:
		if stage.has_meta(key): stage.get_meta(key).sync_camera()


static func resize(stage: Node) -> void:
	for key: String in ["cloud_render_pass", "galaxy_render_pass"]:
		if stage.has_meta(key): stage.get_meta(key).resize(stage.viewport.size, stage.render_scale)


static func _curved_patch() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions: int = 96
	var extent: float = 160.0
	for z: int in range(divisions + 1):
		for x: int in range(divisions + 1):
			var px: float = (float(x)/divisions*2.0-1.0)*extent
			var pz: float = (float(z)/divisions*2.0-1.0)*extent
			var py: float = sqrt(EARTH_RADIUS_KM*EARTH_RADIUS_KM-px*px-pz*pz)-EARTH_RADIUS_KM+0.002
			surface.set_normal(Vector3(px,py+EARTH_RADIUS_KM,pz).normalized())
			surface.add_vertex(Vector3(px,py,pz))
	for z: int in range(divisions):
		for x: int in range(divisions):
			var a: int = z*(divisions+1)+x
			surface.add_index(a)
			surface.add_index(a+1)
			surface.add_index(a+divisions+1)
			surface.add_index(a+1)
			surface.add_index(a+divisions+2)
			surface.add_index(a+divisions+1)
	return surface.commit()


static func _unlit(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func _stars(stage: Node, count: int, inner: float, outer: float, spiral: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 260907
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i: int in range(count):
		var p: Vector3
		var size: float
		if spiral:
			var radius: float = pow(rng.randf(), 0.67) * outer
			var arm: float = float(i % 2) * PI + (1.65 if i % 5 == 0 else 0.0)
			var angle: float = arm + 4.0 * log(1.0 + radius / 1.6) + rng.randfn(0, 0.16)
			p = Vector3(cos(angle) * radius, rng.randfn(0, 0.11 + radius * 0.017), sin(angle) * radius)
			size = rng.randf_range(0.017, 0.038)
		else:
			p = Vector3(rng.randfn(),rng.randfn(),rng.randfn()).normalized()*rng.randf_range(inner,outer)
			size = rng.randf_range(0.05, 0.18) if stage.scale_id=="solar_system" else rng.randf_range(0.028, 0.095)
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),p))
		var temperature: float = rng.randf()
		var colour: Color = Color(1.0, 0.77, 0.52).lerp(Color(0.61, 0.77, 1.0), temperature)
		var brightness: float = (0.18 + pow(rng.randf(), 3.0) * 0.90) if stage.scale_id=="solar_system" else (0.10 + pow(rng.randf(), 4.0) * 0.78)
		colour.a = brightness
		multimesh.set_instance_color(i, colour)
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "ProceduralStarPositions_NotACatalog"
	instance.multimesh = multimesh
	var material: ShaderMaterial = _material(stage, GALACTIC_STAR_SHADER if spiral else STAR_SHADER)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.world_root.add_child(instance)


static func _galaxy(stage: Node) -> void:
	stage.semantic_size_m = Galactic.REFERENCE_DIAMETER_LY*Galactic.LIGHT_YEAR_M
	stage.target_position = Galactic.sun_position()
	stage.target_radius = 0.24
	stage.default_position = Vector3(5,13,24)
	stage.camera.fov = 56.0
	stage.environment.glow_intensity = .28
	stage.default_target = Vector3.ZERO
	stage.close_position = stage.target_position+Vector3(0,0.5,1.0)
	stage.set_meta("scientific_category","authored_galactic_structure_not_star_catalog")
	stage.set_meta("scientific_label", "银河系结构与转动示意 · 参考盘径约10万光年，太阳距银心约2.6万光年\n恒星采用理想化差速转动，旋臂图案单独转动；速度、方位、厚度与星点为作者示意，非银河动力学或恒星目录。\n真实太阳绕银心一周约2.3亿年；本图大幅压缩时间，暂停受同一世界控制。")
	_stars(stage,22000,0,15,true)
	_stars(stage,1300,55,100,false)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(32,6,32)
	var material: ShaderMaterial = _material(stage, GALAXY_SHADER)
	material.render_priority = 10
	var volume: MeshInstance3D = stage.add_mesh(box, material)
	volume.name = "GalacticArmsAndDust_Illustration"
	volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The smooth 96-step dust integration was the dominant galaxy cost. Keep
	# every star at the main resolution and composite only the volume in HDR.
	var dust_pass: Node = CloudRenderPass.new()
	stage.add_child(dust_pass)
	dust_pass.configure(stage, volume, 0.5, "GalacticDust", 10)
	stage.set_meta("galaxy_render_pass", dust_pass)
	var anchor_mesh: QuadMesh = QuadMesh.new()
	anchor_mesh.size = Vector2(2, 2)
	var anchor: MeshInstance3D = stage.add_mesh(anchor_mesh, _material(stage, STAR_SHADER), stage.target_position)
	anchor.scale = Vector3.ONE * 0.065
	anchor.name = "SolarSystemSemanticAnchor"
	Galactic.build(stage)


static func _solar(stage: Node) -> void:
	stage.semantic_size_m = 1.5e13
	stage.default_position = SOLAR_OVERVIEW_POSITION
	stage.default_target = Vector3.ZERO
	stage.camera.fov = 50.0
	stage.environment.glow_intensity = .25
	stage.set_meta("scientific_category","de440_planet_positions_with_teaching_orbits")
	stage.set_meta("scientific_label", Ephemeris.position_source() + " · 选中行星青实线为DE440日期采样轨迹，橙虚线/等时点是Table 1近似教学椭圆\n行星大小放大、默认逐轨道缩放；太阳、八行星与卫星共用同一日期/倍率。全景默认10天/世界秒，快进时滤除无法分辨的自转纹理；选中或自然靠近卫星系统时全系统1小时/秒慢放，不单独减慢天体。全景月距压缩；近景宿主、卫星距离和平均半径同比，补正系统质心/EMB到本体中心（1995—2050）。远距天体保持几何方向和视大小，识别点不是实体大小；超出中心偏移覆盖时保留质心近似。月球为ERFA位置与IAU月面模型，非精密掩食预报。自转是IAU参考系，非实时云带或当日纹理。")
	stage.add_mesh(_sphere(1.65,128,64),_material(stage,SUN_SHADER)).name = "Sun_AuthoredPhotosphere"
	var corona: QuadMesh = QuadMesh.new()
	corona.size = Vector2(13.2,13.2)
	stage.add_mesh(corona,_material(stage,CORONA_SHADER)).name = "SolarCorona_Illustration"
	var palette: Array[Color] = [Color(0.51,0.47,0.4),Color(0.79,0.66,0.44),Color(0.15,0.4,0.67),Color(0.62,0.29,0.13),Color(0.77,0.64,0.48),Color(0.79,0.71,0.51),Color(0.39,0.69,0.71),Color(0.23,0.39,0.79)]
	var sizes: Array[float] = [0.14,0.24,0.38,0.21,1.18,0.93,0.46,0.43]
	var bodies: Array[Dictionary] = []
	stage.set_meta("solar_bodies", bodies)
	stage.set_meta("solar_jd", Ephemeris.DEFAULT_JD)
	stage.set_meta("solar_true_distance", false)
	stage.set_meta("solar_focus_index", -1)
	for i: int in range(8):
		var p: Vector3 = Ephemeris.display_position(i, Ephemeris.DEFAULT_JD)
		var material: ShaderMaterial
		if i == 2:
			material = _earth_material(stage, Basis.IDENTITY, p, -p.normalized())
		else:
			material = _material(stage, PLANET_SHADER)
			material.set_shader_parameter("planet_colour",palette[i])
			material.set_shader_parameter("planet_center",p)
			material.set_shader_parameter("planet_kind",i)
			if i in [0, 3, 4, 5]:
				var map_key: String = {0: "mercury", 3: "mars", 4: "jupiter", 5: "saturn"}[i]
				material.set_shader_parameter("has_planet_map",true)
				material.set_shader_parameter("planet_map",stage.textures[map_key])
				if i == 0: material.set_shader_parameter("map_longitude_border", 2.5/float(stage.textures[map_key].get_width()))
				if i == 4: material.set_shader_parameter("map_polar_limit", 0.06)
		var planet: MeshInstance3D = stage.add_mesh(_sphere(sizes[i],96,48),material,p)
		planet.name = "IllustrativePlanet_%d" % i
		var body: Dictionary = {"node": planet, "material": material, "extras": []}
		bodies.append(body)
		if i == 5:
			planet.basis = Orientation.body_basis(i, Ephemeris.DEFAULT_JD)
			material.set_shader_parameter("ring_normal", planet.basis.y)
			material.set_shader_parameter("ring_inner", sizes[i] * 1.24)
			material.set_shader_parameter("ring_outer", sizes[i] * 2.25)
			var rings: ShaderMaterial = _material(stage,RING_SHADER)
			rings.set_shader_parameter("planet_center",p)
			rings.set_shader_parameter("planet_radius",sizes[i])
			var ring_node: MeshInstance3D = stage.add_mesh(_planet_rings(sizes[i]*1.24,sizes[i]*2.25),rings,p)
			ring_node.basis = planet.basis
			ring_node.name = "SaturnRings_Illustration"
			body.extras.append(ring_node)
		var orbit_material: StandardMaterial3D = _unlit(Color(0.09,0.19,0.23),0.0)
		orbit_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		body["orbit"] = stage.add_mesh(_orbit_mesh(i, Ephemeris.DEFAULT_JD, false), orbit_material)
		body["orbit_material"] = orbit_material
		body.orbit.name = "KeplerianOrbit_%d" % i
		var label: Label3D = Label3D.new()
		label.text = Ephemeris.NAMES[i]
		label.font_size = 38
		label.pixel_size = 0.009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = p + Vector3(0,sizes[i]+0.35,0)
		label.hide() # Names are projected by the existing HUD observation overlay.
		stage.world_root.add_child(label)
		body["label"] = label
		body["label_height"] = sizes[i]+0.35
		body["name_visible"] = true
		if i == 2:
			stage.target_position = p
			stage.target_radius = sizes[i]
			stage.close_position = p+Vector3(0,0.4,1.1)
			_air(stage,sizes[i],p,-p.normalized())
			body.extras.append(stage.world_root.get_node("SingleScatteringAtmosphere"))
	_build_solar_moon(stage)
	SolarSatellites.build(stage)
	# The old arbitrary asteroid ring is omitted from the ephemeris view.
	_stars(stage,3200,65,130,false)
	var trail_material: StandardMaterial3D = _unlit(Color.WHITE,0.0)
	trail_material.vertex_color_use_as_albedo = true
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	trail_material.no_depth_test = false
	var trail: MeshInstance3D = stage.add_mesh(ImmediateMesh.new(),trail_material)
	trail.name = "PlanetDateHistory_NotLuminousWake"
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.set_meta("solar_history",{"node":trail,"jd":-1.0,"distance":false})
	SolarPhysical.build(stage)
	solar_overview_pose(stage, Ephemeris.DEFAULT_JD, false)
	stage.set_meta("solar_visual_label", "电影化取景与曝光增强 · 太阳纹理/日冕、环带和背景星点为作者视觉，非当日观测")


static func solar_overview_pose(stage: Node, jd: float, true_distance: bool) -> Dictionary:
	# Choose a camera, never move the scientific bodies to imitate a concept.
	# Cinema fits the actual bodies and inner orbits; outer arcs may leave the
	# frame, as in A. The scientific AU/selected-orbit views keep whole paths.
	var size: Vector2=Vector2(stage.viewport.size)
	var tangent: float=tan(deg_to_rad(stage.camera.fov*.5))
	var horizontal: float=tangent*maxf(.45,size.x/maxf(size.y,1.0))*.88
	var vertical: float=tangent*.66
	var target: Vector3=Vector3(0,-1.8,0)*(0.55 if true_distance else 1.0)
	var best: Dictionary={}
	var best_score: float=-INF
	for candidate: int in range(32):
		var yaw: float=TAU*candidate/32.0
		var direction: Vector3=Vector3(sin(yaw)*cos(.35),sin(.35),cos(yaw)*cos(.35))
		var right: Vector3=Vector3.UP.cross(direction).normalized()
		var up: Vector3=direction.cross(right).normalized()
		var distance: float=8.0 if not true_distance else 1.0
		for index: int in range(8):
			var el: Array[float]=Ephemeris.elements(index,jd)
			var extent: float=([.14,.24,1.56,.21,1.18,2.0925,.46,.43][index])*Ephemeris.body_display_scale(index,true_distance)
			var point: Vector3=Ephemeris.display_position(index,jd,true_distance)-target
			distance=maxf(distance,point.dot(direction)+maxf((absf(point.dot(right))+extent)/horizontal,(absf(point.dot(up))+extent)/vertical))
			for sample: int in range(65 if true_distance or index<4 else 0):
				point=Ephemeris.display_vector(index,Ephemeris.orbital_point(el,TAU*sample/64.0),true_distance)-target
				distance=maxf(distance,point.dot(direction)+maxf((absf(point.dot(right))+extent)/horizontal,(absf(point.dot(up))+extent)/vertical))
		distance*=1.08
		var position: Vector3=direction*distance+target
		var p4: Vector3=Ephemeris.display_position(4,jd,true_distance)
		var p5: Vector3=Ephemeris.display_position(5,jd,true_distance)
		var depth4: float=distance-(p4-target).dot(direction)
		var depth5: float=distance-(p5-target).dot(direction)
		var separation: float=absf((p4-target).dot(right)/depth4-(p5-target).dot(right)/depth5)
		var light4: float=(position-p4).normalized().dot(-p4.normalized())
		var light5: float=(position-p5).normalized().dot(-p5.normalized())
		var score: float=separation*.15+1.18/depth4*(.6+.4*light4)+2.0925/depth5*(.6+.4*light5)
		if score>best_score:
			best_score=score
			best={"position":position,"target":target,"true_distance":true_distance,"jd":jd}
	stage.default_position=best.position
	stage.default_target=best.target
	stage.set_meta("solar_cinematic_overview",best)
	return best


static func solar_close_pose(stage: Node, index: int, jd: float, true_distance: bool, frame: Rect2 = Rect2(.02,.12,.96,.66)) -> Dictionary:
	var center: Vector3=Ephemeris.display_position(index,jd,true_distance)
	var sunward: Vector3=-center.normalized()
	var lateral: Vector3=sunward.cross(Vector3.UP).normalized()
	var direction: Vector3=(sunward*.55+lateral*.75+Vector3.UP*.35).normalized()
	if index==5:
		# View the real IAU ring plane at an angle; do not alter its obliquity.
		var axis: Vector3=Orientation.body_basis(index,jd).y
		if absf(direction.dot(axis))<.32:
			direction=(direction+axis*.38*(1.0 if direction.dot(axis)>=0.0 else -1.0)).normalized()
	var body: Dictionary=stage.get_meta("solar_bodies")[index]
	var radius: float=body.node.mesh.radius*(1.0 if SolarPhysical.owner(stage)>=0 else Ephemeris.body_display_scale(index,true_distance))
	var right: Vector3=Vector3.UP.cross(direction).normalized()
	var up: Vector3=direction.cross(right).normalized()
	var size: Vector2=Vector2(stage.viewport.size)
	var tangent: float=tan(deg_to_rad(stage.camera.fov*.5))
	var middle: float=frame.get_center().y
	var upper: float=tangent*(1.0-2.0*frame.position.y)
	var lower: float=tangent*(2.0*frame.end.y-1.0)
	var shift: float=tangent*(2.0*middle-1.0)
	var vertical: float=tangent*frame.size.y
	var horizontal: float=tangent*maxf(.45,size.x/maxf(size.y,1.0))*frame.size.x*.90
	var distance: float=maxf(radius/sin(atan(horizontal)),radius*maxf(sqrt(1.0+upper*upper),sqrt(1.0+lower*lower))/vertical)
	if index==5 and not true_distance:
		var basis: Basis=Orientation.body_basis(index,jd)
		for sample: int in range(64):
			var angle: float=TAU*sample/64.0
			var point: Vector3=(basis.x*cos(angle)+basis.z*sin(angle))*radius*2.25
			distance=maxf(distance,maxf(point.dot(direction)+absf(point.dot(right))/horizontal,maxf((point.dot(up)+upper*point.dot(direction))/vertical,(-point.dot(up)+lower*point.dot(direction))/vertical)))
		distance*=1.035 # Leave room between sampled extrema and the actual ring mesh.
	var offset: Vector3=up*shift*distance
	return {"position":solar_safe_camera(stage,center+direction*distance+offset),"target":center+offset,"offset":offset}


static func solar_safe_camera(stage: Node, position: Vector3) -> Vector3:
	# This only guards the short authored flight, not the user's free camera.
	var centers: Array[Vector3]=[stage.world_root.get_node("Sun_AuthoredPhotosphere").position]
	var extents: Array[float]=[stage.world_root.get_node("Sun_AuthoredPhotosphere").mesh.radius*stage.world_root.get_node("Sun_AuthoredPhotosphere").scale.x]
	for index: int in range(8):
		var body: Dictionary=stage.get_meta("solar_bodies")[index]
		centers.append(body.node.position)
		extents.append(body.node.mesh.radius*body.node.scale.x*(2.25 if index==5 and not bool(stage.get_meta("solar_true_distance")) else 1.0))
	var moon: Dictionary=stage.get_meta("solar_moon")
	centers.append(moon.node.position); extents.append(moon.radius*moon.node.scale.x)
	var result: Vector3=position
	for pass_index: int in range(2):
		for index: int in range(centers.size()):
			var offset: Vector3=result-centers[index]
			var minimum: float=extents[index]+maxf(.01,extents[index]*.08)
			if offset.length()<minimum:
				result=centers[index]+(offset.normalized() if offset.length_squared()>.000001 else Vector3.UP)*minimum
	return result


static func _asteroid_belt(stage: Node) -> void:
	# Authoring context only, with no persistent entities or dynamical claims.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73015
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = _sphere(1.0, 6, 4)
	instances.instance_count = 1600
	for index: int in range(instances.instance_count):
		var angle: float = rng.randf() * TAU
		var radius: float = clampf(rng.randfn(7.20, 0.16), 6.85, 7.5)
		var size: float = rng.randf_range(0.004, 0.013)
		var position: Vector3 = Vector3(cos(angle) * radius, rng.randfn(0, 0.06), sin(angle) * radius)
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 0.7, size * 1.2)), position))
		instances.set_instance_color(index, Color(0.06, 0.055, 0.045) * rng.randf_range(0.4, 1.0))
	var field: MultiMeshInstance3D = MultiMeshInstance3D.new()
	field.name = "AsteroidBelt_AuthoredContext"
	field.multimesh = instances
	var material: StandardMaterial3D = _unlit(Color.WHITE, 0.0)
	material.vertex_color_use_as_albedo = true
	field.material_override = material
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.world_root.add_child(field)


static func _planet_rings(inner: float, outer: float) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(193):
		var angle: float = TAU * float(index) / 192.0
		for edge: int in range(2):
			var radius: float = inner if edge == 0 else outer
			surface.set_uv(Vector2(float(edge),float(index)/192.0))
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(cos(angle)*radius,0,sin(angle)*radius))
	for index: int in range(192):
		var a: int = index * 2
		for vertex_index: int in [a,a+2,a+1,a+1,a+2,a+3]:
			surface.add_index(vertex_index)
	return surface.commit()


static func entry_pose(stage: Node, source_id: String) -> Dictionary:
	match stage.scale_id:
		"universe":
			if source_id=="galaxy": return {"position":stage.close_position,"target":stage.target_position,"up":Vector3.UP}
			return {"position":stage.default_position*1.25,"target":stage.default_target}
		"galaxy":
			if source_id == "solar_system":
				return {"position": stage.close_position, "target": stage.target_position, "up": Vector3.UP}
			return {"position": stage.default_position * 1.25, "target": stage.default_target}
		"solar_system":
			if source_id == "earth":
				return {"position": stage.close_position, "target": stage.target_position, "up": Vector3.UP}
			return {"position": stage.default_position * 1.25, "target": stage.default_target}
		"earth":
			if source_id=="atmosphere":
				return {"position": stage.close_position, "target": stage.target_position, "up": Vector3.UP}
			return {"position": anchor_basis().y*15.0, "target": Vector3.ZERO}
		"atmosphere":
			if source_id=="earth":
				return {"position": Vector3(12.742,53.0916667,0), "target": Vector3.ZERO, "up": anchor_basis().inverse()*Vector3.UP}
			return {"position": stage.close_position, "target": Vector3.ZERO}
		_:
			return {"position": stage.default_position*1.25, "target": stage.default_target}


static func earth_boundary_pose(solar_stage: Node, earth_pose: Dictionary) -> Dictionary:
	# Match the existing displayed Earth, including its current IAU orientation
	# and display enlargement. This transforms the camera, never the planet.
	var body: Dictionary = solar_stage.get_meta("solar_bodies")[2]
	var planet: MeshInstance3D = body.node
	var material: ShaderMaterial = body.material
	var ecef_from_solar: Basis = material.get_shader_parameter("ecef_from_local")
	var solar_from_ecef: Basis = ecef_from_solar.inverse()
	var ratio: float = float(planet.mesh.radius) * absf(planet.scale.x) / EARTH_LOCAL_RADIUS
	return {"position": planet.position + solar_from_ecef * Vector3(earth_pose.position) * ratio,
		"target": planet.position + solar_from_ecef * Vector3(earth_pose.target) * ratio,
		"up": (solar_from_ecef * Vector3(earth_pose.get("up", Vector3.UP))).normalized()}


static func earth_fixed_pose(solar_stage: Node, pose: Dictionary, reference_jd: float = NAN) -> Dictionary:
	# Convert once at departure (or the saved view's date), never reinterpret
	# fixed inertial endpoints against a newly rotating Earth each frame.
	var body: Dictionary = solar_stage.get_meta("solar_bodies")[2]
	var planet: MeshInstance3D = body.node
	var center: Vector3 = planet.position
	var ecef_from_solar: Basis = body.material.get_shader_parameter("ecef_from_local")
	if is_finite(reference_jd):
		center=Ephemeris.display_position(2,reference_jd,bool(solar_stage.get_meta("solar_true_distance")))
		ecef_from_solar=Orientation.body_basis(2,reference_jd).transposed()
	var ratio: float = EARTH_LOCAL_RADIUS/(float(planet.mesh.radius)*absf(planet.scale.x))
	return {"position":ecef_from_solar*(Vector3(pose.position)-center)*ratio,
		"target":ecef_from_solar*(Vector3(pose.target)-center)*ratio,
		"up":(ecef_from_solar*Vector3(pose.get("up",Vector3.UP))).normalized()}


static func interpolate_earth_flight(stage: Node, start: Dictionary, finish: Dictionary, amount: float, entering: bool) -> Dictionary:
	# Both endpoints are Earth-fixed. The solar camera follows the current
	# physical Earth pose; the geographic camera uses the same local path.
	var pose: Dictionary = EarthRegionFlight.globe_pose(start,finish,amount,entering)
	return pose if stage.scale_id=="earth" else earth_boundary_pose(stage,pose)


static func exit_pose(stage: Node, target_id: String) -> Dictionary:
	match stage.scale_id:
		"solar_system":
			if target_id == "galaxy":
				return {"position": stage.default_position * 1.25, "target": stage.default_target, "up": Vector3.UP}
		"earth":
			if target_id=="solar_system":
				return {"position": anchor_basis().y*15.0, "target": Vector3.ZERO}
		"atmosphere":
			if target_id=="earth":
				return {"position": Vector3(12.742,53.0916667,0), "target": Vector3.ZERO, "up": anchor_basis().inverse()*Vector3.UP}
	return {"position": stage.close_position, "target": stage.target_position, "up": Vector3.UP}


static func _orbit_mesh(index: int, jd: float, true_distance: bool, dashed: bool = false) -> ImmediateMesh:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var el: Array[float] = Ephemeris.elements(index, jd)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES if dashed else Mesh.PRIMITIVE_LINE_STRIP)
	if dashed:
		for segment: int in range(64):
			for half: int in range(2):
				var angle: float = TAU*(float(segment)+float(half)*0.5)/64.0
				mesh.surface_add_vertex(Ephemeris.display_vector(index, Ephemeris.orbital_point(el, angle), true_distance))
	else:
		for segment: int in range(257):
			mesh.surface_add_vertex(Ephemeris.display_vector(index, Ephemeris.orbital_point(el, TAU*segment/256.0), true_distance))
	mesh.surface_end()
	return mesh


static func set_solar_focus(stage: Node, index: int) -> void:
	if not stage.has_meta("solar_bodies"): return
	stage.set_meta("solar_focus_index", index)
	stage.set_meta("solar_transfer_projection",false)
	stage.set_meta("solar_camera_exploring",false)
	stage.set_meta("solar_lookaround",false)
	stage.camera.fov=50.0
	stage.set_meta("solar_subject_frame",-1)
	stage.set_meta("solar_natural_frame",-1)
	var bodies: Array = stage.get_meta("solar_bodies")
	for i: int in range(bodies.size()):
		var color: Color = Color(0.93,0.57,0.19) if i==index and bool(stage.get_meta("solar_orbit_overview",false)) else Color(.16,.30,.37) if i==index else Color(0.09,0.19,0.23)
		var material: StandardMaterial3D = bodies[i].orbit_material
		material.albedo_color = color
		material.emission = color
		material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if i==index else BaseMaterial3D.BLEND_MODE_ADD
		bodies[i].orbit.mesh = _orbit_mesh(i,float(stage.get_meta("solar_jd")),bool(stage.get_meta("solar_true_distance")),i==index and Ephemeris.position_source()=="DE440离线行星位置")
	_refresh_solar_orbit_aid(stage)
	_refresh_solar_de440_trajectory(stage)
	if stage.has_meta("solar_physical") and stage.has_meta("solar_history"):
		set_solar_view(stage,float(stage.get_meta("solar_jd")),bool(stage.get_meta("solar_true_distance")))


static func _refresh_solar_orbit_aid(stage: Node) -> void:
	var index: int = int(stage.get_meta("solar_focus_index",-1))
	var aid: MultiMeshInstance3D = stage.world_root.get_node_or_null("SelectedOrbitEqualTime") as MultiMeshInstance3D
	if index<0 or not bool(stage.get_meta("solar_orbit_overview",false)):
		if aid!=null: aid.hide()
		return
	if aid==null:
		aid = MultiMeshInstance3D.new()
		aid.name = "SelectedOrbitEqualTime"
		aid.material_override = _unlit(Color(1.0,0.68,0.29),0.0)
		aid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.world_root.add_child(aid)
	var epoch: float = float(stage.get_meta("solar_orbit_epoch",stage.get_meta("solar_jd")))
	var true_distance: bool = bool(stage.get_meta("solar_true_distance"))
	if aid.get_meta("index",-1)==index and aid.get_meta("epoch",-1.0)==epoch and aid.get_meta("true_distance",not true_distance)==true_distance:
		aid.show()
		return
	var elements: Array[float] = Ephemeris.elements(index,epoch)
	var orbit_radius: float = Ephemeris.display_vector(index,Vector3(elements[0],0,0),true_distance).length()
	var point_radius: float = clampf(orbit_radius*0.013,0.009,0.12)
	var markers: MultiMesh = MultiMesh.new()
	markers.transform_format = MultiMesh.TRANSFORM_3D
	markers.mesh = _sphere(1.0,10,6)
	markers.instance_count = 12
	for step: int in range(12):
		# Equal increments of mean anomaly represent equal intervals of one
		# osculating period. This is a frozen date reference, not 12 bodies.
		var anomaly: float = Ephemeris.eccentric_anomaly(TAU*float(step)/12.0,elements[1])
		var point: Vector3 = Ephemeris.display_vector(index,Ephemeris.orbital_point(elements,anomaly),true_distance)
		markers.set_instance_transform(step,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*point_radius),point))
	aid.multimesh = markers
	aid.set_meta("index",index)
	aid.set_meta("epoch",epoch)
	aid.set_meta("true_distance",true_distance)
	aid.show()


static func _de440_trajectory_mesh(index: int, jd: float, true_distance: bool) -> ImmediateMesh:
	var window: Array[float] = Ephemeris.trajectory_window(index,jd)
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for segment: int in range(257):
		var date: float = lerpf(window[0],window[1],float(segment)/256.0)
		mesh.surface_add_vertex(Ephemeris.display_position(index,date,true_distance))
	mesh.surface_end()
	return mesh


static func _refresh_solar_de440_trajectory(stage: Node) -> void:
	var index: int = int(stage.get_meta("solar_focus_index",-1))
	var trajectory: MeshInstance3D = stage.world_root.get_node_or_null("SelectedDE440Trajectory") as MeshInstance3D
	if index < 0 or not bool(stage.get_meta("solar_orbit_overview",false)) or Ephemeris.position_source() != "DE440离线行星位置":
		if trajectory != null: trajectory.hide()
		return
	var jd: float = float(stage.get_meta("solar_jd"))
	var true_distance: bool = bool(stage.get_meta("solar_true_distance"))
	if trajectory == null:
		trajectory = MeshInstance3D.new()
		trajectory.name = "SelectedDE440Trajectory"
		trajectory.material_override = _unlit(Color(0.16,0.72,0.94),0.0)
		trajectory.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.world_root.add_child(trajectory)
	var last_epoch: float = float(trajectory.get_meta("epoch",-1.0))
	var period_days: float = Ephemeris.PERIOD_YEARS[index]*365.25
	if trajectory.get_meta("index",-1)==index and trajectory.get_meta("true_distance",not true_distance)==true_distance and jd >= float(trajectory.get_meta("first_jd",INF)) and jd <= float(trajectory.get_meta("last_jd",-INF)) and absf(jd-last_epoch)<minf(365.25,period_days*0.25):
		trajectory.show()
		return
	var window: Array[float] = Ephemeris.trajectory_window(index,jd)
	trajectory.mesh = _de440_trajectory_mesh(index,jd,true_distance)
	trajectory.set_meta("index",index)
	trajectory.set_meta("epoch",jd)
	trajectory.set_meta("first_jd",window[0])
	trajectory.set_meta("last_jd",window[1])
	trajectory.set_meta("true_distance",true_distance)
	trajectory.show()


static func set_solar_view(stage: Node, jd: float, true_distance: bool, exposure_days: float = 0.0) -> void:
	if not stage.has_meta("solar_bodies"): return
	var rebuild: bool = true_distance != bool(stage.get_meta("solar_true_distance")) or absf(jd-float(stage.get_meta("solar_orbit_epoch", 0.0))) > 365.25
	stage.set_meta("solar_jd", jd)
	stage.set_meta("solar_true_distance", true_distance)
	# AU mode has a smaller outer displayed orbit than the readable overview.
	# Fit its own extent rather than leave the expanded overview camera in place.
	if bool(stage.get_meta("solar_cinematic_overview",{}).get("true_distance",not true_distance))!=true_distance:
		solar_overview_pose(stage,jd,true_distance)
	var bodies: Array = stage.get_meta("solar_bodies")
	var orbit_focus: bool = bool(stage.get_meta("solar_orbit_overview",false))
	var focus_index: int = int(stage.get_meta("solar_focus_index",-1))
	for index: int in range(bodies.size()):
		var body: Dictionary = bodies[index]
		var p: Vector3 = Ephemeris.display_position(index, jd, true_distance)
		body.node.position = p
		body.orbit.show()
		body.node.basis = Orientation.body_basis(index,jd)
		body.material.set_shader_parameter("rotation_exposure_turns", exposure_days/Orientation.rotation_days(index))
		body.material.set_shader_parameter("planet_center", p)
		body.material.set_shader_parameter("sun_direction",-Ephemeris.display_position(index,jd,true).normalized())
		if index == 2:
			body.material.set_shader_parameter("sun_direction", -p.normalized())
			body.material.set_shader_parameter("ecef_from_local", Orientation.body_basis(2,jd).transposed())
		# True-distance mode uses smaller, still exaggerated markers for inner planets.
		var size_factor: float = Ephemeris.body_display_scale(index,true_distance) * (0.16 if orbit_focus and index!=focus_index else 1.0)
		body.node.scale = Vector3.ONE * size_factor
		if index==5:
			body.material.set_shader_parameter("ring_normal", Orientation.body_basis(5,jd).y)
			body.material.set_shader_parameter("ring_inner", 0.0 if true_distance else 0.93*1.24)
			body.material.set_shader_parameter("ring_outer", 0.0 if true_distance else 0.93*2.25)
		body.label.position = p + Vector3(0, body.label_height*size_factor+0.1,0)
		body["name_visible"] = (not true_distance or index >= 4 or index==focus_index) and (not orbit_focus or index==focus_index)
		body.label.hide()
		body.label.scale = Vector3.ONE*clampf(stage.camera.position.distance_to(body.label.position)*0.035,0.03,4.0)
		for extra: MeshInstance3D in body.extras:
			extra.position = p
			if index==5: extra.basis = Orientation.body_basis(5,jd)
			extra.scale = Vector3.ONE * size_factor
			var material: ShaderMaterial = extra.material_override
			material.set_shader_parameter("planet_center", p)
			material.set_shader_parameter("sun_direction", -p.normalized())
		# Atmosphere/ring shader radii are in world units; hide their exaggerated
		# auxiliaries in true-distance mode rather than misrepresenting geometry.
		for extra: MeshInstance3D in body.extras: extra.visible = not true_distance and (not orbit_focus or index==focus_index)
		if rebuild: body.orbit.mesh = _orbit_mesh(index, jd, true_distance,index==focus_index and Ephemeris.position_source()=="DE440离线行星位置")
		if index == 2:
			stage.target_position = p
			stage.close_position = p + Vector3(0,0.4,1.1)
	var sun: MeshInstance3D = stage.world_root.get_node("Sun_AuthoredPhotosphere")
	sun.position=Vector3.ZERO
	sun.basis = Orientation.sun_basis(jd)
	sun.scale = Vector3.ONE * (0.009 if orbit_focus and true_distance else 0.035 if true_distance else 0.21 if orbit_focus else 1.0)
	var corona: MeshInstance3D = stage.world_root.get_node("SolarCorona_Illustration")
	corona.position=Vector3.ZERO; corona.scale=Vector3.ONE
	corona.visible = not true_distance and not orbit_focus
	if rebuild:
		stage.set_meta("solar_orbit_epoch", jd)
		_refresh_solar_orbit_aid(stage)
	_refresh_solar_de440_trajectory(stage)
	_update_solar_history(stage,jd,true_distance,not orbit_focus)
	EarthSeasonOrbit.update(stage)
	_update_solar_moon(stage,jd,true_distance,exposure_days)
	SolarPhysical.update(stage,jd)
	SolarSatellites.update(stage,jd)



static func _build_solar_moon(stage: Node) -> void:
	var material: ShaderMaterial = _material(stage,MOON_SHADER)
	material.set_shader_parameter("moon_map",stage.textures.moon)
	# Keep the real lunar/Earth radius ratio. Local separation is explicitly
	# compressed for overview legibility; never modify its orbital phase/time.
	var radius: float = 0.38*Orientation.MOON_RADIUS_KM/Ephemeris.RADII_KM[2]
	var node: MeshInstance3D = stage.add_mesh(_sphere(radius,64,32),material)
	node.name = "SolarMoon_LROC_LocalDistanceCompressed"
	var orbit: MeshInstance3D = _line(stage,PackedVector3Array([Vector3.ZERO,Vector3.ONE]),Color(0.17,0.23,0.25),"SolarMoonDateTrajectory_LocalDistanceCompressed")
	stage.set_meta("solar_moon",{"node":node,"orbit":orbit,"radius":radius,"orbit_epoch":-1.0,"true_distance":false})
	_update_solar_moon(stage,Ephemeris.DEFAULT_JD,false)


static func solar_moon_offset(jd: float, true_distance: bool) -> Vector3:
	# J2000 ecliptic -> same world frame as the planets. Even in the global
	# AU-distance mode this local Earth-Moon group is enlarged and declared.
	return Orientation.moon_position_km(jd)*(1.25/Orientation.MOON_A_KM)*Ephemeris.body_display_scale(2,true_distance)


static func _update_solar_moon(stage: Node, jd: float, true_distance: bool, exposure_days: float = 0.0) -> void:
	if not stage.has_meta("solar_moon"): return
	var data: Dictionary = stage.get_meta("solar_moon")
	var earth: MeshInstance3D = stage.get_meta("solar_bodies")[2].node
	var focus: int = int(stage.get_meta("solar_focus_index",-1))
	var local_scale: float = Ephemeris.body_display_scale(2,true_distance)
	var factor: float = local_scale*(0.16 if bool(stage.get_meta("solar_orbit_overview",false)) and focus!=2 else 1.0)
	var physical: bool = SolarPhysical.owner(stage)==2
	var moon_scale: float = float(earth.mesh.radius)/Ephemeris.RADII_KM[2] if physical else 1.25/Orientation.MOON_A_KM
	if physical: factor=1.0
	data.node.position = earth.position+Orientation.moon_position_km(jd)*moon_scale*factor
	data.node.basis = Orientation.moon_basis(jd)
	data.node.scale = Vector3.ONE*factor
	data.node.visible = earth.visible and (not bool(stage.get_meta("solar_orbit_overview",false)) or focus==2)
	var material: ShaderMaterial = data.node.material_override
	material.set_shader_parameter("planet_center",data.node.position)
	material.set_shader_parameter("sun_direction",Orientation.sun_direction(jd))
	material.set_shader_parameter("rotation_exposure_turns",exposure_days*float(Orientation.Lunar.Data.ROTATION.polynomials[2][1])/360.0)
	data.orbit.position = earth.position
	data.orbit.scale = Vector3.ONE*factor
	data.orbit.visible = data.node.visible
	if absf(jd-float(data.orbit_epoch))>Orientation.MOON_SIDEREAL_DAYS or bool(data.get("physical",not physical))!=physical:
		var mesh: ImmediateMesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k: int in range(65):
			var date: float = clampf(jd+(float(k)/64.0-.5)*Orientation.MOON_SIDEREAL_DAYS,Ephemeris.START_JD,Ephemeris.END_JD)
			mesh.surface_add_vertex(Orientation.moon_position_km(date)*moon_scale)
		mesh.surface_end()
		data.orbit.mesh=mesh; data.orbit_epoch=jd
	data.jd=jd
	data.physical=physical


static func _update_solar_history(stage: Node, jd: float, true_distance: bool, visible: bool) -> void:
	if not stage.has_meta("solar_history"): return
	var data: Dictionary = stage.get_meta("solar_history")
	data.node.visible = visible and not true_distance
	if not data.node.visible: return
	if absf(jd-float(data.jd))<1.0 and bool(data.distance)==true_distance: return
	var mesh: ImmediateMesh = ImmediateMesh.new()
	for index: int in range(8):
		var span: float = minf(Ephemeris.PERIOD_YEARS[index]*365.25*.14,720.0)
		var first: float = maxf(Ephemeris.START_JD,jd-span)
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k: int in range(41):
			var amount: float = float(k)/40.0
			mesh.surface_set_color(Color(.43,.68,.85,pow(amount,1.8)*.55))
			mesh.surface_add_vertex(Ephemeris.display_position(index,lerpf(first,jd,amount),true_distance))
		mesh.surface_end()
	data.node.mesh = mesh
	data.jd = jd; data.distance = true_distance


static func set_solar_moon_focus(stage: Node, enabled: bool) -> void:
	if not stage.has_meta("solar_moon"): return
	var seasons: Dictionary = stage.get_meta("earth_season_orbit",{})
	var season_active: bool = bool(seasons.get("active",false)) and bool(seasons.get("symbols",false))
	var active: bool = enabled and not season_active
	stage.set_meta("solar_moon_focus",active)
	# The physical Earth-Moon frame already separates local and distant space.
	# No body needs to be hidden to make the lunar neighbourhood believable.


static func animate(stage: Node, time: float) -> void:
	if stage.scale_id=="universe": Cosmic.animate(stage,time)
	elif stage.scale_id=="galaxy":
		var phase: float = time*.035
		stage.target_position = Basis(Vector3.UP,-phase)*Galactic.sun_position()
		stage.close_position = stage.target_position+Vector3(0,.5,1.0)
		stage.world_root.get_node("SolarSystemSemanticAnchor").position = stage.target_position


static func _line(stage: Node, points: PackedVector3Array, color: Color, label: String) -> MeshInstance3D:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point: Vector3 in points: mesh.surface_add_vertex(point)
	mesh.surface_end()
	var node: MeshInstance3D = stage.add_mesh(mesh,_unlit(color))
	node.name = label
	return node

static func _earth_moon(stage: Node) -> void:
	stage.semantic_size_m = 8.0e8
	stage.default_position = Vector3(12,9,15)*8.0
	stage.default_target = Vector3.ZERO
	stage.close_position = Vector3(0,1.1,3)
	stage.camera.far = 800.0
	stage.target_radius = 1.0
	stage.set_meta("scientific_category","lunar_series_and_iau_rotation")
	stage.set_meta("content_summary","选择地球看昼夜与倾斜的自转轴，选择月球看同步自转。\n切换至日附近日期，比较南北半球昼长。")
	stage.set_meta("scientific_label","地月观察台 · 月轨道摄动近似 / IAU月面朝向\n距离与平均半径同比，遮光按物理距离计算；均匀太阳圆盘，无大气折射红月或食预报。")
	var sun: Vector3 = Orientation.sun_direction(Ephemeris.DEFAULT_JD)
	var globe: MeshInstance3D = stage.add_mesh(_sphere(1.0,160,80),_earth_material(stage,Basis.IDENTITY,Vector3.ZERO,sun))
	globe.name = "ObservatoryEarth"
	_air(stage,1.0,Vector3.ZERO,sun)
	var cloud_mat: ShaderMaterial = _material(stage,CLOUD_SHADER)
	cloud_mat.set_shader_parameter("cloud_map",stage.textures.earth_clouds)
	cloud_mat.set_shader_parameter("layer_opacity",0.62)
	cloud_mat.render_priority = 5
	var cloud: MeshInstance3D = stage.add_mesh(_sphere(1.001,160,80),cloud_mat)
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var moon_mat: ShaderMaterial = _material(stage,MOON_SHADER)
	moon_mat.set_shader_parameter("moon_map",stage.textures.moon)
	var moon: MeshInstance3D = stage.add_mesh(_sphere(Orientation.MOON_RADIUS_KM/Ephemeris.RADII_KM[2],96,48),moon_mat)
	moon.name = "Moon_LROC"
	var axis: MeshInstance3D = _line(stage,PackedVector3Array([Vector3(0,-1.55,0),Vector3(0,1.55,0)]),Color(0.62,0.79,0.89),"EarthSpinAxis")
	var equator_points: PackedVector3Array = []
	for i: int in range(129): equator_points.append(Vector3(sin(TAU*i/128.0),0,cos(TAU*i/128.0))*1.018)
	var equator: MeshInstance3D = _line(stage,equator_points,Color(0.23,0.57,0.64),"EarthEquator")
	var orbit: MeshInstance3D = _line(stage,PackedVector3Array([Vector3.ZERO,Vector3.ONE]),Color(0.15,0.25,0.3),"MoonDateTrajectory")
	var axis_label: Label3D = Label3D.new()
	axis_label.text = "N · 自转轴"
	axis_label.font_size = 34; axis_label.pixel_size = 0.004
	axis_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stage.world_root.add_child(axis_label)
	stage.set_meta("lunar",{"earth":globe,"cloud":cloud,"moon":moon,"axis":axis,"equator":equator,"orbit":orbit,"label":axis_label,"orbit_epoch":0.0,"true_distance":false})
	_stars(stage,1300,180,260,false)
	set_lunar_view(stage,Ephemeris.DEFAULT_JD,false)

static func moon_display_position(jd: float, _true_distance: bool) -> Vector3:
	return Orientation.moon_position_km(jd)/Ephemeris.RADII_KM[2]

static func set_lunar_view(stage: Node, jd: float, true_distance: bool, exposure_days: float = 0.0) -> void:
	if not stage.has_meta("lunar"): return
	var data: Dictionary = stage.get_meta("lunar")
	var sun: Vector3 = Orientation.sun_direction(jd)
	var basis: Basis = Orientation.body_basis(2,jd)
	data.earth.material_override.set_shader_parameter("ecef_from_local",basis.transposed())
	data.cloud.material_override.set_shader_parameter("ecef_from_local",basis.transposed())
	data.earth.material_override.set_shader_parameter("rotation_exposure_turns",exposure_days/Orientation.rotation_days(2))
	data.cloud.material_override.set_shader_parameter("rotation_exposure_turns",exposure_days/Orientation.rotation_days(2))
	for material: ShaderMaterial in stage.materials: material.set_shader_parameter("sun_direction",sun)
	data.moon.position = moon_display_position(jd,true_distance)
	data.moon.basis = Orientation.moon_basis(jd)
	data.moon.material_override.set_shader_parameter("planet_center",data.moon.position)
	data.moon.material_override.set_shader_parameter("rotation_exposure_turns",exposure_days*float(Orientation.Lunar.Data.ROTATION.polynomials[2][1])/360.0)
	var eclipse: Dictionary = Eclipse.sample(jd)
	for material: ShaderMaterial in stage.materials:
		if material.shader not in [SURFACE_SHADER,CLOUD_SHADER,AIR_SHADER,MOON_SHADER]: continue
		var lunar_surface: bool = material.shader == MOON_SHADER
		material.set_shader_parameter("eclipse_enabled",true)
		material.set_shader_parameter("eclipse_sun_km",eclipse.sun_km)
		material.set_shader_parameter("eclipse_blocker_km",Vector3.ZERO if lunar_surface else eclipse.moon_km)
		material.set_shader_parameter("eclipse_blocker_radius_km",Ephemeris.RADII_KM[2] if lunar_surface else Orientation.MOON_RADIUS_KM)
		material.set_shader_parameter("eclipse_body_km",eclipse.moon_km if lunar_surface else Vector3.ZERO)
		material.set_shader_parameter("eclipse_display_center",data.moon.position if lunar_surface else Vector3.ZERO)
		material.set_shader_parameter("eclipse_km_per_unit",Ephemeris.RADII_KM[2])
	stage.set_meta("eclipse_geometry",eclipse)
	data.axis.basis = basis
	data.equator.basis = basis
	data.label.position = basis.y*1.7
	if absf(jd-float(data.orbit_epoch))>1.0 or true_distance!=bool(data.true_distance):
		var mesh: ImmediateMesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k: int in range(257):
			var date: float=clampf(jd+(float(k)/256.-.5)*Orientation.MOON_SIDEREAL_DAYS,Ephemeris.START_JD,Ephemeris.END_JD)
			mesh.surface_add_vertex(moon_display_position(date,true_distance))
		mesh.surface_end()
		data.orbit.mesh = mesh
		data.orbit_epoch = jd
		data.true_distance = true_distance
	stage.default_position = (sun.rotated(Vector3.UP,0.65)*19.0+Vector3.UP*11.0)*7.5
	data.label.scale = Vector3.ONE*clampf(stage.camera.position.distance_to(data.label.position)*0.06,0.06,5.0)

static func set_earth_daylight(stage: Node, jd: float) -> void:
	# Geographic camera/anchor stay Earth-fixed; rotate illumination in this frame.
	var sun: Vector3 = Orientation.sun_ecef(jd)
	for material: ShaderMaterial in stage.materials: material.set_shader_parameter("sun_direction",sun)
	EarthDaylight.update(stage,jd)
