extends RefCounted
const CloudSurface = preload("res://shaders/ecology_robin_surface.gdshader")
## Authored feather/skin articulation driven only by the existing 103 activity sample.
## Three wing segments and planar leg IK illustrate motion, not measured biomechanics.
static func prepare(root: Node3D) -> bool:
	var skeletons: Array[Node] = root.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty(): return false
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var bones: Dictionary = {}
	for i: int in range(skeleton.get_bone_count()):
		var name: String = skeleton.get_bone_name(i)
		var rest: Transform3D = skeleton.get_bone_global_rest(i)
		var inverse: Basis = rest.basis.inverse()
		bones[name] = {"id":i,"rest_rotation":skeleton.get_bone_rest(i).basis.get_rotation_quaternion(),"axis_x":(inverse*Vector3.RIGHT).normalized(),"axis_y":(inverse*Vector3.UP).normalized(),"axis_z":(inverse*Vector3.BACK).normalized(),"origin":rest.origin}
	for key: String in ["Spine","Neck","Head","Tail","WingL","WingLFore","WingLHand","WingR","WingRFore","WingRHand","LegL","LegLHock","FootL","LegR","LegRHock","FootR"]:
		if not bones.has(key): return false
	var cloud: Array[ShaderMaterial] = []
	var flight: Array[Node] = root.find_children("RobinFlight*","MeshInstance3D",true,false)
	var perched: Array[Node] = root.find_children("RobinPerchedSurface*","MeshInstance3D",true,false)
	for child: Node in flight:
		var mesh: MeshInstance3D = child as MeshInstance3D
		for slot: int in range(mesh.mesh.get_surface_count()):
			var source: StandardMaterial3D = mesh.mesh.surface_get_material(slot) as StandardMaterial3D
			if source==null or source.albedo_texture==null: continue
			var surface: ShaderMaterial = ShaderMaterial.new()
			surface.shader = CloudSurface
			surface.set_shader_parameter("albedo_map",source.albedo_texture)
			surface.set_shader_parameter("tint",source.albedo_color)
			surface.set_shader_parameter("roughness_value",source.roughness)
			if source.normal_texture!=null:
				surface.set_shader_parameter("normal_map",source.normal_texture)
				surface.set_shader_parameter("has_normal",true)
			mesh.set_surface_override_material(slot,surface)
			cloud.append(surface)
	root.set_meta("robin_skin",{"skeleton":skeleton,"bones":bones,"cloud_surfaces":cloud,"flight_surfaces":flight,"perched_surfaces":perched})
	root.set_meta("asset_species","bird")
	return true

static func _rotate(data: Dictionary, key: String, pitch: float = 0., yaw: float = 0., roll: float = 0.) -> void:
	var bone: Dictionary = data.bones[key]
	data.skeleton.set_bone_pose_rotation(bone.id,bone.rest_rotation*Quaternion(bone.axis_z,pitch)*Quaternion(bone.axis_x,roll)*Quaternion(bone.axis_y,yaw))

static func pose(root: Node3D, time: float, flying: float, inspecting: float, walking: float, tuck: float, gait: float, terrain: Object = null) -> void:
	var data: Dictionary = root.get_meta("robin_skin")
	var folded: float = 1.-flying
	for side: float in [-1.,1.]:
		var suffix: String = "L" if side>0 else "R"
		_rotate(data,"Wing"+suffix,.18*folded,-side*.85*folded,side*.90*folded+side*sin(time*30.)*.70*flying)
		_rotate(data,"Wing"+suffix+"Fore",0,side*(1.65*folded+.08*sin(time*30.-.35)*flying),side*sin(time*30.-.35)*.12*flying)
		_rotate(data,"Wing"+suffix+"Hand",0,-side*(1.80*folded+.10*flying),side*sin(time*30.-.65)*.16*flying)
		var key: String = "Leg"+suffix
		var hip: Vector3 = data.bones[key].origin
		var hock: Vector3 = data.bones[key+"Hock"].origin
		var ankle: Vector3 = data.bones["Foot"+suffix].origin
		var upper: Vector2 = Vector2(hock.x-hip.x,hock.y-hip.y)
		var lower: Vector2 = Vector2(ankle.x-hock.x,ankle.y-hock.y)
		var cycle: float = fposmod(gait/TAU+(.5 if side<0 else 0.),1.)
		var step: Vector2
		if cycle<.64: step=Vector2(lerpf(.0192,-.0192,cycle/.64),0)
		else:
			var swing: float = (cycle-.64)/.36
			step=Vector2(lerpf(-.0192,.0192,smoothstep(0.,1.,swing)),sin(PI*swing)*.016)
		var target: Vector2 = Vector2(ankle.x-hip.x,ankle.y-hip.y)+step*walking
		if terrain!=null and tuck<1.:
			var sample_point: Vector3 = root.to_global(Vector3(hip.x+target.x,ankle.y,ankle.z))
			var ground_y: float = terrain._height(sample_point.x,sample_point.z)
			var contact: Vector3 = root.to_local(Vector3(sample_point.x,ground_y+.009,sample_point.z))
			target.y=lerpf(contact.y-hip.y+step.y*walking,target.y,tuck)
		target=target.lerp(Vector2(-.026,.056)-Vector2(hip.x,hip.y),tuck)
		var l1: float = upper.length()
		var l2: float = lower.length()
		var d: float = clampf(target.length(),absf(l1-l2)+.00001,l1+l2-.00001)
		var direction: float = atan2(target.x,-target.y)
		var a: float = direction+acos(clampf((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1))
		var b: float = direction-acos(clampf((l2*l2+d*d-l1*l1)/(2*l2*d),-1,1))
		var rest_a: float = atan2(upper.x,-upper.y)
		var rest_b: float = atan2(lower.x,-lower.y)
		_rotate(data,key,a-rest_a)
		_rotate(data,key+"Hock",b-a-(rest_b-rest_a))
		_rotate(data,"Foot"+suffix,-(b-rest_b)-.55*tuck)
	_rotate(data,"Neck",-.38*inspecting)
	_rotate(data,"Head",-.44*inspecting+sin(time*2.)*.045*folded,0,.18*inspecting)
	_rotate(data,"Tail",sin(time*3.)*.035*folded)
	for surface: ShaderMaterial in data.get("cloud_surfaces",[]):
		surface.set_shader_parameter("world_phase",time*30.)
		surface.set_shader_parameter("flying",1.)
	for mesh: MeshInstance3D in data.get("flight_surfaces",[]): mesh.visible=flying>.15
	for mesh: MeshInstance3D in data.get("perched_surfaces",[]): mesh.visible=flying<=.15

static func point(root: Node3D, key: String, rest_point: Vector3) -> Vector3:
	var data: Dictionary = root.get_meta("robin_skin")
	var skeleton: Skeleton3D = data.skeleton
	var id: int = data.bones[key].id
	return skeleton.to_global(skeleton.get_bone_global_pose(id)*skeleton.get_bone_global_rest(id).affine_inverse()*rest_point)
