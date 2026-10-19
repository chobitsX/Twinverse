extends "res://tests/integration/land_lighting_suite.gd"
const RayObservation = preload("res://scripts/experience/ray_observation.gd")
const RayShader = preload("res://shaders/ray_swim.gdshader")

# Use the actual production vertex shader on a thin calibration ribbon viewed
# from +Z. The measured image crest must move toward model -X (posterior).
func gpu_wave_probe() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size=Vector2i(600,240)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color.BLACK
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE
	world.environment.ambient_light_energy=1.
	viewport.add_child(world)
	var camera: Camera3D = Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=.24
	camera.position=Vector3(0,0,2)
	viewport.add_child(camera)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(221):
		var x: float = -.22+float(i)*.002
		for y: float in [-.002,.002]:
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(Vector3(x,y,.25))
	for i: int in range(220):
		var a: int = i*2
		for index: int in [a,a+1,a+2,a+1,a+3,a+2]: surface.add_index(index)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh=surface.commit()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader=RayShader
	# See both sides of the calibration ribbon by matching the generated winding.
	mesh.material_override=material
	viewport.add_child(mesh)
	var peaks: Array[float] = []
	for phase: float in [0.,.8]:
		mesh.set_instance_shader_parameter("swim_phase",phase)
		for frame: int in range(4): await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var best_y: float = INF
		var peak_x: int = -1
		var visible_columns: int = 0
		for x: int in range(600):
			var sum_y: float = 0.
			var count: int = 0
			for y: int in range(240):
				if image.get_pixel(x,y).get_luminance()>.1: sum_y+=y; count+=1
			if count>0:
				visible_columns+=1
				if sum_y/count<best_y: best_y=sum_y/count; peak_x=x
		peaks.append(float(peak_x))
		check("production shader probe visible phase %.1f" % phase,visible_columns>300)
		image.save_png(directory.path_join("gpu-wave-%.1f.png" % phase))
	comparisons.gpu_crest_x_px=peaks
	check("rendered crest travels from head +X toward tail -X",peaks[0]-peaks[1]>40.)
	viewport.queue_free()
	await get_tree().process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world126-check="): directory=argument.trim_prefix("--world126-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("reef"):
		await finish()
		return
	await gpu_wave_probe()
	await at_time(3.)
	var stage: Node = main.coordinator.active_scene
	var actor: Dictionary = stage.get_meta("marine_actors")[43]
	var root: Node3D = actor.node
	main.explorer_panel.show()
	await settle()
	check("ray motion topic selects the real animal",main.explorer_panel.select_topic("ray") and main.content_targets()[main._content_follow].node==root)
	get_window().size=Vector2i(900,650)
	await settle()
	check("complete ray body remains observable beside compact panel",subject_visible(root))
	check("three live fin annotations visible",main.learning_overlay.last_visible_marks==3)
	await capture("ray-wave-compact")
	get_window().size=Vector2i(1280,720)
	main.explorer_panel.hide()
	await settle()
	var points: PackedVector3Array = RayObservation.fin_points(root)
	var position: Vector3 = root.position
	await settle()
	check("pause freezes path and deformed annotation anchors",RayObservation.fin_points(root)==points and root.position==position)
	main.learning_overlay.enabled=false
	await capture("ray-wave-phase-a")
	await at_time(3.+.8/3.8)
	check("same world clock advances real fin shader and annotations",RayObservation.fin_points(root)[1].distance_to(points[1])>.0001 and is_equal_approx(float(actor.meshes[0].get_instance_shader_parameter("swim_phase")),3.*3.8+.8))
	await capture("ray-wave-phase-b")
	var time: float = main.world.simulation_time_s
	position=root.position
	if not await arrive("earth") or not await arrive("reef"):
		await finish()
		return
	actor=main.coordinator.active_scene.get_meta("marine_actors")[43]
	check("return retains ray route and host time",actor.node.position.distance_to(position)<.0001 and main.world.simulation_time_s==time)
	await finish()
