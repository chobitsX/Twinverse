extends RefCounted
## Camera-only navigation. The optical inspector reads existing render resources;
## neither navigation nor inspection owns a celestial state or clock.

static func subject(host: Node) -> MeshInstance3D:
	var stage: Node=host.coordinator.active_scene
	if stage.scale_id=="solar_system" and host.solar_follow>=0:
		return stage.get_meta("solar_bodies")[host.solar_follow].node
	if stage.scale_id in ["solar_system","earth_moon"] or stage.has_meta("natural_satellites"):
		var items: Array[Dictionary]=host.content_targets(false)
		if host._content_follow>=0 and host._content_follow<items.size() and items[host._content_follow].node is MeshInstance3D:
			return items[host._content_follow].node
	if host.SatelliteFraming.is_pair(stage):
		var frame: Dictionary=host.SatelliteFraming.state(stage)
		var pair: Dictionary=host.SatelliteFraming.subjects(stage,int(frame.owner),str(frame.get("key","")))
		if not pair.is_empty(): return pair.planet
	return null

static func orbit(host: Node, stage: Node, pixels: Vector2) -> bool:
	var node: MeshInstance3D=subject(host)
	if not is_instance_valid(node) or not host.learning_overlay.topic.is_empty(): return false
	if host.SatelliteFraming.is_pair(stage):
		if stage.scale_id=="solar_system": host.follow_planet(int(host.SatelliteFraming.state(stage).owner),true)
		else: host.follow_content(1)
		node=subject(host)
	if not is_instance_valid(node): return false
	var camera: Camera3D=stage.camera
	# Rotate eye and aim about the actual subject together. This preserves its
	# camera-space position and distance, including a composition's screen offset.
	var turn: Basis=Basis(camera.basis.y,-pixels.x*.004)*Basis(camera.basis.x,-pixels.y*.004)
	var center: Vector3=host._orbit_target-host._pan_offset
	var eye: Vector3=center+turn*(camera.position-center)
	var aim: Vector3=center+turn*(host._orbit_target-center)
	var current_aim: Vector3=host._orbit_target
	if not host._solar_camera_motion.is_empty():
		var motion: Dictionary=host._solar_camera_motion
		current_aim+=Vector3(motion.look)*(1.0-smoothstep(0.0,1.0,float(motion.elapsed)/float(motion.duration)))
		if motion.has("rotation_start"): current_aim=camera.position-camera.basis.z*maxf(.01,camera.position.distance_to(host._orbit_target))
	host._pan_offset=aim-center
	host._orbit_target=aim
	stage.set_meta("solar_lookaround",false)
	if not host._solar_camera_motion.is_empty():
		for field: String in ["start","finish","look","up_start","up_end"]:
			host._solar_camera_motion[field]=turn*Vector3(host._solar_camera_motion[field])
		for field: String in ["rotation_start","rotation_end"]:
			if host._solar_camera_motion.has(field): host._solar_camera_motion[field]=(turn*Basis(host._solar_camera_motion[field])).get_rotation_quaternion()
	stage.set_pose(eye,center+turn*(current_aim-center),turn*camera.basis.y)
	return true

static func observer(stage: Node, aim: Vector3) -> Dictionary:
	if stage.scale_id!="solar_system": return {}
	var data: Dictionary=stage.get_meta("solar_physical",{})
	if int(data.get("owner",-1))<0 or not data.has("km_to_world"): return {}
	return {"owner":int(data.owner),"centre":data.centres[int(data.owner)].duplicate(),"anchor":data.anchor,
		"unit":float(data.km_to_world),"eye":stage.camera.position,"aim":aim,"basis":stage.camera.basis,"up":stage.camera.basis.y}

static func physical_position(stage: Node, item: Dictionary) -> Vector3:
	var data: Dictionary=stage.get_meta("solar_physical",{})
	if stage.scale_id=="solar_system" and int(data.get("owner",-1))>=0:
		if bool(item.get("sun",false)): return data.physical_positions[8]
		if bool(item.get("moon",false)): return data.physical_positions[9]
	return item.node.position

static func rebase(stage: Node, former: Dictionary) -> Dictionary:
	var data: Dictionary=stage.get_meta("solar_physical",{})
	if former.is_empty() or int(data.get("owner",-1))<0 or int(data.owner)==int(former.owner): return {}
	var offset: Vector3=Vector3(former.eye)-Vector3(former.anchor)
	var center: Array=data.centres[int(data.owner)]
	var old: Array=former.centre
	# Subtract astronomical centres in double precision before entering Vector3.
	var eye: Vector3=Vector3(data.anchor)+Vector3(
		(float(old[0])-float(center[0])+offset.x/float(former.unit))*float(data.km_to_world),
		(float(old[2])-float(center[2])+offset.y/float(former.unit))*float(data.km_to_world),
		(float(center[1])-float(old[1])+offset.z/float(former.unit))*float(data.km_to_world))
	# A short old sightline can round to zero beside astronomical coordinates.
	# Carry orientation directly; the aim distance is a camera aid, not geometry.
	var sight_length: float=maxf(1.0,maxf(eye.length()*.0001,Vector3(former.aim).distance_to(former.eye)*float(data.km_to_world)/float(former.unit)))
	var aim: Vector3=eye-Basis(former.basis).z*sight_length
	stage.set_meta("solar_transfer_projection",true)
	stage.camera.position=eye; stage.camera.basis=former.basis
	stage.builder.update_camera(stage)
	return {"position":eye,"target":aim}

static func choose(host: Node, choice: Dictionary) -> void:
	if choice.is_empty() or not is_instance_valid(choice.get("node")) or host.coordinator.is_busy(): return
	host.explorer_panel.hide()
	host.explorer_panel.clear_topic()
	if choice.has("planet"): host.follow_planet(int(choice.planet),true)
	else: host.follow_content(int(choice.index)+1,choice)
