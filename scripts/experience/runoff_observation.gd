extends RefCounted
const Model = preload("res://scripts/core/urban_runoff.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const HARD_AT: Vector3 = Vector3(22,.22,43)
const GREEN_AT: Vector3 = Vector3(27,.22,43)
const GREEN_SOURCE: String = "https://www.epa.gov/green-infrastructure/types-green-infrastructure"

static func reserved(x: float, z: float) -> bool:
	return x>18 and x<34 and z>39 and z<56

static func box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size=size
	return Forms.mesh(parent,mesh,material,at)

static func build(stage: Node) -> void:
	var soil_mat: StandardMaterial3D = Forms.material(Color(.38,.25,.13),.97)
	var curb: StandardMaterial3D = Forms.material(Color(.55,.56,.51),.9)
	var hard: StandardMaterial3D = Forms.material(Color(.09,.12,.14),.94)
	var green: StandardMaterial3D = Forms.material(Color(.21,.39,.12),.9)
	var wet_soil: StandardMaterial3D = Forms.material(Color(.12,.23,.23),.81)
	var water: StandardMaterial3D = Forms.material(Color(.16,.62,.82),.31)
	water.emission_enabled=true
	water.emission=Color(.025,.11,.14)
	var top_water: StandardMaterial3D = water.duplicate() as StandardMaterial3D
	top_water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	top_water.albedo_color=Color(.13,.5,.64,.30)
	var plots: Array[Dictionary] = []
	for i: int in range(2):
		var root: Node3D = Node3D.new()
		root.name="RunoffHardSurface" if i==0 else "RunoffGreenSurface"
		root.position=HARD_AT if i==0 else GREEN_AT
		stage.world_root.add_child(root)
		box(root,Vector3(0,.40,0),Vector3(3,.8,3),soil_mat)
		box(root,Vector3(0,.83,0),Vector3(3,.06,3),hard if i==0 else green)
		for side: float in [-1.,1.]:
			box(root,Vector3(side*1.54,.88,0),Vector3(.08,.16,3.08),curb)
		box(root,Vector3(0,.88,-1.54),Vector3(3.16,.16,.08),curb)
		# An open edge and gutter make the surface outflow path unambiguous.
		box(root,Vector3(0,.68,1.73),Vector3(3.1,.08,.38),curb)
		box(root,Vector3(0,.79,1.94),Vector3(3.1,.18,.06),curb)
		box(root,Vector3(0,.48,2.17),Vector3(.28,.07,.60),curb)
		var wet: MeshInstance3D = box(root,Vector3(0,.865,0),Vector3(2.98,.005,2.98),top_water)
		wet.name="SurfaceWetnessSymbol"
		var storage: MeshInstance3D = box(root,Vector3(0,.10,1.505),Vector3(2.98,.01,.009),wet_soil)
		storage.name="SoilStorageSection"
		if i==1:
			for k: int in range(40):
				var x: float = -1.28+float(k%8)*.36
				var z: float = -1.18+float(k/8)*.55
				Forms.fin(root,[Vector3(x-.035,.86,z),Vector3(x-.07,.98,z+.025),Vector3(x+.045,.86,z)],green)
		var drops: Array[Node3D] = []
		var flow: Array[Node3D] = []
		var soaking: Array[Node3D] = []
		var drainage: Array[Node3D] = []
		for k: int in range(32): drops.append(Forms.segment(root,Vector3(0,0,0),Vector3(0,.13,0),.012,water,1.0))
		for k: int in range(10): flow.append(Forms.ellipsoid(root,Vector3.ZERO,Vector3(.075,.035,.16),water))
		for k: int in range(8): soaking.append(Forms.ellipsoid(root,Vector3.ZERO,Vector3(.055,.11,.035),water))
		for k: int in range(4): drainage.append(Forms.ellipsoid(root,Vector3.ZERO,Vector3(.055,.06,.09),water))
		plots.append({"root":root,"wet":wet,"storage":storage,"drops":drops,"flow":flow,"soaking":soaking,"drainage":drainage})
	stage.set_meta("runoff_plots",plots)
	var anchor: Node3D = Node3D.new()
	stage.world_root.add_child(anchor)
	anchor.position=Vector3(24.5,1.,43.5)
	stage.set_meta("runoff_targets",[{"node":anchor,"pick_nodes":[plots[0].root,plots[1].root],"topic":"runoff","spatial_hint":"点实验阀门开关降雨 · 双击实验台看说明","label":"雨水去向 · 硬地与绿地对照","role":"两块各9m²的剖面示意台，比较同量降雨的地表暂存、入渗、径流与深排水。作者参数，不是街区水文实测。","source_url":Model.SOURCE,"distance":18.,"view_offset":Vector3(-2.5,10.,14.5)}])
	# A small physical valve operates this local teaching experiment. It is
	# neither a weather simulation nor a new source of water in the model.
	var valve: Node3D = Node3D.new()
	valve.name="LocalRainExperimentValve"
	valve.position=Vector3(24.5,.22,47.2)
	stage.world_root.add_child(valve)
	var metal: StandardMaterial3D = Forms.material(Color(.36,.27,.15),.43)
	var handle_material: StandardMaterial3D = Forms.material(Color(.13,.58,.67),.49)
	box(valve,Vector3(0,.06,0),Vector3(.72,.12,.65),curb)
	Forms.segment(valve,Vector3(0,.12,0),Vector3(0,1.28,0),.075,metal,1.0)
	Forms.segment(valve,Vector3(0,1.20,0),Vector3(0,1.20,-.42),.06,metal,1.0)
	var handle: Node3D = Node3D.new()
	handle.name="RainValveHandle"
	handle.position=Vector3(0,1.45,0)
	valve.add_child(handle)
	Forms.segment(valve,Vector3(0,1.28,0),handle.position,.04,metal,1.0)
	Forms.segment(handle,Vector3(-.34,0,0),Vector3(.34,0,0),.048,handle_material,1.0)
	Forms.ellipsoid(handle,Vector3.ZERO,Vector3(.17,.13,.17),handle_material)
	var caption: Label3D = Label3D.new()
	caption.name="LocalRainValveReadout"
	caption.position=Vector3(0,1.95,.85)
	caption.font_size=32; caption.pixel_size=.006
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	caption.outline_size=7
	caption.modulate=Color(.79,.94,.95)
	valve.add_child(caption)
	stage.set_meta("runoff_valve",{"node":valve,"handle":handle,"caption":caption})
	stage.set_meta("spatial_controls",[{"node":valve,"observer":anchor,"topic":"runoff","action":"runoff_rain","label":"局部降雨实验阀门","spatial_hint":"再点阀门开关降雨 · 不改变世界时间"}])
	animate(stage,stage.world_snapshot.get("simulation_time_s",0.0))

static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("runoff_plots"): return
	var state: Dictionary = stage.world_snapshot.get("urban_runoff",{})
	if state.is_empty(): return
	var valve: Dictionary = stage.get_meta("runoff_valve",{})
	if not valve.is_empty():
		valve.handle.rotation.y=PI*.5 if state.raining else 0.0
		valve.caption.text="局部实验降雨 · "+("开" if state.raining else "关")+"\n点阀门开关 · 非真实天气\n径流：硬地 %.0f / 绿地 %.0f L" % [state.runoff[0]*Model.AREA_M2,state.runoff[1]*Model.AREA_M2]
	for i: int in range(2):
		var plot: Dictionary = stage.get_meta("runoff_plots")[i]
		plot.wet.visible=float(state.surface[i])>.00001
		plot.storage.visible=i==1 and float(state.soil[i])>.00001
		var depth: float = float(state.soil[i])/Model.SOIL_CAPACITY_MM*.70
		plot.storage.scale.y=maxf(.01,depth/.01)
		plot.storage.position.y=.08+depth*.5
		for k: int in range(plot.drops.size()):
			var drop: Node3D = plot.drops[k]
			drop.visible=state.raining
			drop.position=Vector3(-1.28+float(k%8)*.36,.96+fposmod(-time*1.7+k*.37,1.)*2.,-1.14+float(k/8)*.75)
		for k: int in range(plot.flow.size()):
			var drop: Node3D = plot.flow[k]
			drop.visible=float(state.last_runoff[i])>.00001
			var phase: float = fposmod(time*.55+k*.13,1.)
			if phase<.75: drop.position=Vector3((k%5-2)*.48,.884,-1.2+phase/.75*2.7)
			else: drop.position=Vector3((k%5-2)*.48*(1.-(phase-.75)/.25),.74-(phase-.75)*.7,1.5+(phase-.75)*3.0)
		for k: int in range(plot.soaking.size()):
			var drop: Node3D = plot.soaking[k]
			drop.visible=float(state.last_infiltration[i])>.00001
			drop.position=Vector3(-1.15+float(k%4)*.76,.08+(1.-fposmod(time*.55+k*.31,1.))*.76,1.522)
		for k: int in range(plot.drainage.size()):
			var drop: Node3D = plot.drainage[k]
			drop.visible=float(state.soil[i])>.001
			drop.position=Vector3(-1.05+k*.7,.045,1.52+fposmod(time*.35+k*.27,1.)*.70)

static func readout(host: Node) -> String:
	var state: Dictionary = host.world.runoff.snapshot()
	return "每区降雨 %.1f L · 示意 %.1f min\n径流：硬地 %.1f / 绿地 %.1f L\n绿地入渗 %.1f L · 现存 %.1f L\n深排水 %.1f L · 暂存 %.1f / %.1f L" % [state.rain_mm*Model.AREA_M2,state.steps*Model.STEP,state.runoff[0]*Model.AREA_M2,state.runoff[1]*Model.AREA_M2,state.infiltrated[1]*Model.AREA_M2,state.soil[1]*Model.AREA_M2,state.drained[1]*Model.AREA_M2,state.surface[0]*Model.AREA_M2,state.surface[1]*Model.AREA_M2]

static func marks(stage: Node) -> Array[Dictionary]:
	var plots: Array = stage.get_meta("runoff_plots",[])
	if plots.size()!=2: return []
	return [{"at":plots[0].root.position+Vector3(0,.85,0),"label":"硬地 · 不入渗","offset":Vector2(-85,-105)},
		{"at":plots[1].root.position+Vector3(0,.85,0),"label":"绿地 · 储水有上限","offset":Vector2(40,-105)},
		{"at":plots[1].root.position+Vector3(0,.45,1.52),"label":"入渗 / 深排水 · 剖面示意","offset":Vector2(30,90)}]
