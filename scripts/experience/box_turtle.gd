extends RefCounted
## Original metre-scale terrestrial turtle; all activity reads the one world time.
const SkinPose = preload("res://scripts/experience/human_skin_motion.gd")
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const SOURCE: String = "https://nationalzoo.si.edu/animals/eastern-box-turtle"
const SHAPE_SOURCE: String = "https://www.nps.gov/gate/learn/nature/eastern-box-turtle.htm"
const STABLE_ID: String = "3dworld:teaching:box-turtle:0000"
const HEAD_ID: String = "3dworld:teaching:box-turtle:head"
const PERIOD_S: float = 40.0
const RADIUS_M: float = .18
const STRIDE_M: float = .014
const KEYS: Array[String] = ["ForeL","HindR","ForeR","HindL"]

static func sample(time: float) -> Dictionary:
	var cycle: float = fposmod(time,PERIOD_S)
	var moving: float = smoothstep(0.,2.,cycle)*(1.-smoothstep(14.,16.,cycle))
	var travel_s: float
	if cycle<2.:
		var u: float = cycle/2.
		travel_s = 2.*(pow(u,3)-.5*pow(u,4))
	elif cycle<14.: travel_s = cycle-1.
	elif cycle<16.:
		var u: float = (cycle-14.)/2.
		travel_s = 13.+2.*(u-pow(u,3)+.5*pow(u,4))
	else: travel_s = 14.
	travel_s += floor(time/PERIOD_S)*14.
	var distance: float = travel_s*.014
	var angle: float = distance/RADIUS_M+.25
	return {"position":Vector3(cos(angle)*RADIUS_M,0,sin(angle)*RADIUS_M),"heading":atan2(-cos(angle),-sin(angle)),"moving":moving,"step_phase":distance/(STRIDE_M/.64),"distance":distance,"activity":"短步慢行 · 作者路线" if cycle<16. else "停步 · 头部轻微查看"}

static func bend(hip: Vector3,knee: Vector3,ankle: Vector3,target: Vector3) -> Dictionary:
	var upper: float = hip.distance_to(knee)
	var lower: float = knee.distance_to(ankle)
	var axis: Vector3 = (target-hip).normalized()
	var distance: float = clampf(target.distance_to(hip),absf(upper-lower)+.00001,upper+lower-.00001)
	var along: float = (upper*upper+distance*distance-lower*lower)/(2.*distance)
	var pole: Vector3 = knee-hip-axis*(knee-hip).dot(axis)
	if pole.length_squared()<1e-12: pole = axis.cross(Vector3.UP)
	var middle: Vector3 = hip+axis*along+pole.normalized()*sqrt(maxf(0.,upper*upper-along*along))
	return {"knee":middle,"ankle":hip+axis*distance,"clamped_m":absf(distance-target.distance_to(hip))}

static func ground_at(root: Node3D,x: float,z: float) -> float:
	# Query the existing indexed terrain vertices; do not substitute the analytic
	# generator's curved height between its actual 1.25 m grid vertices.
	var data: Dictionary = root.get_meta("turtle_skin")
	var vertices: PackedVector3Array = data.ground_vertices
	var local: Vector3 = data.terrain.to_local(Vector3(x,0,z))
	var ix: int = int(floor(local.x/1.25))+100
	var iz: int = int(floor(local.z/1.25))+100
	assert(ix>52 and ix<147 and iz>52 and iz<147)
	var a: int = iz*201+ix
	var p: Vector3 = vertices[a]
	var right: Vector3 = vertices[a+1]
	var down: Vector3 = vertices[a+201]
	var u: float = (local.x-p.x)/(right.x-p.x)
	var v: float = (local.z-p.z)/(down.z-p.z)
	var height: float = p.y*(1.-u-v)+right.y*u+down.y*v if u+v<=1. else right.y*(1.-v)+vertices[a+202].y*(u+v-1.)+down.y*(1.-u)
	return data.terrain.to_global(Vector3(local.x,height,local.z)).y

static func _clearing(stage: Node) -> Dictionary:
	var grass: MultiMeshInstance3D = stage.world_root.get_node("Understory") as MultiMeshInstance3D
	var best: Vector3 = Vector3.ZERO
	var best_clearance: float = -INF
	# Fixed small set in the existing near clearing; choose a gap without moving
	# any original grass, trees, rocks or other named animals/flower observations.
	# South of the original deer ellipses, still within the tree/rock-free central
	# radius. A close camera must not sit inside another actor's pick bounds.
	for x: float in [-6.,-4.8,-3.6,-2.4]:
		for z: float in [-9.5,-8.7,-7.9]:
			var clearance: float = INF
			for index: int in range(grass.multimesh.instance_count):
				var transform: Transform3D = grass.multimesh.get_instance_transform(index)
				var point: Vector3 = grass.to_global(transform.origin)
				var radius: float = transform.basis.get_scale().x*.19
				clearance = minf(clearance,Vector2(point.x-x,point.z-z).length()-radius)
			if clearance>best_clearance:
				best = Vector3(x,0,z)
				best_clearance = clearance
	return {"center":best,"grass_clearance_m":best_clearance,"authored_candidates":12}

static func prepare(root: Node3D,stage: Node) -> void:
	LifeMotion.prepare_materials(root)
	var skeleton: Skeleton3D = root.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var bones: Dictionary = {}
	for id: int in range(skeleton.get_bone_count()):
		var rest: Transform3D = skeleton.get_bone_global_rest(id)
		bones[skeleton.get_bone_name(id)] = {"id":id,"rest":rest,"origin":rest.origin,"rest_rotation":skeleton.get_bone_rest(id).basis.get_rotation_quaternion(),"axis_z":(rest.basis.inverse()*Vector3.BACK).normalized(),"axis_y":(rest.basis.inverse()*Vector3.UP).normalized()}
	var terrain: MeshInstance3D = stage.world_root.get_node("WoodlandTerrain") as MeshInstance3D
	var ground: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var soles: Dictionary = {}
	var mesh: MeshInstance3D = root.find_child("ContinuousSoftBody",true,false) as MeshInstance3D
	var bind_ids: Dictionary = {}
	for bind: int in range(mesh.skin.get_bind_count()):
		var bone: int = mesh.skin.get_bind_bone(bind)
		if bone<0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
		bind_ids[bind] = bone
	for key: String in KEYS:
		assert(bones.has(key) and bones.has(key+"Knee") and bones.has(key+"Paw"))
		var points: PackedVector3Array = PackedVector3Array()
		# The replacement shell and retained scientific toes use different materials.
		# Read the actual sole vertices across all surfaces of the continuous skin.
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var influences: int = weights.size()/positions.size()
			for index: int in range(positions.size()):
				if positions[index].y>.004: continue
				for slot: int in range(influences):
					if bind_ids[ids[index*influences+slot]]==int(bones[key+"Paw"].id) and weights[index*influences+slot]>.999:
						points.append(positions[index])
		assert(not points.is_empty(),"Missing rigid sole samples: "+key)
		soles[key] = points
	root.set_meta("turtle_skin",{"skeleton":skeleton,"bones":bones,"terrain":terrain,"ground_vertices":ground,"soles":soles})

static func _rotation(data: Dictionary,key: String,wanted: Basis,parent_basis: Basis) -> void:
	data.skeleton.set_bone_pose_rotation(data.bones[key].id,(parent_basis.inverse()*wanted).get_rotation_quaternion())

static func pose(root: Node3D,time: float,state: Dictionary) -> void:
	var data: Dictionary = root.get_meta("turtle_skin")
	var contacts: Array[Dictionary] = []
	for index: int in range(KEYS.size()):
		var key: String = KEYS[index]
		var hip: Vector3 = data.bones[key].origin
		var knee: Vector3 = data.bones[key+"Knee"].origin
		var ankle: Vector3 = data.bones[key+"Paw"].origin
		var step: Vector2 = LifeMotion._step(float(state.step_phase)+float(index)*.25,STRIDE_M,.004)*float(state.moving)
		var offset: float = -INF
		for vertex: Vector3 in data.soles[key]:
			var point: Vector3 = root.to_global(vertex+Vector3(step.x,0,0))
			offset = maxf(offset,ground_at(root,point.x,point.z)-point.y)
		var requested: Vector3 = ankle+Vector3(step.x,offset+step.y,0)
		var solved: Dictionary = bend(hip,knee,ankle,requested)
		var upper: Basis = Basis(Quaternion((knee-hip).normalized(),(solved.knee-hip).normalized()))*data.bones[key].rest.basis
		var lower: Basis = Basis(Quaternion((ankle-knee).normalized(),(solved.ankle-solved.knee).normalized()))*data.bones[key+"Knee"].rest.basis
		_rotation(data,key,upper,data.bones.Root.rest.basis)
		_rotation(data,key+"Knee",lower,upper)
		_rotation(data,key+"Paw",data.bones[key+"Paw"].rest.basis,lower)
		contacts.append({"key":key,"lift_m":step.y,"requested":requested,"clamped_m":solved.clamped_m})
	SkinPose._angle(data,"Neck",.028*sin(time*.41),.020*sin(time*.29))
	SkinPose._angle(data,"Head",.024*sin(time*.53),.040*sin(time*.31))
	SkinPose._angle(data,"Tail",0,.030*sin(time*.27))
	root.set_meta("foot_requests",contacts)

static func point(root: Node3D,key: String,rest_point: Vector3) -> Vector3:
	var data: Dictionary = root.get_meta("turtle_skin")
	var skeleton: Skeleton3D = data.skeleton
	var id: int = int(data.bones[key].id)
	return skeleton.to_global(skeleton.get_bone_global_pose(id)*skeleton.get_bone_global_rest(id).affine_inverse()*rest_point)

static func build(stage: Node) -> void:
	var root: Node3D = stage.assets.box_turtle.instantiate()
	root.name = "EasternBoxTurtleReference"
	root.set_meta("stable_id",STABLE_ID)
	stage.world_root.add_child(root)
	prepare(root,stage)
	var head: Node3D = Node3D.new()
	head.name = "BoxTurtleHeadObserver"
	head.set_meta("stable_id",HEAD_ID)
	head.set_meta("box_turtle_root",root)
	stage.world_root.add_child(head)
	var clearing: Dictionary = _clearing(stage)
	stage.set_meta("box_turtle",{"root":root,"head_view":head,"clearing":clearing})
	stage.set_meta("box_turtle_targets",[
		{"node":root,"label":"东部箱龟 · Terrapene carolina carolina","role":"陆生箱龟参考：高拱背甲、黄橙斑纹、带铰链腹甲和有趾足。一个作者个体短步慢行/停步；资料中的杂食角色尚未接摄食求解。","source_url":SOURCE,"distance":.40,"min_distance":.18,"focus_height":.036,"view_offset_local":Vector3(.28,.16,.25)},
		{"node":head,"label":"东部箱龟 · 同一只的头部","role":"近看同一只箱龟的钩状上颌、鼻孔、眼与颈部斑纹，头部观察点跟随原骨骼。尺寸不随镜头放大。","source_url":SHAPE_SOURCE,"distance":.145,"min_distance":.065,"view_offset_local":Vector3(.095,.047,.100)}])
	animate(stage,float(stage.world_snapshot.simulation_time_s))

static func animate(stage: Node,time: float) -> void:
	if not stage.has_meta("box_turtle"): return
	var data: Dictionary = stage.get_meta("box_turtle")
	var root: Node3D = data.root
	var state: Dictionary = sample(time)
	root.position = data.clearing.center+state.position
	root.position.y = ground_at(root,root.position.x,root.position.z)
	root.rotation.y = state.heading
	pose(root,time,state)
	root.set_meta("sampled_world_time_s",time)
	root.set_meta("activity",state.activity)
	data.head_view.position = point(root,"Head",Vector3(.092,.038,0))
	data.head_view.rotation.y = root.rotation.y
	data.head_view.set_meta("activity",state.activity)

static func near_clip(stage: Node) -> float:
	var data: Dictionary = stage.get_meta("box_turtle",{})
	return .002 if not data.is_empty() and stage.camera.position.distance_to(data.root.position)<.65 else .08

static func readout(host: Node,topic: String) -> String:
	var data: Dictionary = host.coordinator.active_scene.get_meta("box_turtle",{})
	if data.is_empty(): return "箱龟参考未载入"
	if topic=="box_turtle_head": return "同一只箱龟 · 钩状上颌与颈部斑纹\n观察点跟随原头骨；性别未指定"
	return "东部箱龟 · 1只陆生参考\n"+str(data.root.get_meta("activity",""))+"\n生成外形未作标本尺寸标定；40秒作者节律\n双叶腹甲铰链为静态参考，未演示闭壳"

static func marks(host: Node,topic: String) -> Array[Dictionary]:
	var data: Dictionary = host.coordinator.active_scene.get_meta("box_turtle",{})
	if data.is_empty(): return []
	var root: Node3D = data.root
	if topic=="box_turtle_head": return [{"at":point(root,"Head",Vector3(.109,.026,.004)),"label":"钩状上颌","offset":Vector2(105,55)},{"at":point(root,"Neck",Vector3(.068,.043,.014)),"label":"有斑纹的头颈","offset":Vector2(-105,-55)}]
	return [{"at":root.to_global(Vector3(0,.076,0)),"label":"高拱背甲 · 生成外形参考","offset":Vector2(-105,-75)},{"at":point(root,"HindLPaw",Vector3(-.018,.003,.073)),"label":"后足四趾 · 陆地支撑","offset":Vector2(105,60)}]
