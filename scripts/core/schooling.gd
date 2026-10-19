extends RefCounted
## Authored local steering rules, not calibrated Chromis viridis behaviour.
const MODEL_ID: String = "local-schooling-teaching-v1"
const SOURCE: String = "https://www.red3d.com/cwr/boids/"
const COUNT: int = 24
const STEP: float = .05
const CENTER: Vector3 = Vector3(.3,1.65,-3.)
const HALF_EXTENT: Vector3 = Vector3(1.35,.42,.85)
const NEIGHBOR_RADIUS: float = .55
const SEPARATION_RADIUS: float = .16
const MAX_SPEED: float = .24
const MAX_ACCELERATION: float = .45
var started_at_s: float = 0.
var steps: int = 0
var alignment: bool = true
var positions: Array[Vector3] = []
var velocities: Array[Vector3] = []

func _init() -> void:
	initialize_at(0.)

func initialize_at(time: float) -> void:
	started_at_s=time
	steps=0
	alignment=true
	positions.clear()
	velocities.clear()
	for i: int in range(COUNT):
		var angle: float = i*2.39996323
		var radius: float = sqrt((i+.5)/COUNT)
		positions.append(CENTER+Vector3(cos(angle)*radius*.68,sin(i*5.27)*.18,sin(angle)*radius*.48))
		velocities.append(Vector3(.15,0,.055*sin(i*1.7)))

func neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	for j: int in range(COUNT):
		if j==index: continue
		var offset: Vector3 = positions[j]-positions[index]
		# Broad 300-degree influence field, not a measured visual field.
		if offset.length_squared()<=NEIGHBOR_RADIUS*NEIGHBOR_RADIUS and (offset.length_squared()<SEPARATION_RADIUS*SEPARATION_RADIUS or velocities[index].normalized().dot(offset.normalized())>-.8660254): result.append(j)
	return result

func steering(index: int) -> Vector3:
	var nearby: Array[int] = neighbors(index)
	var separation: Vector3 = Vector3.ZERO
	var average_position: Vector3 = Vector3.ZERO
	var average_velocity: Vector3 = Vector3.ZERO
	for j: int in nearby:
		var away: Vector3 = positions[index]-positions[j]
		var distance: float = away.length()
		if distance<SEPARATION_RADIUS:
			separation+=(away/distance if distance>.000001 else Vector3(1 if index<j else -1,0,0))*(1.-distance/SEPARATION_RADIUS)
		average_position+=positions[j]
		average_velocity+=velocities[j]
	var force: Vector3 = separation*1.8
	if not nearby.is_empty():
		force+=(average_position/nearby.size()-positions[index])*.20
		if alignment: force+=(average_velocity/nearby.size()-velocities[index])*1.6
	# A weak bounded habitat preference keeps this local lesson observable.
	# It is separate from neighbour interactions and never prescribes a trajectory.
	var offset: Vector3 = positions[index]-CENTER
	force+=Vector3(-offset.z,0,offset.x)*.018-offset*.035
	force.y-=offset.y*.25
	for axis: int in range(3):
		var edge: float = HALF_EXTENT[axis]-.18
		if absf(offset[axis])>edge: force[axis]-=signf(offset[axis])*(absf(offset[axis])-edge)*1.8
	var speed: float = velocities[index].length()
	if speed<.12: force+=velocities[index].normalized()*(.12-speed)*.9
	return force.limit_length(MAX_ACCELERATION)

func advance_to(time: float) -> void:
	if not is_finite(time) or time<started_at_s: return
	var required: int = int(floor((time-started_at_s+.00000001)/STEP))
	while steps<required:
		var next_velocity: Array[Vector3] = []
		# Compute all decisions from one old state; no index-order leader.
		for i: int in range(COUNT): next_velocity.append((velocities[i]+steering(i)*STEP).limit_length(MAX_SPEED))
		for i: int in range(COUNT):
			positions[i]+=next_velocity[i]*STEP
			for axis: int in range(3):
				var relative: float = positions[i][axis]-CENTER[axis]
				if absf(relative)>HALF_EXTENT[axis]:
					positions[i][axis]=CENTER[axis]+signf(relative)*HALF_EXTENT[axis]
					next_velocity[i][axis]=-signf(relative)*absf(next_velocity[i][axis])*.5
		velocities=next_velocity
		steps+=1

func perturb_representative() -> void:
	# A visible teaching turn, not a predator or external fluid-force simulation.
	velocities[0]=velocities[0].rotated(Vector3.UP,PI*.65)

func metrics() -> Dictionary:
	var center: Vector3 = Vector3.ZERO
	var direction: Vector3 = Vector3.ZERO
	var minimum: float = INF
	for i: int in range(COUNT):
		center+=positions[i]
		direction+=velocities[i].normalized()
		for j: int in range(i): minimum=minf(minimum,positions[i].distance_to(positions[j]))
	return {"center":center/COUNT,"direction":direction/COUNT,"order":direction.length()/COUNT,"minimum_distance":minimum,"neighbors":neighbors(0)}

func checkpoint() -> Dictionary:
	var points: Array = []
	var speeds: Array = []
	for i: int in range(COUNT):
		points.append([positions[i].x,positions[i].y,positions[i].z])
		speeds.append([velocities[i].x,velocities[i].y,velocities[i].z])
	return {"model_id":MODEL_ID,"started_at_s":started_at_s,"steps":steps,"alignment":alignment,"positions":points,"velocities":speeds}

func snapshot() -> Dictionary:
	return checkpoint()

static func number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

static func checkpoint_error(value: Dictionary, time: float) -> String:
	if value.get("model_id")!=MODEL_ID: return "incompatible"
	if not number(value.get("started_at_s")) or value.started_at_s<0 or value.started_at_s>time: return "invalid_school_time"
	if not number(value.get("steps")) or value.steps<0 or floorf(value.steps)!=value.steps or value.steps>2.e13: return "invalid_school_steps"
	var remainder: float = time-(float(value.started_at_s)+float(value.steps)*STEP)
	if remainder<-.00001 or remainder>=STEP+.00001: return "invalid_school_time"
	if not value.get("alignment") is bool: return "invalid_school_mode"
	for key: String in ["positions","velocities"]:
		if not value.get(key) is Array or value[key].size()!=COUNT: return "invalid_school_count"
		for item: Variant in value[key]:
			if not item is Array or item.size()!=3: return "invalid_school_vector"
			for component: Variant in item:
				if not number(component): return "invalid_school_vector"
			var v: Vector3 = vector(item)
			if key=="velocities" and v.length()>MAX_SPEED+.00001: return "invalid_school_speed"
			if key=="positions":
				for axis: int in range(3):
					if absf(v[axis]-CENTER[axis])>HALF_EXTENT[axis]+.00001: return "invalid_school_bounds"
	return ""

func restore(value: Dictionary) -> void:
	started_at_s=float(value.started_at_s)
	steps=int(value.steps)
	alignment=value.alignment
	for i: int in range(COUNT):
		positions[i]=vector(value.positions[i])
		velocities[i]=vector(value.velocities[i])
