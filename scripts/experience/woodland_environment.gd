extends RefCounted
const Deadwood = preload("res://scripts/experience/deadwood_observation.gd")
const Fungi = preload("res://scripts/experience/fungus_observation.gd")
const Browse = preload("res://scripts/experience/browse_observation.gd")
## Authored habitat geometry, not terrain/hydrology data. All animated surfaces use host time.
const Forms = preload("res://scripts/experience/life_forms.gd")
const GROUND = preload("res://shaders/woodland_ground.gdshader")
const FOLIAGE = preload("res://shaders/woodland_foliage.gdshader")
const WATER = preload("res://shaders/woodland_water.gdshader")
const FLOOR_COLOR = preload("res://assets/textures/woodland89/forrest_ground_01_diff_1k.jpg")
const FLOOR_NORMAL = preload("res://assets/textures/woodland89/forrest_ground_01_nor_gl_1k.jpg")
const FLOOR_ARM = preload("res://assets/textures/woodland89/forrest_ground_01_arm_1k.jpg")
const BARK_COLOR = preload("res://assets/textures/woodland89/bark_brown_02_diff_1k.jpg")
const BARK_NORMAL = preload("res://assets/textures/woodland89/bark_brown_02_nor_gl_1k.jpg")
const BARK_ARM = preload("res://assets/textures/woodland89/bark_brown_02_arm_1k.jpg")
const ROCK_COLOR = preload("res://assets/textures/woodland89/rock_surface_diff_1k.jpg")
const ROCK_NORMAL = preload("res://assets/textures/woodland89/rock_surface_nor_gl_1k.jpg")
const ROCK_ARM = preload("res://assets/textures/woodland89/rock_surface_arm_1k.jpg")
const WATER_Y: float = -.65

static func river_center(z: float) -> float:
	var distant_bend: float = 8.0*sin((z-5.0)*.07)*(1.0-smoothstep(-3.0,8.0,z))
	return -17.0+sin(z*.032)*5.0+sin(z*.011)*3.0+distant_bend

static func height_at(x: float,z: float) -> float:
	var distance: float = absf(x-river_center(z))
	var meadow: float = .6*sin(x*.047)*cos(z*.058)+.17*sin(x*.16+z*.075)
	var far: float = smoothstep(45.,175.,Vector2(x,z).length())
	var hills: float = far*(9.+8.*sin(x*.012+z*.008)*cos(z*.017)+4.*sin(z*.031+x*.014))
	var outer_bank: float = 9.5+far*20.+(1.0-smoothstep(-3.0,8.0,z))*(.9*sin(z*.23)+.45*sin(z*.41+1.7))
	return lerpf(WATER_Y-.7,meadow+hills,smoothstep(2.7,outer_bank,distance))

static func _axis(index: int) -> float:
	var a: float = index-100
	return a*1.25 if absf(a)<=48. else signf(a)*(60.+pow((absf(a)-48.)/52.,1.4)*300.)

static func _terrain(stage: Node) -> void:
	var surf: SurfaceTool = SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz: int in range(201):
		for ix: int in range(201):
			var x: float = _axis(ix)
			var z: float = _axis(iz)
			surf.set_uv(Vector2(x,z)*.5)
			surf.add_vertex(Vector3(x,height_at(x,z),z))
	for iz: int in range(200):
		for ix: int in range(200):
			var a: int = iz*201+ix
			for i: int in [a,a+1,a+201,a+1,a+202,a+201]: surf.add_index(i)
	surf.generate_normals()
	surf.generate_tangents()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GROUND
	material.set_shader_parameter("litter_color",FLOOR_COLOR)
	material.set_shader_parameter("litter_normal",FLOOR_NORMAL)
	material.set_shader_parameter("litter_arm",FLOOR_ARM)
	material.set_shader_parameter("bank_color",ROCK_COLOR)
	Forms.mesh(stage.world_root,surf.commit(),material).name = "WoodlandTerrain"
	var water: SurfaceTool = SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Sample the existing bed beneath the water. This is an authored depth tint,
	# not screen-space refraction, an added reflection pass or a flow solver.
	const WIDTH_SAMPLES: int=17
	for iz: int in range(241):
		var z: float = (iz-120)*3.0
		for ix: int in range(WIDTH_SAMPLES):
			var side: float=2.*float(ix)/float(WIDTH_SAMPLES-1)-1.
			var x: float=river_center(z)+side*(12.+smoothstep(45.,175.,absf(z))*18.)
			water.set_uv2(Vector2(maxf(0.,WATER_Y-height_at(x,z)),0.))
			water.add_vertex(Vector3(x,WATER_Y,z))
	for iz: int in range(240):
		for ix: int in range(WIDTH_SAMPLES-1):
			var a: int = iz*WIDTH_SAMPLES+ix
			for i: int in [a,a+1,a+WIDTH_SAMPLES,a+1,a+WIDTH_SAMPLES+1,a+WIDTH_SAMPLES]: water.add_index(i)
	water.generate_normals()
	var water_mat: ShaderMaterial = ShaderMaterial.new()
	water_mat.shader = WATER
	stage.materials.append(water_mat)
	Forms.mesh(stage.world_root,water.commit(),water_mat).name = "MeanderingRiver"

static func _pbr(color: Texture2D,normal: Texture2D,arm: Texture2D,scale_value: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = color
	mat.normal_enabled = true
	mat.normal_texture = normal
	mat.normal_scale = .65
	mat.ao_enabled = true
	mat.ao_texture = arm
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness_texture = arm
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE*scale_value
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat

static func _materials(root: Node,bark: Material,leaf: Material,rock: Material) -> void:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			for slot: int in range(child.mesh.get_surface_count()):
				var mat: Material = child.mesh.surface_get_material(slot)
				if mat.resource_name in ["Leaves","FernLeaves"]: child.set_surface_override_material(slot,leaf)
				elif mat.resource_name=="Bark": child.set_surface_override_material(slot,bark)
				elif mat.resource_name=="Rock": child.set_surface_override_material(slot,rock)
		_materials(child,bark,leaf,rock)

static func _plant(stage: Node,key: String,at: Vector2,size_value: float,angle: float,bark: Material,leaf: Material,rock: Material) -> Node3D:
	var node: Node3D = stage.assets[key].instantiate()
	node.position = Vector3(at.x,height_at(at.x,at.y),at.y)
	node.scale = Vector3.ONE*size_value
	node.rotation.y = angle
	if key.begins_with("broadleaf_"):
		node.add_to_group("woodland_background_trees")
		node.set_meta("canopy_variant", key)
	_materials(node,bark,leaf,rock)
	stage.world_root.add_child(node)
	return node

static func _grass(stage: Node,rng: RandomNumberGenerator,leaf: Material) -> void:
	var surf: SurfaceTool = SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade: int in range(8):
		var a: float = blade*2.39996
		var base: Vector3 = Vector3(cos(a),0,sin(a))*.075
		var side: Vector3 = Vector3(-sin(a),0,cos(a))*.009
		var mid: Vector3 = base+Vector3(cos(a)*.02,.105+blade*.006,sin(a)*.02)
		var tip: Vector3 = base+Vector3(cos(a)*.09,.17+blade*.011,sin(a)*.09)
		surf.set_color(Color(.24,.33,.085).lerp(Color(.48,.46,.22),float(blade%3)*.16))
		for v: Vector3 in [base-side,base+side,mid-side*.7,base+side,mid+side*.7,mid-side*.7,mid-side*.7,mid+side*.7,tip]: surf.add_vertex(v)
	surf.generate_normals()
	var transforms: Array[Transform3D] = []
	for k: int in range(12500):
		var x: float = rng.randf_range(-65,65)
		var z: float = rng.randf_range(-65,55)
		var elevation: float = height_at(x,z)
		if elevation<WATER_Y+.18 or Browse.reserved(x,z) or (Fungi.reserved(x,z) or Deadwood.reserved(x,z)): continue
		var patch: float = .5+.5*sin(x*.5+cos(z*.3))*cos(z*.42)
		if rng.randf()>patch*.8+.15: continue
		var size_value: float = rng.randf_range(.55,1.3)
		transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size_value),Vector3(x,elevation-.015,z)))
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = surf.commit()
	multi.instance_count = transforms.size()
	for i: int in range(transforms.size()): multi.set_instance_transform(i,transforms[i])
	var layer: MultiMeshInstance3D = MultiMeshInstance3D.new()
	layer.name = "Understory"
	layer.multimesh = multi
	layer.material_override = leaf
	stage.world_root.add_child(layer)
	stage.set_meta("grass_instances",transforms.size())

static func build(stage: Node) -> void:
	_terrain(stage)
	var bark: StandardMaterial3D = _pbr(BARK_COLOR,BARK_NORMAL,BARK_ARM,.6)
	var rock: StandardMaterial3D = _pbr(ROCK_COLOR,ROCK_NORMAL,ROCK_ARM,.7)
	var leaf: ShaderMaterial = ShaderMaterial.new()
	leaf.shader = FOLIAGE
	stage.materials.append(leaf)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 89012
	var tree_count: int = 0
	var tree_positions: Array[Vector2] = []
	# Keep the near clearing open while joining the groves across the far hillside.
	var groves: Array[Vector2] = [Vector2(-42,-35),Vector2(24,-39),Vector2(55,8),Vector2(-45,-115),Vector2(0,-60),Vector2(5,-130),Vector2(-29,-64),Vector2(-75,-105)]
	for k: int in range(160):
		var at: Vector2
		if k%4==0:
			at = Vector2(rng.randf_range(-130,130),rng.randf_range(-155,100))
		else:
			var angle: float = rng.randf()*TAU
			var radius: float = sqrt(rng.randf())*23.
			at = groves[(k/4)%groves.size()]+Vector2(cos(angle)*radius,sin(angle)*radius*.72)
		var x: float = at.x
		var z: float = at.y
		if height_at(x,z)<WATER_Y+.35 or at.length()<18 or Browse.reserved(x,z) or Fungi.reserved(x,z) or Deadwood.reserved(x,z): continue
		var clear: bool = true
		for previous: Vector2 in tree_positions:
			if previous.distance_to(at)<4.5: clear=false; break
		if not clear: continue
		var key: String = "broadleaf_a" if k%2==0 else "broadleaf_b"
		var tree: Node3D = _plant(stage,key,at,rng.randf_range(7.0,12.0),rng.randf()*TAU,bark,leaf,rock)
		tree.scale *= Vector3(rng.randf_range(.85,1.12),rng.randf_range(.9,1.1),rng.randf_range(.85,1.12))
		tree_positions.append(at)
		tree_count += 1
	# Frame the clearing with a few nearer trees, leaving actors and camera clear.
	for at: Vector2 in [Vector2(river_center(-16.)-11.5,-16),Vector2(-26,14),Vector2(19,-13),Vector2(23,11),Vector2(3,-22),Vector2(-2,22)]:
		_plant(stage,"broadleaf_a",at,8.5,rng.randf()*TAU,bark,leaf,rock)
		tree_positions.append(at)
		tree_count += 1
	# A few smaller, unnamed background trees break the even canopy along the bend.
	var river_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	river_rng.seed = 20703
	var riparian_trees: int = 0
	for at: Vector2 in [Vector2(river_center(-39.)-13.5,-39),Vector2(river_center(-33.)+13.,-33),Vector2(river_center(-21.)+13.4,-21)]:
		if height_at(at.x,at.y)<WATER_Y+.35 or at.length()<18 or Browse.reserved(at.x,at.y) or Fungi.reserved(at.x,at.y) or Deadwood.reserved(at.x,at.y): continue
		var separated: bool = true
		for previous: Vector2 in tree_positions:
			if previous.distance_to(at)<5.: separated=false; break
		if not separated: continue
		_plant(stage,"broadleaf_b",at,river_rng.randf_range(4.5,6.2),river_rng.randf()*TAU,bark,leaf,rock)
		tree_positions.append(at)
		tree_count += 1
		riparian_trees += 1
	var rocks: int = 0
	var ferns: int = 0
	for k: int in range(180):
		var at: Vector2 = Vector2(rng.randf_range(-52,52),rng.randf_range(-55,45))
		if height_at(at.x,at.y)<WATER_Y+.10 or at.length()<12 or Browse.reserved(at.x,at.y): continue
		if k%4==0:
			var stone: Node3D = _plant(stage,"rock_a" if k%8==0 else "rock_b",at,rng.randf_range(.3,1.1),rng.randf()*TAU,bark,leaf,rock)
			stone.position.y += .12*stone.scale.y
			rocks += 1
		else:
			_plant(stage,"fern_cluster",at,rng.randf_range(.65,1.35),rng.randf()*TAU,bark,leaf,rock)
			ferns += 1
	var riparian_ferns: int = 0
	for i: int in range(18):
		var z: float = [-47.,-46.,-39.,-36.,-34.,-28.,-27.,-25.,-21.,-20.,-18.,-16.,-13.,-12.,-9.,-7.,-5.,-3.][i]
		var side: float = -1. if i%4==0 else 1.
		var x: float = river_center(z)+side*river_rng.randf_range(10.7,13.4)
		var at: Vector2 = Vector2(x,z)
		if height_at(x,z)<WATER_Y+.14 or at.length()<14 or Browse.reserved(x,z) or Fungi.reserved(x,z) or Deadwood.reserved(x,z): continue
		_plant(stage,"fern_cluster",at,river_rng.randf_range(.8,1.45),river_rng.randf()*TAU,bark,leaf,rock)
		ferns += 1
		riparian_ferns += 1
	for at: Vector2 in [Vector2(14,-18),Vector2(-27,4),Vector2(7,-24)]:
		_plant(stage,"fallen_log",at,1.,rng.randf()*TAU,bark,leaf,rock)
	_grass(stage,rng,leaf)
	stage.set_meta("woodland_layout",{"trees":tree_count,"rocks":rocks,"ferns":ferns,"riparian_trees":riparian_trees,"riparian_ferns":riparian_ferns,"river_surface_y":WATER_Y,"scope":"authored habitat, no surveyed terrain or hydrology"})
