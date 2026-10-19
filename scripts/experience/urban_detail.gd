extends RefCounted
## Original synthetic architecture and street furniture, authored in metres.
const Forms = preload("res://scripts/experience/life_forms.gd")
const Masonry = preload("res://shaders/urban_masonry.gdshader")
const WALL_COLORS: Array[Color] = [Color("915344"),Color("c2b59d"),Color("485967")]
const TRIM_COLORS: Array[Color] = [Color("c4b59a"),Color("a49e91"),Color("6b7e87")]
const RESIDENTIAL_WALLS: Array[Color] = [Color("9f9487"),Color("b29b84"),Color("8f9c93"),Color("b9a695"),Color("a9918e")]
const AWNING_COLORS: Array[Color] = [Color("35584f"),Color("596047"),Color("445566"),Color("785948"),Color("47656a")]
const Glass = preload("res://shaders/urban_glass.gdshader")

static func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	return Forms.mesh(parent,shape,mat,at)

static func building_materials(stage: Node, root: Node3D, cache: Dictionary, category: int = 0, variation: int = 0) -> void:
	root.set_meta("architecture_category",category)
	root.set_meta("architecture_variation",variation)
	for child: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		for index: int in range(mesh.mesh.get_surface_count()):
			var source: StandardMaterial3D = mesh.mesh.surface_get_material(index) as StandardMaterial3D
			if source==null: continue
			if source.resource_name=="WindowGlass":
				var key: String = "glass:%d" % source.get_instance_id()
				if not cache.has(key):
					var material: ShaderMaterial = ShaderMaterial.new()
					material.shader=Glass
					material.set_shader_parameter("glass_color",source.albedo_color)
					cache[key]=material
					stage.materials.append(material)
				mesh.set_surface_override_material(index,cache[key])
			elif source.resource_name in ["BuildingWall","ArchitecturalTrim","Awning"]:
				var key: String = "%s:%d:%d" % [source.resource_name,category,variation]
				if not cache.has(key):
					var tone: float = [.84,.92,1.,1.08,1.15][variation%5]
					if source.resource_name=="BuildingWall":
						var material: ShaderMaterial = ShaderMaterial.new()
						material.shader=Masonry
						var wall: Color = RESIDENTIAL_WALLS[variation%5] if category==1 else WALL_COLORS[category]*Color(tone,tone,tone,1.)
						material.set_shader_parameter("wall_color",wall)
						material.set_shader_parameter("joint_color",Color("777268") if category==0 else Color("38464f"))
						material.set_shader_parameter("finish_kind",category)
						cache[key]=material
					else:
						var material: StandardMaterial3D = source.duplicate() as StandardMaterial3D
						material.albedo_color=TRIM_COLORS[category] if source.resource_name=="ArchitecturalTrim" else AWNING_COLORS[variation%5]
						material.roughness=.82
						cache[key]=material
				mesh.set_surface_override_material(index,cache[key])

static func cache_solar_geometry(root: Node3D) -> void:
	# Read the largest upward triangle from the actual imported panel geometry.
	# This keeps teaching vectors consistent with Blender tilt and building rotation.
	var largest: float = 0.0
	for child: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		for slot: int in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.mesh.surface_get_material(slot)
			if material==null or material.resource_name!="SolarCells": continue
			var arrays: Array = mesh.mesh.surface_get_arrays(slot)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for triangle: int in range(indices.size()/3):
				var a: int = indices[triangle*3]
				var b: int = indices[triangle*3+1]
				var c: int = indices[triangle*3+2]
				var normal: Vector3 = (mesh.global_basis*(normals[a]+normals[b]+normals[c])).normalized()
				var area: float = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length()/2.0
				if normal.y>.5 and area>largest:
					largest = area
					root.set_meta("solar_normal_world",normal)
					root.set_meta("solar_anchor_world",mesh.to_global((vertices[a]+vertices[b]+vertices[c])/3.0))

static func prepare_car(root: Node3D, index: int) -> void:
	var wheels: Array[Node3D] = []
	for key: String in ["WheelFL","WheelFR","WheelRL","WheelRR"]:
		var wheel: Node3D = root.find_child(key,true,false) as Node3D
		if wheel!=null: wheels.append(wheel)
	root.set_meta("wheels",wheels)
	var paint: StandardMaterial3D
	for child: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		for slot: int in range(mesh.mesh.get_surface_count()):
			var source: StandardMaterial3D = mesh.mesh.surface_get_material(slot) as StandardMaterial3D
			if source==null or source.resource_name!="CarPaint": continue
			if paint==null:
				paint = source.duplicate() as StandardMaterial3D
				paint.albedo_color = [Color(.52,.53,.50),Color(.025,.065,.10),Color(.31,.045,.025),Color(.16,.21,.18),Color(.12,.13,.15),Color(.47,.31,.09)][index%6]
				paint.metallic = .34
			mesh.set_surface_override_material(slot,paint)

static func furniture(stage: Node) -> void:
	var wood: Material = Forms.material(Color(.23,.125,.051),.84)
	var metal: Material = Forms.material(Color(.035,.05,.046),.64)
	var stone: Material = Forms.material(Color(.38,.40,.34),.85)
	var leaves: Material = Forms.material(Color(.12,.22,.065),.89)
	var count: int = 0
	for x: float in [23.0,29.0,39.0,45.0]:
		for z: float in [30.9,35.1]:
			var bench: Node3D = Node3D.new()
			bench.name = "ParkBench%d" % count
			bench.position = Vector3(x,.36,z)
			bench.rotation.y = PI if z<33 else 0.0
			stage.world_root.add_child(bench)
			for slat: int in range(5):
				box(bench,Vector3(0,.46,(slat-2)*.105),Vector3(1.65,.055,.088),wood)
			for slat: int in range(4): box(bench,Vector3(0,.62+slat*.11,-.24),Vector3(1.65,.075,.045),wood)
			for side: float in [-1.0,1.0]:
				box(bench,Vector3(side*.59,.24,0),Vector3(.055,.48,.43),metal)
				box(bench,Vector3(side*.59,.66,-.26),Vector3(.045,.62,.045),metal)
			count += 1
	for x: float in [-27.0,27.0]:
		for z: float in [-9.0,9.0]:
			box(stage.world_root,Vector3(x,.48,z),Vector3(2.3,.64,.95),stone)
			for k: int in range(5): Forms.ellipsoid(stage.world_root,Vector3(x+(k-2)*.37,.94,z),Vector3(.60,.48,.66),leaves)
	stage.set_meta("street_furniture",{"benches":count,"planters":4})

static func park_lights(stage: Node, post_material: Material) -> void:
	# The existing road lamps reach the south edge of the park. Two low-cost,
	# shadowless fixtures illuminate its north walk without blocking the route.
	var root: Node3D = Node3D.new()
	root.name = "ParkLights"
	stage.world_root.add_child(root)
	var night_lamps: Array = stage.get_meta("night_lamps")
	for point: Vector3 in [Vector3(23,0,36.7),Vector3(43,0,36.7)]:
		var fixture: Node3D = Node3D.new()
		fixture.name = "ParkLight%d" % root.get_child_count()
		fixture.position = point
		root.add_child(fixture)
		Forms.segment(fixture,Vector3.ZERO,Vector3(0,4.1,0),.055,post_material)
		box(fixture,Vector3(0,4.17,0),Vector3(.7,.12,.55),post_material)
		var glow: StandardMaterial3D = Forms.material(Color(.65,.59,.43))
		glow.emission_enabled = true
		glow.emission = Color.BLACK
		Forms.ellipsoid(fixture,Vector3(0,4.04,0),Vector3(.47,.10,.36),glow)
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "WalkwayLight"
		light.position = Vector3(0,3.95,0)
		light.omni_range = 15.0
		light.light_color = Color(1.0,.78,.48)
		light.light_energy = 0.0
		light.shadow_enabled = false
		fixture.add_child(light)
		night_lamps.append({"light":light,"material":glow})
