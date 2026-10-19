extends "res://tests/integration/world_expansion_suite.gd"
const Stages = preload("res://scripts/experience/monarch_life_stages.gd")
const Larva = preload("res://scripts/experience/monarch_larva_observation.gd")
const Species = preload("res://scripts/experience/species_catalog.gd")
const Store = preload("res://scripts/core/world_store.gd")
var observations: Dictionary = {}
var view_settings: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var isolated_directory: String = ""
var resumed: bool = false
var return_details: Dictionary = {}

func authority_without_observation_history(value: Dictionary) -> Dictionary:
	# Navigation legitimately records visits/events and samples. Keep all model
	# checkpoints and habitat identity/start, and test the arrival history below.
	var result: Dictionary=value.duplicate(true)
	for key: String in ["samples","events","visits"]: result.local_habitat.erase(key)
	return result

func pupa_clear_of_leaf(data: Dictionary) -> bool:
	var leaf: MeshInstance3D=data.leaf
	var camera: Camera3D=main.coordinator.active_scene.camera
	var start: Vector3=leaf.to_local(camera.global_position)
	var faces: PackedVector3Array=leaf.mesh.get_faces()
	var bounds: AABB=model_bounds(data.node,"PupaContinuousCuticle")
	var points: Array[Vector3]=[data.node.find_child("PupaTailMark",true,false).global_position]
	for corner: int in range(8): points.append(data.node.to_global(bounds.get_endpoint(corner)))
	for point: Vector3 in points:
		var end: Vector3=leaf.to_local(point)
		for index: int in range(0,faces.size(),3):
			var hit: Variant=Geometry3D.segment_intersects_triangle(start,end,faces[index],faces[index+1],faces[index+2])
			if hit!=null and leaf.to_global(hit).distance_to(point)>.00002: return false
	return true

func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen==DisplayServer.get_primary_screen(): continue
		if get_window().current_screen!=screen:
			var wanted: Vector2i=get_window().size
			get_window().current_screen=screen
			get_window().position=DisplayServer.screen_get_usable_rect(screen).position+Vector2i(30,30)
			get_window().size=wanted
		main._measurement_screen=screen
		break
	for frame: int in range(4): await get_tree().process_frame

func capture(label: String) -> void:
	await settle()
	var stage: Node=main.coordinator.active_scene
	view_settings.append({"view":label,"screen_count":DisplayServer.get_screen_count(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"window_size":[get_window().size.x,get_window().size.y]})
	var data: Dictionary=stage.get_meta("monarch_life_stages")
	samples.append({"view":label,"world_time_s":main.world.simulation_time_s,"topic":main.learning_overlay.topic,
		"egg_at":Store.components(data.egg.node.global_position),"pupa_at":Store.components(data.pupa.node.global_position),
		"camera_position":Store.components(stage.camera.position),"camera_target":Store.components(main._orbit_target),"near_clip_m":stage.camera.near})
	await super.capture(label)

func model_bounds(node: Node3D, mesh_name: String) -> AABB:
	var part: MeshInstance3D=node.find_child(mesh_name,true,false) as MeshInstance3D
	var vertices: PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bounds: AABB=AABB(node.to_local(part.to_global(vertices[0])),Vector3.ZERO)
	for vertex: Vector3 in vertices: bounds=bounds.expand(node.to_local(part.to_global(vertex)))
	return bounds

func fits(node: Node3D, mesh_name: String) -> bool:
	var stage: Node=main.coordinator.active_scene
	var bounds: AABB=model_bounds(node,mesh_name)
	var clear: bool=true
	var left: float=main.explorer_panel.get_global_rect().end.x+8.0
	var view: Rect2=Rect2(Vector2(left,112),Vector2(get_window().size.x-left-22,get_window().size.y-218))
	for index: int in range(8):
		var at: Vector3=node.to_global(bounds.get_endpoint(index))
		clear=clear and not stage.camera.is_position_behind(at) and view.has_point(stage.camera.unproject_position(at))
	return clear

func controls_fit() -> bool:
	var panel: Node=main.explorer_panel
	var clip: Rect2=panel.scroll.get_global_rect().grow(.5)
	var clear: bool=panel.monarch_controls.get_child_count()==4
	for control: Control in [panel.topic_picker,panel.monarch_stage_hint]:
		clear=clear and control.is_visible_in_tree() and clip.encloses(control.get_global_rect())
	for button: Button in panel.monarch_controls.get_children():
		clear=clear and button.is_visible_in_tree() and clip.encloses(button.get_global_rect())
	return clear

func press_stage(index: int) -> void:
	main.explorer_panel.monarch_controls.get_child(index).pressed.emit()
	await settle()

func pose_vertices_finite(node: Node3D) -> bool:
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			if not mesh.to_global(vertex).is_finite(): return false
	return true

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world236-review="): directory=arg.trim_prefix("--world236-review=")
		if arg.begins_with("--world-dir="): isolated_directory=arg.trim_prefix("--world-dir=")
		if arg=="--world236-resume": resumed=true
	var target: String=directory.get_file().get_slice("-",0)
	var expected: String=directory.get_base_dir().path_join(target+"-stages").path_join("isolated-world")
	if not directory.is_absolute_path() or target not in ["source","release"] or isolated_directory!=expected:
		get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	main=Experience.instantiate()
	main.world.set_paused(true)
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage(): await finish();return
	get_window().size=Vector2i(1280,800)
	main._audio.volume_db=-80.0
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	await settle()
	check("ordinary persistence uses only explicit isolated directory and woodland",main._persistence_enabled and main._store.directory==isolated_directory and main.world.current_scale_id=="woodland")
	if resumed: await resume_flow();return
	main.world.simulation_time_s=12.0
	main.world.set_time_scale(2.0)
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.explorer_panel.show()
	await settle()
	var authority: int=main.world.get_instance_id()
	var stage: Node=main.coordinator.active_scene
	var data: Dictionary=stage.get_meta("monarch_life_stages",{})
	check("new references are actual imported meshes on existing two plants",not data.is_empty())
	if data.is_empty(): await finish();return
	var egg: Node3D=data.egg.node
	var pupa: Node3D=data.pupa.node
	var larva: Node3D=stage.get_meta("monarch_larva").node
	var adult: Node3D=stage.get_meta("pollinators")[0].node
	var egg_bounds: AABB=model_bounds(egg,"EggRidgedShell")
	var pupa_bounds: AABB=model_bounds(pupa,"PupaContinuousCuticle")
	check("imported egg has actual 1.2 by 0.9 millimetre geometry at unit scale",absf(egg_bounds.size.y-.0012)<.000002 and absf(egg_bounds.size.x-.0009)<.000002 and egg.scale.is_equal_approx(Vector3.ONE))
	check("imported continuous green pupa is authored 25 millimetres and finite",absf(pupa_bounds.size.y-.025)<.000002 and pupa.scale.is_equal_approx(Vector3.ONE) and pose_vertices_finite(egg) and pose_vertices_finite(pupa))
	var shell: MeshInstance3D=egg.find_child("EggRidgedShell",true,false) as MeshInstance3D
	var cuticle: MeshInstance3D=pupa.find_child("PupaContinuousCuticle",true,false) as MeshInstance3D
	check("actual imported cream and jade pigment drives visible materials",(shell.mesh.surface_get_material(0) as StandardMaterial3D).vertex_color_use_as_albedo and (cuticle.mesh.surface_get_material(0) as StandardMaterial3D).vertex_color_use_as_albedo and shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR].size()>0)
	var supported: bool=true
	for row: Dictionary in [data.egg,data.pupa]:
		supported=supported and row.support.normal.y<-.75 and row.top.at.y>row.support.at.y and row.top.at.distance_to(row.support.at)<.0005 and row.node.global_position.distance_to(row.support.at)<.00006 and row.leaf.name=="MilkweedOppositeLeaves"
	check("actual bottom triangles support egg and silk at original leaf thickness",supported and data.egg.plant==stage.get_meta("milkweed_plants")[0] and data.pupa.plant==stage.get_meta("milkweed_plants")[1])
	check("egg extends below leaf and pupa hangs down with real dark attachment and silk",egg.find_child("EggTip",true,false).global_position.y<egg.global_position.y-.001 and pupa.find_child("PupaCremaster",true,false)!=null and pupa.find_child("PupaSilkPad",true,false)!=null and pupa.find_child("PupaBodyMark",true,false).global_position.y<pupa.global_position.y-.014)
	check("four distinct stable stage IDs do not replace existing larva or adults",egg.get_meta("stable_id")==Stages.EGG_ID and pupa.get_meta("stable_id")==Stages.PUPA_ID and larva.get_meta("stable_id")==Larva.STABLE_ID and adult.get_meta("stable_id")=="3dworld:teaching:monarch:0000" and stage.get_meta("pollinators").size()==4 and main.content_targets()[6].node==adult)
	var actual_feet: Array[Node]=larva.find_children("*Foot*","Node3D",true,false)
	var supported_feet: bool=actual_feet.size()==16
	for foot: Node3D in actual_feet:
		var hit: Dictionary=Larva.leaf_hit(stage.get_meta("monarch_larva").leaf,foot.global_position+Vector3.UP*.005)
		supported_feet=supported_feet and not hit.is_empty() and foot.global_position.distance_to(hit.get("at",Vector3.INF))<.001
	check("original larva real leaf contacts remain supported",supported_feet)
	var found: int=0
	for entry: Dictionary in Species.ENTRIES:
		if entry.id=="plexippus": found+=1;check("single species atlas entry opens four-stage observation",entry.topic=="monarch_egg")
	check("no stage inflates forty named species",found==1 and Species.ENTRIES.size()==40)
	main._open_guide()
	main.world_guide.search.text="帝王蝶"
	main.world_guide.search.text_changed.emit("帝王蝶")
	var route: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="monarch_egg": route=button
	check("two new real routes produce eighty-eight and searchable egg entry",main.world_guide.route_buttons.size()==88 and route!=null and route.visible)
	var before: Dictionary=main.world.checkpoint()
	route.pressed.emit()
	await settle()
	check("actual guide opens same egg without playback date or world reset",main.learning_overlay.topic=="monarch_egg" and main.content_targets()[main._content_follow].node==egg and main.world.checkpoint()==before and main.solar_jd==Ephemeris.DEFAULT_JD and main.solar_rate==0.0)
	check("front four-stage controls and source are visible",controls_fit() and main.explorer_panel.lesson_source.visible and main.explorer_panel.monarch_controls.get_child(0).button_pressed)
	check("egg body beside panel and microscopic clip preserve real scale",fits(egg,"EggRidgedShell") and stage.camera.near<.0001 and main.learning_overlay.last_visible_marks==2)
	await capture("egg-close")
	check("ordinary save accepts microscopic pose and existing v15 checkpoint",main.save_world()=="ok")
	var loaded: Dictionary=main._store.load_session()
	check("actual isolated JSON stores pose with unchanged world format",loaded.status=="ok" and loaded.payload.world.version==15 and Store.vector(loaded.payload.observer.views.woodland.position).is_equal_approx(stage.camera.position))
	main._persistence_enabled=false
	var roots: Array[Transform3D]=[egg.transform,pupa.transform,larva.transform,adult.transform]
	var jaw: Vector3=stage.get_meta("monarch_larva").joints.MandibleL.rotation
	await settle()
	check("pause fixes static stages original motions and world together",roots==[egg.transform,pupa.transform,larva.transform,adult.transform] and stage.get_meta("monarch_larva").joints.MandibleL.rotation==jaw and main.world.checkpoint()==before)
	var wheel: InputEventMouseButton=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.position=Vector2(750,400)
	main._unhandled_input(wheel)
	await settle()
	check("programmatic normal zoom retains subcentimetre target range",stage.camera.position.distance_to(main._orbit_target)<.02 and stage.camera.near<.0001)
	main._reset_observation_view()
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact egg keeps four controls sequence and whole physical body",controls_fit() and fits(egg,"EggRidgedShell"))
	await capture("egg-compact")
	get_window().size=Vector2i(1280,800)
	await press_stage(1)
	check("actual larva button selects original leaf body and food comparison",main.learning_overlay.topic=="monarch_larva" and main.content_targets()[main._content_follow].node==larva and controls_fit() and main.explorer_panel.lesson_readout.text.contains("乳草叶"))
	await capture("larva-stage")
	await press_stage(2)
	check("actual pupa button selects same suspended body with source and boundaries",main.learning_overlay.topic=="monarch_pupa" and main.content_targets()[main._content_follow].node==pupa and controls_fit() and fits(pupa,"PupaContinuousCuticle") and stage.camera.near<=.0011 and main.learning_overlay.last_visible_marks==2)
	check("actual host leaf does not occlude suspended body or cremaster",pupa_clear_of_leaf(data.pupa))
	await capture("pupa-close")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact pupa retains controls and full continuous body",controls_fit() and fits(pupa,"PupaContinuousCuticle"))
	check("compact host leaf leaves suspended body and cremaster visible",pupa_clear_of_leaf(data.pupa))
	await capture("pupa-compact")
	get_window().size=Vector2i(1280,800)
	await press_stage(3)
	check("actual adult button returns existing nectaring flying loop with one clock",main.learning_overlay.topic=="monarch" and main.content_targets()[main._content_follow].node==adult and is_equal_approx(stage.camera.near,.08) and main.world.checkpoint()==before)
	await capture("adult-stage")
	main.world.set_paused(false);main.world.advance(.1);main.world.set_paused(true)
	await settle()
	check("short continue moves existing larva adult only while static egg pupa stay",main.world.simulation_time_s>12.0 and not stage.get_meta("monarch_larva").joints.MandibleL.rotation.is_equal_approx(jaw) and not adult.transform.is_equal_approx(roots[3]) and egg.transform.is_equal_approx(roots[0]) and pupa.transform.is_equal_approx(roots[1]))
	main.world.restore_checkpoint(before)
	await settle()
	check("restore original paused authority restores existing motions without growth",main.world.get_instance_id()==authority and main.world.simulation_time_s==12.0 and adult.transform.is_equal_approx(roots[3]) and larva.transform.is_equal_approx(roots[2]))
	await press_stage(0)
	var remembered: Vector3=stage.camera.position
	main.observe_scale("earth");if not await ready_stage(): await finish();return
	main.observe_scale("woodland");if not await ready_stage(): await finish();return
	await settle()
	stage=main.coordinator.active_scene
	data=stage.get_meta("monarch_life_stages")
	var returned: Dictionary=main.world.checkpoint()
	return_details={"camera_restored":stage.camera.position.is_equal_approx(remembered),"near_clip_m":stage.camera.near,"egg_id":data.egg.node.get_meta("stable_id"),"pupa_id":data.pupa.node.get_meta("stable_id"),"world_instance_kept":main.world.get_instance_id()==authority,"model_authority_kept":authority_without_observation_history(returned)==authority_without_observation_history(before),"original_event_count":before.local_habitat.events.size(),"returned_events":returned.local_habitat.events.slice(before.local_habitat.events.size())}
	check("earth return restores microscopic view and original authority stage IDs",return_details.camera_restored and stage.camera.near<.0001 and return_details.egg_id==Stages.EGG_ID and return_details.pupa_id==Stages.PUPA_ID and return_details.world_instance_kept and return_details.model_authority_kept)
	check("normal Earth woodland arrival records retain paused world seconds",return_details.returned_events==[{"kind":"arrived","time_s":12.0,"scale_id":"earth","multiplier":2.0},{"kind":"arrived","time_s":12.0,"scale_id":"woodland","multiplier":2.0}])
	main._reset_camera()
	await settle()
	check("normal woodland overview restores ground clip and all existing actors",is_equal_approx(stage.camera.near,.08) and stage.get_meta("actors").size()==20 and stage.get_meta("pollinators").size()==4 and stage.get_meta("milkweed_plants").size()==6)
	await capture("woodland-return")
	check("runtime obeys background fps two workers fluid and inactive native input",Engine.max_fps==5 and ProjectSettings.get_setting("application/run/max_fps")==30 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2 and main._render_ratio==.75 and get_window().unfocusable and get_viewport().gui_disable_input)
	observations={"egg_local_bounds_size_m":Store.components(egg_bounds.size),"pupa_cuticle_bounds_size_m":Store.components(pupa_bounds.size),"world_time_s":main.world.simulation_time_s,"jd":main.solar_jd,"solar_rate":main.solar_rate,"paused":main.world.paused,"time_scale":main.world.time_scale,"checkpoint_version":15,"named_species":40,"guide_routes":88,"actual_save_world":true,"isolated_world_dir":isolated_directory,"user_save_accessed":false,"capture_window_settings":view_settings,"samples":samples,"return_details":return_details,"audio_volume_db":main._audio.volume_db,"max_fps":Engine.max_fps,"foreground_fps":30,"worker_pool_threads":2,"render_ratio":main._render_ratio}
	await finish()

func resume_flow() -> void:
	var stage: Node=main.coordinator.active_scene
	var loaded: Dictionary=main._store.load_session()
	var saved_view: Dictionary=loaded.payload.observer.views.woodland
	check("ordinary second process loads real isolated v15 save without catch-up",loaded.status=="ok" and main.world.simulation_time_s==12.0 and main.world.paused and main.world.time_scale==2.0 and main.solar_jd==Ephemeris.DEFAULT_JD and main.solar_rate==0.0)
	check("ordinary open restores actual millimetre pose target and derived clip",stage.camera.position.is_equal_approx(Store.vector(saved_view.position)) and main._orbit_target.is_equal_approx(Store.vector(saved_view.target)) and stage.camera.near<.0001)
	check("restored stage has original size leaf-backed egg and pupa",stage.get_meta("monarch_life_stages").egg.node.scale.is_equal_approx(Vector3.ONE) and stage.get_meta("monarch_life_stages").pupa.node.get_meta("stable_id")==Stages.PUPA_ID)
	var before: Dictionary=main.world.checkpoint()
	main.explorer_panel.show()
	await settle()
	check("restored same egg theme opens without world or date mutation",main.explorer_panel.select_topic("monarch_egg",true))
	await settle()
	check("restored explanation keeps physical egg and front stage buttons",fits(stage.get_meta("monarch_life_stages").egg.node,"EggRidgedShell") and controls_fit() and main.world.checkpoint()==before)
	await capture("egg-restored")
	check("restored native budget and isolated user-save boundary hold",Engine.max_fps==5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2 and main._render_ratio==.75 and main._store.directory==isolated_directory)
	main._persistence_enabled=false
	observations={"restored_from_actual_file":true,"world_time_s":12.0,"jd":main.solar_jd,"paused":main.world.paused,"time_scale":main.world.time_scale,"checkpoint_version":15,"capture_window_settings":view_settings,"samples":samples,"isolated_world_dir":isolated_directory,"user_save_accessed":false,"max_fps":Engine.max_fps,"render_ratio":main._render_ratio}
	await finish()

func finish() -> void:
	var file: FileAccess=FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"native_ime_tested":false},"\t")+"\n")
	file.close()
	print("MONARCH_STAGES236_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
