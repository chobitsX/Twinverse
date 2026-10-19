extends "res://tests/integration/spatial_input_suite.gd"
## Finite UI/geometry checks use the real viewport route. No saves or performance capture.
var section: String = "regions"
var layouts: Array[Dictionary] = []

func ready_stage() -> bool:
	var deadline: int = Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground:
			if DisplayServer.get_name()=="headless" or DisplayServer.window_can_draw(): return true
		if not main.coordinator.recovery_state().is_empty(): break
	var failure: Dictionary = {"scale":main.world.current_scale_id,"target":main.coordinator._target_id,"phase":main.coordinator.phase,"foreground":main.world.foreground,"window_can_draw":DisplayServer.get_name()=="headless" or DisplayServer.window_can_draw(),"recovery":main.coordinator.recovery_state(),"active_prepared":main.coordinator.active_scene.is_prepared()}
	FileAccess.open(directory.path_join("stage-failure.json"),FileAccess.WRITE).store_string(JSON.stringify(failure,"\t")+"\n")
	print("UI258_STAGE_FAILURE ",JSON.stringify(failure))
	check("stage ready",false)
	return false

func gui_click(point: Vector2) -> void:
	# A Button must retain GUI mouse focus between press/release. The shared
	# 3D dispatch helper disables GUI after each event and clears that focus.
	get_viewport().gui_disable_input=false
	get_viewport().notify_mouse_entered()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; get_viewport().push_input(motion,true)
	for down: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; get_viewport().push_input(event,true)
	get_viewport().gui_disable_input=true

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui258-output="): directory = argument.trim_prefix("--ui258-output=")
		if argument.begins_with("--ui258-section="): section = argument.trim_prefix("--ui258-section=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(115).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate(); add_child(main)
	main._measurement_screen = get_window().current_screen
	if is_instance_valid(main._audio): main._audio.volume_db = -80
	main._reduced_motion = true; main.world.set_paused(true); main.set_solar_rate(0.0)
	get_window().size = Vector2i(1280,800)
	if not await ready_stage(): await finish(); return
	original_id = main.world.get_instance_id(); original_time = main.world.simulation_time_s; original_jd = main.solar_jd
	if section=="regions": await regions()
	elif section=="panels": await panels()
	elif section=="scales": await scales()
	else: check("known UI section",false)
	check("same authoritative World and held date/time",main.world.get_instance_id()==original_id and main.solar_jd==original_jd and main.world.simulation_time_s==original_time and main.world.paused)
	check("review never writes user saves",not main._persistence_enabled)
	await finish()

func record_layout(label: String) -> void:
	var ui: Node = main.immersive_interface
	var window: Rect2 = Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
	for pair: Array in [["header",ui.header],["time",ui.transport],["context",ui.context_panel]]:
		var control: Control = pair[1]
		if control.is_visible_in_tree(): check(label+" "+pair[0]+" stays inside window",window.encloses(control.get_global_rect()))
	layouts.append({"label":label,"header":str(ui.header.get_global_rect()),"time":str(ui.transport.get_global_rect()),"context":str(ui.context_panel.get_global_rect()),"context_visible":ui.context_panel.visible,"viewport":str(window)})

func pose_area(id: String, distance: float = 9.6) -> void:
	var site: Dictionary = main.Sites.for_scale(id)
	main.coordinator.active_scene.set_pose(main.Sites.normal(site.lat,site.lon)*distance,Vector3.ZERO)
	main._orbit_target = Vector3.ZERO
	await settle(); main.earth_entry_panel.refresh_points()

func regions() -> void:
	var panel: Node = main.earth_entry_panel
	var ui: Node = main.immersive_interface
	panel.clear_selection()
	await pose_area("reef")
	record_layout("earth overview"); await capture("earth-overview")
	for id: String in panel.ORDER:
		await pose_area(id)
		check(id+" original reference remains inside the new area",panel.points.has(id) and panel.pick(panel.points[id].pixel)==id)
		var site: Dictionary = main.Sites.for_scale(id)
		var within: Vector3 = main.Sites.normal(site.lat-.6,site.lon+1.1)*panel.SURFACE_RADIUS
		var point: Vector2 = main.coordinator.active_scene.camera.unproject_position(within)
		check(id+" non-anchor point selects the geographic area",panel.pick(point)==id)
		click(point); await settle()
		check(id+" first click selects without entering",panel.selected==id and not main.coordinator.is_busy() and ui.context_panel.visible)
		check(id+" concise strip carries actual reference meaning",ui.context_note.text.contains("教学") or ui.context_note.text.contains("非实地地址"))
		if id!="reef":
			click(point)
			check(id+" repeat area click requests its real scene",main.coordinator.is_busy() and main.coordinator._target_id==id)
			if not await ready_stage(): return
			check(id+" area entry arrives at its real scene",main.world.current_scale_id==id)
			if id=="city": await capture("city-area-entry")
			main._navigate_relative(-1)
			if not await ready_stage(): return
			check(id+" returns to the original Earth context",main.world.current_scale_id=="earth")
		panel.clear_selection()
	await pose_area("reef")
	check("the opposite desert and woodland areas are excluded",not panel.points.has("desert") and not panel.points.has("woodland"))
	var point: Vector2 = panel.points.reef.pixel
	var start: Transform3D = main.coordinator.active_scene.camera.transform
	var press: InputEventMouseButton = InputEventMouseButton.new(); press.position=point; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; dispatch(press)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new(); drag.position=point+Vector2(45,15); drag.relative=Vector2(45,15); drag.button_mask=MOUSE_BUTTON_MASK_LEFT; dispatch(drag)
	press.position=drag.position; press.pressed=false; dispatch(press)
	check("drag across an area rotates without selecting/entering",panel.selected.is_empty() and not main.coordinator.is_busy() and not main.coordinator.active_scene.camera.transform.is_equal_approx(start))
	await pose_area("reef"); click(panel.points.reef.pixel); await settle()
	record_layout("ocean selected"); await capture("earth-ocean-selected")
	check("ocean strip explains atmosphere and reef",ui.context_path.text.contains("大气") and ui.context_path.text.contains("珊瑚礁"))
	var before: float = radius(); magnify(1.04)
	check("area selection preserves continuous pinch",radius()<before and not main.coordinator.is_busy())
	main.clean_observation.set_active(true); await settle()
	check("clean view still picks the area",panel.available() and panel.pick(panel.points.reef.pixel)=="reef")
	main.clean_observation.set_active(false)
	get_window().size=Vector2i(900,650); await settle(); record_layout("compact ocean selection"); await capture("earth-compact")
	get_window().size=Vector2i(1280,800); await pose_area("reef",3.9); magnify(1.08)
	check("pinching near selected ocean starts atmosphere",main.coordinator.is_busy() and main.coordinator._target_id=="atmosphere")
	if not await ready_stage(): return
	await capture("atmosphere")
	if not await arrive("pacific"): return
	await capture("sea-surface")
	if not await arrive("reef"): return
	main._reset_camera(); await settle(); record_layout("reef"); await capture("reef")
	var chosen: Dictionary = visible_choice("", "海葵双锯鱼")
	if chosen.is_empty(): chosen=visible_choice("fish")
	check("reef contains a real selectable fish",not chosen.is_empty())
	if not chosen.is_empty():
		click(chosen.point); await settle()
		check("actual organism selection opens the concise strip",ui.context_panel.visible and not ui.context_title.text.is_empty())
		await capture("fish-selected")
		main._clear_observation_selection()
	check("pullback path preserves the atmosphere introduction",main.observation_parent("reef")=="pacific" and main.observation_parent("pacific")=="atmosphere" and main.observation_parent("atmosphere")=="earth")
	main._clear_observation_selection()
	for parent: String in ["pacific","atmosphere","earth"]:
		main._navigate_relative(-1)
		if not await ready_stage(): return
		check("ocean reverse path returns to "+parent,main.world.current_scale_id==parent)

func panels() -> void:
	var ui: Node = main.immersive_interface
	gui_click(ui.search_button.get_global_rect().get_center()); await settle(); await capture("world-guide"); check("search icon opens the guide",main.world_guide.visible)
	main.world_guide.search.text="海龟"; main.world_guide._filter_routes("海龟"); await settle()
	check("world guide search remains functional",not main.world_guide._no_results()); await capture("guide-search")
	main.world_guide.show_ecology(true); await settle(); await capture("ecology-map")
	check("ecology relationships retain their on-demand page",main.world_guide.ecology_map.is_visible_in_tree())
	main.world_guide.show_species(true); await settle(); await capture("species-atlas")
	var atlas: Node = main.world_guide.species_atlas
	atlas.search.text="银杏"; atlas._apply_filters(); await settle()
	check("species atlas preserves real species filtering",atlas.count.text.begins_with("显示 1 /")); await capture("atlas-search")
	get_window().size=Vector2i(900,650); await settle(); await capture("atlas-compact")
	check("compact atlas modal fits the window",Rect2(Vector2.ZERO,Vector2(900,650)).encloses(main.world_guide.panel.get_global_rect()))
	get_window().size=Vector2i(1280,800); await settle()
	main.world_guide.hide()
	gui_click(ui.knowledge_button.get_global_rect().get_center()); await settle(); await capture("knowledge")
	check("knowledge panel can scroll",main.explorer_panel.scroll.is_visible_in_tree())
	main._escape_navigation(); check("Esc closes knowledge before navigating",not main.explorer_panel.visible and main.world.current_scale_id=="earth"); await settle()
	gui_click(ui.source_button.get_global_rect().get_center()); await settle(); await capture("science")
	check("scientific explanation and provenance remain available",main.info_panel.visible and main.info_label.text.length()>150)
	main._escape_navigation()
	main._toggle_observation(); await settle(); await capture("observations")
	check("influence and history tabs remain accessible",main.observation_panel.tabs.get_tab_count()==2)
	main._escape_navigation()
	ui._menu_action(2); await settle(); await capture("sound")
	check("sound setting menu opens the actual sound panel",main.sound_panel.visible)
	main._escape_navigation()
	gui_click(main.pause_button.get_global_rect().get_center()); check("new icon resumes authoritative time",not main.world.paused)
	gui_click(main.pause_button.get_global_rect().get_center()); check("new icon pauses authoritative time",main.world.paused)
	ui._set_rate(3); check("new rate menu sets the real world multiplier",main.world.time_scale==2.0); ui._set_rate(2)
	gui_click(ui.menu_button.get_global_rect().get_center()); await settle(); check("tool menu opens from real viewport input",ui.menu_button.get_popup().visible); await capture("tools-menu")
	ui.menu_button.get_popup().hide()
	ui._menu_action(9); check("reduced motion setting remains functional",not main._reduced_motion); ui._menu_action(9)
	ui._menu_action(8); check("quality setting remains functional",main._render_ratio==1.0); ui._menu_action(8)
	main.guided_journey.open("world"); await settle(); await capture("world-journey")
	check("world route still includes the atmosphere",main.guided_journey.route.has("atmosphere"))
	main.guided_journey.suspend()
	if not await ready_stage(): return
	get_window().size=Vector2i(900,650); await settle(); main._toggle_info(); await settle(); await capture("science-compact")
	check("compact scientific inspector fits the window",main.info_panel.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(900,650)).encloses(main.info_panel.get_global_rect()))
	main.info_panel.hide(); record_layout("compact interface")
	get_window().size=Vector2i(1280,800); await settle()
	if not await arrive("solar_system"): return
	main.open_size_comparison(); await settle(); await capture("solar-size")
	check("same-scale celestial comparison remains available",main.size_comparison.is_visible_in_tree() and main.size_comparison.ratio_text.text.contains("地球"))
	main.size_comparison.close()

func scales() -> void:
	var picture: Array[String] = ["galaxy","solar_system","heart","mitochondrion","city","woodland","desert","polar"]
	for id: String in ZOOM_SCALES:
		if not await arrive(id): return
		main._clear_observation_selection(); main._reset_camera(); await settle()
		record_layout(id)
		var before: float = radius(); magnify(1.03)
		check(id+" new chrome leaves world pinch operational",radius()<before and not main.coordinator.is_busy()); magnify(1.0/1.03)
		check(id+" breadcrumb follows the actual scale",not main.navigation_bar.path_buttons.is_empty() and main.navigation_bar.path_buttons[-1].get_meta("scale")==id)
		if picture.has(id): await capture(id)
		if id in ["solar_system","mitochondrion"]:
			var hit: Dictionary = visible_choice()
			check(id+" actual geometry has a selectable object",not hit.is_empty())
			if not hit.is_empty():
				click(hit.point); await settle()
				check(id+" object selection reveals contextual knowledge",main.immersive_interface.context_panel.visible and not main.immersive_interface.context_title.text.is_empty())
				await capture(id+"-selected")
				main._escape_navigation(); await settle()
				check(id+" Esc clears context before navigation",not main.immersive_interface.context_panel.visible and main.world.current_scale_id==id)
	check("all existing scales were reachable",main.world.current_scale_id=="jupiter_moons")

func finish() -> void:
	FileAccess.open(directory.path_join("layout.json"),FileAccess.WRITE).store_string(JSON.stringify(layouts,"\t")+"\n")
	await super.finish()
