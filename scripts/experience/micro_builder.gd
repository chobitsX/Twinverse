extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Author-created microstructure illustrations. Geometry is not a fish-specific scan.

const Oxygen = preload("res://scripts/core/oxygen_atom.gd")
const SURFACE: Shader = preload("res://shaders/micro_surface.gdshader")
const MEMBRANE: Shader = preload("res://shaders/micro_membrane.gdshader")
const DENSITY: Shader = preload("res://shaders/micro_density.gdshader")
const PARTICLES: Shader = preload("res://shaders/micro_particles.gdshader")
const SUPPORTED: Array[String] = ["cardiomyocyte", "mitochondrion", "molecule", "atom"]
const CRISTAE_COUNT: int = 19
const LIPID_COUNT: int = 10240
const MATRIX_PARTICLES: int = 8192
const PROTEIN_COUNT: int = 456
const O2_ENTRY_SCALE: float = 0.06
const O2_ENTRY_CAMERA_OFFSET: Vector3 = Vector3(0.26, 0.19, 0.72)
const MITO_ENTRY_SCALE: float = 0.18
const MITO_ENTRY_CAMERA_OFFSET: Vector3 = Vector3(0.38, 0.28, 1.05)


static func build(stage: Node) -> void:
	if stage.scale_id not in SUPPORTED:
		push_error("Unsupported micro scale: " + String(stage.scale_id))
		return
	stage.is_underwater = false
	stage.camera.near = 0.015
	stage.camera.far = 90.0
	stage.camera.fov = 44.0
	stage.environment.background_color = Color(0.045, 0.075, 0.086)
	stage.environment.ambient_light_color = Color(0.68, 0.77, 0.79)
	stage.environment.ambient_light_energy = 0.68
	stage.environment.ssao_enabled = true
	stage.environment.ssao_radius = 0.16
	stage.environment.ssao_intensity = 0.65
	stage.environment.glow_enabled = true
	stage.environment.glow_intensity = 0.16
	stage.environment.fog_enabled = true
	stage.environment.fog_density = 0.008
	stage.environment.fog_light_color = Color(0.045, 0.075, 0.086)
	var key: DirectionalLight3D = stage.add_sun(Vector3(-42, -30, -8), Color(1.0, 0.93, 0.86), 0.95)
	key.light_specular = 0.60
	var fill: DirectionalLight3D = stage.add_sun(Vector3(26, 148, 0), Color(0.66, 0.79, 0.83), 0.55)
	fill.shadow_enabled = false
	fill.light_specular = 0.25
	var stats: Dictionary = {"scale_id": stage.scale_id, "cristae": 0, "lipid_instances": 0,
		"protein_instances": 0, "particle_quads": 0, "mesh_triangles": 0, "scientific_status": "author_created_illustration"}
	stage.set_meta("micro_geometry_stats", stats)
	stage.set_meta("orbit_min_distance", 0.42)
	stage.set_meta("orbit_max_distance", 18.0)
	I18n.set_meta_text(stage,"scientific_label","科学示意 · 形状、颜色、密度与运动经观察简化\n不是 A. percula 活体扫描或分子动力学；过程速度读取参考ATP通量，粒子数不是分子计数。")
	match stage.scale_id:
		"cardiomyocyte": _build_cell(stage)
		"mitochondrion": _build_mitochondrion(stage)
		"molecule": _build_molecule(stage)
		"atom": _build_atom(stage)
	var attributes: CameraAttributesPractical = CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = stage.scale_id != "atom"
	attributes.dof_blur_far_distance = stage.default_position.distance_to(stage.default_target) + 1.0
	attributes.dof_blur_far_transition = 3.2
	attributes.dof_blur_near_enabled = stage.scale_id != "atom"
	attributes.dof_blur_near_distance = maxf(0.1, stage.default_position.distance_to(stage.default_target) - 2.5)
	attributes.dof_blur_near_transition = 2.2
	attributes.dof_blur_amount = 0.075 if stage.scale_id != "atom" else 0.035
	stage.camera.attributes = attributes
	stage.set_meta("micro_dof_enabled", stage.scale_id != "atom")
	stage.set_meta("micro_framing_label", "局部坐标的观察放大；颜色与标记密度为作者设计。")


static func _surface(stage: Node, color: Color, roughness: float = 0.43) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("tissue_color", color)
	material.set_shader_parameter("roughness_value", roughness)
	stage.materials.append(material)
	return material


static func _membrane(stage: Node, color: Color) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = MEMBRANE
	material.set_shader_parameter("membrane_color", color)
	stage.materials.append(material)
	return material


static func _build_mitochondrion(stage: Node) -> void:
	stage.semantic_size_m = 2.0e-6
	stage.default_position = Vector3(3.0, 2.65, 7.3)
	stage.default_target = Vector3.ZERO
	stage.target_position = Vector3(0.12, 0.08, 0.84)
	stage.target_radius = 0.13
	stage.close_position = stage.target_position + O2_ENTRY_CAMERA_OFFSET
	var shell_material: ShaderMaterial = _membrane(stage, Color(0.27, 0.49, 0.48, 0.18))
	shell_material.set_shader_parameter("rim_strength", 0.28)
	var inner_material: ShaderMaterial = _surface(stage, Color(0.39, 0.26, 0.23), 0.65)
	var fold_material: ShaderMaterial = _surface(stage, Color(0.64, 0.40, 0.34), 0.61)
	_add(stage, _ellipsoid_patch(Vector3(2.65, 1.10, 1.0), 64, 96, true), shell_material, "OuterMembraneCutaway")
	_add(stage, _ellipsoid_patch(Vector3(2.53, 0.99, 0.89), 56, 88, true), inner_material, "InnerBoundaryMembrane")
	# Cristae are thickened flattened invaginations with rounded end surfaces.
	for index: int in range(CRISTAE_COUNT):
		var x: float = (float(index) - 9.0) * 0.245
		var envelope: float = sqrt(maxf(0.10, 1.0 - pow(x / 2.55, 2.0)))
		var fold: ArrayMesh = _crista_mesh(x, envelope, float(index) * 0.61)
		_add(stage, fold, fold_material, "Crista_%02d" % index)
		var y: float = -0.24 * envelope
		var z: float = -0.53 * envelope
		var start: Vector3 = Vector3(x + _crista_bend(y, z, float(index) * 0.61), y, z)
		var end: Vector3 = Vector3(x, y, -0.89 * sqrt(maxf(0.01, 1.0 - pow(x / 2.53, 2.0) - pow(y / 0.99, 2.0))) - 0.025)
		var path: Array[Vector3] = []
		for step: int in range(9):
			var t: float = float(step) / 8.0
			path.append(start.lerp(end, t) + Vector3(0.018 * sin(t * PI), -0.02 * sin(t * PI), 0))
		var neck: ArrayMesh = _tube(path, 0.038, 16)
		_add(stage, neck, fold_material, "CristaJunction_%02d" % index)
	var lipid: ShaderMaterial = _surface(stage, Color(0.26, 0.41, 0.40), 0.75)
	var positions: Array[Transform3D] = []
	for index: int in range(LIPID_COUNT):
		# Paired display samples avoid latitude rows and crowded polar rings.
		# The number and spacing remain author choices, not a molecular count.
		var pair: int = index / 2
		var angle: float = fposmod(float(pair) * 2.399963229728653, TAU) / TAU * (TAU - 1.85) + 1.85
		angle = clampf(angle + sin(float(pair) * 45.13) * 0.035, 1.85, TAU)
		var axial: float = 1.0 - (float(pair) + 0.5) / float(LIPID_COUNT / 2) * 2.0
		var u: float = acos(clampf(axial + sin(float(pair) * 73.31) * 0.0025, -0.9999, 0.9999))
		var radius: Vector3 = Vector3(2.663, 1.113, 1.013) if index % 2 == 0 else Vector3(2.63, 1.08, 0.98)
		var p: Vector3 = Vector3(cos(u) * radius.x, sin(u) * cos(angle) * radius.y, sin(u) * sin(angle) * radius.z)
		positions.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0105), p))
	_instances(stage, _sphere(1.0, 12, 8), lipid, positions, "MembraneLipidHeads")
	var protein_positions: Array[Transform3D] = []
	for index: int in range(PROTEIN_COUNT):
		var fold_index: int = index / 24
		var phase: float = float(index % 24) / 24.0 * TAU
		var x: float = (float(fold_index) - 9.0) * 0.245
		var envelope: float = sqrt(maxf(0.1, 1.0 - pow(x / 2.55, 2.0)))
		var u: float = 0.62 + 0.09 * float(index % 5)
		var p: Vector3 = _crista_point(x, envelope, float(fold_index) * 0.61, u, phase)
		p.x += 0.014
		protein_positions.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.022, 0.018, 0.018)), p))
	_instances(stage, _sphere(1.0, 10, 6), _surface(stage, Color(0.66, 0.56, 0.40), 0.66), protein_positions, "CristaProteinDensityMarkers")
	_add_oxygen_model(stage, stage.target_position, O2_ENTRY_SCALE, "SelectedO2EntrySymbolNotPhysicalScale")
	_particles(stage, MATRIX_PARTICLES, Vector3(3.2, 1.5, 1.7), 0.012, Color(0.44, 0.66, 0.66, 0.075), 0.065, 913)
	var stats: Dictionary = stage.get_meta("micro_geometry_stats")
	stats.cristae = CRISTAE_COUNT
	stats.lipid_instances = LIPID_COUNT
	stats.protein_instances = PROTEIN_COUNT
	stats.oxygen_entry_symbols = 2
	stage.set_meta("micro_region_labels", ["外膜（局部透明）", "内边界膜", "嵴：内膜折入", "嵴连接颈", "基质", "蛋白密度标记（不是原子模型）"])


static func _build_cell(stage: Node) -> void:
	stage.semantic_size_m = 1.0e-4
	stage.default_position = Vector3(3.8, 2.8, 8.9)
	stage.default_target = Vector3.ZERO
	stage.target_position = Vector3(0.45, 0.17, 1.58)
	stage.target_radius = 0.34
	stage.close_position = stage.target_position + MITO_ENTRY_CAMERA_OFFSET
	I18n.set_meta_text(stage,"scientific_label","心肌细胞局部片段 · 科学示意\n肌原纤维、条纹与线粒体布置为作者化重建；非完整细胞或 A. percula 扫描。")
	var fiber_material: ShaderMaterial = _surface(stage, Color(0.58, 0.33, 0.30), 0.62)
	fiber_material.set_shader_parameter("fiber_strength", 1.0)
	var fibers: Array[Transform3D] = []
	for row: int in range(7):
		for column: int in range(9):
			var phase: float = float(row * 9 + column) * 2.399
			var y: float = (float(row) - 3.0) * 0.33 + 0.012 * sin(phase)
			var width: float = 1.0 - 0.30 * pow(absf(float(row) - 3.0) / 3.0, 2.0)
			var z: float = (float(column) - 4.0) * 0.30 * width + 0.016 * cos(phase)
			var length_envelope: float = sqrt(maxf(0.1, 1.0 - pow(y / 1.5, 2.0) - pow(z / 1.8, 2.0)))
			var size: Vector3 = Vector3(0.74 + 0.25 * length_envelope + 0.015 * sin(phase), 0.95 + 0.07 * cos(phase), 0.95 + 0.05 * sin(phase))
			fibers.append(Transform3D(Basis.IDENTITY.scaled(size), Vector3(0.04 * sin(phase), y, z)))
	_instances(stage, _myofibril_mesh(), fiber_material, fibers, "MyofibrilBundles")
	var mito_material: ShaderMaterial = _surface(stage, Color(0.30, 0.48, 0.43), 0.64)
	mito_material.set_shader_parameter("organelle_strength", 1.0)
	var mitochondria: Array[Transform3D] = []
	for index: int in range(48):
		var phase: float = float(index) * 2.399
		var y: float = (float(index % 6) - 2.5) * 0.34 + sin(phase) * 0.045
		var x: float = (float(index / 6) - 3.5) * 0.77 + sin(phase * 1.3) * 0.14
		var z: float = (1.42 - 0.25 * pow(absf(y), 2.0)) * (-1.0 if index % 3 == 0 else 1.0)
		if absf(x - stage.target_position.x) < 0.82 and absf(y - stage.target_position.y) < 0.36:
			z = -absf(z)
		var shape: Vector3 = Vector3(0.29 + 0.04 * sin(phase), 0.095, 0.12)
		mitochondria.append(Transform3D(Basis.IDENTITY.scaled(shape).rotated(Vector3.FORWARD, sin(phase) * 0.11), Vector3(x, y, z)))
	_instances(stage, _ellipsoid_patch(Vector3.ONE, 20, 36, false), mito_material, mitochondria, "InterfibrillarMitochondriaContext")
	# The selected organelle repeats the destination's cutaway silhouette and palette.
	var target_scale: Vector3 = Vector3.ONE * MITO_ENTRY_SCALE
	var selected_membrane: ShaderMaterial = _membrane(stage, Color(0.27, 0.49, 0.48, 0.18))
	selected_membrane.set_shader_parameter("rim_strength", 0.28)
	var shell: MeshInstance3D = _add(stage, _ellipsoid_patch(Vector3(2.65, 1.10, 1.0), 32, 48, true), selected_membrane, "SelectedMitochondrion")
	shell.position = stage.target_position
	shell.scale = target_scale
	var boundary: MeshInstance3D = _add(stage, _ellipsoid_patch(Vector3(2.53, 0.99, 0.89), 32, 48, true), _surface(stage, Color(0.39, 0.26, 0.23), 0.65), "SelectedMitoInnerBoundary")
	boundary.position = stage.target_position
	boundary.scale = target_scale
	var folds: ShaderMaterial = _surface(stage, Color(0.64, 0.40, 0.34), 0.61)
	for index: int in range(CRISTAE_COUNT):
		var x: float = (float(index) - 9.0) * 0.245
		var envelope: float = sqrt(maxf(0.10, 1.0 - pow(x / 2.55, 2.0)))
		var fold: MeshInstance3D = _add(stage, _crista_mesh(x, envelope, float(index) * 0.61), folds, "SelectedMitoCrista_%02d" % index)
		fold.position = stage.target_position
		fold.scale = target_scale
	var membrane: ShaderMaterial = _membrane(stage, Color(0.44, 0.43, 0.41, 0.045))
	membrane.set_shader_parameter("rim_strength", 0.18)
	_add(stage, _ellipsoid_patch(Vector3(3.65, 1.65, 1.70), 48, 64, true), membrane, "SarcolemmaContextCutaway")
	_particles(stage, 4096, Vector3(4.1, 1.8, 2.1), 0.014, Color(0.71, 0.56, 0.43, 0.07), 0.045, 829)
	stage.set_meta("micro_region_labels", ["肌原纤维束（组织示意）", "肌节条纹示意", "纤维间线粒体", "所选线粒体剖面"])
	stage.get_meta("micro_geometry_stats")["myofibrils"] = 63
	stage.get_meta("micro_geometry_stats")["sarcomere_bands_per_fiber"] = 17
	stage.get_meta("micro_geometry_stats")["mitochondria_context"] = 49


static func _build_molecule(stage: Node) -> void:
	stage.semantic_size_m = 2.0e-9
	stage.default_position = Vector3(1.5, 0.95, 4.4)
	stage.default_target = Vector3.ZERO
	stage.target_position = Vector3(0.60, 0, 0)
	stage.target_radius = 0.44
	stage.close_position = Vector3(0.90, 0.20, 0.90)
	_add_oxygen_model(stage, Vector3.ZERO, 1.0, "O2AtomicCenterSymbols")
	_particles(stage, 6144, Vector3(4.2, 3.1, 3.5), 0.010, Color(0.42, 0.70, 0.78, 0.035), 0.11, 384)
	I18n.set_meta_text(stage,"scientific_label","O₂ · 两个氧原子中心的结构符号\n球半径、连接棒与颜色不是电子云或实测外观；尺寸为局部示意，不显示未经核验的键长。")
	stage.set_meta("micro_region_labels", ["O₂ 双原子结构", "连接棒仅表示键连通", "进入概率密度教学视图"])
	stage.get_meta("micro_geometry_stats")["oxygen_centers"] = 2


static func _add_oxygen_model(stage: Node, origin: Vector3, display_scale: float, node_name: String) -> void:
	# One authored symbol at both display scales, not a physical size conversion.
	var oxygen: ShaderMaterial = _surface(stage, Color(0.58, 0.24, 0.19), 0.38)
	oxygen.set_shader_parameter("detail_strength", 0.0)
	var centers: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, origin + Vector3(-0.60, 0, 0) * display_scale),
		Transform3D(Basis.IDENTITY, origin + Vector3(0.60, 0, 0) * display_scale)]
	_instances(stage, _sphere(0.46 * display_scale, 48, 32), oxygen, centers, node_name)
	var bond: ShaderMaterial = _surface(stage, Color(0.71, 0.65, 0.51), 0.43)
	bond.set_shader_parameter("detail_strength", 0.0)
	for side: float in [-1.0, 1.0]:
		_add(stage, _tube([origin + Vector3(-0.60, side * 0.13, 0) * display_scale,
			origin + Vector3(0.60, side * 0.13, 0) * display_scale], 0.055 * display_scale, 16), bond, "BondOrderSymbol")


static func _build_atom(stage: Node) -> void:
	stage.semantic_size_m = 1.0e-10
	stage.default_position = Vector3(2.1, 1.1, 7.2)
	stage.default_target = Vector3.ZERO
	stage.target_position = Vector3.ZERO
	stage.target_radius = 0.20
	stage.close_position = Vector3(0.5, 0.35, 1.7)
	stage.environment.ssao_enabled = false
	stage.environment.background_color = Color(0.014, 0.025, 0.043)
	I18n.set_meta_text(stage,"scientific_label","中性氧 · 8个电子 · 1s² 2s² 2p⁴
孤立原子组成教学；云形使用类氢参考函数，不是O₂分子或氧原子的精确电子密度。")
	var volume: ShaderMaterial = ShaderMaterial.new()
	volume.shader = DENSITY
	stage.materials.append(volume)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * 12.0
	var cloud: MeshInstance3D = _add(stage, box, volume, "AtomicReferenceDensity")
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var marker: MeshInstance3D=_add(stage, _sphere(0.019,24,16), _surface(stage,Color(.97,.73,.37),.30), "OriginMarkerNotScaleNucleus")
	var nucleus: Node3D=Node3D.new()
	nucleus.name="Oxygen16NucleusEnlarged"
	stage.world_root.add_child(nucleus)
	var proton: ShaderMaterial=_surface(stage,Color(.9,.33,.13),.4)
	var neutron: ShaderMaterial=_surface(stage,Color(.18,.48,.74),.4)
	var bead: SphereMesh=_sphere(.13,24,16)
	for index: int in range(Oxygen.MASS_NUMBER):
		var z: float=1.-2.*(float(index)+.5)/16.
		var angle: float=float(index)*2.39996323
		var direction: Vector3=Vector3(sqrt(1.-z*z)*cos(angle),z,sqrt(1.-z*z)*sin(angle))
		var nucleon: MeshInstance3D=_add(stage,bead,proton if index%2==0 else neutron,"Proton" if index%2==0 else "Neutron")
		nucleon.reparent(nucleus)
		nucleon.position=direction*.29
		nucleon.set_meta("nucleon","proton" if index%2==0 else "neutron")
	nucleus.hide()
	stage.set_meta("oxygen_atom",{"cloud":cloud,"volume":volume,"nucleus":nucleus,"marker":marker,"mode":0,"section":false})
	stage.set_meta("micro_region_labels",["中性氧：1s² 2s² 2p⁴", "类氢参考形状；不是电子飞行路径", "核单独放大；尺度不可与云比较"])
	stage.get_meta("micro_geometry_stats")["density_samples"]=0


static func set_atom_view(stage: Node, mode: int, section: bool) -> void:
	if not stage.has_meta("oxygen_atom") or mode<0 or mode>=Oxygen.LABELS.size(): return
	var data: Dictionary=stage.get_meta("oxygen_atom")
	data.mode=mode; data.section=section and mode!=4
	data.volume.set_shader_parameter("orbital_mode",mode)
	data.volume.set_shader_parameter("section_view",data.section)
	data.cloud.visible=mode!=4
	data.marker.visible=mode!=4
	data.nucleus.visible=mode==4


static func _particles(stage: Node, count: int, extent: Vector3, size: float, color: Color, amplitude: float, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var transforms: Array[Transform3D] = []
	for index: int in range(count):
		var p: Vector3 = Vector3(rng.randf_range(-extent.x, extent.x), rng.randf_range(-extent.y, extent.y), rng.randf_range(-extent.z, extent.z))
		while (p / extent).length_squared() > 1.0:
			p = Vector3(rng.randf_range(-extent.x, extent.x), rng.randf_range(-extent.y, extent.y), rng.randf_range(-extent.z, extent.z))
		transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size * rng.randf_range(0.60, 1.75)), p))
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PARTICLES
	material.set_shader_parameter("marker_color", color)
	material.set_shader_parameter("motion_amplitude", amplitude)
	stage.materials.append(material)
	_instances(stage, quad, material, transforms, "SuspendedVisualMarkers", true)
	stage.get_meta("micro_geometry_stats")["particle_quads"] += count


static func _instances(stage: Node, mesh: Mesh, material: Material, transforms: Array[Transform3D], name_value: String, custom: bool = false) -> MultiMeshInstance3D:
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = custom
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
		if custom:
			multi.set_instance_custom_data(index, Color(fposmod(float(index) * 0.6180339, 1.0), 0, 0, 0.7 + 0.3 * sin(float(index))))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = name_value
	node.multimesh = multi
	node.material_override = material
	node.extra_cull_margin = 0.3
	stage.world_root.add_child(node)
	stage.get_meta("micro_geometry_stats")["mesh_triangles"] += _triangles(mesh) * transforms.size()
	return node


static func _add(stage: Node, mesh: Mesh, material: Material, name_value: String) -> MeshInstance3D:
	var node: MeshInstance3D = stage.add_mesh(mesh, material)
	node.name = name_value
	stage.get_meta("micro_geometry_stats")["mesh_triangles"] += _triangles(mesh)
	return node


static func _sphere(radius: float, radial: int, rings: int) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	return mesh


static func _triangles(mesh: Mesh) -> int:
	var count: int = 0
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var index_array: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertex_array: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		count += index_array.size() / 3 if not index_array.is_empty() else vertex_array.size() / 3
	return count


static func _ellipsoid_patch(radius: Vector3, rings: int, segments: int, cutaway: bool) -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var uv: PackedVector2Array = []
	var indices: PackedInt32Array = []
	var offset: float = 1.85 if cutaway else 0.0
	for row: int in range(rings + 1):
		var u: float = float(row) / float(rings) * PI
		for column: int in range(segments + 1):
			var v: float = offset + float(column) / float(segments) * (TAU - offset)
			vertices.append(Vector3(cos(u) * radius.x, sin(u) * cos(v) * radius.y, sin(u) * sin(v) * radius.z))
			uv.append(Vector2(float(column) / float(segments), float(row) / float(rings)))
	_grid_indices(indices, rings, segments)
	return _array_mesh(vertices, uv, indices, true)


static func _crista_mesh(x: float, envelope: float, phase: float) -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var uv: PackedVector2Array = []
	var indices: PackedInt32Array = []
	const RINGS: int = 24
	const SEGMENTS: int = 48
	for row: int in range(RINGS + 1):
		var u: float = float(row) / float(RINGS) * PI
		for column: int in range(SEGMENTS + 1):
			var v: float = float(column) / float(SEGMENTS) * TAU
			vertices.append(_crista_point(x, envelope, phase, u, v))
			uv.append(Vector2(float(column) / float(SEGMENTS), float(row) / float(RINGS)))
	_grid_indices(indices, RINGS, SEGMENTS)
	return _array_mesh(vertices, uv, indices, true)


static func _crista_point(x: float, envelope: float, phase: float, u: float, v: float) -> Vector3:
	var edge: float = 1.0 + 0.045 * sin(v * 3.0 + phase) + 0.025 * cos(v * 5.0 - phase)
	var y: float = sin(u) * cos(v) * 0.76 * envelope * edge
	var z: float = sin(u) * sin(v) * 0.68 * envelope * edge
	var bend: float = _crista_bend(y, z, phase)
	return Vector3(x + cos(u) * 0.034 + bend, y, z)


static func _crista_bend(y: float, z: float, phase: float) -> float:
	return 0.052 * sin(z * 6.0 + phase * 0.45) + 0.020 * sin(y * 7.7 + phase)


static func _myofibril_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var uv: PackedVector2Array = []
	var indices: PackedInt32Array = []
	const ROWS: int = 136
	const SIDES: int = 24
	for row: int in range(ROWS + 1):
		var t: float = float(row) / float(ROWS)
		var x: float = (t - 0.5) * 6.4
		var taper: float = smoothstep(0.0, 0.04, t) * smoothstep(0.0, 0.04, 1.0 - t)
		var center: Vector3 = Vector3(x, sin(t * TAU) * 0.025, sin(t * PI) * 0.035)
		for column: int in range(SIDES + 1):
			var v: float = float(column) / float(SIDES)
			var angle: float = v * TAU
			var radius: float = (0.11 + 0.002 * sin(t * TAU * 17.0)) * taper
			vertices.append(center + Vector3(0.0, cos(angle) * radius, sin(angle) * radius))
			uv.append(Vector2(v, t))
	_grid_indices(indices, ROWS, SIDES)
	return _array_mesh(vertices, uv, indices)


static func _tube(points: Array[Vector3], radius: float, segments: int) -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var uv: PackedVector2Array = []
	var indices: PackedInt32Array = []
	for row: int in range(points.size()):
		var direction: Vector3 = (points[mini(row + 1, points.size() - 1)] - points[maxi(row - 1, 0)]).normalized()
		var side: Vector3 = direction.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var up: Vector3 = side.cross(direction).normalized()
		for column: int in range(segments + 1):
			var angle: float = float(column) / float(segments) * TAU
			vertices.append(points[row] + (side * cos(angle) + up * sin(angle)) * radius)
			uv.append(Vector2(float(column) / float(segments), float(row) / float(points.size() - 1)))
	_grid_indices(indices, points.size() - 1, segments)
	return _array_mesh(vertices, uv, indices, true)


static func _grid_indices(indices: PackedInt32Array, rows: int, columns: int) -> void:
	for row: int in range(rows):
		for column: int in range(columns):
			var a: int = row * (columns + 1) + column
			var b: int = a + columns + 1
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))


static func _array_mesh(vertices: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array, reverse_winding: bool = false) -> ArrayMesh:
	# Ellipsoid and transported tube parameterizations run opposite to the fiber grid.
	# Godot front faces are clockwise; outward normals must agree with the winding.
	if reverse_winding:
		indices = indices.duplicate()
		indices.reverse()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.create_from(mesh, 0)
	tool.generate_normals()
	return tool.commit()


static func update_camera(stage: Node) -> void:
	var attributes: CameraAttributesPractical = stage.camera.attributes as CameraAttributesPractical
	if attributes == null:
		return
	var distance: float = stage.camera.position.distance_to(stage.target_position)
	attributes.dof_blur_far_distance = maxf(0.2, distance + 0.8)
	attributes.dof_blur_near_distance = maxf(0.05, distance - 2.0)


static func entry_pose(stage: Node, source_id: String) -> Dictionary:
	if stage.scale_id == "mitochondrion" and source_id == "cardiomyocyte":
		return {"position": MITO_ENTRY_CAMERA_OFFSET / MITO_ENTRY_SCALE, "target": Vector3.ZERO}
	if stage.scale_id == "molecule" and source_id == "mitochondrion":
		return {"position": O2_ENTRY_CAMERA_OFFSET / O2_ENTRY_SCALE, "target": Vector3.ZERO}
	var path: Array[String] = ["heart", "cardiomyocyte", "mitochondrion", "molecule", "atom"]
	var approaching: bool = path.find(source_id) < path.find(stage.scale_id)
	return {"position": stage.default_position * 1.7 if approaching else stage.close_position, "target": stage.default_target if approaching else stage.target_position}


static func exit_pose(stage: Node, target_id: String) -> Dictionary:
	if stage.scale_id == "mitochondrion" and target_id == "cardiomyocyte":
		return {"position": MITO_ENTRY_CAMERA_OFFSET / MITO_ENTRY_SCALE, "target": Vector3.ZERO}
	if stage.scale_id == "molecule" and target_id == "mitochondrion":
		return {"position": O2_ENTRY_CAMERA_OFFSET / O2_ENTRY_SCALE, "target": Vector3.ZERO}
	var path: Array[String] = ["heart", "cardiomyocyte", "mitochondrion", "molecule", "atom"]
	var descending: bool = path.find(target_id) > path.find(stage.scale_id)
	return {"position": stage.close_position if descending else stage.default_position * 1.7, "target": stage.target_position if descending else stage.default_target}
