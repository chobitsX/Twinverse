extends RefCounted
## A bounded authored demonstration for the existing third penguin.
## Every transform is resolved from the one world clock; no wildlife state.
const CYCLE_S: float = 80.0
const WATER_Y: float = -.10
const SURFACE_ROOT_Y: float = -.065
const LAND_HOME: Vector2 = Vector2(3.6, 8.2)
const EXIT_X: float = 8.8
const SOURCE: String = "https://www.antarctica.gov.au/about-antarctica/animals/penguins/"
const SelectedSkin = preload("res://scripts/experience/adelie_skin_motion.gd")

static func sample(time: float, entry_shore_z: float, exit_shore_z: float) -> Dictionary:
	var phase: float = fposmod(time, CYCLE_S)
	var entry_z: float = entry_shore_z + .28
	var water_z: float = entry_shore_z - 1.5
	var exit_z: float = exit_shore_z + .28
	var return_heading: float = atan2(-(LAND_HOME.y-exit_z), LAND_HOME.x-EXIT_X)
	var position: Vector3 = Vector3(LAND_HOME.x, 0, LAND_HOME.y)
	var heading: float = PI/2.0
	var swim: float = 0.0
	var walk: float = 0.0
	var activity: String = "岸上停歇"
	if phase >= 6.0 and phase < 26.0:
		var u: float = (phase-6.0)/20.0
		position.z = lerpf(LAND_HOME.y, entry_z, smoothstep(0.0, 1.0, u))
		walk = smoothstep(0.0, .15, u)*(1.0-smoothstep(.85, 1.0, u))
		activity = "岸上迈步"
	elif phase >= 26.0 and phase < 32.0:
		var u: float = smoothstep(0.0, 1.0, (phase-26.0)/6.0)
		position.z = lerpf(entry_z, water_z, u)
		swim = u
		walk = 1.0-u
		activity = "入水 · 身体转为水平"
	elif phase >= 32.0 and phase < 54.0:
		var angle: float = PI*smoothstep(0.0, 1.0, (phase-32.0)/22.0)
		position.x = 6.2-2.6*cos(angle)
		position.z = water_z-3.3*sin(angle)
		heading = atan2(3.3*cos(angle), 2.6*sin(angle))
		swim = 1.0
		activity = "水面鳍划水"
	elif phase >= 54.0 and phase < 60.0:
		var u: float = smoothstep(0.0, 1.0, (phase-54.0)/6.0)
		position.x = EXIT_X
		position.z = lerpf(water_z, exit_z, u)
		heading = lerp_angle(-PI/2.0, return_heading, smoothstep(.65, 1.0, u))
		swim = 1.0-u
		walk = u
		activity = "上岸 · 收鳍迈步"
	elif phase >= 60.0 and phase < 74.0:
		var u: float = (phase-60.0)/14.0
		var progress: float = smoothstep(0.0, 1.0, u)
		position.x = lerpf(EXIT_X, LAND_HOME.x, progress)
		position.z = lerpf(exit_z, LAND_HOME.y, progress)
		heading = return_heading
		walk = smoothstep(0.0, .15, u)*(1.0-smoothstep(.85, 1.0, u))
		activity = "岸上返回"
	elif phase >= 74.0:
		heading = lerp_angle(return_heading, PI/2.0, smoothstep(74.0, 78.0, phase))
	return {"position": position, "heading": heading, "swim": swim, "walk": walk,
		"head_bob": .025*walk*sin(TAU*time*1.25), "activity": activity, "phase_s": phase}

static func _pivot(bird: Node3D, name: String, at: Vector3, parts: Array[String], shift: Vector3 = Vector3.ZERO) -> Node3D:
	var joint: Node3D = Node3D.new()
	joint.name = name
	joint.position = at
	bird.add_child(joint)
	for part_name: String in parts:
		var part: Node3D = bird.find_child(part_name, true, false) as Node3D
		if part != null:
			part.reparent(joint, true)
			part.position += shift
	return joint

static func prepare(bird: Node3D) -> Dictionary:
	var skin: Dictionary = SelectedSkin.prepare(bird)
	if not skin.is_empty(): return skin
	var flippers: Array[Node3D] = []
	var legs: Array[Node3D] = []
	for side: int in [1, -1]:
		var suffix: String = "L" if side > 0 else "R"
		var flipper_parts: Array[String] = ["Flipper"+suffix, "FlipperInner"+suffix, "FlipperTrailingEdge"+suffix]
		# The runtime overlap keeps the original separate meshes at the shoulder.
		flippers.append(_pivot(bird, "ActivityFlipper"+suffix, Vector3(-.045, .46, side*.12), flipper_parts, Vector3(0, 0, -side*.035)))
		var foot_parts: Array[String] = ["ShortLeg"+suffix, "WebbedFoot"+suffix, "Toe"+suffix+"-1", "Toe"+suffix+"0", "Toe"+suffix+"1"]
		legs.append(_pivot(bird, "ActivityLeg"+suffix, Vector3(0, .10, side*.065), foot_parts))
	var feathers: Array[String] = []
	for index: int in range(5): feathers.append("ShortTail%02d" % index)
	return {"flippers": flippers, "legs": legs,
		"head": bird.find_child("HeadPivot", true, false),
		"tail": _pivot(bird, "ActivityTail", Vector3(-.10, .13, 0), feathers)}

static func apply(bird: Node3D, rig: Dictionary, pose: Dictionary, time: float) -> void:
	var swim: float = pose.swim
	var walk: float = pose.walk
	bird.rotation = Vector3(.018*walk*sin(TAU*time*1.25), pose.heading, -PI/2.0*swim)
	if rig.get("continuous_skin", false):
		SelectedSkin.pose(rig, pose, time)
		return
	(rig.head as Node3D).rotation.z = PI/2.0*swim+pose.head_bob
	(rig.tail as Node3D).rotation.z = PI/2.0*swim
	for index: int in range(2):
		var side: float = 1.0 if index == 0 else -1.0
		var flipper: Node3D = rig.flippers[index]
		flipper.rotation = Vector3(-side*swim*(1.1+.48*sin(TAU*time*1.4)), .10*swim*cos(TAU*time*1.4), 0)
		var stride: float = sin(TAU*time*1.25+float(index)*PI)
		var leg: Node3D = rig.legs[index]
		leg.rotation.z = .18*walk*stride-.10*swim
		leg.position.y = .10+walk*(.014*absf(stride)+.020*maxf(0.0, stride))

static func readout(host: Node) -> String:
	var data: Dictionary = host.coordinator.active_scene.get_meta("polar", {})
	if data.is_empty(): return "企鹅观察尚未就绪"
	var bird: Node3D = data.birds[2] if host._content_follow in [5, 6] else data.birds[0]
	return "%s · 同一世界时间\n%s" % [bird.get_meta("activity", "形态观察"),
		"第3只 · 80世界秒作者往返；可暂停/调时比较" if host._content_follow in [5, 6] else "同种成鸟参考；切至跟随往返比较岸上与水中"]

static func marks(host: Node) -> Array[Dictionary]:
	var data: Dictionary = host.coordinator.active_scene.get_meta("polar", {})
	if data.is_empty(): return []
	if host._content_follow in [5, 6]:
		return [{"at": data.activity_focus.global_position, "label": "同一企鹅 · "+str(data.birds[2].get_meta("activity", "观察")), "offset": Vector2(80, -75)}]
	var bird: Node3D = data.birds[0]
	if bird.has_meta("adelie_skin"):
		return [{"at": SelectedSkin.point(bird, "Head", Vector3(.080, .586, -.060)), "label": "白色眼环", "offset": Vector2(70, -80)},
			{"at": SelectedSkin.point(bird, "L_Clavicle", Vector3(.020, .290, -.175)), "label": "鳍状翼", "offset": Vector2(90, 60)}]
	return [{"at": bird.to_global(Vector3(.110, .611, .108)), "label": "白色眼环", "offset": Vector2(70, -80)},
		{"at": bird.to_global(Vector3(-.045, .331, .187)), "label": "鳍状翼", "offset": Vector2(90, 60)}]
