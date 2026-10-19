extends "res://tests/integration/land_lighting_suite.gd"
const SpeciesShader = preload("res://shaders/marine_species.gdshader")

func ribbon_centers(image: Image) -> PackedFloat32Array:
	var centers: PackedFloat32Array = PackedFloat32Array()
	for x: int in range(image.get_width()):
		var sum: float = 0.
		var count: int = 0
		for y: int in range(image.get_height()):
			if image.get_pixel(x,y).get_luminance()>.1: sum+=y; count+=1
		centers.append(sum/count if count>0 else -1000.)
	return centers

func probe() -> void:
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
	camera.position=Vector3(-.1,2,0)
	viewport.add_child(camera)
	camera.look_at(Vector3(-.1,0,0),Vector3.FORWARD)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(301):
		var x: float = -.4+float(i)*.002
		for z: float in [-.002,.002]:
			# A valid flank basis supplied to the production vertex program.
			surface.set_normal(Vector3.BACK)
			surface.set_tangent(Plane(Vector3.RIGHT,1.))
			surface.add_vertex(Vector3(x,0,z))
	for i: int in range(300):
		var a: int = i*2
		for index: int in [a,a+1,a+2,a+1,a+3,a+2]: surface.add_index(index)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh=surface.commit()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader=SpeciesShader
	mesh.material_override=material
	viewport.add_child(mesh)
	var zeros: Array[int] = []
	var last_centers: PackedFloat32Array
	for phase: float in [.4,.8]:
		mesh.set_instance_shader_parameter("swim_phase",phase)
		for frame: int in range(4): await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		last_centers=ribbon_centers(image)
		var nearest: float = INF
		var zero: int = -1
		for x: int in range(50,380):
			var distance: float = absf(last_centers[x]-119.5)
			if distance<nearest: nearest=distance; zero=x
		zeros.append(zero)
		check("production body wave crosses rest plane %.1f" % phase,nearest<1.)
		check("save production wave probe %.1f" % phase,image.save_png(directory.path_join("fish-wave-%.1f.png" % phase))==OK)
	check("actual GPU wave travels toward model tail -X",zeros[0]-zeros[1]>70)
	comparisons.gpu_zero_x_px=zeros
	# Instrument the unchanged production vertex program to read its normal.
	# Compare with the tangent measured from rendered positions, not another
	# implementation of the analytic derivative.
	var code: String = SpeciesShader.code
	code=code.replace("render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;","render_mode cull_disabled, unshaded, fog_disabled;\nvarying vec3 probe_normal;")
	code=code.split("void fragment(){")[0]
	var end: int = code.rfind("}")
	code=code.substr(0,end)+"probe_normal=NORMAL;\n}\nvoid fragment(){ALBEDO=probe_normal*0.5+0.5;}"
	var diagnostic: Shader = Shader.new()
	diagnostic.code=code
	material.shader=diagnostic
	for frame: int in range(4): await RenderingServer.frame_post_draw
	var normal_image: Image = viewport.get_texture().get_image()
	var maximum_dot: float = 0.
	for x: int in [100,180,260]:
		var color: Color = normal_image.get_pixel(x,roundi(last_centers[x])).srgb_to_linear()
		var normal: Vector3 = (Vector3(color.r,color.g,color.b)*2.-Vector3.ONE).normalized()
		var slope: float = (last_centers[x+8]-last_centers[x-8])/16.
		maximum_dot=maxf(maximum_dot,absf(normal.dot(Vector3(1,0,slope).normalized())))
	comparisons.normal_tangent_max_abs_dot=maximum_dot
	check("GPU normals perpendicular to measured deformed surface",maximum_dot<.045)
	check("save normal diagnostic",normal_image.save_png(directory.path_join("fish-normal-probe.png"))==OK)
	viewport.queue_free()
	await get_tree().process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world127-check="): directory=argument.trim_prefix("--world127-check=")
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
	await probe()
	await at_time(3.)
	var stage: Node = main.coordinator.active_scene
	var positions: Array[Vector3] = []
	var phases: Array[float] = []
	var representatives: Array[Dictionary] = []
	for actor: Dictionary in stage.get_meta("marine_actors"):
		if actor.kind<3 and actor.index==0: representatives.append(actor)
	main.explorer_panel.show()
	get_window().size=Vector2i(900,650)
	for actor: Dictionary in representatives:
		var root: Node3D = actor.node
		main.follow_content(int(actor.kind)+1)
		await settle()
		var mouth: MeshInstance3D = root.find_child("Mouth",true,false)
		var tail: MeshInstance3D = root.find_child("Caudal",true,false)
		check("actual mesh head is +X kind %d" % actor.kind,mouth.get_aabb().get_center().x>tail.get_aabb().get_center().x+.5)
		check("representative fish remains fully in compact view kind %d" % actor.kind,subject_visible(root))
		var body: MeshInstance3D = root.find_child("Body",true,false)
		var skin: ShaderMaterial = body.get_surface_override_material(0)
		check("production material and normal map retained kind %d" % actor.kind,skin.shader==SpeciesShader and skin.get_shader_parameter("has_normal")==true and skin.get_shader_parameter("normal_map")!=null)
		await capture("marine-fish-%d" % actor.kind)
		positions.append(root.position)
		phases.append(float(actor.meshes[0].get_instance_shader_parameter("swim_phase")))
	await settle()
	var paused: bool = true
	for i: int in range(3):
		paused=paused and representatives[i].node.position==positions[i] and float(representatives[i].meshes[0].get_instance_shader_parameter("swim_phase"))==phases[i]
	check("pause holds all three real fish and vertex phases",paused)
	await at_time(3.2)
	var advanced: bool = true
	for i: int in range(3): advanced=advanced and float(representatives[i].meshes[0].get_instance_shader_parameter("swim_phase"))>phases[i]
	check("shared world time advances all three deformation phases",advanced)
	if not await arrive("earth") or not await arrive("reef"):
		await finish()
		return
	check("return preserves existing marine population and clock",main.coordinator.active_scene.get_meta("marine_actors").size()==44 and main.world.simulation_time_s==3.2)
	await finish()
