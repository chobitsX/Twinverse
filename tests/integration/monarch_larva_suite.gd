extends "res://tests/integration/galactic_suite.gd"
const Larva=preload("res://scripts/experience/monarch_larva_observation.gd")

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world144-check="): directory=arg.trim_prefix("--world144-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,800);root.unfocusable=true
	main=Experience.instantiate();root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("woodland"): finish_larva();return
	main.world.set_paused(true);main._reduced_motion=true;main.ground_light_preview=false
	var authority: RefCounted=main.world
	var time: float=main.world.simulation_time_s
	var stage: Node=main.coordinator.active_scene
	check("actual larva attached to existing woodland",stage.has_meta("monarch_larva"))
	if not stage.has_meta("monarch_larva"): finish_larva();return
	var data: Dictionary=stage.get_meta("monarch_larva")
	var larva: Node3D=data.node
	check("original continuous GLB body and same host plant",larva.find_child("LarvaContinuousBody",true,false)!=null and data.plant==stage.get_meta("milkweed_plants")[0])
	var body: MeshInstance3D=larva.find_child("LarvaContinuousBody",true,false) as MeshInstance3D
	var material: StandardMaterial3D=body.mesh.surface_get_material(0) as StandardMaterial3D
	var colours: PackedColorArray=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var darkest: float=1.;var brightest: float=0.
	for colour: Color in colours: darkest=minf(darkest,colour.r);brightest=maxf(brightest,colour.r)
	check("imported pigment actually drives body material with dark and pale bands",material.vertex_color_use_as_albedo and darkest<.03 and brightest>.5)
	check("three pairs of thoracic legs and five pairs of prolegs",larva.find_children("ThoracicLeg*","MeshInstance3D",true,false).size()==6 and larva.find_children("ProlegA*","MeshInstance3D",true,false).size()==10)
	check("paired front rear filaments remain distinct from head antennae",larva.find_children("TentacleSurface*","MeshInstance3D",true,false).size()==4 and larva.find_children("ShortHeadAntenna*","MeshInstance3D",true,false).size()==2)
	var feet: Array[Node]=larva.find_children("TrueFoot*","Node3D",true,false)
	feet.append_array(larva.find_children("ProlegFoot*","Node3D",true,false))
	var supported: bool=feet.size()==16
	var worst: float=0.
	for foot: Node3D in feet:
		var contact: Dictionary=Larva.leaf_hit(data.leaf,foot.global_position+Vector3.UP*.005)
		if contact.is_empty(): supported=false;continue
		worst=maxf(worst,foot.global_position.distance_to(contact.at))
	check("all sixteen feet remain within one millimetre of actual host leaf",supported and worst<.001)
	var real_contact: bool=true
	for foot: Node3D in feet:
		var name: String=str(foot.name).replace("TrueFoot","ThoracicLeg").replace("ProlegFoot","ProlegPad")
		var part: MeshInstance3D=larva.find_child(name,true,false) as MeshInstance3D
		var vertices: PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var nearest: float=INF
		for vertex: Vector3 in vertices: nearest=minf(nearest,part.to_global(vertex).distance_to(foot.global_position))
		real_contact=real_contact and nearest<.00075
	check("real foot geometry reaches fitted contact markers",real_contact)
	print("LARVA_SUPPORT_MAX_M ",worst)
	main._open_guide();main.world_guide.search.text="幼虫"
	main.world_guide.search.text_changed.emit("幼虫")
	var route: Button
	for entry: Button in main.world_guide.route_buttons:
		if entry.get_meta("guide_topic","")=="monarch_larva": route=entry
	check("new life stage has searchable route without species inflation",route!=null and route.visible and main.world_guide.route_buttons.size()==42)
	if route==null: finish_larva();return
	route.pressed.emit();await frames()
	var panel: Node=main.explorer_panel
	check("stable identity selects larva without shifting older target indices",main.content_targets()[main._content_follow].node==larva and main.content_targets()[6].node==stage.get_meta("pollinators")[0].node)
	check("life stage comparison controls and source are visible",panel.monarch_controls.visible and panel.lesson_source.visible and main.learning_overlay.topic=="monarch_larva")
	check("close view keeps body and both ends beside explanation",fits_larva(larva))
	await capture("larva-on-leaf")
	var pose: Transform3D=larva.transform
	var jaw: Vector3=data.joints.MandibleL.rotation
	await frames()
	check("pause keeps attachment and authored motion fixed",larva.transform.is_equal_approx(pose) and data.joints.MandibleL.rotation.is_equal_approx(jaw) and main.world.simulation_time_s==time)
	stage.builder.Larva.animate(stage,time+1.)
	check("authored mouth movement does not move supporting feet",not data.joints.MandibleL.rotation.is_equal_approx(jaw) and larva.transform.is_equal_approx(pose))
	stage.builder.Larva.animate(stage,time)
	panel.monarch_controls.get_child(1).pressed.emit();await frames()
	check("compare button reaches existing adult flower observation",main.learning_overlay.topic=="monarch" and main._content_follow==6 and panel.monarch_controls.visible)
	await capture("adult-comparison")
	panel.monarch_controls.get_child(0).pressed.emit();root.size=Vector2i(900,650);await frames()
	check("compact view preserves larva and both comparison buttons",fits_larva(larva) and panel.monarch_controls.get_global_rect().end.y<650-60)
	await capture("larva-compact")
	main._open_guide();main.world_guide.show_ecology(true)
	var map: Node=main.world_guide.ecology_map
	map.set_branch("woodland");map.select_relation(1);await frames()
	check("previously absent larva is now an enabled real 3D graph endpoint",not map.nodes.larva.disabled and not map.explanation.text.contains("尚未建模"))
	map.nodes.larva.pressed.emit();await frames()
	check("ecology endpoint opens the same individual",main.learning_overlay.topic=="monarch_larva" and main.content_targets()[main._content_follow].node==larva)
	main.observe_scale("earth");if not await ready_scale("earth"):finish_larva();return
	main.observe_scale("woodland");if not await ready_scale("woodland"):finish_larva();return
	stage=main.coordinator.active_scene;data=stage.get_meta("monarch_larva")
	check("return retains identity leaf placement and the one world clock",data.node.get_meta("stable_id")==Larva.STABLE_ID and data.node.transform.is_equal_approx(pose) and main.world==authority and main.world.simulation_time_s==time)
	check("native run obeys background cap",not native or Engine.max_fps==5)
	finish_larva()

func fits_larva(node: Node3D) -> bool:
	var stage: Node=main.coordinator.active_scene
	var viewport_size: Vector2=stage.viewport.size
	var left: float=main.explorer_panel.get_global_rect().end.x*viewport_size.x/root.size.x
	for local: Vector3 in [Vector3(-.022,0,0),Vector3(.023,0,0),Vector3(.014,.018,0),Vector3(0,0,.004)]:
		var at: Vector3=node.to_global(local)
		var point: Vector2=stage.camera.unproject_position(at)
		if stage.camera.is_position_behind(at) or point.x<left+8 or point.x>viewport_size.x-8 or point.y<80.*viewport_size.y/root.size.y or point.y>viewport_size.y*(root.size.y-80.)/root.size.y:return false
	return true

func finish_larva() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"native":native,"debug_build":OS.is_debug_build(),"performance_test":false},"\t")+"\n")
	print("MONARCH_LARVA_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
