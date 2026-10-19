extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Observer-only framing. This class never changes a celestial transform or clock.
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const Model = preload("res://scripts/core/natural_satellites.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const PREFERRED: Dictionary = {3:401,4:503,5:606,6:703,7:801}
const META: String = "satellite_framing"

static func state(stage: Node) -> Dictionary:
	return stage.get_meta(META,{})

static func is_pair(stage: Node) -> bool:
	return str(state(stage).get("mode",""))=="pair"

static func clear(stage: Node) -> void:
	stage.set_meta(META,{})

static func subjects(stage: Node, owner: int, key: String = "") -> Dictionary:
	var planet: MeshInstance3D
	var moon: MeshInstance3D
	var record: Dictionary = {}
	var label: String = I18n.text("月球")
	var moon_key: String = "moon"
	if stage.scale_id=="solar_system":
		if owner<2 or owner>7: return {}
		planet=stage.get_meta("solar_bodies")[owner].node
		if owner==2: moon=stage.get_meta("solar_moon").node
		else:
			var system: Dictionary=stage.get_meta("solar_satellite_systems")[owner]
			if not bool(system.valid): return {}
			for body: Dictionary in system.bodies:
				if (key.is_empty() and int(body.record.code)==int(PREFERRED[owner])) or str(body.record.key)==key:
					moon=body.node; record=body.record; break
	elif stage.scale_id=="earth_moon":
		owner=2; planet=stage.get_meta("lunar").earth; moon=stage.get_meta("lunar").moon
	elif stage.has_meta("natural_satellites"):
		var system: Dictionary=stage.get_meta("natural_satellites")
		owner=int(system.index); planet=system.planet
		if not bool(system.valid): return {}
		for body: Dictionary in system.bodies:
			if float(body.radius_km)<=0.0 or not bool(body.node.get_meta("satellite_position_valid",false)): continue
			if (key.is_empty() and int(body.record.code)==int(PREFERRED[owner])) or str(body.record.key)==key:
				moon=body.node; record=body.record; break
	else: return {}
	if not is_instance_valid(planet) or not is_instance_valid(moon): return {}
	if not record.is_empty(): label=I18n.text(str(record.display_name)); moon_key=str(record.key)
	return {"planet":planet,"moon":moon,"owner":owner,"key":moon_key,"label":label,
		"radius":float(planet.mesh.radius)*absf(planet.scale.x),"moon_radius":float(moon.mesh.radius)*absf(moon.scale.x),"record":record}

static func normal(data: Dictionary, jd: float) -> Vector3:
	var delta: Vector3=data.moon.position-data.planet.position
	var velocity: Vector3
	if int(data.owner)==2:
		velocity=Orientation.moon_position_km(jd+.01)-Orientation.moon_position_km(jd-.01)
	else:
		var sample: Dictionary=Model.sample(data.record,jd)
		var v: Array=sample.velocity_km_day
		velocity=Vector3(v[0],v[2],-v[1])
	var pole: Vector3=delta.cross(velocity).normalized()
	return pole if pole.length_squared()>.9 else Vector3.UP

static func frame_basis(data: Dictionary, pole: Vector3) -> Basis:
	var axis: Vector3=(data.moon.position-data.planet.position).normalized()
	var side: Vector3=pole.cross(axis).normalized()
	if side.length_squared()<.9: side=Vector3.RIGHT.cross(axis).normalized()
	return Basis(side,axis.cross(side).normalized(),axis)

static func solve(data: Dictionary, viewport: Vector2, frame: Rect2, pole: Vector3) -> Dictionary:
	var host: Vector3=data.planet.position
	var moon: Vector3=data.moon.position
	var radius: float=data.radius
	var small: float=data.moon_radius
	var separation: float=host.distance_to(moon)
	var axes: Basis=frame_basis(data,pole)
	# Perspective can make a nearby moon readable beside a distant planet.
	# Both keep their actual radius and position; the observer goes beyond the moon.
	var apparent_ratio: float=.42 if int(data.owner)==2 else .34
	var q: float=small/radius
	var beyond: float=maxf(small*6.0,q*separation/maxf(.01,apparent_ratio-q))
	var bound: float=radius*(2.25 if int(data.owner)==5 else 1.035)
	var lateral: float=(bound/radius+apparent_ratio+.42)*radius*beyond/separation
	var eye: Vector3=host+axes.z*(separation+beyond)-axes.x*lateral
	var forward: Vector3=((host-eye).normalized()+(moon-eye).normalized()).normalized()
	var up: Vector3=axes.y
	var aspect: float=maxf(.25,viewport.x/maxf(1.0,viewport.y))
	var tangent: float=1.0
	for iteration: int in range(8):
		var right: Vector3=forward.cross(up).normalized()
		up=right.cross(forward).normalized()
		var limits: Rect2=_limits(eye,forward,right,up,host,bound,moon,small*1.035)
		tangent=maxf(limits.size.x/(2.0*aspect*frame.size.x*.88),limits.size.y/(2.0*frame.size.y*.88))
		var desired: Vector2=Vector2((frame.get_center().x*2.0-1.0)*tangent*aspect,(1.0-frame.get_center().y*2.0)*tangent)
		var correction: Vector2=limits.get_center()-desired
		forward=(forward+right*correction.x+up*correction.y).normalized()
	var target: Vector3=eye+forward*eye.distance_to(host)
	return {"position":eye,"target":target,"up":up,"fov":clampf(rad_to_deg(2.0*atan(tangent)),.05,80.0),
		"near":clip_near(data,eye)}

static func _limits(eye: Vector3, forward: Vector3, right: Vector3, up: Vector3, host: Vector3, radius: float, moon: Vector3, small: float) -> Rect2:
	var low: Vector2=Vector2(INF,INF)
	var high: Vector2=Vector2(-INF,-INF)
	for body: Array in [[host,radius],[moon,small]]:
		var delta: Vector3=Vector3(body[0])-eye
		var depth: float=delta.dot(forward)
		var x: float=delta.dot(right)
		var y: float=delta.dot(up)
		var r: float=float(body[1])
		var horizontal: float=asin(clampf(r/sqrt(x*x+depth*depth),0.0,.999))
		var vertical: float=asin(clampf(r/sqrt(y*y+depth*depth),0.0,.999))
		low=low.min(Vector2(tan(atan2(x,depth)-horizontal),tan(atan2(y,depth)-vertical)))
		high=high.max(Vector2(tan(atan2(x,depth)+horizontal),tan(atan2(y,depth)+vertical)))
	return Rect2(low,high-low)

static func configure(stage: Node, data: Dictionary, pose: Dictionary, pole: Vector3) -> void:
	stage.set_meta(META,{"mode":"pair","owner":int(data.owner),"key":str(data.key),"normal":pole,
		"base_fov":float(pose.fov),"fov":float(pose.fov)})
	remember(stage,data,pose)

static func remember(stage: Node, data: Dictionary = {}, pose: Dictionary = {}) -> void:
	var value: Dictionary=state(stage)
	if not is_pair(stage): return
	if data.is_empty(): data=subjects(stage,int(value.owner),str(value.key))
	if data.is_empty(): clear(stage); return
	var axes: Basis=frame_basis(data,value.normal)
	var distance: float=data.planet.position.distance_to(data.moon.position)
	var eye: Vector3=pose.get("position",stage.camera.position)
	var target: Vector3=pose.get("target",stage.get_meta("camera_look_target",Vector3.ZERO))
	var up: Vector3=pose.get("up",stage.camera.basis.y)
	value.eye=axes.transposed()*(eye-data.planet.position)/distance
	value.aim=axes.transposed()*(target-data.planet.position)/distance
	value.up=axes.transposed()*up
	value.fov=float(pose.get("fov",stage.camera.fov))

static func tracked_pose(stage: Node) -> Dictionary:
	var value: Dictionary=state(stage)
	var data: Dictionary=subjects(stage,int(value.owner),str(value.key))
	if data.is_empty(): clear(stage); return {}
	var axes: Basis=frame_basis(data,value.normal)
	var distance: float=data.planet.position.distance_to(data.moon.position)
	return {"position":data.planet.position+axes*Vector3(value.eye)*distance,
		"target":data.planet.position+axes*Vector3(value.aim)*distance,"up":axes*Vector3(value.up),"fov":float(value.fov),
		"near":clip_near(data,data.planet.position+axes*Vector3(value.eye)*distance)}

static func detail(stage: Node, owner: int, key: String, distance: float) -> void:
	stage.set_meta(META,{"mode":"detail","owner":owner,"key":key,"detail_distance":distance})

static func saved(stage: Node) -> Dictionary:
	var result: Dictionary=state(stage).duplicate()
	if not result.is_empty(): result.fov=stage.camera.fov
	for field: String in ["normal","eye","aim","up"]:
		if result.has(field):
			var v: Vector3=result[field]
			result[field]=[v.x,v.y,v.z]
	return result

static func restore(stage: Node, value: Dictionary) -> void:
	var result: Dictionary=value.duplicate(true)
	for field: String in ["normal","eye","aim","up"]:
		if result.has(field): result[field]=Vector3(result[field][0],result[field][1],result[field][2])
	stage.set_meta(META,result)


static func clip_near(data: Dictionary, eye: Vector3) -> float:
	# A useful near plane is essential to separate thin clouds in a distant
	# telephoto view. It stays safely before the nearest of the two surfaces.
	var surface: float=minf(eye.distance_to(data.planet.position)-float(data.radius)*(2.25 if int(data.owner)==5 else 1.04),eye.distance_to(data.moon.position)-float(data.moon_radius))
	return maxf(.001,surface*.05)
