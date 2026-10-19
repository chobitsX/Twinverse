extends RefCounted
## Six resource patches and six consumers, owned only by WorldState.
## Relative stock and accelerated rates are authored, not Zebrasoma calibration.
const MODEL_ID: String = "six-patch-algal-grazing-v1"
const SOURCE: String = "https://fishesofaustralia.net.au/home/species/2204"
const PROCESS_SOURCE: String = "https://www.fisheries.noaa.gov/feature-story/restoring-natural-grazing-processes-can-help-coral-reefs"
const STEP: float = .1
const CAPACITY: float = 100.
const INITIAL: Array[float] = [90.,65.,80.,45.,70.,55.]
const RECOVERY: float = .012
const REMOVAL: float = .12
const PERIOD: float = 32.
var started_at_s: float = 0.
var steps: int = 0
var enabled: bool = true
var adaptive: bool = true
var stock: Array[float] = INITIAL.duplicate()
var grown: Array[float] = [0.,0.,0.,0.,0.,0.]
var eaten: Array[float] = [0.,0.,0.,0.,0.,0.]
var targets: Array[int] = [0,1,2,3,4,5]
var engagement: Array[float] = [1.,1.,1.,1.,1.,1.]

func initialize_at(time: float) -> void:
	started_at_s=time; steps=0; enabled=true; adaptive=true
	stock.assign(INITIAL); grown.fill(0.); eaten.fill(0.)
	targets.assign([0,1,2,3,4,5]); engagement.fill(1.)

static func phase(time: float, start: float, fish: int) -> float:
	return fposmod(maxf(0.,time-start)+fish*4.,PERIOD)

static func approach(cycle: float) -> float:
	return smoothstep(10.,14.,cycle)*(1.-smoothstep(24.,28.,cycle))

static func preferred_patch(fish: int, stocks: Array, assigned: Array) -> int:
	var best: int=int(assigned[fish])
	var best_score: float=-INF
	for patch: int in range(6):
		var others: int=0
		for i: int in range(6):
			if i!=fish and int(assigned[i])==patch: others+=1
		# Relative availability, crowding and ordinal travel cost are teaching rules.
		var score: float=float(stocks[patch])/(1.+.25*others)-.75*absi(patch-int(assigned[fish]))
		if score>best_score:
			best_score=score; best=patch
	return best

func advance_to(time: float) -> void:
	if not is_finite(time) or time<started_at_s: return
	var required: int=int(floor((time-started_at_s+1.e-8)/STEP))
	while steps<required:
		var begin: float=started_at_s+steps*STEP
		var end: float=begin+STEP
		var next_targets: Array[int]=targets.duplicate()
		for fish: int in range(6):
			if phase(end,started_at_s,fish)<phase(begin,started_at_s,fish)-.001:
				next_targets[fish]=preferred_patch(fish,stock,targets) if adaptive else fish
		targets=next_targets
		var rates: Array[float]=[0.,0.,0.,0.,0.,0.]
		for fish: int in range(6):
			var target: int=targets[fish]
			var participation: float=1. if enabled and stock[target]>5. else 0.
			engagement[fish]=lerpf(engagement[fish],participation,1.-exp(-2.8*STEP))
			var contact: float=approach(phase(begin+STEP*.5,started_at_s,fish))*engagement[fish]
			# Resource is removed only during the fully approached part of a visit.
			if enabled: rates[target]+=REMOVAL*smoothstep(.995,1.,contact)
		for patch: int in range(6):
			# Exact stock and flux for rates held over this fixed step:
			# A'=r(K-A)-gA. Sum consumer demand before removal; no fish order bias.
			var rate: float=RECOVERY+rates[patch]
			var equilibrium: float=RECOVERY*CAPACITY/rate
			var decay: float=exp(-rate*STEP)
			var integral: float=equilibrium*STEP+(stock[patch]-equilibrium)*(1.-decay)/rate
			grown[patch]+=maxf(0.,RECOVERY*(CAPACITY*STEP-integral))
			eaten[patch]+=rates[patch]*integral
			stock[patch]=equilibrium+(stock[patch]-equilibrium)*decay
		steps+=1

func checkpoint() -> Dictionary:
	return {"model_id":MODEL_ID,"started_at_s":started_at_s,"steps":steps,"enabled":enabled,"adaptive":adaptive,"stock":stock.duplicate(),"grown":grown.duplicate(),"eaten":eaten.duplicate(),"targets":targets.duplicate(),"engagement":engagement.duplicate()}

func snapshot() -> Dictionary:
	return checkpoint()

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func checkpoint_error(value: Dictionary, world_time: float) -> String:
	if value.get("model_id")!=MODEL_ID: return "incompatible"
	if not number(value.get("started_at_s")) or value.started_at_s<0 or value.started_at_s>world_time: return "invalid_algae_time"
	if not number(value.get("steps")) or value.steps<0 or floorf(value.steps)!=value.steps or value.steps>1.e13: return "invalid_algae_steps"
	var remainder: float=world_time-(float(value.started_at_s)+float(value.steps)*STEP)
	if remainder<-.00001 or remainder>=STEP+.00001: return "invalid_algae_time"
	if not value.get("enabled") is bool or not value.get("adaptive") is bool: return "invalid_algae_mode"
	for key: String in ["stock","grown","eaten","targets","engagement"]:
		if not value.get(key) is Array or value[key].size()!=6: return "invalid_algae_count"
		for item: Variant in value[key]:
			if not number(item) or item<0. or item>1.e15: return "invalid_algae_number"
	for patch: int in range(6):
		if value.stock[patch]>CAPACITY+1.e-6 or value.engagement[patch]>1.: return "invalid_algae_bounds"
		if floorf(value.targets[patch])!=value.targets[patch] or value.targets[patch]>5: return "invalid_algae_target"
		if absf(value.stock[patch]-INITIAL[patch]-value.grown[patch]+value.eaten[patch])>1.e-6*maxf(1.,value.grown[patch]+value.eaten[patch]): return "invalid_algae_balance"
	return ""

func restore(value: Dictionary) -> void:
	started_at_s=float(value.started_at_s); steps=int(value.steps)
	enabled=value.enabled; adaptive=value.adaptive
	stock.assign(value.stock); grown.assign(value.grown); eaten.assign(value.eaten)
	targets.assign(value.targets); engagement.assign(value.engagement)
