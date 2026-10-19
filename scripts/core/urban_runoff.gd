extends RefCounted
## Paired equal-area teaching surfaces. All water depths are in millimetres.
## One world second represents one demonstration minute; these are authored
## bucket capacities/rates, not site-calibrated hydrology or drainage design.
const MODEL_ID: String = "urban-paired-runoff-v1"
const SOURCE: String = "https://www.usgs.gov/water-science-school/science/impervious-surfaces-and-flooding"
const STEP: float = .25
const AREA_M2: float = 9.0
const RAIN_MM_H: float = 36.0
const INFILTRATION_MM_H: float = 60.0
const SOIL_CAPACITY_MM: float = 12.0
const SOIL_DRAIN_PER_MIN: float = .004
const SURFACE_RELEASE_PER_MIN: Array[float] = [2.0,.6]
var started_at_s: float = 0.0
var steps: int = 0
var raining: bool = false
var rain_mm: float = 0.0
var surface: Array[float] = [0.0,0.0]
var soil: Array[float] = [0.0,0.0]
var infiltrated: Array[float] = [0.0,0.0]
var runoff: Array[float] = [0.0,0.0]
var drained: Array[float] = [0.0,0.0]
var last_infiltration: Array[float] = [0.0,0.0]
var last_runoff: Array[float] = [0.0,0.0]

func initialize_at(time: float) -> void:
	started_at_s=time
	steps=0
	raining=false
	rain_mm=0.0
	for values: Array[float] in [surface,soil,infiltrated,runoff,drained,last_infiltration,last_runoff]: values.fill(0.0)

func advance_to(time: float) -> void:
	if not is_finite(time) or time<started_at_s: return
	var required: int = int(floor((time-started_at_s+.00000001)/STEP))
	while steps<required:
		var rain: float = RAIN_MM_H/60.0*STEP if raining else 0.0
		rain_mm+=rain
		for i: int in range(2):
			var drainage: float = soil[i]*(1.0-exp(-SOIL_DRAIN_PER_MIN*STEP))
			soil[i]-=drainage
			drained[i]+=drainage
			surface[i]+=rain
			var intake: float = minf(surface[i],minf(INFILTRATION_MM_H/60.0*STEP,maxf(0.0,SOIL_CAPACITY_MM-soil[i]))) if i==1 else 0.0
			surface[i]-=intake
			soil[i]+=intake
			infiltrated[i]+=intake
			var released: float = surface[i]*(1.0-exp(-SURFACE_RELEASE_PER_MIN[i]*STEP))
			surface[i]-=released
			runoff[i]+=released
			last_infiltration[i]=intake
			last_runoff[i]=released
		steps+=1

func checkpoint() -> Dictionary:
	return {"model_id":MODEL_ID,"started_at_s":started_at_s,"steps":steps,"raining":raining,"rain_mm":rain_mm,
		"surface":surface.duplicate(),"soil":soil.duplicate(),"infiltrated":infiltrated.duplicate(),"runoff":runoff.duplicate(),"drained":drained.duplicate(),
		"last_infiltration":last_infiltration.duplicate(),"last_runoff":last_runoff.duplicate()}

func snapshot() -> Dictionary:
	return checkpoint()

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func checkpoint_error(value: Dictionary, world_time: float) -> String:
	if value.get("model_id")!=MODEL_ID: return "incompatible"
	if not _number(value.get("started_at_s")) or value.started_at_s<0 or value.started_at_s>world_time: return "invalid_runoff_time"
	if not _number(value.get("steps")) or value.steps<0 or floorf(value.steps)!=value.steps: return "invalid_runoff_steps"
	var elapsed: float = world_time-(float(value.started_at_s)+float(value.steps)*STEP)
	if elapsed<-.00001 or elapsed>=STEP+.00001: return "invalid_runoff_time"
	if not value.get("raining") is bool: return "invalid_rain_mode"
	if not _number(value.get("rain_mm")) or value.rain_mm<0 or value.rain_mm>1.e15: return "invalid_rain_amount"
	if value.rain_mm>float(value.steps)*STEP*RAIN_MM_H/60.+.000001: return "invalid_rain_amount"
	for key: String in ["surface","soil","infiltrated","runoff","drained","last_infiltration","last_runoff"]:
		if not value.get(key) is Array or value[key].size()!=2: return "invalid_runoff_stock"
		for item: Variant in value[key]:
			if not _number(item) or item<0.0 or item>1.e15: return "invalid_runoff_stock"
	for i: int in range(2):
		if value.soil[i]>SOIL_CAPACITY_MM+.000001: return "invalid_soil_capacity"
		var tolerance: float = 1.e-8*maxf(1.0,value.rain_mm)
		if absf(value.rain_mm-value.surface[i]-value.soil[i]-value.runoff[i]-value.drained[i])>tolerance: return "invalid_water_balance"
		if absf(value.soil[i]-value.infiltrated[i]+value.drained[i])>tolerance: return "invalid_soil_balance"
		if value.last_infiltration[i]>INFILTRATION_MM_H/60.*STEP+.000001 or value.last_infiltration[i]>value.infiltrated[i]+.000001 or value.last_runoff[i]>value.runoff[i]+.000001: return "invalid_runoff_flux"
	if value.soil[0]!=0. or value.drained[0]!=0. or value.infiltrated[0]!=0. or value.last_infiltration[0]!=0.: return "invalid_impervious_plot"
	return ""

func restore(value: Dictionary) -> void:
	started_at_s=float(value.started_at_s)
	steps=int(value.steps)
	raining=value.raining
	rain_mm=float(value.rain_mm)
	surface.assign(value.surface)
	soil.assign(value.soil)
	infiltrated.assign(value.infiltrated)
	runoff.assign(value.runoff)
	drained.assign(value.drained)
	last_infiltration.assign(value.last_infiltration)
	last_runoff.assign(value.last_runoff)
