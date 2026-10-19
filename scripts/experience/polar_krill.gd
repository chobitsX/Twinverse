extends RefCounted
## One authored nearshore ice-krill group, resolved from the host's world time.
const LifeMotion = preload("res://scripts/experience/life_asset_motion.gd")
const SOURCE: String = "https://euphausiids.linnaeus.naturalis.nl/linnaeus_ng/app/views/species/taxon.php?epi=3&id=176888"
const MORPHOLOGY_SOURCE: String = "https://www.bas.ac.uk/data/our-data/publication/comparative-morphology-of-southern-ocean-euphausia-species-ecological-significance-of-sexual-dimorphic-features/"
const FOOD_SOURCE: String = "https://www.antarctica.gov.au/about-antarctica/animals/penguins/adelie-penguin/"
const COUNT: int = 12
const BODY_LENGTH_M: float = .030
const CENTRE: Vector3 = Vector3(-1.8, -.50, -15.1)

static func _set_layer(root: Node, layer: int) -> void:
	if root is MeshInstance3D:
		root.layers = layer
		for slot: int in range(root.mesh.get_surface_count()):
			var material: StandardMaterial3D = root.mesh.surface_get_material(slot) as StandardMaterial3D
			if material != null and material.albedo_color.a < 1.0:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for child: Node in root.get_children(): _set_layer(child, layer)

static func sample(time: float, index: int) -> Dictionary:
	var angle: float = float(index) * 2.39996
	var radius: float = 0.0 if index == 0 else .039 + .008 * float(index)
	var home: Vector3 = Vector3(cos(angle) * radius, .009 * float(index % 5 - 2), sin(angle) * radius * .61)
	# Keep the observed adult in front of companions so its close lens is unobstructed.
	if index > 0: home.z = -.055 - (.035 + radius * .30) * (.5 + .5 * sin(angle))
	var phase: float = TAU * time / 26.0 + float(index) * .73
	return {"position": CENTRE + home + Vector3(.007 * sin(phase), .004 * sin(phase * 1.3), .009 * cos(phase)),
		"heading": .06 + .17 * sin(phase), "pitch": .04 * cos(phase * .7)}

static func build(stage: Node) -> Array[Dictionary]:
	var animals: Array[Node3D] = []
	var pleopods: Array[Array] = []
	for index: int in range(COUNT):
		var animal: Node3D = stage.assets.ice_krill.instantiate()
		LifeMotion.prepare_materials(animal)
		_set_layer(animal, 2 if index == 0 else 4)
		animal.name = "IceKrill_%02d" % index
		animal.set_meta("stable_id", "3dworld:teaching:ice-krill:%04d" % index)
		stage.world_root.add_child(animal)
		animals.append(animal)
		var pairs: Array[Node3D] = []
		for pair: int in range(5):
			pairs.append(animal.find_child("PleopodPair%02d" % (pair + 1), true, false) as Node3D)
		pleopods.append(pairs)
	var overview: Node3D = Node3D.new()
	overview.name = "IceKrillGroupOverview"
	overview.position = CENTRE
	overview.set_meta("stable_id", "3dworld:teaching:ice-krill:group")
	stage.world_root.add_child(overview)
	var head_focus: Node3D = Node3D.new()
	head_focus.name = "IceKrillHeadFocus"
	head_focus.set_meta("stable_id", "3dworld:teaching:ice-krill:head")
	stage.world_root.add_child(head_focus)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.name = "KrillObservationFill"
	fill.position = CENTRE + Vector3(0, .10, .15)
	fill.light_color = Color(.69, .86, .91)
	fill.light_energy = .005
	fill.layers = 6
	fill.light_cull_mask = 6
	fill.omni_range = .50
	fill.shadow_enabled = false
	stage.world_root.add_child(fill)
	stage.set_meta("ice_krill", {"animals": animals, "pleopods": pleopods, "overview": overview,
		"head_focus": head_focus, "fill": fill})
	animate(stage, float(stage.world_snapshot.simulation_time_s))
	return [
		{"node": overview, "label": "近岸水下 · 冰磷虾小群", "role": "12只同种作者参考，保持约3厘米本体；海冰旁数量与游动不是实测群密度或水流。可切到同一只成体近看。", "source_url": SOURCE, "distance": .40, "min_distance": .20, "view_offset": Vector3(.015, .04, .40)},
		{"node": animals[0], "label": "冰磷虾 · Euphausia crystallorophias", "role": "约3厘米成体参考：大圆眼、长尖额剑、分节腹部、游泳足与尾扇。镜头靠近，模型保持米制尺寸；触角伸出本体。", "source_url": SOURCE, "distance": .070, "min_distance": .033, "view_offset": Vector3(.006, .010, .070)},
		{"node": head_focus, "label": "冰磷虾 · 同一成体的大眼与额剑", "role": "同一只小群成体的头部，不是另造的放大标本；比较黑色大圆眼、眼柄和长尖额剑。细部为原创简化形态。", "source_url": MORPHOLOGY_SOURCE, "distance": .024, "min_distance": .014, "view_offset": Vector3(.001, .004, .024)},
	]

static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("ice_krill"): return
	var data: Dictionary = stage.get_meta("ice_krill")
	for index: int in range(COUNT):
		var animal: Node3D = data.animals[index]
		var pose: Dictionary = sample(time, index)
		animal.position = pose.position
		animal.rotation = Vector3(0, pose.heading, pose.pitch)
		for pair: int in range(5):
			var joint: Node3D = data.pleopods[index][pair]
			if joint != null: joint.rotation.z = .23 * sin(TAU * time * 1.8 + float(index) * .9 - float(pair) * .65)
		animal.set_meta("activity", "作者短程游动 · 本体约3 cm")
	data.head_focus.position = (data.animals[0] as Node3D).to_global(Vector3(.0107, .0010, .0010))

static func readout(host: Node, topic: String) -> String:
	if topic == "ice_krill_habitat":
		return "12只同种教学参考 · 本体约3 cm\n冰磷虾是阿德利企鹅近岸食物的一种；本场景没有捕食过程。"
	return "同一只成体 · 额剑至尾端约3 cm\n形态近看隔离显示该个体；回到小群可看其他个体。尺寸与世界时间保持。"

static func marks(host: Node, topic: String) -> Array[Dictionary]:
	var stage: Node = host.coordinator.active_scene
	if not stage.has_meta("ice_krill"): return []
	var data: Dictionary = stage.get_meta("ice_krill")
	var animal: Node3D = data.animals[0]
	if topic == "ice_krill_habitat":
		return [{"at": animal.global_position, "label": "冰磷虾 · 3 cm量级", "offset": Vector2(70, -60)}]
	var result: Array[Dictionary] = [
		{"at": animal.to_global(Vector3(.01135, .0011, .00157)), "label": "大圆眼", "offset": Vector2(80, -95)},
		{"at": animal.to_global(Vector3(.0125, .00145, 0)), "label": "长尖额剑", "offset": Vector2(120, 30)}]
	if topic != "ice_krill_head":
		result.append({"at": animal.to_global(Vector3(-.0162, -.0012, .0018)), "label": "尾扇", "offset": Vector2(-80, -75)})
	return result
