extends "res://tests/integration/world_expansion_suite.gd"
const Turtle = preload("res://scripts/experience/box_turtle.gd")
const Species = preload("res://scripts/experience/species_catalog.gd")
const Store = preload("res://scripts/core/world_store.gd")
var samples: Array[Dictionary] = []
var settings: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var observations: Dictionary = {}
var ground_mesh_id: int = -1
var ground_vertices: PackedVector3Array = PackedVector3Array()
var ground_indices: PackedInt32Array = PackedInt32Array()

func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen==DisplayServer.get_primary_screen(): continue
		if get_window().current_screen!=screen:
			var wanted: Vector2i = get_window().size
			get_window().current_screen = screen
			get_window().position = DisplayServer.screen_get_usable_rect(screen).position+Vector2i(30,30)
			get_window().size = wanted
		main._measurement_screen = screen
		break
	for frame: int in range(4): await get_tree().process_frame

func at_time(value: float) -> void:
	main.world.simulation_time_s=value
	await settle()

func slot_for(identity: String) -> int:
	var entries: Array[Dictionary] = main.content_targets(false)
	for index: int in range(entries.size()):
		if str(entries[index].node.get_meta("stable_id",""))==identity: return index
	return -1

func actual_ground(root: Node3D,at: Vector3) -> float:
	# Independent plane intersection of the actual indexed triangles, rather than
	# the runtime's weighted-vertex interpolation or original curved generator.
	var data: Dictionary = root.get_meta("turtle_skin")
	var terrain: MeshInstance3D = data.terrain
	if terrain.mesh.get_instance_id()!=ground_mesh_id:
		var arrays: Array = terrain.mesh.surface_get_arrays(0)
		ground_vertices = arrays[Mesh.ARRAY_VERTEX]
		ground_indices = arrays[Mesh.ARRAY_INDEX]
		ground_mesh_id = terrain.mesh.get_instance_id()
	var vertices: PackedVector3Array = ground_vertices
	var indices: PackedInt32Array = ground_indices
	var local: Vector3 = terrain.to_local(at)
	var cell: int = (int(floor(local.z/1.25))+100)*200+int(floor(local.x/1.25))+100
	for triangle: int in range(2):
		var first: int = cell*6+triangle*3
		var a: Vector3 = vertices[indices[first]]
		var b: Vector3 = vertices[indices[first+1]]
		var c: Vector3 = vertices[indices[first+2]]
		var p: Vector2 = Vector2(local.x,local.z)
		var aa: Vector2 = Vector2(a.x,a.z)
		var bb: Vector2 = Vector2(b.x,b.z)
		var cc: Vector2 = Vector2(c.x,c.z)
		var crosses: Array[float] = [(bb-aa).cross(p-aa),(cc-bb).cross(p-bb),(aa-cc).cross(p-cc)]
		if crosses.all(func(value: float) -> bool: return value>=-.000001) or crosses.all(func(value: float) -> bool: return value<=.000001):
			var hit: Variant = Plane(a,b,c).intersects_ray(Vector3(local.x,local.y+1.,local.z),Vector3.DOWN)
			if hit!=null: return terrain.to_global(hit).y
	return INF

func foot_metrics(root: Node3D) -> Dictionary:
	var skin: Dictionary = root.get_meta("turtle_skin")
	var feet: Array[Dictionary] = []
	var worst: float = 0.
	var clamped: float = 0.
	for request: Dictionary in root.get_meta("foot_requests"):
		var key: String = request.key
		var minimum: float = INF
		var max_ground_error: float = 0.
		for vertex: Vector3 in skin.soles[key]:
			var actual: Vector3 = Turtle.point(root,key+"Paw",vertex)
			var ground: float = actual_ground(root,actual)
			minimum = minf(minimum,actual.y-ground)
			max_ground_error = maxf(max_ground_error,absf(ground-Turtle.ground_at(root,actual.x,actual.z)))
		var error: float = absf(minimum-float(request.lift_m))
		worst = maxf(worst,error)
		clamped = maxf(clamped,float(request.clamped_m))
		feet.append({"key":key,"actual_min_clearance_m":minimum,"authored_lift_m":request.lift_m,"error_m":error,"sole_vertices":skin.soles[key].size(),"independent_ground_error_m":max_ground_error})
	return {"time_s":main.world.simulation_time_s,"feet":feet,"worst_lift_error_m":worst,"max_clamped_m":clamped}

func subject_fits(root: Node3D,head_only: bool=false) -> bool:
	if main.world_guide.visible or not main.explorer_panel.visible: return false
	var stage: Node = main.coordinator.active_scene
	var left: float = main.explorer_panel.get_global_rect().end.x+8.
	var count: int = 0
	var clear: bool = true
	var bounds: Rect2
	var points: PackedVector3Array = PackedVector3Array()
	if head_only:
		for x: float in [.073,.087,.110]:
			for y: float in [.024,.051]:
				for z: float in [-.016,.016]: points.append(Turtle.point(root,"Head",Vector3(x,y,z)))
	else:
		# Rigid shell vertices and actual deformed rigid soles/head endpoints.
		var shell: MeshInstance3D = root.find_child("CarapaceDome",true,false) as MeshInstance3D
		var vertices: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for index: int in range(0,vertices.size(),8): points.append(shell.to_global(vertices[index]))
		var skin: Dictionary = root.get_meta("turtle_skin")
		for key: String in Turtle.KEYS:
			for vertex: Vector3 in skin.soles[key]: points.append(Turtle.point(root,key+"Paw",vertex))
		points.append(Turtle.point(root,"Head",Vector3(.110,.025,0)))
		points.append(Turtle.point(root,"Tail",Vector3(-.086,.014,.002)))
	for point: Vector3 in points:
		var pixel: Vector2 = stage.camera.unproject_position(point)
		bounds = Rect2(pixel,Vector2.ZERO) if count==0 else bounds.expand(pixel)
		clear = clear and not stage.camera.is_position_behind(point) and pixel.x>left and pixel.x<get_window().size.x-8 and pixel.y>85 and pixel.y<get_window().size.y-60
		count+=1
	root.set_meta("actual_projected_bounds",{"x":bounds.position.x,"y":bounds.position.y,"width":bounds.size.x,"height":bounds.size.y,"points":count,"head_only":head_only})
	return clear and count>0 and bounds.size.x>(90 if head_only else 180)

func capture(label: String) -> void:
	await settle()
	var stage: Node = main.coordinator.active_scene
	var data: Dictionary = stage.get_meta("box_turtle",{})
	settings.append({"view":label,"screen_count":DisplayServer.get_screen_count(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"window_size":[get_window().size.x,get_window().size.y]})
	if not data.is_empty():
		var root: Node3D = data.root
		samples.append({"view":label,"jd":main.solar_jd,"world_time_s":main.world.simulation_time_s,"root_position":Store.components(root.position),"root_heading":root.rotation.y,"root_scale":Store.components(root.scale),"head":Store.components(data.head_view.position),"camera_position":Store.components(stage.camera.position),"camera_target":Store.components(main._orbit_target),"projected_bounds":root.get_meta("actual_projected_bounds",{}),"markers":main.learning_overlay.last_visible_marks,"clearing_center":Store.components(data.clearing.center),"grass_clearance_m":data.clearing.grass_clearance_m,"feet":foot_metrics(root)})
	await super.capture(label)
	write_report("running")

func write_report(status: String) -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":status,"cases":cases,"failures":failures,"captures":captures,"samples":samples,"contacts":contacts,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false,"feeding_population_or_closure_tested":false},"  ")+"\n")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world238-review="): directory=argument.trim_prefix("--world238-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	main=Experience.instantiate()
	main.world.set_paused(true)
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage(): await finish(); return
	get_window().size=Vector2i(1280,800)
	main._audio.volume_db=-80.0
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world.set_time_scale(1.)
	main.set_solar_rate(0.)
	main.world_guide.hide()
	main.explorer_panel.show()
	await settle()
	var stage: Node=main.coordinator.active_scene
	var data: Dictionary=stage.get_meta("box_turtle",{})
	check("one metre-scale box turtle belongs to the existing woodland",not data.is_empty() and stage.scale_id=="woodland")
	if data.is_empty(): await finish(); return
	var root: Node3D=data.root
	var head: Node3D=data.head_view
	var skin: Dictionary=root.get_meta("turtle_skin")
	var skeleton: Skeleton3D=skin.skeleton
	var authority: int=main.world.get_instance_id()
	var old_date: float=main.solar_jd
	var body: MeshInstance3D=root.find_child("ContinuousSoftBody",true,false) as MeshInstance3D
	var shell: MeshInstance3D=root.find_child("CarapaceDome",true,false) as MeshInstance3D
	var shell_width: float=shell.get_aabb().size.x
	check("actual imported shell is fourteen centimetres and animal is not scaled",absf(shell_width-.14)<.00001 and root.scale.is_equal_approx(Vector3.ONE))
	check("sixteen actual bones and continuous soft mesh are present",skeleton.get_bone_count()==16 and body!=null and skin.soles.size()==4)
	check("two static plastron lobes and hinge seam are present",root.find_child("PlastronFrontLobe",true,false)!=null and root.find_child("PlastronRearLobe",true,false)!=null and root.find_child("PlastronHingeSeam",true,false)!=null)
	check("imported hind feet each retain four authored claws",root.find_children("Claw_HindL_*","MeshInstance3D",true,false).size()==4 and root.find_children("Claw_HindR_*","MeshInstance3D",true,false).size()==4)
	var rest_coordinates: bool=true
	for key: String in Turtle.KEYS:
		var fore: bool=key.begins_with("Fore")
		var side: float=1. if key.ends_with("L") else -1.
		rest_coordinates=rest_coordinates and skin.bones[key+"Paw"].origin.distance_to(Vector3(.041 if fore else -.037,.007,side*(.068 if fore else .062)))<1e-6
	check("actual glTF rest coordinates agree with the authored metre limb frame",rest_coordinates)
	var bind_clear: bool=true
	var arrays: Array=body.mesh.surface_get_arrays(0)
	for bind: int in range(body.skin.get_bind_count()):
		var id: int=body.skin.get_bind_bone(bind)
		if id<0: id=skeleton.find_bone(body.skin.get_bind_name(bind))
		var transform: Transform3D=skeleton.get_bone_global_rest(id)*body.skin.get_bind_pose(bind)
		bind_clear=bind_clear and transform.is_equal_approx(Transform3D.IDENTITY)
	check("actual imported skin binds use the same vertex and skeleton space",bind_clear and arrays[Mesh.ARRAY_VERTEX].size()>15000)
	check("selected original grass gap clears the complete circular route",float(data.clearing.grass_clearance_m)>Turtle.RADIUS_M+.13 and data.clearing.authored_candidates==12)
	var whole: int=slot_for(Turtle.STABLE_ID)
	var close: int=slot_for(Turtle.HEAD_ID)
	print("TURTLE_POINTER_REGISTRY ",JSON.stringify({"whole":whole,"close":close,"registered_root":main.object_pointer.choices.get(root.get_instance_id(),{}).get("index",-1),"registered_count":main.object_pointer.choices.size(),"menu_targets":main.content_targets(false).size()}))
	check("existing observation menu contains both stable subjects",whole>=0 and close==whole+1)
	await at_time(5.)
	main.explorer_panel.object_picker.item_selected.emit(whole+1)
	await settle()
	check("actual object signal follows this one root",main._content_follow==whole)
	check("whole topic reaches the same root and names scientific boundary",main.explorer_panel.select_topic("box_turtle") and main.explorer_panel.lesson_text.text.contains("Terrapene carolina carolina") and main.explorer_panel.lesson_text.text.contains("未演示闭壳"))
	await settle()
	var pixel: Vector2=stage.camera.unproject_position(root.to_global(Vector3(0,.070,.005)))
	var picked: Dictionary=main.object_pointer.pick(pixel)
	var origin: Vector3=stage.camera.project_ray_origin(pixel)
	var direction: Vector3=stage.camera.project_ray_normal(pixel)
	var target: Vector3=root.to_global(Vector3(0,.070,.005))
	var hits: Array[Dictionary]=[]
	for item: Dictionary in main.object_pointer.surfaces:
		if item.choice.get("node")!=root: continue
		var hit: Variant=main.object_pointer.surface_hit(item,origin,origin+direction*stage.camera.far)
		if hit is Vector3: hits.append({"mesh":item.node.name,"hit":true})
	var pointer_data: Dictionary={"available":main.object_pointer.available(),"pixel":Store.components(Vector3(pixel.x,pixel.y,0)),"camera_h_offset":stage.camera.h_offset,"ray_origin":Store.components(origin),"camera_position":Store.components(stage.camera.position),"ray_miss_m":(origin+direction*(target-origin).dot(direction)).distance_to(target),"selected_index":picked.get("index",-1),"registry":main.object_pointer.choices.size(),"registered_root":main.object_pointer.choices.get(root.get_instance_id(),{}).get("index",-1),"root_mesh_hits":hits}
	print("TURTLE_ACTUAL_POINTER ",JSON.stringify(pointer_data))
	check("real pointer query lazily registers and hits the actual same turtle",not picked.is_empty() and picked.get("node")==root and picked.get("index",-1)==whole and main.object_pointer.choices.get(root.get_instance_id(),{}).get("index",-1)==whole)
	main.object_pointer.activate(pixel)
	await settle()
	check("actual pointer activation follows same body at unchanged world time",main._content_follow==whole and main.world.simulation_time_s==5. and main.solar_jd==old_date)
	main.explorer_panel.select_topic("box_turtle")
	await settle()
	var fits: bool=subject_fits(root)
	print("TURTLE_INITIAL_VIEW ",JSON.stringify({"fits":fits,"bounds":root.get_meta("actual_projected_bounds"),"marks":main.learning_overlay.last_visible_marks,"near":stage.camera.near}))
	check("wide whole turtle and both learning labels are observable",fits and main.learning_overlay.last_visible_marks==2 and absf(stage.camera.near-.002)<1e-7)
	if "--box-turtle-pointer-only" in OS.get_cmdline_user_args():
		await capture("pointer-only")
		observations={"pointer_diagnostic":pointer_data}
		await finish()
		return
	await capture("box-whole")
	var paused_pose: Transform3D=root.transform
	var paused_head: Vector3=head.position
	var paused_knee: Quaternion=skeleton.get_bone_pose_rotation(skin.bones.ForeLKnee.id)
	await settle()
	check("pause holds root actual knee head and shared seconds",root.transform.is_equal_approx(paused_pose) and head.position.is_equal_approx(paused_head) and skeleton.get_bone_pose_rotation(skin.bones.ForeLKnee.id).is_equal_approx(paused_knee) and main.world.simulation_time_s==5.)
	main.world.set_paused(false)
	await get_tree().create_timer(.8).timeout
	main.world.set_paused(true)
	await settle()
	check("short continuation advances the one clock and same actual animal",main.world.simulation_time_s>5. and main.world.simulation_time_s<7. and not root.position.is_equal_approx(paused_pose.origin) and float(root.get_meta("sampled_world_time_s"))==main.world.simulation_time_s and main.solar_jd==old_date)
	await at_time(5.)
	check("head topic selects the existing same-body observer",main.explorer_panel.select_topic("box_turtle_head"))
	await settle()
	check("head anchor follows actual imported Head bone at unchanged size",main._content_follow==close and head.position.distance_to(Turtle.point(root,"Head",Vector3(.092,.038,0)))<1e-6 and root.scale.is_equal_approx(Vector3.ONE))
	check("wide head fills available space without clipping explanation",subject_fits(root,true) and main.learning_overlay.last_visible_marks==2)
	await capture("box-head")
	var support_ok: bool=true
	var ground_ok: bool=true
	for time: float in [0.,2.,5.,7.,10.,12.,14.,16.,22.,40.]:
		await at_time(time)
		var measured: Dictionary=foot_metrics(root)
		contacts.append(measured)
		support_ok=support_ok and float(measured.worst_lift_error_m)<.00045 and float(measured.max_clamped_m)<.0002
		for foot: Dictionary in measured.feet: ground_ok=ground_ok and float(foot.independent_ground_error_m)<.00001 and float(foot.actual_min_clearance_m)>-.0002
	check("forty actual sole sets follow swing or terrain support at ten short samples",support_ok)
	check("independent actual terrain planes agree and soles do not penetrate",ground_ok)
	await at_time(20.)
	var rest_pose: Transform3D=root.transform
	await at_time(22.)
	check("rest holds root while same-time head remains a posed observation",root.transform.is_equal_approx(rest_pose) and Turtle.sample(22.).moving==0. and root.get_meta("activity").contains("停步") and main.solar_jd==old_date)
	main.explorer_panel.select_topic("box_turtle")
	await settle()
	check("resting whole turtle remains visible",subject_fits(root))
	await capture("box-rest")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact whole turtle fits beside existing explanation",subject_fits(root) and main.learning_overlay.last_visible_marks==2)
	await capture("box-compact")
	main.explorer_panel.select_topic("box_turtle_head")
	await settle()
	check("compact head is close and clear at its original metre size",subject_fits(root,true) and main.learning_overlay.last_visible_marks==2)
	await capture("box-head-compact")
	main.explorer_panel.markers_toggle.button_pressed=false
	await settle()
	check("existing marks control hides the turtle labels",not main.learning_overlay.enabled and main.learning_overlay.last_visible_marks==0)
	main.explorer_panel.markers_toggle.button_pressed=true
	await settle()
	get_window().size=Vector2i(1280,800)
	main._open_guide()
	main.world_guide.species_button.pressed.emit()
	var atlas: Node=main.world_guide.species_atlas
	atlas.search.text="Terrapene carolina"
	atlas.search.text_changed.emit(atlas.search.text)
	await settle()
	check("atlas adds one unique terrestrial reptile without counting other life stages",Species.ENTRIES.size()==41 and atlas.cards.size()==41 and atlas.visible_ids()==["carolina"] and Species.ENTRIES.filter(func(entry: Dictionary) -> bool: return entry.scale=="woodland").size()==14)
	await capture("atlas-box-turtle")
	var card: Dictionary={}
	for item: Dictionary in atlas.cards:
		if item.entry.id=="carolina": card=item
	check("actual atlas card has a reachable woodland visit",not card.is_empty())
	if not card.is_empty(): card.button.pressed.emit()
	await settle()
	check("atlas real action returns to this whole turtle without date or clock change",main.learning_overlay.topic=="box_turtle" and main.world.simulation_time_s==22. and main.solar_jd==old_date and not main.world_guide.visible)
	main._open_guide()
	var route: Button=null
	for button: Button in main.world_guide.route_buttons:
		if str(button.get_meta("guide_topic",""))=="box_turtle_head": route=button
	check("two guide routes extend existing guide to ninety-one actions",route!=null and main.world_guide.route_buttons.size()==91)
	if route!=null: route.pressed.emit()
	await settle()
	check("guide real action reaches same head and paused world",main.learning_overlay.topic=="box_turtle_head" and main.world.paused and main.world.simulation_time_s==22.)
	main._remember_view()
	var saved_camera: Vector3=stage.camera.position
	var saved_target: Vector3=main._orbit_target
	if not await arrive("earth"): await finish(); return
	await settle()
	check("Earth remains original and no parallel world or turtle appears",main.world.get_instance_id()==authority and main.coordinator.active_scene.has_meta("earth_daylight") and not main.coordinator.active_scene.has_meta("box_turtle") and main.solar_jd==old_date)
	if not await arrive("woodland"): await finish(); return
	await settle()
	stage=main.coordinator.active_scene
	data=stage.get_meta("box_turtle")
	root=data.root
	check("ordinary return recreates deterministic same identity route and head pose",str(root.get_meta("stable_id"))==Turtle.STABLE_ID and root.position.distance_to(rest_pose.origin)<1e-6 and float(root.get_meta("sampled_world_time_s"))==22. and main.world.get_instance_id()==authority)
	check("original observer view restores at unchanged date and paused time",stage.camera.position.is_equal_approx(saved_camera) and main._orbit_target.is_equal_approx(saved_target) and main.world.paused and main.world.simulation_time_s==22. and main.solar_jd==old_date)
	main.explorer_panel.select_topic("box_turtle_head")
	await settle()
	check("returned head and original woodland contents stay reachable",subject_fits(root,true) and stage.get_meta("actors").size()==20 and stage.get_meta("pollinators").size()==4 and stage.has_meta("monarch_life_stages") and stage.has_meta("red_fox"))
	await capture("box-return")
	check("resource and diagnostic save-input boundaries hold",Engine.max_fps==5 and ProjectSettings.get_setting("application/run/max_fps")==30 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2 and main._render_ratio==.75 and not main._persistence_enabled and get_window().unfocusable and get_viewport().gui_disable_input)
	observations={"samples":samples,"contacts":contacts,"capture_window_settings":settings,"actual_shell_length_m":shell_width,"actual_bones":root.get_meta("turtle_skin").skeleton.get_bone_count(),"named_species":Species.ENTRIES.size(),"woodland_primary_entries":Species.ENTRIES.filter(func(entry: Dictionary) -> bool: return entry.scale=="woodland").size(),"guide_routes":main.world_guide.route_buttons.size(),"existing_actor_count":stage.get_meta("actors").size(),"existing_pollinators":stage.get_meta("pollinators").size(),"world_time_s":main.world.simulation_time_s,"jd":main.solar_jd,"paused":main.world.paused,"time_scale":main.world.time_scale,"max_fps":Engine.max_fps,"foreground_fps":30,"worker_pool_threads":2,"render_ratio":main._render_ratio,"audio_volume_db":main._audio.volume_db,"user_save_accessed":false,"save_schema_changed":false}
	await finish()

func finish() -> void:
	write_report("completed")
	print("BOX_TURTLE_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	main._quit(0 if failures.is_empty() else 1)
