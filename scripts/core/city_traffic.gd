extends RefCounted
## Authored teaching itinerary in scene metres, evaluated from the only world time.
## No traffic forecast, collision solver, jurisdictional signal standard or new clock.
const PERIOD: float = 48.0
const WALK_START: float = 24.0
const ENTRY_END: float = 26.0
const CLEAR_END: float = 44.0
const WALK_DURATION: float = 16.0
const CROSS_X: float = -11.5
const PARK_PEOPLE: int = 26

static func clear_end(walk_duration: float = WALK_DURATION) -> float:
	return WALK_START+maxf(CLEAR_END-WALK_START,walk_duration+4.0)

static func cycle_period(walk_duration: float = WALK_DURATION) -> float:
	return clear_end(walk_duration)+4.0

static func phase(time: float, walk_duration: float = WALK_DURATION) -> float:
	return fposmod(time,cycle_period(walk_duration))

static func vehicle_green(time: float, axis: int, walk_duration: float = WALK_DURATION) -> bool:
	var p: float=phase(time,walk_duration)
	return p<20.0 if axis==0 else p>=24.0 and p<clear_end(walk_duration)

static func pedestrian_signal(time: float, walk_duration: float = WALK_DURATION) -> String:
	var p: float = phase(time,walk_duration)
	if p>=WALK_START and p<ENTRY_END: return "开始通行"
	if p>=ENTRY_END and p<clear_end(walk_duration): return "清空过街带 · 新到者等待"
	return "等待"

static func wait_seconds(time: float, walk_duration: float = WALK_DURATION) -> float:
	return fposmod(WALK_START-phase(time,walk_duration),cycle_period(walk_duration))

static func progress(elapsed: float, walk_duration: float = WALK_DURATION) -> float:
	var t: float = clampf(elapsed,0.0,walk_duration)
	if t<1.0: return .5*t*t/(walk_duration-1.0)
	if t>walk_duration-1.0: return 1.0-.5*pow(walk_duration-t,2)/(walk_duration-1.0)
	return (t-.5)/(walk_duration-1.0)

static func surface_height(z: float) -> float:
	return lerpf(.04,.16,clampf((absf(z)-5.8)/1.7,0.0,1.0))

static func pedestrian(time: float, index: int, walk_duration: float = WALK_DURATION) -> Dictionary:
	var p: float = phase(time,walk_duration)
	var ordinal: int = index
	var initial: float = 1.0 if index==0 else -1.0
	var direction: float = initial*(1.0 if floori(time/cycle_period(walk_duration))%2==0 else -1.0)
	var elapsed: float = p-WALK_START-float(ordinal)*.9
	var fraction: float = progress(elapsed,walk_duration)
	var extent: float = 8.2
	var z: float = direction*lerpf(-extent,extent,fraction)
	var moving: float = clampf(minf(elapsed,walk_duration-elapsed),0.0,1.0)
	var turn: float = smoothstep(walk_duration+1.0,walk_duration+3.0,elapsed)
	var heading: float = (-PI*.5 if direction>0 else PI*.5)+PI*turn
	return {"position":Vector3(CROSS_X+(-.6 if index==0 else .6),surface_height(z),z),
		"heading":heading,"moving":moving,"fraction":fraction,"travel":fraction*extent*2.0,
		"activity":"正在过街" if moving>0 else "已到达 · 留在路缘内" if fraction>=1 else "路缘内等待 · 查看通行信号"}

static func vehicle(time: float, index: int, walk_duration: float = WALK_DURATION) -> Dictionary:
	var north: bool = index>=6
	var cohort: int = int((index%6)/3)
	var period: float=cycle_period(walk_duration)
	var p: float = fposmod(time-(24.0 if north else 0.0)-cohort*period,period*2.0)
	var order: int = index%3
	var delay: float = order*1.6
	var elapsed: float = maxf(0.0,p-delay)
	# Depart smoothly; allow already-cleared cars to keep moving past the
	# local boundary. Every queue member is hidden before the authored wrap.
	var travel: float = 9.0*(.5*elapsed*elapsed if elapsed<1.0 else elapsed-.5)
	var x: float = -15.8-order*5.4+travel
	var activity: String = "通过路口" if elapsed>0 else "停止线前等待"
	if p>=23.0:
		var approach_start: float=period*2.0-36.0
		var approach_end: float=period*2.0-24.0
		var approach: float = clampf((p-approach_start)/12.0,0.0,1.0)
		x = lerpf(-145.0-order*5.4,-15.8-order*5.4,smoothstep(0.0,1.0,approach))
		activity = "接近停止线" if p>=approach_start and p<approach_end else "停止线前等待"
	return {"position":Vector3(x,.04,3.0).rotated(Vector3.UP,PI*.5 if north else 0.0),
		"heading":PI*.5 if north else 0.0,"visible":absf(x)<117.0,"distance":x,"activity":activity}

static func readout(time: float, walk_duration: float = WALK_DURATION) -> String:
	var p: float = phase(time,walk_duration)
	var cars: String = "横向车辆通行" if p<20 else "纵向车辆通行" if p>=24 and p<clear_end(walk_duration) else "两向车辆等待 · 清空路口"
	var pedestrians: String = pedestrian_signal(time,walk_duration)
	if p<WALK_START or p>=clear_end(walk_duration): pedestrians += " · 约%d秒后开始" % ceili(wait_seconds(time,walk_duration))
	return "行人：%s\n%s" % [pedestrians,cars]
