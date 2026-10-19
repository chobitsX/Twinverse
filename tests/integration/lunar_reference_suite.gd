extends "res://tests/integration/ecology_map_suite.gd"
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Phase = preload("res://scripts/core/lunar_phase.gd")
const Store = preload("res://scripts/core/world_store.gd")
const Compare = preload("res://tests/core/test_ecophysiology.gd")
var mode: String=""
var save_directory: String=""
var light_samples: Array[Dictionary]=[]
func frames() -> void:
	for frame: int in range(6):
		await get_tree().process_frame
		if native: RenderingServer.force_draw(false,0.0)
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world139-check="): directory=argument.trim_prefix("--world139-check=")
		if argument.begins_with("--lunar-mode="): mode=argument.trim_prefix("--lunar-mode=")
		if argument.begins_with("--world-dir="): save_directory=argument.trim_prefix("--world-dir=")
	if not directory.is_absolute_path() or not save_directory.is_absolute_path() or mode not in ["write","resume"] or save_directory==ProjectSettings.globalize_path("user://world"):
		get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,800)
	if native: root.unfocusable=true
	main=Experience.instantiate();root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("earth_moon"): finish_lunar();return
	main.world.set_paused(true);main._reduced_motion=true;main.world_guide.hide()
	if mode=="resume": await resume_check();return
	main._open_guide()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="lunar_phases":action=button
	check("same lunar route remains among 41 topics",action!=null and main.world_guide.route_buttons.size()==41)
	if action==null:finish_lunar();return
	action.pressed.emit();await frames()
	var panel: Node=main.explorer_panel
	var stage: Node=main.coordinator.active_scene
	var data: Dictionary=stage.get_meta("lunar")
	var world_before: Dictionary=main.world.checkpoint()
	main.set_solar_date(main.Ephemeris.DEFAULT_JD)
	panel.lunar_earth_button.pressed.emit();await frames()
	check("actual lunar mesh uses independent series and IAU attitude",geometry_matches())
	check("Earth camera follows Earth bearing instead of prime meridian",earth_aligned() and stage.camera.basis.z.dot(data.moon.basis.z)<.9999)
	var before_basis: Basis=data.moon.basis
	var before_date: float=main.solar_jd
	var before_marker: Vector2=stage.camera.unproject_position(data.moon.position+data.moon.basis.z*.274)
	panel.lunar_day_button.pressed.emit();await frames()
	check("one-day control changes observer date without advancing ecology",main.solar_jd==before_date+1. and main.solar_rate==0. and main.world.checkpoint()==world_before and geometry_matches())
	check("lunar orientation moves while close view keeps Earth direction",not data.moon.basis.is_equal_approx(before_basis) and earth_aligned() and stage.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
	for day: int in range(6):panel.lunar_day_button.pressed.emit()
	await frames()
	var after_marker: Vector2=stage.camera.unproject_position(data.moon.position+data.moon.basis.z*.274)
	check("same fixed surface reference visibly shifts under libration",before_marker.distance_to(after_marker)>3. and panel.lesson_readout.text.contains("地心月面经/纬度"))
	await capture("lunar-libration")
	var quarter_values: Array[float]=[]
	for quarter: int in [0,1,2,3]:
		main.set_solar_date(main.Ephemeris.DEFAULT_JD)
		panel.lunar_phase_buttons[quarter].pressed.emit();await frames()
		check("phase control uses upgraded geometry "+str(quarter),absf(wrapf(Phase.cycle(main.solar_jd)-quarter*.25,-.5,.5))<.000001 and earth_aligned() and geometry_matches())
		if native:
			var sample: Dictionary=light_sample();light_samples.append(sample);quarter_values.append(sample.lit_fraction)
		if quarter==1:await capture("lunar-first-quarter")
		if quarter==2:await capture("lunar-full")
	if native:check("rendered phase illumination remains consistent",quarter_values[0]<.04 and absf(quarter_values[1]-.5)<.07 and quarter_values[2]>.95 and absf(quarter_values[3]-.5)<.07)
	var frozen: Transform3D=data.moon.transform
	await frames()
	check("paused date freezes real surface and position",data.moon.transform.is_equal_approx(frozen) and main.world.checkpoint()==world_before)
	panel.lunar_orbit_button.pressed.emit();await frames()
	var points: PackedVector3Array=data.orbit.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check("visible trajectory samples the same time-dependent lunar positions",points.size()==257 and points[128].distance_to(stage.builder.moon_display_position(float(data.orbit_epoch),false))<.00001)
	var length: float=data.moon.position.length()
	main.set_solar_distance(true);await frames()
	check("true distance restores physical Earth radius scale",absf(data.moon.position.length()*main.Ephemeris.RADII_KM[2]-Orientation.moon_position_km(main.solar_jd).length())<.1 and data.moon.position.length()>length*7.)
	main.set_solar_distance(false);await frames()
	await capture("lunar-date-trajectory")
	root.size=Vector2i(900,650);panel.lunar_earth_button.pressed.emit();await frames()
	panel.scroll.ensure_control_visible(panel.lunar_day_button);await frames()
	check("compact view exposes one-day control without losing Moon",panel.scroll.get_global_rect().encloses(panel.lunar_day_button.get_global_rect()) and earth_aligned())
	await capture("lunar-compact")
	var saved_date: float=main.solar_jd
	if not await visit("earth") or not await visit("earth_moon","lunar_phases"):finish_lunar();return
	check("scene return retains observer date and world authority",main.solar_jd==saved_date and main.world.simulation_time_s==world_before.simulation_time_s and geometry_matches())
	main.save_button.pressed.emit()
	var loaded: Dictionary=Store.new(save_directory).load_session()
	check("existing v12 save persists date without inventing a lunar clock",loaded.status=="ok" and loaded.payload.world.version==12 and loaded.payload.observer.views.earth_moon.astronomy.jd==saved_date)
	FileAccess.open(save_directory.path_join("lunar-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"jd":saved_date,"world":main.world.checkpoint()},"\t",true,true))
	finish_lunar()
func visit(id: String, topic: String="") -> bool:
	if not await ready_scale(main.world.current_scale_id):return false
	main.start_guide_visit(id,topic)
	if not await ready_scale(id):return false
	await frames();return true
func geometry_matches() -> bool:
	var stage: Node=main.coordinator.active_scene
	var moon: Node3D=stage.get_meta("lunar").moon
	return moon.position.distance_to(stage.builder.moon_display_position(main.solar_jd,main.solar_true_distance))<.00001 and moon.basis.is_equal_approx(Orientation.moon_basis(main.solar_jd))
func earth_aligned() -> bool:
	var stage: Node=main.coordinator.active_scene
	return stage.camera.basis.z.dot(-stage.get_meta("lunar").moon.position.normalized())>.99999
func light_sample() -> Dictionary:
	var stage: Node=main.coordinator.active_scene
	var moon: Node3D=stage.get_meta("lunar").moon
	var camera: Camera3D=stage.camera
	var picture: Image=stage.viewport.get_texture().get_image()
	var center: Vector2=camera.unproject_position(moon.position)
	var radius: float=camera.unproject_position(moon.position+camera.basis.x*.273).distance_to(center)*.68
	var count: int=0;var lit: int=0
	for y: int in range(maxi(0,int(center.y-radius)),mini(picture.get_height(),int(center.y+radius))):
		for x: int in range(maxi(0,int(center.x-radius)),mini(picture.get_width(),int(center.x+radius))):
			if Vector2(x,y).distance_to(center)>radius:continue
			var c: Color=picture.get_pixel(x,y)
			if .2126*c.r+.7152*c.g+.0722*c.b>.025:lit+=1
			count+=1
	return {"jd":main.solar_jd,"pixels":count,"lit_fraction":float(lit)/maxi(1,count)}
func resume_check() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(save_directory.path_join("lunar-expected.json")))
	var actual: Dictionary=main.world.checkpoint();var same: bool=true
	for key: String in expected.world:
		if key!="local_habitat":same=same and Compare.equivalent(expected.world[key],actual[key])
	check("fresh process restores observer date and all saved world models",same and main.solar_jd==expected.jd)
	main.explorer_panel.show();await frames();main.explorer_panel.select_topic("lunar_phases");await frames()
	main.explorer_panel.lunar_earth_button.pressed.emit();await frames()
	check("restored surface retains reference geometry and Earth viewing line",geometry_matches() and earth_aligned())
	main.explorer_panel.lunar_day_button.pressed.emit();await frames()
	check("continued observation advances only the shared astronomical date",main.solar_jd==float(expected.jd)+1. and main.world.simulation_time_s==expected.world.simulation_time_s and geometry_matches())
	await capture("lunar-resumed");finish_lunar()
func finish_lunar() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"light_samples":light_samples,"native":native,"debug_build":OS.is_debug_build(),"mode":mode,"performance_test":false},"\t")+"\n")
	print("LUNAR_REFERENCE_FINISHED ",mode," ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
