extends "res://tests/integration/world_expansion_suite.gd"

## Short real-window checks of the six existing public greens and their neighbors.
const BASELINE: Dictionary = {
	"ConnectedRoads":{"count":26,"transforms_sha256":"64a8672ba91dc2c8c256981a3e5ecf32c375637997021f688f78f681b47d8864","colors_sha256":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
	"ContextBuildings":{"count":575,"transforms_sha256":"02bcfa0aa4c68b545ac5d77a0c19b5113a2238c8ba0b3b4f7c51f4689ab2eca2","colors_sha256":"bff2ef74944fb49dfeba010a2932a4bbd65a63ce4feeeacd702d2b18c25555d4"},
	"PublicGreens":{"count":6,"transforms_sha256":"718cf07fe8343035ac8e7d10907177b91a633039ec422c43e16d17b3d9b62ae7","colors_sha256":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
	"ContextPavements":{"count":1271,"transforms_sha256":"1c0b4e5e26661c0938413e8b9f698fa88c8a29a4aa5421592ce16164f51c0e96","colors_sha256":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
	"ContextTrees":{"count":972,"transforms_sha256":"08d7f2af5a724675be9333a17927e96e8623739939e68b2459d519db8557a5f8","colors_sha256":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
	"ContextTrunks":{"count":972,"transforms_sha256":"a87d57f59fc5d2c50593b4f8ba1e0f1ee0aa221223fd86f9ee1a3def475fd439","colors_sha256":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}
}
var observations: Dictionary = {}
var view_settings: Array[Dictionary] = []

func settle() -> void:
	# A display may wake after startup; move only this diagnostic if necessary.
	for screen: int in range(DisplayServer.get_screen_count()):
		if screen==DisplayServer.get_primary_screen(): continue
		if get_window().current_screen!=screen:
			var original_size: Vector2i = get_window().size
			get_window().current_screen = screen
			get_window().position = DisplayServer.screen_get_usable_rect(screen).position+Vector2i(30,30)
			get_window().size = original_size
		main._measurement_screen = screen
		break
	for frame: int in range(4): await get_tree().process_frame

func capture(label: String) -> void:
	await settle()
	view_settings.append({"view":label,"screen_count":DisplayServer.get_screen_count(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"window_size":[get_window().size.x,get_window().size.y]})
	await super.capture(label)

func core_checkpoint() -> Dictionary:
	var value: Dictionary = main.world.checkpoint()
	value.erase("current_scale_id")
	value.erase("local_habitat")
	return value

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world233-review="): directory = argument.trim_prefix("--world233-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size = Vector2i(1280,800)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	get_tree().create_timer(95.0).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	get_window().size = Vector2i(1280,800)
	main._measurement_screen = get_window().current_screen
	main._audio.volume_db = -80.0
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world.set_time_scale(2.0)
	main.set_solar_rate(0.0)
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	main.ground_light_preview = false
	main.world_guide.hide()
	main.explorer_panel.hide()
	main.sound_panel.hide()
	if not await arrive("city"):
		await finish()
		return
	main.world.simulation_time_s = 12.0
	main._reset_camera()
	await settle()
	var authority: int = main.world.get_instance_id()
	var core: Dictionary = core_checkpoint()
	var stage: Node = main.coordinator.active_scene
	var root: Node3D = stage.world_root.get_node("UrbanSurroundings")
	var context: Dictionary = stage.get_meta("urban_context")
	var lots: Array[Rect2] = footprints((root.get_node("PublicGreens") as MultiMeshInstance3D).multimesh)
	var batches: Dictionary = neighboring_batches(root,lots)
	for label: String in BASELINE:
		check("original neighboring batch unchanged: " + label,batches[label]==BASELINE[label])
	check("six original green lots keep 72 park trees and 1044 total crowns",lots.size()==6 and context.green_blocks==6 and context.green_trees==72 and context.tree_crowns==1044)
	check("context still has 575 building volumes and 28 stepped towers",context.building_volumes==575 and context.stepped_towers==28 and not context.surveyed)
	check("near teaching buildings remain 9 shops 10 homes 8 offices",stage.get_meta("building_counts")=={"shops":9,"homes":10,"offices":8})
	var people: int = 0
	var cars: int = 0
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind=="person": people += 1
		if actor.kind=="car": cars += 1
	var street_people: int = stage.get_meta("street_walkers",[]).size()
	people += street_people
	check("existing 34 people and 12 cars remain",people==34 and street_people==6 and cars==12)
	check("existing near park ground cover remains its bounded batch",stage.get_meta("city_park_ground_cover",{}).get("count")==700)
	check("diagnostic keeps native focus and input disabled",get_window().unfocusable and get_viewport().gui_disable_input)
	check("diagnostic uses a nonprimary screen when available",DisplayServer.get_screen_count()<=1 or get_window().current_screen!=DisplayServer.get_primary_screen())
	var layout: Dictionary = inspect_paths_and_trees(root,lots)
	observations["geometry"] = context
	observations["neighbor_batches"] = batches
	observations["layout"] = layout
	await capture("city-public-greens-overview")
	get_window().size = Vector2i(900,650)
	main._reset_camera()
	await settle()
	await capture("city-public-greens-compact")
	get_window().size = Vector2i(1280,800)
	main._reset_camera()
	# Inspection camera only; product navigation continues to use the same pan/zoom.
	stage.set_pose(Vector3(-95,58,7),Vector3(-143,0,-48))
	await settle()
	await capture("city-public-green-local")
	main._reset_camera()
	check("existing people-view control is available",main.next_button.text=="走近人群" and not main.next_button.disabled)
	main.next_button.pressed.emit()
	await settle()
	check("people control enters original same-time park view",main._city_people_view and main.world.simulation_time_s==12.0)
	await capture("city-public-green-human")
	main.next_button.pressed.emit()
	await settle()
	check("same control enters original street-height view",main._city_street_view and not main._city_people_view and main.world.simulation_time_s==12.0)
	await capture("city-public-green-street")
	main.next_button.pressed.emit()
	await settle()
	check("same control returns original city overview",not main._city_street_view and not main._city_people_view)
	main.ground_light_preview = true
	var site: Dictionary = stage.builder.Sites.for_scale("city")
	var night_date: float = Ephemeris.DEFAULT_JD
	for fraction: float in [0.0,.25,.5,.75]:
		if stage.builder.Orientation.local_sun(Ephemeris.DEFAULT_JD+fraction,site.lat,site.lon).y<-.2:
			night_date = Ephemeris.DEFAULT_JD+fraction
			break
	main.set_solar_date(night_date)
	await settle()
	check("night uses existing date lighting and background windows",(stage.get_meta("daylight_sun") as DirectionalLight3D).light_energy<.01 and float((root.get_node("ContextBuildings") as MultiMeshInstance3D).material_override.get_shader_parameter("night_amount"))>.9)
	await capture("city-public-green-night")
	main.ground_light_preview = false
	main.set_solar_date(Ephemeris.DEFAULT_JD)
	if not await arrive("earth") or not await arrive("city"):
		await finish()
		return
	await settle()
	stage = main.coordinator.active_scene
	root = stage.world_root.get_node("UrbanSurroundings")
	check("return rebuilds the same context and all neighboring batches",stage.get_meta("urban_context")==context and neighboring_batches(root,lots)==batches)
	check("return rebuilds the same park path and tree layout",park_layout_sha(root,lots)==layout.park_layout_sha256)
	check("observations keep one paused world checkpoint and date",main.world.get_instance_id()==authority and core_checkpoint()==core and main.world.paused and main.world.simulation_time_s==12.0 and main.world.time_scale==2.0 and main.solar_jd==Ephemeris.DEFAULT_JD and main.solar_rate==0.0)
	main._open_guide()
	check("layout adds no species guides or save fields",main.world_guide.species_atlas.cards.size()==40 and main.world_guide.route_buttons.size()==86 and main.guided_journey.checkpoint().size()==6)
	main.world_guide.hide()
	await settle()
	observations["views"] = view_settings
	observations.merge({"people":people,"street_walkers":street_people,"cars":cars,"world_time_s":main.world.simulation_time_s,"time_scale":main.world.time_scale,"paused":main.world.paused,"date_jd":main.solar_jd,"solar_rate":main.solar_rate,"night_date_jd":night_date,"core_unchanged":core_checkpoint()==core,"same_authority":main.world.get_instance_id()==authority,"screen_count":DisplayServer.get_screen_count(),"screen":get_window().current_screen,"primary":DisplayServer.get_primary_screen(),"unfocusable":get_window().unfocusable,"native_input_disabled":get_viewport().gui_disable_input,"audio_volume_db":main._audio.volume_db})
	await finish()

func inspect_paths_and_trees(root: Node3D, lots: Array[Rect2]) -> Dictionary:
	var paths: MultiMesh = (root.get_node("PublicGreenPaths") as MultiMeshInstance3D).multimesh
	var vertices: PackedVector3Array = (paths.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var roads: Array[Rect2] = footprints((root.get_node("ConnectedRoads") as MultiMeshInstance3D).multimesh)
	var sidewalks: Array[Rect2] = footprints((root.get_node("ContextPavements") as MultiMeshInstance3D).multimesh)
	var lines: Array[PackedVector2Array] = []
	var ribbons: Array = []
	var clear: bool = true
	var connected: bool = true
	var curved: bool = true
	for index: int in range(paths.instance_count):
		var placement: Transform3D = paths.get_instance_transform(index)
		var bounds: AABB = placement*paths.mesh.get_aabb()
		var rectangle: Rect2 = Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
		for road: Rect2 in roads: clear = clear and not rectangle.intersects(road)
		var points: PackedVector2Array = PackedVector2Array()
		var quads: Array[PackedVector2Array] = []
		for pair: int in range(vertices.size()/2):
			var at: Vector3 = placement*((vertices[pair*2]+vertices[pair*2+1])*.5)
			points.append(Vector2(at.x,at.z))
		for segment: int in range(vertices.size()/2-1):
			var quad: PackedVector2Array = PackedVector2Array()
			for offset: int in [0,1,3,2]:
				var at: Vector3 = placement*vertices[segment*2+offset]
				quad.append(Vector2(at.x,at.z))
			quads.append(quad)
		for endpoint: Vector2 in [points[0],points[-1]]:
			var on_sidewalk: bool = false
			for sidewalk: Rect2 in sidewalks: on_sidewalk = on_sidewalk or sidewalk.has_point(endpoint)
			connected = connected and on_sidewalk
		var deviation: float = 0.0
		for point: Vector2 in points: deviation = maxf(deviation,point.distance_to(Geometry2D.get_closest_point_to_segment(point,points[0],points[-1])))
		curved = curved and deviation>10.0
		lines.append(points)
		ribbons.append(quads)
	check("six actual paths share one shallow ribbon mesh",paths.instance_count==6 and paths.mesh.get_surface_count()==1 and paths.mesh.get_aabb().size.y<.001)
	check("actual return loops deviate visibly from the old straight line",curved)
	check("actual path bounds leave all driving lanes clear",clear)
	check("both ends of every actual path meet existing sidewalks",connected)
	var trees: MultiMesh = (root.get_node("ContextTrees") as MultiMeshInstance3D).multimesh
	var trunks: MultiMesh = (root.get_node("ContextTrunks") as MultiMeshInstance3D).multimesh
	var tree_counts: Array[int] = []
	tree_counts.resize(lots.size())
	tree_counts.fill(0)
	var contained: bool = true
	var minimum_distance: float = INF
	var minimum_edge_distance: float = INF
	var trunks_clear: bool = true
	for index: int in range(trees.instance_count):
		var placement: Transform3D = trees.get_instance_transform(index)
		var point: Vector2 = Vector2(placement.origin.x,placement.origin.z)
		for lot: int in range(lots.size()):
			if not lots[lot].has_point(point): continue
			tree_counts[lot] += 1
			var bounds: AABB = placement*trees.mesh.get_aabb()
			contained = contained and lots[lot].encloses(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
			for segment: int in range(lines[lot].size()-1):
				minimum_distance = minf(minimum_distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,lines[lot][segment],lines[lot][segment+1])))
			var trunk: Transform3D = trunks.get_instance_transform(index)
			var foot: Vector2 = Vector2(trunk.origin.x,trunk.origin.z)
			var edge_distance: float = INF
			for quad: PackedVector2Array in ribbons[lot]:
				trunks_clear = trunks_clear and not Geometry2D.is_point_in_polygon(foot,quad)
				for edge: int in range(quad.size()):
					edge_distance = minf(edge_distance,foot.distance_to(Geometry2D.get_closest_point_to_segment(foot,quad[edge],quad[(edge+1)%quad.size()])))
			minimum_edge_distance = minf(minimum_edge_distance,edge_distance)
			var trunk_foot_radius: float = .5*sqrt(trunk.basis.x.length_squared()+trunk.basis.z.length_squared())
			trunks_clear = trunks_clear and edge_distance>trunk_foot_radius+.1
	check("each actual grass lot retains twelve trees",tree_counts==[12,12,12,12,12,12])
	check("park crowns remain within their original grass lots",contained)
	check("actual trunk boxes leave the curved walking surface open",trunks_clear)
	return {"path_instances":paths.instance_count,"ribbon_vertices":vertices.size(),"park_tree_counts":tree_counts,"minimum_trunk_to_path_center_m":minimum_distance,"minimum_trunk_center_to_ribbon_edge_m":minimum_edge_distance,"park_layout_sha256":park_layout_sha(root,lots)}

func footprints(instances: MultiMesh) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for index: int in range(instances.instance_count):
		var bounds: AABB = instances.get_instance_transform(index)*instances.mesh.get_aabb()
		result.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
	return result

func neighboring_batches(root: Node3D, lots: Array[Rect2]) -> Dictionary:
	var result: Dictionary = {}
	for label: String in BASELINE:
		var instances: MultiMesh = (root.get_node(label) as MultiMeshInstance3D).multimesh
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		for index: int in range(instances.instance_count):
			var placement: Transform3D = instances.get_instance_transform(index)
			var in_green: bool = false
			for lot: Rect2 in lots: in_green = in_green or lot.has_point(Vector2(placement.origin.x,placement.origin.z))
			if label in ["ContextPavements","ContextTrees","ContextTrunks"] and in_green: continue
			transforms.append(placement)
			if instances.use_custom_data: colors.append(instances.get_instance_custom_data(index))
		result[label] = {"count":transforms.size(),"transforms_sha256":transforms_sha(transforms),"colors_sha256":colors_sha(colors)}
	return result

func park_layout_sha(root: Node3D, lots: Array[Rect2]) -> String:
	var values: Array[Transform3D] = []
	for label: String in ["PublicGreenPaths","ContextTrees","ContextTrunks"]:
		var instances: MultiMesh = (root.get_node(label) as MultiMeshInstance3D).multimesh
		for index: int in range(instances.instance_count):
			var placement: Transform3D = instances.get_instance_transform(index)
			for lot: Rect2 in lots:
				if lot.has_point(Vector2(placement.origin.x,placement.origin.z)):
					values.append(placement)
					break
	return transforms_sha(values)

func transforms_sha(transforms: Array[Transform3D]) -> String:
	var values: PackedFloat32Array = PackedFloat32Array()
	for t: Transform3D in transforms:
		values.append_array(PackedFloat32Array([t.basis.x.x,t.basis.x.y,t.basis.x.z,t.basis.y.x,t.basis.y.y,t.basis.y.z,t.basis.z.x,t.basis.z.y,t.basis.z.z,t.origin.x,t.origin.y,t.origin.z]))
	return values.to_byte_array().hex_encode().sha256_text()

func colors_sha(colors: Array[Color]) -> String:
	var values: PackedFloat32Array = PackedFloat32Array()
	for c: Color in colors: values.append_array(PackedFloat32Array([c.r,c.g,c.b,c.a]))
	return values.to_byte_array().hex_encode().sha256_text()

func finish() -> void:
	var output: FileAccess = FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"native_input_tested":false,"native_ime_tested":false,"performance_test":false},"\t")+"\n")
	output.close()
	print("PUBLIC_GREEN233_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
