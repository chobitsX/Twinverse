extends RefCounted
## Annotation of the existing authored waveform, not a thrust/flow model.
const SOURCE: String = "https://doi.org/10.1242/jeb.202.24.3523"

static func displacement(point: Vector3, phase: float) -> float:
	return smoothstep(.065,.25,absf(point.z))*.031*sin(phase+point.x*11.)

static func prepare(root: Node3D) -> void:
	var disc: MeshInstance3D = root.find_child("RayDisc",true,false) as MeshInstance3D
	var vertices: PackedVector3Array = disc.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var points: PackedVector3Array = PackedVector3Array()
	# Select real dorsal vertices along one side, keeping annotations on the mesh.
	for wanted: Vector3 in [Vector3(.17,.016,.185),Vector3(0,.013,.245),Vector3(-.17,.016,.205)]:
		var nearest: Vector3 = Vector3.ZERO
		var distance: float = INF
		for point: Vector3 in vertices:
			if point.y<0.: continue
			var delta: float = point.distance_squared_to(wanted)
			if delta<distance: nearest=point; distance=delta
		points.append(nearest)
	root.set_meta("ray_fin_points",points)

static func fin_points(root: Node3D) -> PackedVector3Array:
	var disc: MeshInstance3D = root.find_child("RayDisc",true,false) as MeshInstance3D
	var phase: float = float(disc.get_instance_shader_parameter("swim_phase"))
	var result: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in root.get_meta("ray_fin_points"):
		result.append(disc.to_global(point+Vector3(0,displacement(point,phase),0)))
	return result

static func marks(root: Node3D) -> Array[Dictionary]:
	var points: PackedVector3Array = fin_points(root)
	return [{"at":points[0],"label":"前段 · 波从这里向后传播","offset":Vector2(-100,-100)},
		{"at":points[1],"label":"中段 · 胸鳍起伏","offset":Vector2(80,65)},
		{"at":points[2],"label":"后段 · 波继续传向尾侧","offset":Vector2(-80,115)}]
