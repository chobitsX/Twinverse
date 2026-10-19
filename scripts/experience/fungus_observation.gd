extends RefCounted
## Static original reference: visible fruiting bodies, not a decay simulator.
const Life = preload("res://scripts/experience/life_asset_motion.gd")
const PORES = preload("res://shaders/fungus_pores.gdshader")
const SOURCE: String = "https://www.nps.gov/muwo/learn/nature/decomposing-fungi.htm"
const STRUCTURE_SOURCE: String = "https://www.fs.usda.gov/nrs/pubs/gtr/gtr_nrs79.pdf"
const CENTER: Vector2 = Vector2(10,-3)

static func reserved(x: float,z: float) -> bool:
	return Vector2(x,z).distance_to(CENTER)<1.25

static func build(stage: Node) -> void:
	var root: Node3D = stage.assets.turkey_tail_deadwood.instantiate()
	root.name="TurkeyTailDeadwoodReference"
	Life.prepare_materials(root)
	var pores: ShaderMaterial = ShaderMaterial.new()
	pores.shader=PORES
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		for slot: int in range(mesh.mesh.get_surface_count()):
			if mesh.mesh.surface_get_material(slot).resource_name=="TurkeyTailPoreSurface": mesh.set_surface_override_material(slot,pores)
	stage.world_root.add_child(root)
	root.position=Vector3(CENTER.x,stage.builder._height(CENTER.x,CENTER.y)-.018,CENTER.y)
	root.set_meta("stable_id","3dworld:teaching:trametes-versicolor:deadwood01")
	root.set_meta("activity","枯木上的云芝 · 可见子实体不等于物种数或菌丝个体数")
	stage.set_meta("fungus_root",root)
	stage.set_meta("fungus_pore_material",pores)
	var role: String = "云芝Trametes versicolor是真菌；薄扇形子实体附着枯木，上表面有同心色带，底面是细小孔口。菌丝大多隐在木内，参与分解；可见子实体不是整个真菌。原创静态参考，未计算木材损失、养分流或分解速度。"
	var targets: Array[Dictionary] = [{"node":root,"label":"枯木与云芝 · 分解者","role":role,"source_url":SOURCE,"distance":2.2,"focus_height":.17,"view_offset":Vector3(.75,.88,1.90)}]
	for underside: bool in [false,true]:
		var anchor: Node3D = root.find_child("PoreSurfaceAnchor" if underside else "CapBandAnchor",true,false) as Node3D
		var point: Node3D = Node3D.new()
		point.name="FungusPoreDetail" if underside else "FungusCapDetail"
		stage.world_root.add_child(point)
		point.position=anchor.global_position
		point.set_meta("fungus_root",root)
		point.set_meta("activity","底面孔口表面示意 · 未显示管内显微结构" if underside else "同一附木子实体 · 薄菌盖与同心色带")
		targets.append({"node":point,"label":"云芝 · 底面孔口" if underside else "云芝 · 菌盖色带","role":role,"source_url":STRUCTURE_SOURCE,"distance":.09 if underside else .23,"min_distance":.045 if underside else .10,"view_offset":Vector3(.005,-.034,.074) if underside else Vector3(.065,.15,.18)})
	stage.set_meta("fungus_targets",targets)

static func readout(_host: Node) -> String:
	return "真菌分解者 · 云芝 Trametes versicolor\n可见的是子实体；菌丝主要隐在木内。"

static func marks(host: Node) -> Array[Dictionary]:
	var root: Node3D = host.coordinator.active_scene.get_meta("fungus_root")
	return [{"at":root.find_child("CapBandAnchor",true,false).global_position,"label":"扇形子实体 · 同心色带","offset":Vector2(70,-85)},
		{"at":root.find_child("DeadwoodAnchor",true,false).global_position,"label":"枯木基质 · 菌丝主要隐在内部","offset":Vector2(-70,90)}]
