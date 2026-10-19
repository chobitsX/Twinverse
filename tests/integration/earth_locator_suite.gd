extends "res://tests/integration/life_assets_suite.gd"
const Sites = preload("res://scripts/data/earth_sites.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world96-check="): directory = argument.trim_prefix("--world96-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	if not await arrive("earth"):
		await finish()
		return
	main.explorer_panel.show()
	for frame: int in range(3): await get_tree().process_frame
	var stage: Node = main.coordinator.active_scene
	var panel: Node = main.explorer_panel
	var data: Dictionary = stage.get_meta("earth_locator")
	var anchor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/lizard_woa23_annual.json")).anchor
	check("region uses existing frozen boundary location",absf(Sites.REEF_LAT-float(anchor.latitude_deg))<1e-8 and absf(Sites.REEF_LON-float(anchor.longitude_deg))<1e-8)
	check("coordinate convention matches equator prime meridian and poles",Sites.normal(0,0).is_equal_approx(Vector3.BACK) and Sites.normal(0,90).is_equal_approx(Vector3.RIGHT) and Sites.normal(90,0).is_equal_approx(Vector3.UP))
	check("surface marker aligns with existing golden path anchor",data.marker.position.normalized().is_equal_approx(stage.target_position.normalized()) and data.marker.position.length()>3.0)
	panel.select_earth_site(0)
	panel.earth_focus.pressed.emit()
	for frame: int in range(3): await get_tree().process_frame
	check("regional focus preserves whole globe and visible marker",stage.camera.position.length()>9 and data.marker.visible and data.region_label.visible and not data.band.visible)
	await capture("earth-regional-reference")
	var saved_camera: Vector3 = stage.camera.position
	stage.set_pose(-saved_camera,Vector3.ZERO)
	check("label on far side is hidden",not data.region_label.visible and not data.region_label.no_depth_test)
	stage.set_pose(saved_camera,Vector3.ZERO)
	var time: float = main.world.simulation_time_s
	main.set_solar_date(main.solar_jd+.25)
	for frame: int in range(3): await get_tree().process_frame
	check("date changes light while geographic anchor stays fixed",data.marker.position.normalized().is_equal_approx(stage.target_position.normalized()) and main.world.simulation_time_s==time)
	panel.earth_enter.pressed.emit()
	if not await ready_stage():
		await finish()
		return
	check("regional entry reaches real reef branch",main.world.current_scale_id=="reef" and main.content_targets().size()==5)
	if not await arrive("earth"):
		await finish()
		return
	for id: String in ["woodland","city"]:
		stage = main.coordinator.active_scene
		data = stage.get_meta("earth_locator")
		panel.select_earth_site(1 if id=="woodland" else 2)
		panel.earth_focus.pressed.emit()
		for frame: int in range(3): await get_tree().process_frame
		check(id+" shows latitude reference without a false location pin",not data.marker.visible and data.band.visible and data.band_label.visible and panel.earth_detail.text.contains("无真实"))
		check(id+" selection does not alter date or world time",main.world.simulation_time_s==time)
		await capture("earth-"+id+"-reference")
		panel.earth_enter.pressed.emit()
		if not await ready_stage():
			await finish()
			return
		check("reference entry reaches "+id,main.world.current_scale_id==id and main.content_targets().size()>=2)
		var site: Dictionary = Sites.for_scale(id)
		check(id+" lighting coordinates preserved",site.lat==35.0 and site.lon==(-75.0 if id=="woodland" else 120.0))
		if not await arrive("earth"):
			await finish()
			return
		for frame: int in range(3): await get_tree().process_frame
		check(id+" return keeps selection within this session",main.coordinator.active_scene.get_meta("earth_locator").selection==id)
	get_window().size = Vector2i(900,650)
	for frame: int in range(4): await get_tree().process_frame
	check("compact Earth entry stays visible and in bounds",panel.earth_enter.get_global_rect().end.y<panel.get_global_rect().end.y and panel.earth_enter.get_global_rect().end.x<900 and panel.earth_box.visible)
	await capture("earth-reference-compact")
	await finish()
