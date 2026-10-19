extends RefCounted
## A fixed-ellipse teaching reference on the existing JPL orbit and observer clock.
## It does not integrate another orbit or predict physical apsis event times.
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
const SOURCE: String = "https://science.nasa.gov/solar-system/orbits-and-keplers-laws/"
const DAYS: float = 8.0
const STEPS: int = 96
const NEAR: Color = Color(1.0,.58,.23)
const FAR: Color = Color(.25,.77,1.0)

static func mean_rate() -> float:
	return deg_to_rad((Orbit.RATES[0][3]-Orbit.RATES[0][4])/36525.0)

static func sample(jd: float) -> Dictionary:
	var el: Array[float] = Orbit.elements(0,jd)
	if el.is_empty(): return {}
	var arcs: Array[Dictionary] = []
	for center: float in [0.0,PI]:
		var points: PackedVector3Array = []
		for i: int in range(STEPS+1):
			var mean: float = center+(float(i)/STEPS-.5)*DAYS*mean_rate()
			points.append(Orbit.orbital_point(el,Orbit.eccentric_anomaly(mean,el[1])))
		arcs.append({"points":points,"angle_deg":rad_to_deg(points[0].angle_to(points[-1]))})
	return {"jd":jd,"el":el,"arcs":arcs,
		"peri":Orbit.orbital_point(el,0.0),"apo":Orbit.orbital_point(el,PI),
		"area":.5*el[0]*el[0]*sqrt(1.0-el[1]*el[1])*DAYS*mean_rate()}

static func segment_start(jd: float, far: bool) -> float:
	# Solve the table's linear mean anomaly, choosing the nearest complete valid
	# eight-day interval. At date limits choose another revolution, never clamp
	# an interval into a different orbital phase.
	var n: float = mean_rate()
	var base_mean: float = deg_to_rad(Orbit.ELEMENTS[0][3]-Orbit.ELEMENTS[0][4])
	var wanted: float = (PI if far else 0.0)-.5*DAYS*n
	var first: float = Orbit.EPOCH+(wanted-base_mean)/n
	var period: float = TAU/n
	var lower: int = ceili((Orbit.START_JD-first)/period)
	var upper: int = floori((Orbit.END_JD-DAYS-first)/period)
	var cycle: int = clampi(roundi((jd-first)/period),lower,upper)
	return first+cycle*period

static func cached_reference(stage: Node, jd: float) -> Dictionary:
	var epoch: float = clampf(floor(jd),Orbit.START_JD,Orbit.END_JD)
	var data: Dictionary = stage.get_meta("kepler_reference",{})
	if data.is_empty() or data.jd!=epoch:
		data = sample(epoch)
		stage.set_meta("kepler_reference",data)
	return data

static func update(stage: Node, jd: float, true_distance: bool, active: bool, marks_enabled: bool) -> void:
	var root: Node3D = stage.world_root.get_node_or_null("KeplerObservation") as Node3D
	if not active:
		if root!=null: root.hide()
		return
	var data: Dictionary = cached_reference(stage,jd)
	if root==null:
		root = Node3D.new()
		root.name = "KeplerObservation"
		stage.world_root.add_child(root)
	if root.get_meta("epoch",-1.0)!=data.jd or root.get_meta("true_distance",not true_distance)!=true_distance:
		for child: Node in root.get_children():
			root.remove_child(child)
			child.queue_free()
		var ellipse: PackedVector3Array = []
		for i: int in range(257): ellipse.append(Orbit.display_vector(0,Orbit.orbital_point(data.el,float(i)/256*TAU),true_distance))
		_mesh(root,"ReferenceEllipse",ellipse,Mesh.PRIMITIVE_LINE_STRIP,Color(.45,.65,.72))
		for side: int in range(2):
			var arc: PackedVector3Array = []
			for point: Vector3 in data.arcs[side].points: arc.append(Orbit.display_vector(0,point,true_distance))
			var fan: PackedVector3Array = []
			for i: int in range(arc.size()-1): fan.append_array([Vector3.ZERO,arc[i],arc[i+1]])
			var color: Color = NEAR if side==0 else FAR
			_mesh(root,"NearArea" if side==0 else "FarArea",fan,Mesh.PRIMITIVE_TRIANGLES,Color(color,.23))
			var border: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
			border.append_array(arc)
			border.append(Vector3.ZERO)
			_mesh(root,"NearBoundary" if side==0 else "FarBoundary",border,Mesh.PRIMITIVE_LINE_STRIP,color)
		root.set_meta("epoch",data.jd)
		root.set_meta("true_distance",true_distance)
	root.visible = marks_enabled
	# Reduce only the illustrative Sun in this close orbit view. Leaving the
	# lesson restores the builder's normal display scale on the next update.
	var sun: Node3D = stage.world_root.get_node("Sun_AuthoredPhotosphere")
	sun.scale = Vector3.ONE*(.035 if true_distance else .21)
	stage.world_root.get_node("SolarCorona_Illustration").hide()
	var bodies: Array = stage.get_meta("solar_bodies")
	bodies[0].label.hide() # The lesson projects the same real Mercury position.

static func _mesh(root: Node3D, title: String, vertices: PackedVector3Array, primitive: Mesh.PrimitiveType, color: Color) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(primitive,arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a<1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)

static func readout(host: Node) -> String:
	var data: Dictionary = cached_reference(host.coordinator.active_scene,host.solar_jd)
	return "各8天：橙 %.1f° / 蓝 %.1f°\n各扫过 %.4f AU² · 当前距日 %.3f AU" % [data.arcs[0].angle_deg,data.arcs[1].angle_deg,data.area,Orbit.position_au(0,host.solar_jd).length()]

static func marks(host: Node) -> Array[Dictionary]:
	var data: Dictionary = cached_reference(host.coordinator.active_scene,host.solar_jd)
	return [
		{"at":Orbit.display_vector(0,data.peri,host.solar_true_distance),"label":"近日点 · %.3f AU" % data.peri.length(),"offset":Vector2(-95,-60)},
		{"at":Orbit.display_vector(0,data.apo,host.solar_true_distance),"label":"远日点 · %.3f AU" % data.apo.length(),"offset":Vector2(-75,45)},
		{"at":Vector3.ZERO,"label":"太阳 · 椭圆的一个焦点","offset":Vector2(-90,75)},
		{"at":Orbit.display_position(0,host.solar_jd,host.solar_true_distance),"label":"水星 · 当前日期","offset":Vector2(25,-35)}]
