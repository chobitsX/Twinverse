extends "res://tests/integration/world_expansion_suite.gd"

## Checks the actual instanced city geometry; headless runs are structural only.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world190-check="):
			directory = argument.trim_prefix("--world190-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless" and get_window().current_screen != DisplayServer.get_primary_screen():
		main._measurement_screen = get_window().current_screen
		get_window().unfocusable = true
	if not await ready_stage():
		await finish()
		return
	if DisplayServer.get_name() != "headless":
		var stable_since: int = Time.get_ticks_msec()
		var startup_deadline: int = stable_since + 10000
		while Time.get_ticks_msec() - stable_since < 2000 and Time.get_ticks_msec() < startup_deadline:
			await get_tree().process_frame
			if not main.world.foreground or not DisplayServer.window_can_draw():
				stable_since = Time.get_ticks_msec()
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await arrive("city"):
		await finish()
		return
	var stage: Node = main.coordinator.active_scene
	var root: Node3D = stage.world_root.get_node("UrbanSurroundings")
	var volumes: MultiMesh = (root.get_node("ContextBuildings") as MultiMeshInstance3D).multimesh
	var context: Dictionary = stage.get_meta("urban_context")
	var geometry_readback: bool = DisplayServer.get_name() != "headless"
	var stepped: int = 0
	var joined: bool = true
	var contained: bool = true
	var closest: float = INF
	var close_origins: Array[Vector2] = []
	var index: int = 0
	while geometry_readback and index < volumes.instance_count:
		var lower: Transform3D = volumes.get_instance_transform(index)
		var location: Vector2 = Vector2(lower.origin.x,lower.origin.z)
		var clearance: float = maxf(absf(location.x),absf(location.y))
		closest = minf(closest,clearance)
		if clearance <= 100.0 and close_origins.size() < 12: close_origins.append(location)
		if index+1 < volumes.instance_count:
			var upper: Transform3D = volumes.get_instance_transform(index+1)
			if absf(upper.origin.x-lower.origin.x)<.001 and absf(upper.origin.z-lower.origin.z)<.001:
				var a: Vector3 = lower.basis.get_scale()
				var b: Vector3 = upper.basis.get_scale()
				joined = joined and absf((lower.origin.y+a.y*.5)-(upper.origin.y-b.y*.5))<.001
				contained = contained and b.x<a.x*.8 and b.z<a.z*.85
				stepped += 1
				index += 2
				continue
		index += 1
	check("575 instanced background volumes leave the public green bend",volumes.instance_count==575 and int(context.building_volumes)==575)
	check("28 tower profiles retain their joined silhouette",int(context.stepped_towers)==28)
	if geometry_readback:
		check("visible tower levels join inside lower footprint",stepped==28 and joined and contained)
	check("distant high-rise heights vary without outliers",float(context.tallest_context_m)>70.0 and float(context.tallest_context_m)<90.0)
	check("near city and time remain authoritative",stage.get_meta("building_counts")=={"shops":9,"homes":10,"offices":8} and stage.get_meta("actors").size()==40 and main.world.paused)
	check("roads and green context remain present",(root.get_node("ConnectedRoads") as MultiMeshInstance3D).multimesh.instance_count==26 and int(context.tree_crowns)==1044 and int(context.green_blocks)==6)
	var geometry: Dictionary = {"background_volumes":volumes.instance_count,"geometry_readback":geometry_readback,"stepped_towers_readback":stepped if geometry_readback else null,"joined":joined if geometry_readback else null,"contained":contained if geometry_readback else null,"closest_center_m":closest if geometry_readback else null,"centers_at_or_inside_100_m":close_origins if geometry_readback else [],"context":context}
	var output: FileAccess = FileAccess.open(directory.path_join("geometry.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(geometry,"\t")+"\n")
	output.close()
	if DisplayServer.get_name() != "headless":
		await capture("city-context-overview")
		main.follow_content(1)
		await capture("city-context-human")
	if not await arrive("earth") or not await arrive("city"):
		await finish()
		return
	check("reentry repeats background layout",main.coordinator.active_scene.get_meta("urban_context")==context)
	await finish()
