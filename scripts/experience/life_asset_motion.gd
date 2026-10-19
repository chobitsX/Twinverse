extends RefCounted
const RobinSkin = preload("res://scripts/experience/robin_skin_motion.gd")
const DeerSkin = preload("res://scripts/experience/deer_skin_motion.gd")
const HumanSkin = preload("res://scripts/experience/human_skin_motion.gd")
const EcologySurface=preload("res://scripts/experience/ecology_source_surface.gd")
## Posed from the host's world time. Joint rest positions come from the authored GLBs.
## Planar two-link legs keep feet near the ground; this is animation, not biomechanics.

static func prepare_scene_materials(scene: PackedScene) -> void:
	# The compact replacement materials carry their pigment in COLOR_0. Set the
	# shared imported base before controllers clone or override those materials.
	if not scene.resource_path.contains("/ecology269/"):return
	var state: SceneState=scene.get_state()
	for node: int in range(state.get_node_count()):
		for property: int in range(state.get_node_property_count(node)):
			if state.get_node_property_name(node,property)!=&"mesh":continue
			var mesh: Mesh=state.get_node_property_value(node,property) as Mesh
			if mesh==null:continue
			for slot: int in range(mesh.get_surface_count()):
				var base: StandardMaterial3D=mesh.surface_get_material(slot) as StandardMaterial3D
				if base!=null and mesh.surface_get_format(slot)&Mesh.ARRAY_FORMAT_COLOR:
					base.vertex_color_use_as_albedo=true
					base.vertex_color_is_srgb=false

static func prepare_materials(root: Node) -> void:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			for slot: int in range(child.mesh.get_surface_count()):
				var material: StandardMaterial3D = child.mesh.surface_get_material(slot) as StandardMaterial3D
				if material!=null and child.mesh.surface_get_format(slot)&Mesh.ARRAY_FORMAT_COLOR:
					material.vertex_color_use_as_albedo = true
					material.vertex_color_is_srgb = false
			EcologySurface.prepare_mesh(child as MeshInstance3D)
		prepare_materials(child)

static func prepare(root: Node3D, species: String) -> void:
	prepare_materials(root)
	if species=="person" and HumanSkin.prepare(root): return
	if species=="deer" and DeerSkin.prepare(root): return
	if species=="bird" and RobinSkin.prepare(root): return
	var joints: Dictionary = {}
	var names: Array[String] = []
	names.assign(["LegL","LegR","LegLKnee","LegRKnee","ArmL","ArmR","ArmLElbow","ArmRElbow"] if species=="person" else ["ForeL","ForeR","HindL","HindR","ForeLKnee","ForeRKnee","HindLKnee","HindRKnee","HeadPivot","Tail"])
	if species=="bird": names.assign(["BirdHead","BirdWingL","BirdWingR","BirdLegL","BirdLegR","BirdTail"])
	for joint_name: String in names:
		var node: Node3D = root.find_child(joint_name,true,false) as Node3D
		if node != null: joints[joint_name] = node
	root.set_meta("life_joints",joints)
	root.set_meta("asset_species",species)

static func _angle(joints: Dictionary, key: String, angle: float) -> void:
	if joints.has(key): joints[key].rotation.z = angle

static func _leg(joints: Dictionary, key: String, foot: Vector2, rest_ankle: Vector2, bend: float) -> void:
	if not joints.has(key) or not joints.has(key+"Knee"): return
	var hip: Node3D = joints[key]
	var knee: Node3D = joints[key+"Knee"]
	var upper: Vector2 = Vector2(knee.position.x,knee.position.y)
	var lower: Vector2 = rest_ankle-upper
	var l1: float = upper.length()
	var l2: float = lower.length()
	var distance: float = clampf(foot.length(),absf(l1-l2)+0.001,l1+l2-0.001)
	var direction: float = atan2(foot.x,-foot.y)
	var a: float = direction+bend*acos(clampf((l1*l1+distance*distance-l2*l2)/(2*l1*distance),-1,1))
	var b: float = direction-bend*acos(clampf((l2*l2+distance*distance-l1*l1)/(2*l2*distance),-1,1))
	var rest_a: float = atan2(upper.x,-upper.y)
	var rest_b: float = atan2(lower.x,-lower.y)
	hip.rotation.z = a-rest_a
	knee.rotation.z = b-a-(rest_b-rest_a)

static func _step(phase: float, stride: float, lift: float) -> Vector2:
	var p: float = fposmod(phase,1.0)
	if p<0.64: return Vector2(lerpf(stride/2,-stride/2,p/0.64),0)
	var swing: float = (p-0.64)/0.36
	return Vector2(lerpf(-stride/2,stride/2,smoothstep(0.0,1.0,swing)),sin(swing*PI)*lift)

const HUMAN_STRIDE: float = .60
const HUMAN_CYCLE_DISTANCE: float = HUMAN_STRIDE/.64

static func person_root_offset(moving: float) -> float:
	# Keep the ankle at the same ground-relative height as the pelvis lowers.
	return lerpf(-.005,-.070,moving)

static func person(root: Node3D, time: float, moving: float, phase_offset: float = 0.0, travel: float = INF) -> void:
	var phase: float = (time/1.2 if is_inf(travel) else travel/HUMAN_CYCLE_DISTANCE)+phase_offset
	if root.has_meta("human_skin"):
		var steps: Array[Vector2] = [_step(phase,HUMAN_STRIDE,.10)*moving,_step(phase+.5,HUMAN_STRIDE,.10)*moving]
		HumanSkin.person(root,time,moving,phase,steps)
		return
	var joints: Dictionary = root.get_meta("life_joints",{})
	for side: int in range(2):
		var key: String = "LegL" if side==0 else "LegR"
		var step: Vector2 = _step(phase+side*0.5,0.69,0.10)*moving
		_leg(joints,key,Vector2(step.x,-0.79+step.y),Vector2(0,-0.82),1.0)
		var wave: float = sin((phase+side*0.5)*TAU)
		_angle(joints,"ArmL" if side==0 else "ArmR",-wave*0.24*moving)
		_angle(joints,"ArmLElbow" if side==0 else "ArmRElbow",0.09+maxf(0.0,wave)*0.22*moving)

static func deer(root: Node3D, time: float, moving: float, grazing: float, phase_offset: float = 0.0) -> void:
	var joints: Dictionary = root.get_meta("life_joints",{})
	var phase: float = time/1.65+phase_offset
	var keys: Array[String] = ["ForeL","HindR","ForeR","HindL"]
	for index: int in range(4):
		var key: String = keys[index]
		var fore: bool = key.begins_with("Fore")
		var step: Vector2 = _step(phase+index*0.25,0.30,0.07)*moving
		var rest_x: float = 0.03 if fore else -0.02
		_leg(joints,key,Vector2(rest_x+step.x,-0.845+step.y),Vector2(rest_x,-0.86),1.0 if fore else -1.0)
	_angle(joints,"HeadPivot",-1.29*grazing+sin(time*1.3+phase_offset)*0.035*(1.0-grazing))
	if joints.has("Tail"): joints.Tail.rotation.y = sin(time*2.1+phase_offset)*0.10

static func bird(root: Node3D, time: float, flying: float, pecking: float, walking: float, leg_tuck: float = -1.0, step_phase: float = -1.0, terrain: Object = null) -> void:
	var joints: Dictionary = root.get_meta("life_joints",{})
	var tuck: float = flying if leg_tuck<0 else leg_tuck
	var gait: float = time*24.0 if step_phase<0 else step_phase
	if root.has_meta("robin_skin"):
		RobinSkin.pose(root,time,flying,pecking,walking,tuck,gait,terrain)
		return
	for side: float in [-1.0,1.0]:
		var wing: Node3D = joints.get("BirdWingL" if side>0 else "BirdWingR")
		if wing!=null:
			wing.rotation = Vector3(side*sin(time*30.0)*0.70*flying,-side*1.35*(1.0-flying),0)
		_angle(joints,"BirdLegL" if side>0 else "BirdLegR",sin(gait+side*PI/2)*0.34*walking-2.0*tuck)
	_angle(joints,"BirdHead",-.82*pecking+sin(time*2.0)*.06*(1.0-flying))
	if joints.has("BirdHead"): joints.BirdHead.rotation.x = .18*pecking
	_angle(joints,"BirdTail",sin(time*3.0)*.045*(1.0-flying))
