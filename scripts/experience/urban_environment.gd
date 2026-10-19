extends RefCounted
## Authored surroundings for the 240 m teaching district, not surveyed city data.
const Forms = preload("res://scripts/experience/life_forms.gd")
const Facade = preload("res://shaders/urban_context_facade.gdshader")
const Ground = preload("res://shaders/urban_context_ground.gdshader")
const SPACING: float = 96.0
const ROAD_LENGTH: float = 1600.0
const CROSSINGS: Array[float] = [-672,-576,-480,-384,-288,-192,0,192,288,384,480,576,672]
const GROVE_CENTERS: Array[Vector3] = [Vector3(-4,0,-15),Vector3(-3,0,12),Vector3(29,0,-22)]
const GROVE_OFFSETS: Array[Vector3] = [Vector3(-4.4,0,-3.8),Vector3(4.6,0,-2.4),Vector3(-3,0,4.3),Vector3(3.8,0,4.8)]
const PATH_CONTROLS: Array[Vector2] = [Vector2(-10,-42),Vector2(-10,-25),Vector2(-25,-19),Vector2(-25,2),Vector2(-25,19),Vector2(-13,30),Vector2(-2,30),Vector2(10,30),Vector2(22,20),Vector2(22,5),Vector2(22,-14),Vector2(10,-23),Vector2(10,-42)]

static func build(stage: Node, road: Material, pavement: Material) -> void:
	var root: Node3D = Node3D.new()
	root.name = "UrbanSurroundings"
	stage.world_root.add_child(root)
	stage.camera.far = 1800.0
	stage.environment.fog_density = .0015
	var ground: ShaderMaterial = ShaderMaterial.new()
	ground.shader = Ground
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(4000,4000)
	Forms.mesh(root,plane,ground,Vector3(0,-.051,0)).name = "ContinuousGround"
	var street_transforms: Array[Transform3D] = []
	var pavement_transforms: Array[Transform3D] = []
	var building_transforms: Array[Transform3D] = []
	var building_variations: Array[Color] = []
	var stepped_towers: int = 0
	var tallest_context_m: float = 0.0
	var green_transforms: Array[Transform3D] = []
	var green_path_transforms: Array[Transform3D] = []
	var green_blocks: int = 0
	var green_trees: int = 0
	var tree_transforms: Array[Transform3D] = []
	var trunk_transforms: Array[Transform3D] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 94016
	# The central two roads continue under their existing surface, with no gap.
	for axis: int in range(2):
		var rotation: Basis = Basis(Vector3.UP,axis*PI/2)
		for crossing: float in CROSSINGS:
			var at: Vector3 = Vector3(0,-.025,crossing)
			street_transforms.append(Transform3D(rotation.scaled_local(Vector3(ROAD_LENGTH,.05,12 if crossing==0 else 9)),rotation*at))
			var cuts: Array[float] = [-ROAD_LENGTH*.5]
			cuts.append_array(CROSSINGS)
			cuts.append(ROAD_LENGTH*.5)
			for section: int in range(cuts.size()-1):
				var left: float = cuts[section]+8
				var right: float = cuts[section+1]-8
				# Existing center sidewalks reach +/-120; cross streets start at +/-192.
				if crossing==0:
					if left<0 and right> -120: right = -120
					if right>0 and left<120: left = 120
				if right<=left: continue
				for side: float in [-1.0,1.0]:
					var central: bool = crossing==0
					var size: Vector3 = Vector3(right-left,.16 if central else .14,3.5 if central else 2.3)
					var position: Vector3 = Vector3((left+right)*.5,.08 if central else .02,crossing+side*(8 if central else 6))
					pavement_transforms.append(Transform3D(rotation.scaled_local(size),rotation*position))

	for x: int in range(-7,7):
		for z: int in range(-7,7):
			var center: Vector3 = Vector3((x+.5)*SPACING,0,(z+.5)*SPACING)
			# Keep the authored near district and all actor/camera/solar targets intact.
			if maxf(absf(center.x),absf(center.z))<80: continue
			if center.length()>720: continue
			# West and north greens break the background building wall into places.
			# It is part of this synthetic teaching layout, not mapped land use.
			var public_green: bool = x==-2 and z>=-2 and z<=1
			# Two north-side blocks turn the western green strip toward the skyline.
			# This is authored urban spacing, not mapped land use.
			public_green = public_green or (x==-1 and (z==-2 or z==-3))
			if public_green:
				green_blocks += 1
				var green_width: float = 80.0 if x==-1 else 84.0
				green_transforms.append(Transform3D(Basis.from_scale(Vector3(green_width,.08,84)),center+Vector3(0,-.02,0)))
				# Return to a real sidewalk; +/-96 are deliberately not cross streets.
				var near_center_road: bool = z in [-1,0]
				var path_basis: Basis = _green_layout(x,z).scaled_local(Vector3(1,1,40.0/42.0 if near_center_road else 1.0))
				green_path_transforms.append(Transform3D(path_basis,center))
			var block_style: float = float(posmod(x*11+z*7+absi(x*z)*3,4))/3.0
			for a: float in [-1.0,1.0]:
				for b: float in [-1.0,1.0]:
					var at: Vector3 = center+Vector3(a*22,0,b*22)
					if rng.randf()<.17: continue # scattered green courtyards
					var width: float = rng.randf_range(18,29)
					var depth: float = rng.randf_range(18,29)
					var height: float = rng.randf_range(9,27)
					if center.z<-230 and absf(center.x)<400 and rng.randf()<.33: height *= 2.0
					var category: int = 0 if center.z>0 else 2 if center.z< -230 and absf(center.x)<400 else 1
					var tint: Color = Color(rng.randf(),rng.randf(),float(category),block_style)
					# Consume the original seed stream so all other blocks keep their layout.
					if public_green: continue
					var stepped: bool = height>27.0
					var total_height: float = height*(lerpf(1.12,1.64,tint.r) if stepped else lerpf(.82,1.20,tint.r))
					tallest_context_m = maxf(tallest_context_m,total_height)
					var lower_height: float = total_height*lerpf(.46,.68,tint.g) if stepped else total_height
					building_transforms.append(Transform3D(Basis.from_scale(Vector3(width,lower_height,depth)),at+Vector3(0,lower_height*.5+.16,0)))
					building_variations.append(tint)
					if stepped:
						var upper_height: float = total_height-lower_height
						var upper_width: float = width*lerpf(.50,.74,tint.g)
						var upper_depth: float = depth*lerpf(.54,.78,tint.r)
						building_transforms.append(Transform3D(Basis.from_scale(Vector3(upper_width,upper_height,upper_depth)),at+Vector3(0,lower_height+upper_height*.5+.16,0)))
						building_variations.append(tint)
						stepped_towers += 1
					pavement_transforms.append(Transform3D(Basis.from_scale(Vector3(width+3,.14,depth+3)),at+Vector3(0,.07,0)))
			for side: float in [-1.0,1.0]:
				for k: int in range(3):
					var at: Vector3 = center+Vector3((k-1)*22,0,side*35)
					var height: float = rng.randf_range(4.5,7.0)
					if not public_green:
						trunk_transforms.append(Transform3D(Basis.from_scale(Vector3(.27,height*.6,.27)),at+Vector3(0,height*.3,0)))
						tree_transforms.append(Transform3D(Basis.from_scale(Vector3(height*.67,height*.57,height*.63)),at+Vector3(0,height*.73,0)))
			if public_green:
				var park_rng: RandomNumberGenerator = RandomNumberGenerator.new()
				park_rng.seed = 21000 + (x+7)*17 + (z+7)*131
				for index: int in range(12):
					# Three small groves leave open lawn rather than two uniform rows.
					var cluster: Vector3 = GROVE_CENTERS[index/4] + GROVE_OFFSETS[index%4]*(.65 if index>=8 else 1.0)
					cluster += Vector3(park_rng.randf_range(-.7,.7),0,park_rng.randf_range(-.7,.7))
					var at: Vector3 = center + _green_layout(x,z)*cluster
					var height: float = park_rng.randf_range(4.8,8.4)
					trunk_transforms.append(Transform3D(Basis.from_scale(Vector3(.32,height*.62,.32)),at+Vector3(0,height*.31,0)))
					tree_transforms.append(Transform3D(Basis.from_scale(Vector3(height*.73,height*.58,height*.68)),at+Vector3(0,height*.75,0)))
					green_trees += 1
	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3.ONE
	_batch(root,"ConnectedRoads",cube,street_transforms,road)
	_batch(root,"ContextPavements",cube,pavement_transforms,pavement)
	_batch(root,"PublicGreens",cube,green_transforms,Forms.material(Color(.19,.30,.13),.98))
	_batch(root,"PublicGreenPaths",_green_path_mesh(),green_path_transforms,pavement)
	var facade: ShaderMaterial = ShaderMaterial.new()
	facade.shader = Facade
	stage.materials.append(facade)
	_batch(root,"ContextBuildings",cube,building_transforms,facade,building_variations)
	_batch(root,"ContextTrunks",cube,trunk_transforms,Forms.material(Color(.15,.11,.07),.94))
	var crown: SphereMesh = SphereMesh.new()
	crown.radius = .5
	crown.height = 1.0
	crown.radial_segments = 8
	crown.rings = 5
	_batch(root,"ContextTrees",crown,tree_transforms,Forms.material(Color(.17,.25,.095),.95))
	stage.set_meta("urban_context",{"building_volumes":building_transforms.size(),"stepped_towers":stepped_towers,"tallest_context_m":tallest_context_m,"tree_crowns":tree_transforms.size(),"green_blocks":green_blocks,"green_trees":green_trees,"green_paths":green_path_transforms.size(),"road_length_m":ROAD_LENGTH,"ground_size_m":4000.0,"near_buildings":27,"surveyed":false})

static func _green_layout(x: int, z: int) -> Basis:
	var toward_high_z: bool = (x==-2 and z in [-1,1]) or (x==-1 and z==-3)
	var turn: float = PI if toward_high_z else 0.0
	var breadth: float = .88 if posmod(z,3)==0 else 1.08
	return Basis(Vector3.UP,turn).scaled_local(Vector3(breadth,1,1))

static func _green_path_mesh() -> ArrayMesh:
	# An asymmetric return loop has two entrances on the same actual sidewalk.
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	const SEGMENTS: int = 28
	for step: int in range(SEGMENTS+1):
		var curve: int = mini(step/7,3)
		var t: float = float(step-curve*7)/7.0
		var u: float = 1.0-t
		var a: Vector2 = PATH_CONTROLS[curve*3]
		var b: Vector2 = PATH_CONTROLS[curve*3+1]
		var c: Vector2 = PATH_CONTROLS[curve*3+2]
		var d: Vector2 = PATH_CONTROLS[curve*3+3]
		var point: Vector2 = a*u*u*u + b*3*u*u*t + c*3*u*t*t + d*t*t*t
		var tangent: Vector2 = (b-a)*3*u*u + (c-b)*6*u*t + (d-c)*3*t*t
		var normal: Vector2 = Vector2(tangent.y,-tangent.x).normalized()
		for side: float in [-1.0,1.0]:
			vertices.append(Vector3(point.x+side*normal.x*1.6,.095,point.y+side*normal.y*1.6))
			normals.append(Vector3.UP)
			uv.append(Vector2((side+1.0)*.5,float(step)/SEGMENTS))
		if step<SEGMENTS:
			var k: int = step*2
			indices.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func _batch(root: Node3D, label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material, variations: Array[Color] = []) -> void:
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = not variations.is_empty()
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		instances.set_instance_transform(index,transforms[index])
		if instances.use_custom_data: instances.set_instance_custom_data(index,variations[index])
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if label=="ContextBuildings" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
