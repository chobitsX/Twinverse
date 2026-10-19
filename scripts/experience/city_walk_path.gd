extends RefCounted
## Two authored loops on the existing east/west park paths, in metres.
## Rounded corners keep heading continuous; there is no crowd solver.
const CORNER_RADIUS: float = 1.0
const LENGTH: float = 53.4+2.0*PI
const ROUTES: Array = [[17.0,31.7,17.0,33.0],[34.3,49.0,17.0,33.0]]
const SPEED: float = .9
const WALK_SECONDS: float = 48.0
const REST_SECONDS: float = 12.0
const PERIOD: float = WALK_SECONDS+REST_SECONDS
const MEAN_SPEED: float = SPEED*WALK_SECONDS/PERIOD
const RAMP_SECONDS: float = .8
# Preserve the itinerary's total distance and mean spacing after smoothing stops.
const CRUISE_SPEED: float = SPEED*WALK_SECONDS/(WALK_SECONDS-RAMP_SECONDS)

static func itinerary(time: float, index: int, count: int) -> Dictionary:
	var route: int = posmod(index,2)
	var route_index: int = index/2
	var route_count: int = maxi(1,(count+1-route)/2)
	# Keep stop phases spaced as in the original 26-person park; widening the
	# phase interval to one full cycle made neighbours converge during rest.
	var offset: float = float(route_index)*PERIOD/float(count)
	var clock: float = time+offset
	var phase: float = fposmod(clock,PERIOD)
	var t: float = minf(phase,WALK_SECONDS)
	var integral: float = t-RAMP_SECONDS*.5
	if t<RAMP_SECONDS:
		integral = t*t/(2.0*RAMP_SECONDS)
	elif t>WALK_SECONDS-RAMP_SECONDS:
		integral = WALK_SECONDS-RAMP_SECONDS-pow(WALK_SECONDS-t,2)/(2.0*RAMP_SECONDS)
	var travel: float = floor(clock/PERIOD)*WALK_SECONDS*SPEED+integral*CRUISE_SPEED
	var distance: float = travel-MEAN_SPEED*offset+float(route_index)*LENGTH/float(route_count)
	var pose: Dictionary = sample(distance,route)
	var rest_offset: float = maxf(1.0-smoothstep(0.0,1.2,phase),smoothstep(WALK_SECONDS-1.8,WALK_SECONDS,phase))*.70
	pose.position += Vector3(0,0,rest_offset).rotated(Vector3.UP,pose.heading)
	pose.moving = clampf(minf(t,WALK_SECONDS-t)/RAMP_SECONDS,0.0,1.0)
	pose.travel = travel
	pose.route = route
	return pose

static func sample(distance: float, route: int = 0) -> Dictionary:
	var d: float = fposmod(LENGTH-distance if route==1 else distance,LENGTH)
	var bounds: Array = ROUTES[route]
	var left: float = bounds[0]
	var right: float = bounds[1]
	var bottom: float = bounds[2]
	var top: float = bounds[3]
	var starts: Array[Vector2] = [Vector2(left+CORNER_RADIUS,top),Vector2(right,top-CORNER_RADIUS),Vector2(right-CORNER_RADIUS,bottom),Vector2(left,bottom+CORNER_RADIUS)]
	var directions: Array[Vector2] = [Vector2.RIGHT,Vector2(0,-1),Vector2.LEFT,Vector2(0,1)]
	var centers: Array[Vector2] = [Vector2(right-CORNER_RADIUS,top-CORNER_RADIUS),Vector2(right-CORNER_RADIUS,bottom+CORNER_RADIUS),Vector2(left+CORNER_RADIUS,bottom+CORNER_RADIUS),Vector2(left+CORNER_RADIUS,top-CORNER_RADIUS)]
	for side: int in range(4):
		var length: float = right-left-2.0*CORNER_RADIUS if side%2==0 else top-bottom-2.0*CORNER_RADIUS
		if d<=length:
			var p: Vector2 = starts[side]+directions[side]*d
			return _pose(p,float(side)*PI/2,route)
		d -= length
		if d<=PI*CORNER_RADIUS/2.0:
			var angle: float = PI/2-float(side)*PI/2-d/CORNER_RADIUS
			var p: Vector2 = centers[side]+Vector2(cos(angle),sin(angle))*CORNER_RADIUS
			return _pose(p,float(side)*PI/2+d/CORNER_RADIUS,route)
		d -= PI*CORNER_RADIUS/2.0
	return _pose(starts[0],0.0,route)

static func _pose(point: Vector2, heading: float, route: int) -> Dictionary:
	return {"position":Vector3(point.x,.37,point.y),"heading":fposmod(heading+PI if route==1 else heading,TAU)}
