extends "res://tests/integration/world_expansion_suite.gd"
## A bounded real-window flow; the camera never owns astronomical state.
var observations: Dictionary = {}
var view_settings: Array[Dictionary] = []
var samples: Array[Dictionary] = []

func settle() -> void:
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen==DisplayServer.get_primary_screen(): continue
		if get_window().current_screen!=screen:
			var original_size: Vector2i=get_window().size
			get_window().current_screen=screen
			get_window().position=DisplayServer.screen_get_usable_rect(screen).position+Vector2i(30,30)
			get_window().size=original_size
		main._measurement_screen=screen
		break
	for frame: int in range(4): await get_tree().process_frame

func capture(label: String) -> void:
	await settle()
	view_settings.append({"view":label,"screen_count":DisplayServer.get_screen_count(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"window_size":[get_window().size.x,get_window().size.y]})
	await super.capture(label)

func core_checkpoint() -> Dictionary:
	var value: Dictionary=main.world.checkpoint()
	value.erase("current_scale_id"); value.erase("local_habitat")
	return value

func body_positions() -> Array[Vector3]:
	var values: Array[Vector3]=[]
	for body: Dictionary in main.coordinator.active_scene.get_meta("solar_bodies"): values.append(body.node.position)
	return values

func body_ids() -> Array[int]:
	var values: Array[int]=[]
	for body: Dictionary in main.coordinator.active_scene.get_meta("solar_bodies"): values.append(body.node.get_instance_id())
	return values

func mesh_sha(node: MeshInstance3D) -> String:
	var vertices: PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return vertices.to_byte_array().hex_encode().sha256_text()

func orbit_hashes() -> Array[String]:
	var values: Array[String]=[]
	for body: Dictionary in main.coordinator.active_scene.get_meta("solar_bodies"): values.append(mesh_sha(body.orbit))
	return values

func positions_match_date() -> bool:
	var correct: bool=true
	var points: Array[Vector3]=body_positions()
	for index: int in range(8): correct=correct and points[index].distance_to(Ephemeris.display_position(index,main.solar_jd,main.solar_true_distance))<.00001
	return correct

func controls_fit() -> bool:
	var panel: Node=main.explorer_panel
	var clip: Rect2=panel.scroll.get_global_rect()
	var clear: bool=true
	var controls: Array[Control]=[panel.body_picker,panel.solar_top_button,panel.solar_side_button,panel.solar_plane_hint]
	if panel.orbit_view_button.visible: controls.append(panel.orbit_view_button)
	for control: Control in controls:
		clear=clear and control.is_visible_in_tree() and clip.grow(.5).encloses(control.get_global_rect())
	return clear

func sample_view(label: String) -> Rect2:
	var stage: Node=main.coordinator.active_scene
	var camera: Camera3D=stage.camera
	var bounds: Rect2
	var count: int=0
	var clear: bool=true
	var left: float=main.explorer_panel.get_global_rect().end.x+8.0 if main.explorer_panel.visible else 24.0
	for index: int in range(8):
		if main.solar_orbit_focus>=0 and index!=main.solar_orbit_focus: continue
		var orbit: MeshInstance3D=stage.get_meta("solar_bodies")[index].orbit
		var vertices: PackedVector3Array=orbit.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var actual: Vector3=orbit.to_global(vertex)
			var point: Vector2=camera.unproject_position(actual)
			bounds=Rect2(point,Vector2.ZERO) if count==0 else bounds.expand(point)
			count+=1
			clear=clear and not camera.is_position_behind(actual) and point.x>left and point.x<get_window().size.x-22 and point.y>112 and point.y<get_window().size.y-104
	check(label+" actual orbit geometry fits beside the panel and HUD",clear and count>0)
	samples.append({"view":label,"focus":main.solar_orbit_focus,"plane":main.solar_plane_view,"jd":main.solar_jd,"true_distance":main.solar_true_distance,"vertices":count,"bounds_px":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"clear":clear,"camera_position":[camera.position.x,camera.position.y,camera.position.z],"camera_up":[camera.basis.y.x,camera.basis.y.y,camera.basis.y.z]})
	return bounds

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world234-review="): directory=argument.trim_prefix("--world234-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size=Vector2i(1280,800)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	check("diagnostic cannot consume desktop focus or input",get_window().unfocusable and get_viewport().gui_disable_input)
	get_tree().create_timer(110.0).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	if not await ready_stage(): await finish(); return
	get_window().size=Vector2i(1280,800)
	main._audio.volume_db=-80.0
	main._reduced_motion=true
	main.world.set_paused(true); main.world.set_time_scale(2.0)
	main.set_solar_rate(1.0)
	main.world_guide.hide()
	main.world.simulation_time_s=12.0
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	await settle()
	var authority: int=main.world.get_instance_id()
	var baseline: Dictionary=core_checkpoint()
	if not await arrive("solar_system"): await finish(); return
	main.explorer_panel.show()
	await settle()
	var panel: Node=main.explorer_panel
	var stage: Node=main.coordinator.active_scene
	var original: Array[Vector3]=body_positions()
	var identities: Array[int]=body_ids()
	var original_orbits: Array[String]=orbit_hashes()
	check("real solar observation controls are available",panel.solar_top_button.is_visible_in_tree() and panel.solar_side_button.is_visible_in_tree())
	check("primary camera controls and frame note fit the actual scroll viewport",controls_fit())
	panel.solar_top_button.pressed.emit()
	await settle()
	check("overview top uses the shared ecliptic normal without selecting a planet",stage.camera.basis.z.dot(Vector3.UP)>.99999 and main.solar_plane_view=="top" and main.solar_orbit_focus==-1)
	check("top view preserves actual positions orbit vertices and identities",body_positions()==original and orbit_hashes()==original_orbits and body_ids()==identities)
	sample_view("top overview")
	await capture("plane-top-overview")
	panel.solar_side_button.pressed.emit()
	await settle()
	check("overview side uses the fixed ecliptic x direction",stage.camera.basis.z.dot(Vector3.RIGHT)>.99999 and stage.camera.basis.y.dot(Vector3.UP)>.99999 and main.solar_plane_view=="side")
	check("side explanation distinguishes projection from inclination",panel.solar_plane_hint.text.contains("J2000黄道") and panel.solar_plane_hint.text.contains("斜率不等于倾角"))
	check("side view changes no actual orbit or time",body_positions()==original and orbit_hashes()==original_orbits and main.solar_jd==Ephemeris.DEFAULT_JD and main.solar_rate==1.0 and core_checkpoint()==baseline)
	sample_view("side overview")
	await capture("plane-side-overview")
	panel.body_picker.item_selected.emit(1)
	await settle()
	check("original picker still selects Mercury close view",main.solar_follow==0 and main.solar_plane_view.is_empty())
	var selected_orbits: Array[String]=orbit_hashes()
	var trajectory: MeshInstance3D=stage.world_root.get_node("SelectedDE440Trajectory") as MeshInstance3D
	var trajectory_sha: String=mesh_sha(trajectory)
	panel.solar_side_button.pressed.emit()
	await settle()
	check("selected Mercury shares the same ecliptic side direction",main.solar_orbit_focus==0 and main.solar_follow==-1 and stage.camera.basis.z.dot(Vector3.RIGHT)>.99999)
	check("selected view keeps DE440 and teaching vertices unchanged",mesh_sha(trajectory)==trajectory_sha and orbit_hashes()==selected_orbits and body_positions()==original and body_ids()==identities)
	var side_bounds: Rect2=sample_view("Mercury side")
	check("unexaggerated Mercury side has observable vertical extent",side_bounds.size.y>5.0)
	await capture("plane-mercury-side")
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact resize retains selection and the same ecliptic direction",main.solar_plane_view=="side" and main.solar_orbit_focus==0 and stage.camera.basis.z.dot(Vector3.RIGHT)>.99999)
	check("compact selected view keeps picker cameras return and frame note above the fold",controls_fit())
	panel.solar_toggle.pressed.emit()
	await settle()
	check("folding astronomy parameters keeps the primary cameras usable",not panel.solar.visible and controls_fit() and main.solar_plane_view=="side" and body_positions()==original)
	panel.solar_toggle.pressed.emit()
	await settle()
	sample_view("compact Mercury side")
	await capture("plane-mercury-compact")
	panel.solar_top_button.pressed.emit()
	await settle()
	check("Mercury top uses the common normal rather than its inclined orbit normal",stage.camera.basis.z.dot(Vector3.UP)>.99999 and main.solar_orbit_focus==0)
	sample_view("compact Mercury top")
	await capture("plane-mercury-top")
	var before_zoom: Transform3D=stage.camera.transform
	var wheel: InputEventMouseButton=InputEventMouseButton.new()
	wheel.pressed=true; wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	main._unhandled_input(wheel)
	await settle()
	check("top wheel zoom preserves orientation and astronomical positions",stage.camera.basis.is_equal_approx(before_zoom.basis) and stage.camera.position.length()<before_zoom.origin.length() and body_positions()==original)
	var drag: InputEventMouseMotion=InputEventMouseMotion.new()
	drag.button_mask=MOUSE_BUTTON_MASK_RIGHT; drag.relative=Vector2(12,-8)
	main._unhandled_input(drag)
	await settle()
	check("top drag freely rotates without a polar roll jump or moving planets",stage.camera.basis.z.dot(Vector3.UP)<.9999 and main._orbit_target.is_zero_approx() and body_positions()==original)
	main._reset_observation_view()
	await settle()
	check("reset returns the current top preset with the same selected object",stage.camera.basis.z.dot(Vector3.UP)>.99999 and main.solar_plane_view=="top" and main.solar_orbit_focus==0)
	panel.orbit_view_button.pressed.emit()
	await settle()
	check("real orbit control restores the original selected-orbit front view",main.solar_plane_view.is_empty() and main.solar_orbit_focus==0 and panel.orbit_view_button.text=="返回行星近看" and mesh_sha(trajectory)==trajectory_sha)
	panel.orbit_view_button.pressed.emit()
	await settle()
	check("original orbit control returns to the same planet close view",main.solar_follow==0 and main.solar_orbit_focus==-1 and main.solar_plane_view.is_empty() and body_ids()==identities)
	panel.solar_side_button.pressed.emit()
	await settle()
	var fixed_pose: Transform3D=stage.camera.transform
	main.set_solar_date(Ephemeris.DEFAULT_JD+1.0)
	await settle()
	check("explicit date advances the original ephemeris in the fixed side camera",positions_match_date() and body_positions()!=original and stage.camera.transform.is_equal_approx(fixed_pose) and main.solar_plane_view=="side" and main.solar_rate==1.0 and main.world.simulation_time_s==12.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	get_window().size=Vector2i(1280,800)
	await settle()
	panel.body_picker.item_selected.emit(6)
	await settle()
	panel.solar_side_button.pressed.emit()
	await settle()
	panel.mode.set_pressed_no_signal(true); panel.mode.toggled.emit(true)
	await settle()
	check("distance control retains Saturn side with the existing common AU scale",main.solar_true_distance and main.solar_plane_view=="side" and main.solar_orbit_focus==5 and stage.camera.basis.z.dot(Vector3.RIGHT)>.99999 and positions_match_date())
	sample_view("true-distance Saturn side")
	await capture("plane-saturn-side-true")
	panel.orbit_view_button.pressed.emit()
	await settle()
	sample_view("true-distance Saturn front")
	await capture("plane-saturn-front")
	panel.mode.set_pressed_no_signal(false); panel.mode.toggled.emit(false)
	await settle()
	panel.body_picker.item_selected.emit(0)
	await settle()
	panel.solar_top_button.pressed.emit()
	await settle()
	var saved_pose: Transform3D=stage.camera.transform
	main._remember_view()
	var saved: Dictionary=main._views.solar_system
	check("camera save uses the existing position target up schema",main.WorldStore.vector(saved.position).is_equal_approx(stage.camera.position) and main.WorldStore.vector(saved.target).is_zero_approx() and main.WorldStore.vector(saved.up).is_equal_approx(stage.camera.basis.y) and not saved.has("solar_plane_view"))
	main._reset_camera()
	main._apply_saved_view(stage)
	await settle()
	check("original pose restore preserves the top camera without new session fields",stage.camera.transform.is_equal_approx(saved_pose) and main.solar_plane_view.is_empty() and main.solar_orbit_focus==-1)
	check("return to overview restores all original positions and orbit vertices",body_positions()==original and orbit_hashes()==original_orbits and body_ids()==identities)
	if not await arrive("earth"): await finish(); return
	await settle()
	check("Earth clears temporary solar selection without changing date or authority",main.solar_plane_view.is_empty() and main.solar_follow==-1 and main.solar_orbit_focus==-1 and main.solar_jd==Ephemeris.DEFAULT_JD and main.world.get_instance_id()==authority)
	if not await arrive("solar_system"): await finish(); return
	await settle()
	check("solar reentry keeps the original world and ephemeris",positions_match_date() and body_positions()==original and orbit_hashes()==original_orbits and core_checkpoint()==baseline and main.world.get_instance_id()==authority and main.world.paused and main.world.time_scale==2.0 and main.world.simulation_time_s==12.0 and main.solar_rate==1.0)
	check("resource settings remain two workers and the actual five FPS background cap",int(ProjectSettings.get_setting("threading/worker_pool/max_threads"))==2 and Engine.max_fps==5 and int(ProjectSettings.get_setting("application/run/max_fps"))==30 and main._render_ratio==.75)
	observations={"world_instance":authority,"world_time_s":main.world.simulation_time_s,"paused":main.world.paused,"time_scale":main.world.time_scale,"jd":main.solar_jd,"solar_rate":main.solar_rate,"samples":samples,"capture_window_settings":view_settings,"original_orbit_sha256":original_orbits,"selected_trajectory_sha256":trajectory_sha,"core_checkpoint_unchanged":core_checkpoint()==baseline,"projection_inclination_exaggerated":false,"new_save_fields":false,"native_input_tested":false,"unfocusable":get_window().unfocusable,"native_input_disabled":get_viewport().gui_disable_input,"audio_volume_db":main._audio.volume_db,"max_fps":Engine.max_fps,"foreground_fps":ProjectSettings.get_setting("application/run/max_fps"),"worker_pool_threads":ProjectSettings.get_setting("threading/worker_pool/max_threads"),"render_ratio":main._render_ratio}
	await finish()

func finish() -> void:
	var output: FileAccess=FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"native_input_tested":false,"native_ime_tested":false,"performance_test":false},"\t")+"\n")
	output.close()
	print("SOLAR_ORBIT_VIEWS234_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
