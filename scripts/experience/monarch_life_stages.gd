extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Four actual reference objects; selection owns no age, growth or world clock.
const Larva = preload("res://scripts/experience/monarch_larva_observation.gd")
const Pollinators = preload("res://scripts/experience/pollinator_observation.gd")
const Life = preload("res://scripts/experience/life_asset_motion.gd")
const SOURCE: String = "https://www.monarchwatch.org/biology/"
const GOLD_SOURCE: String = "https://monarchjointventure.org/faq/monarch-biology/chrysalis-gold-dots"
const EGG_ID: String = "3dworld:teaching:monarch-egg:0000"
const PUPA_ID: String = "3dworld:teaching:monarch-pupa:0000"
const TOPICS: Array[String] = ["monarch_egg", "monarch_larva", "monarch_pupa", "monarch"]
const LABELS: Array[String] = ["1 卵", "2 幼虫", "3 蛹", "4 成蝶"]

static func underside(mesh: MeshInstance3D, world_top: Vector3) -> Dictionary:
	# The actual solidified leaf has separate top and bottom triangles.
	var world_origin: Vector3 = world_top-Vector3.UP*.004
	var origin: Vector3 = mesh.to_local(world_origin)
	var direction: Vector3 = mesh.global_basis.inverse()*Vector3.UP
	var faces: PackedVector3Array = mesh.mesh.get_faces()
	var best: float = INF
	var result: Dictionary = {}
	for index: int in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin,direction,faces[index],faces[index+1],faces[index+2])
		if hit==null: continue
		var at: Vector3 = mesh.to_global(hit)
		var distance: float = world_origin.distance_to(at)
		if distance>=best: continue
		var normal: Vector3 = (mesh.global_basis*(faces[index+1]-faces[index]).cross(faces[index+2]-faces[index]).normalized()).normalized()
		if normal.y>0: normal=-normal
		best=distance
		result={"at":at,"normal":normal,"triangle":index/3}
	return result

static func build(stage: Node) -> void:
	var plants: Array = stage.get_meta("milkweed_plants",[])
	if plants.size()<2: return
	var data: Dictionary = {}
	for kind: String in ["egg","pupa"]:
		var plant: Node3D = plants[0 if kind=="egg" else 1]
		var leaf: MeshInstance3D = plant.find_child("MilkweedOppositeLeaves",true,false) as MeshInstance3D
		var top: Dictionary = Larva.leaf_hit(leaf,plant.to_global(Vector3(.073 if kind=="egg" else .104,.80,.012)))
		if top.is_empty():
			push_error("Monarch stage: no existing host leaf for "+kind)
			return
		var support: Dictionary = underside(leaf,top.at)
		if support.is_empty():
			push_error("Monarch stage: no actual leaf underside for "+kind)
			return
		var node: Node3D = stage.assets["monarch_"+kind].instantiate()
		Life.prepare_materials(node)
		node.name="MonarchEgg" if kind=="egg" else "MonarchPupa"
		stage.world_root.add_child(node)
		node.global_position=support.at+support.normal*.000035
		if kind=="egg":
			var up: Vector3=support.normal
			var along: Vector3=(Vector3.RIGHT-up*Vector3.RIGHT.dot(up)).normalized()
			node.global_basis=Basis(along,up,along.cross(up))
		else:
			# Body hangs with gravity. Only the silk pad follows the sloping leaf.
			var pad: Node3D=node.find_child("PupaSilkPad",true,false) as Node3D
			var up: Vector3=-support.normal
			var along: Vector3=(Vector3.RIGHT-up*Vector3.RIGHT.dot(up)).normalized()
			pad.basis=Basis(along,up,along.cross(up))
		node.set_meta("stable_id",EGG_ID if kind=="egg" else PUPA_ID)
		node.set_meta("activity",I18n.text("叶背单卵 · 固定未孵化参考") if kind=="egg" else I18n.text("绿蛹 · 固定悬挂阶段参考"))
		data[kind]={"node":node,"plant":plant,"leaf":leaf,"top":top,"support":support}
	stage.set_meta("monarch_life_stages",data)
	stage.set_meta("monarch_stage_targets",[
		{"node":data.egg.node,"label":I18n.text("帝王蝶卵 · 原乳草叶背"),"role":I18n.text("约1.2毫米高、0.9毫米宽的奶黄有脊卵；镜头近看不放大模型。固定未孵化阶段，不是胚胎或孵化倒计时。"),"source_url":SOURCE,"distance":.008,"min_distance":.0027,"focus_height":-.00057,"view_offset":Vector3(.0040,-.0030,.0060)},
		{"node":data.pupa.node,"label":I18n.text("帝王蝶蛹 · 尾端悬挂部与丝垫"),"role":I18n.text("固定玉绿色蛹参考，尾端黑色悬挂部连接实际叶背的丝垫；金色外观斑点不表示金属黄金或已知生理功能。"),"source_url":SOURCE,"distance":.11,"min_distance":.035,"focus_height":-.014,"view_offset":Vector3(.040,-.045,.100)}])

static func near_clip(stage: Node) -> float:
	var data: Dictionary=stage.get_meta("monarch_life_stages",{})
	if data.is_empty(): return .08
	if stage.camera.position.distance_to(data.egg.node.position)<.04: return .00008
	if stage.camera.position.distance_to(data.pupa.node.position)<.20: return .001
	return .08

static func readout(host: Node, topic: String) -> String:
	if topic=="monarch_egg":
		return I18n.text("1 / 4 · 卵\n约1.2 mm高、0.9 mm宽 · 原尺寸\n叶背单卵，尚未孵化；不从外观推算年龄。")
	if topic=="monarch_pupa":
		return I18n.text("3 / 4 · 蛹（chrysalis）\n作者体长约25 mm · 固定绿蛹\n蛹期不取食；尾端悬挂部接丝垫。金色是外观。")
	if topic=="monarch_larva": return I18n.text("2 / 4 · 幼虫\n")+Larva.readout(host)
	if topic=="monarch": return I18n.text("4 / 4 · 成蝶 · 花蜜食物\n")+Pollinators.readout(host)
	return ""

static func marks(host: Node, topic: String) -> Array[Dictionary]:
	var data: Dictionary=host.coordinator.active_scene.get_meta("monarch_life_stages",{})
	if data.is_empty(): return []
	if topic=="monarch_egg":
		var node: Node3D=data.egg.node
		return [
			{"at":node.find_child("EggRidgeMark",true,false).global_position,"label":I18n.text("卵壳纵向脊 · 原尺寸近看"),"offset":Vector2(80,75)},
			{"at":node.find_child("EggAttachment",true,false).global_position,"label":I18n.text("同一株乳草的真实叶背"),"offset":Vector2(65,-100)}]
	if topic=="monarch_pupa":
		var node: Node3D=data.pupa.node
		return [
			{"at":node.find_child("PupaTailMark",true,false).global_position,"label":I18n.text("尾端悬挂部 · 接丝垫"),"offset":Vector2(80,-65)},
			{"at":node.find_child("PupaGoldMark",true,false).global_position,"label":I18n.text("金色外观斑点 · 不是黄金"),"offset":Vector2(95,50)}]
	return []
