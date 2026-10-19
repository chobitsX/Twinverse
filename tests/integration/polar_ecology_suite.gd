extends "res://tests/integration/world_expansion_suite.gd"
## One short real-renderer check; no user save, native input or performance sampling.
const Seasons = preload("res://scripts/experience/season_observation.gd")
const Geometry = preload("res://scripts/core/ground_sky.gd")
const Sites = preload("res://scripts/data/earth_sites.gd")
var observations: Dictionary = {}

func settle() -> void:
	for frame: int in range(4): await get_tree().process_frame

func capture(label: String) -> void:
	if not "--polar267-system-capture" in OS.get_cmdline_user_args():
		await super.capture(label)
		return
	# Repeated Viewport readback corrupts static Canvas draws in this Release.
	# Let the bounded background observer read the already-presented OS window.
	for frame: int in range(3): await RenderingServer.frame_post_draw
	FileAccess.open(directory.path_join(label+".ready"),FileAccess.WRITE).store_string("presented\n")
	var deadline: int=Time.get_ticks_msec()+4000
	while not FileAccess.file_exists(directory.path_join(label+".captured")) and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	var image: Image=Image.load_from_file(directory.path_join(label+".png")) if FileAccess.file_exists(directory.path_join(label+".png")) else null
	check("capture "+label,image!=null and not image.is_empty())
	captures.append(label+".png")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--polar267-output="): directory=argument.trim_prefix("--polar267-output=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true
	get_viewport().gui_disable_input=true
	get_window().size=Vector2i(1280,800)
	Engine.max_fps=5
	main=Experience.instantiate()
	add_child(main)
	# The existing visible diagnostic policy avoids activating the user's desktop.
	main._measurement_screen=get_window().current_screen
	main._audio.volume_db=-80.0
	get_tree().create_timer(70.0).timeout.connect(func() -> void: get_tree().quit(2))
	if not await ready_stage(): await finish(); return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world.simulation_time_s=12.0
	main.set_solar_rate(0.0)
	main.world_guide.hide()
	main.explorer_panel.hide()
	var authority_id: int=main.world.get_instance_id()
	if not await arrive("polar"): await finish(); return
	await settle()
	var south: Node=main.coordinator.active_scene
	var landscape: Dictionary=south.get_meta("polar_environment")
	check("Antarctic wildlife identities and counts remain",south.get_meta("polar").birds.size()==4 and south.get_meta("ice_krill").animals.size()==12)
	check("Antarctic glacier and iceberg geometry is present",landscape.root.has_node("WestGlacier_SnowAndBlueIce") and landscape.root.has_node("NearIceberg_BlueCrevasses") and not landscape.arctic)
	var glacier: MeshInstance3D=landscape.root.get_node("WestGlacier_SnowAndBlueIce")
	var normals: PackedVector3Array=glacier.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check("glacier crown normals face upwards",normals[1].y>.5 and normals[2].y>.5)
	check("sky reuses 8404 catalog entries and bounded curtains",landscape.star_count==8404 and landscape.curtains.size()==3)
	var panel: Node=main.explorer_panel
	panel.show(); panel._process(0.0)
	var prior_date: float=main.solar_jd
	check("aurora theme selection does not silently change date",panel.select_topic("polar_aurora") and main.solar_jd==prior_date and panel.polar_sky_controls.visible)
	panel.polar_sky_controls.get_child(1).pressed.emit()
	panel.hide(); main._reset_camera(); await settle()
	check("summer daylight hides authored aurora",south.get_meta("sun_elevation")>30.0 and landscape.night==0.0 and landscape.curtains[0].get_shader_parameter("night_strength")==0.0)
	await capture("antarctic-summer-ice")
	panel.show(); panel._process(0.0); panel.select_topic("polar_aurora")
	panel.polar_sky_controls.get_child(0).pressed.emit()
	panel.hide(); await settle()
	var south_night_jd: float=main.solar_jd
	check("explicit winter midnight uses the original date authority",south.get_meta("sun_elevation")< -40.0 and main.solar_rate==0.0 and main.world.paused)
	check("south sky basis follows common date and site",landscape.sky_root.basis.is_equal_approx(Geometry.inertial_to_local(main.solar_jd,Sites.for_scale("polar"))))
	check("night sky and author curtains are enabled",landscape.night>.99 and landscape.stars.get_shader_parameter("night_strength")>.8)
	south.builder.update_camera(south)
	check("camera updates preserve winter night fog",south.environment.fog_light_color.b<.08)
	await capture("antarctic-winter-aurora")
	var frozen_phase: float=landscape.curtains[0].get_shader_parameter("world_time")
	await settle()
	check("paused world freezes both water and curtain phase",frozen_phase==12.0 and landscape.curtains[0].get_shader_parameter("world_time")==frozen_phase and south.world_root.get_node("OpenSouthernOceanReference").get_active_material(0).get_shader_parameter("world_time")==12.0)
	main.world.simulation_time_s=20.0
	await settle()
	check("seeking the one world time updates environmental motion",landscape.curtains[0].get_shader_parameter("world_time")==20.0 and main.solar_jd==south_night_jd)
	await capture("antarctic-aurora-motion")
	if "--polar267-ui-probe" in OS.get_cmdline_user_args():
		# Diagnose the Release-only static canvas loss without modifying product UI.
		await capture("motion-ui-later")
		var pending: Array[Node]=[main.hud]
		var redrawn: int=0
		while not pending.is_empty():
			var item: Node=pending.pop_back()
			pending.append_array(item.get_children())
			if item is Control and item.is_visible_in_tree():
				item.queue_redraw()
				redrawn+=1
		await settle()
		await capture("motion-ui-redraw")
		print("POLAR267_UI_PROBE ",JSON.stringify({"visible_controls_redrawn":redrawn,"world_time_s":main.world.simulation_time_s,"date_unchanged":main.solar_jd==south_night_jd}))
	var before_image: Image=Image.load_from_file(directory.path_join("antarctic-winter-aurora.png"))
	var after_image: Image=Image.load_from_file(directory.path_join("antarctic-aurora-motion.png"))
	var sky_area: Rect2i=Rect2i(before_image.get_width()/4,before_image.get_height()*3/10,before_image.get_width()/2,before_image.get_height()/4)
	check("rendered aurora pixels change at fixed date and camera",before_image.get_region(sky_area).get_data()!=after_image.get_region(sky_area).get_data())
	panel.show(); panel._process(0.0)
	check("original krill topic remains reachable",panel.select_topic("ice_krill_habitat"))
	panel.hide(); await settle()
	check("underwater hides far landscape and sky without losing krill",south.is_underwater and not landscape.root.visible and south.get_meta("ice_krill").animals.size()==12)
	check("winter sky colour does not darken original underwater fill",south.environment.ambient_light_color.r>.7)
	await capture("antarctic-krill-preserved")
	if not await arrive("earth"): await finish(); return
	main.explorer_panel.hide(); await settle()
	check("Earth has a distinct Arctic surface region",main.earth_entry_panel.ORDER.has("arctic") and main.coordinator.active_scene.get_meta("earth_entry_markers").has("arctic"))
	main.earth_entry_panel.select_region("arctic")
	check("Arctic selection names the correct world branch",main.earth_entry_panel.selected=="arctic" and main.earth_entry_panel.card_title.text.contains("北极"))
	main.earth_entry_panel.enter_selected()
	if not await ready_stage(): await finish(); return
	var north: Node=main.coordinator.active_scene
	check("Earth region enters Arctic without changing shared date",main.world.current_scale_id=="arctic" and main.solar_jd==south_night_jd)
	var northscape: Dictionary=north.get_meta("polar_environment")
	check("Arctic is sea ice rather than Antarctic wildlife",northscape.arctic and northscape.root.has_node("ArcticObservationIce_SnowMantle") and not north.has_meta("polar") and not north.has_meta("ice_krill") and north.asset_scenes.is_empty())
	check("same June date gives opposite polar daylight",north.get_meta("sun_elevation")>0.0 and northscape.night==0.0)
	panel.show(); panel._process(0.0)
	check("Arctic aurora theme and explicit controls work",panel.select_topic("polar_aurora") and panel.polar_sky_controls.visible)
	panel.polar_sky_controls.get_child(1).pressed.emit()
	panel.hide(); main._reset_camera(); await settle()
	check("Arctic summer sun hides the night illustration",north.get_meta("sun_elevation")>30.0 and northscape.night==0.0)
	await capture("arctic-summer-ice")
	panel.show(); panel._process(0.0); panel.select_topic("polar_aurora")
	panel.polar_sky_controls.get_child(0).pressed.emit()
	panel.hide(); await settle()
	check("Arctic winter night is computed at 78 north",north.get_meta("sun_elevation")< -30.0 and northscape.night>.99 and northscape.sky_root.basis.is_equal_approx(Geometry.inertial_to_local(main.solar_jd,Sites.for_scale("arctic"))))
	await capture("arctic-winter-aurora")
	var night_jd: float=main.solar_jd
	# Window dimensions are physical pixels; exercise a 900x650 logical layout on HiDPI.
	get_window().size=Vector2i(Vector2(900,650)*main.ui_scale)
	panel.show(); panel._process(0.0); await settle()
	check("narrow knowledge panel and transport remain inside window",Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).encloses(panel.get_global_rect()) and Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).encloses(main.immersive_interface.transport.get_global_rect()))
	await capture("arctic-knowledge-narrow")
	get_window().size=Vector2i(Vector2(1280,800)*main.ui_scale)
	panel.hide()
	main.navigation_bar.earth_button.pressed.emit()
	if not await ready_stage(): await finish(); return
	check("Arctic return restores Earth and keeps time and authority",main.world.current_scale_id=="earth" and main.world.get_instance_id()==authority_id and main.solar_jd==night_jd and main.world.simulation_time_s==20.0 and main.world.paused)
	check("resource and user-save limits stay applied",not main._persistence_enabled and get_viewport().gui_disable_input and get_window().unfocusable and Engine.max_fps<=5 and ProjectSettings.get_setting("threading/worker_pool/max_threads")==2)
	observations={"south_night_jd":south_night_jd,"north_night_jd":night_jd,"world_time_s":20.0,"catalog_stars":8404,"screen":get_window().current_screen,"screen_count":DisplayServer.get_screen_count(),"primary_screen":DisplayServer.get_primary_screen(),"render_ratio":main._render_ratio,"world_identity_preserved":main.world.get_instance_id()==authority_id,"performance_test":false,"native_input_tested":false}
	await finish()

func finish() -> void:
	var report: Dictionary={"status":"completed","cases":cases,"failures":failures,"captures":captures,"observations":observations,"renderer":RenderingServer.get_current_rendering_driver_name(),"debug":OS.is_debug_build(),"performance_test":false,"native_input_tested":false}
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("POLAR267_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
