extends RefCounted
## Authored camera bridge only. Resource/World ownership stays with the coordinator.
const Sites = preload("res://scripts/data/earth_sites.gd")
const BRANCHES: Array[String] = ["reef", "woodland", "desert", "city", "polar", "arctic", "night_sky"]

static func region_for(id: String) -> String:
	if id in ["pacific", "school", "fish"]: return "reef"
	return id if BRANCHES.has(id) else ""

static func profile(outgoing: String, incoming: String) -> Dictionary:
	if outgoing == "earth" and not region_for(incoming).is_empty():
		return {"direction": "enter", "region": region_for(incoming)}
	if incoming == "earth" and not region_for(outgoing).is_empty():
		return {"direction": "exit", "region": region_for(outgoing)}
	return {}

static func near_pose(region: String) -> Dictionary:
	var site: Dictionary = Sites.for_scale(region)
	var normal: Vector3 = Sites.normal(float(site.lat), float(site.lon))
	return {"position": normal * 3.22, "target": normal * 3.0, "up": Vector3.UP}

static func far_pose(near: Dictionary) -> Dictionary:
	var offset: Vector3 = near.position - near.target
	return {"position": near.target + offset * 2.8 + Vector3.UP * offset.length() * .5, "target": near.target, "up": near.get("up", Vector3.UP)}

static func interpolate(start: Dictionary, finish: Dictionary, amount: float) -> Dictionary:
	var up: Vector3 = start.get("up", Vector3.UP).lerp(finish.get("up", Vector3.UP), amount)
	return {"position": start.position.lerp(finish.position, amount), "target": start.target.lerp(finish.target, amount), "up": up.normalized() if up.length_squared() > .00001 else Vector3.UP}

static func globe_pose(start: Dictionary, finish: Dictionary, amount: float, entering: bool) -> Dictionary:
	# Turn on a sphere first; a straight chord can pass through the globe when
	# a search/list opens a region on the opposite hemisphere.
	var turn: float = smoothstep(0.0, .48, amount) if entering else smoothstep(.35, 1.0, amount)
	var zoom: float = smoothstep(.25, 1.0, amount) if entering else smoothstep(0.0, .75, amount)
	var from: Vector3 = start.position.normalized()
	var to: Vector3 = finish.position.normalized()
	var direction: Vector3
	if from.dot(to) < -.999:
		var axis: Vector3 = from.cross(to)
		if axis.length_squared() < .00000001: axis = from.cross(Vector3.UP)
		if axis.length_squared() < .00000001: axis = from.cross(Vector3.RIGHT)
		direction = from.rotated(axis.normalized(), acos(clampf(from.dot(to), -1.0, 1.0)) * turn)
	else:
		direction = from.slerp(to, turn).normalized()
	var pose: Dictionary = interpolate(start, finish, zoom)
	pose.position = direction * lerpf(start.position.length(), finish.position.length(), zoom)
	return pose
