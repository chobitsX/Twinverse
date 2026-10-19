extends RefCounted
## Authored schooling/inspection demonstration, not calibrated predator or prey dynamics.
const PERIOD: float = 52.0
const OFFSETS: Array[Vector3] = [
	Vector3(.66,0,0), Vector3(.34,.04,-.22), Vector3(.34,-.03,.22),
	Vector3(.02,-.04,-.36), Vector3(.02,.06,0), Vector3(.02,-.02,.36),
	Vector3(-.30,.03,-.36), Vector3(-.30,-.05,0), Vector3(-.30,.06,.36),
	Vector3(-.62,-.02,-.36), Vector3(-.62,.04,0), Vector3(-.62,-.04,.36)]

static func position_at(time: float, index: int) -> Vector3:
	var angle: float = time*.10
	var center: Vector3 = Vector3(cos(angle)*.48,1.36+sin(time*.07)*.04,-2.2+sin(angle)*.27)
	var heading: float = atan2(-cos(angle)*.27,-sin(angle)*.48)
	var offset: Vector3 = OFFSETS[index]
	if index==0:
		var phase: float = fposmod(time,PERIOD)
		if phase>14 and phase<38:
			var u: float = smoothstep(0.0,1.0,(phase-14.0)/24.0)
			var reach: float = sin(PI*u)
			offset += Vector3(1.05*reach*reach,-.12*reach*reach,.48*sin(TAU*u)*reach)
	return center+offset.rotated(Vector3.UP,heading)

static func sample(time: float, index: int) -> Dictionary:
	var position: Vector3 = position_at(time,index)
	var velocity: Vector3 = (position_at(time+.01,index)-position_at(time-.01,index))/.02
	var phase: float = fposmod(time,PERIOD)
	var activity: String = "礁旁集群 · 食性包括鱼类与甲壳类"
	if index==0 and phase>14 and phase<26: activity = "离开群体巡游 · 教学动作"
	elif index==0 and phase>=26 and phase<38: activity = "转向返回群体 · 教学动作"
	return {"position":position,"yaw":atan2(-velocity.z,velocity.x),"pitch":atan2(velocity.y,Vector2(velocity.x,velocity.z).length()),"activity":activity}
