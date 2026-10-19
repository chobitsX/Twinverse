extends RefCounted
## Six authored sidewalk walkers use the existing world time and person rig.
## The paired narrow loops stay on the two paved strips; they are not a crowd model.
const COUNT: int = 6
const SPEED: float = 0.88
const RADIUS: float = 0.55
const INNER_X: float = 6.95
const OUTER_X: float = 8.05
const MIN_Z: float = 15.0
const MAX_Z: float = 108.0
const STRAIGHT: float = MAX_Z-MIN_Z-2.0*RADIUS
const LOOP_LENGTH: float = 2.0*STRAIGHT+2.0*PI*RADIUS
const OFFSETS: Array[float] = [18.0,47.0,143.0,28.0,79.0,138.0]

static func sample(time: float, index: int) -> Dictionary:
	var side: float = -1.0 if index<3 else 1.0
	var travel: float = maxf(0.0,time)*SPEED+OFFSETS[index]
	var d: float = fposmod(travel,LOOP_LENGTH)
	var center_x: float = side*(INNER_X+RADIUS)
	if d<STRAIGHT:
		return _pose(side*INNER_X,MIN_Z+RADIUS+d,0.0,1.0,travel)
	d -= STRAIGHT
	if d<PI*RADIUS:
		var angle: float = (PI if side>0.0 else 0.0)-side*d/RADIUS
		return _pose(center_x+RADIUS*cos(angle),MAX_Z-RADIUS+RADIUS*sin(angle),
			side*sin(angle),-side*cos(angle),travel)
	d -= PI*RADIUS
	if d<STRAIGHT:
		return _pose(side*OUTER_X,MAX_Z-RADIUS-d,0.0,-1.0,travel)
	d -= STRAIGHT
	var angle: float = (0.0 if side>0.0 else PI)-side*d/RADIUS
	return _pose(center_x+RADIUS*cos(angle),MIN_Z+RADIUS+RADIUS*sin(angle),
		side*sin(angle),-side*cos(angle),travel)

static func _pose(x: float, z: float, dx: float, dz: float, travel: float) -> Dictionary:
	return {"position":Vector3(x,.16,z),"heading":fposmod(atan2(-dz,dx),TAU),
		"moving":1.0,"travel":travel,"activity":"街道人行道步行"}
