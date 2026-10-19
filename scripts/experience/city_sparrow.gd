extends RefCounted
## Four authored small birds in a synthetic park, driven by the one world clock.
## Pedestrian proximity is a bounded teaching response, not a measured FID.
const SOURCE: String = "https://www.allaboutbirds.org/guide/Eurasian_Tree_Sparrow/id"
const URBAN_SOURCE: String = "https://www.nparks.gov.sg/docs/default-source/resources/2025/4703npb_ebook---spread.pdf"
const HUMAN_RESPONSE_SOURCE: String = "https://j-avianres.com/article/doi/10.1016/j.avrs.2025.100315"
const CityWalk = preload("res://scripts/experience/city_walk_path.gd")
const Traffic = preload("res://scripts/core/city_traffic.gd")
const Life = preload("res://scripts/experience/life_asset_motion.gd")
const BASES: Array[Vector3] = [
	Vector3(20.2,.21,25.4),Vector3(25.4,.21,27.2),
	Vector3(27.2,.21,24.5),Vector3(28.4,.21,28.0)]
const SEGMENT_SECONDS: float = 3.0
const HOP_SECONDS: float = .42
const SEGMENTS: int = 6
const PERIOD: float = SEGMENT_SECONDS*SEGMENTS
# These are scene design values. No field-study distance is transplanted here.
const ALERT_INNER_M: float = 3.2
const ALERT_OUTER_M: float = 3.7
const MAX_RETREAT_M: float = .27

static func walking_positions(time: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for index: int in range(Traffic.PARK_PEOPLE):
		positions.append(CityWalk.itinerary(time,index,Traffic.PARK_PEOPLE).position)
	return positions

static func point(index: int, step: int) -> Vector3:
	var angle: float = TAU*float(posmod(step,SEGMENTS))/float(SEGMENTS)+float(index)*.38
	return BASES[index]+Vector3(.36*cos(angle),0.,.28*sin(angle))

static func sample(time: float, index: int, walkers: Array[Vector3] = []) -> Dictionary:
	var clock: float = time+float(index)*2.1
	var segment: int = int(floor(fposmod(clock,PERIOD)/SEGMENT_SECONDS))
	var phase: float = fposmod(clock,SEGMENT_SECONDS)
	var from: Vector3 = point(index,segment)
	var to: Vector3 = point(index,segment+1)
	var moving: float = clampf(phase/HOP_SECONDS,0.0,1.0)
	var hopped: float = moving*moving*(3.0-2.0*moving)
	var position: Vector3 = from.lerp(to,hopped)
	position.y += .025*sin(PI*moving) if phase<HOP_SECONDS else 0.0
	var delta: Vector3 = to-from
	var heading: float = -atan2(delta.z,delta.x)
	var peck_phase: float = clampf((phase-HOP_SECONDS-.35)/.28,0.0,1.0)
	var peck: float = -.18*pow(sin(PI*peck_phase),2) if phase<HOP_SECONDS+1.1 else 0.0
	var nearby: Array[Vector3] = walkers if not walkers.is_empty() else walking_positions(time)
	var nearest_m: float = INF
	var nearest_at: Vector3 = Vector3.ZERO
	var retreat: Vector2 = Vector2.ZERO
	for walker: Vector3 in nearby:
		var away: Vector2 = Vector2(position.x-walker.x,position.z-walker.z)
		var distance: float = away.length()
		if distance<nearest_m:
			nearest_m=distance
			nearest_at=walker
		if distance<ALERT_OUTER_M and distance>.001:
			retreat += away/distance*(1.0-smoothstep(ALERT_INNER_M,ALERT_OUTER_M,distance))
	var alert: float = 1.0-smoothstep(ALERT_INNER_M,ALERT_OUTER_M,nearest_m)
	var step_away: Vector2 = retreat.limit_length(1.0)*MAX_RETREAT_M
	position += Vector3(step_away.x,0,step_away.y)
	# The lesson reports the drawn bird-to-person distance, not the approach
	# distance used to decide whether the authored response should start.
	nearest_m=INF
	for walker: Vector3 in nearby:
		var displayed_distance: float=Vector2(position.x-walker.x,position.z-walker.z).length()
		if displayed_distance<nearest_m:
			nearest_m=displayed_distance
			nearest_at=walker
	peck *= 1.0-alert
	if step_away.length_squared()>.000001:
		heading=lerp_angle(heading,-atan2(step_away.y,step_away.x),alert)
	var activity: String = "短跳" if phase<HOP_SECONDS else "地面查看 / 啄食示意"
	if alert>.50: activity="行人靠近 · 警觉停啄 / 草地短跳"
	elif alert>.05: activity="留意附近行人 · 地面查看"
	return {"position":position,"heading":heading,"peck":peck,
		"activity":activity,"segment":segment,"alert":alert,
		"nearest_pedestrian_m":nearest_m,"nearest_pedestrian_at":nearest_at}

static func build(stage: Node) -> void:
	var birds: Array[Node3D] = []
	for index: int in range(BASES.size()):
		var bird: Node3D = stage.assets.eurasian_tree_sparrow.instantiate()
		Life.prepare_materials(bird)
		bird.name="CityTreeSparrow_%02d" % index
		bird.set_meta("stable_id","3dworld:teaching:tree-sparrow:%04d" % index)
		stage.world_root.add_child(bird)
		birds.append(bird)
	stage.set_meta("city_sparrows",birds)
	stage.set_meta("city_sparrow_targets",[{"node":birds[0],
		"label":"欧亚树麻雀 · Passer montanus","role":"原创成鸟形态参考：栗色头顶、白颊黑斑与短圆锥喙；行人靠近时的警觉停啄/短跳使用作者阈值，不是实测起飞距离或城市种群。",
		"source_url":SOURCE,"distance":.72,"min_distance":.34,
		"focus_height":.09,"view_offset":Vector3(.55,.35,.45)}])

static func animate(stage: Node, time: float) -> void:
	var birds: Array = stage.get_meta("city_sparrows",[])
	var walkers: Array[Vector3] = []
	var actors: Array = stage.get_meta("actors",[])
	for index: int in range(mini(Traffic.PARK_PEOPLE,actors.size())):
		walkers.append(actors[index].node.position)
	for index: int in range(birds.size()):
		var pose: Dictionary = sample(time,index,walkers)
		var bird: Node3D = birds[index]
		bird.position=pose.position
		bird.rotation=Vector3(0.0,pose.heading,pose.peck)
		bird.set_meta("activity",pose.activity)
		bird.set_meta("nearest_pedestrian_m",pose.nearest_pedestrian_m)
		bird.set_meta("nearest_pedestrian_at",pose.nearest_pedestrian_at)
		bird.set_meta("pedestrian_alert",pose.alert)
