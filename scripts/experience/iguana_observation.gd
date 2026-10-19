extends RefCounted
## Authored locomotion on the actual terrain triangles, evaluated from host time.
const Terrain = preload("res://scripts/experience/desert_terrain.gd")
const Life = preload("res://scripts/experience/life_asset_motion.gd")
const SOURCE: String = "https://www.nps.gov/sagu/learn/nature/lizards.htm"
const SHAPE_SOURCE: String = "https://www.desertmuseum.org/books/nhsd_desert_iguana.php"
const STRIDE: float = .035
const STANCE: float = .65
const PERIOD: float = 22.

static func sample(time: float) -> Dictionary:
	var cycle: float = fposmod(time,PERIOD)
	var moving: float = smoothstep(0.,1.,cycle)*(1.-smoothstep(7.,8.,cycle))
	var travel: float
	if cycle<1.: travel=pow(cycle,3)-.5*pow(cycle,4)
	elif cycle<7.: travel=cycle-.5
	elif cycle<8.:
		var u: float = cycle-7.
		travel=6.5+u-pow(u,3)+.5*pow(u,4)
	else: travel=7.
	var distance: float = (floor(time/PERIOD)*7.+travel)*STRIDE
	return {"distance":distance,"phase":distance/STRIDE,"moving":moving,"activity":"灌木旁短行 · 四足与长尾配合" if cycle<8. else "停步观察 · 植物为主要食物（未模拟摄食）"}

static func path(distance: float) -> Transform3D:
	var angle: float = distance/1.15+.3
	var position: Vector3 = Vector3(3.+1.15*cos(angle),0,3.+1.15*sin(angle))
	var surface: Dictionary = Terrain.surface_at(position.x,position.z)
	position.y=surface.height
	var up: Vector3 = surface.normal
	var forward: Vector3 = Vector3(-sin(angle),0,cos(angle)).slide(up).normalized()
	return Transform3D(Basis(forward,up,forward.cross(up)),position)

static func prepare(root: Node3D) -> bool:
	var skeletons: Array[Node] = root.find_children("*","Skeleton3D",true,false)
	if skeletons.size()!=1: return false
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var bones: Dictionary = {}
	for i: int in range(skeleton.get_bone_count()):
		bones[skeleton.get_bone_name(i)]={"id":i,"rest":skeleton.get_bone_global_rest(i)}
	for key: String in ["Root","Spine","Head","Tail8","ForeL","ForeR","HindL","HindR","ForeLFoot","ForeRFoot","HindLFoot","HindRFoot"]:
		if not bones.has(key): return false
	root.set_meta("iguana_skin",{"skeleton":skeleton,"bones":bones})
	return true

static func _plant_at(distance: float, rest: Vector3) -> Vector3:
	var frame: Transform3D = path(distance)
	var point: Vector3 = frame*Vector3(rest.x,0,rest.z)
	point.y=Terrain.surface_at(point.x,point.z).height
	return point

static func foot_frame(phase: float, offset: float, rest: Vector3, root_frame: Transform3D) -> Transform3D:
	var p: float = fposmod(phase+offset,1.)
	var planted_at: float = (floor(phase+offset)-offset+STANCE*.5)*STRIDE
	var point: Vector3 = _plant_at(planted_at,rest)
	if p>=STANCE:
		var swing: float = (p-STANCE)/(1.-STANCE)
		point=point.lerp(_plant_at(planted_at+STRIDE,rest),smoothstep(0.,1.,swing))
		point.y=Terrain.surface_at(point.x,point.z).height+sin(swing*PI)*.008
	# Each foot follows its own supporting triangle, including across a terrain seam.
	var up: Vector3 = Terrain.surface_at(point.x,point.z).normal
	var forward: Vector3 = root_frame.basis.x.slide(up).normalized()
	var foot_basis: Basis = Basis(forward,up,forward.cross(up))
	point+=up*rest.y
	return root_frame.affine_inverse()*Transform3D(foot_basis,point)

static func _global_rotation(data: Dictionary, key: String, desired: Basis, rotations: Dictionary) -> void:
	var skeleton: Skeleton3D = data.skeleton
	var id: int = data.bones[key].id
	var parent: int = skeleton.get_bone_parent(id)
	var parent_basis: Basis = rotations.get(parent,skeleton.get_bone_global_rest(parent).basis) if parent>=0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(id,(parent_basis.inverse()*desired).get_rotation_quaternion().normalized())
	rotations[id]=desired

static func _limb(data: Dictionary, key: String, frame: Transform3D, rotations: Dictionary) -> void:
	var target: Vector3 = frame.origin
	var hip: Vector3 = data.bones[key].rest.origin
	var knee: Vector3 = data.bones[key+"Knee"].rest.origin
	var foot: Vector3 = data.bones[key+"Foot"].rest.origin
	var a: Vector3 = knee-hip
	var b: Vector3 = foot-knee
	var direction: Vector3 = (target-hip).normalized()
	var d: float = clampf((target-hip).length(),absf(a.length()-b.length())+.00001,a.length()+b.length()-.00001)
	var along: float = (a.length_squared()+d*d-b.length_squared())/(2.*d)
	var bend: Vector3 = a.slide(direction).normalized()
	var elbow: Vector3 = hip+direction*along+bend*sqrt(maxf(0.,a.length_squared()-along*along))
	var first: Basis = Basis(Quaternion(a.normalized(),(elbow-hip).normalized()))*data.bones[key].rest.basis
	var second: Basis = Basis(Quaternion(b.normalized(),(target-elbow).normalized()))*data.bones[key+"Knee"].rest.basis
	_global_rotation(data,key,first,rotations)
	_global_rotation(data,key+"Knee",second,rotations)
	_global_rotation(data,key+"Foot",frame.basis*data.bones[key+"Foot"].rest.basis,rotations)

static func pose(root: Node3D, time: float) -> void:
	var state: Dictionary = sample(time)
	root.transform=path(state.distance)
	var data: Dictionary = root.get_meta("iguana_skin")
	var rotations: Dictionary = {}
	var keys: Array[String] = ["ForeL","HindR","ForeR","HindL"]
	var contacts: Dictionary = {}
	for i: int in range(4):
		var key: String = keys[i]
		var rest: Vector3 = data.bones[key+"Foot"].rest.origin
		var frame: Transform3D = foot_frame(state.phase,0. if i<2 else .5,rest,root.transform)
		_limb(data,key,frame,rotations)
		contacts[key]=root.to_global(frame.origin)
	# Rotate around each joint in model Y, retaining the authored rest axes.
	var skeleton: Skeleton3D = data.skeleton
	for i: int in range(1,9):
		var key: String = "Tail"+str(i)
		var id: int = data.bones[key].id
		var rest: Transform3D = skeleton.get_bone_rest(id)
		var axis: Vector3 = data.bones[key].rest.basis.inverse()*Vector3.UP
		skeleton.set_bone_pose_rotation(id,rest.basis.get_rotation_quaternion()*Quaternion(axis.normalized(),sin(state.phase*TAU-i*.32)*.018*state.moving))
	var head_id: int = data.bones.Head.id
	var head_axis: Vector3 = data.bones.Head.rest.basis.inverse()*Vector3.UP
	skeleton.set_bone_pose_rotation(head_id,skeleton.get_bone_rest(head_id).basis.get_rotation_quaternion()*Quaternion(head_axis.normalized(),sin(time*.37)*.065*(1.-state.moving)))
	root.set_meta("activity",state.activity)
	root.set_meta("foot_targets",contacts)
	root.set_meta("motion_sample",state)

static func build(stage: Node) -> void:
	var root: Node3D = stage.asset_instance("desert_iguana")
	root.name="DesertIguana"
	Life.prepare_materials(root)
	stage.world_root.add_child(root)
	if not prepare(root):
		push_error("Desert iguana requires its 23-bone rig")
		root.queue_free()
		return
	root.set_meta("stable_id","3dworld:teaching:desert-iguana:0000")
	stage.set_meta("iguana",root)
	pose(root,0.)
	var targets: Array = stage.get_meta("desert_targets")
	var role: String = "沙漠鬣蜥Dipsosaurus dorsalis。浅色网纹、钝头和背中线低矮棱鳞；主要吃植物，常见于三齿拉瑞阿灌丛。吻肛长14 cm、尾长24 cm为作者尺寸；运动是教学示意，没有摄食消耗或体温求解。"
	targets.append({"node":root,"label":"沙漠鬣蜥 · 四足与长尾","role":role,"source_url":SOURCE,"distance":.96,"min_distance":.26,"focus_height":.025,"view_offset":Vector3(.686,.49,.462)})
	var anchor: Node3D = Node3D.new()
	anchor.name="IguanaHeadObserver"
	stage.world_root.add_child(anchor)
	anchor.set_meta("reference_root",root)
	stage.set_meta("iguana_head_observer",anchor)
	targets.append({"node":anchor,"label":"沙漠鬣蜥 · 头部与背鳞","role":role,"source_url":SHAPE_SOURCE,"distance":.20,"min_distance":.11,"view_offset":Vector3(.12,.09,.12)})
	stage.set_meta("desert_targets",targets)
	animate(stage,0.)

static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("iguana"): return
	var root: Node3D = stage.get_meta("iguana")
	pose(root,time)
	var anchor: Node3D = stage.get_meta("iguana_head_observer")
	anchor.position=root.to_global(Vector3(.04,.048,0))
	anchor.set_meta("activity",root.get_meta("activity"))

static func readout(host: Node) -> String:
	var state: Dictionary = sample(host.world.simulation_time_s)
	return "%s\n14 cm吻肛长 + 24 cm尾长（作者尺寸）\n短行/停步由统一世界时间驱动，非实测速度或热调节。" % state.activity

static func marks(host: Node) -> Array[Dictionary]:
	var root: Node3D = host.coordinator.active_scene.get_meta("iguana")
	var data: Dictionary = root.get_meta("iguana_skin")
	var skeleton: Skeleton3D = data.skeleton
	var head: Transform3D = skeleton.get_bone_global_pose(data.bones.Head.id)*data.bones.Head.rest.affine_inverse()
	return [{"at":skeleton.to_global(head*Vector3(.070,.055,.010)),"label":"钝头 · 浅色网纹","offset":Vector2(90,-105)},
		{"at":root.to_global(Vector3(0,.057,0)),"label":"低矮背中线棱鳞","offset":Vector2(-100,-130)}]
