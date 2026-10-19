extends RefCounted
## Slow authored observation itinerary. All phases come from the host world time.
## Species reference supports ground foraging, not these distances or flight dynamics.
const PERIOD: float = 48.0
const FLIGHT_START: float = 22.0
const FLIGHT_END: float = 46.0
const STEP_DISTANCE: float = .42
const SOURCE: String = "https://www.allaboutbirds.org/guide/American_Robin/lifehistory"

static func phase(time: float, index: int) -> float:
	return fposmod(time+index*4.3,PERIOD)

static func base_position(index: int) -> Vector3:
	return Vector3(4.5+cos(index*2.4)*6.0,0,-12.5+sin(index*2.4)*4.5)

static func pulse(p: float, start: float, end: float) -> float:
	if p<=start or p>=end: return 0.0
	return pow(sin(PI*(p-start)/(end-start)),2)

static func body_basis(pose: Dictionary) -> Basis:
	# The original GLB faces +X. Pitch around local +Z, bank around local +X.
	return Basis(Vector3.UP,pose.heading)*Basis(Vector3.BACK,pose.pitch)*Basis(Vector3.RIGHT,pose.bank)

static func sample(time: float, index: int) -> Dictionary:
	var p: float = phase(time,index)
	var heading: float = index*1.7
	var displacement: Vector3 = Vector3.ZERO
	var pitch: float = 0.0
	var bank: float = 0.0
	var moving: float = 0.0
	var distance: float = 0.0
	var inspect: float = pulse(p,5.0,6.4)+pulse(p,12.0,13.4)+pulse(p,17.0,18.4)
	var wings: float = smoothstep(20.5,FLIGHT_START,p)*(1.0-smoothstep(FLIGHT_END,47.5,p))
	var activity: String = "停步查看 · 地面觅食参考"
	if p>=2.0 and p<4.0:
		var u: float = (p-2.0)/2.0
		displacement.x = STEP_DISTANCE*smoothstep(0.0,1.0,u)
		distance = displacement.x
		moving = 4.0*u*(1.0-u)
		activity = "短距离行走 · 寻找取食位置"
	elif p>=4.0 and p<9.0:
		displacement.x = STEP_DISTANCE
		distance = STEP_DISTANCE
		heading += PI*smoothstep(7.0,9.0,p)
		if p>=7.0: activity = "停步转身 · 改变查看方向"
	elif p>=9.0 and p<11.0:
		var u: float = (p-9.0)/2.0
		displacement.x = STEP_DISTANCE*(1.0-smoothstep(0.0,1.0,u))
		distance = 2.0*STEP_DISTANCE-displacement.x
		heading += PI
		moving = 4.0*u*(1.0-u)
		activity = "短距离行走 · 返回观察点"
	elif p>=11.0 and p<16.0:
		distance = 2.0*STEP_DISTANCE
		heading += PI*(1.0-smoothstep(14.0,16.0,p))
		if p>=14.0: activity = "停步转身 · 准备下一段活动"
	if p>=20.5 and p<FLIGHT_START: activity = "展开翅膀 · 准备起飞"
	if p>=FLIGHT_START and p<FLIGHT_END:
		var u: float = smoothstep(0.0,1.0,(p-FLIGHT_START)/(FLIGHT_END-FLIGHT_START))
		var angle: float = TAU*u
		displacement = Vector3(3.0*sin(angle),2.4*pow(sin(PI*u),2),1.2*(1.0-cos(angle)))
		# The curve's limiting tangent at both endpoints is +X, matching the
		# resting heading. Endpoint speed is zero after time reparameterisation.
		var tangent: Vector3 = Vector3(3.0*TAU*cos(angle),2.4*PI*sin(TAU*u),1.2*TAU*sin(angle))
		heading += atan2(-tangent.z,tangent.x)
		pitch = atan2(tangent.y,Vector2(tangent.x,tangent.z).length())
		bank = .14*sin(angle)
		activity = "起飞 · 收起双足" if p<26.0 else "落地 · 伸足接近地面" if p>42.0 else "飞行 · 缓速观察翼与尾"
	elif p>=FLIGHT_END: activity = "落地收翼 · 返回地面观察"
	var at: Vector3 = base_position(index)+displacement.rotated(Vector3.UP,index*1.7)
	return {"position":at,"height":displacement.y,"heading":heading,"pitch":pitch,"bank":bank,
		"walking":moving,"inspect":inspect,"wings":wings,"tuck":smoothstep(.06,.24,displacement.y),
		"step_phase":TAU*distance/.06,"activity":activity,"phase":p}
