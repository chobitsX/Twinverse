extends RefCounted
## A deliberately uncalibrated surviving-colony teaching example.
## WorldState will own this stock and its heat switch; scenes only read it.
const MODEL_ID: String = "coral-symbiosis-teaching-v1"
const SOURCE: String = "https://oceanservice.noaa.gov/facts/coral_bleach.html"
const STEP: float = .25
const STRESS_TAU: float = 12.0
const LOSS_RATE: float = .035
const RECOVERY_RATE: float = .010
var started_at_s: float = 0.0
var steps: int = 0
var heated: bool = false
var stress: float = 0.0
var symbiont: float = 1.0
var lost: float = 0.0
var regained: float = 0.0
var heat_seconds: float = 0.0

func initialize_at(time: float) -> void:
	started_at_s=time
	steps=0
	heated=false
	stress=0.0
	symbiont=1.0
	lost=0.0
	regained=0.0
	heat_seconds=0.0

func advance_to(time: float) -> void:
	if not is_finite(time) or time<started_at_s: return
	var required: int = int(floor((time-started_at_s+.00000001)/STEP))
	while steps<required:
		stress=lerpf(stress,1.0 if heated else 0.0,1.0-exp(-STEP/STRESS_TAU))
		if heated: heat_seconds+=STEP
		var loss_rate: float = LOSS_RATE*stress
		# Recovery is conditional on relief, residual stress and surviving tissue.
		# It is selected by this teaching example, never a survival prediction.
		var gain_rate: float = 0.0 if heated else RECOVERY_RATE*(1.0-smoothstep(.10,.25,stress))
		var rate: float = gain_rate+loss_rate
		if rate>0.0:
			var equilibrium: float = gain_rate/rate
			var decay: float = exp(-rate*STEP)
			var integral: float = equilibrium*STEP+(symbiont-equilibrium)*(1.0-decay)/rate
			regained+=gain_rate*(STEP-integral)
			lost+=loss_rate*integral
			symbiont=equilibrium+(symbiont-equilibrium)*decay
		steps+=1

func checkpoint() -> Dictionary:
	return {"model_id":MODEL_ID,"started_at_s":started_at_s,"steps":steps,"heated":heated,"stress":stress,"symbiont":symbiont,"lost":lost,"regained":regained,"heat_seconds":heat_seconds}

func snapshot() -> Dictionary:
	return checkpoint()

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func checkpoint_error(value: Dictionary, world_time: float) -> String:
	if value.get("model_id")!=MODEL_ID: return "incompatible"
	if not _number(value.get("started_at_s")) or value.started_at_s<0 or value.started_at_s>world_time: return "invalid_symbiosis_time"
	if not _number(value.get("steps")) or value.steps<0 or floorf(value.steps)!=value.steps: return "invalid_symbiosis_steps"
	var elapsed: float = world_time-(float(value.started_at_s)+float(value.steps)*STEP)
	if elapsed<-.00001 or elapsed>=STEP+.00001: return "invalid_symbiosis_time"
	if not value.get("heated") is bool: return "invalid_symbiosis_mode"
	for key: String in ["stress","symbiont","lost","regained","heat_seconds"]:
		if not _number(value.get(key)) or value[key]<-.0000001 or value[key]>1.e15: return "invalid_symbiosis_stock"
	if value.stress>1.0 or value.symbiont>1.0: return "invalid_symbiosis_stock"
	if value.heat_seconds>float(value.steps)*STEP+.000001: return "invalid_symbiosis_duration"
	if absf(float(value.heat_seconds)/STEP-roundf(float(value.heat_seconds)/STEP))>.00001: return "invalid_symbiosis_duration"
	if absf(value.symbiont-1.0-value.regained+value.lost)>1.e-7*maxf(1.0,value.regained+value.lost): return "invalid_symbiosis_balance"
	return ""

func restore(value: Dictionary) -> void:
	started_at_s=float(value.started_at_s)
	steps=int(value.steps)
	heated=value.heated
	stress=float(value.stress)
	symbiont=float(value.symbiont)
	lost=float(value.lost)
	regained=float(value.regained)
	heat_seconds=float(value.heat_seconds)
