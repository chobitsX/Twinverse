extends "res://tests/integration/observation_framing_suite.gd"

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world100-check="): directory = argument.trim_prefix("--world100-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless" and DisplayServer.get_screen_count()==1:
		main._measurement_screen = get_window().current_screen
		get_window().unfocusable = true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("reef"):
		await finish()
		return
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var targets: Array[Dictionary] = main.content_targets()
	check("urchin and top detail join the five existing marine targets",targets.size()==7 and targets[5].label.contains("Diadema setosum") and stage.get_meta("marine_actors").size()==44)
	var root: Node3D = targets[5].node
	var body: MeshInstance3D = root.find_child("Test",true,false) as MeshInstance3D
	check("authored test remains six by three centimetres",absf(body.get_aabb().size.x-.06)<.00001 and absf(body.get_aabb().size.y-.03)<.00001 and root.scale.is_equal_approx(Vector3.ONE))
	var body_material: StandardMaterial3D = body.get_active_material(0) as StandardMaterial3D
	var pigment: PackedColorArray = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check("dark test pigment is actually enabled on the imported material",body_material!=null and body_material.vertex_color_use_as_albedo and not body_material.vertex_color_is_srgb and pigment[0].r<.03)
	var white_count: int = 0
	var faces_up: bool = true
	for i: int in range(1,6):
		var spot: MeshInstance3D = root.find_child("WhiteSpot"+str(i),true,false) as MeshInstance3D
		if spot==null: continue
		white_count+=1
		var normals: PackedVector3Array = spot.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		for normal: Vector3 in normals: faces_up = faces_up and (spot.global_basis*normal).y>.4
	check("five real white spots face outward",white_count==5 and faces_up)
	var spines: MeshInstance3D = root.find_child("Spines",true,false) as MeshInstance3D
	var arrays: Array = spines.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var anchored: bool = true
	var bases: Dictionary = {}
	for i: int in range(vertices.size()):
		var phi: float = uv[i].x*TAU
		var c: float = 1.0-uv[i].y
		var s: float = sqrt(maxf(0,1.0-c*c))
		var base: Vector3 = Vector3(.03*s*cos(phi),.021+.015*c,.03*s*sin(phi))
		var radius: float = vertices[i].distance_to(base)
		anchored = anchored and radius<.152 and vertices[i].y>0
		if radius<.0012: bases[uv[i]] = true
	check("imported spine anchors survive glTF UV conversion",anchored and bases.size()==220)
	panel.object_picker.item_selected.emit(6)
	await settle()
	check("whole invertebrate clears explanation and viewport",subject_visible(root))
	await capture("urchin-whole")
	check("structure lesson selects the attached top view",panel.select_topic("urchin") and main._content_follow==6 and targets[6].node.get_meta("urchin_root")==root)
	await settle()
	check("six structure annotations and source are shown",main.learning_overlay.last_visible_marks==6 and panel.lesson_source.visible and panel.lesson_text.text.contains("不是眼睛"))
	await capture("urchin-top-structure")
	var position: Vector3 = root.position
	var material: ShaderMaterial = stage.get_meta("urchin_spine_material")
	await at_time(12.0)
	check("spine motion reads the only world time",absf(float(material.get_shader_parameter("world_time"))-12.0)<.001 and root.position.is_equal_approx(position))
	await settle()
	check("pause freezes the authored spine motion",main.world.simulation_time_s==12.0 and absf(float(material.get_shader_parameter("world_time"))-12.0)<.001)
	panel.markers_toggle.set_pressed(false)
	await settle()
	check("structure annotations can be hidden",main.learning_overlay.last_visible_marks==0)
	if not await arrive("earth"):
		await finish()
		return
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="urchin": action=button
	check("nineteenth guide route reaches the real lesson",action!=null and main.world_guide.route_buttons.size()==19)
	if action!=null:
		action.pressed.emit()
		if not await ready_stage():
			await finish()
			return
	await settle()
	check("return keeps reference identity and shared time",main.world.current_scale_id=="reef" and main.learning_overlay.topic=="urchin" and main.content_targets()[5].node.get_meta("stable_id")=="3dworld:teaching:diadema-setosum:0001" and main.world.simulation_time_s==12.0)
	get_window().size = Vector2i(900,650)
	await settle()
	root = main.content_targets()[5].node
	check("compact body geometry and controls remain observable",subject_visible(root.find_child("Test",true,false)) and panel.topic_picker.get_global_rect().end.y<panel.get_global_rect().end.y)
	await capture("urchin-compact")
	await finish()
