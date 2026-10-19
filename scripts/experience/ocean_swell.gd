extends RefCounted
## CPU counterpart of ocean_water.gdshader's three displaced long waves.
## Authored visual water, not an ocean forecast; fine ripples only shade the surface.
const MEAN_LEVEL: float = 5.0
static func height_at(point: Vector2, world_time: float) -> float:
	var t: float = world_time*.7
	var a: float = point.dot(Vector2(.96,.28).normalized())*1.208+t*.84
	var b: float = point.dot(Vector2(-.38,.92).normalized())*1.698-t*1.17+3.1
	var c: float = point.dot(Vector2(.57,.82).normalized())*2.244+t*1.42+1.7
	var weight: float = 1.-smoothstep(32.,40.,maxf(absf(point.x),absf(point.y)))
	return MEAN_LEVEL+(sin(a)*.028+sin(b)*.018+sin(c)*.008)*weight
