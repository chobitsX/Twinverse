extends "res://tests/integration/life_assets_suite.gd"
## Short visible regression for the available observation area, not a performance run.

func settle() -> void:
	for frame: int in range(4): await get_tree().process_frame

func subject_visible(root: Node3D) -> bool:
	var camera: Camera3D = main.coordinator.active_scene.camera
	var meshes: Array[Node] = root.find_children("*","MeshInstance3D",true,false)
	if root is MeshInstance3D: meshes.append(root)
	var count: int = 0
	var bounds: Rect2
	var clear: bool = true
	for item: Node in meshes:
		var mesh: MeshInstance3D = item as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh==null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var world_point: Vector3 = mesh.to_global(vertex)
				var point: Vector2 = camera.unproject_position(world_point)
				bounds = Rect2(point,Vector2.ZERO) if count==0 else bounds.expand(point)
				count += 1
				clear = clear and not camera.is_position_behind(world_point) and point.x>main.explorer_panel.get_global_rect().end.x+8 and point.x<get_window().size.x-8 and point.y>80 and point.y<get_window().size.y-60
	print("OBSERVATION_BOUNDS ",root.name," ",bounds," vertices=",count)
	return count>0 and clear

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world99-check="): directory = argument.trim_prefix("--world99-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	# The no-save diagnostic stays drawable on the requested screen without
	# taking focus from another app. Ordinary launches retain their own policy.
	if DisplayServer.get_name()!="headless":
		main._measurement_screen = get_window().current_screen
		get_window().unfocusable = true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	get_window().size = Vector2i(900,650)
	if not await arrive("woodland"):
		await finish()
		return
	main.ground_light_preview = false
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	panel.object_picker.item_selected.emit(1)
	await settle()
	var stage: Node = main.coordinator.active_scene
	var subject: Node3D = main.content_targets()[0].node
	check("deer geometry beside panel in compact window",subject_visible(subject))
	await capture("woodland-observer")
	var target: Vector3 = main._orbit_target
	var before: Transform3D = stage.camera.transform
	var subject_position: Vector3 = subject.position
	var time: float = main.world.simulation_time_s
	main._toggle_explorer()
	await settle()
	check("hiding explanation recenters without moving world or orbit",stage.camera.h_offset==0 and stage.camera.transform.is_equal_approx(before) and subject.position.is_equal_approx(subject_position) and absf(stage.camera.unproject_position(target).x-450.0)<1.0)
	await capture("woodland-panel-hidden")
	main._toggle_explorer()
	await settle()
	check("showing explanation restores usable area with same orbit",stage.camera.h_offset<0 and stage.camera.transform.is_equal_approx(before))
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	drag.relative = Vector2(18,-8)
	main._unhandled_input(drag)
	await settle()
	check("orbit input keeps the subject clear and target fixed",subject_visible(subject) and main._orbit_target.is_equal_approx(target) and not stage.camera.transform.is_equal_approx(before))
	main._remember_view()
	check("saved camera pose excludes transient panel offset",main.WorldStore.vector(main._views.woodland.position).is_equal_approx(stage.camera.position) and main.WorldStore.vector(main._views.woodland.target).is_equal_approx(target))
	main._reset_camera()
	await settle()
	check("overview removes selection offset",stage.camera.h_offset==0 and main._content_follow==-1)
	if not await arrive("reef"):
		await finish()
		return
	panel.show()
	await settle()
	panel.object_picker.item_selected.emit(4)
	await settle()
	check("turtle geometry beside panel in compact window",subject_visible(main.content_targets()[3].node))
	await capture("reef-observer")
	if not await arrive("city"):
		await finish()
		return
	panel.show()
	await settle()
	panel.object_picker.item_selected.emit(3)
	await settle()
	check("shop geometry beside panel in compact window",subject_visible(main.content_targets()[2].node))
	await capture("city-observer")
	main._navigate_relative(-1)
	if not await ready_stage():
		await finish()
		return
	check("return to Earth has no leftover camera offset",main.world.current_scale_id=="earth" and main.coordinator.active_scene.camera.h_offset==0)
	if not await arrive("solar_system"):
		await finish()
		return
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	panel.show()
	main.follow_planet(5)
	await settle()
	stage = main.coordinator.active_scene
	var saturn: Dictionary = stage.get_meta("solar_bodies")[5]
	check("Saturn and rings clear the explanation",subject_visible(saturn.node) and subject_visible(saturn.extras[0]))
	var header: HBoxContainer = main.time_label.get_parent()
	var header_clear: bool = not main.context_label.visible
	var last_right: float = 0.0
	for child: Control in header.get_children():
		if not child.visible: continue
		header_clear = header_clear and child.get_global_rect().position.x>=last_right and child.get_global_rect().end.x<900
		last_right = child.get_global_rect().end.x
	check("compact header keeps date and every action readable",header_clear and main.time_label.text.contains("TDB"))
	await capture("saturn-observer")
	var orbit_offset: Vector3 = stage.camera.position-main._orbit_target
	main.set_solar_date(Ephemeris.DEFAULT_JD+30)
	await settle()
	check("date change follows actual orbit without changing camera distance",(stage.camera.position-main._orbit_target).is_equal_approx(orbit_offset) and main._orbit_target.is_equal_approx(Ephemeris.display_position(5,main.solar_jd,main.solar_true_distance)))
	main._toggle_explorer()
	await settle()
	check("planet panel close recenters immediately",stage.camera.h_offset==0)
	get_window().size = Vector2i(1280,720)
	await settle()
	check("wide window restores context and preserves world time",main.context_label.visible and main.world.simulation_time_s==time)
	await finish()
