extends "res://tests/integration/world_guide_search_suite.gd"
const EXPECTED_RADII: Array[float]=[2439.4,6051.8,6371.0084,3389.5,69911.,58232.,25362.,24622.,695700.]
var geometry_samples: Array[Dictionary]=[]
func ready_scale(id: String) -> bool:
	var deadline: int=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if main.coordinator!=null and main.coordinator.active_scene!=null and not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.current_scale_id==id: return true
	check("ready "+id,false)
	return false
func frames() -> void:
	for frame: int in range(5): await get_tree().process_frame
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world132-check="): directory=argument.trim_prefix("--world132-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,720)
	if native: root.unfocusable=true
	main=Experience.instantiate()
	root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("solar_system"):
		finish_size()
		return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.set_solar_rate(0.)
	main.world_guide.hide()
	main.explorer_panel.show()
	await frames()
	var stage: Node=main.coordinator.active_scene
	var camera_before: Transform3D=stage.camera.transform
	var time_before: float=main.world.simulation_time_s
	var jd_before: float=main.solar_jd
	var actual_positions: Array[Vector3]=[]
	for entry: Dictionary in stage.get_meta("solar_bodies"): actual_positions.append(entry.node.position)
	var comparison: Node=main.size_comparison
	main.explorer_panel.size_compare_button.pressed.emit()
	await frames()
	check("solar observation button opens isolated size comparison",comparison.visible and comparison.viewport.own_world_3d and comparison.picker.item_count==9)
	for index: int in range(9):
		comparison.picker.item_selected.emit(index)
		await frames()
		var a: MeshInstance3D=comparison.bodies[0]
		var b: MeshInstance3D=comparison.bodies[1]
		var ratio: float=(a.mesh.get_aabb().size.x*a.scale.x)/(b.mesh.get_aabb().size.x*b.scale.x)
		var expected: float=EXPECTED_RADII[index]/EXPECTED_RADII[2]
		var cam: Camera3D=comparison.camera
		var diameter_a: float=cam.unproject_position(a.position+Vector3.RIGHT*a.scale.x).distance_to(cam.unproject_position(a.position-Vector3.RIGHT*a.scale.x))
		var diameter_b: float=cam.unproject_position(b.position+Vector3.RIGHT*b.scale.x).distance_to(cam.unproject_position(b.position-Vector3.RIGHT*b.scale.x))
		check("actual mesh and projected diameter ratio "+str(index),absf(ratio/expected-1.)<.00001 and absf(diameter_a/diameter_b/expected-1.)<.0001 and a.position.z==b.position.z and cam.projection==Camera3D.PROJECTION_ORTHOGONAL)
		geometry_samples.append({"body":index,"expected_ratio":expected,"actual_mesh_ratio":ratio,"projected_ratio":diameter_a/diameter_b,"reference_diameter_px":diameter_b})
	comparison.picker.item_selected.emit(4)
	await frames()
	await capture("jupiter-earth-wide")
	root.size=Vector2i(900,650)
	comparison.picker.item_selected.emit(0)
	await frames()
	check("compact panel controls and viewport remain visible",comparison.panel.get_global_rect().end.y<=650 and comparison.picker.get_global_rect().end.x<=900 and comparison.viewport_container.size.y>=210 and comparison.boundary_text.get_global_rect().end.y<=650)
	await capture("mercury-earth-compact")
	comparison.picker.item_selected.emit(8)
	await frames()
	check("nominal Sun and staging boundaries visible",comparison.boundary_text.text.contains("换算常数") and comparison.boundary_text.text.contains("不代表轨道距离") and comparison.ratio_text.text.contains("109."))
	await capture("sun-earth-compact")
	var space: InputEventKey=InputEventKey.new()
	space.keycode=KEY_SPACE
	space.pressed=true
	main._input(space)
	check("comparison keyboard does not toggle world pause",main.world.paused)
	var escape: InputEventKey=InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	main._input(escape)
	await frames()
	check("Escape returns and stops comparison rendering",not comparison.visible and comparison.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not main._shutting_down)
	var unchanged: bool=main.world.simulation_time_s==time_before and main.solar_jd==jd_before and stage.camera.transform.is_equal_approx(camera_before)
	for i: int in range(8): unchanged=unchanged and stage.get_meta("solar_bodies")[i].node.position.is_equal_approx(actual_positions[i])
	check("size choices leave orbit geometry date world time and camera intact",unchanged)
	main.observe_scale("earth")
	if await ready_scale("earth"):
		main.open_size_comparison()
		check("comparison cannot open as a different scene",not comparison.visible)
	finish_size()
func finish_size() -> void:
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"geometry_samples":geometry_samples,"captures":captures,"debug_build":OS.is_debug_build(),"native":native,"performance_test":false},"\t")+"\n")
	print("SOLAR_SIZE_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
