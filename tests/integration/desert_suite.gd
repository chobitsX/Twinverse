extends "res://tests/integration/frog_suite.gd"
const Desert = preload("res://scripts/experience/desert_builder.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")
const Store = preload("res://scripts/core/world_store.gd")
const Compare = preload("res://tests/core/test_ecophysiology.gd")
var mode: String = ""
var save_directory: String = ""

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world115-check="): directory=argument.trim_prefix("--world115-check=")
		if argument.begins_with("--desert-mode="): mode=argument.trim_prefix("--desert-mode=")
		if argument.begins_with("--world-dir="): save_directory=argument.trim_prefix("--world-dir=")
	if not directory.is_absolute_path() or not save_directory.is_absolute_path() or mode not in ["write","resume"] or save_directory==ProjectSettings.globalize_path("user://world") or not FileAccess.file_exists(save_directory.path_join("desert-fixture.marker")):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate();add_child(main)
	if DisplayServer.get_name()!="headless" and DisplayServer.get_screen_count()==1:
		main._measurement_screen=get_window().current_screen
		get_window().unfocusable=true
	if not await ready_stage():
		await finish();return
	var stable: int = Time.get_ticks_msec()
	var deadline: int = stable+10000
	while Time.get_ticks_msec()-stable<2000 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw(): stable=Time.get_ticks_msec()
	main._reduced_motion=true;main.world.set_paused(true);main.world_guide.hide()
	get_window().size=Vector2i(1280,720)
	if mode=="resume":
		await resume_check();return
	if not await arrive("earth"):
		await finish();return
	var panel: Node = main.explorer_panel
	panel.show();panel.select_earth_site(3);panel.earth_focus.pressed.emit()
	await settle()
	var locator: Dictionary = main.coordinator.active_scene.get_meta("earth_locator")
	check("Earth entry uses 32N band without a false surveyed location",locator.selection=="desert" and locator.latitude==32.0 and locator.band.visible and not locator.marker.visible and panel.earth_detail.text.contains("非国家公园测绘"))
	panel.earth_enter.pressed.emit()
	if not await ready_stage():
		await finish();return
	await settle()
	check("Earth selection opens a dedicated desert stage",main.world.current_scale_id=="desert" and main.coordinator.active_scene.builder==Desert and main.previous_button.text=="返回地球")
	if main.world.current_scale_id!="desert":
		await finish();return
	var stage: Node = main.coordinator.active_scene
	var cactus: Node3D = stage.get_meta("desert_cactus")
	var shrub: Node3D = stage.get_meta("desert_shrub")
	main.ground_light_preview=false
	await settle()
	check("real terrain foothills and four observation targets exist",stage.world_root.find_child("DryWashTerrain",true,false)!=null and stage.world_root.find_child("AuthoredDistantFoothills",true,false)!=null and main.content_targets().size()==4)
	var hills: MeshInstance3D = stage.world_root.find_child("AuthoredDistantFoothills",true,false) as MeshInstance3D
	var normals: PackedVector3Array = hills.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var upward: bool = true
	for normal: Vector3 in normals: upward=upward and normal.y>0
	check("foothill visible faces point upward without a reversed inner slope",upward and normals.size()>100)
	check("plants start on the same authored terrain",absf(cactus.position.y-Desert.height_at(cactus.position.x,cactus.position.z)+.018)<.000001 and absf(shrub.position.y-Desert.height_at(shrub.position.x,shrub.position.z)+.018)<.000001)
	check("new scale has species provenance and explicit limitations",Reference.allows_url("desert",Desert.CACTUS_SOURCE) and Reference.describe("desert").limit.contains("首批未加入荒漠动物"))
	await capture("desert-overview")
	panel.object_picker.item_selected.emit(1)
	await settle()
	check("whole cactus fits beside the explanation panel",subject_visible(cactus))
	await capture("desert-saguaro")
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="desert_cactus": action=button
	check("guide includes all three new desert routes",action!=null and main.world_guide.route_buttons.size()==34)
	if action!=null: action.pressed.emit()
	await settle()
	var areole: Vector3 = cactus.find_child("AreoleAnchor",true,false).global_position
	check("lesson follows actual attached areole with readable marker",main._content_follow==2 and main.learning_overlay.last_visible_marks==1 and main.content_targets()[2].node.get_meta("reference_root")==cactus and stage.camera.near<.001)
	check("spines and stem actually render at their close anchor",await part_pixels(cactus,areole,Vector2i(35,35))>200)
	await capture("desert-areole")
	panel.object_picker.item_selected.emit(2)
	await settle()
	check("whole shrub fits beside panel",subject_visible(shrub))
	await capture("desert-creosote")
	panel.select_topic("desert_leaf")
	await settle()
	var leaves: MeshInstance3D = shrub.find_child("BifoliolateLeaves",true,false) as MeshInstance3D
	var leaf_anchor: Vector3 = shrub.find_child("PairedLeafletsAnchor",true,false).global_position
	check("macro uses same shrub and actual leaves remain visible",main._content_follow==3 and main.content_targets()[3].node.get_meta("reference_root")==shrub and shrub.scale==Vector3.ONE and await part_pixels(leaves,leaf_anchor,Vector2i(25,25))>80)
	for i: int in range(12):
		var wheel: InputEventMouseButton = InputEventMouseButton.new()
		wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
		main._unhandled_input(wheel)
	await settle()
	check("wheel reaches real leaf close distance without scaling",absf(stage.camera.position.distance_to(main._orbit_target)-.025)<.001 and stage.camera.near<.001 and shrub.scale==Vector3.ONE)
	panel.select_topic("desert_leaf")
	await settle()
	await capture("desert-paired-leaflets")
	var time: float = main.world.simulation_time_s
	panel.select_topic("season_light");panel.select_season(1)
	await settle()
	var summer: float = stage.get_meta("sun_elevation")
	panel.select_season(3)
	await settle()
	check("32N season controls change sunlight without changing biological time",summer-float(stage.get_meta("sun_elevation"))>40 and main.world.simulation_time_s==time and panel.lesson_readout.text.contains("32°N"))
	main.ground_light_preview=false
	if not await arrive("earth") or not await arrive("desert"):
		await finish();return
	stage=main.coordinator.active_scene
	check("Earth return reconstructs same plants and paused world",stage.get_meta("desert_cactus").get_meta("stable_id")=="3dworld:teaching:saguaro:000" and main.world.simulation_time_s==time)
	get_window().size=Vector2i(900,650)
	panel.show();panel.select_topic("desert_leaf")
	await settle()
	check("compact macro keeps leaf marker and toggle reachable",main.learning_overlay.last_visible_marks==1 and panel.markers_toggle.get_global_rect().end.y<panel.get_global_rect().end.y-12)
	await capture("desert-compact")
	main.save_button.pressed.emit()
	var stored: Dictionary = Store.new(save_directory).load_session()
	check("production save writes new scale with protective v8 version",stored.status=="ok" and stored.payload.world.version==8 and stored.payload.world.current_scale_id=="desert" and stored.payload.observer.views.has("desert"))
	FileAccess.open(save_directory.path_join("desert-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"world":main.world.checkpoint(),"view":stored.payload.observer.views.desert},"\t",true,true))
	await finish()

func resume_check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_directory.path_join("desert-expected.json")))
	var actual: Dictionary = main.world.checkpoint()
	var same: bool = main.world.current_scale_id=="desert"
	for key: String in ["science","woodland_browse","urban_runoff","coral_symbiosis","simulation_time_s","paused","seed","accumulator_s"]:
		same=same and Compare.equivalent(actual[key],expected.world[key])
	check("new Release process restores desert time and existing authoritative models",same)
	check("resume adds a continued observation without inventing elapsed time",actual.local_habitat.events.size()>=expected.world.local_habitat.events.size() and actual.local_habitat.events[-1].kind=="continued")
	var stage: Node = main.coordinator.active_scene
	check("new process rebuilds correct reference plants",stage.has_meta("desert_cactus") and stage.has_meta("desert_shrub") and main.content_targets().size()==4)
	await settle()
	check("stored macro camera restores with appropriate near plane",stage.camera.position.distance_to(Store.vector(expected.view.position))<.0001 and stage.camera.near<.001)
	main.explorer_panel.show()
	await settle()
	check("restored visible panel accepts its desert leaf topic",main.explorer_panel.select_topic("desert_leaf"))
	await settle()
	check("restored branch can reopen its same-scale learning view",main.learning_overlay.last_visible_marks==1 and main._content_follow==3)
	await capture("desert-resumed")
	await finish()
