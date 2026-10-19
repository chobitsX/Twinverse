extends "res://tests/integration/world_expansion_suite.gd"

## One bounded real-window check of the synthetic city fabric and unchanged actors.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world199-review="):
			directory = argument.trim_prefix("--world199-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless":
		main._measurement_screen = get_window().current_screen
		get_window().unfocusable = true
	get_window().size = Vector2i(1280, 800)
	get_tree().create_timer(70.0).timeout.connect(func() -> void:
		push_error("City fabric short check exceeded bounded runtime")
		get_tree().quit(2))
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	main.sound_panel.hide()
	if not await arrive("city"):
		await finish()
		return
	var stage: Node = main.coordinator.active_scene
	var root: Node3D = stage.world_root.get_node("UrbanSurroundings")
	var buildings: MultiMesh = (root.get_node("ContextBuildings") as MultiMeshInstance3D).multimesh
	var greens: MultiMesh = (root.get_node("PublicGreens") as MultiMeshInstance3D).multimesh
	var context: Dictionary = stage.get_meta("urban_context")
	var geometry_file: FileAccess = FileAccess.open(directory.path_join("geometry.json"),FileAccess.WRITE)
	geometry_file.store_string(JSON.stringify(context,"\t")+"\n")
	geometry_file.close()
	var styles: Dictionary = {}
	for k: int in range(buildings.instance_count):
		var variant: Color = buildings.get_instance_custom_data(k)
		var style: int = roundi(variant.a * 3.0)
		styles[style] = int(styles.get(style, 0)) + 1
	check("background remains one instanced batch with 575 volumes",
		buildings.instance_count == 575 and int(context.building_volumes) == 575)
	var expected_greens: Array[Vector2] = [Vector2(-144,-144),Vector2(-144,-48),Vector2(-144,48),Vector2(-144,144),Vector2(-48,-240),Vector2(-48,-144)]
	var placed_greens: Array[Vector2] = []
	for k: int in range(greens.instance_count):
		var at: Vector3 = greens.get_instance_transform(k).origin
		placed_greens.append(Vector2(at.x,at.z))
	var positions_match: bool = placed_greens.size() == expected_greens.size()
	for center: Vector2 in expected_greens: positions_match = positions_match and placed_greens.has(center)
	check("western four and northern two green blocks form a visible bend",
		greens.instance_count == 6 and positions_match and int(context.green_blocks) == 6)
	var road_boxes: Array[Rect2] = []
	var roads: MultiMesh = (root.get_node("ConnectedRoads") as MultiMeshInstance3D).multimesh
	for k: int in range(roads.instance_count):
		var bounds: AABB = roads.get_instance_transform(k)*roads.mesh.get_aabb()
		road_boxes.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
	var roads_clear: bool = true
	for k: int in range(greens.instance_count):
		var bounds: AABB = greens.get_instance_transform(k)*greens.mesh.get_aabb()
		var footprint: Rect2 = Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
		for road_box: Rect2 in road_boxes: roads_clear = roads_clear and not footprint.intersects(road_box)
	check("green ground leaves the connected driving lanes open",roads_clear)
	var lots_clear: bool = true
	for k: int in range(buildings.instance_count):
		var at: Vector3 = buildings.get_instance_transform(k).origin
		for center: Vector2 in expected_greens:
			lots_clear = lots_clear and not (absf(at.x-center.x)<42.0 and absf(at.z-center.y)<42.0)
	check("green blocks contain no background building volumes",lots_clear)
	check("six green blocks gain separate irregular trees without shifting other blocks",int(context.green_trees) == 72 and int(context.tree_crowns) == 1044)
	check("four district color groups reach actual background instances", styles.size() == 4)
	check("27 near buildings and original people and cars remain",
		stage.get_meta("building_counts") == {"shops":9,"homes":10,"offices":8} and
		stage.get_meta("actors").size() == 40)
	check("same roads and context trees remain",
		(root.get_node("ConnectedRoads") as MultiMeshInstance3D).multimesh.instance_count == 26 and
		int(context.tree_crowns) == 1044)
	main.sound_panel.hide()
	await capture("city-fabric-overview")
	get_window().size = Vector2i(900, 650)
	main._reset_camera()
	main.sound_panel.hide()
	await capture("city-fabric-compact")
	get_window().size = Vector2i(1280, 800)
	main._reset_camera()
	main.follow_content(1)
	main.sound_panel.hide()
	await capture("city-fabric-human")
	check("city observation keeps authoritative time paused", main.world.paused)
	main._reset_camera()
	main.ground_light_preview = true
	var site: Dictionary = stage.builder.Sites.for_scale("city")
	for fraction: float in [0.0, .25, .5, .75]:
		var jd: float = Ephemeris.DEFAULT_JD + fraction
		if stage.builder.Orientation.local_sun(jd, site.lat, site.lon).y < -.2:
			main.set_solar_date(jd)
			break
	for frame: int in range(3): await get_tree().process_frame
	check("city night still follows one astronomy date",
		(stage.get_meta("daylight_sun") as DirectionalLight3D).light_energy < .01 and
		float(stage.get_meta("sun_elevation")) < 0.0)
	main.sound_panel.hide()
	await capture("city-fabric-night")
	await finish()
