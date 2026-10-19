extends "res://tests/integration/spatial_input_suite.gd"
## Finite native Retina layout and viewport-routed input checks; no user saves.
var basic: bool=false

func gui_click(point: Vector2) -> void:
	# Retain GUI mouse focus across the complete press/release, like real input.
	get_viewport().gui_disable_input=false
	get_viewport().notify_mouse_entered()
	var motion: InputEventMouseMotion=InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point
	get_viewport().push_input(motion,true)
	for down: bool in [true,false]:
		var event: InputEventMouseButton=InputEventMouseButton.new()
		event.position=point; event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		get_viewport().push_input(event,true)
	get_viewport().gui_disable_input=true

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui263-output="): directory=argument.trim_prefix("--ui263-output=")
		if argument=="--ui263-basic": basic=true
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(90).timeout.connect(func() -> void: get_tree().quit(2))
	main=Experience.instantiate(); main.world.set_paused(true); add_child(main)
	main._measurement_screen=get_window().current_screen; main._reduced_motion=true
	if is_instance_valid(main._audio): main._audio.volume_db=-80
	if not await ready_stage(): await finish(); return
	original_id=main.world.get_instance_id(); original_time=main.world.simulation_time_s; original_jd=main.solar_jd
	main.world_guide.hide(); main.explorer_panel.show(); main.message_label.text=""
	await settle(); await settle()
	check("native Retina scale follows the actual display",is_equal_approx(main.ui_scale,DisplayServer.screen_get_scale(get_window().current_screen)))
	check("HUD logical extent and native 3D pixels remain separate",main.hud.size.is_equal_approx(get_viewport().get_visible_rect().size/main.ui_scale) and main.coordinator.active_scene.viewport.size==get_window().size)
	check("readable body, navigation and date text",main.explorer_panel.summary_text.get_theme_font_size("font_size")==18 and main.navigation_bar.path_buttons[-1].get_theme_font_size("font_size")==16 and main.time_label.get_theme_font_size("font_size")>=16)
	check("UI glyphs rasterize at Retina density",is_equal_approx(main.hud.theme.default_font.oversampling,main.ui_scale) and main.hud.theme.default_font.has_char("鉴".unicode_at(0)) and main.object_pointer.theme==main.hud.theme)
	check("collapsed knowledge floats by content height",main.explorer_panel.size.y<main.ui_view_size().y-180 and not main.explorer_panel.observation_body.visible and not main.explorer_panel.science_body.visible)
	await earth_ui()
	await tools_ui()
	if not basic:
		await small_window()
		await solar_ui()
		await night_ui()
		await ecology_ui()
	check("one unchanged World, paused authority and no user save",main.world.get_instance_id()==original_id and main.world.simulation_time_s==original_time and main.world.paused and not main._persistence_enabled)
	check("single short five FPS diagnostic, two workers",Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	await finish()

func in_window(control: Control) -> bool:
	return Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).grow(1).encloses(control.get_global_rect())

func earth_ui() -> void:
	var stage: Node=main.coordinator.active_scene
	var region: Dictionary=main.Sites.for_scale("night_sky")
	stage.set_pose(main.Sites.normal(region.lat,region.lon)*9.6,Vector3.ZERO)
	await settle(); main.earth_entry_panel.refresh_points()
	check("knowledge leaves the neighboring globe selectable",main.earth_entry_panel.available() and main.earth_entry_panel.points.has("night_sky"))
	if main.earth_entry_panel.points.has("night_sky"):
		click(main.earth_entry_panel.points.night_sky.pixel); await settle()
		check("native camera pixel selects the real Earth region",main.earth_entry_panel.selected=="night_sky" and not main.coordinator.is_busy())
		check("A summary follows the real 3D selection",main.explorer_panel.selection_title.text.contains("阿塔卡马") and main.explorer_panel.summary_text.text.contains("共同日期"))
	check("A panel and readable transport fit native window",in_window(main.explorer_panel) and in_window(main.immersive_interface.transport))
	var pose: Transform3D=stage.camera.transform
	magnify(1.2,main.explorer_panel.get_global_rect().get_center())
	check("scaled UI hit region blocks camera gestures",stage.camera.transform.is_equal_approx(pose))
	magnify(1.04,Vector2(950,350)*main.ui_scale)
	check("pinch next to the knowledge panel reaches 3D",radius()<pose.origin.length())
	stage.set_pose(pose.origin,Vector3.ZERO)
	await capture("earth-A-selected")
	gui_click(main.explorer_panel.observation_toggle.get_global_rect().get_center()); await settle()
	check("real GUI click opens observation accordion",main.explorer_panel.observation_body.visible)
	await capture("earth-topics")
	main.explorer_panel._observation_open=false; main.explorer_panel._present_sections(); await settle()
	gui_click(main.explorer_panel.details_toggle.get_global_rect().get_center()); await settle()
	check("real GUI click opens science accordion",main.explorer_panel.science_body.visible)
	check("Earth science retains historical image boundaries",main.explorer_panel.detail.text.contains("2004") and main.explorer_panel.detail.text.contains("当前天气"))
	await capture("earth-science")
	main.explorer_panel._science_open=false; main.explorer_panel._present_sections(); await settle()

func tools_ui() -> void:
	main.explorer_panel.hide(); await settle()
	gui_click(main.immersive_interface.search_button.get_global_rect().get_center()); await settle()
	check("labelled guide opens through scaled header",main.world_guide.visible and in_window(main.world_guide.panel))
	main.world_guide.search.text="月相"; main.world_guide._filter_routes("月相"); await settle()
	check("guide keeps actual search results",main.world_guide.cards[1].node.visible and not main.world_guide.empty_results.visible)
	await capture("guide-search")
	main.world_guide.show_species(true); await settle()
	main.world_guide.species_atlas.search.text="银杏"; main.world_guide.species_atlas._apply_filters(); await settle()
	check("atlas search and cards use readable type",main.world_guide.species_atlas.search.get_theme_font_size("font_size")==18 and main.world_guide.species_atlas.count.text.contains("1"))
	await capture("species-atlas")
	main.world_guide.hide()
	main.sound_panel.show(); await settle()
	check("sound settings remain inside native window",in_window(main.sound_panel))
	await capture("sound-settings"); main.sound_panel.hide()
	main._toggle_info(); await settle()
	check("science sources remain readable and scrollable",in_window(main.info_panel) and main.info_label.get_theme_font_size("normal_font_size")==18 and main.info_label.scroll_active)
	await capture("science-sources"); main.info_panel.hide()
	gui_click(main.immersive_interface.menu_button.get_global_rect().get_center()); await settle()
	check("separate native popup inherits display ratio",main.immersive_interface.menu_button.get_popup().visible and is_equal_approx(main.immersive_interface.menu_button.get_popup().content_scale_factor,main.ui_scale))
	var popup_image: Image=main.immersive_interface.menu_button.get_popup().get_texture().get_image()
	check("native menu image is readable",popup_image.get_width()>=400)
	check("capture native menu",popup_image.save_png(directory.path_join("menu-window.png"))==OK)
	captures.append("menu-window.png")
	records.append({"kind":"ui","native_pixels":str(get_window().size),"logical_points":str(main.ui_view_size()),"scale":main.ui_scale,"menu_pixels":str(popup_image.get_size())})
	main.immersive_interface.menu_button.get_popup().hide()
	main.clean_observation.set_active(true); await settle()
	check("clean observation has readable scaled escape",main.clean_observation.visible and in_window(main.clean_observation.exit_button) and is_equal_approx(main.clean_observation.scale.x,main.ui_scale))
	await capture("clean-view"); main.clean_observation.set_active(false)
	main.explorer_panel.show(); await settle()

func small_window() -> void:
	get_window().size=Vector2i(Vector2(640,440)*main.ui_scale); await settle(); await settle()
	check("small window uses scroll without reducing text",in_window(main.explorer_panel) and main.explorer_panel.summary_text.get_theme_font_size("font_size")==18 and main.explorer_panel.scroll.get_v_scroll_bar().visible)
	check("small header and transport remain inside window",in_window(main.immersive_interface.header) and in_window(main.immersive_interface.transport) and in_window(main.immersive_interface.menu_button))
	await capture("small-knowledge")
	main.explorer_panel.hide(); main.world_guide.open(); await settle()
	check("small guide stays inside the window",in_window(main.world_guide.panel))
	await capture("small-guide")
	main.world_guide.hide()
	get_window().size=Vector2i(Vector2(1280,800)*main.ui_scale); await settle(); await settle()

func solar_ui() -> void:
	if not await arrive("solar_system"): return
	main.set_solar_rate(1./24.); main.explorer_panel.show(); await settle(); await settle()
	check("solar default avoids a wall of parameters",not main.explorer_panel.science_body.visible and not main.explorer_panel.observation_body.visible)
	main.explorer_panel.hide(); await settle()
	var stage: Node=main.coordinator.active_scene
	var point: Vector2=stage.camera.unproject_position(stage.get_meta("solar_bodies")[4].node.global_position)
	cursor(point); main.object_pointer.cursor=point; main.object_pointer.pending=true; main.object_pointer.cooldown=0.; main.object_pointer._process(.17)
	await settle()
	check("solar hover uses camera pixels and a readable scaled caption",main.object_pointer.tooltip.visible and main.object_pointer.tooltip.text=="木星" and in_window(main.object_pointer.tooltip) and is_equal_approx(main.object_pointer.tooltip.scale.x,main.ui_scale))
	await capture("solar-hover")
	main.object_pointer.clear_hover(); main.explorer_panel.show(); await settle()
	main.explorer_panel._observation_open=true; main.explorer_panel._present_sections(); await settle()
	main.explorer_panel.toggle_solar_comparison(); await settle()
	check("existing solar comparison still reads eight planets",main.explorer_panel.solar_comparison.visible and main.explorer_panel.solar_comparison.entries.size()==8)
	main.explorer_panel.scroll.ensure_control_visible(main.explorer_panel.solar_comparison); await settle()
	await capture("solar-comparison")
	main.explorer_panel.solar_comparison.hide(); main.explorer_panel._observation_open=false; main.explorer_panel._science_open=true; main.explorer_panel._astro_open=true; await settle()
	check("shared date and system rate remain authoritative",main.solar_rate==1./24. and main.explorer_panel.solar.visible and main.time_label.text.contains("TDB"))
	check("astronomy rate is readable without rounding authority",main.explorer_panel.date_text.text.contains("每世界秒 1 小时") and main.solar_rate==1./24.)
	await capture("solar-science")
	main.explorer_panel.hide()
	main.open_size_comparison(); await settle()
	check("size comparison keeps the same ratio with readable controls",main.size_comparison.visible and in_window(main.size_comparison.panel))
	await capture("solar-size"); main.size_comparison.close()

func night_ui() -> void:
	if not await arrive("night_sky"): return
	main.explorer_panel.hide(); await settle()
	records.append({"kind":"night UI","credit":str(main.immersive_interface.sky_credit.get_global_rect()),"credit_size":str(main.immersive_interface.sky_credit.size),"transport":str(main.immersive_interface.transport.get_global_rect()),"visible":main.immersive_interface.sky_credit.visible,"unobstructed":str([main.info_panel.visible,main.observation_panel.visible,main.explorer_panel.visible,main.size_comparison.visible,main.world_guide.visible,main.guided_journey.visible])})
	check("night date, rate and attribution fit the window",in_window(main.immersive_interface.transport) and in_window(main.immersive_interface.sky_credit) and main.immersive_interface.sky_credit.visible)
	await capture("night-sky")
	main.clean_observation.set_active(true); await settle()
	check("night attribution survives clean UI",main.immersive_interface.sky_credit.is_visible_in_tree())
	main.clean_observation.set_active(false)

func ecology_ui() -> void:
	if not await arrive("city"): return
	check("city lesson opens real wrapped controls",main.explorer_panel.open_topic("runoff"))
	await settle(); await settle()
	check("lesson stays reachable with readable card",main.explorer_panel.observation_body.visible and in_window(main.explorer_panel) and main.explorer_panel.runoff_balance.visible)
	main.explorer_panel.scroll.ensure_control_visible(main.explorer_panel.runoff_balance); await settle()
	await capture("city-lesson")
	main.explorer_panel.hide(); main._toggle_observation(); await settle()
	check("influence journal fits the same UI system",in_window(main.observation_panel) and main.observation_panel.journal.get_theme_font_size("normal_font_size")==18)
	await capture("observation-journal"); main.observation_panel.hide()
	main.guided_journey.open("world")
	if not await ready_stage(): return
	await settle(); await settle()
	check("guided journey preserves readable content",in_window(main.guided_journey) and main.guided_journey.description.get_theme_font_size("font_size")==18)
	await capture("guided-journey")
