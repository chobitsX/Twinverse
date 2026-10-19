extends RefCounted
## Two teaching plots owned by WorldState. Stocks are relative leaf units,
## and rates are authored for observation, not measured forest growth rates.
const MODEL_ID: String = "woodland-paired-browse-v1"
const SOURCE: String = "https://www.nps.gov/articles/000/forest-health-deer-browsing.htm"
const STEP: float = .25
const INITIAL: float = 70.0
const CAPACITY: float = 100.0
const GROWTH: float = .012
const BROWSE: float = .045
var started_at_s: float = 0.0
var steps: int = 0
var protected_left: bool = false
var grazing: float = 0.0
var stock: Array[float] = [INITIAL,INITIAL]
var grown: Array[float] = [0.0,0.0]
var eaten: Array[float] = [0.0,0.0]

func initialize_at(time: float) -> void:
	started_at_s=time
	steps=0
	protected_left=false
	grazing=0.0
	stock.assign([INITIAL,INITIAL])
	grown.assign([0.0,0.0])
	eaten.assign([0.0,0.0])

func advance_to(time: float) -> void:
	if not is_finite(time) or time<started_at_s: return
	var required: int = int(floor((time-started_at_s+.00000001)/STEP))
	while steps<required:
		var target: float = 0.0 if protected_left else smoothstep(8.0,30.0,stock[0])
		grazing=lerpf(grazing,target,1.0-exp(-2.8*STEP))
		for i: int in range(2):
			var removal: float = BROWSE*smoothstep(.7,1.,grazing) if i==0 and not protected_left else 0.0
			# Exact stock/flux solution with rates held over this fixed step.
			var rate: float = GROWTH+removal
			var equilibrium: float = GROWTH*CAPACITY/rate
			var decay: float = exp(-rate*STEP)
			var integral: float = equilibrium*STEP+(stock[i]-equilibrium)*(1.0-decay)/rate
			grown[i]+=GROWTH*(CAPACITY*STEP-integral)
			eaten[i]+=removal*integral
			stock[i]=equilibrium+(stock[i]-equilibrium)*decay
		steps+=1

func checkpoint() -> Dictionary:
	return {"model_id":MODEL_ID,"started_at_s":started_at_s,"steps":steps,"protected_left":protected_left,"grazing":grazing,"stock":stock.duplicate(),"grown":grown.duplicate(),"eaten":eaten.duplicate()}

func snapshot() -> Dictionary:
	return checkpoint()

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func checkpoint_error(value: Dictionary, world_time: float) -> String:
	if value.get("model_id")!=MODEL_ID: return "incompatible"
	if not _number(value.get("started_at_s")) or value.started_at_s<0 or value.started_at_s>world_time: return "invalid_browse_time"
	if not _number(value.get("steps")) or value.steps<0 or floorf(value.steps)!=value.steps: return "invalid_browse_steps"
	var elapsed: float = world_time-(float(value.started_at_s)+float(value.steps)*STEP)
	if elapsed<-.00001 or elapsed>=STEP+.00001: return "invalid_browse_time"
	if not value.get("protected_left") is bool: return "invalid_browse_mode"
	if not _number(value.get("grazing")) or value.grazing<0 or value.grazing>1: return "invalid_browse_pose"
	for key: String in ["stock","grown","eaten"]:
		if not value.get(key) is Array or value[key].size()!=2: return "invalid_browse_stock"
		for item: Variant in value[key]:
			if not _number(item) or item<-.000001 or item>1.e15: return "invalid_browse_stock"
	for i: int in range(2):
		if value.stock[i]>CAPACITY+.000001: return "invalid_browse_stock"
		if absf(value.stock[i]-INITIAL-value.grown[i]+value.eaten[i])>1.e-6*maxf(1.,value.grown[i]+value.eaten[i]): return "invalid_browse_balance"
	if absf(value.eaten[1])>.000001: return "invalid_protected_plot"
	return ""

func restore(value: Dictionary) -> void:
	started_at_s=float(value.started_at_s)
	steps=int(value.steps)
	protected_left=value.protected_left
	grazing=float(value.grazing)
	stock.assign(value.stock)
	grown.assign(value.grown)
	eaten.assign(value.eaten)
