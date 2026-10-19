extends RefCounted
## Original atmosphere reference, not recorded or calibrated Antarctic acoustics.
## Receives the existing host sample time; owns no clock or world state.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _wind: Vector2 = Vector2.ZERO
var _low: Vector2 = Vector2.ZERO
var _foam: Vector2 = Vector2.ZERO

func _init() -> void:
	_rng.seed = 22591

func next_frame(t: float, weight: float) -> Vector2:
	if weight < .00000001: return Vector2.ZERO
	var noise: Vector2 = Vector2(_rng.randf_range(-1,1),_rng.randf_range(-1,1))
	_low = _low.lerp(noise,.0025)
	_wind = _wind.lerp(noise,.038)
	_foam = _foam.lerp(noise,.19)
	var gust: float = .72+.16*sin(t*.29)+.10*sin(t*.097)
	var wash: float = .12+.88*pow(.5+.5*sin(t*.92),2.0)
	var air: Vector2 = (_wind-_low)*.19*gust+_low*.08
	var water: Vector2 = (_foam-_wind)*.041*wash
	return (air+water)*weight
