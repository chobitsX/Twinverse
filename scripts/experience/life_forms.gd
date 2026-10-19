extends RefCounted
## Original procedural teaching assets. Morphotypes, not scanned/validated species.

static func material(color: Color, roughness: float = 0.72) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

static func mesh(parent: Node3D, shape: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

static func ellipsoid(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 20
	sphere.rings = 12
	var node: MeshInstance3D = mesh(parent, sphere, mat, at)
	node.scale = size
	return node

static func segment(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material, taper: float = 0.65) -> MeshInstance3D:
	var shape: CylinderMesh = CylinderMesh.new()
	shape.height = start.distance_to(end)
	shape.bottom_radius = radius
	shape.top_radius = radius*taper
	shape.radial_segments = 8
	var node: MeshInstance3D = mesh(parent, shape, mat, (start+end)*0.5)
	var direction: Vector3 = (end-start).normalized()
	node.quaternion = Quaternion(Vector3.UP,direction)
	return node

static func fin(parent: Node3D, points: Array[Vector3], mat: Material) -> MeshInstance3D:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(1,points.size()-1):
		for p: Vector3 in [points[0],points[index],points[index+1]]: surface.add_vertex(p)
	surface.generate_normals()
	return mesh(parent,surface.commit(),mat)

static func fish(kind: int) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ReefMorphotype_%d" % kind
	var colors: Array[Color] = [Color(0.82,0.70,0.12),Color(0.13,0.58,0.75),Color(0.65,0.79,0.82)]
	var mat: StandardMaterial3D = material(colors[kind],0.38)
	var dark: StandardMaterial3D = material(Color(0.03,0.06,0.075),0.26)
	var fin_mat: StandardMaterial3D = material(colors[kind].darkened(0.12),0.5)
	fin_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var depth: float = 0.51 if kind == 0 else (0.3 if kind == 1 else 0.18)
	ellipsoid(root,Vector3(0.02,0,0),Vector3(0.85,depth,0.16),mat)
	ellipsoid(root,Vector3(0.40,-0.01,0),Vector3(0.2,0.13,0.12),mat)
	for side: float in [-1.0,1.0]:
		ellipsoid(root,Vector3(0.29,0.065,side*0.075),Vector3(0.045,0.046,0.022),dark)
		segment(root,Vector3(0.17,0.08,side*0.081),Vector3(0.12,-0.09,side*0.074),0.006,dark)
		fin(root,[Vector3(0.12,0,side*0.06),Vector3(-0.05,-0.13,side*0.22),Vector3(-0.06,-0.02,side*0.07)],fin_mat)
	fin(root,[Vector3(0.24,depth*0.34,0),Vector3(-0.05,depth*0.80,0),Vector3(-0.34,depth*0.35,0)],fin_mat)
	fin(root,[Vector3(0.08,-depth*0.32,0),Vector3(-0.19,-depth*0.66,0),Vector3(-0.34,-depth*0.29,0)],fin_mat)
	var tail: Node3D = Node3D.new()
	tail.name = "Tail"
	tail.position.x = -0.35
	root.add_child(tail)
	fin(tail,[Vector3(0.02,0,0),Vector3(-0.3,depth*0.56,0),Vector3(-0.2,0,0),Vector3(-0.3,-depth*0.56,0)],fin_mat)
	if kind == 1:
		for side: float in [-1.0,1.0]:
			segment(root,Vector3(-0.3,0.03,side*0.06),Vector3(0.31,0.045,side*0.076),0.013,material(Color(0.92,0.8,0.18)))
	return root

static func turtle() -> Node3D:
	var root: Node3D = Node3D.new()
	var shell: StandardMaterial3D = material(Color(0.22,0.31,0.16))
	var skin: StandardMaterial3D = material(Color(0.39,0.46,0.27))
	ellipsoid(root,Vector3.ZERO,Vector3(0.72,0.26,0.52),shell)
	ellipsoid(root,Vector3(0,-0.08,0),Vector3(0.68,0.11,0.49),material(Color(0.66,0.63,0.39)))
	ellipsoid(root,Vector3(0.42,0,0),Vector3(0.3,0.15,0.18),skin)
	for side: float in [-1.0,1.0]:
		ellipsoid(root,Vector3(0.49,0.048,side*0.066),Vector3(0.034,0.025,0.024),material(Color(0.025,0.035,0.02)))
		for front: float in [-1.0,1.0]:
			var flipper: MeshInstance3D = ellipsoid(root,Vector3(front*0.23,-0.08,side*0.35),Vector3(0.22,0.055,0.49 if front > 0 else 0.28),skin)
			flipper.rotation.y = side*front*0.5
	for row: int in range(5):
		ellipsoid(root,Vector3(-0.22+row*0.11,0.115,0),Vector3(0.1,0.035,0.15),material(Color(0.34,0.4,0.20)))
	return root

static func ray() -> Node3D:
	var root: Node3D = Node3D.new()
	var mat: StandardMaterial3D = material(Color(0.27,0.36,0.36),0.6)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ellipsoid(root,Vector3.ZERO,Vector3(0.55,0.085,0.36),mat)
	for side: float in [-1.0,1.0]:
		var wing: Node3D = Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		root.add_child(wing)
		fin(wing,[Vector3(0.3,0,0),Vector3(0,0.01,side*0.52),Vector3(-0.34,0,side*0.12)],mat)
		ellipsoid(root,Vector3(0.16,0.055,side*0.065),Vector3(0.055,0.036,0.045),material(Color(0.035,0.06,0.07)))
	segment(root,Vector3(-0.2,0,0),Vector3(-1.0,-0.025,0),0.019,mat,0.1)
	return root

static func deer() -> Node3D:
	var root: Node3D = Node3D.new()
	var fur: StandardMaterial3D = material(Color(0.42,0.24,0.10))
	var cream: StandardMaterial3D = material(Color(0.73,0.65,0.47))
	ellipsoid(root,Vector3(0,1.05,0),Vector3(1.2,0.62,0.43),fur)
	ellipsoid(root,Vector3(0.41,1.45,0),Vector3(0.36,0.85,0.32),fur).rotation.z = -0.3
	ellipsoid(root,Vector3(0.60,1.88,0),Vector3(0.55,0.25,0.23),fur)
	ellipsoid(root,Vector3(0.84,1.85,0),Vector3(0.1,0.12,0.18),material(Color(0.065,0.045,0.035)))
	ellipsoid(root,Vector3(-0.55,1.0,0),Vector3(0.2,0.36,0.34),cream)
	for side: float in [-1.0,1.0]:
		ellipsoid(root,Vector3(0.46,2.1,side*0.12),Vector3(0.16,0.38,0.1),fur).rotation.x = side*0.6
		ellipsoid(root,Vector3(0.65,1.94,side*0.107),Vector3(0.055,0.05,0.025),material(Color(0.02,0.018,0.012)))
		for fore: float in [-1.0,1.0]:
			var leg: Node3D = Node3D.new()
			leg.position = Vector3(fore*0.4,0.98,side*0.16)
			root.add_child(leg)
			segment(leg,Vector3.ZERO,Vector3(-0.04,-0.48,0),0.075,fur)
			segment(leg,Vector3(-0.04,-0.48,0),Vector3(0,-0.94,0),0.038,cream)
			ellipsoid(leg,Vector3(0.035,-0.93,0),Vector3(0.15,0.1,0.09),material(Color(0.08,0.065,0.046)))
			leg.set_meta("gait", fore*side)
	return root

static func bird() -> Node3D:
	var root: Node3D = Node3D.new()
	var mat: StandardMaterial3D = material(Color(0.37,0.42,0.46))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ellipsoid(root,Vector3.ZERO,Vector3(0.55,0.15,0.17),mat)
	ellipsoid(root,Vector3(0.24,0.045,0),Vector3(0.19,0.16,0.15),mat)
	segment(root,Vector3(0.3,0.03,0),Vector3(0.46,0.02,0),0.048,material(Color(0.55,0.36,0.16)),0.02)
	for side: float in [-1.0,1.0]:
		var wing: Node3D = Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		root.add_child(wing)
		fin(wing,[Vector3(0.10,0,side*0.07),Vector3(-0.12,0.02,side*0.72),Vector3(-0.4,0,side*0.62),Vector3(-0.22,0,side*0.09)],mat)
	return root

static func person(color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	var shirt: StandardMaterial3D = material(color)
	var trousers: StandardMaterial3D = material(Color(0.09,0.13,0.18))
	var skin: StandardMaterial3D = material(Color(0.64,0.43,0.29))
	ellipsoid(root,Vector3(0,1.12,0),Vector3(0.25,0.59,0.43),shirt)
	ellipsoid(root,Vector3(0,1.35,0),Vector3(0.28,0.18,0.57),shirt)
	segment(root,Vector3(0,1.33,0),Vector3(0,1.56,0),0.085,skin,1.0)
	ellipsoid(root,Vector3(0,1.65,0),Vector3(0.27,0.33,0.27),skin)
	ellipsoid(root,Vector3(-0.04,1.78,0),Vector3(0.28,0.15,0.29),trousers)
	for side: float in [-1.0,1.0]:
		for limb: int in range(2):
			var joint: Node3D = Node3D.new()
			joint.position = Vector3(0,0.9 if limb==0 else 1.35,side*(0.13 if limb==0 else 0.26))
			root.add_child(joint)
			segment(joint,Vector3.ZERO,Vector3(0,-0.78 if limb==0 else -0.58,0),0.09 if limb==0 else 0.065,trousers if limb==0 else shirt)
			joint.set_meta("gait",side*(1.0 if limb==0 else -1.0))
	return root

static func gait(root: Node3D, phase: float, amount: float) -> void:
	for child: Node in root.get_children():
		if child.has_meta("gait"): child.rotation.z = sin(phase+float(child.get_meta("gait"))*PI/2.0)*amount
	var tail: Node3D = root.get_node_or_null("Tail")
	if tail: tail.rotation.y = sin(phase)*0.32
	var left: Node3D = root.get_node_or_null("WingL")
	var right: Node3D = root.get_node_or_null("WingR")
	if left: left.rotation.x = sin(phase)*amount
	if right: right.rotation.x = -sin(phase)*amount
