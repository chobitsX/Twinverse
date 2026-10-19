extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Authored observation sequence, not a reconstruction of the paper's kinematics.
## Uses the existing world clock; selected mesh has a locally weighted skin.
const Swell = preload("res://scripts/experience/ocean_swell.gd")
const SelectedSkin = preload("res://scripts/experience/turtle_skin_motion.gd")
const HEAD_PIVOT: Vector3 = Vector3(.39,.015,0)
const NOSTRIL: Vector3 = Vector3(.735,.048,0)
const MODEL_SCALE: float = .65
const SOURCE: String = "https://pmc.ncbi.nlm.nih.gov/articles/PMC9622894/"
const SPECIES_SOURCE: String = "https://www.fisheries.noaa.gov/species/green-turtle"
const PERIOD: float = 8.0
const ROUTE_PERIOD: float = 72.0
const TIMES: Array[float] = [0.0,1.4,2.4,3.2,4.4,8.0]
const POSES: Array[Vector3] = [Vector3(-.15,0,0),Vector3(-.70,.12,-.08),Vector3(.65,-.05,.08),Vector3(.78,-.42,.04),Vector3(-.15,0,0),Vector3(-.15,0,0)]
const ACTIVITIES: Array[String] = ["抬鳍 · 准备下一次划动","下划 · 前鳍肢主要划动","内扫 · 前鳍肢向身体下方收拢","舒展 · 接入滑行","滑行 · 前鳍肢舒展、身体继续前进"]

static func _stroke(time: float) -> Dictionary:
	var phase: float = fposmod(time,PERIOD)
	var segment: int = 0
	while segment<4 and phase>=TIMES[segment+1]: segment+=1
	var amount: float = smoothstep(TIMES[segment],TIMES[segment+1],phase)
	var fore: Vector3 = POSES[segment].lerp(POSES[segment+1],amount)
	return {"phase":phase,"segment":segment,"activity":I18n.strings(ACTIVITIES)[segment],
		"fore_left":fore,"fore_right":Vector3(-fore.x,-fore.y,fore.z),
		"hind_left":Vector3(.05,-.45,-.035),"hind_right":Vector3(-.05,.45,-.035)}

static func surface_amount(time: float) -> float:
	var t: float = fposmod(time,ROUTE_PERIOD)
	return smoothstep(20.,34.,t)*(1.-smoothstep(42.,60.,t))

static func _route(time: float, root: Node3D = null) -> Dictionary:
	var modulation: float = TAU*(time-2.5)/PERIOD
	var angle: float = TAU*fposmod(time,ROUTE_PERIOD)/ROUTE_PERIOD+5.7+.025*sin(modulation)
	var position: Vector3 = Vector3(2.6*cos(angle),1.85+.12*sin(2.*angle),-3.8+sin(angle))
	var tangent: Vector3 = Vector3(-2.6*sin(angle),0,cos(angle))
	var yaw: float = atan2(-tangent.z,tangent.x)
	var amount: float = surface_amount(time)
	var head_angle: float = .6*smoothstep(.5,1.,amount)
	var nose: Vector3 = (HEAD_PIVOT+Basis(Vector3.BACK,head_angle)*(NOSTRIL-HEAD_PIVOT))*MODEL_SCALE
	var skinned: bool = root!=null and root.has_meta("turtle_skin")
	if skinned: nose=SelectedSkin.raised_nose(root,head_angle)
	var nose_horizontal: Vector3 = position+Basis(Vector3.UP,yaw)*nose
	var surface: float = Swell.height_at(Vector2(nose_horizontal.x,nose_horizontal.z),time)
	position.y=lerpf(position.y,surface-nose.y+.045 if skinned else surface-.10,amount)
	return {"position":position,"yaw":yaw,"head_angle":head_angle,"amount":amount}

static func sample(time: float, root: Node3D = null) -> Dictionary:
	var pose: Dictionary = _stroke(time)
	var route: Dictionary = _route(time,root)
	var velocity: Vector3 = (_route(time+.01,root).position-_route(time-.01,root).position)/.02
	var pitch: float = atan2(velocity.y,Vector2(velocity.x,velocity.z).length())
	# At the interface the body levels while the neck raises the nostrils.
	pitch=lerpf(pitch,0.,smoothstep(.88,1.,route.amount))
	pose.merge(route,true)
	pose.pitch=pitch
	var t: float = fposmod(time,ROUTE_PERIOD)
	pose.route_activity=I18n.text("水下巡游")
	if t>=20. and t<34.: pose.route_activity=I18n.text("上浮 · 接近海面")
	elif t>=34. and t<42.: pose.route_activity=I18n.text("水面停留 · 鼻端露出换气示意")
	elif t>=42. and t<60.: pose.route_activity=I18n.text("下潜 · 返回水下")
	if route.amount>.95:
		var hold: Vector3 = Vector3(-.15+sin(time*1.5)*.035,0,0)
		pose.fore_left=pose.fore_left.lerp(hold,smoothstep(.95,1.,route.amount))
		pose.fore_right=Vector3(-pose.fore_left.x,-pose.fore_left.y,pose.fore_left.z)
	pose.activity=pose.route_activity+" · "+pose.activity if route.amount<.95 else pose.route_activity
	return pose

static func prepare(root: Node3D) -> void:
	if SelectedSkin.prepare(root): return
	var pivot: Node3D = Node3D.new()
	pivot.name="BreathingHeadPivot"
	root.add_child(pivot)
	pivot.position=HEAD_PIVOT
	for mesh: Node in root.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name).begins_with("Head") or str(mesh.name).begins_with("Neck") or str(mesh.name).begins_with("Eye") or str(mesh.name).begins_with("Nostril"):
			mesh.reparent(pivot,true)
	root.set_meta("breathing_head",pivot)

static func nose_position(root: Node3D) -> Vector3:
	if root.has_meta("turtle_skin"): return SelectedSkin.point(root,"Head","Nose")
	var center: Vector3 = Vector3.ZERO
	var count: int = 0
	for node: Node in root.find_children("Nostril*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		center+=mesh.to_global(mesh.get_aabb().get_center())
		count+=1
	return center/float(count) if count>0 else root.global_position

static func surface_marks(root: Node3D,time: float) -> Array[Dictionary]:
	var nose: Vector3 = nose_position(root)
	var water: Vector3 = Vector3(nose.x,Swell.height_at(Vector2(nose.x,nose.z),time),nose.z)
	return [{"at":nose,"label":I18n.text("鼻端 · 上浮后呼吸空气"),"offset":Vector2(95,-60)},
		{"at":water,"label":I18n.text("海面 · 空气与水的边界"),"offset":Vector2(-100,65),"link":0}]

static func readout(root: Node3D,time: float) -> String:
	var nose: Vector3 = nose_position(root)
	var gap: float = nose.y-Swell.height_at(Vector2(nose.x,nose.z),time)
	var next: float = fposmod(20.-fposmod(time,ROUTE_PERIOD),ROUTE_PERIOD)
	return I18n.text("%s\n鼻端距海面 %+.2f m（场景尺度）\n72秒循环为教学设置；可调快时间观察") % [root.get_meta("activity",I18n.text("水下巡游")),gap] if surface_amount(time)>0 else I18n.text("水下巡游 · 约%d秒后开始上浮\n海龟需呼吸空气；可调快时间观察") % ceili(next)

static func apply_fins(actor: Dictionary, pose: Dictionary) -> void:
	if actor.node.has_meta("turtle_skin"):
		SelectedSkin.pose(actor.node,pose)
		actor.node.set_meta("turtle_phase",pose.segment)
		return
	var keys: Array[String] = ["FlipperL","FlipperR","HindFlipperL","HindFlipperR"]
	var rotations: Array[Vector3] = [pose.fore_left,pose.fore_right,pose.hind_left,pose.hind_right]
	for i: int in range(keys.size()):
		var fin: Node3D = actor.fins[keys[i]]
		if fin!=null: fin.rotation=rotations[i]
	if actor.node.has_meta("breathing_head"): actor.node.get_meta("breathing_head").rotation.z=pose.head_angle
	actor.node.set_meta("turtle_phase",pose.segment)

static func marks(root: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if root.has_meta("turtle_skin"):
		for item: Array in [["Body","Carapace",I18n.text("背甲 · 保护身体"),Vector2(-100,-85)],
			["FlipperL","Flipper",I18n.text("长前鳍肢 · 主要划动"),Vector2(110,55)],
			["HindFlipperR","HindFlipper",I18n.text("短后鳍肢 · 巡游时收后"),Vector2(-115,70)]]:
			result.append({"at":SelectedSkin.point(root,item[0],item[1]),"label":item[2],"offset":item[3]})
		return result
	for item: Array in [["Carapace",I18n.text("背甲 · 保护身体"),Vector2(-100,-85)],["FlipperLSurface",I18n.text("长前鳍肢 · 主要划动"),Vector2(110,55)],["HindFlipperRSurface",I18n.text("短后鳍肢 · 巡游时收后"),Vector2(-115,70)]]:
		var mesh: MeshInstance3D = root.find_child(item[0],true,false) as MeshInstance3D
		if mesh!=null: result.append({"at":mesh.to_global(mesh.get_aabb().get_center()),"label":item[1],"offset":item[2]})
	return result
