extends RefCounted
const EcologySurface = preload("res://scripts/experience/ecology_surface_material.gd")
## One original reference invertebrate; shares the stage/world clock.
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const Forms = preload("res://scripts/experience/life_forms.gd")
const SpineShader = preload("res://shaders/urchin_spines.gdshader")
const SOURCE: String = "https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0102376"
const FIELD_SOURCE: String = "https://lifg.australian.museum/Group.html?groupId=Fg2ZK5TA"

static func build(stage: Node) -> void:
	var ground: Vector3 = Vector3(-3.8,stage.builder._terrain_height(stage,-3.8,1.5),1.5)
	var stone: ShaderMaterial = ShaderMaterial.new()
	stone.shader = preload("res://shaders/reef_surface.gdshader")
	stone.set_shader_parameter("tint",Color(.28,.31,.21))
	stone.set_shader_parameter("rock_surface",true)
	stone.set_shader_parameter("roughness_value",.90)
	stage.materials.append(stone)
	Forms.ellipsoid(stage.world_root,ground+Vector3(0,.02,0),Vector3(.52,.04,.42),stone)
	var root: Node3D = stage.assets.diadema_setosum.instantiate()
	LifeMotion.prepare_materials(root)
	root.name = "DiademaSetosumReference"
	root.position = ground+Vector3(0,.041,0)
	stage.world_root.add_child(root)
	root.set_meta("stable_id","3dworld:teaching:diadema-setosum:0001")
	root.set_meta("activity","长棘微动 · 作者动作；体壳直径6cm")
	var spines: MeshInstance3D = root.find_child("Spines",true,false) as MeshInstance3D
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SpineShader
	EcologySurface.copy_maps(spines.mesh.surface_get_material(0) as StandardMaterial3D,material)
	spines.material_override = material
	stage.materials.append(material)
	stage.set_meta("urchin_spine_material",material)
	var detail: Node3D = Node3D.new()
	detail.name = "UrchinAboralObservation"
	stage.world_root.add_child(detail)
	detail.position = root.position+Vector3(0,.035,0)
	detail.set_meta("urchin_root",root)
	detail.set_meta("activity","数五个白斑 · 橙环位于肛锥，并非眼睛")
	var role: String = "棘皮动物参考形态：长棘、五白斑与橙色肛锥环。资料记录夜间活动；此处为便于观察的个体摆放，未模拟昼夜觅食、摄食量或生物侵蚀。"
	var targets: Array[Dictionary] = [
		{"node":root,"label":"长刺海胆 · Diadema setosum","role":role,"source_url":SOURCE,"distance":.60,"focus_height":.045,"view_offset":Vector3(.20,.30,.49)},
		{"node":detail,"label":"长刺海胆 · 顶端结构近看","role":role,"source_url":SOURCE,"distance":.19,"view_offset":Vector3(.006,.18,.04)}]
	stage.set_meta("benthic_targets",targets)
	stage.set_meta("content_summary",str(stage.get_meta("content_summary"))+"\n长刺海胆提供长棘/五白斑/橙环结构观察；近看摆放与微动为教学设置。")

static func marks(host: Node) -> Array[Dictionary]:
	var targets: Array = host.coordinator.active_scene.get_meta("benthic_targets",[])
	var marks: Array[Dictionary] = []
	if targets.is_empty(): return marks
	var root: Node3D = targets[0].node
	var offsets: Array[Vector2] = [Vector2(100,-45),Vector2(70,85),Vector2(-95,80),Vector2(-115,-40),Vector2(-40,-110)]
	for i: int in range(1,6):
		var mesh: MeshInstance3D = root.find_child("WhiteSpot"+str(i),true,false) as MeshInstance3D
		marks.append({"at":mesh.to_global(mesh.get_aabb().get_center()),"label":"白斑 "+str(i),"offset":offsets[i-1]})
	var anchor: Node3D = root.find_child("AnalRingAnchor",true,false) as Node3D
	marks.append({"at":anchor.global_position,"label":"橙色肛锥环 · 非眼睛","offset":Vector2(70,-140)})
	return marks
