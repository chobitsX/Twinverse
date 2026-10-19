extends "res://tests/integration/galactic_suite.gd"
const Habitat=preload("res://scripts/experience/woodland_environment.gd")
const Seasons=preload("res://scripts/experience/season_observation.gd")

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world145-check="): directory=arg.trim_prefix("--world145-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,800);root.unfocusable=true
	main=Experience.instantiate();root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("woodland"): finish_river();return
	main.world.set_paused(true);main._reduced_motion=true;main.ground_light_preview=false
	main.world_guide.hide();main.explorer_panel.hide();main._reset_camera();await frames()
	var authority: RefCounted=main.world
	var time: float=main.world.simulation_time_s
	var stage: Node=main.coordinator.active_scene
	var river: MeshInstance3D=stage.world_root.get_node("MeanderingRiver")
	var arrays: Array=river.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var depths: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
	var min_depth: float=INF;var max_depth: float=0.;var aligned: bool=true
	for i: int in range(vertices.size()):
		min_depth=minf(min_depth,depths[i].x);max_depth=maxf(max_depth,depths[i].x)
		aligned=aligned and absf(vertices[i].y-Habitat.WATER_Y)<.0001
	check("existing water elevation retained with both shallows and channel samples",aligned and min_depth==0. and max_depth>.65 and vertices.size()==4097)
	check("water stays an opaque single surface without extra reflection viewport",river.material_override is ShaderMaterial and not stage.world_root.has_node("RiverReflectionViewport"))
	check("existing landscape content and reference individuals remain present",stage.get_meta("woodland_layout").trees==135 and stage.get_meta("actors").size()==20 and stage.get_meta("milkweed_plants").size()==6 and stage.has_meta("monarch_larva"))
	check("haze no longer replaces the sky while terrain still has distance fog",stage.environment.fog_enabled and stage.environment.fog_density>0. and stage.environment.fog_sky_affect<.25)
	await capture("woodland-overview")
	stage.set_pose(Vector3(5,4,12),Vector3(-16,.3,-23))
	main._orbit_target=Vector3(-16,.3,-23);await frames()
	await capture("river-and-bank")
	var water: ShaderMaterial=river.material_override
	var before: float=water.get_shader_parameter("world_time")
	await frames()
	check("water ripples pause with the same authoritative world time",is_equal_approx(before,water.get_shader_parameter("world_time")) and main.world.simulation_time_s==time)
	main.explorer_panel.show();await frames()
	main.explorer_panel.select_topic("bullfrog");await frames()
	check("existing riverbank observation remains selectable",main.learning_overlay.topic=="bullfrog" and main._content_follow>=0)
	await capture("riverbank-frog")
	main.explorer_panel.hide();main._reset_camera()
	main.set_solar_rate(0.);main.ground_light_preview=true
	main.set_solar_date(Seasons.noon(main.solar_jd,-75.)+.5);await frames()
	var sun: DirectionalLight3D=stage.get_meta("daylight_sun")
	check("date-driven night keeps the sun below horizon and direct light off",float(stage.get_meta("sun_elevation"))<0. and sun.light_energy==0.)
	await capture("woodland-night")
	main.ground_light_preview=false
	var layout: Dictionary=stage.get_meta("woodland_layout").duplicate(true)
	main.observe_scale("earth");if not await ready_scale("earth"):finish_river();return
	main.observe_scale("woodland");if not await ready_scale("woodland"):finish_river();return
	stage=main.coordinator.active_scene
	check("return preserves the same woodland layout authority and time",stage.get_meta("woodland_layout")==layout and main.world==authority and main.world.simulation_time_s==time)
	check("native diagnostic stays within background frame cap",not native or Engine.max_fps==5)
	finish_river()

func finish_river() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"native":native,"debug_build":OS.is_debug_build(),"performance_test":false},"\t")+"\n")
	print("WOODLAND_RIVER_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
