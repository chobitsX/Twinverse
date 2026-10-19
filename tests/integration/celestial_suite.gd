extends "res://tests/integration/world_expansion_suite.gd"
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world85-check="): directory = argument.trim_prefix("--world85-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if not await ready_stage():
		await finish()
		return
	if DisplayServer.get_name()!="headless":
		var stable_since: int = Time.get_ticks_msec()
		var limit: int = stable_since+10000
		while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<limit:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since = Time.get_ticks_msec()
	main._reduced_motion = true
	main.world.set_paused(true)
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	if not await arrive("earth_moon"):
		await finish()
		return
	main.explorer_panel.show()
	await capture("earth-moon-observatory")
	var stage: Node = main.coordinator.active_scene
	var lunar: Dictionary = stage.get_meta("lunar")
	check("Earth Moon radii",absf(lunar.moon.mesh.radius/lunar.earth.mesh.radius-1737.4/6371.0084)<1e-6)
	var old: Vector3 = lunar.moon.position
	var world_start: float = main.world.simulation_time_s
	main.set_solar_date(Ephemeris.DEFAULT_JD+7)
	await get_tree().process_frame
	await get_tree().process_frame
	check("date changes lunar position",lunar.moon.position.distance_to(old)>7.0)
	check("date leaves biology time unchanged",main.world.simulation_time_s==world_start)
	main.set_solar_distance(true)
	await get_tree().process_frame
	await get_tree().process_frame
	check("true lunar distance",absf(lunar.moon.position.length()-Orientation.moon_position_km(main.solar_jd).length()/6371.0084)<0.001)
	await capture("earth-moon-true-distance")
	main.set_solar_distance(false)
	main.explorer_panel.hide()
	main.follow_content(1)
	await capture("earth-axis-close")
	main.follow_content(2)
	await capture("moon-close")
	main.set_solar_rate(1.0/24.0)
	main.world.set_paused(false)
	var wait_until: int = Time.get_ticks_msec()+1200
	var jd_before: float = main.solar_jd
	while Time.get_ticks_msec()<wait_until: await get_tree().process_frame
	main.world.set_paused(true)
	check("hour per world second motion",main.solar_jd>jd_before and main.solar_jd-jd_before<0.2)
	main.set_solar_rate(0.0)
	main._remember_view()
	check("observer saves from lunar branch",main._views.earth_moon.astronomy.rate==0.0)
	main._navigate_relative(-1)
	if not await ready_stage():
		await finish()
		return
	check("Moon branch returns to Earth",main.world.current_scale_id=="earth")
	main.explorer_panel.show()
	await capture("earth-daylight")
	if not await arrive("city"):
		await finish()
		return
	main.ground_light_preview = true
	main.set_solar_date(2461212.5+4.0/24.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var city: Node = main.coordinator.active_scene
	check("city midday sun",float(city.get_meta("sun_elevation"))>70.0)
	await capture("city-noon")
	main.set_solar_date(main.solar_jd+0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	check("city night and lights",float(city.get_meta("sun_elevation"))< -25.0 and city.get_meta("night_lamps")[0].light.light_energy>2.0)
	await capture("city-night")
	main._remember_view()
	check("ground observation persistence",main._views.city.astronomy.ground_light)
	if not await arrive("solar_system"):
		await finish()
		return
	main.explorer_panel.show()
	main.follow_planet(6)
	await capture("uranus-spin-axis")
	var bodies: Array = main.coordinator.active_scene.get_meta("solar_bodies")
	check("rendered Uranus pole",bodies[6].node.basis.orthonormalized().y.dot(Orientation.body_basis(6,main.solar_jd).y)>0.9999)
	await finish()
