extends RefCounted
const EcologySurface = preload("res://scripts/experience/ecology_surface_material.gd")
## Species-reference plants alongside the unidentified background habitat.
const LEAF = preload("res://shaders/plant_leaf.gdshader")
const OAK_SOURCE: String = "https://landscapeplants.oregonstate.edu/plants/quercus-alba"
const PINE_SOURCE: String = "https://plants.ces.ncsu.edu/plants/pinus-strobus/"

static func _materials(node: Node, leaf: ShaderMaterial, stage: Node, cache: Dictionary) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			for slot: int in range(child.mesh.get_surface_count()):
				var material: Material = child.mesh.surface_get_material(slot)
				if material.resource_name in ["PlantLeaves","PlantNeedles"]:
					var source: StandardMaterial3D = material as StandardMaterial3D
					if source.albedo_texture==null and source.normal_texture==null:
						child.set_surface_override_material(slot,leaf)
					else:
						var key: int = source.get_instance_id()
						if not cache.has(key):
							var mapped: ShaderMaterial = leaf.duplicate() as ShaderMaterial
							EcologySurface.copy_maps(source,mapped)
							cache[key]=mapped
							stage.materials.append(mapped)
						child.set_surface_override_material(slot,cache[key])
		_materials(child,leaf,stage,cache)

static func build(stage: Node) -> void:
	var leaf: ShaderMaterial = ShaderMaterial.new()
	leaf.shader = LEAF
	stage.materials.append(leaf)
	var targets: Array[Dictionary] = []
	var cache: Dictionary = {}
	var details: Array[Dictionary] = []
	for index: int in range(2):
		var is_oak: bool = index==0
		var key: String = "white_oak_young" if is_oak else "eastern_white_pine_young"
		var node: Node3D = stage.assets[key].instantiate()
		node.name = "WhiteOakReference" if is_oak else "WhitePineReference"
		var at: Vector2 = Vector2(12,-6) if is_oak else Vector2(15,-6)
		node.position = Vector3(at.x,stage.builder._height(at.x,at.y),at.y)
		stage.world_root.add_child(node)
		_materials(node,leaf,stage,cache)
		var label: String = "北美白橡 · Quercus alba" if is_oak else "东部白松 · Pinus strobus"
		var source: String = OAK_SOURCE if is_oak else PINE_SOURCE
		var role: String = "落叶阔叶树；互生单叶、圆裂片与楔形叶基。当前为原创幼树参考形态，季节落叶未模拟。" if is_oak else "常绿针叶树；枝条轮生，柔软针叶通常五针一束。当前为原创幼树参考形态，针叶更新未模拟。"
		node.set_meta("activity","幼树参考形态 · "+label)
		targets.append({"node":node,"label":label,"role":role,"source_url":source,"distance":3.5,"focus_height":1.0,"view_offset":Vector3(1.1,.9,3.0)})
		var anchor: Node3D = node.find_child("LeafObservationAnchor" if is_oak else "NeedleObservationAnchor",true,false) as Node3D
		var base: Node3D = node.find_child("LeafBaseAnchor" if is_oak else "NeedleBaseAnchor",true,false) as Node3D
		var detail: Node3D = Node3D.new()
		detail.name = "OakLeafDetail" if is_oak else "PineNeedleDetail"
		stage.world_root.add_child(detail)
		detail.position = anchor.global_position
		detail.set_meta("plant_root",node)
		detail.set_meta("activity","北美白橡叶片 · 观察圆裂片与叶脉" if is_oak else "东部白松 · 数一束中的五枚针叶")
		var marks: Array[Dictionary] = [{"at":base.global_position,"label":"叶柄连接处" if is_oak else "五针共用的束基部","offset":Vector2(-155,70)}]
		if is_oak:
			var lobe: Node3D = node.find_child("LeafLobeAnchor",true,false) as Node3D
			marks.append({"at":lobe.global_position,"label":"圆裂片 · 无刺尖","offset":Vector2(80,-70)})
		else:
			var offsets: Array[Vector2] = [Vector2(-125,-80),Vector2(-150,15),Vector2(15,85),Vector2(120,20),Vector2(95,-85)]
			for i: int in range(1,6):
				var needle: MeshInstance3D = node.find_child("ReferenceNeedle"+str(i),true,false) as MeshInstance3D
				var tip: Vector3 = base.global_position
				var distance: float = 0.0
				var vertices: PackedVector3Array = needle.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in vertices:
					var at_world: Vector3 = needle.to_global(vertex)
					if at_world.distance_squared_to(base.global_position)>distance:
						distance = at_world.distance_squared_to(base.global_position)
						tip = at_world
				marks.append({"at":tip,"label":"针叶 "+str(i),"offset":offsets[i-1]})
		detail.set_meta("plant_markers",marks)
		details.append({"node":detail,"label":"北美白橡 · 叶片近看" if is_oak else "东部白松 · 针叶束近看","role":role,"source_url":source,"distance":.32,"view_offset":Vector3(.02,.27,.16) if is_oak else Vector3(.07,.14,.27)})
	targets.append_array(details)
	stage.set_meta("plant_targets",targets)
