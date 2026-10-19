extends RefCounted
const Grazing = preload("res://scripts/core/algal_grazing.gd")
const School = preload("res://scripts/core/schooling.gd")
const Zooplankton = preload("res://scripts/core/zooplankton_lesson.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const SpeciesSkinShader = preload("res://shaders/marine_species.gdshader")
const RayShader = preload("res://shaders/ray_swim.gdshader")
const RayObservation = preload("res://scripts/experience/ray_observation.gd")
const TurtleMotion = preload("res://scripts/experience/turtle_motion.gd")
const SnapperMotion = preload("res://scripts/experience/snapper_motion.gd")
const LABELS: Array[String] = ["褐吊 · Zebrasoma scopas","四带笛鲷 · Lutjanus kasmira","青绿雀鲷 · Chromis viridis","绿海龟 · Chelonia mydas","蓝斑条尾魟 · Taeniura lymma"]
const SOURCES: Array[String] = ["https://fishesofaustralia.net.au/home/species/2204","https://fishesofaustralia.net.au/home/species/559","https://fishesofaustralia.net.au/home/species/329","https://www.fisheries.noaa.gov/species/green-turtle","https://fishesofaustralia.net.au/home/species/2030"]
const KEYS: Array[String] = ["brown_tang","bluestriped_snapper","blue_green_chromis","green_turtle","bluespotted_ray"]
const ROLES: Array[String] = ["食藻鱼：刮食岩面藻毯。","捕食性礁鱼：以鱼类、甲壳类为食；白天常在礁体附近集群。","水层取食：捕食浮游动物，常在分枝珊瑚上方集群。","长前鳍肢参与推进，巡游时短后鳍肢收后。爬行动物，需上浮呼吸；上浮换气为作者演示，未模拟真实呼吸周期。食性随年龄、生境变化。","砂底觅食：以软体动物、多毛类与甲壳类等无脊椎动物为食。"]

static func _fish_materials(root: Node3D, cache: Dictionary, ray: bool = false) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child: Node in root.find_children("*","MeshInstance3D",true,false):
		var node: MeshInstance3D = child as MeshInstance3D
		meshes.append(node)
		for slot: int in range(node.mesh.get_surface_count()):
			var source: StandardMaterial3D = node.mesh.surface_get_material(slot) as StandardMaterial3D
			if source==null: continue
			var key: int = source.get_instance_id()
			if not cache.has(key):
				var mat: ShaderMaterial = ShaderMaterial.new()
				mat.shader = RayShader if ray else SpeciesSkinShader
				mat.set_shader_parameter("tint",source.albedo_color)
				mat.set_shader_parameter("roughness_value",source.roughness)
				mat.set_shader_parameter("vertex_pigment",bool(node.mesh.surface_get_format(slot)&Mesh.ARRAY_FORMAT_COLOR))
				if not ray:
					mat.set_shader_parameter("brown_tang_pigment",str(node.name).begins_with("brown_tangBody"))
				if source.albedo_texture!=null:
					mat.set_shader_parameter("has_albedo",true)
					mat.set_shader_parameter("albedo_map",source.albedo_texture)
				if source.normal_texture!=null:
					mat.set_shader_parameter("has_normal",true)
					mat.set_shader_parameter("normal_map",source.normal_texture)
				cache[key] = mat
			node.set_surface_override_material(slot,cache[key])
	return meshes

static func build(stage: Node) -> void:
	var actors: Array[Dictionary] = []
	var materials: Dictionary = {}
	for kind: int in range(5):
		var count: int = [6,12,24,1,1][kind]
		for index: int in range(count):
			var node: Node3D = stage.assets[KEYS[kind]].instantiate()
			node.scale = Vector3.ONE * ([0.20,0.25,0.085,0.65,0.65][kind])
			LifeMotion.prepare_materials(node)
			stage.world_root.add_child(node)
			node.set_meta("stable_id","3dworld:teaching:marine:%d:%03d" % [kind,index])
			var actor: Dictionary = {"node":node,"kind":kind,"index":index,"label":LABELS[kind],"role":ROLES[kind],"source_url":SOURCES[kind],"meshes":[]}
			if kind<3 or kind==4: actor.meshes = _fish_materials(node,materials,kind==4)
			if kind==4: RayObservation.prepare(node)
			if kind==3:
				TurtleMotion.prepare(node)
				var fins: Dictionary = {}
				for key: String in ["FlipperL","FlipperR","HindFlipperL","HindFlipperR"]:
					fins[key] = node.find_child(key,true,false)
				actor.fins = fins
			actors.append(actor)
	stage.set_meta("marine_actors",actors)
	stage.set_meta("marine_counts", {"海葵鱼":2,"褐吊":6,"四带笛鲷":12,"青绿雀鲷":24,"绿海龟":1,"蓝斑条尾魟":1})
	stage.set_meta("content_summary","海洋生命：海葵鱼与褐吊、四带笛鲷、青绿雀鲷、绿海龟与蓝斑条尾魟参考形态。\n选择对象，比较身体结构、活动空间与食物角色。物种采用参考模型；节律、数量与轨迹均为作者设定，不是实测种群或生态预测。")
	# Six low rock/algally coloured feeding patches, away from the target anemone.
	var patches: Array[Vector3] = []
	var patch_materials: Array[ShaderMaterial]=[]
	for index: int in range(6):
		var rock: ShaderMaterial=ShaderMaterial.new()
		rock.shader=preload("res://shaders/algal_turf.gdshader")
		rock.set_shader_parameter("stock_fraction",Grazing.INITIAL[index]/Grazing.CAPACITY)
		stage.materials.append(rock)
		patch_materials.append(rock)
		var x: float = -3.0+index*0.35
		var z: float = 1.6+index%2*0.3
		var point: Vector3 = Vector3(x,stage.builder._terrain_height(stage,x,z)+0.11,z)
		patches.append(point)
		Forms.ellipsoid(stage.world_root,point-Vector3(0,0.06,0),Vector3(0.25,0.12,0.21),rock)
	stage.set_meta("feeding_patches",patches)
	stage.set_meta("algal_materials",patch_materials)
	var motes: Array[Node3D] = []
	var mote_mat: StandardMaterial3D = Forms.material(Color(.30,.80,.87),.42)
	mote_mat.emission_enabled = true
	mote_mat.emission = Color(.11,.38,.43)
	for i: int in range(Zooplankton.INITIAL_UNITS):
		var column: int = i%4
		var row: int = i/4
		var point: Vector3 = School.CENTER+Vector3((float(column)-1.5)*.21,(float(row)-1.)*.14,-.28+float((i*7)%5)*.12)
		var mote: Node3D = Forms.ellipsoid(stage.world_root,point,Vector3.ONE*.023,mote_mat)
		mote.name = "MagnifiedZooplanktonUnit%02d" % i
		mote.set_meta("base_position",point)
		motes.append(mote)
	stage.set_meta("zooplankton_motes",motes)

static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("marine_actors"): return
	var water: Dictionary = stage.world_snapshot.get("zooplankton_lesson",{})
	if not water.is_empty():
		var motes: Array = stage.get_meta("zooplankton_motes",[])
		for i: int in range(motes.size()):
			var mote: Node3D = motes[i]
			mote.visible = bool(water.active) and i < int(water.water_units)
			var base: Vector3 = mote.get_meta("base_position")
			mote.position = base+Vector3(sin(time*.23+i*1.4),cos(time*.19+i*.9),sin(time*.15+i*2.1))*.016
	var resources: Dictionary=stage.world_snapshot.get("algal_grazing",{})
	if not resources.is_empty():
		for patch: int in range(6):
			stage.get_meta("algal_materials")[patch].set_shader_parameter("stock_fraction",float(resources.stock[patch])/Grazing.CAPACITY)
	for actor: Dictionary in stage.get_meta("marine_actors"):
		var kind: int = actor.kind
		var index: int = actor.index
		var rate: float = [0.10,0.16,0.22,0.055,0.07][kind]
		var angle: float = time*rate + index*0.37 + kind*1.9
		var center: Vector3 = [Vector3(-0.8,0.9,-1.0),Vector3(0,1.25,-2.2),Vector3(0.3,1.5,-3),Vector3(0,1.7,-3.8),Vector3(0,0.52,-2.2)][kind]
		var radius: float = [0.7,1.7,2.0,2.6,1.5][kind]
		var position: Vector3 = center + Vector3(cos(angle)*radius,sin(angle*1.7+index)*0.055+(index%3)*0.05,sin(angle)*radius*0.32)
		actor.node.rotation = Vector3(0,atan2(-cos(angle)*0.32,-sin(angle)),0)
		var activity: String = ["巡游 · 接近藻毯","礁区群游 · 捕食角色示意","水层集群 · 浮游动物取食示意","划水游动 · 礁区穿行","贴近海床游动"][kind]
		if kind==0:
			var target_index: int=int(resources.targets[index]) if not resources.is_empty() else index
			var start: float=float(resources.get("started_at_s",0.))
			var cycle: float=Grazing.phase(time,start,index)
			var feeding: float=Grazing.approach(cycle)*(float(resources.engagement[index]) if not resources.is_empty() else 1.)
			var patch: Vector3=stage.get_meta("feeding_patches")[target_index]
			# A replacement reads its actual mesh-vertex mark. Original assets use
			# their existing authored mouth reference at the same .2 scene scale.
			var feeding_yaw: float=index*TAU/6.
			var mouth_anchor: Node3D=actor.node.find_child("FeedingMouthAnchor",true,false) as Node3D
			var mouth_point: Vector3=actor.node.to_local(mouth_anchor.global_position) if mouth_anchor!=null else Vector3(.468,-.075,0)
			var mouth_offset: Vector3=Basis(Vector3.UP,feeding_yaw)*Basis(Vector3.BACK,-.8)*mouth_point*.2
			# Separate approach sectors on the actual ellipsoid's upper surface.
			var contact_at: Vector3=patch+Vector3(-.0625*cos(feeding_yaw),.06*(sqrt(.75)-1.),.0525*sin(feeding_yaw))
			position=position.lerp(contact_at-mouth_offset+Vector3(0,.001+sin(time*5+index)*.0005,0),feeding)
			actor.node.rotation.y = lerp_angle(actor.node.rotation.y,feeding_yaw,feeding)
			actor.node.rotation.z = -0.8*feeding
			actor.node.set_meta("grazing_target",target_index)
			actor.node.set_meta("grazing_approach",feeding)
			activity="下一取食点 · 斑块%d" % (target_index+1)
			if feeding>.995 and bool(resources.get("enabled",true)): activity="刮食斑块%d · 藻量随摄食减少" % (target_index+1)
			elif not bool(resources.get("enabled",true)): activity="停止刮食 · 教学对照中"
		elif kind==1:
			var pose: Dictionary = SnapperMotion.sample(time,index)
			position = pose.position
			actor.node.rotation = Vector3(0,pose.yaw,pose.pitch)
			activity = pose.activity
		elif kind==2:
			var state: Dictionary = stage.world_snapshot.get("schooling",{})
			if not state.is_empty():
				position=School.vector(state.positions[index])
				var velocity: Vector3 = School.vector(state.velocities[index])
				actor.node.rotation=Vector3(0,atan2(-velocity.z,velocity.x),atan2(velocity.y,Vector2(velocity.x,velocity.z).length()))
				activity="局部避挤 / 聚合 · "+("方向对齐开启" if state.alignment else "方向对齐关闭")
		elif kind==3:
			var pose: Dictionary = TurtleMotion.sample(time,actor.node)
			position=pose.position
			actor.node.rotation=Vector3(0,pose.yaw,pose.pitch)
			activity=pose.activity
			TurtleMotion.apply_fins(actor,pose)
		elif kind==4:
			# Low, open-sand circuit. Height samples actual terrain; not benthic prey simulation.
			position = Vector3(-4.2+cos(angle)*.65,0.0,2.8+sin(angle)*.40)
			position.y = stage.builder._terrain_height(stage,position.x,position.z)+.08
			actor.node.rotation.y = atan2(-cos(angle)*.40,-sin(angle)*.65)
			activity = "砂底巡游 · 胸鳍波动；底栖食物角色示意"
		actor.node.position = position
		actor.node.set_meta("activity",activity)
		if kind<3 or kind==4:
			for mesh: MeshInstance3D in actor.meshes: mesh.set_instance_shader_parameter("swim_phase",time*(3.8 if kind==4 else 6.5 if kind!=2 else 9.0)+index)

	var center: Vector3 = Vector3.ZERO
	var leader: Node3D
	var members: int = 0
	for actor: Dictionary in stage.get_meta("marine_actors"):
		if actor.kind!=1: continue
		if actor.index==0: leader = actor.node
		else:
			center += actor.node.position
			members += 1
	if members>0 and is_instance_valid(leader):
		center /= members
		stage.set_meta("snapper_group_center",center)
		leader.set_meta("group_distance_m",leader.position.distance_to(center))
