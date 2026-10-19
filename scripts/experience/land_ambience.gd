extends RefCounted
## Original synthetic atmospheres, not species recordings or positional sources.
## Receives the host audio sample time; never advances or reads world simulation.
const RATE: float = 22050.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _leaf: Vector2 = Vector2.ZERO
var _water: Vector2 = Vector2.ZERO
var _road: Vector2 = Vector2.ZERO
var _rumble: Vector2 = Vector2.ZERO
var _bird_start: float = -10.0
var _next_bird: float = 1.3
var _bird_duration: float = 1.2
var _bird_frequency: float = 2200.0
var _bird_pan: float = 0.2
var _bird_phase: float = 0.0
var _vehicle_start: float = -10.0
var _next_vehicle: float = 0.8
var _vehicle_duration: float = 5.0
var _vehicle_direction: float = 1.0
var _engine_phase: float = 0.0

func _init() -> void:
	_rng.seed = 92091

func next_frame(t: float, weights: Vector2) -> Vector2:
	if weights.length_squared()<1e-12: return Vector2.ZERO
	var noise: Vector2 = Vector2(_rng.randf_range(-1,1),_rng.randf_range(-1,1))
	_leaf = _leaf.lerp(noise,.055)
	_water = _water.lerp(noise,.30)
	_road = _road.lerp(noise,.024)
	_rumble = _rumble.lerp(noise,.005)
	var woodland: Vector2 = Vector2.ZERO
	if weights.x>.000001:
		var wind: float = .85+.12*sin(t*.41)+.08*sin(t*.137)
		woodland = _leaf*.18*wind+(_water-_leaf)*.027
		if t>=_next_bird:
			_bird_start = t
			_bird_duration = _rng.randf_range(.95,1.65)
			_bird_frequency = _rng.randf_range(1800,2900)
			_bird_pan = _rng.randf_range(-.65,.65)
			_next_bird = t+_bird_duration+_rng.randf_range(3.2,6.5)
		var age: float = t-_bird_start
		if age>=0 and age<_bird_duration:
			var syllable: float = fposmod(age,.31)/.21
			if syllable<1.0:
				var frequency: float = _bird_frequency+700*sin(syllable*PI)+80*sin(age*TAU*29)
				_bird_phase = fposmod(_bird_phase+TAU*frequency/RATE,TAU)
				var envelope: float = pow(sin(syllable*PI),2.0)*smoothstep(0,.08,age)*(1-smoothstep(_bird_duration-.15,_bird_duration,age))
				woodland += _pan((sin(_bird_phase)+.12*sin(_bird_phase*2))*.024*envelope,_bird_pan)
	var city: Vector2 = Vector2.ZERO
	if weights.y>.000001:
		city = _road*.08+_rumble*.18
		if t>=_next_vehicle:
			_vehicle_start = t
			_vehicle_duration = _rng.randf_range(4.5,7.0)
			_vehicle_direction = -1.0 if _rng.randf()<.5 else 1.0
			_next_vehicle = t+_vehicle_duration+_rng.randf_range(2.0,5.0)
		var passage: float = (t-_vehicle_start)/_vehicle_duration
		if passage>=0 and passage<1:
			var envelope: float = pow(sin(passage*PI),2.0)
			_engine_phase = fposmod(_engine_phase+TAU*(80+20*sin(passage*PI))/RATE,TAU)
			var rolling: float = (_road.x+_road.y)*.22+sin(_engine_phase)*.012+sin(_engine_phase*2)*.003
			city += _pan(rolling*envelope,lerpf(-.75,.75,passage)*_vehicle_direction)
	return woodland*weights.x+city*weights.y

func _pan(sample: float, pan: float) -> Vector2:
	return sample*Vector2(sqrt((1-pan)*.5),sqrt((1+pan)*.5))
