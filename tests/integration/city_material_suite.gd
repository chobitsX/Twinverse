extends "res://tests/integration/land_lighting_suite.gd"
var material_records: Array[Dictionary] = []

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world124-check="): directory=argument.trim_prefix("--world124-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await arrive("city"):
		await finish()
		return
	await at_time(9.)
	main.ground_light_preview=false
	main._reset_camera()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var context: Dictionary = stage.get_meta("urban_context")
	var buildings: Array[Node] = stage.world_root.find_children("CityBuilding_*","Node3D",false,false)
	check("authored district layout population and surroundings stay intact",buildings.size()==27 and stage.get_meta("actors").size()==40 and stage.get_meta("building_counts")=={"shops":9,"homes":10,"offices":8} and context.building_volumes==575)
	var all_panels: bool = true
	for building: Node3D in buildings:
		all_panels=all_panels and building.has_meta("solar_normal_world") and building.has_meta("solar_anchor_world")
		material_records.append({"name":building.name,"category":building.get_meta("architecture_category"),"variant":building.get_meta("architecture_variation"),"position":str(building.position)})
	check("roof teaching still uses real geometry anchors on every building",all_panels)
	await capture("city-material-overview")
	main.explorer_panel.show()
	await settle()
	check("street topic still opens same architectural subject",main.explorer_panel.select_topic("street"))
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact shop remains fully observable beside explanation",subject_visible(main.content_targets()[2].node))
	await capture("city-shop-compact")
	main.explorer_panel.hide()
	get_window().size=Vector2i(1280,720)
	main._content_follow=-1
	var shop: Node3D = stage.world_root.get_node("CityBuilding_-1_1")
	var at: Vector3 = shop.to_global(Vector3(0,5.3,5.42))
	main._orbit_target=at
	stage.set_pose(shop.to_global(Vector3(.4,5.7,7.5)),at)
	await settle()
	var wall: MeshInstance3D = shop.find_child("BuildingWallGeometry",true,false) as MeshInstance3D
	var material: Material = wall.get_surface_override_material(0)
	var after: Image = await frame_image(stage)
	wall.set_surface_override_material(0,null)
	var before: Image = await frame_image(stage)
	wall.set_surface_override_material(0,material)
	comparisons.shop_surface=shadow_change(before,after)
	check("new facade material is actually visible on the original wall",comparisons.shop_surface.darkened>200)
	await capture("city-masonry-near")
	main._reset_camera()
	main.explorer_panel.show()
	await settle()
	check("solar roof topic remains usable",main.explorer_panel.select_topic("solar_roof"))
	await settle()
	check("solar panel normal is retained on selected building",main.content_targets()[3].node.has_meta("solar_normal_world"))
	main.explorer_panel.hide()
	main._reset_camera()
	main.ground_light_preview=true
	for fraction: float in [0.,.25,.5,.75]:
		var jd: float = Ephemeris.DEFAULT_JD+fraction
		if stage.builder.Orientation.local_sun(jd,35,120).y<-.2:
			main.set_solar_date(jd)
			break
	await settle()
	var context_mesh: MultiMeshInstance3D = stage.world_root.get_node("UrbanSurroundings/ContextBuildings")
	check("night lighting still follows existing date and emission",stage.get_meta("daylight_sun").light_energy==0. and float(context_mesh.material_override.get_shader_parameter("night_amount"))>.9)
	await capture("city-material-night")
	main.ground_light_preview=false
	if not await arrive("earth") or not await arrive("city"):
		await finish()
		return
	stage=main.coordinator.active_scene
	var restored: Array[Dictionary] = []
	for building: Node3D in stage.world_root.find_children("CityBuilding_*","Node3D",false,false):
		restored.append({"name":building.name,"category":building.get_meta("architecture_category"),"variant":building.get_meta("architecture_variation"),"position":str(building.position)})
	check("reentry preserves palettes placement and paused world time",restored==material_records and main.world.simulation_time_s==9.)
	await finish()
