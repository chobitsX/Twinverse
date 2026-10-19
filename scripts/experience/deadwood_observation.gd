extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## A visible paired experiment beside the existing static fungus reference.
const Model = preload("res://scripts/core/deadwood_decomposition.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const DECAY = preload("res://shaders/deadwood_decay.gdshader")
const CENTER: Vector2 = Vector2(12.,.7)
const COLORS: Array[Color] = [Color(.31,.16,.06),Color(.80,.56,.18),Color(.12,.57,.55)]

static func reserved(x: float,z: float) -> bool:
	return Vector2(x,z).distance_to(CENTER)<2.1

static func box(root: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size=size
	var node: MeshInstance3D = Forms.mesh(root,mesh,material)
	node.position=at
	return node

static func build(stage: Node) -> void:
	var plots: Array[Dictionary] = []
	var tray_material: StandardMaterial3D = Forms.material(Color(.14,.17,.16))
	var water_material: StandardMaterial3D = Forms.material(Color(.12,.40,.48,.28))
	water_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness=.25
	for i: int in range(2):
		var root: Node3D = Node3D.new()
		root.name="DeadwoodLeftSample" if i==0 else "DeadwoodDryReference"
		stage.world_root.add_child(root)
		root.position=Vector3(CENTER.x+(-.76 if i==0 else .76),0,CENTER.y)
		root.position.y=stage.builder._height(root.position.x,root.position.z)+.015
		root.set_meta("stable_id","3dworld:teaching:deadwood:left" if i==0 else "3dworld:teaching:deadwood:dry-reference")
		box(root,Vector3(0,.03,.04),Vector3(1.27,.06,.64),tray_material)
		var log_root: Node3D = stage.assets.turkey_tail_deadwood.instantiate()
		log_root.name="DeadwoodSampleGeometry"
		root.add_child(log_root)
		var materials: Array[ShaderMaterial] = []
		var low: float = INF
		for child: Node in log_root.find_children("*","MeshInstance3D",true,false):
			var mesh: MeshInstance3D = child as MeshInstance3D
			if not (mesh.name.begins_with("DeadwoodBark") or mesh.name.begins_with("BrokenWoodEnd")):
				mesh.free()
				continue
			low=minf(low,(mesh.transform*mesh.get_aabb()).position.y)
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader=DECAY
			material.set_shader_parameter("bark",mesh.name.begins_with("DeadwoodBark"))
			mesh.material_override=material
			materials.append(material)
		for material: ShaderMaterial in materials: material.set_shader_parameter("floor_y",low)
		log_root.position.y=.06-low
		var water: MeshInstance3D = box(root,Vector3(0,.29,0),Vector3(1.20,.005,.48),water_material)
		water.name="WaterloggedConditionSymbol"
		water.visible=false
		var bars: Array[MeshInstance3D] = []
		for part: int in range(3):
			var bar: MeshInstance3D = box(root,Vector3(0,.085,.305),Vector3(1.12,.045,.055),Forms.material(COLORS[part]))
			bar.name=["WoodCarbonBar","RetainedCarbonBar","RespiredCarbonBar"][part]
			bars.append(bar)
		var label: Label3D = Label3D.new()
		label.name="ConditionLabel"
		label.font_size=36
		label.pixel_size=.0024
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.position=Vector3(0,.51,0)
		label.modulate=Color(.87,.96,.87)
		label.outline_modulate=Color(.015,.025,.018)
		label.outline_size=6
		root.add_child(label)
		plots.append({"root":root,"log":log_root,"materials":materials,"bars":bars,"water":water,"label":label})
	stage.set_meta("deadwood_plots",plots)
	var anchor: Node3D = Node3D.new()
	anchor.name="DeadwoodComparisonView"
	stage.world_root.add_child(anchor)
	anchor.position=Vector3(CENTER.x,stage.builder._height(CENTER.x,CENTER.y)+.18,CENTER.y)
	stage.set_meta("deadwood_targets",[{"node":anchor,"pick_nodes":[plots[0].root,plots[1].root],"topic":"deadwood","spatial_hint":I18n.text("点条件旋钮切换左侧 · 双击样方看碳去向"),"label":I18n.text("枯木分解 · 水分与碳去向"),"role":I18n.text("两份相同枯木的局部教学对照：右侧持续干燥，改变左侧水分/供氧条件；碳从木材转入有机留存和呼吸释放。不是实际年数、克数或云芝速率预测。"),"source_url":Model.SOURCE,"distance":5.4,"view_offset":Vector3(.9,2.2,4.5)}])
	var dial: Node3D = Node3D.new()
	dial.name="DeadwoodTeachingConditionDial"
	stage.world_root.add_child(dial)
	dial.position=Vector3(CENTER.x-.24,0,CENTER.y+1.08)
	dial.position.y=stage.builder._height(dial.position.x,dial.position.z)+.025
	var metal: StandardMaterial3D = Forms.material(Color(.46,.38,.24),.48)
	var grip: StandardMaterial3D = Forms.material(Color(.17,.35,.28),.56)
	box(dial,Vector3(0,.025,0),Vector3(.44,.05,.28),tray_material)
	Forms.segment(dial,Vector3(0,.05,0),Vector3(0,.23,0),.028,metal,1.0)
	Forms.ellipsoid(dial,Vector3(0,.23,0),Vector3(.105,.028,.105),metal)
	var pointer: Node3D = Node3D.new()
	pointer.name="ThreePositionConditionHandle"
	pointer.position=Vector3(0,.28,0)
	dial.add_child(pointer)
	Forms.ellipsoid(pointer,Vector3.ZERO,Vector3(.07,.035,.07),grip)
	Forms.segment(pointer,Vector3.ZERO,Vector3(0,.015,-.12),.014,metal,1.0)
	for mode: int in range(3):
		var at: Vector3 = Vector3(0,.266,-.096).rotated(Vector3.UP,(mode-1)*TAU/3.)
		Forms.ellipsoid(dial,at,Vector3(.012,.005,.012),Forms.material([Color(.75,.60,.35),Color(.24,.62,.40),Color(.23,.49,.65)][mode]))
	var caption: Label3D = Label3D.new()
	caption.name="DeadwoodConditionDialCaption"
	caption.position=Vector3(0,.52,.15)
	caption.font_size=28;caption.pixel_size=.0024
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	caption.outline_size=6;caption.modulate=Color(.84,.94,.88)
	dial.add_child(caption)
	stage.set_meta("deadwood_dial",{"node":dial,"pointer":pointer,"caption":caption})
	var controls: Array = stage.get_meta("spatial_controls",[]).duplicate()
	controls.append({"node":dial,"observer":anchor,"topic":"deadwood","action":"deadwood_condition","label":I18n.text("枯木左样方 · 条件旋钮"),"spatial_hint":I18n.text("再点旋钮：干燥→湿润→浸水 · 右侧始终干燥")})
	stage.set_meta("spatial_controls",controls)
	animate(stage)

static func animate(stage: Node) -> void:
	if not stage.has_meta("deadwood_plots"): return
	var state: Dictionary = stage.world_snapshot.get("deadwood_decomposition",{})
	if state.is_empty(): return
	var dial: Dictionary = stage.get_meta("deadwood_dial",{})
	if not dial.is_empty():
		dial.pointer.rotation.y=(int(state.left_mode)-1)*TAU/3.
		dial.caption.text=I18n.text(I18n.text("条件旋钮 · 再点切换\n左：")+[I18n.text("干燥"),I18n.text("湿润有氧"),I18n.text("浸水缺氧")][int(state.left_mode)]+I18n.text(" / 右：干燥\n教学条件 · 非真实气候"))
	for i: int in range(2):
		var plot: Dictionary = stage.get_meta("deadwood_plots")[i]
		var mode: int = int(state.left_mode) if i==0 else 0
		var remaining: float = float(state.wood[i])/Model.INITIAL
		for material: ShaderMaterial in plot.materials:
			material.set_shader_parameter("remaining",remaining)
			material.set_shader_parameter("moisture",0. if mode==0 else .55 if mode==1 else 1.)
		plot.water.visible=mode==2
		plot.label.text=I18n.text((I18n.text("左 · ") if i==0 else I18n.text("右 · "))+[I18n.text("持续干燥"),I18n.text("湿润有氧"),I18n.text("浸水缺氧")][mode]+I18n.text("\n剩余木材碳 %.1f / 100") % state.wood[i])
		var stock: Array[float] = [float(state.wood[i]),float(state.organic[i]),float(state.respired[i])]
		var edge: float = -.56
		for part: int in range(3):
			var width: float = 1.12*stock[part]/Model.INITIAL
			plot.bars[part].visible=width>.00001
			plot.bars[part].scale.x=maxf(.00001,width/1.12)
			plot.bars[part].position.x=edge+width*.5
			edge+=width

static func readout(host: Node) -> String:
	var value: Dictionary = host.world.deadwood.snapshot()
	return I18n.text("局部教学对照 · %.1f s（非现实年数）\n左：%s\n木材 %.1f · 有机留存 %.1f · 呼吸释放 %.1f\n右：持续干燥，木材 %.1f\n棕＝木材　金＝有机留存　青＝释放\n每份初始100相对碳单位；三项总和守恒。") % [value.steps*Model.STEP,I18n.strings(Model.LABELS)[int(value.left_mode)],value.wood[0],value.organic[0],value.respired[0],value.wood[1]]

static func marks(host: Node) -> Array[Dictionary]:
	var plots: Array = host.coordinator.active_scene.get_meta("deadwood_plots")
	return [{"at":plots[0].root.to_global(Vector3(0,.24,0)),"label":I18n.text("左 · 条件可切换"),"offset":Vector2(-90,-90)},
		{"at":plots[1].root.to_global(Vector3(0,.24,0)),"label":I18n.text("右 · 干燥对照"),"offset":Vector2(60,-80)},
		{"at":plots[0].root.to_global(Vector3(0,.085,.305)),"label":I18n.text("色条 · 三种碳去向"),"offset":Vector2(25,70)}]
