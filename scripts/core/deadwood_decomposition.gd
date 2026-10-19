extends RefCounted
## Closed carbon accounting for a paired teaching experiment, not a species fit.
## Prescribed moisture/oxygen conditions; no weather, fungal growth or nutrient model.
const MODEL_ID: String = "deadwood-carbon-teaching-v1"
const SOURCE: String = "https://research.fs.usda.gov/download/treesearch/37418.pdf"
const CARBON_SOURCE: String = "https://www.energy.gov/science/articles/behind-scenes-how-fungi-make-nutrients-available-world"
const STEP: float = .25
const INITIAL: float = 100.
const WOOD_RATE: float = .010
const ORGANIC_RATE: float = .0035
const RETAINED_SHARE: float = .38
const MODES: Array[String] = ["dry","moist","waterlogged"]
const LABELS: Array[String] = ["干燥 · 缺水限制","湿润 · 有氧分解","浸水 · 缺氧限制"]
const ACTIVITY: Array[float] = [0.,1.,.03]
var started_at_s: float = 0.
var steps: int = 0
var left_mode: int = 1
var wood: Array[float] = [INITIAL,INITIAL]
var organic: Array[float] = [0.,0.]
var respired: Array[float] = [0.,0.]

func initialize_at(time: float) -> void:
	started_at_s=time
	steps=0
	left_mode=1
	wood.assign([INITIAL,INITIAL])
	organic.assign([0.,0.])
	respired.assign([0.,0.])

func advance_to(time: float) -> void:
	if not is_finite(time) or time<started_at_s: return
	var required: int = int(floor((time-started_at_s+.00000001)/STEP))
	if required<=steps: return
	var elapsed: float = (required-steps)*STEP
	# Exact solution over this unchanged-condition interval, independent of frame chunks.
	# W'=-kW, P'=y*kW-mP, G'=(1-y)*kW+mP. Right sample stays dry.
	var activity: float = ACTIVITY[left_mode]
	if activity>0.:
		var k: float = WOOD_RATE*activity
		var m: float = ORGANIC_RATE*activity
		var ew: float = exp(-k*elapsed)
		var ep: float = exp(-m*elapsed)
		var next_wood: float = wood[0]*ew
		var next_organic: float = organic[0]*ep+RETAINED_SHARE*k*wood[0]*(ew-ep)/(m-k)
		respired[0]+=wood[0]+organic[0]-next_wood-next_organic
		wood[0]=next_wood
		organic[0]=next_organic
	steps=required

func checkpoint() -> Dictionary:
	return {"model_id":MODEL_ID,"started_at_s":started_at_s,"steps":steps,"left_mode":left_mode,"wood":wood.duplicate(),"organic":organic.duplicate(),"respired":respired.duplicate()}

func snapshot() -> Dictionary:
	return checkpoint()

static func number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func checkpoint_error(value: Dictionary, world_time: float) -> String:
	if value.get("model_id")!=MODEL_ID: return "incompatible"
	if not number(value.get("started_at_s")) or value.started_at_s<0 or value.started_at_s>world_time: return "invalid_deadwood_time"
	if not number(value.get("steps")) or value.steps<0 or floorf(value.steps)!=value.steps or value.steps>4.e12: return "invalid_deadwood_steps"
	var elapsed: float = world_time-(float(value.started_at_s)+float(value.steps)*STEP)
	if elapsed<-.00001 or elapsed>=STEP+.00001: return "invalid_deadwood_time"
	if not number(value.get("left_mode")) or floorf(value.left_mode)!=value.left_mode or value.left_mode<0 or value.left_mode>=MODES.size(): return "invalid_deadwood_mode"
	for key: String in ["wood","organic","respired"]:
		if not value.get(key) is Array or value[key].size()!=2: return "invalid_deadwood_stock"
		for item: Variant in value[key]:
			if not number(item) or item<0. or item>INITIAL+.000001: return "invalid_deadwood_stock"
	for i: int in range(2):
		if absf(value.wood[i]+value.organic[i]+value.respired[i]-INITIAL)>.000001: return "invalid_deadwood_balance"
	if value.wood[1]!=INITIAL or value.organic[1]!=0. or value.respired[1]!=0.: return "invalid_deadwood_reference"
	return ""

func restore(value: Dictionary) -> void:
	started_at_s=float(value.started_at_s)
	steps=int(value.steps)
	left_mode=int(value.left_mode)
	wood.assign(value.wood)
	organic.assign(value.organic)
	respired.assign(value.respired)
