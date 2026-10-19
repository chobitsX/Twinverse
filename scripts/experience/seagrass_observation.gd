extends RefCounted
const EcologySurface = preload("res://scripts/experience/ecology_surface_material.gd")
## Original marine flowering plant reference; regional context, authored placement.
const SOURCE: String = "https://powo.science.kew.org/taxon/urn:lsid:ipni.org:names:431761-1/general-information"
const ECOLOGY_SOURCE: String = "https://outlookreport.gbrmpa.gov.au/values/2-biodiversity/24-populations-species-and-groups-species/242-seagrasses"
const FIELD_SOURCE: String = "https://www.seagrasswatch.org/wp-content/uploads/Resources/Proceeding/PDF/Wuthathi_Jun22.pdf"
const LEAF = preload("res://shaders/seagrass_leaf.gdshader")
const CENTRE: Vector2 = Vector2(-3.55,2.8)
const SHOOT_COUNT: int = 360

static func ground_pose(stage: Node, at: Vector2, angle: float) -> Transform3D:
	var step: float = .008
	var dx: float = (stage.builder._terrain_height(stage,at.x+step,at.y)-stage.builder._terrain_height(stage,at.x-step,at.y))/(step*2.)
	var dz: float = (stage.builder._terrain_height(stage,at.x,at.y+step)-stage.builder._terrain_height(stage,at.x,at.y-step))/(step*2.)
	var up: Vector3 = Vector3(-dx,1.,-dz).normalized()
	var basis: Basis = Basis(Quaternion(Vector3.UP,up))*Basis(Vector3.UP,angle)
	return Transform3D(basis,Vector3(at.x,stage.builder._terrain_height(stage,at.x,at.y),at.y))

static func build(stage: Node) -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader=LEAF
	stage.materials.append(material)
	var root: Node3D = stage.assets.halophila_ovalis_reference.instantiate()
	var textured: MeshInstance3D = root.find_child("HalophilaReference",true,false) as MeshInstance3D
	EcologySurface.copy_maps(textured.mesh.surface_get_material(0) as StandardMaterial3D,material)
	root.name="HalophilaOvalisReference"
	stage.world_root.add_child(root)
	root.transform=ground_pose(stage,CENTRE,0.)
	root.set_meta("stable_id","3dworld:teaching:halophila-ovalis:reference")
	root.set_meta("activity","3对有柄叶 · 叶长18mm · 根与根茎埋在砂中")
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false): mesh.material_override=material
	var source: Node3D = stage.assets.halophila_ovalis_shoot.instantiate()
	var mesh: MeshInstance3D = source.find_child("HalophilaShoot",true,false) as MeshInstance3D
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_colors=true
	multimesh.mesh=mesh.mesh
	multimesh.instance_count=SHOOT_COUNT
	var patch: MultiMeshInstance3D = MultiMeshInstance3D.new()
	patch.name="HalophilaSandPatches"
	patch.multimesh=multimesh
	patch.material_override=material
	stage.world_root.add_child(patch)
	source.free()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed=12201
	var centres: Array[Vector2] = [CENTRE+Vector2(-.15,-.14),CENTRE+Vector2(.30,.10),CENTRE+Vector2(-.33,.23)]
	var accepted: Array[Vector2] = []
	for i: int in range(SHOOT_COUNT):
		var at: Vector2
		for attempt: int in range(100):
			var theta: float = rng.randf()*TAU
			var radius: float = sqrt(rng.randf())
			at=centres[i%3]+Vector2(cos(theta)*.25,sin(theta)*.18)*radius
			var clear: bool = at.distance_to(CENTRE)>.065
			for other: Vector2 in accepted:
				if at.distance_squared_to(other)<.00036: clear=false; break
			if clear: break
		accepted.append(at)
		var transform: Transform3D = ground_pose(stage,at,rng.randf()*TAU)
		transform.basis=transform.basis.scaled(Vector3.ONE*rng.randf_range(.8,1.15))
		multimesh.set_instance_transform(i,transform)
		var shade: float = rng.randf_range(.80,1.18)
		multimesh.set_instance_color(i,Color(shade,shade,shade,1))
	stage.set_meta("seagrass_root",root)
	stage.set_meta("seagrass_patch",patch)
	stage.set_meta("seagrass_material",material)
	var whole: Node3D = Node3D.new()
	stage.world_root.add_child(whole)
	whole.position=root.position+Vector3(0,.015,0)
	whole.set_meta("activity","360个叶对丛与1段参考根茎 · 布局和密度为作者设置")
	var detail: Node3D = Node3D.new()
	stage.world_root.add_child(detail)
	detail.position=root.find_child("LeafCentreAnchor",true,false).global_position
	detail.set_meta("activity","同一植株叶片 · 18×9mm · 10对横脉 · 镜头近看")
	var role: String = "卵叶喜盐草Halophila ovalis是海洋开花植物，成对具柄叶、平滑叶缘和叶脉有形态依据。海草为绿海龟等提供食物；此处仅展示结构与生态角色，未模拟啃食、生长、开花、光合或碳储量。砂底斑块为区域参考的作者布局，不是该坐标的实测群落；根和根茎埋在砂中。"
	stage.set_meta("seagrass_targets",[
		{"node":whole,"label":"卵叶喜盐草 · 砂底斑块","role":role,"source_url":ECOLOGY_SOURCE,"distance":1.1,"view_offset":Vector3(.30,.65,.85),"min_distance":.08},
		{"node":detail,"label":"卵叶喜盐草 · 同株叶片近看","role":role,"source_url":SOURCE,"distance":.065,"view_offset":Vector3(.018,.053,.033),"min_distance":.026}])
	stage.set_meta("content_summary",str(stage.get_meta("content_summary"))+"\n卵叶喜盐草是海洋开花植物；可比较砂底斑块与同株叶脉。尺寸/布局/微摆为作者设置，非现场调查或生长模型。")

static func point(stage: Node, name: String) -> Vector3:
	var root: Node3D = stage.get_meta("seagrass_root")
	var anchor: Node3D = root.find_child(name,true,false) as Node3D
	var local: Vector3 = root.to_local(anchor.global_position)
	var weight: float = clampf(local.y/.03,0.,1.)
	local.x+=sin(float(stage.get_meta("seagrass_material").get_shader_parameter("world_time"))*.8+root.position.x*2.+root.position.z*3.)*.0008*weight*weight
	return root.to_global(local)

static func marks(stage: Node, detail: bool) -> Array[Dictionary]:
	if not stage.has_meta("seagrass_root"): return []
	if not detail:
		return [{"at":stage.get_meta("seagrass_root").position+Vector3(0,.023,0),"label":"海洋开花植物 · 叶片成对","offset":Vector2(50,-75)}]
	return [
		{"at":point(stage,"PetioleAnchor"),"label":"有柄叶 · 同株近看","offset":Vector2(-85,78)},
		{"at":point(stage,"LeafVeinAnchor"),"label":"横脉连接中脉与近叶缘脉","offset":Vector2(35,-90)},
		{"at":point(stage,"LeafMarginAnchor"),"label":"平滑叶缘 · 无叶毛","offset":Vector2(90,40)}]
