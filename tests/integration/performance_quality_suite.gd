extends "res://tests/integration/satellite_coverage_suite.gd"
## Finite visual/resource/quality regression checks, separate from timing capture.
const QualityExperience = preload("res://tests/diagnostics/performance284_experience.gd")
const Quality = preload("res://scripts/experience/render_quality.gd")

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--performance284-output="): directory=arg.trim_prefix("--performance284-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=QualityExperience.new(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	main.set_solar_date(main.Ephemeris.DEFAULT_JD); main._reset_camera(); await settle()
	var stage: Node=main.coordinator.active_scene
	var identity: int=stage.get_instance_id()
	var clock: float=main.world.simulation_time_s
	var date: float=main.solar_jd
	var legacy: bool="--performance284-legacy-resources" in OS.get_cmdline_user_args()
	if not legacy:
		if stage.scale_id=="city": check("city excludes woodland-only assets",stage.assets.size()==20 and not stage.assets.has("deer"))
		if stage.scale_id=="woodland": check("woodland excludes city-only assets",stage.assets.size()==24 and not stage.assets.has("human_short"))
		if stage.scale_id in ["universe","galaxy"]: check("deep space excludes unused planetary maps",stage.textures.is_empty())
		if stage.scale_id in ["earth","atmosphere"]: check("Earth loads exactly its two maps",stage.textures.size()==2)
	check("balanced preserves current preview resolution",is_equal_approx(Quality.effective_scale(Vector2i(2560,1600),.75),.75))
	check("4K pixel budget stays bounded",Quality.effective_scale(Vector2i(3840,2160),.75)<.53)
	check("economy 4K pixel budget stays bounded",Quality.effective_scale(Vector2i(3840,2160),.5)<.36)
	if stage.scale_id in ["city","woodland"]:
		stage.builder.set_daylight(stage,date,false)
		var daylight: Transform3D=stage.get_meta("daylight_sun").transform
		stage.builder.set_daylight(stage,date+1.0,false)
		check("authored day stays identical across dates",stage.get_meta("daylight_sun").transform==daylight)
		stage.builder.set_daylight(stage,date+.25,true)
		check("date-driven light still responds",not stage.get_meta("daylight_sun").transform.is_equal_approx(daylight))
		stage.builder.set_daylight(stage,date,false)
	main._set_render_quality(.75); await settle(); await capture("balanced")
	if stage.scale_id=="galaxy":
		var pass_node: Node=stage.get_meta("galaxy_render_pass")
		check("dust shares the same world and authoritative camera",pass_node.viewport.find_world_3d()==stage.viewport.find_world_3d() and pass_node.camera.global_transform.is_equal_approx(stage.camera.global_transform))
		var volume: MeshInstance3D=stage.world_root.get_node("GalacticArmsAndDust_Illustration")
		volume.layers=1; stage.camera.get_node("GalacticDustComposite").hide()
		pass_node.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		await capture("volume-full-reference")
		volume.layers=pass_node.CLOUD_LAYER; stage.camera.get_node("GalacticDustComposite").show()
		pass_node.viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
		stage.set_pose(Vector3(0,2,28),Vector3.ZERO); await settle(); await capture("oblique")
		check("dust camera follows orbit immediately",pass_node.camera.global_transform.is_equal_approx(stage.camera.global_transform))
		main._reset_camera(); await settle()
	main.immersive_interface._menu_action(13); await settle()
	check("economy menu applies FSR with 4x MSAA retained",stage.viewport.scaling_3d_mode==Viewport.SCALING_3D_MODE_FSR and stage.viewport.msaa_3d==Viewport.MSAA_4X and main._render_ratio==.5)
	await capture("economy")
	main.immersive_interface._menu_action(8); await settle()
	check("clear menu restores native 3D",stage.viewport.scaling_3d_scale==1.0)
	main.immersive_interface._menu_action(12); await settle()
	check("quality changes preserve scene, date and shared world time",stage.get_instance_id()==identity and main.world.simulation_time_s==clock and main.solar_jd==date)
	check("quality never reduces model count or stops motion clock",stage.viewport.msaa_3d==Viewport.MSAA_4X and main._render_ratio==.75)
	measurements.append({"scale":stage.scale_id,"asset_keys":stage.assets.keys(),"texture_keys":stage.textures.keys(),"nodes":stage.world_root.get_child_count(),"legacy_resources":legacy,"world_time":clock,"date":date})
	if "--performance284-navigation" in OS.get_cmdline_user_args():
		var world_id: int=main.world.get_instance_id()
		for destination: String in ["solar_system","earth","earth_moon","galaxy"]:
			main.navigate_to(destination)
			if not await ready_stage(): await finish(); return
			await settle()
			check("resource transition reaches "+destination,main.world.current_scale_id==destination and main.world.get_instance_id()==world_id and main.solar_jd==date)
		check("only the current stage survives transitions",main.scene_host.get_child_count()==1)
	check("no save writes and bounded worker count",not main._persistence_enabled and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()
