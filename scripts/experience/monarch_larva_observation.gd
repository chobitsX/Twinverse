extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## A second life-stage reference on the existing plant, not a growth simulation.
const SOURCE: String = "https://mjv.nyc3.cdn.digitaloceanspaces.com/documents/Education-Grown-up-Guides/Grown-up-Guide-Life-Cycle.pdf"
const STABLE_ID: String = "3dworld:teaching:monarch-larva:0000"
const Life=preload("res://scripts/experience/life_asset_motion.gd")

static func leaf_hit(mesh: MeshInstance3D, world_origin: Vector3) -> Dictionary:
	var origin: Vector3=mesh.to_local(world_origin)
	var direction: Vector3=mesh.global_basis.inverse()*Vector3.DOWN
	var faces: PackedVector3Array=mesh.mesh.get_faces()
	var best: float=INF
	var result: Dictionary={}
	for index: int in range(0,faces.size(),3):
		var hit: Variant=Geometry3D.ray_intersects_triangle(origin,direction,faces[index],faces[index+1],faces[index+2])
		if hit==null: continue
		var at: Vector3=mesh.to_global(hit)
		var distance: float=world_origin.distance_to(at)
		if distance<best:
			var normal: Vector3=(mesh.global_basis*(faces[index+1]-faces[index]).cross(faces[index+2]-faces[index]).normalized()).normalized()
			if normal.y<0: normal=-normal
			best=distance; result={"at":at,"normal":normal}
	return result

static func build(stage: Node) -> void:
	var plant: Node3D=stage.get_meta("milkweed_plants")[0]
	var leaves: MeshInstance3D=plant.find_child("MilkweedOppositeLeaves",true,false) as MeshInstance3D
	# Intersect the actual imported leaf, not a detached proxy plane or label.
	var support: Dictionary=leaf_hit(leaves,plant.to_global(Vector3(.104,.80,.016)))
	if support.is_empty():
		push_error("Monarch larva: no host leaf at the authored attachment")
		return
	var node: Node3D=stage.assets.monarch_larva.instantiate()
	Life.prepare_materials(node)
	node.name="MonarchLarva"
	stage.world_root.add_child(node)
	var along: Vector3=Vector3(cos(.15),0,sin(.15))
	var front: Dictionary=leaf_hit(leaves,support.at+along*.02+Vector3.UP*.01)
	var back: Dictionary=leaf_hit(leaves,support.at-along*.02+Vector3.UP*.01)
	var axis: Vector3=(front.at-back.at).normalized()
	# Follow the midrib lengthwise; one triangle's transverse slope would roll
	# the entire body sideways over the raised central vein.
	var across: Vector3=Vector3(-sin(.15),0,cos(.15))
	var up: Vector3=across.cross(axis).normalized()
	node.global_transform=Transform3D(Basis(axis,up,axis.cross(up)),support.at)
	_fit_feet(node,leaves)
	node.set_meta("stable_id",STABLE_ID)
	var joints: Dictionary={}
	for name: String in ["MandibleL","MandibleR","TentacleFrontL","TentacleFrontR","TentacleRearL","TentacleRearR"]:
		joints[name]=node.find_child(name,true,false)
	stage.set_meta("monarch_larva",{"node":node,"plant":plant,"leaf":leaves,"joints":joints,"support":support})
	stage.set_meta("larva_targets",[{"node":node,"label":I18n.text("帝王蝶幼虫 · 乳草叶上的生命阶段"),"role":I18n.text("幼虫吃乳草叶，成虫吸花蜜；三对胸足与五对腹足用途不同。当前为晚龄幼虫形态参考。"),"source_url":SOURCE,"distance":.16,"focus_height":.004,"view_offset":Vector3(.055,.075,.145)}])

static func _fit_feet(node: Node3D, leaves: MeshInstance3D) -> void:
	# Fit the authored static resting pose once. Deform real limb/pad vertices,
	# not just the inspection markers; retain the source GLB mesh unchanged.
	var feet: Array[Node]=node.find_children("TrueFoot*","Node3D",true,false)
	feet.append_array(node.find_children("ProlegFoot*","Node3D",true,false))
	for foot: Node3D in feet:
		var hit: Dictionary=leaf_hit(leaves,foot.global_position+Vector3.UP*.006)
		if hit.is_empty(): continue
		var target: Vector3=hit.at+Vector3.UP*.00003
		var delta: Vector3=node.global_basis.inverse()*(target-foot.global_position)
		var suffix: String=str(foot.name).trim_prefix("TrueFoot") if str(foot.name).begins_with("TrueFoot") else str(foot.name).trim_prefix("ProlegFoot")
		var names: Array[String]=[]
		names.assign(["ThoracicLeg"+suffix] if str(foot.name).begins_with("TrueFoot") else ["Proleg"+suffix,"ProlegPad"+suffix])
		for mesh_name: String in names:
			var part: MeshInstance3D=node.find_child(mesh_name,true,false) as MeshInstance3D
			var arrays: Array=part.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i: int in range(vertices.size()):
				var at: Vector3=node.to_local(part.to_global(vertices[i]))
				var amount: float=clampf((.003-at.y)/.003,0.,1.)
				vertices[i]=part.to_local(node.to_global(at+delta*amount))
			arrays[Mesh.ARRAY_VERTEX]=vertices
			var adjusted: ArrayMesh=ArrayMesh.new()
			adjusted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var surface: SurfaceTool=SurfaceTool.new()
			surface.create_from(adjusted,0);surface.generate_normals()
			surface.set_material(part.mesh.surface_get_material(0))
			part.mesh=surface.commit()
		foot.global_position=target

static func animate(stage: Node, time: float) -> void:
	if not stage.has_meta("monarch_larva"): return
	var joints: Dictionary=stage.get_meta("monarch_larva").joints
	# Small mouth/filament motion is authored; there is no hidden leaf depletion.
	for side: int in [-1,1]:
		var suffix: String="L" if side>0 else "R"
		joints["Mandible"+suffix].rotation.y=side*.18*(.5+.5*sin(time*2.8))
		joints["TentacleFront"+suffix].rotation.x=side*.055*sin(time*.8)
		joints["TentacleRear"+suffix].rotation.x=side*.035*sin(time*.8+.7)

static func readout(_host: Node) -> String:
	return I18n.text("同一物种 · 不同生命阶段\n幼虫：乳草叶 · 成虫：花蜜\n模型体长约4.5 cm；原尺寸附在同株叶片上。")

static func marks(host: Node) -> Array[Dictionary]:
	var node: Node3D=host.coordinator.active_scene.get_meta("monarch_larva").node
	return [
		{"at":node.find_child("LarvaThoraxMark",true,false).global_position,"label":I18n.text("胸足 · 三对关节足"),"offset":Vector2(90,95)},
		{"at":node.find_child("LarvaProlegMark",true,false).global_position,"label":I18n.text("腹足 · 五对支撑足"),"offset":Vector2(-110,95)},
		{"at":node.find_child("TentacleRearL",true,false).global_position,"label":I18n.text("前后肉质丝状突起 · 不是触角"),"offset":Vector2(-45,-100)}]
