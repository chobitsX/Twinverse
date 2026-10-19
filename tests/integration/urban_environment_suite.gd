extends "res://tests/integration/life_assets_suite.gd"
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world94-check="): directory = argument.trim_prefix("--world94-check=")
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
	if not await arrive("city"):
		await finish()
		return
	await at_time(9.0)
	main.explorer_panel.hide()
	var stage: Node = main.coordinator.active_scene
	var context: Dictionary = stage.get_meta("urban_context")
	var context_record: FileAccess = FileAccess.open(directory.path_join("context.json"),FileAccess.WRITE)
	context_record.store_string(JSON.stringify(context,"\t")+"\n")
	context_record.close()
	var root: Node3D = stage.world_root.get_node("UrbanSurroundings")
	var floor: MeshInstance3D = root.get_node("ContinuousGround")
	var roads: MultiMeshInstance3D = root.get_node("ConnectedRoads")
	check("surrounding ground covers camera horizon",floor.mesh.size==Vector2(4000,4000) and stage.camera.far==1800.0)
	check("main roads continue beyond original district",roads.multimesh.instance_count==26 and context.road_length_m==1600.0)
	var volumes: MultiMeshInstance3D = root.get_node("ContextBuildings")
	var cleared: bool = true
	for i: int in range(volumes.multimesh.instance_count):
		var position: Vector3 = volumes.multimesh.get_instance_transform(i).origin
		cleared = cleared and maxf(absf(position.x),absf(position.z))>100.0
	check("context buildings preserve near district",cleared and context.building_volumes>0)
	check("context pavements leave driving lanes clear",pavements_clear(root.get_node("ContextPavements"),roads))
	check("near targets and actors preserved",stage.get_meta("building_counts")=={"shops":9,"homes":10,"offices":8} and stage.get_meta("actors").size()==40 and main.content_targets().size()==4)
	await capture("city-connected-overview")
	main.follow_content(4)
	await capture("roof-with-city-context")
	check("actual roof normal and anchor preserved",main.content_targets()[3].node.has_meta("solar_normal_world") and main.content_targets()[3].node.has_meta("solar_anchor_world"))
	main.follow_content(3)
	await capture("street-with-neighborhood")
	main._reset_camera()
	main.ground_light_preview = true
	var night_jd: float = Ephemeris.DEFAULT_JD
	for fraction: float in [0.0,.25,.5,.75]:
		if stage.builder.Orientation.local_sun(Ephemeris.DEFAULT_JD+fraction,35,120).y<-.2:
			night_jd = Ephemeris.DEFAULT_JD+fraction
			break
	main.set_solar_date(night_jd)
	for frame: int in range(3): await get_tree().process_frame
	check("surrounding windows follow existing night lighting",float(volumes.material_override.get_shader_parameter("night_amount"))>.9)
	await capture("city-context-night")
	main.ground_light_preview = false
	if not await arrive("earth") or not await arrive("city"):
		await finish()
		return
	check("reentry preserves deterministic context",main.coordinator.active_scene.get_meta("urban_context")==context)
	await finish()

func pavements_clear(pavements: MultiMeshInstance3D, roads: MultiMeshInstance3D) -> bool:
	var road_rectangles: Array[Rect2] = []
	for i: int in range(roads.multimesh.instance_count):
		var bounds: AABB = roads.multimesh.get_instance_transform(i)*roads.multimesh.mesh.get_aabb()
		road_rectangles.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
	for i: int in range(pavements.multimesh.instance_count):
		var bounds: AABB = pavements.multimesh.get_instance_transform(i)*pavements.multimesh.mesh.get_aabb()
		var footprint: Rect2 = Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
		for road: Rect2 in road_rectangles:
			if footprint.intersects(road): return false
	return true
