extends RefCounted
const Model = preload("res://scripts/core/schooling.gd")
const Zooplankton = preload("res://scripts/core/zooplankton_lesson.gd")

static func readout(host: Node) -> String:
	var value: Dictionary = host.world.schooling.metrics()
	var water: Dictionary = host.world.zooplankton.snapshot()
	return "24尾 · 同一世界中的局部规则\n代表鱼当前邻居：%d尾（0.55 m范围）\n方向一致度 %.2f / 1 · 最近两鱼 %.3f m\n水层教学单位：剩余%d / %d · 已取%d\n仅选中此主题并继续时间时推进，可单独重置。" % [value.neighbors.size(),value.order,value.minimum_distance,water.water_units,Zooplankton.INITIAL_UNITS,water.taken]

static func marks(host: Node) -> Array[Dictionary]:
	var model: RefCounted = host.world.schooling
	var value: Dictionary = model.metrics()
	return [{"at":model.positions[0],"label":"代表鱼 · 局部影响范围","offset":Vector2(30,-95)},
		{"at":value.center,"label":"群体中心 · 观察辅助","offset":Vector2(-100,65)},
		{"at":value.center+value.direction.normalized()*.5,"label":"平均方向","offset":Vector2(65,65),"link":1},
		{"at":Model.CENTER+Vector3(0,.15,-.26),"label":"浮游动物 · 放大教学单位","offset":Vector2(80,-45)}]

static func draw_neighbors(overlay: Control, host: Node) -> void:
	var model: RefCounted = host.world.schooling
	var camera: Camera3D = host.coordinator.active_scene.camera
	var origin: Vector3 = model.positions[0]
	if camera.is_position_behind(origin): return
	var point: Vector2 = overlay.local_point(camera.unproject_position(origin))
	for index: int in model.neighbors(0):
		if not camera.is_position_behind(model.positions[index]):
			overlay.draw_line(point,overlay.local_point(camera.unproject_position(model.positions[index])),Color(.25,.88,.9,.55),1.3,true)
	for i: int in range(40):
		var a: float = TAU*i/40.
		var b: float = TAU*(i+1)/40.
		var p: Vector3 = origin+Vector3(cos(a),0,sin(a))*Model.NEIGHBOR_RADIUS
		var q: Vector3 = origin+Vector3(cos(b),0,sin(b))*Model.NEIGHBOR_RADIUS
		if not camera.is_position_behind(p) and not camera.is_position_behind(q):
			overlay.draw_line(overlay.local_point(camera.unproject_position(p)),overlay.local_point(camera.unproject_position(q)),Color(.38,.85,.88,.4),1.,true)
