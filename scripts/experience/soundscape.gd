extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Original listening aids, not field recordings or scientific sonification.
## One host-owned sample clock; no writes to simulation state.

const LandAmbience = preload("res://scripts/experience/land_ambience.gd")
const PolarAmbience = preload("res://scripts/experience/polar_ambience.gd")
const SAMPLE_RATE: float = 22050.0
var master: float = 0.8
var environment_volume: float = 0.8
var music_volume: float = 0.3
var effects_volume: float = 0.65
var muted: bool = false
var _land: LandAmbience = LandAmbience.new()
var _polar: PolarAmbience = PolarAmbience.new()
var _polar_weight: float = 0.0
var _polar_target: float = 0.0
var _desert_weight: float = 0.0
var _desert_target: float = 0.0
var _land_weights: Vector2 = Vector2.ZERO
var _land_target: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sample_index: int = 0
var _low: float = 0.0
var _air: float = 0.0
var _gain: float = 0.0
var _levels: Vector3 = Vector3.ZERO
var _weights: Vector4 = Vector4.ZERO
var _target: Vector4 = Vector4.ZERO
var _immersion: float = 0.0
var _target_immersion: float = 0.0
var _cue_age: float = 2.0
var _cue_frequency: float = 440.0
var _cue_value: float = 0.0
var _cue_release_value: float = 0.0
var _cue_release_age: float = 1.0

func _init() -> void:
	_rng.seed = 1729

static func profile(scale_id: String) -> Vector4:
	match scale_id:
		"universe", "galaxy", "solar_system", "earth", "earth_moon", "jupiter_moons", "mars_moons", "saturn_moons", "uranus_moons", "neptune_moons": return Vector4(0, 0, 0, 1)
		"woodland", "city", "desert", "polar", "arctic", "night_sky": return Vector4.ZERO # independent terrestrial atmospheres
		"atmosphere": return Vector4(0.45, 0, 0, 0.4)
		"pacific", "reef", "school", "fish": return Vector4(1, 0, 0, 0)
		"heart": return Vector4(0, 1, 0, 0)
		_: return Vector4(0, 0, 1, 0)

func set_context(source: String, destination: String, blend: float, immersion: float) -> void:
	_target = profile(source).lerp(profile(destination), clampf(blend, 0.0, 1.0))
	_land_target = land_profile(source).lerp(land_profile(destination),clampf(blend,0,1))
	_target_immersion = clampf(immersion, 0.0, 1.0)
	_desert_target=lerpf(1.0 if source in ["desert","night_sky"] else 0.0,1.0 if destination in ["desert","night_sky"] else 0.0,clampf(blend,0,1))
	_polar_target=lerpf(1.0 if source in ["polar","arctic"] else 0.0,1.0 if destination in ["polar","arctic"] else 0.0,clampf(blend,0,1))

static func land_profile(scale_id: String) -> Vector2:
	return Vector2(1,0) if scale_id=="woodland" else Vector2(0,1) if scale_id=="city" else Vector2.ZERO

static func description(scale_id: String) -> String:
	match scale_id:
		"night_sky": return I18n.text("合成山地微风；非现场录音或日期天气。")
		"desert": return I18n.text("合成微风氛围；没有加入野生动物录音或水流。")
		"arctic": return I18n.text("合成极地微风与开阔水面氛围；非实测北极风浪或日期天气。")
		"polar": return I18n.text("合成微风与近岸海水氛围；不对应实测风浪、企鹅录音或日期天气。")
		"woodland": return I18n.text("合成风叶、水流与泛化鸟声；非物种录音。")
		"city": return I18n.text("合成远处道路氛围；不定位具体车辆。")
		"universe", "galaxy", "solar_system", "earth", "earth_moon", "jupiter_moons", "mars_moons", "saturn_moons", "uranus_moons", "neptune_moons": return I18n.text("太空声音为听觉辅助，非真空传声。")
		"heart", "cardiomyocyte", "mitochondrion", "molecule", "atom": return I18n.text("体内与微观声音为听觉辅助，非实测录音。")
		_: return I18n.text("合成环境氛围，非现场采集或声学预测。")

func cue(kind: String) -> void:
	# Preserve the current sample when a second UI action interrupts a cue.
	# The short tail also covers repeated retriggers without an unbounded voice list.
	_cue_release_value = _cue_value
	_cue_release_age = 0.0
	_cue_frequency = {"approach": 330.0, "arrive": 660.0, "select": 520.0,
		"time": 390.0, "cancel": 260.0, "failure": 185.0}.get(kind, 440.0)
	_cue_age = 0.0

func next_frame() -> Vector2:
	var t: float = float(_sample_index) / SAMPLE_RATE
	_sample_index += 1
	# Smooth every sample, including mute and context changes after cancellation.
	_weights = _weights.lerp(_target, 0.00035)
	_land_weights = _land_weights.lerp(_land_target,0.00035)
	_desert_weight=lerpf(_desert_weight,_desert_target,.00035)
	_polar_weight=lerpf(_polar_weight,_polar_target,.00035)
	_immersion = lerpf(_immersion, _target_immersion, 0.00035)
	_gain = lerpf(_gain, 0.0 if muted else master, 0.002)
	_levels = _levels.lerp(Vector3(environment_volume, music_volume, effects_volume), 0.002)
	var noise: float = _rng.randf_range(-1.0, 1.0)
	_low = lerpf(_low, noise, 0.018)
	_air = lerpf(_air, noise, lerpf(0.16, 0.035, _immersion))
	var ocean: float = _air * (0.32 + 0.12 * sin(t * 0.41)) + sin(t * TAU * 47.0) * 0.008 * _immersion
	var organic: float = _low * 0.17 + sin(t * TAU * 73.0) * 0.009
	var micro: float = _low * 0.06 + sin(t * TAU * 174.6) * 0.006 + sin(t * TAU * 261.6) * 0.003
	var cosmos: float = sin(t * TAU * 65.4) * 0.008 + sin(t * TAU * 98.0) * 0.004
	var bed: float = Vector4(ocean, organic, micro, cosmos).dot(_weights) * _levels.x
	# Restrained harmonic bed, independently adjustable from environment and cues.
	var music: float = (sin(t * TAU * 130.81) + 0.5 * sin(t * TAU * 196.0)) * 0.006
	music *= (0.7 + 0.3 * sin(t * 0.19)) * _levels.y
	_cue_age += 1.0 / SAMPLE_RATE
	_cue_release_age += 1.0 / SAMPLE_RATE
	_cue_value = _cue_release_value * (1.0 - smoothstep(0.0, 0.02, _cue_release_age))
	if _cue_age < 0.45:
		var envelope: float = smoothstep(0.0, 0.015, _cue_age) * pow(1.0 - _cue_age / 0.45, 3.0)
		_cue_value += sin(_cue_age * TAU * _cue_frequency) * envelope * 0.06
	var effect: float = _cue_value * _levels.z
	var desert: float = (_air-_low)*(.09+.035*sin(t*.19))*_desert_weight*_levels.x
	var left: float = (bed + music + effect + desert) * _gain
	var right: float = (bed * 0.97 + music * 0.92 + effect + desert*.96) * _gain
	return Vector2(left, right)+(_land.next_frame(t,_land_weights)+_polar.next_frame(t,_polar_weight))*_levels.x*_gain
