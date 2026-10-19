extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const Model = preload("res://scripts/core/woodland_browse.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const OPEN_AT: Vector3 = Vector3(11,0,3)
const PROTECTED_AT: Vector3 = Vector3(15,0,3)
const DEER_AT: Vector3 = Vector3(9.15,0,3)

static func reserved(x: float,z: float) -> bool:
	return x>8.3 and x<16.4 and z>1.6 and z<4.4

static func build(stage: Node) -> void:
	var stem_mat: StandardMaterial3D = Forms.material(Color(.30,.25,.10),.92)
	var leaf_mat: StandardMaterial3D = Forms.material(Color(.19,.37,.09),.86)
	leaf_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var frame_mat: StandardMaterial3D = Forms.material(Color(.30,.27,.21),.9)
	var wire_mat: StandardMaterial3D = Forms.material(Color(.31,.36,.32),.7)
	var plots: Array[Dictionary] = []
	for i: int in range(2):
		var center: Vector3 = OPEN_AT if i==0 else PROTECTED_AT
		var root: Node3D = Node3D.new()
		root.name="BrowsePlotOpen" if i==0 else "BrowsePlotProtected"
		root.position=Vector3(center.x,stage.builder._height(center.x,center.z),center.z)
		stage.world_root.add_child(root)
		var cage: Node3D = Node3D.new()
		cage.name="Exclosure"
		root.add_child(cage)
		var leaves: Array[Node3D] = []
		for k: int in range(24):
			var x: float = -.87+float(k%6)*.348
			var z: float = -.75+float(k/6)*.5
			var base: Vector3 = Vector3(x,stage.builder._height(center.x+x,center.z+z)-root.position.y+.015,z)
			Forms.segment(root,base,base+Vector3(0,.34,0),.007,stem_mat,.6)
			for tier: int in range(3):
				for side: float in [-1.,1.]:
					var leaf: Node3D = Node3D.new()
					root.add_child(leaf)
					leaf.position=base+Vector3(0,.09+tier*.095,0)
					leaf.rotation.y=k*2.39996+tier*.8
					var points: Array[Vector3] = [Vector3.ZERO,Vector3(side*.09,.045,-.05),Vector3(side*.19,.065,0),Vector3(side*.09,.045,.05)]
					Forms.fin(leaf,points,leaf_mat)
					leaves.append(leaf)
		for side: float in [-1.,1.]:
			for end: float in [-1.,1.]:
				var corner: Vector3 = Vector3(side*1.1,stage.builder._height(center.x+side*1.1,center.z+end*1.1)-root.position.y,end*1.1)
				Forms.segment(cage,corner,corner+Vector3(0,1.05,0),.024,frame_mat,1.)
			# Low plot outline remains visible whether access is open or protected.
			for axis: int in range(2):
				var start: Vector3 = Vector3(side*1.1,0,-1.1) if axis==0 else Vector3(-1.1,0,side*1.1)
				var finish: Vector3 = Vector3(side*1.1,0,1.1) if axis==0 else Vector3(1.1,0,side*1.1)
				start.y=stage.builder._height(center.x+start.x,center.z+start.z)-root.position.y+.025
				finish.y=stage.builder._height(center.x+finish.x,center.z+finish.z)-root.position.y+.025
				Forms.segment(root,start,finish,.014,frame_mat,1.)
				for level: int in range(1,5):
					Forms.segment(cage,start+Vector3(0,level*.25,0),finish+Vector3(0,level*.25,0),.007,wire_mat,1.)
		# Covered small exclosure; this is a schematic, not a fence design standard.
		for k: int in range(7):
			var z: float = -1.1+k*(2.2/6.)
			Forms.segment(cage,Vector3(-1.1,1.05,z),Vector3(1.1,1.05,z),.006,wire_mat,1.)
		plots.append({"root":root,"leaves":leaves,"cage":cage})
	stage.set_meta("browse_plots",plots)
	var anchor: Node3D = Node3D.new()
	stage.world_root.add_child(anchor)
	anchor.position=Vector3(12.7,stage.builder._height(12.7,3)+.45,3)
	stage.set_meta("browse_targets",[{"node":anchor,"pick_nodes":[plots[0].root,plots[1].root],"topic":"browse","spatial_hint":I18n.text("点左侧门闩开放/保护 · 双击样方看说明"),"label":I18n.text("植被对照 · 开放区与保护区"),"role":I18n.text("同样的初始相对叶量，比较取食与恢复。加速教学，不对应实际年数或森林生物量。"),"source_url":Model.SOURCE,"distance":13.0,"view_offset":Vector3(-3.0,7.5,10.4)}])
	var latch: Node3D = Node3D.new()
	latch.name="LeftBrowseGateLatch"
	latch.position=Vector3(-1.13,stage.builder._height(OPEN_AT.x-1.13,OPEN_AT.z+1.1)-plots[0].root.position.y,1.1)
	plots[0].root.add_child(latch)
	Forms.segment(latch,Vector3.ZERO,Vector3(0,1.16,0),.035,frame_mat,1.0)
	var lever: Node3D = Node3D.new()
	lever.name="ProtectionLatchLever"
	lever.position=Vector3(0,1.04,0)
	latch.add_child(lever)
	Forms.segment(lever,Vector3.ZERO,Vector3(.38,0,0),.045,wire_mat,1.0)
	Forms.ellipsoid(lever,Vector3(.38,0,0),Vector3(.13,.13,.13),frame_mat)
	var caption: Label3D = Label3D.new()
	caption.name="BrowseLatchReadout"
	caption.position=Vector3(.2,1.8,0)
	caption.font_size=36; caption.pixel_size=.007
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	caption.outline_size=6
	caption.modulate=Color(.83,.95,.78)
	latch.add_child(caption)
	stage.set_meta("browse_latch",{"node":latch,"lever":lever,"caption":caption})
	stage.set_meta("spatial_controls",[{"node":latch,"observer":anchor,"topic":"browse","action":"browse_protection","label":I18n.text("左侧样方 · 保护门闩"),"spatial_hint":I18n.text("再点门闩开放/保护 · 右侧保持保护对照")}])

static func animate(stage: Node) -> void:
	if not stage.has_meta("browse_plots"): return
	var state: Dictionary = stage.world_snapshot.get("woodland_browse",{})
	if state.is_empty(): return
	var latch: Dictionary = stage.get_meta("browse_latch",{})
	if not latch.is_empty():
		latch.lever.rotation.z=0.0 if state.protected_left else -PI*.45
		latch.caption.text=I18n.text(I18n.text("左侧 · ")+(I18n.text("保护") if state.protected_left else I18n.text("开放"))+I18n.text("\n点门闩切换 · 教学屏障"))
	for i: int in range(2):
		var plot: Dictionary = stage.get_meta("browse_plots")[i]
		var fraction: float = float(state.stock[i])/Model.CAPACITY
		for k: int in range(plot.leaves.size()):
			# Relative edible foliage, not individual plant birth/death or height.
			var amount: float = smoothstep(float(k%6)*.105,float(k%6)*.105+.45,fraction)
			plot.leaves[k].scale=Vector3.ONE*maxf(.015,amount)
		plot.cage.visible=i==1 or (state.protected_left and float(state.grazing)<.02)

static func deer_pose(state: Dictionary) -> Dictionary:
	var grazing: float = float(state.get("grazing",0.))
	return {"position":DEER_AT,"heading":0.,"moving":0.,"grazing":grazing,"step_phase":0.,"activity":I18n.text("样方取食 · 叶量影响取食强度") if grazing>.7 else I18n.text("停止取食 · 等待开放样方") if state.get("protected_left",false) else I18n.text("接近地表植物 · 准备取食")}

static func readout(host: Node) -> String:
	var state: Dictionary = host.world.browse.snapshot()
	return I18n.text("相对可食叶量\n左 %.0f%% · %s / 右 %.0f%% · 持续保护\n%s") % [state.stock[0],I18n.text("已保护") if state.protected_left else I18n.text("可取食"),state.stock[1],I18n.text("时间已暂停；继续后观察变化") if host.world.paused else I18n.text("加速过程示意；不对应真实生长速度")]

static func marks(stage: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in range(2):
		var plot: Dictionary = stage.get_meta("browse_plots")[i]
		result.append({"at":plot.root.position+Vector3(0,.25,0),"label":I18n.text("左 · 可切换保护") if i==0 else I18n.text("右 · 持续保护"),"offset":Vector2(10,90) if i==0 else Vector2(90,-55)})
	return result
