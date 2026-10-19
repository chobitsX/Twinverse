extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const EcologySurface = preload("res://scripts/experience/ecology_surface_material.gd")
## One attached reference colony; reads WorldState-owned symbiosis teaching state.
const Symbiosis = preload("res://scripts/core/coral_symbiosis.gd")
const TISSUE_SHADER = preload("res://shaders/coral_symbiosis.gdshader")
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const SOURCE: String = "https://oceanservice.noaa.gov/education/tutorial_corals/coral01_intro.html"
const SYMBIOSIS_SOURCE: String = "https://oceanservice.noaa.gov/education/tutorial_corals/coral02_zooxanthellae.html"
const MORPHOLOGY_SOURCE: String = "https://www.frontiersin.org/journals/ecology-and-evolution/articles/10.3389/fevo.2022.979278/full"

static func build(stage: Node) -> void:
	var ground: Vector3 = Vector3(-5.1,stage.builder._terrain_height(stage,-5.1,.4),.4)
	var rock: StandardMaterial3D = StandardMaterial3D.new()
	rock.albedo_color=Color(.24,.28,.25)
	rock.roughness=.92
	Forms.ellipsoid(stage.world_root,ground+Vector3(0,.01,0),Vector3(.17,.023,.16),rock)
	var root: Node3D = stage.assets.acropora_millepora.instantiate()
	LifeMotion.prepare_materials(root)
	var tissue_materials: Array[ShaderMaterial] = []
	var cache: Dictionary = {}
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		for slot: int in range(mesh.mesh.get_surface_count()):
			var original: StandardMaterial3D = mesh.mesh.surface_get_material(slot) as StandardMaterial3D
			if original==null or original.resource_name=="MouthCavity": continue
			var key: int = original.get_instance_id()
			if not cache.has(key):
				var material: ShaderMaterial = ShaderMaterial.new()
				material.shader=TISSUE_SHADER
				EcologySurface.copy_maps(original,material)
				material.set_shader_parameter("tissue_color",original.albedo_color)
				material.set_shader_parameter("vertex_pigment",original.vertex_color_use_as_albedo)
				material.set_shader_parameter("tissue_roughness",original.roughness)
				cache[key]=material
				tissue_materials.append(material)
			mesh.set_surface_override_material(slot,cache[key])
	stage.set_meta("coral_tissue_materials",tissue_materials)
	root.name="AcroporaMilleporaReference"
	stage.world_root.add_child(root)
	root.position=ground+Vector3(0,.029,0)
	root.set_meta("stable_id","3dworld:teaching:acropora-millepora:0001")
	root.set_meta("activity",I18n.text("1个珊瑚群体 · 群体和珊瑚虫是同一动物类群的不同观察尺度"))
	var anchor: Node3D = root.find_child("PolypMouthAnchor",true,false) as Node3D
	var detail: Node3D = Node3D.new()
	detail.name="AttachedCoralPolypObservation"
	stage.world_root.add_child(detail)
	detail.position=anchor.global_position
	detail.set_meta("coral_root",root)
	detail.set_meta("activity",I18n.text("同一枝条上的珊瑚虫 · 镜头近看，未放大模型"))
	var tentacles: Array[Node3D] = []
	for i: int in range(12): tentacles.append(root.find_child("Tentacle%02d"%i,true,false) as Node3D)
	stage.set_meta("coral_tentacles",tentacles)
	stage.set_meta("coral_root",root)
	var role: String = I18n.text("Acropora millepora参考群体。珊瑚虫是刺胞动物；活组织覆在碳酸钙骨骼上，触手围绕口。共生藻在组织内提供光合产物，这里不把它画成能用肉眼数出的颗粒。形态、数量、尺寸及摆动为作者设置，共生藻相对量与表面颜色接入独立局部热压力教学实验；不是物种白化或死亡预测，未模拟捕食、钙化或生长。")
	stage.set_meta("coral_targets",[
		{"node":root,"precise_pick":true,"topic":"coral_symbiosis","spatial_hint":I18n.text("点开关比较热压力 · 双指靠近，再点枝条上的珊瑚虫"),"label":I18n.text("分枝石珊瑚 · Acropora millepora"),"role":role,"source_url":MORPHOLOGY_SOURCE,"focus_height":.056,"distance":.65,"view_offset":Vector3(.27,.27,.53),"min_distance":.16},
		{"node":detail,"precise_pick":true,"pick_nodes":[root.find_child("HeroPolyp",true,false)],"topic":"coral_polyp","label":I18n.text("珊瑚虫 · 同一群体上的近看"),"role":role,"source_url":SOURCE,"distance":.019,"view_offset":Vector3(.002,.010,.016),"min_distance":.011}])
	# This author-made apparatus operates the existing local teaching switch;
	# it is not a temperature sensor, heater or another simulation model.
	var control: Node3D = Node3D.new()
	control.name="CoralTeachingHeatSwitch"
	stage.world_root.add_child(control)
	control.position=ground+Vector3(.18,.016,.10)
	var metal: StandardMaterial3D = Forms.material(Color(.29,.38,.40),.43)
	var grip: StandardMaterial3D = Forms.material(Color(.64,.25,.15),.51)
	Forms.ellipsoid(control,Vector3.ZERO,Vector3(.033,.008,.027),metal)
	Forms.segment(control,Vector3(0,0,0),Vector3(0,.052,0),.007,metal,1.0)
	var lever: Node3D = Node3D.new()
	lever.name="HeatTeachingLever"
	lever.position=Vector3(0,.052,0)
	control.add_child(lever)
	Forms.segment(lever,Vector3.ZERO,Vector3(0,.035,0),.004,metal,1.0)
	Forms.ellipsoid(lever,Vector3(0,.035,0),Vector3(.011,.012,.011),grip)
	var caption: Label3D = Label3D.new()
	caption.name="CoralHeatSwitchCaption"
	caption.position=Vector3(.11,.14,.055)
	caption.font_size=28;caption.pixel_size=.00025
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	caption.outline_size=6;caption.modulate=Color(.89,.94,.91)
	control.add_child(caption)
	stage.set_meta("coral_heat_switch",{"node":control,"lever":lever,"caption":caption})
	var controls: Array = stage.get_meta("spatial_controls",[]).duplicate()
	controls.append({"node":control,"observer":root,"topic":"coral_symbiosis","action":"coral_heat","label":I18n.text("珊瑚共生 · 热压力教学开关"),"spatial_hint":I18n.text("再点切换热压力 · 作者实验，非真实加热")})
	stage.set_meta("spatial_controls",controls)
	I18n.set_meta_text(stage,"content_summary",{"parts":[I18n.meta_message(stage,"content_summary"),"\n新增Acropora millepora参考群体和真实附着珊瑚虫近看；珊瑚是动物，骨骼和共生关系有资料，可观察局部热压力与共生颜色变化；作者相对模型不作真实白化/死亡预测，未模拟生长。"]})

static func animate(stage: Node, time: float) -> void:
	var state: Dictionary = stage.world_snapshot.get("coral_symbiosis",{})
	if not state.is_empty():
		for material: ShaderMaterial in stage.get_meta("coral_tissue_materials",[]): material.set_shader_parameter("symbiont_proxy",state.symbiont)
		if stage.has_meta("coral_root"):
			stage.get_meta("coral_root").set_meta("activity",I18n.text("共生状态示意 · 相对藻量 %.0f%% · 不作死亡判定") % (100.*float(state.symbiont)))
		var control: Dictionary = stage.get_meta("coral_heat_switch",{})
		if not control.is_empty():
			control.lever.rotation.z=-PI*.22 if state.heated else PI*.22
			control.caption.text=I18n.text(I18n.text("热压力教学 · ")+(I18n.text("开") if state.heated else I18n.text("关"))+I18n.text("\n再点切换 · 非真实加热\n相对共生藻 %.0f%% · 作者代理") % (100.*float(state.symbiont)))
			control.caption.visible=stage.camera.position.distance_to(stage.get_meta("coral_targets")[1].node.position)>.10
	var tentacles: Array = stage.get_meta("coral_tentacles",[])
	for i: int in range(tentacles.size()):
		# Small authored bend about each attached base, never an independent clock.
		tentacles[i].rotation=Vector3(.075*sin(time*.8+i*.43),.035*sin(time*.65+i*.7),.055*sin(time*.7+i*.5))

static func marks(stage: Node, detail: bool) -> Array[Dictionary]:
	if not stage.has_meta("coral_root"): return []
	var root: Node3D = stage.get_meta("coral_root")
	var marks: Array[Dictionary] = []
	var rows: Array = [["PolypMouthAnchor",I18n.text("口"),Vector2(90,-70)],["PolypTentacleAnchor",I18n.text("触手"),Vector2(-85,-95)],["PolypTissueAnchor",I18n.text("活组织 · 共生藻在组织内"),Vector2(40,100)]] if detail else [["ColonyAnchor",I18n.text("共同的分枝骨骼 · 表面覆活组织"),Vector2(-30,95)],["PolypMouthAnchor",I18n.text("近看入口 · 同一枝条的珊瑚虫"),Vector2(45,-90)]]
	for row: Array in rows:
		var anchor: Node3D = root.find_child(row[0],true,false) as Node3D
		marks.append({"at":anchor.global_position,"label":row[1],"offset":row[2]})
	return marks


static func symbiosis_readout(host: Node) -> String:
	var state: Dictionary = host.world.symbiosis.snapshot()
	return I18n.text("热压力：%s · 残余压力 %.0f%%\n共生藻相对量 %.0f%% · 作者代理\n白化不等于死亡；此例假定仍可恢复。") % [I18n.text("开启") if state.heated else I18n.text("解除"),100.*float(state.stress),100.*float(state.symbiont)]

static func symbiosis_marks(stage: Node) -> Array[Dictionary]:
	var root: Node3D = stage.get_meta("coral_root")
	return [{"at":root.find_child("ColonyAnchor",true,false).global_position,"label":I18n.text("同一群体 · 共生颜色逐步变化"),"offset":Vector2(-60,90)},
		{"at":root.find_child("PolypMouthAnchor",true,false).global_position,"label":I18n.text("活组织仍在 · 变白不等于死亡"),"offset":Vector2(30,-85)}]
