extends "res://tests/integration/satellite_coverage_suite.gd"
## Bounded panorama framing, same-clock motion and navigation checks.
const ProbeExperience = preload("res://tests/diagnostics/ecology269_experience.gd")

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cosmic285-output="): directory=arg.trim_prefix("--cosmic285-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(75.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=ProbeExperience.new(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if not await ready_stage(): await finish(); return
	main.world_guide.hide(); main.explorer_panel.hide(); main.info_panel.hide()
	main._reset_camera(); await settle()
	var stage: Node=main.coordinator.active_scene
	var world_id: int=main.world.get_instance_id()
	var data: Dictionary=stage.get_meta("cosmic_panorama")
	await capture("default")
	for step: int in range(8): main._zoom_camera(stage,2.0)
	await settle(); await capture("widest")
	var wide_position: Vector3=stage.camera.position
	check("zoom reaches the actual outer bound",is_equal_approx(wide_position.length(),float(stage.get_meta("orbit_max_distance",stage.default_position.length()*5.0))))
	measurements.append({"wide_distance":wide_position.length(),"default_distance":stage.default_position.length(),"points":data.get("point_count",0),"mist":data.get("mist_count",0),"main_draws":stage.viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)})
	if "--cosmic285-baseline" in OS.get_cmdline_user_args(): await finish(); return
	check("outer structure surrounds the most distant observer",float(data.extent)>wide_position.length()*.6)
	check("far galaxies use a bounded batch",data.galaxy_batch.multimesh.instance_count<=600 and data.point_count<=70000 and data.mist_count<8000)
	check("universe loads no planetary maps",stage.textures.is_empty())
	stage.set_pose(Vector3(-1,.28,.18).normalized()*wide_position.length(),Vector3.ZERO); await settle(); await capture("wide-side")
	main._set_render_quality(.5); await settle(); await capture("economy-wide")
	main._set_render_quality(.75); main._reset_camera(); await settle()
	var factor: float=float(data.factor)
	var start_time: float=main.world.simulation_time_s
	main.world.set_paused(false)
	var deadline: int=Time.get_ticks_msec()+6500
	while main.world.simulation_time_s-start_time<1.0 and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	main.world.set_paused(true); await settle()
	check("all layers expand from the same live World",main.world.simulation_time_s>start_time+.5 and float(data.factor)>factor and is_equal_approx(float(data.galaxy_material.get_shader_parameter("expansion_factor")),float(data.factor)))
	check("expansion preserves galaxy size and reference anchor",data.galaxies[1].node.scale==Vector3.ONE and data.galaxies[0].node.position==Vector3.ZERO)
	var held: float=float(data.factor)
	var pixels: PackedByteArray=get_viewport().get_texture().get_image().get_data()
	await settle()
	check("pause holds both world and rendered structure",float(data.factor)==held and pixels==get_viewport().get_texture().get_image().get_data())
	main.immersive_interface._menu_action(11); await settle()
	check("replay only resets illustrative spacing",is_equal_approx(float(data.factor),1.0) and main.world.simulation_time_s>start_time+.5 and main.world.get_instance_id()==world_id)
	var point: Vector2=stage.camera.unproject_position(Vector3.ZERO)
	var picked: Dictionary=main.object_pointer.pick(point)
	check("central Milky Way remains a 3D entry",picked.get("destination","")=="galaxy")
	main.enter_spatial_choice(picked)
	if not await ready_stage(): await finish(); return
	check("galaxy entry shares the same World",main.world.current_scale_id=="galaxy" and main.world.get_instance_id()==world_id)
	main._navigate_relative(-1)
	if not await ready_stage(): await finish(); return
	check("return restores universe without extra stages",main.world.current_scale_id=="universe" and main.scene_host.get_child_count()==1)
	check("scientific illustration remains explicit",main.ScienceReference.describe("universe").sources.size()==2 and main.immersive_interface.source_button.text.contains("示意"))
	check("no save and bounded work budget",not main._persistence_enabled and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()
