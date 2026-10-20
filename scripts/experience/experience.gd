extends Node
const I18n = preload("res://scripts/core/app_text.gd")
## The only owner of world state, navigation, sound and experience input.

const Oxygen = preload("res://scripts/core/oxygen_atom.gd")
const WorldState = preload("res://scripts/core/world_state.gd")
const WorldStore = preload("res://scripts/core/world_store.gd")
const Catalog = preload("res://scripts/core/scale_catalog.gd")
const Coordinator = preload("res://scripts/core/transition_coordinator.gd")
const Recorder = preload("res://scripts/core/performance_recorder.gd")
const RenderQuality = preload("res://scripts/experience/render_quality.gd")
const MotionRecorder = preload("res://scripts/core/motion_recorder.gd")
const Stage = preload("res://scripts/experience/visual_stage.gd")
const ObservationPanel = preload("res://scripts/experience/observation_panel.gd")
const ScienceReference = preload("res://scripts/experience/science_reference.gd")
const SolarSizeComparison = preload("res://scripts/experience/solar_size_comparison.gd")
const LoadingStatus = preload("res://scripts/experience/loading_status.gd")
const CleanObservation = preload("res://scripts/experience/clean_observation.gd")
const ObjectPointer = preload("res://scripts/experience/object_pointer.gd")
const NavigationBar = preload("res://scripts/experience/navigation_bar.gd")
const InterfaceTheme = preload("res://scripts/experience/interface_theme.gd")
const ImmersiveInterface = preload("res://scripts/experience/immersive_interface.gd")
const GuidedJourney = preload("res://scripts/experience/guided_journey.gd")
const WorldGuide = preload("res://scripts/experience/world_guide.gd")
const ExplorerPanel = preload("res://scripts/experience/explorer_panel.gd")
const EarthEntryPanel = preload("res://scripts/experience/earth_entry_panel.gd")
const EarthRegionFlight = preload("res://scripts/experience/earth_region_flight.gd")
const LearningOverlay = preload("res://scripts/experience/learning_overlay.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Sites = preload("res://scripts/data/earth_sites.gd")
const LunarObservation = preload("res://scripts/experience/lunar_observation.gd")
const Kepler = preload("res://scripts/experience/kepler_observation.gd")
const Jovian = preload("res://scripts/core/jovian_ephemeris.gd")
const Satellites = preload("res://scripts/core/natural_satellites.gd")
const SatelliteBuilder = preload("res://scripts/experience/satellite_system_builder.gd")
const SolarSatellites = preload("res://scripts/experience/solar_satellite_view.gd")
const SolarPhysical = preload("res://scripts/experience/solar_physical_context.gd")
const SolarContextCompass = preload("res://scripts/experience/solar_context_compass.gd")
const SatelliteFraming = preload("res://scripts/experience/satellite_framing.gd")
const SolarCloseup = preload("res://scripts/experience/solar_closeup.gd")
const OpticalInspector = preload("res://scripts/experience/solar_optical_inspector.gd")
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const GroundSky = preload("res://scripts/experience/ground_sky_builder.gd")
const DEFAULT_SOLAR_RATE: float = 10.0
const Soundscape = preload("res://scripts/experience/soundscape.gd")
const BUILDERS: Array[Script] = [
	GroundSky,
	preload("res://scripts/experience/ocean_builder.gd"),
	preload("res://scripts/experience/anatomy_builder.gd"),
	preload("res://scripts/experience/cosmos_builder.gd"),
	preload("res://scripts/experience/micro_builder.gd"),
	preload("res://scripts/experience/land_builder.gd"),
	preload("res://scripts/experience/desert_builder.gd"),
	preload("res://scripts/experience/polar_builder.gd"),
	preload("res://scripts/experience/jovian_builder.gd"),
	SatelliteBuilder,
]
const STAGE_PATHS: Dictionary = {
	"night_sky":"ground_sky",
	"mars_moons":"satellites", "saturn_moons":"satellites", "uranus_moons":"satellites", "neptune_moons":"satellites",
	"jupiter_moons":"jovian", "desert":"desert", "polar":"polar", "arctic":"arctic", "woodland":"land", "city":"land", "earth_moon":"cosmos",
	"universe":"cosmos", "galaxy": "cosmos", "solar_system": "cosmos", "earth": "cosmos", "atmosphere": "cosmos",
	"pacific": "ocean", "reef": "ocean", "school": "ocean", "fish": "ocean",
	"heart": "anatomy", "cardiomyocyte": "micro", "mitochondrion": "micro", "molecule": "micro", "atom": "micro",
}
const SUBTITLES: Dictionary = {
	"night_sky":"ATACAMA / GROUND OBSERVER · ENHANCED EXPOSURE",
	"jupiter_moons":"JUPITER / NATURAL SATELLITES · JPL HORIZONS",
	"mars_moons":"MARS / PHOBOS & DEIMOS · JPL HORIZONS",
	"saturn_moons":"SATURN / NATURAL SATELLITES · JPL HORIZONS",
	"uranus_moons":"URANUS / NATURAL SATELLITES · JPL HORIZONS",
	"neptune_moons":"NEPTUNE / NATURAL SATELLITES · JPL HORIZONS",
	"desert":"SONORAN DESERT / SYNTHETIC LOWLAND SCRUB",
	"polar":"ANTARCTIC COAST / SYNTHETIC REFERENCE",
	"arctic":"ARCTIC OCEAN / SEA ICE & NIGHT SKY · AUTHORED REFERENCE",
	"woodland":"LAND ECOSYSTEM / REPRESENTATIVE HABITAT",
	"city":"HUMAN HABITAT / SYNTHETIC TEACHING CITY",
	"pacific": "CORAL SEA  /  14°40′ S · 145°28′ E",
	"reef": "LIZARD ISLAND  /  GREAT BARRIER REEF",
	"school": "ANEMONE ASSOCIATION  /  LOCAL HABITAT",
	"fish": "AMPHIPRION PERCULA  /  80 mm",
	"heart": "TELEOST HEART  /  SCIENTIFIC ILLUSTRATION",
	"earth": "OUR HOME  /  BLUE MARBLE 2004",
	"atmosphere": "EARTH · ATMOSPHERE  /  CORAL SEA",
}

var loading_status: PanelContainer
var clean_observation: VBoxContainer
var optical_inspector: Control
var object_pointer: Control
var clean_button: Button
var immersive_interface: Control
var navigation_bar: HBoxContainer
var size_comparison: Control
var guided_journey: PanelContainer
var _journey_restore: Dictionary = {}
var world_guide: Control
var _first_visit: bool = false
var _guide_visit: Dictionary = {}
var _recovery_guide: Dictionary = {}
var recovery_actions: HBoxContainer
var retry_button: Button
var learning_overlay: Control
var _earth_reference: String = "reef"
var explorer_panel: PanelContainer
var earth_entry_panel: PanelContainer
var solar_jd: float = Ephemeris.DEFAULT_JD
var solar_rate: float = 0.0
const SOLAR_CLOSE_RATE: float = 1.0/24.0
# Observer preference only; every body still reads the single solar_jd.
var _solar_close_playback: Dictionary = {}
var _earth_bridge: Dictionary = {}
var _satellite_bridge: Dictionary = {}
var _satellite_zoom_return: bool = false
# Camera gesture state only. A single outward gesture must settle at the solar
# overview before a fresh gesture can cross the next semantic boundary.
const SOLAR_ZOOM_RELEASE_MS: int = 260
var _solar_zoom_return_stage: int = 0
var _solar_zoom_out_ms: int = 0
var _solar_render_world_time: float = -1.0
var solar_demo_auto: bool = true
var solar_manual_setting: bool = false
var ground_light_preview: bool = false
var solar_true_distance: bool = false
var solar_follow: int = -1
var solar_orbit_focus: int = -1
var solar_plane_view: String = ""
var _solar_origin_jd: float = Ephemeris.DEFAULT_JD
var _solar_origin_time: float = 0.0
var lunar_observation_view: String = "orbit"
var _content_follow: int = -1
var _direct_content: Dictionary = {}
var _follow_scale: String = ""
var _city_people_view: bool = false
var _city_street_view: bool = false
const CITY_PEOPLE_POSITION: Vector3 = Vector3(58.0, 4.2, 30.0)
const CITY_PEOPLE_TARGET: Vector3 = Vector3(32.0, 1.5, 30.0)
const CITY_STREET_POSITION: Vector3 = Vector3(-5.0, 3.0, 90.0)
const CITY_STREET_TARGET: Vector3 = Vector3(-72.0, 10.0, -170.0)

var world: WorldState = WorldState.new()
var coordinator: Coordinator = Coordinator.new()
var recorder: Recorder = Recorder.new()
var motion: MotionRecorder = MotionRecorder.new()
var _motion_recording: bool = false
var scene_host: Node = Node.new()
var hud: Control
var title_label: Label
var subtitle_label: Label
var context_label: Label
var time_label: Label
var message_label: Label
var debug_label: Label
var science_badge: Label
var info_label: RichTextLabel
var info_panel: PanelContainer
var observation_panel: PanelContainer
var _trial_return: Dictionary = {}
var _trial_views: Dictionary = {}
var _returning_from_trial: bool = false
var _switching_observation: bool = false
var sound_panel: PanelContainer
var sound_context_label: Label
var sound_mute_button: Button
var quality_button: Button
var save_button: Button
var target_button: Button
var next_button: Button
var previous_button: Button
var pause_button: Button
var anatomy_controls: HBoxContainer
var cutaway_button: Button
var _incoming: Node
var _outgoing: Node
var _out_start: Dictionary = {}
var _out_end: Dictionary = {}
var _in_start: Dictionary = {}
var _in_end: Dictionary = {}
var _earth_flight: Dictionary = {}
var _orbit_target: Vector3 = Vector3.ZERO
var _pan_offset: Vector3 = Vector3.ZERO
var _solar_camera_motion: Dictionary = {}
var _reduced_motion: bool = false
var _render_ratio: float = 0.75
var _debug_visible: bool = false
var _muted: bool = false
var _recording: bool = false
var _shutting_down: bool = false
var _start_scale: String = WorldState.INITIAL_SCALE_ID
var _capture_path: String = ""
var _capture_after: float = 3.0
var _run_duration: float = 0.0
var _wall_start_us: int = 0
var _tour: bool = false
var _tour_direction: int = 1
var _next_tour_us: int = 0
var _measurement_screen: int = -1
var _audio: AudioStreamPlayer
var _audio_playback: AudioStreamGeneratorPlayback
var soundscape: Soundscape = Soundscape.new()
var _progress_alpha: float = 0.0
var _run_metadata: Dictionary = {}
var _store: WorldStore
var _persistence_enabled: bool = true
var _views: Dictionary = {}
var _spatial_parents: Dictionary = {}
var _restore_notice: String = ""
var _save_requested: bool = false
var _next_save_us: int = 0
var _save_failure_dialog: ConfirmationDialog
const AUTOSAVE_INTERVAL_US: int = 30000000
var ui_scale: float = 1.0


func ui_view_size() -> Vector2i:
	return Vector2i(Vector2(get_viewport().get_visible_rect().size) / ui_scale)


func _apply_ui_scale() -> void:
	ui_scale = 1.0
	if DisplayServer.get_name()!="headless":
		# macOS window/viewport coordinates use the session's maximum density,
		# including on a 1x external screen. Per-screen density halves the HUD there.
		var density: float = DisplayServer.screen_get_max_scale() if OS.get_name()=="macOS" else DisplayServer.screen_get_scale(get_window().current_screen)
		ui_scale = clampf(density,1.0,3.0)
	if not is_instance_valid(hud): return
	hud.scale = Vector2.ONE * ui_scale
	hud.size = Vector2(ui_view_size())
	InterfaceTheme.fit_fonts(hud.theme,ui_scale)
	InterfaceTheme.fit_popups(hud,ui_scale)
	if is_instance_valid(clean_observation): clean_observation.fit_window(ui_view_size())
	if is_instance_valid(object_pointer): object_pointer.fit_ui_scale()


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--asset-audit="):
			_asset_audit(argument.trim_prefix("--asset-audit="))
			return
	get_tree().auto_accept_quit = false
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().title = I18n.text("孪生宇宙")
	# Keep camera pixels native; only presentation Controls use logical points.
	_apply_ui_scale()
	if DisplayServer.get_name()!="headless" and not "--resolution" in OS.get_cmdline_args():
		var desktop: Rect2i = DisplayServer.screen_get_usable_rect(get_window().current_screen)
		get_window().size = Vector2i(Vector2(1280,800)*ui_scale).min(desktop.size-Vector2i(48,96))
		get_window().position = desktop.position + (desktop.size-get_window().size)/2
	_measurement_screen = int(get_window().get_meta("preview_secondary_screen", -1))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--run-metadata="):
			var metadata_file: String = argument.trim_prefix("--run-metadata=")
			if FileAccess.file_exists(metadata_file):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_file))
				if parsed is Dictionary: _run_metadata = parsed
		if argument.begins_with("--scale="): _start_scale = argument.trim_prefix("--scale=")
		if argument.begins_with("--capture="): _capture_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--capture-after="): _capture_after = float(argument.trim_prefix("--capture-after="))
		if argument.begins_with("--duration="): _run_duration = float(argument.trim_prefix("--duration="))
		if argument == "--tour": _tour = true
		if argument == "--experience-preset": _render_ratio = 0.75
		if argument == "--native-baseline": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if argument == "--mute": _muted = true
		if argument.begins_with("--measurement-screen="):
			var requested_screen: String = argument.trim_prefix("--measurement-screen=")
			if not requested_screen.is_valid_int() or int(requested_screen) < 0:
				push_error("MEASUREMENT_SCREEN_INVALID")
				get_tree().quit(6)
				return
			_measurement_screen = int(requested_screen)
	if _measurement_screen >= 0:
		if DisplayServer.get_name() == "headless" or _measurement_screen >= DisplayServer.get_screen_count() or _measurement_screen == DisplayServer.get_primary_screen():
			push_error("MEASUREMENT_REQUIRES_SECONDARY_SCREEN")
			get_tree().quit(6)
			return
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(_measurement_screen)
		if usable.size.x < 2560 or usable.size.y < 1440 or "--borderless-1440p" in OS.get_cmdline_user_args():
			push_error("MEASUREMENT_SCREEN_CANNOT_FIT_1440P")
			get_tree().quit(6)
			return
		# A titled secondary window stays visible when the user works elsewhere.
		# It never grabs keyboard focus; the ordinary experience keeps its policy.
		get_window().unfocusable = true
		get_window().mode = Window.MODE_WINDOWED
		get_window().borderless = false
		get_window().always_on_top = true
		get_window().current_screen = _measurement_screen
		get_window().size = Vector2i(2560, 1440)
		get_window().position = usable.position + (usable.size - get_window().size) / 2
	# A titled 1440p window is constrained by macOS's usable desktop rectangle.
	# Keep this opt-in measurement surface in the current desktop, outside Spaces.
	if "--borderless-1440p" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_WINDOWED
		get_window().borderless = true
		get_window().position = DisplayServer.screen_get_position(get_window().current_screen)
		get_window().size = Vector2i(2560, 1440)
		get_window().grab_focus.call_deferred()
	var has_record: bool = false
	var has_motion: bool = false
	for argument: String in OS.get_cmdline_user_args():
		has_record = has_record or argument.begins_with("--record=")
		has_motion = has_motion or argument.begins_with("--motion=")
	if has_record and has_motion:
		push_error("Formal performance capture and motion readback must use separate runs")
		get_tree().quit(6)
		return
	if not Catalog.contains(_start_scale): _start_scale = WorldState.INITIAL_SCALE_ID
	_open_world()
	# Explicit diagnostic settings override restored preferences without rewriting saves.
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--quality=economy": _render_ratio = RenderQuality.ECONOMY
		if argument == "--quality=balanced": _render_ratio = RenderQuality.BALANCED
		if argument == "--quality=clear": _render_ratio = RenderQuality.CLEAR
	get_window().set_meta("experience_render_ratio", _render_ratio)
	get_window().set_meta("experience_reduced_motion", _reduced_motion)
	scene_host.name = "ScaleHost"
	add_child(scene_host)
	add_child(coordinator)
	coordinator.configure(world, scene_host)
	coordinator.wait_for_visible_response = DisplayServer.get_name() != "headless"
	coordinator.intent_accepted.connect(_on_intent)
	coordinator.resource_ready.connect(_on_resource_ready)
	coordinator.authoring_started.connect(_on_authoring_started)
	coordinator.authoring_progress.connect(_on_authoring_progress)
	coordinator.interactive.connect(_on_interactive)
	coordinator.recovery_changed.connect(_update_recovery)
	coordinator.transition_failed.connect(_on_failure)
	coordinator.transition_cancelled.connect(_on_cancelled)
	coordinator.recovery_required.connect(func(_reason: String) -> void: message_label.text = I18n.text(I18n.text("加载仍在收尾，当前场景可继续观察")))
	_build_hud()
	get_node("/root/AppLanguage").language_changed.connect(_language_changed)
	get_window().size_changed.connect(_resize)
	if get_window().has_signal("dpi_changed"): get_window().connect("dpi_changed",_resize)
	var path: String = _path_for(_start_scale)
	if not ResourceLoader.exists(path):
		push_error("START_STAGE_MISSING " + path)
		get_tree().quit(2)
		return
	var packed: PackedScene = load(path) as PackedScene
	var stage: Node = packed.instantiate()
	if not coordinator.install_initial(stage, _start_scale, _estimate_mb(_start_scale)):
		stage.free()
		get_tree().quit(3)
		return
	stage.set_opacity(1.0)
	var night_preset: bool=_prepare_ground_sky(stage)
	_orbit_target = stage.default_target
	_resize()
	_update_ui()
	# Every ordinary launch opens on the cosmic overview, even after a saved
	# close-up. Other saved observer views remain available when revisited.
	if _start_scale != WorldState.INITIAL_SCALE_ID: _apply_saved_view(stage)
	pause_button.text = I18n.text(I18n.text("继续时间") if world.paused else I18n.text("暂停时间"))
	message_label.text = I18n.text(_restore_notice)
	if night_preset: message_label.text=I18n.text(I18n.text("已切至观星点的夜空预设 · 下方显示同一天文日期"))
	world.record_observation("continued" if not world.habitat.events.is_empty() else "started")
	_remember_view()
	_setup_sound()
	# Keep the initial universe visible; the guide stays available in the HUD.
	if "--show-knowledge" in OS.get_cmdline_user_args(): world_guide.hide(); explorer_panel.show()
	_wall_start_us = Time.get_ticks_usec()
	_next_save_us = _wall_start_us + AUTOSAVE_INTERVAL_US
	_next_tour_us = _wall_start_us + 8000000
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--record="):
			var output_dir: String = argument.trim_prefix("--record=")
			var metadata: Dictionary = {
				"preset": RenderQuality.label(_render_ratio),
				"render_scale": _render_ratio, "dynamic_resolution": false,
				"upscaling": "none" if _render_ratio == 1.0 else "fsr1" if _render_ratio == 0.5 else "bilinear", "msaa": "4x",
				"warmup_exclusion_s": 60.0, "scenario": "interactive_local_scales", "build_identity": "M0-integration-worktree",
				"window_activity_policy": "visible_secondary" if _measurement_screen >= 0 else "focused",
				"measurement_screen": _measurement_screen,
				"primary_screen": DisplayServer.get_primary_screen() if DisplayServer.get_name() != "headless" else -1,
			}
			metadata.merge(_run_metadata, true)
			var status: Error = recorder.begin(output_dir, metadata)
			_recording = status == OK
			if _recording: coordinator.metrics_recorded.connect(recorder.record_transition)
			else: push_error("RECORDER_START_FAILED " + error_string(status))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--motion="):
			var metadata: Dictionary = {"scenario": "interactive_local_scales", "build_identity": "M0-integration-worktree", "audio_recorded": false, "max_duration_s": 90.0}
			metadata.merge(_run_metadata, true)
			_motion_recording = motion.begin(argument.trim_prefix("--motion="), get_viewport(), metadata) == OK
			if not _motion_recording: push_error("MOTION_START_FAILED")
	print("EXPERIENCE_READY ", JSON.stringify({"scale": _start_scale, "target": WorldState.TARGET_FISH_ID, "driver": RenderingServer.get_current_rendering_driver_name(), "arm64": OS.has_feature("arm64"), "debug_build": OS.is_debug_build(), "output_px": str(get_viewport().get_texture().get_size()), "ratio": _render_ratio, "ui_scale":ui_scale, "logical_ui":str(ui_view_size())}))
	if not _capture_path.is_empty(): _capture_when_ready.call_deferred()


func _open_world() -> void:
	var save_directory: String = "user://world"
	var explicit_directory: bool = false
	var temporary: bool = DisplayServer.get_name() == "headless"
	var no_save: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world-dir="):
			save_directory = argument.trim_prefix("--world-dir=")
			explicit_directory = not save_directory.is_empty()
		if argument == "--no-save": no_save = true
		for prefix: String in ["--scale=", "--suite", "--record=", "--motion=", "--capture=", "--duration=", "--tour"]:
			if argument.begins_with(prefix): temporary = true
	# Diagnostic/fixture launches never read or overwrite the user's world.
	_persistence_enabled = not no_save and (not temporary or explicit_directory)
	if not _persistence_enabled: return
	_store = WorldStore.new(save_directory)
	var result: Dictionary = _store.load_session()
	if result.status in ["ok", "recovered"]:
		world.restore_checkpoint(result.payload.world)
		# Restore the living world and preferences, then choose the requested
		# entry independently of the saved observer location.
		world.current_scale_id = _start_scale
		_views = result.payload.observer.views.duplicate(true)
		_restore_solar_view()
		var preferences: Dictionary = result.payload.observer.preferences
		if preferences.get("guided_journey") is Dictionary: _journey_restore=preferences.guided_journey.duplicate(true)
		_render_ratio = float(preferences.render_ratio)
		_reduced_motion = bool(preferences.reduced_motion)
		_muted = bool(preferences.muted)
		for key: String in ["master", "environment_volume", "music_volume", "effects_volume"]:
			soundscape.set(key, float(preferences[key]))
		if _start_scale == WorldState.INITIAL_SCALE_ID:
			_restore_notice = I18n.text("世界进度已恢复 · 从宇宙开始观察") if result.status == "ok" else I18n.text("已从备份恢复世界进度 · 从宇宙开始观察")
		else:
			_restore_notice = I18n.text("已继续上次观察 · 离线期间时间保持不变") if result.status == "ok" else I18n.text("已从上一份可用存档恢复，继续观察")
	elif result.status == "missing":
		_first_visit = not temporary
		_restore_notice = I18n.text("从宇宙开始探索 · 双击银河进入") if _start_scale == WorldState.INITIAL_SCALE_ID else I18n.text("世界会自动保存，下次打开可继续观察")
	else:
		_restore_notice = I18n.text("存档版本不兼容，本次观察不会覆盖原存档") if result.status == "incompatible" else I18n.text("存档暂时无法读取，本次观察不会覆盖原存档")
	print("WORLD_SESSION ", JSON.stringify({"status": result.status, "scale": _start_scale, "simulation_time_s": world.simulation_time_s}))


func _remember_view() -> void:
	if (coordinator.is_busy() and coordinator.phase != Coordinator.Phase.DRAINING) or not is_instance_valid(coordinator.active_scene): return
	var stage: Node = coordinator.active_scene
	var saved_position: Vector3 = stage.camera.position
	if stage.camera.projection==Camera3D.PROJECTION_ORTHOGONAL:
		saved_position=_orbit_target+stage.camera.basis.z*stage.camera.size/(2.0*tan(deg_to_rad(stage.camera.fov*.5)))
	_views[world.current_scale_id] = {
		"position": WorldStore.components(saved_position),
		"target": WorldStore.components(_orbit_target), "up": WorldStore.components(stage.camera.basis.y),
		"cutaway": bool(stage.get_meta("anatomy_cutaway_active", true)),
		"heart_region": str(stage.get_meta("anatomy_selected_region", "")),
		"info_visible": info_panel.visible,
	}

	_views[world.current_scale_id]["astronomy"] = {"jd":solar_jd,"time":world.simulation_time_s,"rate":solar_rate,"true_distance":solar_true_distance,"ground_light":ground_light_preview,"auto":solar_demo_auto,"manual":solar_manual_setting}
	if (stage.has_meta("natural_satellites") or stage.has_meta("solar_satellite_systems")) and _content_follow>=0:
		var entries: Array[Dictionary] = content_targets(false)
		if _content_follow<entries.size(): _views[world.current_scale_id]["satellite_key"]=str(entries[_content_follow].get("satellite_key",""))
	if world.current_scale_id=="solar_system" and not _solar_close_playback.is_empty():
		_views[world.current_scale_id].astronomy["close_playback"]=_solar_close_playback.duplicate()
	if world.current_scale_id=="solar_system":
		_views[world.current_scale_id]["solar_exploring"]=bool(stage.get_meta("solar_camera_exploring",false))
		_views[world.current_scale_id]["solar_physical_context"]=int(stage.get_meta("solar_physical",{}).get("owner",-1))
		_views[world.current_scale_id]["solar_geometry_version"]=1
		_views[world.current_scale_id]["solar_observer_target"]=solar_follow if solar_follow>=0 else _content_follow+8 if _content_follow>=0 else -1
		_views[world.current_scale_id]["solar_lookaround"]=bool(stage.get_meta("solar_lookaround",false))
		_views[world.current_scale_id]["solar_look_fov"]=stage.camera.fov
	if world.current_scale_id=="earth_moon" or stage.has_meta("natural_satellites"):
		_views[world.current_scale_id]["local_geometry_version"]=1
	if not SatelliteFraming.state(stage).is_empty(): _views[world.current_scale_id]["satellite_framing"]=SatelliteFraming.saved(stage)
	if world.current_scale_id=="night_sky": _views[world.current_scale_id]["sky_fov"]=stage.camera.fov
	if world.current_scale_id=="city":
		_views[world.current_scale_id]["city_people_view"] = _city_people_view
		_views[world.current_scale_id]["city_street_view"] = _city_street_view


func _apply_saved_view(stage: Node) -> void:
	SatelliteFraming.clear(stage)
	if stage.has_meta("natural_satellites") or stage.scale_id=="earth_moon": stage.camera.fov=48.0
	_pan_offset = Vector3.ZERO
	_city_people_view = world.current_scale_id=="city" and bool(_views.get("city",{}).get("city_people_view",false))
	_city_street_view = world.current_scale_id=="city" and bool(_views.get("city",{}).get("city_street_view",false)) and not _city_people_view
	_refresh_city_view_button()
	if not _views.has(world.current_scale_id):
		info_panel.visible = false
		return
	var view: Dictionary = _views[world.current_scale_id]
	if world.current_scale_id=="solar_system":
		var physical_owner: int = int(view.get("solar_physical_context",-1))
		if physical_owner<0 and not _solar_close_playback.is_empty():
			var saved_target: int = int(_solar_close_playback.target)
			physical_owner=saved_target if saved_target<8 else 8 if saved_target==8 else 2 if saved_target==9 else -1
		if physical_owner>=0:
			stage.set_meta("solar_natural_frame",physical_owner if bool(_solar_close_playback.get("context",false)) else -1)
			stage.set_meta("solar_subject_frame",physical_owner if not bool(_solar_close_playback.get("context",false)) else -1)
			var observer_target: int = int(view.get("solar_observer_target",physical_owner))
			if observer_target>=0:
				solar_follow=observer_target if observer_target<8 else -1
				_content_follow=observer_target-8 if observer_target in [8,9] else -1
				_begin_solar_close_playback(observer_target)
		stage.builder.set_solar_view(stage,solar_jd,solar_true_distance)
	if world.current_scale_id=="night_sky": stage.camera.fov=clampf(float(view.get("sky_fov",78.0)),1.0,100.0)
	_orbit_target = WorldStore.vector(view.target)
	var restored_position: Vector3 = WorldStore.vector(view.position)
	if stage.has_meta("natural_satellites") and view.has("satellite_key"):
		_content_follow=-1
		var entries: Array[Dictionary] = content_targets(false)
		for i: int in range(entries.size()):
			if str(entries[i].get("satellite_key",""))==str(view.satellite_key):
				if not Satellites.available(solar_jd): break
				if i>0 and not Satellites.has_state(stage.get_meta("natural_satellites").bodies[i-1].record,solar_jd): break
				_content_follow=i
				SatelliteBuilder.select(stage,i)
				var former_center: Vector3 = entries[i].node.position
				if i>0:
					var system: Dictionary = stage.get_meta("natural_satellites")
					var record: Dictionary = system.bodies[i-1].record
					var old_state: Dictionary = Satellites.sample(record,float(view.get("astronomy",{}).get("jd",solar_jd)))
					if old_state.valid: former_center=Satellites.world_position(old_state,float(system.radius_km))
				var displacement: Vector3 = entries[i].node.position-former_center
				_pan_offset=_orbit_target-former_center
				_orbit_target+=displacement
				restored_position+=displacement
				if i>0 and int(view.get("local_geometry_version",0))==0 and not bool(view.get("astronomy",{}).get("true_distance",false)):
					restored_position=entries[i].node.position+(restored_position-entries[i].node.position)*.2
					_orbit_target=entries[i].node.position+(_orbit_target-entries[i].node.position)*.2
					_pan_offset*=.2
				break
	elif stage.has_meta("solar_satellite_systems") and not str(view.get("satellite_key","")).is_empty():
		var entries: Array[Dictionary] = content_targets(false)
		for i: int in range(entries.size()):
			var entry: Dictionary = entries[i]
			if str(entry.get("satellite_key",""))!=str(view.satellite_key): continue
			var index: int = int(entry.host_planet)
			var system: Dictionary = stage.get_meta("solar_satellite_systems")[index]
			for body: Dictionary in system.bodies:
				if str(body.record.key)!=str(view.satellite_key): continue
				var old_jd: float = float(view.get("astronomy",{}).get("jd",solar_jd))
				var old: Dictionary = Satellites.sample(body.record,old_jd)
				if not old.valid or not Satellites.has_state(body.record,solar_jd): break
				var old_mode: bool = bool(view.get("astronomy",{}).get("true_distance",solar_true_distance))
				var old_radius: float = stage.get_meta("solar_bodies")[index].node.mesh.radius*(1.0 if int(view.get("solar_geometry_version",0))==1 else Ephemeris.body_display_scale(index,old_mode))
				var former: Vector3 = Ephemeris.display_position(index,old_jd,old_mode)+Satellites.world_position(old,Ephemeris.RADII_KM[index])*old_radius
				stage.set_meta("solar_satellite_selected_key",str(view.satellite_key))
				stage.builder.set_solar_focus(stage,index)
				stage.builder.set_solar_view(stage,solar_jd,solar_true_distance)
				var displacement: Vector3 = body.node.position-former
				_content_follow=i
				_pan_offset=_orbit_target-former
				_orbit_target+=displacement; restored_position+=displacement
				if int(view.get("solar_geometry_version",0))==0 and not old_mode:
					restored_position=body.node.position+(restored_position-body.node.position)*.2
					_orbit_target=body.node.position+(_orbit_target-body.node.position)*.2
					_pan_offset*=.2
				break
			break
	if world.current_scale_id=="earth_moon" and int(view.get("local_geometry_version",0))==0 and not bool(view.get("astronomy",{}).get("true_distance",false)):
		var conversion: float = Orientation.MOON_A_KM/(8.0*Ephemeris.RADII_KM[2])
		if _content_follow==1 or lunar_observation_view=="earth":
			var old_moon: Vector3 = Orientation.moon_position_km(solar_jd)*(8.0/Orientation.MOON_A_KM)
			var shift: Vector3 = stage.get_meta("lunar").moon.position-old_moon
			restored_position+=shift; _orbit_target+=shift
		else:
			restored_position*=conversion; _orbit_target*=conversion
	if world.current_scale_id=="solar_system" and _content_follow==1 and str(view.get("satellite_key","")).is_empty():
		var old_jd: float = float(view.get("astronomy",{}).get("jd",solar_jd))
		var old_mode: bool = bool(view.get("astronomy",{}).get("true_distance",false))
		var old_moon: Vector3 = Ephemeris.display_position(2,old_jd,old_mode)+Orientation.moon_position_km(old_jd)*(stage.get_meta("solar_bodies")[2].node.mesh.radius/Ephemeris.RADII_KM[2] if int(view.get("solar_geometry_version",0))==1 else 1.25/Orientation.MOON_A_KM*Ephemeris.body_display_scale(2,old_mode))
		if int(view.get("solar_geometry_version",0))==1:
			var centres: Array = SolarPhysical.centres_km(old_jd)
			old_moon=Ephemeris.display_position(2,old_jd,old_mode)+SolarPhysical.relative_world(centres[9],centres[2],stage.get_meta("solar_bodies")[2].node.mesh.radius/Ephemeris.RADII_KM[2])
		var shift: Vector3 = stage.get_meta("solar_moon").node.position-old_moon
		restored_position+=shift; _orbit_target+=shift
	if world.current_scale_id=="solar_system": stage.set_meta("solar_camera_exploring",bool(view.get("solar_exploring",_solar_close_playback.get("context",false))))
	if world.current_scale_id=="solar_system":
		stage.set_meta("solar_lookaround",bool(view.get("solar_lookaround",false)))
		stage.camera.fov=clampf(float(view.get("solar_look_fov",50.0)),.05,80.0)
	stage.set_pose(restored_position, _orbit_target, WorldStore.vector(view.up))
	if world.current_scale_id=="solar_system" and not _solar_close_playback.is_empty() and not bool(_solar_close_playback.get("context",false)):
		stage.builder.set_solar_view(stage,solar_jd,solar_true_distance)
		var target: int=int(_solar_close_playback.target)
		var entries: Array[Dictionary] = content_targets(false)
		var center: Vector3=stage.get_meta("solar_bodies")[target].node.position if target<8 else entries[target-8].node.position if target-8<entries.size() else Vector3.ZERO
		_pan_offset=_orbit_target-center
	if view.has("satellite_framing"):
		SatelliteFraming.restore(stage,view.satellite_framing)
		var framing: Dictionary=SatelliteFraming.state(stage)
		var data: Dictionary=SatelliteFraming.subjects(stage,int(framing.owner),str(framing.key))
		if not data.is_empty():
			stage.camera.near=maxf(.001,minf(float(data.radius)*.005,float(data.moon_radius)*.025))
			if not SatelliteFraming.is_pair(stage): stage.camera.fov=float(framing.get("fov",48.0))
			if SatelliteFraming.is_pair(stage):
				var pair: Dictionary=SatelliteFraming.tracked_pose(stage)
				stage.camera.fov=pair.fov; stage.camera.near=pair.near; _orbit_target=pair.target; _pan_offset=Vector3.ZERO
				stage.set_pose(pair.position,pair.target,pair.up)
		else: SatelliteFraming.clear(stage)
	if world.current_scale_id == "heart":
		stage.builder.set_cutaway(stage, bool(view.cutaway))
		_update_cutaway_button()
		if not str(view.heart_region).is_empty(): _select_heart_region(str(view.heart_region))
	info_panel.visible = bool(view.info_visible)


func save_world(show_feedback: bool = false) -> String:
	if is_trial():
		if show_feedback: message_label.text = I18n.text(I18n.text("临时试览不覆盖原世界；返回后继续保存"))
		return "trial"
	if not _persistence_enabled or _store == null: return "disabled"
	if not is_instance_valid(coordinator.active_scene): return "not_ready"
	if (coordinator.is_busy() and coordinator.phase != Coordinator.Phase.DRAINING) or not coordinator.active_scene.is_prepared():
		_save_requested = true
		if show_feedback: message_label.text = I18n.text(I18n.text("到达可观察位置后自动保存"))
		return "queued"
	_remember_view()
	var preferences: Dictionary = {"render_ratio": _render_ratio, "reduced_motion": _reduced_motion, "muted": _muted}
	for key: String in ["master", "environment_volume", "music_volume", "effects_volume"]:
		preferences[key] = float(soundscape.get(key))
	if is_instance_valid(guided_journey): preferences["guided_journey"]=guided_journey.checkpoint()
	var status: String = _store.save_session({"world": world.checkpoint(), "observer": {"views": _views.duplicate(true), "preferences": preferences}})
	_save_requested = false
	_next_save_us = Time.get_ticks_usec() + AUTOSAVE_INTERVAL_US
	if status == "ok":
		save_button.tooltip_text = I18n.text("已保存至 %.1f 秒 · ⌘S 手动保存；下次打开从这里继续。") % world.simulation_time_s
		if show_feedback: message_label.text = I18n.text(I18n.text("世界已保存 · 下次打开从这里继续"))
	elif _store.protected:
		save_button.text = I18n.text(I18n.text("存档已保护"))
		save_button.disabled = true
		if status == "changed_on_disk": message_label.text = I18n.text(I18n.text("存档已有更新，本窗口停止覆盖保存"))
	elif is_instance_valid(message_label):
		message_label.text = I18n.text(I18n.text("世界暂未保存，请检查磁盘空间或目录权限后重试"))
	print("WORLD_SAVE ", JSON.stringify({"status": status, "scale": world.current_scale_id, "simulation_time_s": world.simulation_time_s}))
	return status


func _path_for(scale_id: String) -> String:
	# Keep the builder/context grouping, but load only this view's resources.
	var resource_group: String = {"woodland":"woodland", "city":"city", "universe":"deep_space", "galaxy":"deep_space", "earth":"earth", "atmosphere":"earth", "earth_moon":"earth_moon"}.get(scale_id, "")
	if not resource_group.is_empty(): return "res://scenes/experience/%s_stage.tscn" % resource_group
	return "res://scenes/experience/%s_stage.tscn" % STAGE_PATHS.get(scale_id, "ocean")


func _estimate_mb(scale_id: String) -> float:
	return {"ocean": 390.0, "anatomy": 190.0, "cosmos": 280.0, "micro": 220.0, "land": 190.0, "polar": 170.0}.get(STAGE_PATHS.get(scale_id, "ocean"), 390.0)


func _process(delta: float) -> void:
	if _shutting_down or not is_instance_valid(coordinator.active_scene): return
	_sync_window_availability()
	var seed_observation: bool = false
	if world.current_scale_id=="desert" and not coordinator.is_busy() and ground_light_preview and world.foreground:
		var site: Dictionary=Sites.for_scale("desert")
		seed_observation=Orientation.local_sun(solar_jd,float(site.lat),float(site.lon)).y<sin(deg_to_rad(-6.0))
	if world.desert_seeds.active!=seed_observation: world.set_desert_seed_active(seed_observation)
	var plankton_observation: bool = world.current_scale_id in ["reef","school"] and not coordinator.is_busy() and world.foreground and explorer_panel._topic.get("id","")=="school"
	if world.zooplankton.active!=plankton_observation: world.set_zooplankton_active(plankton_observation)
	world.advance(delta)
	var reference: Dictionary = world.science.snapshot()
	var browse: Dictionary = world.browse.snapshot()
	var runoff: Dictionary = world.runoff.snapshot()
	var symbiosis: Dictionary = world.symbiosis.snapshot()
	var deadwood: Dictionary = world.deadwood.snapshot()
	var schooling: Dictionary = world.schooling.snapshot()
	var algal_grazing: Dictionary = world.algal_grazing.snapshot()
	var desert_seed_transfer: Dictionary = world.desert_seeds.snapshot()
	var zooplankton_lesson: Dictionary = world.zooplankton.snapshot()
	var city_traffic: Dictionary = world.city_traffic.snapshot(world.simulation_time_s)
	for stage: Node in scene_host.get_children():
		if stage.has_method("set_reference_state"): stage.set_reference_state(reference)
		if stage.has_method("set_browse_state"): stage.set_browse_state(browse)
		if stage.has_method("set_runoff_state"): stage.set_runoff_state(runoff)
		if stage.has_method("set_symbiosis_state"): stage.set_symbiosis_state(symbiosis)
		if stage.has_method("set_deadwood_state"): stage.set_deadwood_state(deadwood)
		if stage.has_method("set_school_state"): stage.set_school_state(schooling)
		if stage.has_method("set_algal_state"): stage.set_algal_state(algal_grazing)
		if stage.has_method("set_desert_seed_state"): stage.set_desert_seed_state(desert_seed_transfer)
		if stage.has_method("set_zooplankton_state"): stage.set_zooplankton_state(zooplankton_lesson)
		if stage.has_method("set_city_traffic_state"): stage.set_city_traffic_state(city_traffic)
		if stage.has_method("set_world_time"): stage.set_world_time(world.simulation_time_s)
	_update_exploration()
	_update_solar_camera(delta)
	_finish_guide_visit()
	_fill_audio()
	if sound_panel.visible: sound_context_label.text = I18n.text(Soundscape.description(world.current_scale_id))
	time_label.text = I18n.text((Ephemeris.date_label(solar_jd)+I18n.text(" · 天文推演")) if (Satellites.is_system(world.current_scale_id) or world.current_scale_id in ["solar_system","earth","earth_moon"]) else ("t  %05.1f s   ·   %s×" % [world.simulation_time_s, str(world.time_scale)]))
	var active: Node = coordinator.active_scene
	# Exploration is attached to scene geometry; the old floating entry button
	# remains only as a compatibility handle for keyboard/diagnostic callers.
	target_button.hide()
	var scene_caption_clear: bool=not guided_journey.visible and not explorer_panel.visible and not _spatial_authoring_visible()
	earth_entry_panel.visible=world.current_scale_id=="earth" and not coordinator.is_busy() and not guided_journey.visible and not explorer_panel.visible and learning_overlay.topic!="earth_daylight"
	title_label.visible=scene_caption_clear
	subtitle_label.visible=scene_caption_clear
	anatomy_controls.position=Vector2(guided_journey.get_global_rect().end.x+16.,138.) if guided_journey.visible else Vector2(33,165)
	science_badge.hide() # Full text remains in the on-demand source inspector.
	debug_label.visible = _debug_visible
	if _debug_visible:
		debug_label.text = I18n.text(I18n.text("%d FPS · %s\n%s / %s · %d Viewport\nID %s\n估算准入 %.0f MB · 实测请查看采集文件") % [Engine.get_frames_per_second(), str(get_viewport().get_texture().get_size()), RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(), scene_host.get_child_count(), WorldState.TARGET_FISH_ID, coordinator.reserved_estimated_mb()])
	if _recording:
		var viewports: Array[Viewport] = [get_viewport()]
		for stage: Node in scene_host.get_children():
			if stage is Stage and stage.viewport != null: viewports.append_array(stage.render_viewports())
		recorder.sample(delta, viewports, {"cpu_process_ms": Performance.get_monitor(Performance.TIME_PROCESS)*1000.0, "scale_id": world.current_scale_id, "phase": ["steady", "loading", "preparing", "authoring", "draining"][coordinator.phase], "run_segment": "tour" if _tour else "interactive", "foreground": get_window().has_focus() if _measurement_screen >= 0 else world.foreground, "simulation_active": world.foreground, "simulation_time_s": world.simulation_time_s, "paused": world.paused, "window_focused": get_window().has_focus(), "window_can_draw": DisplayServer.window_can_draw(), "window_mode": get_window().mode, "borderless": get_window().borderless, "window_screen": get_window().current_screen, "window_position": [get_window().position.x, get_window().position.y]})
	if _motion_recording:
		motion.sample({"world_time_s": world.simulation_time_s, "scale_id": world.current_scale_id, "phase": ["steady", "loading", "preparing", "authoring", "draining"][coordinator.phase], "target_fish_id": WorldState.TARGET_FISH_ID, "paused": world.paused, "foreground": get_window().has_focus() if _measurement_screen >= 0 else world.foreground})
	var now: int = Time.get_ticks_usec()
	if _persistence_enabled and not coordinator.is_busy() and active.is_prepared() and (now >= _next_save_us or _save_requested):
		save_world(_save_requested)
	if _tour and now >= _next_tour_us and not coordinator.is_busy():
		var index: int = Catalog.EXPLORATION_PATH.find(world.current_scale_id)
		if index == 0: _tour_direction = 1
		if index == Catalog.EXPLORATION_PATH.size() - 1: _tour_direction = -1
		_navigate_relative(_tour_direction)
		_next_tour_us = now + 10000000
	if _run_duration > 0 and float(now - _wall_start_us) / 1000000.0 >= _run_duration: _quit()


func _navigate_relative(direction: int) -> void:
	if coordinator.is_busy():
		if not coordinator.recovery_state().is_empty():
			_dismiss_recovery()
			return
		coordinator.cancel("navigation_reversed")
		return
	var destination: String = observation_parent(world.current_scale_id) if direction < 0 else Catalog.relative(world.current_scale_id,direction)
	if not destination.is_empty(): navigate_to(destination)


func observation_parent(id: String) -> String:
	return str(_spatial_parents.get(id, Catalog.relative(id, -1)))


func observation_breadcrumb() -> Array[String]:
	var result: Array[String] = []
	var id: String = world.current_scale_id
	while not id.is_empty() and not result.has(id):
		result.push_front(id)
		id = observation_parent(id)
	return result


func _advance_or_city_view() -> void:
	if coordinator.is_busy() or not world.foreground or world_guide.visible or size_comparison.visible: return
	if world.current_scale_id=="earth" and not earth_entry_panel.selected.is_empty():
		earth_entry_panel.enter_selected()
	else:
		var choice: Dictionary = selected_spatial_choice()
		if not choice.is_empty(): enter_spatial_choice(choice)
		elif world.current_scale_id=="city": _toggle_city_people_view()
		else: _navigate_relative(1)


func selected_spatial_choice() -> Dictionary:
	# Resolve the current observer, including an individual picked in 3D. A
	# remembered mouse pixel is only for the second half of a double click.
	if world.current_scale_id=="solar_system" and solar_follow>=0 and solar_follow<I18n.strings(Ephemeris.NAMES).size():
		return {"planet":solar_follow,"label":I18n.strings(Ephemeris.NAMES)[solar_follow]}
	var targets: Array[Dictionary] = content_targets()
	return targets[_content_follow] if _content_follow>=0 and _content_follow<targets.size() else {}


func spatial_destination(choice: Dictionary) -> String:
	if choice.has("action") or choice.has("topic"): return ""
	if choice.has("planet"):
		return {2:"earth",3:"mars_moons",4:"jupiter_moons",5:"saturn_moons",6:"uranus_moons",7:"neptune_moons"}.get(int(choice.planet),"")
	var destination: String = str(choice.get("destination",""))
	if destination.is_empty() and choice.get("primary",false): destination=Catalog.relative(world.current_scale_id,1)
	return destination


func spatial_hint(choice: Dictionary) -> String:
	if choice.get("sky",false): return I18n.text("拖动环顾 · 双指缩放视野 · R恢复全景")
	if choice.has("action"): return I18n.text("再点或 Enter 操作")
	if choice.has("topic"): return I18n.text("双击 / Enter 查看实验")
	if choice.has("planet") and int(choice.planet)>=3 and Satellites.available(solar_jd): return I18n.text("指向卫星查看名字 · 双指缩放继续探索")
	if not spatial_destination(choice).is_empty(): return I18n.text("双击 / Enter / 靠近深入")
	return I18n.text("仅支持近看 · 拖动环绕 / 双指缩放")


func enter_spatial_choice(choice: Dictionary) -> void:
	if coordinator.is_busy() or not world.foreground or world_guide.visible or size_comparison.visible: return
	if choice.has("action"):
		perform_spatial_action(str(choice.action))
	elif choice.has("topic"):
		explorer_panel.open_topic(str(choice.topic))
	else:
		var destination: String = spatial_destination(choice)
		if not destination.is_empty(): observe_scale(destination)
		else: message_label.text=I18n.text(I18n.text("正在观察 · ")+str(choice.get("label",I18n.text("当前对象")))+" · "+spatial_hint(choice))


func _toggle_city_people_view() -> void:
	if coordinator.is_busy() or world.current_scale_id!="city": return
	message_label.text=I18n.text("")
	if _city_street_view:
		_reset_camera()
		return
	explorer_panel.clear_topic()
	_pan_offset=Vector3.ZERO
	_content_follow=-1
	_direct_content.clear()
	if _city_people_view:
		_orbit_target=CITY_STREET_TARGET
		coordinator.active_scene.set_pose(CITY_STREET_POSITION,CITY_STREET_TARGET)
		_city_people_view=false
		_city_street_view=true
	else:
		_orbit_target=CITY_PEOPLE_TARGET
		coordinator.active_scene.set_pose(CITY_PEOPLE_POSITION,CITY_PEOPLE_TARGET)
		_city_people_view=true
		_city_street_view=false
	_refresh_city_view_button()


func _refresh_city_view_button() -> void:
	if not is_instance_valid(next_button): return
	next_button.text = I18n.text((I18n.text("街区全景") if _city_street_view else I18n.text("从街道看城市") if _city_people_view else I18n.text("走近人群")) if world.current_scale_id=="city" else (I18n.text("进入地域") if not earth_entry_panel.selected.is_empty() else I18n.text("进入大气")) if world.current_scale_id=="earth" else I18n.text("继续深入"))
	next_button.hide()


func navigate_to(target_id: String) -> void:
	if is_instance_valid(clean_observation): clean_observation.set_active(false)
	if coordinator.is_busy() or not world.foreground: return
	if not ResourceLoader.exists(_path_for(target_id)):
		message_label.text = I18n.text(I18n.text("该尺度正在制作中，当前场景可继续探索"))
		return
	if not _switching_observation:
		_remember_view()
		navigation_bar.departing()
	end_lunar_close_view()
	if world.current_scale_id=="earth" and not EarthRegionFlight.region_for(target_id).is_empty(): _earth_reference=EarthRegionFlight.region_for(target_id)
	_earth_flight.clear()
	_earth_bridge.clear()
	_satellite_bridge.clear()
	_out_start = {"position": coordinator.active_scene.camera.position, "target": _orbit_target, "up": coordinator.active_scene.camera.basis.y, "fov": coordinator.active_scene.camera.fov}
	if world.current_scale_id=="solar_system" and Satellites.is_system(target_id):
		_out_start.target=coordinator.active_scene.get_meta("camera_look_target",_orbit_target)
	if world.current_scale_id=="solar_system" and target_id=="earth":
		# Capture geography before loading freezes the visible outgoing frame.
		_earth_bridge.out_start=coordinator.active_scene.builder.earth_fixed_pose(coordinator.active_scene,_out_start)
	elif world.current_scale_id=="earth" and target_id=="solar_system":
		_earth_bridge.out_start=_out_start.duplicate()
	# Ocean and land entries can cold-load their complete asset set from the PCK.
	# Keep feedback/cancellation and honest elapsed metrics; do not discard an
	# otherwise healthy first load at the old 10 s generic deadline.
	var deadline_ms: int = 30000 if STAGE_PATHS.get(target_id) in ["ocean", "land"] and not ResourceLoader.has_cached(_path_for(target_id)) else 10000
	coordinator.request_transition(target_id, _path_for(target_id), _estimate_mb(target_id), 2.8 if not _reduced_motion else 0.65, deadline_ms)


func _on_intent(request_id: int, target_id: String) -> void:
	soundscape.cue("approach")
	_progress_alpha = 0.0
	if is_instance_valid(earth_entry_panel): earth_entry_panel.hide()
	# Keep the last 3D frame while dependencies upload; the root HUD still draws.
	coordinator.active_scene.set_render_update_mode(SubViewport.UPDATE_DISABLED)
	message_label.text = I18n.text(I18n.text("正在接近 · ") + str(Catalog.describe(target_id).label))
	_acknowledge_visible_response(request_id)


func _acknowledge_visible_response(request_id: int) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	coordinator.acknowledge_first_response(request_id)


func _on_resource_ready(_request_id: int, incoming: Node) -> void:
	_incoming = incoming
	_incoming.set_view_size(Vector2i(get_viewport().get_texture().get_size()), _render_ratio)
	_incoming.set_opacity(0.0)


func _solar_overview_entry(source: String, destination: String) -> bool:
	# Spatial entry reveals the whole system; an explicit return owns its camera.
	return destination=="solar_system" and source in ["galaxy","universe"] and navigation_bar.pending_restore.get("scale","")!="solar_system"


func _on_authoring_started(_request_id: int, outgoing: Node, incoming: Node, _duration: float) -> void:
	outgoing.set_render_update_mode(SubViewport.UPDATE_ALWAYS)
	_outgoing = outgoing
	_incoming = incoming
	var overview_entry: bool = _solar_overview_entry(outgoing.scale_id,incoming.scale_id)
	if overview_entry:
		incoming.builder.set_solar_view(incoming,solar_jd,solar_true_distance)
		incoming.builder.solar_overview_pose(incoming,solar_jd,solar_true_distance)
	_out_end = outgoing.exit_pose(incoming.scale_id)
	_in_start = incoming.entry_pose(outgoing.scale_id)
	_in_end = {"position": incoming.default_position, "target": incoming.default_target, "up": incoming.camera.basis.y}
	if _views.has(incoming.scale_id) and not overview_entry:
		var saved: Dictionary = _views[incoming.scale_id]
		_in_end = {"position": WorldStore.vector(saved.position), "target": WorldStore.vector(saved.target), "up": WorldStore.vector(saved.up)}
	if navigation_bar.pending_restore.get("scale", "") == incoming.scale_id:
		var saved: Dictionary = navigation_bar.pending_restore
		_in_end = {"position": saved.position, "target": saved.target, "up": saved.up}
	_in_end["fov"] = incoming.camera.fov
	if outgoing.scale_id == "solar_system" and incoming.scale_id == "earth":
		_out_end = outgoing.builder.earth_boundary_pose(outgoing, _in_start)
		_earth_bridge.merge({"out_end":_in_start.duplicate(),"in_start":_in_start.duplicate(),"in_end":_in_end.duplicate()})
	elif outgoing.scale_id == "earth" and incoming.scale_id == "solar_system":
		_in_start = incoming.builder.earth_boundary_pose(incoming, _out_end)
		var reference_jd: float = float(_views.get("solar_system",{}).get("astronomy",{}).get("jd",solar_jd))
		_earth_bridge.merge({"out_end":_out_end.duplicate(),"in_start":_out_end.duplicate(),"in_end":incoming.builder.earth_fixed_pose(incoming,_in_end,reference_jd)})
	_earth_flight = EarthRegionFlight.profile(outgoing.scale_id, incoming.scale_id)
	if not _earth_flight.is_empty():
		if _earth_flight.direction == "enter":
			_out_end = EarthRegionFlight.near_pose(_earth_flight.region)
			_in_start = EarthRegionFlight.far_pose(_in_end)
		else:
			_out_end = EarthRegionFlight.far_pose(_out_start)
			_in_start = EarthRegionFlight.near_pose(_earth_flight.region)
	if STAGE_PATHS[outgoing.scale_id] == "ocean" and STAGE_PATHS[incoming.scale_id] == "ocean":
		# Same metre-space and geometry: both viewports follow the exact same pose.
		_in_start = _out_start.duplicate()
		_out_end = _in_end.duplicate()
	_prepare_satellite_bridge(outgoing,incoming)
	incoming.set_pose(_in_start.position, _in_start.target, _in_start.get("up", Vector3.UP))


func _prepare_satellite_bridge(outgoing: Node, incoming: Node) -> void:
	var entering: bool = outgoing.scale_id=="solar_system" and Satellites.is_system(incoming.scale_id)
	var returning: bool = incoming.scale_id=="solar_system" and Satellites.is_system(outgoing.scale_id)
	if not entering and not returning: return
	var local: Node = incoming if entering else outgoing
	var solar: Node = outgoing if entering else incoming
	var index: int = int(SatelliteBuilder.INDEX[Satellites.host_for_scale(local.scale_id)])
	if local.scale_id=="jupiter_moons": local.builder.set_view(local,solar_jd,solar_true_distance)
	else: SatelliteBuilder.set_view(local,solar_jd,solar_true_distance)
	solar.set_meta("solar_satellite_bridge_index",index)
	solar.builder.set_solar_view(solar,solar_jd,solar_true_distance)
	var key: String = str(selected_spatial_choice().get("satellite_key",""))
	var return_key: String = ""
	var return_anchor: Vector3 = Vector3.ZERO
	var start: Dictionary = SolarSatellites.local_pose(solar,index,_out_start) if entering else _out_start.duplicate()
	var middle: Dictionary = start.duplicate()
	middle.position=Vector3(start.target)+(Vector3(start.position)-Vector3(start.target))*(.92 if entering else 1.08)
	var finish: Dictionary = middle.duplicate()
	if entering:
		var goal: Vector3 = Vector3.ZERO
		var near_distance: float = 10.0
		for entry: Dictionary in SatelliteBuilder.targets(local):
			if not key.is_empty() and str(entry.get("satellite_key",""))==key:
				goal=entry.node.position
				near_distance=float(entry.distance)
				break
		var direction: Vector3 = (Vector3(start.position)-goal).normalized()
		var distance: float = Vector3(start.position).distance_to(goal)
		middle={"position":goal+direction*distance*.92,"target":goal,"up":start.get("up",Vector3.UP)}
		finish={"position":goal+direction*minf(near_distance,distance*.865),"target":goal,"up":middle.up}
		var finish_fov: float=48.0
		if not key.is_empty():
			for entry: Dictionary in SatelliteBuilder.targets(local):
				if str(entry.get("satellite_key",""))==key and entry.node.mesh is SphereMesh: finish_fov=clampf(rad_to_deg(2.0*atan(2.3*float(entry.node.mesh.radius)/float(entry.distance))),.05,48.0)
		if key.is_empty():
			var data: Dictionary=SatelliteFraming.subjects(local,index)
			if not data.is_empty():
				var pole: Vector3=SatelliteFraming.normal(data,solar_jd)
				finish=SatelliteFraming.solve(data,Vector2(local.viewport.size),_solar_observation_frame(),pole)
				SatelliteFraming.configure(local,data,finish,pole)
				local.camera.near=finish.near
				finish_fov=finish.fov
		_in_start=middle.duplicate()
		_in_end=finish.duplicate()
		_in_end.fov=finish_fov
		_out_end=SolarSatellites.solar_pose(solar,index,middle)
	else:
		var saved: Dictionary = _views.get("solar_system",{})
		if not saved.is_empty() and not _satellite_zoom_return:
			var previous: Dictionary = saved.get("astronomy",{})
			var previous_centre: Vector3 = Ephemeris.display_position(index,float(previous.get("jd",solar_jd)),bool(previous.get("true_distance",solar_true_distance)))
			var old_scale: float = solar.get_meta("solar_bodies")[index].node.mesh.radius*(1.0 if int(saved.get("solar_geometry_version",0))==1 else Ephemeris.body_display_scale(index,bool(previous.get("true_distance",solar_true_distance))))
			finish={"position":(WorldStore.vector(saved.position)-previous_centre)/old_scale,"target":(WorldStore.vector(saved.target)-previous_centre)/old_scale,"up":WorldStore.vector(saved.up)}
			return_key=str(saved.get("satellite_key",""))
			for item: Dictionary in Satellites.records(Satellites.host_for_scale(local.scale_id)):
				if str(item.key)!=return_key: continue
				var state: Dictionary = Satellites.sample(item,float(previous.get("jd",solar_jd)))
				if state.valid: return_anchor=Satellites.world_position(state,Ephemeris.RADII_KM[index])
		else:
			var pose: Dictionary = solar.builder.solar_overview_pose(solar,solar_jd,solar_true_distance)
			finish=SolarSatellites.local_pose(solar,index,pose)
		_out_end=middle.duplicate()
		_in_start=SolarSatellites.solar_pose(solar,index,middle)
		_in_end=SolarSatellites.solar_pose(solar,index,finish)
		_in_end.fov=float(saved.get("solar_look_fov",50.0)) if not saved.is_empty() and not _satellite_zoom_return else 50.0
	var anchor: Vector3 = Vector3.ZERO
	if not key.is_empty():
		for item: Dictionary in Satellites.records(Satellites.host_for_scale(local.scale_id)):
			if str(item.key)!=key: continue
			var state: Dictionary = Satellites.sample(item,solar_jd)
			if state.valid: anchor=Satellites.world_position(state,Ephemeris.RADII_KM[index])
	_satellite_bridge={"entering":entering,"index":index,"start":start,"middle":middle,"finish":finish,"key":key,"anchor":anchor,"return_key":return_key,"return_anchor":return_anchor,"zoom_return":_satellite_zoom_return}
	_satellite_zoom_return=false


func _has_matched_bridge() -> bool:
	var pair: String = String(_outgoing.scale_id) + ":" + String(_incoming.scale_id)
	return _has_cosmos_bridge() or pair in ["earth:atmosphere", "atmosphere:earth", "atmosphere:pacific", "pacific:atmosphere",
		"mitochondrion:molecule", "molecule:mitochondrion", "cardiomyocyte:mitochondrion", "mitochondrion:cardiomyocyte"]


func _has_cosmos_bridge() -> bool:
	if not is_instance_valid(_outgoing) or not is_instance_valid(_incoming): return false
	var pair: String = String(_outgoing.scale_id) + ":" + String(_incoming.scale_id)
	return not _satellite_bridge.is_empty() or pair in ["universe:galaxy", "galaxy:universe", "galaxy:solar_system", "solar_system:galaxy", "solar_system:earth", "earth:solar_system"]


func _spatial_authoring_visible() -> bool:
	return coordinator.phase == Coordinator.Phase.AUTHORING and (not _earth_flight.is_empty() or _has_cosmos_bridge())


func _on_authoring_progress(_request_id: int, progress: float) -> void:
	if not is_instance_valid(_outgoing) or not is_instance_valid(_incoming): return
	if not _earth_flight.is_empty() and not _reduced_motion:
		var entering: bool = _earth_flight.direction == "enter"
		var globe_amount: float = smoothstep(0.0, .66, progress) if entering else smoothstep(.42, 1.0, progress)
		var local_amount: float = smoothstep(.52, 1.0, progress) if entering else smoothstep(0.0, .48, progress)
		var globe_pose: Dictionary = EarthRegionFlight.globe_pose(_out_start if entering else _in_start, _out_end if entering else _in_end, globe_amount, entering)
		var local_pose: Dictionary = EarthRegionFlight.interpolate(_in_start if entering else _out_start, _in_end if entering else _out_end, local_amount)
		var globe: Node = _outgoing if entering else _incoming
		var local: Node = _incoming if entering else _outgoing
		globe.set_pose(globe_pose.position, globe_pose.target, globe_pose.up)
		local.set_pose(local_pose.position, local_pose.target, local_pose.up)
		_progress_alpha = smoothstep(.50, .73, progress) if entering else smoothstep(.28, .55, progress)
		_outgoing.set_opacity(1.0)
		_incoming.set_opacity(_progress_alpha)
		return
	if _outgoing.scale_id == "fish" and _incoming.scale_id == "heart":
		_out_end = _outgoing.exit_pose("heart")
	if _outgoing.scale_id == "heart" and _incoming.scale_id == "fish":
		_in_start = _incoming.entry_pose("heart")
	var s: float = progress * progress * (3.0 - 2.0 * progress)
	var out_s: float = s
	var in_s: float = s
	var matched: bool = _has_matched_bridge() and not _reduced_motion
	if matched:
		# First approach the common boundary, blend aligned views, then reveal
		# the destination. Other authored pairs retain their existing trajectory.
		out_s = smoothstep(0.0, 0.42, progress)
		in_s = smoothstep(0.58, 1.0, progress)
		var common_fov: float = (float(_out_start.fov) + float(_in_end.fov)) * 0.5
		_outgoing.camera.fov = lerpf(float(_out_start.fov), common_fov, out_s)
		_incoming.camera.fov = lerpf(common_fov, float(_in_end.fov), in_s)
	if not _reduced_motion:
		var earth_pair: bool = (_outgoing.scale_id == "solar_system" and _incoming.scale_id == "earth") or (_outgoing.scale_id == "earth" and _incoming.scale_id == "solar_system")
		if not _satellite_bridge.is_empty():
			var entering: bool = bool(_satellite_bridge.entering)
			var solar: Node = _outgoing if entering else _incoming
			var local: Node = _incoming if entering else _outgoing
			var a: Dictionary = EarthRegionFlight.interpolate(_satellite_bridge.start,_satellite_bridge.middle,out_s)
			var b: Dictionary = EarthRegionFlight.interpolate(_satellite_bridge.middle,_satellite_bridge.finish,in_s)
			if entering:
				var shift: Vector3 = _satellite_bridge_shift(local)
				a.position+=shift; a.target+=shift; b.position+=shift; b.target+=shift
				var global_pose: Dictionary = SolarSatellites.solar_pose(solar,int(_satellite_bridge.index),a)
				solar.set_pose(global_pose.position,global_pose.target,global_pose.up)
				local.set_pose(b.position,b.target,b.up)
				_in_end={"position":b.position,"target":b.target,"up":b.up,"fov":_in_end.fov}
			else:
				var shift: Vector3 = _satellite_bridge_shift(local)
				a.position+=shift; a.target+=shift
				var finish_shift: Vector3 = _satellite_bridge_shift(local,true)
				var blend_shift: Vector3 = shift*(1.0-in_s)+finish_shift*in_s
				b.position+=blend_shift; b.target+=blend_shift
				local.set_pose(a.position,a.target,a.up)
				var global_pose: Dictionary = SolarSatellites.solar_pose(solar,int(_satellite_bridge.index),b)
				solar.set_pose(global_pose.position,global_pose.target,global_pose.up)
				for field: String in ["position","target","up"]: _in_end[field]=global_pose[field]
		elif earth_pair and not _earth_bridge.is_empty():
			var entering: bool = _incoming.scale_id == "earth"
			var outgoing_pose: Dictionary = _outgoing.builder.interpolate_earth_flight(_outgoing, _earth_bridge.out_start, _earth_bridge.out_end, out_s, entering)
			var incoming_pose: Dictionary = _incoming.builder.interpolate_earth_flight(_incoming, _earth_bridge.in_start, _earth_bridge.in_end, in_s, entering)
			_outgoing.set_pose(outgoing_pose.position, outgoing_pose.target, outgoing_pose.up)
			_incoming.set_pose(incoming_pose.position, incoming_pose.target, incoming_pose.up)
			if not entering:
				var finish: Dictionary = _incoming.builder.earth_boundary_pose(_incoming,_earth_bridge.in_end)
				for key: String in ["position","target","up"]: _in_end[key]=finish[key]
		else:
			var out_pose: Dictionary = EarthRegionFlight.interpolate(_out_start, _out_end, out_s)
			var in_pose: Dictionary = EarthRegionFlight.interpolate(_in_start, _in_end, in_s)
			if _outgoing.scale_id == "earth" and _incoming.scale_id == "atmosphere":
				out_pose = EarthRegionFlight.globe_pose(_out_start, _out_end, out_s, true)
			elif _outgoing.scale_id == "atmosphere" and _incoming.scale_id == "earth":
				in_pose = EarthRegionFlight.globe_pose(_in_start, _in_end, in_s, false)
			_outgoing.set_pose(out_pose.position, out_pose.target, out_pose.up)
			_incoming.set_pose(in_pose.position, in_pose.target, in_pose.up)
	else:
		_incoming.set_pose(_in_end.position, _in_end.target)
	# Macro boundaries share the same camera projection while both poses hold.
	var blend: float = smoothstep(0.42, 0.58, progress) if _has_cosmos_bridge() and not _reduced_motion else smoothstep(0.35, 0.65, progress) if matched else smoothstep(0.20, 0.80, progress)
	_progress_alpha = blend
	_outgoing.set_opacity(1.0)
	_incoming.set_opacity(blend)


func _satellite_bridge_shift(local: Node, returning: bool = false) -> Vector3:
	var key: String = str(_satellite_bridge.get("return_key" if returning else "key",""))
	if key.is_empty(): return Vector3.ZERO
	for item: Dictionary in Satellites.records(Satellites.host_for_scale(local.scale_id)):
		if str(item.key)!=key: continue
		var state: Dictionary = Satellites.sample(item,solar_jd)
		if state.valid: return Satellites.world_position(state,Ephemeris.RADII_KM[int(_satellite_bridge.index)])-Vector3(_satellite_bridge.return_anchor if returning else _satellite_bridge.anchor)
	return Vector3.ZERO


func _prepare_ground_sky(stage: Node) -> bool:
	if stage.scale_id!="night_sky": return false
	var preset: bool=solar_demo_auto and not solar_manual_setting and not _views.has("night_sky")
	if preset:
		solar_jd=GroundSky.Geometry.night_date(solar_jd)
		_solar_origin_jd=solar_jd; _solar_origin_time=world.simulation_time_s
	GroundSky.update(stage,solar_jd); GroundSky.reset_view(stage)
	return preset

func _on_interactive(_request_id: int, _target_id: String, active: Node) -> void:
	# Commit observer context only after a successful transition. Returning from
	# a region must not turn the fixed ocean example into the user's parent.
	var source: String = str(navigation_bar.departure.get("scale", ""))
	if not source.is_empty() and source != _target_id and not _switching_observation:
		var entered: bool = Catalog.relative(source, 1) == _target_id or source == "solar_system" and (Satellites.is_system(_target_id) or _target_id=="earth_moon") or source == "earth" and not EarthRegionFlight.region_for(_target_id).is_empty()
		if entered: _spatial_parents[_target_id] = source
		elif _target_id != observation_parent(source): _spatial_parents.erase(_target_id)
	soundscape.cue("arrive")
	# Keep near playback through loading and the visible bridge. Only a
	# successful departure relinquishes its original return preference.
	if not _solar_close_playback.is_empty():
		_end_solar_close_playback()
		var saved_astronomy: Dictionary = _views.get("solar_system",{}).get("astronomy",{})
		saved_astronomy.erase("close_playback")
		saved_astronomy["rate"]=solar_rate
		saved_astronomy["auto"]=solar_demo_auto
	var earth_handoff: Dictionary = _in_end.duplicate() if active.scale_id=="solar_system" and not _earth_bridge.is_empty() and not _reduced_motion else {}
	var satellite_handoff: Dictionary = _in_end.duplicate() if not _satellite_bridge.is_empty() else {}
	var satellite_context: Dictionary = _satellite_bridge.duplicate()
	active.set_opacity(1.0)
	if _target_id=="night_sky":
		if _prepare_ground_sky(active):
			message_label.text=I18n.text(I18n.text("已切至观星点的夜空预设 · 下方显示同一天文日期"))
	_orbit_target = active.default_target
	_pan_offset = Vector3.ZERO
	_incoming = null
	_outgoing = null
	_earth_flight.clear()
	_earth_bridge.clear()
	_satellite_bridge.clear()
	if _target_id!="night_sky": message_label.text = I18n.text("")
	_update_ui()
	if _solar_overview_entry(source,_target_id):
		_reset_camera()
	else:
		_apply_saved_view(active)
	if not satellite_handoff.is_empty():
		active.set_pose(satellite_handoff.position,satellite_handoff.target,satellite_handoff.up)
		_orbit_target=satellite_handoff.target
		if active.scale_id=="solar_system":
			active.set_meta("solar_satellite_bridge_index",-1)
			if not bool(satellite_context.zoom_return) and not str(satellite_context.return_key).is_empty():
				solar_follow=-1
				var entries: Array[Dictionary] = content_targets(false)
				for i: int in range(entries.size()):
					if str(entries[i].get("satellite_key",""))!=str(satellite_context.return_key): continue
					_content_follow=i
					active.set_meta("solar_satellite_selected_key",str(satellite_context.return_key))
					active.builder.set_solar_focus(active,int(satellite_context.index))
					_pan_offset=_orbit_target-entries[i].node.position
					_begin_solar_close_playback(i+8)
					break
			elif not bool(satellite_context.zoom_return):
				solar_follow=int(satellite_context.index)
				_content_follow=-1
				active.set_meta("solar_satellite_selected_key","")
				active.builder.set_solar_focus(active,solar_follow)
				_pan_offset=_orbit_target-active.get_meta("solar_bodies")[solar_follow].node.position
				_begin_solar_close_playback(solar_follow)
			else:
				solar_follow=-1; _content_follow=-1; _pan_offset=Vector3.ZERO
				active.set_meta("solar_satellite_selected_key","")
				active.builder.set_solar_focus(active,-1)
		else:
			_content_follow=-1
			var entries: Array[Dictionary] = content_targets(false)
			for i: int in range(entries.size()):
				if str(entries[i].get("satellite_key",""))==str(satellite_context.key) and not str(satellite_context.key).is_empty():
					_content_follow=i; SatelliteBuilder.select(active,i)
					_pan_offset=_orbit_target-entries[i].node.position
					break
	if not satellite_handoff.is_empty():
		active.camera.fov=float(satellite_handoff.fov)
		if active.has_meta("natural_satellites") and str(satellite_context.key).is_empty(): frame_satellite_system(int(satellite_context.index),"",false)
		elif active.has_meta("natural_satellites") and _content_follow>=0:
			var entry: Dictionary=content_targets(false)[_content_follow]
			SatelliteFraming.detail(active,int(satellite_context.index),str(satellite_context.key),float(entry.distance))
			if entry.node.mesh is SphereMesh: active.camera.near=maxf(.001,float(entry.node.mesh.radius)*.025)
	if not earth_handoff.is_empty():
		# The saved camera was in the previous inertial frame; the bridge has
		# already carried that same geography to the current shared date.
		active.set_pose(earth_handoff.position,earth_handoff.target,earth_handoff.up)
		_orbit_target=earth_handoff.target
	if (active.scale_id=="earth_moon" or active.has_meta("natural_satellites")) and not _views.has(active.scale_id) and satellite_handoff.is_empty(): frame_satellite_system(-1,"",false)
	navigation_bar.arrived()
	if _returning_from_trial:
		_trial_return.clear()
		_trial_views.clear()
		_returning_from_trial = false
		message_label.text = I18n.text(I18n.text("已返回原世界"))
	elif is_trial() and _switching_observation and world.habitat.events.is_empty():
		world.record_observation("started")
	elif not _switching_observation:
		world.record_observation("arrived")
	_switching_observation = false
	_refresh_observation_controls()
	save_world(_save_requested)
	print("SCALE_INTERACTIVE ", world.current_scale_id, " t=", world.simulation_time_s)


func _restore_view() -> void:
	if not _earth_bridge.is_empty() and is_instance_valid(coordinator.active_scene) and coordinator.active_scene.scale_id=="solar_system":
		var restored: Dictionary = coordinator.active_scene.builder.earth_boundary_pose(coordinator.active_scene,_earth_bridge.out_start)
		for key: String in ["position","target","up"]: _out_start[key]=restored[key]
	_incoming = null
	_outgoing = null
	_earth_flight.clear()
	_earth_bridge.clear()
	for stage: Node in scene_host.get_children():
		if stage.has_meta("solar_satellite_systems"): stage.set_meta("solar_satellite_bridge_index",-1)
	_satellite_bridge.clear()
	_satellite_zoom_return=false
	if is_instance_valid(earth_entry_panel): earth_entry_panel.visible = world.current_scale_id == "earth" and not coordinator.is_busy() and not explorer_panel.visible and not (is_instance_valid(guided_journey) and guided_journey.visible) and not (is_instance_valid(learning_overlay) and learning_overlay.topic=="earth_daylight")
	if is_instance_valid(coordinator.active_scene):
		coordinator.active_scene.set_opacity(1.0)
		if not _out_start.is_empty():
			coordinator.active_scene.camera.fov = float(_out_start.get("fov", coordinator.active_scene.camera.fov))
			coordinator.active_scene.set_pose(_out_start.position, _out_start.target, _out_start.get("up", Vector3.UP))
			_orbit_target = _out_start.target


func _on_failure(_request_id: int, reason: String) -> void:
	navigation_bar.cancelled()
	_recovery_guide = _guide_visit.duplicate(true)
	_guide_visit.clear()
	coordinator.active_scene.set_render_update_mode(SubViewport.UPDATE_ALWAYS)
	soundscape.cue("failure")
	_restore_view()
	message_label.text = I18n.text(I18n.text("暂时无法进入，已保留当前世界；可稍后重试"))
	print("TRANSITION_FAILURE ", reason)


func _update_recovery() -> void:
	if recovery_actions == null: return
	var recovery: Dictionary = coordinator.recovery_state()
	recovery_actions.visible = not recovery.is_empty()
	immersive_interface.fit_window(ui_view_size())
	if recovery.is_empty(): return
	var ready: bool = bool(recovery.ready)
	retry_button.disabled = not ready
	retry_button.text = I18n.text(I18n.text("重试 · ") + str(Catalog.describe(str(recovery.target)).label) if ready else I18n.text("等待加载完成…"))
	message_label.text = I18n.text(I18n.text("未能进入，当前世界已保留；可以重试") if ready else I18n.text("当前世界已保留，目标仍在加载；完成后可重试"))


func _retry_transition() -> void:
	var recovery: Dictionary = coordinator.recovery_state()
	if recovery.is_empty() or not bool(recovery.ready) or coordinator.is_busy() or not world.foreground: return
	_guide_visit = _recovery_guide.duplicate(true)
	_recovery_guide.clear()
	navigate_to(str(recovery.target))


func _dismiss_recovery() -> void:
	_recovery_guide.clear()
	coordinator.dismiss_recovery()
	message_label.text = I18n.text(I18n.text("已取消重试，后台仍在收尾；当前世界可继续观察") if coordinator.is_busy() else I18n.text("继续观察当前世界"))


func _on_cancelled(_request_id: int, reason: String) -> void:
	navigation_bar.cancelled()
	_recovery_guide.clear()
	_guide_visit.clear()
	coordinator.active_scene.set_render_update_mode(SubViewport.UPDATE_ALWAYS)
	soundscape.cue("cancel")
	_restore_view()
	message_label.text = I18n.text(I18n.text("已暂停接近，返回窗口后可继续") if reason in ["application_focus_lost", "window_unavailable"] else I18n.text("已取消接近，继续观察当前尺度"))


func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	if event.keycode==KEY_ESCAPE and is_instance_valid(optical_inspector) and optical_inspector.visible:
		if event.pressed: optical_inspector.dismiss()
		get_viewport().set_input_as_handled()
		return
	if not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
		if event.keycode==KEY_F9 or (clean_observation.active and event.keycode==KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo: clean_observation.toggle()
			return
	if event.keycode == KEY_S and (event.meta_pressed or event.ctrl_pressed) and not event.alt_pressed:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo: save_world(true)
		return
	if is_instance_valid(size_comparison) and size_comparison.visible:
		if event.keycode==KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo: size_comparison.close()
		return
	if world_guide.visible:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo: world_guide.hide()
		return
	var focused: Control=get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		if event.keycode!=KEY_ESCAPE: return
	if focused!=null and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
		if (guided_journey.visible and guided_journey.is_ancestor_of(focused)) or navigation_bar.is_ancestor_of(focused) or immersive_interface.is_ancestor_of(focused): return
	# Modified chords belong to the GUI or operating system, not plain shortcuts.
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed: return
	if get_viewport().gui_get_focus_owner() is Slider and event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END]: return
	if event.keycode not in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_DOWN,
			KEY_BACKSPACE, KEY_UP, KEY_R, KEY_I, KEY_F3, KEY_M, KEY_C]: return
	# A focused Button also accepts Enter/Space on release and consumes arrows.
	# Own both halves of our shortcuts before GUI dispatch, including key repeats.
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: _escape_navigation()
			KEY_SPACE: _toggle_pause()
			KEY_ENTER, KEY_KP_ENTER, KEY_DOWN: _advance_or_city_view()
			KEY_BACKSPACE, KEY_UP: _navigate_relative(-1)
			KEY_R: _reset_observation_view()
			KEY_I: _toggle_info()
			KEY_F3: _debug_visible = not _debug_visible
			KEY_M: _toggle_mute()
			KEY_C: _toggle_cutaway()


func _escape_navigation() -> void:
	# Close observation UI first; a second press releases a selection, then ascends.
	if guided_journey.visible: guided_journey.suspend()
	elif explorer_panel.visible: explorer_panel.hide()
	elif observation_panel.visible: observation_panel.hide()
	elif sound_panel.visible: sound_panel.hide()
	elif immersive_interface.menu_button.get_popup().visible: immersive_interface.menu_button.get_popup().hide()
	elif immersive_interface.rate_button.get_popup().visible: immersive_interface.rate_button.get_popup().hide()
	elif info_panel.visible: info_panel.hide()
	elif not coordinator.recovery_state().is_empty(): _dismiss_recovery()
	elif coordinator.is_busy(): coordinator.cancel()
	elif _clear_observation_selection(): pass
	elif not Catalog.relative(world.current_scale_id,-1).is_empty(): _navigate_relative(-1)
	else: message_label.text=I18n.text(I18n.text("已在银河系 · 可通过世界导览继续探索"))


func _clear_observation_selection() -> bool:
	if world.current_scale_id=="earth" and not earth_entry_panel.selected.is_empty():
		earth_entry_panel.clear_selection()
		message_label.text=I18n.text(I18n.text("已取消地域选择 · 地球视角保持"))
		return true
	var stage: Node=coordinator.active_scene
	var atom_selected: bool=stage.has_meta("oxygen_atom") and (int(stage.get_meta("oxygen_atom").mode)!=0 or bool(stage.get_meta("oxygen_atom").section))
	if atom_selected: stage.builder.set_atom_view(stage,0,false)
	var selected: bool=atom_selected or solar_follow>=0 or solar_orbit_focus>=0 or not solar_plane_view.is_empty() or _content_follow>=0 or _city_people_view or _city_street_view or not learning_overlay.topic.is_empty()
	if world.current_scale_id=="heart" and not str(stage.get_meta("anatomy_selected_region","")).is_empty():
		stage.builder.select_region(stage,"")
		selected=true
	if not selected: return false
	explorer_panel.clear_topic()
	_reset_camera()
	message_label.text=I18n.text(I18n.text("已取消选择 · 再按 Esc 返回上层"))
	return true


func _unhandled_input(event: InputEvent) -> void:
	if world_guide.visible or (is_instance_valid(size_comparison) and size_comparison.visible): return
	if coordinator.is_busy() or not world.foreground or not is_instance_valid(coordinator.active_scene): return
	var stage: Node = coordinator.active_scene
	if event is InputEventMagnifyGesture:
		if _zoom_over_interface(event.position) or not is_finite(event.factor) or event.factor <= 0.0: return
		_zoom_camera(stage, 1.0 / event.factor)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		if _zoom_over_interface(event.position) or not event.delta.is_finite(): return
		if event.shift_pressed: _pan_camera(stage, -event.delta * 16.0)
		else: _zoom_camera(stage, exp(clampf(event.delta.y * 0.15, -0.7, 0.7)))
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(earth_entry_panel) and earth_entry_panel.pointer(event): return
	if is_instance_valid(object_pointer) and object_pointer.pointer(event): return
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT)!=0 and not event.shift_pressed:
			if SolarCloseup.orbit(self,stage,event.relative): return
		_solar_camera_motion.clear()
		if world.current_scale_id=="solar_system": stage.set_meta("solar_camera_exploring",true)
		if world.current_scale_id=="night_sky":
			_content_follow=-1; _direct_content.clear()
			GroundSky.rotate_view(stage,event.relative)
			_orbit_target=GroundSky.EYE-stage.camera.basis.z*10.0
			return
		if SatelliteFraming.is_pair(stage):
			_drag_satellite_frame(stage,event); return
		if world.current_scale_id=="solar_system" and int(stage.get_meta("solar_physical",{}).get("owner",-1))>=0 and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT)!=0:
			# Right drag turns the gaze in place; left drag continues to orbit.
			var turn: Basis = Basis(Vector3.UP,-event.relative.x*.005)*Basis(stage.camera.basis.x,-event.relative.y*.004)
			_set_solar_context_gaze(stage,stage.camera.position,stage.camera.position+turn*(_orbit_target-stage.camera.position))
			return
		if (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE)!=0 or (event.button_mask & MOUSE_BUTTON_MASK_LEFT)!=0 and event.shift_pressed:
			_pan_camera(stage,event.relative)
			return
		if world.current_scale_id=="earth_moon" and learning_overlay.topic=="lunar_phases":
			end_lunar_close_view()
			lunar_observation_view="free"
		var offset: Vector3 = stage.camera.position - _orbit_target
		var radius: float = offset.length()
		if world.current_scale_id=="solar_system" and (learning_overlay.topic=="mercury_orbit" or not solar_plane_view.is_empty()):
			# Rotate about screen axes so a face-on orbit has no polar clamp/roll jump.
			var turn: Basis = Basis(stage.camera.basis.y,-event.relative.x*.005)*Basis(stage.camera.basis.x,-event.relative.y*.004)
			stage.set_pose(_orbit_target+turn*offset,_orbit_target,turn*stage.camera.basis.y)
			return
		var yaw: float = atan2(offset.x, offset.z) - event.relative.x * 0.005
		var pitch: float = clampf(asin(offset.y / maxf(radius, 0.0001)) + event.relative.y * 0.004, -1.35, 1.35)
		stage.set_pose(_orbit_target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * radius, _orbit_target)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if not is_finite(event.factor) or event.factor <= 0.0: return
			_zoom_camera(stage, exp((-.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else .15) * minf(event.factor, 4.0)))
			get_viewport().set_input_as_handled()


func _zoom_over_interface(point: Vector2) -> bool:
	if immersive_interface.blocks(point): return true
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if is_instance_valid(hovered_control) and hovered_control.is_visible_in_tree() and hovered_control.get_global_rect().has_point(point): return true
	for panel: Control in [info_panel, observation_panel, explorer_panel, sound_panel, guided_journey, anatomy_controls]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(point): return true
	return false


func _zoom_camera(stage: Node, factor: float) -> void:
	# All pointing devices use the same camera and semantic boundaries. A pan's
	# vertical delta has the opposite sign to a wheel-up event on macOS.
	if not is_finite(factor) or factor <= 0.0 or is_equal_approx(factor, 1.0): return
	if _hold_solar_overview_zoom(stage,factor): return
	if _solar_camera_motion.has("rotation_start"):
		# A pinch retargets the ongoing dolly; it must not strand the observer
		# in a different host's large coordinate frame halfway through the flight.
		_solar_camera_motion.finish=Vector3(_solar_camera_motion.finish)*clampf(factor,.75,1.5)
		return
	_solar_camera_motion.clear()
	if world.current_scale_id=="solar_system": stage.set_meta("solar_camera_exploring",true)
	var ratio: float = clampf(factor, .5, 2.0)
	var framing: Dictionary=SatelliteFraming.state(stage)
	if SatelliteFraming.is_pair(stage):
		if ratio<1.0:
			if stage.scale_id=="solar_system": follow_planet(int(framing.owner),true)
			else: follow_content(1)
		else:
			framing.fov=float(framing.fov)*ratio
			if float(framing.fov)>minf(80.0,float(framing.base_fov)*1.65): _reset_camera()
			else: stage.camera.fov=framing.fov; stage.builder.update_camera(stage)
		return
	if str(framing.get("mode",""))=="detail" and ratio>1.0 and stage.camera.position.distance_to(_orbit_target)*ratio>float(framing.detail_distance)*1.4:
		if frame_satellite_system(int(framing.owner),str(framing.key)): return
	if world.current_scale_id=="night_sky":
		var requested: float=stage.camera.fov*ratio
		if ratio>1.0 and requested>104.0:
			_navigate_relative(-1)
			return
		stage.camera.fov=clampf(requested,1.0,100.0)
		GroundSky.update_camera(stage)
		return
	if world.current_scale_id=="solar_system" and bool(stage.get_meta("solar_lookaround",false)):
		# Looking toward a distant body changes optical field of view, not the
		# Earth-entry threshold or observer's local distance scale.
		if ratio>1.0 and stage.camera.fov*ratio>80.0:
			_reset_camera(); return
		stage.camera.fov=clampf(stage.camera.fov*ratio,2.0,80.0)
		stage.builder.update_camera(stage)
		return
	if world.current_scale_id == "earth_moon" and learning_overlay.topic == "lunar_phases" and lunar_observation_view == "earth":
		stage.camera.size = clampf(stage.camera.size * ratio, .70, 2.8)
		return
	var offset: Vector3 = stage.camera.position - _orbit_target
	var distance: float = offset.length() * ratio
	var standard: float = stage.default_position.distance_to(stage.default_target)
	var free_minimum: float = standard * .10 if world.current_scale_id in ["universe", "galaxy", "atmosphere", "pacific", "reef", "school", "fish"] else .05 if world.current_scale_id == "solar_system" else .25
	var minimum: float = maxf(stage.camera.near * 2.0, float(stage.get_meta("orbit_min_distance", free_minimum)))
	if world.current_scale_id == "earth": minimum = 3.5
	var destination: String = ""
	var entry_distance: float = standard * .42
	var targets: Array[Dictionary] = content_targets()
	if _content_follow >= 0 and _content_follow < targets.size():
		var item: Dictionary = targets[_content_follow]
		minimum = float(item.get("min_distance", minimum))
		destination = spatial_destination(item)
		entry_distance = float(item.get("entry_distance", minimum * 1.15))
	elif world.current_scale_id == "solar_system" and solar_follow >= 0:
		destination = spatial_destination({"planet":solar_follow})
		var planet: MeshInstance3D = stage.get_meta("solar_bodies")[solar_follow].node
		var radius: float = float(planet.mesh.radius) * absf(planet.scale.x)
		minimum = maxf(.05, radius * 1.35)
		entry_distance = maxf(minimum * 1.1, radius * 3.0)
	elif world.current_scale_id == "earth":
		destination = earth_entry_panel.selected if not earth_entry_panel.selected.is_empty() else "atmosphere"
		entry_distance = 3.8
	elif world.current_scale_id in ["universe", "galaxy", "atmosphere", "pacific", "reef", "school", "fish", "heart", "cardiomyocyte", "mitochondrion", "molecule"]:
		destination = Catalog.relative(world.current_scale_id, 1)
	if ratio < 1.0 and distance < entry_distance and not destination.is_empty():
		if world.current_scale_id == "earth" and not earth_entry_panel.selected.is_empty(): earth_entry_panel.enter_selected()
		else: observe_scale(destination)
		return
	if ratio>1.0 and world.current_scale_id=="solar_system" and int(stage.get_meta("solar_physical",{}).get("owner",-1))>=0:
		var physical_owner: int = int(stage.get_meta("solar_physical").owner)
		var host_radius: float = float(stage.get_meta("solar_bodies")[physical_owner].node.mesh.radius) if physical_owner<8 else 1.65
		if distance>host_radius*32.0:
			_reset_camera(); return
	# Zooming away through the far boundary restores the parent observation.
	var maximum: float = maxf(minimum, float(stage.get_meta("orbit_max_distance", standard * 5.0)))
	var return_boundary: float = minf(standard*3.0,maximum*.98)
	if stage.has_meta("natural_satellites"): return_boundary=minf(float(stage.get_meta("natural_satellites").extent)*3.0,maximum*.98)
	if ratio > 1.0 and distance > return_boundary and not observation_parent(world.current_scale_id).is_empty():
		# Physical near coordinates (including a large moon orbit) cannot be
		# compared with a schematic solar overview's galaxy-exit distance.
		if world.current_scale_id=="solar_system" and (solar_follow>=0 or _content_follow>=0 or int(stage.get_meta("solar_physical",{}).get("owner",-1))>=0):
			_reset_camera(); return
		_satellite_zoom_return=Satellites.is_system(world.current_scale_id)
		_navigate_relative(-1)
		return
	stage.set_pose(_orbit_target + offset.normalized() * clampf(distance, minimum, maximum), _orbit_target, stage.camera.basis.y if learning_overlay.topic in ["mercury_orbit", "galactic_structure"] or not solar_plane_view.is_empty() else Vector3.UP)


func _hold_solar_overview_zoom(stage: Node, factor: float) -> bool:
	if _solar_zoom_return_stage==0: return false
	if stage.scale_id!="solar_system" or stage.get_instance_id()!=_solar_zoom_return_stage or solar_follow>=0 or _content_follow>=0:
		_solar_zoom_return_stage=0; return false
	var now: int=Time.get_ticks_msec()
	if bool(_solar_camera_motion.get("overview_return",false)):
		if factor>1.0: _solar_zoom_out_ms=now
		else:
			# Reversing the pinch can approach the arriving overview without
			# cancelling the flight at a distant former physical-frame position.
			var finish: Vector3=_solar_camera_motion.finish
			var standard: float=stage.default_position.distance_to(stage.default_target)
			_solar_camera_motion.finish=finish.normalized()*clampf(finish.length()*factor,standard*.45,standard)
		return true
	if factor>1.0 and now-_solar_zoom_out_ms<SOLAR_ZOOM_RELEASE_MS:
		_solar_zoom_out_ms=now
		return true
	_solar_zoom_return_stage=0
	return false


func _pan_camera(stage: Node, pixels: Vector2) -> void:
	_solar_camera_motion.clear()
	if pixels.is_zero_approx(): return
	if world.current_scale_id=="solar_system": stage.set_meta("solar_camera_exploring",true)
	if world.current_scale_id=="night_sky":
		_content_follow=-1; _direct_content.clear()
		GroundSky.rotate_view(stage,pixels)
		_orbit_target=GroundSky.EYE-stage.camera.basis.z*10.0
		return
	var camera: Camera3D=stage.camera
	var depth: float=maxf(camera.near*1.1,-camera.to_local(_orbit_target).z)
	var center: Vector2=camera.get_viewport().get_visible_rect().size*.5
	var world_shift: Vector3=camera.project_position(center,depth)-camera.project_position(center+pixels,depth)
	var parent: Node3D=camera.get_parent_node_3d()
	var shift: Vector3=parent.global_basis.inverse()*world_shift if parent!=null else world_shift
	_pan_offset+=shift
	_orbit_target+=shift
	stage.set_pose(camera.position+shift,_orbit_target,camera.basis.y)
	SatelliteFraming.remember(stage)


func _reset_observation_view() -> void:
	if coordinator.is_busy(): return
	if world.current_scale_id=="earth" and learning_overlay.topic=="earth_daylight":
		ExplorerPanel.Topics.EarthDaylight.focus(self); return
	if world.current_scale_id=="earth_moon" and learning_overlay.topic=="lunar_phases":
		if lunar_observation_view=="earth": focus_lunar(true); return
		if lunar_observation_view=="shadow": focus_eclipse_earth(); return
		focus_lunar(false); return
	if world.current_scale_id=="solar_system" and learning_overlay.topic=="mercury_orbit":
		focus_kepler(); return
	if world.current_scale_id=="galaxy" and learning_overlay.topic=="galactic_structure":
		ExplorerPanel.Topics.Galactic.focus(self,coordinator.active_scene.get_meta("galactic_observation").view=="side"); return
	if world.current_scale_id=="solar_system" and not solar_plane_view.is_empty():
		focus_solar_plane(solar_plane_view=="side"); return
	if solar_follow>=0:
		follow_planet(solar_follow)
	elif solar_orbit_focus>=0:
		focus_planet_orbit(solar_orbit_focus)
	elif _content_follow>=0:
		follow_content(_content_follow+1,_direct_content)
	else:
		_reset_camera()


func _toggle_pause() -> void:
	soundscape.cue("time")
	world.set_paused(not world.paused)
	world.record_observation("paused" if world.paused else "running")
	pause_button.text = I18n.text(I18n.text("继续时间") if world.paused else I18n.text("暂停时间"))


func _reset_camera() -> void:
	_end_solar_close_playback()
	var return_flight: bool=world.current_scale_id=="solar_system" and (solar_follow>=0 or _content_follow>=0 or not _solar_camera_motion.is_empty() or int(coordinator.active_scene.get_meta("solar_physical",{}).get("owner",-1))>=0)
	_solar_zoom_return_stage=0
	var previous_target: Vector3=_orbit_target
	var previous_fov: float=coordinator.active_scene.camera.fov
	_solar_camera_motion.clear()
	if message_label.text.begins_with(I18n.text("正在观察 · ")): message_label.text = I18n.text("")
	_pan_offset = Vector3.ZERO
	_city_people_view = false
	_city_street_view = false
	_refresh_city_view_button()
	if is_instance_valid(learning_overlay) and learning_overlay.topic in ["mercury_orbit","lunar_phases","earth_daylight"]: explorer_panel.clear_topic()
	solar_follow = -1
	solar_orbit_focus = -1
	solar_plane_view = ""
	_content_follow = -1
	_direct_content.clear()
	if coordinator.is_busy(): coordinator.cancel("camera_reset")
	var stage: Node = coordinator.active_scene
	SatelliteFraming.clear(stage)
	if stage.has_meta("natural_satellites") or stage.scale_id=="earth_moon": stage.camera.fov=48.0; stage.camera.near=.008
	if stage.has_meta("natural_satellites"): SatelliteBuilder.select(stage,-1)
	if world.current_scale_id=="night_sky":
		GroundSky.reset_view(stage)
		_orbit_target=stage.default_target
		return
	if world.current_scale_id=="solar_system":
		stage.camera.near=.01
		stage.set_meta("solar_orbit_overview",false)
		stage.set_meta("solar_satellite_selected_key","")
		stage.builder.set_solar_focus(stage,-1)
		stage.builder.solar_overview_pose(stage,solar_jd,solar_true_distance)
	_orbit_target = stage.default_target
	if world.current_scale_id=="atom" and stage.has_meta("oxygen_atom"):
		select_atom_view(int(stage.get_meta("oxygen_atom").mode),bool(stage.get_meta("oxygen_atom").section))
		return
	var position: Vector3 = stage.default_position
	if Satellites.is_system(world.current_scale_id):
		var window: Vector2 = get_viewport().get_visible_rect().size
		var left: float = explorer_panel.get_global_rect().end.x+16. if explorer_panel.visible else 0.
		position=stage.builder.overview_position(stage,window.x-left,window.y)
	if return_flight:
		stage.camera.fov=previous_fov
		_begin_solar_camera(position,stage.default_target,previous_target,50.0)
		_solar_zoom_return_stage=stage.get_instance_id()
		_solar_zoom_out_ms=Time.get_ticks_msec()
		if not _solar_camera_motion.is_empty(): _solar_camera_motion.overview_return=true
	else: stage.set_pose(position, stage.default_target)


func _resize() -> void:
	_apply_ui_scale()
	var pixels: Vector2i = Vector2i(get_viewport().get_texture().get_size())
	var size: Vector2i = ui_view_size()
	if is_instance_valid(immersive_interface): immersive_interface.fit_window(size)
	if is_instance_valid(explorer_panel): explorer_panel.fit_window(size)
	if is_instance_valid(earth_entry_panel): earth_entry_panel.fit_window(size)
	if is_instance_valid(world_guide): world_guide.fit_window(size)
	if is_instance_valid(guided_journey): guided_journey.fit_window(size)
	if is_instance_valid(size_comparison): size_comparison.fit_window(size)
	if is_instance_valid(coordinator) and is_instance_valid(coordinator.active_scene) and is_instance_valid(learning_overlay) and world.current_scale_id=="galaxy" and learning_overlay.topic=="galactic_structure":
		ExplorerPanel.Topics.Galactic.focus(self,coordinator.active_scene.get_meta("galactic_observation").view=="side")
	if is_instance_valid(coordinator) and is_instance_valid(coordinator.active_scene) and not coordinator.is_busy() and Satellites.is_system(world.current_scale_id) and _content_follow<0 and not SatelliteFraming.is_pair(coordinator.active_scene): _reset_camera()
	if is_instance_valid(coordinator) and is_instance_valid(coordinator.active_scene) and not coordinator.is_busy() and is_instance_valid(learning_overlay) and world.current_scale_id=="earth" and learning_overlay.topic=="earth_daylight":
		ExplorerPanel.Topics.EarthDaylight.focus(self,true)
	if is_instance_valid(info_panel):
		info_panel.offset_left = -minf(440,float(size.x)-32); info_panel.offset_right = -16
		info_panel.offset_top = 92; info_panel.offset_bottom = float(size.y)-88
	if is_instance_valid(sound_panel):
		sound_panel.offset_left = -minf(400,float(size.x)-32); sound_panel.offset_right = -16
		sound_panel.offset_top = 92
		var content: Control=sound_panel.get_child(0).get_child(0)
		sound_panel.offset_bottom = 92+minf(content.get_combined_minimum_size().y+40,maxf(120,size.y-180))
	if is_instance_valid(observation_panel):
		observation_panel.offset_top = 92; observation_panel.offset_bottom = -88
		observation_panel.offset_left = -minf(500.0,float(size.x)-32.0); observation_panel.offset_right = -16
	for stage: Node in scene_host.get_children():
		if stage.has_method("set_view_size"): stage.set_view_size(pixels, _render_ratio)
	if is_instance_valid(coordinator) and is_instance_valid(coordinator.active_scene) and not coordinator.is_busy() and world.current_scale_id=="solar_system" and not solar_plane_view.is_empty():
		focus_solar_plane(solar_plane_view=="side")


func _toggle_render_quality() -> void:
	_set_render_quality(RenderQuality.BALANCED if _render_ratio == RenderQuality.CLEAR else RenderQuality.CLEAR)


func _set_render_quality(value: float) -> void:
	if value not in [RenderQuality.ECONOMY, RenderQuality.BALANCED, RenderQuality.CLEAR]: return
	_render_ratio = value
	get_window().set_meta("experience_render_ratio", _render_ratio)
	_resize()
	quality_button.text = I18n.text(I18n.text("画质：") + RenderQuality.label(_render_ratio))
	message_label.text = I18n.text(I18n.text("节能画质 · 保留场景效果与清晰文字，远处细节会稍柔和") if value == RenderQuality.ECONOMY else I18n.text("已提高画面清晰度") if value == RenderQuality.CLEAR else I18n.text("流畅画质 · 平衡清晰度与硬件开销"))



func _button(text_value: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = I18n.text(I18n.text(text_value))
	button.custom_minimum_size.y = InterfaceTheme.CONTROL_HEIGHT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button


func _label(text_value: String, size: int, color: Color = Color(0.90, 0.96, 0.97)) -> Label:
	var label: Label = Label.new()
	label.text = I18n.text(I18n.text(text_value))
	if size>=19: label.theme_type_variation="Heading"
	label.add_theme_font_size_override("font_size", InterfaceTheme.readable_size(size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0.035, 0.05, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _scene_caption(text_value: String, size: int, color: Color = Color(0.90, 0.96, 0.97)) -> Label:
	# These labels sit directly over a 3D scene, including pale sky and sand.
	var label: Label = _label(text_value, size, color)
	label.add_theme_color_override("font_outline_color", Color(0.005, 0.025, 0.035, 0.95))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	hud.theme = InterfaceTheme.build(ui_scale)
	_apply_ui_scale()
	var style: StyleBoxFlat = InterfaceTheme.surface()
	immersive_interface = ImmersiveInterface.new()
	hud.add_child(immersive_interface)
	immersive_interface.configure(self)
	navigation_bar = NavigationBar.new()
	immersive_interface.header_row.add_child(navigation_bar)
	navigation_bar.configure(self)
	immersive_interface.add_tools()
	clean_button = _button(I18n.text("纯净观察 · F9"),func() -> void: clean_observation.toggle())
	hud.add_child(clean_button); clean_button.hide()
	target_button = _button(I18n.text("观察"),_navigate_relative.bind(1))
	hud.add_child(target_button); target_button.hide()
	earth_entry_panel = EarthEntryPanel.new()
	hud.add_child(earth_entry_panel)
	earth_entry_panel.configure(self,style)
	earth_entry_panel.fit_window(ui_view_size())
	info_panel = PanelContainer.new()
	hud.add_child(info_panel)
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	info_panel.offset_left = -416; info_panel.offset_top = 78; info_panel.offset_right = -20; info_panel.offset_bottom = 580
	var panel_style: StyleBoxFlat = style.duplicate()
	panel_style.bg_color = InterfaceTheme.INK
	panel_style.content_margin_left = 22; panel_style.content_margin_right = 22
	panel_style.content_margin_top = 20; panel_style.content_margin_bottom = 20
	explorer_panel = ExplorerPanel.new()
	hud.add_child(explorer_panel)
	explorer_panel.configure(self,panel_style)
	learning_overlay = LearningOverlay.new()
	hud.add_child(learning_overlay)
	learning_overlay.configure(self)
	_build_sound_panel(panel_style)
	observation_panel = ObservationPanel.new()
	hud.add_child(observation_panel)
	observation_panel.configure(self, panel_style)
	info_panel.add_theme_stylebox_override("panel", panel_style)
	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.meta_clicked.connect(func(meta: Variant) -> void:
		if ScienceReference.allows_url(world.current_scale_id,str(meta)): OS.shell_open(str(meta)))
	info_label.custom_minimum_size = Vector2(0, 60)
	info_label.add_theme_font_size_override("normal_font_size", InterfaceTheme.BODY_SIZE)
	var info_column: VBoxContainer = VBoxContainer.new()
	info_column.add_theme_constant_override("separation",14)
	info_panel.add_child(info_column)
	var info_heading: HBoxContainer = HBoxContainer.new(); info_column.add_child(info_heading)
	var info_title: Label = _label(I18n.text("依据与边界"),22); info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info_heading.add_child(info_title)
	info_heading.add_child(InterfaceTheme.icon("close",I18n.text("关闭科学说明 · Esc"),info_panel.hide))
	info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_column.add_child(info_label)
	info_panel.visible = false
	anatomy_controls = HBoxContainer.new()
	hud.add_child(anatomy_controls)
	anatomy_controls.position = Vector2(33, 165)
	anatomy_controls.add_theme_constant_override("separation", 7)
	cutaway_button = _button(I18n.text("查看外形  C"), _toggle_cutaway)
	anatomy_controls.add_child(cutaway_button)
	anatomy_controls.visible = false
	debug_label = _label("", 12)
	hud.add_child(debug_label)
	debug_label.position = Vector2(32, 130)
	debug_label.visible = false
	science_badge = _scene_caption("", 13, Color(0.77, 0.89, 0.90))
	hud.add_child(science_badge)
	science_badge.position = Vector2(33, 78)
	science_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_background: StyleBoxFlat = StyleBoxFlat.new()
	badge_background.bg_color = Color(0.012, 0.04, 0.05, 0.68)
	badge_background.set_corner_radius_all(5)
	badge_background.content_margin_left = 8
	badge_background.content_margin_right = 8
	badge_background.content_margin_top = 5
	badge_background.content_margin_bottom = 5
	science_badge.add_theme_stylebox_override("normal", badge_background)
	world_guide = WorldGuide.new()
	hud.add_child(world_guide)
	world_guide.configure(self,panel_style)
	guided_journey=GuidedJourney.new()
	hud.add_child(guided_journey)
	guided_journey.configure(self,panel_style)
	guided_journey.restore(_journey_restore)
	size_comparison=SolarSizeComparison.new()
	hud.add_child(size_comparison)
	size_comparison.configure(self,panel_style)
	clean_observation=CleanObservation.new()
	layer.add_child(clean_observation)
	clean_observation.configure(self,hud.theme)
	object_pointer=ObjectPointer.new()
	layer.add_child(object_pointer) # Requested hover names remain usable in pure observation.
	object_pointer.configure(self)
	optical_inspector=OpticalInspector.new()
	hud.add_child(optical_inspector)
	optical_inspector.configure(self)
	var solar_compass: Control = SolarContextCompass.new()
	hud.add_child(solar_compass)
	solar_compass.configure(self)
	loading_status=LoadingStatus.new()
	hud.add_child(loading_status)
	loading_status.configure(self,panel_style)


func _build_sound_panel(style: StyleBoxFlat) -> void:
	sound_panel = PanelContainer.new()
	hud.add_child(sound_panel)
	sound_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sound_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	sound_panel.offset_left = -356; sound_panel.offset_top = 78
	sound_panel.offset_right = -20; sound_panel.offset_bottom = 390
	sound_panel.add_theme_stylebox_override("panel", style)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 9)
	var scroller: ScrollContainer = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sound_panel.add_child(scroller)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(rows)
	var heading: HBoxContainer = HBoxContainer.new(); rows.add_child(heading)
	var sound_title: Label = _label(I18n.text("声音"),22); sound_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_child(sound_title)
	heading.add_child(InterfaceTheme.icon("close",I18n.text("关闭声音设置"),sound_panel.hide))
	var labels: Dictionary = {"master": I18n.text("主音量"), "environment_volume": I18n.text("环境声"), "music_volume": I18n.text("音乐"), "effects_volume": I18n.text("效果音")}
	for property: String in labels:
		var row: HBoxContainer = HBoxContainer.new()
		rows.add_child(row)
		var caption: Label = _label(labels[property], 13)
		caption.custom_minimum_size.x = 58
		row.add_child(caption)
		var slider: HSlider = HSlider.new()
		slider.name = property
		slider.min_value = 0.0; slider.max_value = 1.0; slider.step = 0.01
		slider.value = float(soundscape.get(property))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 125
		slider.tooltip_text = labels[property]
		slider.value_changed.connect(func(value: float) -> void: soundscape.set(property, value))
		row.add_child(slider)
	sound_mute_button = _button(I18n.text("开启声音  M") if _muted else I18n.text("静音  M"), _toggle_mute)
	rows.add_child(sound_mute_button)
	sound_context_label = _label("",12)
	sound_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(sound_context_label)
	sound_panel.visible = false


func _toggle_mute() -> void:
	_muted = not _muted
	if is_instance_valid(sound_mute_button): sound_mute_button.text = I18n.text(I18n.text("开启声音  M") if _muted else I18n.text("静音  M"))


func _update_ui() -> void:
	var id: String = world.current_scale_id
	if solar_demo_auto:
		_solar_origin_jd = solar_jd; _solar_origin_time = world.simulation_time_s
		solar_rate = 1.0/1440.0 if id=="night_sky" else 1.0/24.0 if id=="earth_moon" or Satellites.is_system(id) and Satellites.available(solar_jd) else DEFAULT_SOLAR_RATE if id in ["solar_system","earth_moon"] else 0.0
	earth_entry_panel.visible = id == "earth" and not coordinator.is_busy() and not explorer_panel.visible and not (is_instance_valid(guided_journey) and guided_journey.visible) and not (is_instance_valid(learning_overlay) and learning_overlay.topic=="earth_daylight")
	anatomy_controls.visible = id == "heart"
	if id == "heart": _update_cutaway_button()
	var science_text: String = I18n.meta_text(coordinator.active_scene,"scientific_label", "")
	science_badge.text = I18n.text(science_text)
	title_label.text = I18n.text(str(Catalog.describe(id).label))
	subtitle_label.text = I18n.text(SUBTITLES.get(id, "TWINVERSE  /  A JOURNEY THROUGH SCALE"))
	context_label.text = I18n.text(I18n.text("   孪生宇宙 / ") + (I18n.text("地球分支") if id in ["woodland","city","desert","polar","arctic","earth_moon"] else I18n.text("跨尺度观察")))
	previous_button.disabled = Catalog.relative(id,-1).is_empty()
	next_button.disabled = Catalog.relative(id,1).is_empty() and id!="city"
	previous_button.text = I18n.text(I18n.text("返回太阳系") if Satellites.is_system(id) else I18n.text("返回地球") if id in ["woodland","city","desert","polar","arctic","earth_moon"] else I18n.text("返回上层"))
	target_button.hide()
	var next_id: String = Catalog.relative(id,1)
	target_button.text = I18n.text("⊙  " + str(Catalog.describe(next_id).get("label","")))
	if _follow_scale!=id:
		_city_people_view = false
		_city_street_view = false
		_content_follow = -1
		_direct_content.clear()
		solar_follow = -1
		solar_orbit_focus = -1
		solar_plane_view = ""
		if id=="solar_system":
			coordinator.active_scene.set_meta("solar_orbit_overview",false)
			coordinator.active_scene.builder.set_solar_focus(coordinator.active_scene,-1)
			if not _solar_close_playback.is_empty() and not bool(_solar_close_playback.get("context",false)):
				var target: int=int(_solar_close_playback.target)
				solar_follow=target if target<8 else -1
				_content_follow=target-8 if target>=8 else -1
				coordinator.active_scene.builder.set_solar_focus(coordinator.active_scene,solar_follow)
		_follow_scale = id
	_refresh_city_view_button()
	info_label.text = I18n.text("[b]" + title_label.text + "[/b]\n\n" + ScienceReference.text_for(id) + I18n.text("\n\n[b]场景说明[/b]\n"))
	if id in ["pacific", "reef", "school", "fish"]:
		info_label.text += I18n.text(I18n.text("蜥蜴岛 · 北大堡礁\n海葵双锯鱼 [i]Amphiprion percula[/i]\n宿主：壮丽海葵\n\n80 mm 个体、约 5 m 水深及场景布局为作者化设定。海葵鱼留在局部宿主附近；背景包含褐吊、四带笛鲷、青绿雀鲷、绿海龟和蓝斑条尾魟参考形态；不当作实测物种分布或生态模拟。\n\n礁区→行为→循环→细胞→ATP已接入统一时间的完整参考模型。点击“影响链 / 记录”切换情境并查看曲线、收支与来源；全部生理参数尚待物种标定。"))
	elif id == "heart":
		info_label.text += I18n.text(I18n.text("[b]科学示意 · 示意放大[/b]\n\n一般成年硬骨鱼结构参考，并非该目标鱼的扫描重建。\n\n静脉窦 → 心房 → 心室 → 动脉球 → 鳃。\n\n组织运动与血流颗粒用于解释方向，未对应实测心率或流速。"))
	else:
		info_label.text += I18n.text(I18n.meta_text(coordinator.active_scene,"scientific_label",I18n.meta_text(coordinator.active_scene,"scientific_note",I18n.text("局部尺度与结构解释原型；非实时科学测量。"))))


func _update_cutaway_button() -> void:
	cutaway_button.text = I18n.text(I18n.text("查看外形  C") if bool(coordinator.active_scene.get_meta("anatomy_cutaway_active", true)) else I18n.text("展开剖面  C"))


func _toggle_cutaway() -> void:
	if coordinator.is_busy() or world.current_scale_id != "heart": return
	soundscape.cue("select")
	var stage: Node = coordinator.active_scene
	stage.builder.set_cutaway(stage, not bool(stage.get_meta("anatomy_cutaway_active", true)))
	_update_cutaway_button()


func _select_heart_region(region_id: String) -> void:
	if coordinator.is_busy() or world.current_scale_id != "heart": return
	var stage: Node = coordinator.active_scene
	stage.builder.select_region(stage, region_id)
	for region: Dictionary in stage.builder.get_regions(stage):
		if region.id == region_id:
			soundscape.cue("select")
			info_label.text = I18n.text("[b]" + str(region.label) + "[/b]\n\n" + str(region.description) + "\n\n" + I18n.meta_text(stage,"scientific_label") + "\n\n" + ScienceReference.text_for("heart"))
			observation_panel.hide()
			info_panel.visible = true
			message_label.text = I18n.text(I18n.text("已选择 · ") + str(region.label))
			return


func _pick_heart_region(point: Vector2) -> void:
	var stage: Node = coordinator.active_scene
	var best: String = ""
	var nearest: float = 70.0
	for region: Dictionary in stage.builder.get_regions(stage):
		if stage.camera.is_position_behind(region.position): continue
		var projected: Vector2 = stage.camera.unproject_position(region.position)
		var distance: float = projected.distance_to(point)
		if distance < nearest:
			nearest = distance
			best = region.id
	if not best.is_empty(): _select_heart_region(best)


func _setup_sound() -> void:
	if DisplayServer.get_name() == "headless": return
	_audio = AudioStreamPlayer.new()
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.25
	_audio.stream = stream
	_audio.volume_db = 0.0
	add_child(_audio)
	_audio.play()
	_audio_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _cycle_time_scale() -> void:
	soundscape.cue("time")
	var scales: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]
	world.set_time_scale(scales[(scales.find(world.time_scale) + 1) % scales.size()])
	world.record_observation("speed")


func _toggle_reduced_motion() -> void:
	_reduced_motion = not _reduced_motion
	if _reduced_motion and not _solar_camera_motion.is_empty():
		coordinator.active_scene.set_pose(_orbit_target+Vector3(_solar_camera_motion.finish),_orbit_target)
		_solar_camera_motion.clear()
	get_window().set_meta("experience_reduced_motion", _reduced_motion)
	for stage: Node in scene_host.get_children():
		stage.reduced_motion = _reduced_motion
		if stage.builder.has_method("set_reduced_motion"): stage.builder.set_reduced_motion(stage, _reduced_motion)
	message_label.text = I18n.text(I18n.text("减少镜头运动：") + (I18n.text("开") if _reduced_motion else I18n.text("关")))


func _fill_audio() -> void:
	if _audio_playback == null: return
	var count: int = _audio_playback.get_frames_available()
	var immersion: float = float(coordinator.active_scene.get_meta("water_immersion", 0.0))
	var destination: String = world.current_scale_id
	if is_instance_valid(_incoming):
		destination = _incoming.scale_id
		immersion = lerpf(immersion, float(_incoming.get_meta("water_immersion", 0.0)), _progress_alpha)
	soundscape.muted = _muted
	soundscape.set_context(world.current_scale_id, destination, _progress_alpha if is_instance_valid(_incoming) else 0.0, immersion)
	for i: int in range(count):
		_audio_playback.push_frame(soundscape.next_frame())


func _capture_when_ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(4)
		return
	await get_tree().create_timer(_capture_after).timeout
	await RenderingServer.frame_post_draw
	var result: Error = get_viewport().get_texture().get_image().save_png(_capture_path)
	print("EXPERIENCE_CAPTURE ", error_string(result), " ", _capture_path)
	if _run_duration <= 0: _quit(0 if result == OK else 5)


func _sync_window_availability() -> void:
	# Application focus alone can stay true while a macOS fullscreen Space stops
	# drawing. Do not advance the world or wait for preparation frames there.
	# Headless tests explicitly control their simulated foreground notifications.
	if DisplayServer.get_name() == "headless": return
	var available: bool = DisplayServer.window_can_draw() and (_measurement_screen >= 0 or get_window().has_focus())
	if world.foreground != available: world.set_foreground(available)
	if not available and coordinator.is_busy():
		coordinator.cancel("window_unavailable")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _quit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _measurement_screen >= 0:
			_sync_window_availability()
			return
		world.set_foreground(false)
		# macOS can stop drawing an occluded/fullscreen window. Cancel the
		# approach, keeping the last usable world and pose; do not silently
		# finish a camera move or wait for unavailable GPU preparation frames.
		if is_instance_valid(coordinator) and coordinator.is_busy():
			coordinator.cancel("application_focus_lost")
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: world.set_foreground(true)


func _quit(code: int = 0, discard_unsaved: bool = false) -> void:
	if _shutting_down: return
	if is_instance_valid(coordinator) and coordinator.is_busy(): coordinator.cancel("application_quit")
	if code == 0 and not discard_unsaved:
		var save_status: String = save_world(false)
		if save_status not in ["ok", "disabled", "protected", "changed_on_disk", "not_ready", "queued", "trial"]:
			if not is_instance_valid(_save_failure_dialog):
				_save_failure_dialog = ConfirmationDialog.new()
				_save_failure_dialog.theme = hud.theme
				_save_failure_dialog.title = I18n.text("本次观察尚未保存")
				_save_failure_dialog.dialog_text = I18n.text("未能保存本次观察。\n可以返回观察，检查磁盘空间或目录权限后重试。")
				_save_failure_dialog.ok_button_text = I18n.text("仍然退出")
				_save_failure_dialog.cancel_button_text = I18n.text("返回观察")
				_save_failure_dialog.confirmed.connect(_quit.bind(0, true))
				add_child(_save_failure_dialog)
			_save_failure_dialog.popup_centered(Vector2i(440, 160))
			return
	_shutting_down = true
	if is_instance_valid(_audio):
		_audio.stop()
		_audio_playback = null
		_audio.stream = null
		_audio.queue_free()
		_audio = null
		# Let the audio server consume its stop command before engine shutdown.
		await get_tree().process_frame
		await get_tree().process_frame
	if _motion_recording:
		print("MOTION_FINISHED ", JSON.stringify(motion.finish()))
	if _recording:
		var summary: Dictionary = recorder.finish()
		print("CAPTURE_FINISHED ", JSON.stringify(summary))
	get_tree().quit(code)


func _asset_audit(output_path: String) -> void:
	_shutting_down = true
	var report: Dictionary = {"debug_build": OS.is_debug_build(), "headless": DisplayServer.get_name() == "headless", "scenes": [], "errors": []}
	for family: String in ["ocean", "anatomy", "cosmos", "micro"]:
		var scene: PackedScene = load("res://scenes/experience/" + family + "_stage.tscn") as PackedScene
		var node: Node = scene.instantiate()
		var exported: Array = []
		for property: Dictionary in node.get_property_list():
			if str(property.name) in ["asset_keys", "asset_scenes", "texture_keys", "texture_assets", "builder"]:
				exported.append({"name": property.name, "usage": property.usage, "type": property.type})
		if node.asset_keys.size() != node.asset_scenes.size() or node.texture_keys.size() != node.texture_assets.size():
			report.errors.append("Exported resource keys mismatch: " + family)
		var resources: Array = []
		for asset: PackedScene in node.asset_scenes:
			resources.append(asset.resource_path if asset != null else "NULL")
		report.scenes.append({"family": family, "keys": Array(node.asset_keys), "scene_count": node.asset_scenes.size(), "texture_keys": Array(node.texture_keys), "texture_count": node.texture_assets.size(), "resources": resources, "properties": exported})
		node.free()
	report["status"] = "passed" if report.errors.is_empty() else "failed"
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	coordinator.free()
	coordinator = null
	scene_host.free()
	scene_host = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if report.errors.is_empty() else 9)


func _toggle_observation() -> void:
	guided_journey.hide()
	observation_panel.visible = not observation_panel.visible
	if observation_panel.visible:
		info_panel.hide()
		explorer_panel.hide()
		observation_panel.refresh()


func observe_scale(scale_id: String) -> void:
	if coordinator.is_busy() or not Catalog.contains(scale_id): return
	if scale_id == world.current_scale_id:
		_reset_camera()
	else:
		navigate_to(scale_id)


func is_trial() -> bool:
	return not _trial_return.is_empty()


func _refresh_observation_controls() -> void:
	pause_button.text = I18n.text(I18n.text("继续时间") if world.paused else I18n.text("暂停时间"))
	save_button.disabled = is_trial() or not _persistence_enabled or (_store != null and _store.protected)
	save_button.text = I18n.text(I18n.text("临时试览") if is_trial() else (I18n.text("存档已保护") if _store != null and _store.protected else I18n.text("保存世界")))
	if observation_panel.visible: observation_panel.refresh()


func toggle_trial() -> void:
	if coordinator.is_busy() or not world.foreground: return
	var active_id: String = world.current_scale_id
	var target_id: String
	if not is_trial():
		_remember_view()
		var status: String = save_world(false)
		if status not in ["ok", "disabled"]:
			message_label.text = I18n.text(I18n.text("原世界尚未保存，请稍后重试"))
			return
		_trial_return = world.checkpoint()
		_trial_views = _views.duplicate(true)
		var fresh: WorldState = WorldState.new()
		fresh.seed = world.seed
		fresh.current_scale_id = active_id
		world.restore_checkpoint(fresh.checkpoint())
		_views.clear()
		_restore_solar_view()
		target_id = WorldState.INITIAL_SCALE_ID
	else:
		target_id = str(_trial_return.current_scale_id)
		world.restore_checkpoint(_trial_return)
		world.current_scale_id = active_id
		_views = _trial_views.duplicate(true)
		_restore_solar_view()
		_returning_from_trial = true
	navigation_bar.reset_history()
	_switching_observation = true
	# Swap value state on the same authority. Failed/cancelled navigation keeps
	# the return checkpoint, so retrying cannot discard the original world.
	if target_id == active_id:
		coordinator.active_scene.set_world_time(world.simulation_time_s)
		if not _returning_from_trial: _reset_camera()
		_on_interactive(0, target_id, coordinator.active_scene)
	else:
		navigate_to(target_id)
	_refresh_observation_controls()
	message_label.text = I18n.text(I18n.text("正在返回原世界") if _returning_from_trial else (I18n.text("临时试览 · 原世界已保留") if is_trial() else I18n.text("已返回原世界")))


func _toggle_info() -> void:
	if is_instance_valid(clean_observation): clean_observation.set_active(false)
	guided_journey.hide()
	info_panel.visible = not info_panel.visible
	if info_panel.visible:
		observation_panel.hide()
		explorer_panel.hide()


func _toggle_explorer() -> void:
	guided_journey.hide()
	explorer_panel.visible = not explorer_panel.visible
	if explorer_panel.visible:
		observation_panel.hide()
		info_panel.hide()

func _open_guide() -> void:
	if is_instance_valid(clean_observation): clean_observation.set_active(false)
	if coordinator.is_busy(): return
	guided_journey.hide()
	explorer_panel.hide()
	info_panel.hide()
	observation_panel.hide()
	sound_panel.hide()
	world_guide.open()

func start_guide_visit(scale_id: String, topic_id: String = "", preserve_date: bool = false, earth_polar_reference: bool = false) -> void:
	if coordinator.is_busy() or not world.foreground or not Catalog.contains(scale_id): return
	_guide_visit = {"scale":scale_id,"topic":topic_id,"preserve_date":preserve_date,"earth_polar_reference":earth_polar_reference}
	world_guide.hide()
	explorer_panel.hide()
	observe_scale(scale_id)

func _finish_guide_visit() -> void:
	if _guide_visit.is_empty() or coordinator.is_busy(): return
	if world.current_scale_id != str(_guide_visit.scale):
		_guide_visit.clear()
		return
	var topic: String = _guide_visit.topic
	var preserve_date: bool = bool(_guide_visit.get("preserve_date",false))
	var earth_polar_reference: bool = bool(_guide_visit.get("earth_polar_reference",false))
	_guide_visit.clear()
	explorer_panel.show()
	# Refresh against the arrived scene before selecting its actual lesson target.
	explorer_panel._process(0.0)
	explorer_panel.clear_topic()
	if not topic.is_empty(): explorer_panel.select_topic(topic,preserve_date)
	elif world.current_scale_id in ["fish","heart"]:
		message_label.text = I18n.text(I18n.text("继续深入可进入下一层；影响链 / 记录可比较氧的输送与利用。"))
	if earth_polar_reference and topic=="earth_daylight" and world.current_scale_id=="earth":
		explorer_panel.earth_daylight_controls.focus_polar()
	explorer_panel.scroll.scroll_vertical = 0


func _restore_solar_view() -> void:
	_solar_close_playback.clear()
	var view: Dictionary = _views.get(world.current_scale_id,{}).get("astronomy",{})
	for entry: Dictionary in _views.values():
		var candidate: Dictionary = entry.get("astronomy",{})
		if not candidate.is_empty() and (view.is_empty() or float(candidate.time)>float(view.time)): view = candidate
	if view.is_empty():
		_solar_origin_time = world.simulation_time_s
		_solar_origin_jd = Ephemeris.DEFAULT_JD
		solar_jd = Ephemeris.DEFAULT_JD
		solar_rate = 0.0
		solar_demo_auto = true
		solar_manual_setting = false
		ground_light_preview = false
		solar_true_distance = false
		return
	solar_jd = float(view.jd)
	_solar_origin_jd = solar_jd
	_solar_origin_time = float(view.time)
	solar_rate = float(view.rate)
	# Earlier releases wrote an untouched default as auto=false. Only migrate
	# that unmarked default; chosen dates/rates and new explicit holds survive.
	var legacy_default: bool = not view.has("manual") and absf(solar_jd-Ephemeris.DEFAULT_JD)<1e-9 and solar_rate==0.0
	solar_demo_auto = bool(view.get("auto",false)) or legacy_default
	solar_manual_setting = bool(view.get("manual",not solar_demo_auto))
	if world.current_scale_id=="solar_system" and view.get("close_playback") is Dictionary:
		_solar_close_playback=view.close_playback.duplicate()
	solar_true_distance = bool(view.true_distance)
	ground_light_preview = bool(view.get("ground_light",false))

func set_solar_date(value: float) -> void:
	if Satellites.is_system(world.current_scale_id) and not Satellites.available(value):
		message_label.text = I18n.text(I18n.text("卫星位置支持1995—2050；保持当前日期"))
		return
	solar_demo_auto = false
	solar_manual_setting = true
	# Explicit date/rate controls take ownership of playback, including return.
	_solar_close_playback.clear()
	solar_jd = clampf(value,Ephemeris.START_JD,Ephemeris.END_JD)
	_solar_origin_jd = solar_jd
	_solar_origin_time = world.simulation_time_s
	if Satellites.is_system(world.current_scale_id) and message_label.text.contains(I18n.text("卫星缓存")):
		message_label.text=I18n.text("")

func set_solar_rate(value: float) -> void:
	if Satellites.is_system(world.current_scale_id) and not Satellites.available(solar_jd):
		solar_rate=0.0
		message_label.text=I18n.text(I18n.text("当前日期超出1995—2050卫星位置范围"))
		return
	set_solar_date(solar_jd)
	solar_rate = value

func _set_solar_playback_rate(value: float) -> void:
	# Rebase at the current date. Changing the rate never rewinds elapsed time.
	_solar_origin_jd=solar_jd
	_solar_origin_time=world.simulation_time_s
	solar_rate=value


func _begin_solar_close_playback(target: int) -> void:
	if world.current_scale_id!="solar_system": return
	if not _solar_close_playback.is_empty():
		_solar_close_playback.target=target
		_solar_close_playback.erase("context")
		return
	if solar_manual_setting or solar_rate<=SOLAR_CLOSE_RATE: return
	_solar_close_playback={"rate":solar_rate,"auto":solar_demo_auto,"target":target}
	solar_demo_auto=false
	_set_solar_playback_rate(SOLAR_CLOSE_RATE)


func _end_solar_close_playback() -> void:
	if _solar_close_playback.is_empty(): return
	var previous: Dictionary=_solar_close_playback.duplicate()
	_solar_close_playback.clear()
	_set_solar_playback_rate(float(previous.rate))
	solar_demo_auto=bool(previous.auto)


func _sync_solar_physical_context(stage: Node) -> void:
	if stage!=coordinator.active_scene or world.current_scale_id!="solar_system" or coordinator.is_busy(): return
	if solar_follow>=0 or _content_follow>=0 or solar_orbit_focus>=0 or not solar_plane_view.is_empty() or learning_overlay.topic=="mercury_orbit": return
	if not bool(stage.get_meta("solar_camera_exploring",false)): return
	var owner: int = int(stage.get_meta("solar_natural_frame",-1))
	if owner>=0:
		var centre: Vector3 = Ephemeris.display_position(owner,solar_jd,solar_true_distance)
		var radius: float = float(stage.get_meta("solar_bodies")[owner].node.mesh.radius)
		if stage.camera.position.distance_to(centre)>radius*24.0: stage.set_meta("solar_natural_frame",-1)
		return
	for index: int in range(8):
		var node: MeshInstance3D = stage.get_meta("solar_bodies")[index].node
		var radius: float = float(node.mesh.radius)*absf(node.scale.x)
		# A Sun-centred overview merely passing nearby stays a schematic view.
		# Natural near detail requires the camera's orbit target to be this body.
		if _orbit_target.distance_to(node.position)>radius*3.0 or stage.camera.position.distance_to(node.position)>radius*22.0 or stage.camera.is_position_behind(node.position): continue
		stage.set_meta("solar_natural_frame",index); return

func _sync_solar_context_playback() -> void:
	if world.current_scale_id!="solar_system" or coordinator.is_busy() or not is_instance_valid(coordinator.active_scene) or not _solar_camera_motion.is_empty(): return
	# Explicit selection already owns the existing close playback/return setting.
	if solar_follow>=0 or _content_follow>=0 or solar_orbit_focus>=0 or not solar_plane_view.is_empty() or learning_overlay.topic=="mercury_orbit": return
	if solar_manual_setting: return
	var index: int = int(coordinator.active_scene.get_meta("solar_visible_context",-1))
	var natural: bool = bool(_solar_close_playback.get("context",false))
	if index>=0:
		if _solar_close_playback.is_empty():
			_begin_solar_close_playback(index)
			if not _solar_close_playback.is_empty(): _solar_close_playback.context=true
		elif natural: _solar_close_playback.target=index
	elif natural: _end_solar_close_playback()


func set_solar_observation_auto(enabled: bool) -> void:
	if world.current_scale_id!="solar_system" or coordinator.is_busy(): return
	if enabled and not solar_manual_setting: return
	_solar_close_playback.clear()
	solar_demo_auto=false
	solar_manual_setting=not enabled
	if enabled:
		if solar_follow>=0: _begin_solar_close_playback(solar_follow)
		elif _content_follow>=0: _begin_solar_close_playback(_content_follow+8)
		else: _sync_solar_context_playback()
	immersive_interface.refresh()


func set_solar_distance(value: bool) -> void:
	solar_true_distance = value
	if is_instance_valid(coordinator.active_scene) and world.current_scale_id=="solar_system":
		coordinator.active_scene.builder.set_solar_view(coordinator.active_scene,solar_jd,value)
	if is_instance_valid(coordinator.active_scene) and world.current_scale_id=="jupiter_moons":
		coordinator.active_scene.builder.set_view(coordinator.active_scene,solar_jd,value)
	elif is_instance_valid(coordinator.active_scene) and coordinator.active_scene.has_meta("natural_satellites"):
		SatelliteBuilder.set_view(coordinator.active_scene,solar_jd,value)
	if is_instance_valid(coordinator.active_scene) and world.current_scale_id=="earth_moon":
		coordinator.active_scene.builder.set_lunar_view(coordinator.active_scene,solar_jd,value)
	if learning_overlay.topic=="lunar_phases" and world.current_scale_id=="earth_moon":
		if lunar_observation_view=="shadow": focus_eclipse_earth()
		else: focus_lunar(lunar_observation_view=="earth")
	elif learning_overlay.topic=="mercury_orbit" and world.current_scale_id=="solar_system": focus_kepler()
	elif world.current_scale_id=="solar_system" and not solar_plane_view.is_empty(): focus_solar_plane(solar_plane_view=="side")
	elif world.current_scale_id=="solar_system" and solar_orbit_focus>=0: focus_planet_orbit(solar_orbit_focus)
	elif world.current_scale_id=="solar_system" and solar_follow>=0: follow_planet(solar_follow)
	elif world.current_scale_id=="solar_system" and _content_follow>=0: follow_content(_content_follow+1)
	else: _reset_camera()

func end_lunar_close_view() -> void:
	if not is_instance_valid(coordinator.active_scene): return
	var stage: Node = coordinator.active_scene
	if stage.camera.projection!=Camera3D.PROJECTION_ORTHOGONAL: return
	lunar_observation_view="free"
	var offset: Vector3 = stage.camera.basis.z*stage.camera.size/(2.0*tan(deg_to_rad(stage.camera.fov*.5)))
	stage.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	stage.set_pose(_orbit_target+offset,_orbit_target,stage.camera.basis.y)
	if stage.has_meta("lunar"): stage.get_meta("lunar").orbit.show()

func focus_lunar(from_earth: bool) -> void:
	if world.current_scale_id!="earth_moon" or coordinator.is_busy(): return
	_pan_offset=Vector3.ZERO
	_solar_camera_motion.clear()
	SatelliteFraming.clear(coordinator.active_scene)
	coordinator.active_scene.camera.fov=50.0
	var stage: Node = coordinator.active_scene
	lunar_observation_view="earth" if from_earth else "orbit"
	stage.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if from_earth else Camera3D.PROJECTION_PERSPECTIVE
	stage.camera.size=1.15
	stage.get_meta("lunar").orbit.visible=not from_earth
	_content_follow=1 if from_earth else -1
	if from_earth:
		_orbit_target=stage.get_meta("lunar").moon.position
		var basis: Basis = Orientation.moon_basis(solar_jd)
		stage.set_pose(_orbit_target-_orbit_target.normalized()*1.1,_orbit_target,basis.y)
	else:
		_orbit_target=Vector3.ZERO
		stage.set_pose(Vector3(0,25,8)*7.5,Vector3.ZERO)

func focus_eclipse_earth() -> void:
	if world.current_scale_id!="earth_moon" or coordinator.is_busy(): return
	_pan_offset=Vector3.ZERO
	_solar_camera_motion.clear()
	SatelliteFraming.clear(coordinator.active_scene)
	coordinator.active_scene.camera.fov=50.0
	var stage: Node=coordinator.active_scene
	stage.builder.set_lunar_view(stage,solar_jd,solar_true_distance)
	lunar_observation_view="shadow"
	stage.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	stage.get_meta("lunar").orbit.hide()
	_content_follow=0
	_orbit_target=Vector3.ZERO
	var point: Vector3=stage.builder.Eclipse.solar_axis_surface(stage.get_meta("eclipse_geometry"))
	stage.set_pose(point.normalized()*3.8,Vector3.ZERO)

func focus_kepler() -> void:
	if world.current_scale_id!="solar_system" or coordinator.is_busy(): return
	_solar_camera_motion.clear()
	SatelliteFraming.clear(coordinator.active_scene)
	coordinator.active_scene.camera.near=.01
	_end_solar_close_playback()
	_pan_offset=Vector3.ZERO
	solar_follow = -1
	solar_orbit_focus = -1
	solar_plane_view = ""
	_content_follow = -1
	var stage: Node = coordinator.active_scene
	stage.set_meta("solar_orbit_overview",false)
	stage.builder.set_solar_focus(stage,-1)
	_orbit_target = Vector3.ZERO
	var el: Array[float] = Ephemeris.elements(0,solar_jd)
	var peri: Vector3 = Ephemeris.display_vector(0,Ephemeris.orbital_point(el,0.0),false).normalized()
	var quarter: Vector3 = Ephemeris.display_vector(0,Ephemeris.orbital_point(el,PI*.5),false)
	var normal: Vector3 = peri.cross(quarter).normalized()
	var distance: float = 12.0*(.55*Ephemeris.ELEMENTS[0][0]/Ephemeris.DISPLAY_A[0] if solar_true_distance else 1.0)
	coordinator.active_scene.set_pose(normal*distance,Vector3.ZERO,normal.cross(peri).normalized())

func follow_planet(index: int, _detail: bool = false) -> void:
	if world.current_scale_id!="solar_system" or coordinator.is_busy() or index>=8: return
	var former: Dictionary=SolarCloseup.observer(coordinator.active_scene,_orbit_target)
	_pan_offset=Vector3.ZERO
	_content_follow=-1
	_direct_content.clear()
	if learning_overlay.topic=="mercury_orbit": explorer_panel.clear_topic()
	solar_follow = index
	solar_orbit_focus = -1
	solar_plane_view = ""
	if index<0:
		_reset_camera()
		return
	_begin_solar_close_playback(index)
	var stage: Node = coordinator.active_scene
	var previous_fov: float=stage.camera.fov
	stage.set_meta("solar_transfer_projection",false)
	stage.set_meta("solar_satellite_selected_key","")
	stage.set_meta("solar_orbit_overview",false)
	stage.builder.set_solar_focus(stage,index)
	stage.camera.fov=previous_fov
	SatelliteFraming.clear(stage)
	stage.camera.fov=50.0
	var pose: Dictionary=stage.builder.solar_close_pose(stage,index,solar_jd,solar_true_distance,_solar_observation_frame())
	stage.camera.fov=previous_fov
	stage.camera.near=maxf(.001,float(stage.get_meta("solar_bodies")[index].node.mesh.radius)*.02)
	if index>=2: SatelliteFraming.detail(stage,index,"",Vector3(pose.position).distance_to(pose.target))
	var rebased: Dictionary=SolarCloseup.rebase(stage,former)
	if not rebased.is_empty(): _orbit_target=rebased.target
	_pan_offset=pose.offset
	_begin_solar_camera(pose.position,pose.target,_orbit_target,50.0)
	immersive_interface.refresh()
	message_label.text=I18n.text(I18n.text("正在观察 · ")+I18n.strings(Ephemeris.NAMES)[index]+" · "+spatial_hint({"planet":index}))


func frame_satellite_system(owner: int = -1, key: String = "", animate: bool = true) -> bool:
	if coordinator.is_busy(): return false
	var stage: Node=coordinator.active_scene
	var former: Dictionary=SolarCloseup.observer(stage,_orbit_target)
	if owner<0: owner=2 if stage.scale_id=="earth_moon" else int(stage.get_meta("natural_satellites",{}).get("index",-1))
	if stage.scale_id=="solar_system":
		if owner<2 or owner>7: return false
		var previous_fov: float=stage.camera.fov
		stage.builder.set_solar_focus(stage,owner)
		stage.camera.fov=previous_fov
		stage.set_meta("solar_satellite_selected_key","")
		# Make positions available before choosing a camera; this does not expose
		# any other host's satellite group in the local physical frame.
		stage.set_meta(SatelliteFraming.META,{"mode":"pair","owner":owner})
		stage.builder.set_solar_view(stage,solar_jd,solar_true_distance)
	var data: Dictionary=SatelliteFraming.subjects(stage,owner,key)
	if data.is_empty(): SatelliteFraming.clear(stage); return false
	var pole: Vector3=SatelliteFraming.normal(data,solar_jd)
	var pose: Dictionary=SatelliteFraming.solve(data,Vector2(stage.viewport.size),_solar_observation_frame(),pole)
	SatelliteFraming.configure(stage,data,pose,pole)
	stage.set_meta("satellite_framing_layout",{"frame":_solar_observation_frame(),"size":stage.viewport.size})
	stage.camera.near=pose.near
	_pan_offset=Vector3.ZERO; _direct_content.clear()
	if stage.scale_id=="solar_system":
		solar_follow=owner; solar_orbit_focus=-1; solar_plane_view=""; _content_follow=-1
		_begin_solar_close_playback(owner)
		stage.set_meta("solar_lookaround",false)
	else:
		_content_follow=-1
		if stage.has_meta("natural_satellites"): SatelliteBuilder.select(stage,-1)
	if animate:
		var rebased: Dictionary=SolarCloseup.rebase(stage,former)
		if not rebased.is_empty(): _orbit_target=rebased.target
		_begin_solar_camera(pose.position,pose.target,_orbit_target,float(pose.fov),pose.up)
	else:
		_solar_camera_motion.clear(); _orbit_target=pose.target; stage.camera.fov=pose.fov
		stage.set_pose(pose.position,pose.target,pose.up)
	immersive_interface.refresh()
	message_label.text=I18n.text("")
	return true


func _drag_satellite_frame(stage: Node, event: InputEventMouseMotion) -> void:
	var camera: Camera3D=stage.camera
	var forward: Vector3=_orbit_target-camera.position
	var turn: Basis=Basis(camera.basis.y,-event.relative.x*.003)*Basis(camera.basis.x,-event.relative.y*.003)
	if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT)!=0:
		stage.set_pose(camera.position,camera.position+turn*forward,turn*camera.basis.y)
	elif (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE)!=0 or event.shift_pressed:
		_pan_camera(stage,event.relative)
	else:
		stage.set_pose(_orbit_target-turn*forward,_orbit_target,turn*camera.basis.y)
	_orbit_target=stage.get_meta("camera_look_target")
	SatelliteFraming.remember(stage)


func _set_solar_context_gaze(stage: Node, position: Vector3, target: Vector3) -> void:
	_solar_camera_motion.clear()
	stage.set_meta("solar_lookaround",true)
	var reference: Vector3 = stage.get_meta("solar_physical").anchor
	var entries: Array[Dictionary] = content_targets(false)
	if _content_follow>=0 and _content_follow<entries.size(): reference=entries[_content_follow].node.position
	_pan_offset=target-reference
	_orbit_target=target
	stage.set_pose(position,target)


func look_solar_context(index: int) -> void:
	if world.current_scale_id!="solar_system" or coordinator.is_busy() or index not in [8,9]: return
	var stage: Node = coordinator.active_scene
	var data: Dictionary = stage.get_meta("solar_physical",{})
	if int(data.get("owner",-1))!=2: return
	SatelliteFraming.detail(stage,2,"",stage.camera.position.distance_to(_orbit_target))
	var earth: MeshInstance3D = stage.get_meta("solar_bodies")[2].node
	var eye: Vector3 = stage.camera.position
	var physical: Vector3 = data.physical_positions[index]
	var direction: Vector3 = (physical-eye).normalized()
	var distance: float = maxf(eye.distance_to(earth.position),float(earth.mesh.radius)*1.2)
	if SolarContextCompass.occluded(stage,index):
		# Move the observer to the body's side of Earth, never the body itself.
		eye=earth.position+direction*distance
		direction=(physical-eye).normalized()
	var previous_target: Vector3 = _orbit_target
	var target: Vector3 = eye+direction*distance
	stage.set_meta("solar_lookaround",true)
	_pan_offset=target-earth.position
	_begin_solar_camera(eye,target,previous_target)
	message_label.text=I18n.text(I18n.text("地球近景 · 正在望向")+(I18n.text("太阳") if index==8 else I18n.text("月球"))+I18n.text(" · 右键拖动环顾"))


func _solar_observation_frame() -> Rect2:
	var size: Vector2=get_viewport().get_visible_rect().size
	var top: float=(immersive_interface.header.get_global_rect().end.y+16.0)/size.y
	var bottom: float=(immersive_interface.context_panel.get_global_rect().position.y-24.0)/size.y if immersive_interface.context_panel.visible else .86
	var left: float=(explorer_panel.get_global_rect().end.x+16.0)/size.x if explorer_panel.visible else .02
	return Rect2(left,top,maxf(.15,.98-left),maxf(.15,bottom-top))


func _begin_solar_camera(position: Vector3, target: Vector3, previous_target: Vector3, fov: float = -1.0, up: Vector3 = Vector3.UP) -> void:
	var stage: Node=coordinator.active_scene
	_solar_zoom_return_stage=0
	_solar_camera_motion.clear()
	var lens: float=stage.camera.fov if fov<0.0 else fov
	if _reduced_motion or stage.camera.position.distance_to(position)<.000001:
		stage.camera.fov=lens
		stage.set_meta("solar_transfer_projection",false)
		stage.set_pose(position,target,up)
	else:
		_solar_camera_motion={"start":stage.camera.position-target,"look":previous_target-target,"finish":position-target,"elapsed":0.0,"duration":1.15,"stage":stage.get_instance_id(),"fov_start":stage.camera.fov,"fov_end":lens,"up_start":stage.camera.basis.y,"up_end":up}
		if bool(stage.get_meta("solar_transfer_projection",false)):
			_solar_camera_motion.duration=1.8
			_solar_camera_motion.rotation_start=stage.camera.basis.get_rotation_quaternion()
			_solar_camera_motion.rotation_end=Basis.looking_at(target-position,up).get_rotation_quaternion()
	_orbit_target=target


func _update_solar_camera(delta: float) -> void:
	if _solar_camera_motion.is_empty(): return
	var stage: Node=coordinator.active_scene
	if coordinator.is_busy() or stage.get_instance_id()!=int(_solar_camera_motion.stage):
		_solar_camera_motion.clear(); return
	_solar_camera_motion.elapsed=float(_solar_camera_motion.elapsed)+delta
	var progress: float=clampf(float(_solar_camera_motion.elapsed)/float(_solar_camera_motion.duration),0.0,1.0)
	var amount: float=smoothstep(0.0,1.0,progress)
	var start: Vector3=_solar_camera_motion.start
	var finish: Vector3=_solar_camera_motion.finish
	# Geometric dolly/lens interpolation keeps the subject readable during a
	# long-lens approach instead of collapsing it midway through a linear zoom.
	var direction: Vector3=start.normalized().slerp(finish.normalized(),amount)
	var distance: float=exp(lerpf(log(maxf(.000001,start.length())),log(maxf(.000001,finish.length())),amount))
	var position: Vector3=_orbit_target+direction*distance
	if stage.scale_id=="solar_system": position=stage.builder.solar_safe_camera(stage,position)
	if SatelliteFraming.is_pair(stage):
		var data: Dictionary=SatelliteFraming.subjects(stage,int(SatelliteFraming.state(stage).owner),str(SatelliteFraming.state(stage).key))
		if not data.is_empty(): stage.camera.near=SatelliteFraming.clip_near(data,position)
	var tangent: float=exp(lerpf(log(tan(deg_to_rad(float(_solar_camera_motion.fov_start)*.5))),log(tan(deg_to_rad(float(_solar_camera_motion.fov_end)*.5))),amount))
	stage.camera.fov=rad_to_deg(2.0*atan(tangent))
	if _solar_camera_motion.has("rotation_start"):
		var orientation: Basis=Basis(Quaternion(_solar_camera_motion.rotation_start).slerp(_solar_camera_motion.rotation_end,amount))
		stage.set_pose(position,position-orientation.z*maxf(.01,position.distance_to(_orbit_target)),orientation.y)
	else: stage.set_pose(position,_orbit_target+Vector3(_solar_camera_motion.look)*(1.0-amount),Vector3(_solar_camera_motion.up_start).slerp(_solar_camera_motion.up_end,amount).normalized())
	if progress>=1.0:
		_solar_camera_motion.clear()
		stage.set_meta("solar_transfer_projection",false)

func focus_planet_orbit(index: int) -> void:
	if world.current_scale_id!="solar_system" or coordinator.is_busy() or index<0 or index>=8: return
	_end_solar_close_playback()
	_solar_camera_motion.clear()
	_pan_offset=Vector3.ZERO
	if learning_overlay.topic=="mercury_orbit": explorer_panel.clear_topic()
	solar_follow=-1
	solar_orbit_focus=index
	solar_plane_view=""
	_content_follow=-1
	_orbit_target=Vector3.ZERO
	var stage: Node=coordinator.active_scene
	SatelliteFraming.clear(stage)
	stage.set_meta("solar_orbit_overview",true)
	stage.builder.set_solar_focus(stage,index)
	stage.builder.set_solar_view(stage,solar_jd,solar_true_distance)
	var el: Array[float]=Ephemeris.elements(index,solar_jd)
	var peri: Vector3=Ephemeris.display_vector(index,Ephemeris.orbital_point(el,0.0),solar_true_distance).normalized()
	var quarter: Vector3=Ephemeris.display_vector(index,Ephemeris.orbital_point(el,PI*.5),solar_true_distance)
	var normal: Vector3=peri.cross(quarter).normalized()
	var semimajor: float=Ephemeris.display_vector(index,Vector3(el[0],0,0),solar_true_distance).length()
	stage.set_pose(normal*(semimajor*(1.0+el[1])*_solar_orbit_frame_scale(stage)),Vector3.ZERO,normal.cross(peri).normalized())

func focus_solar_plane(side: bool) -> void:
	if world.current_scale_id!="solar_system" or coordinator.is_busy(): return
	_end_solar_close_playback()
	_solar_camera_motion.clear()
	_pan_offset=Vector3.ZERO
	if learning_overlay.topic=="mercury_orbit": explorer_panel.clear_topic()
	var selected: int=solar_follow if solar_follow>=0 else solar_orbit_focus
	solar_follow=-1
	solar_orbit_focus=selected
	solar_plane_view="side" if side else "top"
	_content_follow=-1
	_orbit_target=Vector3.ZERO
	var stage: Node=coordinator.active_scene
	SatelliteFraming.clear(stage)
	stage.set_meta("solar_orbit_overview",selected>=0)
	stage.builder.set_solar_focus(stage,selected)
	stage.builder.set_solar_view(stage,solar_jd,solar_true_distance)
	var radius: float=0.0
	for index: int in range(8):
		if selected>=0 and index!=selected: continue
		var el: Array[float]=Ephemeris.elements(index,solar_jd)
		radius=maxf(radius,Ephemeris.display_vector(index,Vector3(el[0]*(1.0+el[1]),0,0),solar_true_distance).length())
	# UP is the common J2000 ecliptic normal after (x,y,z)->(x,z,-y).
	# The fixed side direction is its x axis, never a selected orbit's node.
	stage.set_pose((Vector3.RIGHT if side else Vector3.UP)*(radius*_solar_orbit_frame_scale(stage)),Vector3.ZERO,Vector3.UP if side else Vector3.FORWARD)

func _solar_orbit_frame_scale(stage: Node) -> float:
	# Reserve the panel and top/bottom HUD in orbit view. Scale the same
	# face-on camera when the drawable area is narrower than the default view.
	var view_size: Vector2=stage.camera.get_viewport().get_visible_rect().size
	var panel_edge: float=explorer_panel.get_global_rect().end.x+16.0 if explorer_panel.visible else 0.0
	var safe_width: float=maxf(1.0,view_size.x-panel_edge-22.0)
	var safe_height: float=maxf(1.0,view_size.y-112.0-104.0)
	# Perspective projection already shrinks with viewport height; only add
	# distance if the remaining screen area shrinks faster than that.
	var horizontal_fit: float=470.0*(view_size.y/650.0)/safe_width
	var vertical_fit: float=550.0*(view_size.y/800.0)/safe_height
	return 4.0*maxf(1.0,maxf(horizontal_fit,vertical_fit))

func content_targets(use_direct: bool = true) -> Array[Dictionary]:
	return I18n.present_dictionaries(_content_targets_source(use_direct))


func _content_targets_source(use_direct: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stage: Node = coordinator.active_scene
	if stage.scale_id=="night_sky":
		result.assign(GroundSky.targets(stage))
	elif stage.scale_id == "universe":
		result.append({"node":stage.world_root.get_node("MilkyWaySemanticAnchor"),"label":I18n.text("银河系 · 进入我们的恒星家园"),"distance":4.0,"min_distance":1.1,"entry_distance":2.7,"destination":"galaxy","primary":true})
	elif stage.scale_id == "galaxy":
		result.append({"node":stage.world_root.find_child("SolarSystemSemanticAnchor", true, false), "label":I18n.text("太阳系 · 银河中的教学锚点"), "distance":1.6, "min_distance":.35, "entry_distance":1.05, "destination":"solar_system", "primary":true})
	elif stage.scale_id == "solar_system":
		result.append({"node":stage.world_root.get_node("Sun_AuthoredPhotosphere"),"label":I18n.text("太阳"),"sun":true,"pick_nodes":[stage.get_meta("solar_physical").points[8]],"distance":5.8,"min_distance":2.2,"primary":false})
		var moon: Dictionary = stage.get_meta("solar_moon")
		var factor: float = absf(moon.node.scale.x)
		result.append({"node":moon.node,"label":I18n.text("月球"),"moon":true,"pick_nodes":[stage.get_meta("solar_physical").points[9]],"distance":.55*factor,"min_distance":.15*factor,"entry_distance":.18*factor,"destination":"earth_moon","primary":false})
		result.append_array(SolarSatellites.targets(stage))
	elif stage.scale_id == "atmosphere":
		result.append({"node":stage.world_root.find_child("LizardTangentPatch", true, false), "label":I18n.text("蜥蜴岛海面 · 接近海洋"), "focus_position":stage.target_position, "distance":100.0, "entry_distance":42.0, "destination":"pacific", "primary":true})
	elif stage.scale_id == "heart":
		for region: Dictionary in stage.builder.get_regions(stage):
			result.append({"node":region.external_node, "cutaway_node":region.cutaway_node, "label":region.label, "region":region.id, "focus_position":region.position, "distance":maxf(.5, float(region.radius) * 3.0), "min_distance":.22, "entry_distance":.30, "destination":"cardiomyocyte" if region.id == "ventricle" else "", "primary":region.id == "ventricle", "role":region.description})
	elif stage.scale_id == "cardiomyocyte":
		result.append({"node":stage.world_root.find_child("SelectedMitochondrion", true, false), "label":I18n.text("所选线粒体 · 科学示意"), "distance":2.0, "min_distance":.42, "entry_distance":1.15, "destination":"mitochondrion", "primary":true})
	elif stage.scale_id in ["mitochondrion", "molecule"]:
		result.append({"node":stage.world_root.find_child("SelectedO2EntrySymbolNotPhysicalScale" if stage.scale_id == "mitochondrion" else "O2AtomicCenterSymbols", true, false), "label":I18n.text("O₂结构符号") if stage.scale_id == "mitochondrion" else I18n.text("氧原子中心 · 进入密度教学视图"), "focus_position":stage.target_position, "distance":1.4 if stage.scale_id == "mitochondrion" else 2.2, "min_distance":.42, "entry_distance":.85 if stage.scale_id == "mitochondrion" else 1.0, "destination":"molecule" if stage.scale_id == "mitochondrion" else "atom", "primary":true})
	elif stage.has_meta("lunar"):
		var lunar: Dictionary = stage.get_meta("lunar")
		result.append({"node":lunar.earth,"label":I18n.text("地球 · 昼夜分界与自转轴"),"distance":3.6,"destination":"earth","primary":true})
		result.append({"node":lunar.moon,"label":I18n.text("月球 · 同步自转与受光面"),"distance":1.1,"min_distance":.62})
	elif stage.has_meta("natural_satellites"):
		result.assign(SatelliteBuilder.targets(stage))
	elif stage.has_meta("jovian"):
		result.assign(stage.builder.targets(stage))
	elif stage.has_meta("marine_actors"):
		var actors: Array = stage.get_meta("marine_actors")
		for kind: int in range(5):
			for actor: Dictionary in actors:
				if actor.kind==kind:
					result.append({"node":actor.node,"label":actor.label,"role":actor.role,"source_url":actor.source_url,"distance":0.85 if kind<3 else 1.9})
					break
		for item: Dictionary in stage.get_meta("benthic_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("coral_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("seagrass_targets",[]): result.append(item)
		if stage.has_meta("target_node"):
			result.append({"node":stage.get_meta("target_node"),"label":I18n.text("目标海葵双锯鱼 · Amphiprion percula"),"distance":.42,"primary":true,"role":I18n.text("局部宿主附近的目标个体；双击继续深入既有观察路径。")})
		for item: Dictionary in stage.get_meta("clam_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("holothuria_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("octopus_targets",[]): result.append(item)
	elif stage.has_meta("desert_targets"):
		result.assign(stage.get_meta("desert_targets"))
	elif stage.has_meta("polar_targets"):
		result.assign(stage.get_meta("polar_targets"))
	elif stage.has_meta("actors"):
		var seen: Array[String] = []
		for actor: Dictionary in stage.get_meta("actors"):
			if str(actor.kind) in seen: continue
			seen.append(actor.kind)
			result.append({"node":actor.node,"label":actor.label,"role":actor.get("role",""),"source_url":"https://www.nps.gov/bith/learn/nature/white-tailed-deer.htm" if actor.kind=="deer" else actor.get("source_url",""),"distance":.75 if actor.kind=="bird" else 9.0 if actor.kind=="car" else 3.6 if actor.kind=="person" else 4.0,"focus_height":.10 if actor.kind=="bird" else .95})
			if actor.kind=="person": result[-1]["view_offset"] = Vector3(1.5,2.4,4.0)
			if actor.kind=="deer": result[-1]["view_offset"] = Vector3(-3.2,1.3,-2.4)
		for item: Dictionary in stage.get_meta("urban_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("plant_targets",[]): result.append(item)
		if stage.scale_id!="city":
			for item: Dictionary in stage.get_meta("pollinator_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("browse_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("runoff_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("city_sparrow_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("city_ginkgo_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("city_park_tree_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("frog_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("fungus_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("deadwood_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("larva_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("river_wetland_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("freshwater_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("wild_celery_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("banded_killifish_targets",[]): result.append(item)
		for item: Dictionary in stage.get_meta("red_fox_targets",[]): result.append(item)
		if stage.scale_id=="city":
			for item: Dictionary in stage.get_meta("pollinator_targets",[]): result.append(item)
			for item: Dictionary in stage.get_meta("city_pond_targets",[]): result.append(item)
			for item: Dictionary in stage.get_meta("street_walker_targets",[]): result.append(item)
	for item: Dictionary in stage.get_meta("monarch_stage_targets",[]): result.append(item)
	for item: Dictionary in stage.get_meta("box_turtle_targets",[]): result.append(item)
	if use_direct and not _direct_content.is_empty() and _content_follow>=0 and _content_follow<result.size() and is_instance_valid(_direct_content.get("node")) and stage.world_root.is_ancestor_of(_direct_content.node):
		result[_content_follow]=_direct_content
	return result

func follow_content(index: int, direct: Dictionary = {}) -> void:
	if coordinator.is_busy(): return
	var former: Dictionary=SolarCloseup.observer(coordinator.active_scene,_orbit_target)
	var previous_target: Vector3=_orbit_target
	var detail_fov: float=coordinator.active_scene.camera.fov
	var detail_lens: float=50.0 if world.current_scale_id=="solar_system" else 48.0
	_solar_camera_motion.clear()
	coordinator.active_scene.set_meta("solar_transfer_projection",false)
	if world.current_scale_id=="solar_system":
		solar_follow=-1; solar_orbit_focus=-1; solar_plane_view=""
		coordinator.active_scene.set_meta("solar_orbit_overview",false)
		coordinator.active_scene.builder.set_solar_focus(coordinator.active_scene,-1)
		coordinator.active_scene.set_meta("solar_satellite_selected_key",str(direct.get("satellite_key","")))
	if Satellites.is_system(world.current_scale_id) and not Satellites.available(solar_jd):
		message_label.text=I18n.text(I18n.text("当前日期超出1995—2050卫星位置范围"))
		return
	_pan_offset=Vector3.ZERO
	_city_people_view=false
	_city_street_view=false
	_refresh_city_view_button()
	_content_follow = index-1
	_direct_content=direct.duplicate()
	var targets: Array[Dictionary] = content_targets()
	if _content_follow<0 or _content_follow>=targets.size():
		_reset_camera()
		return
	var item: Dictionary = targets[_content_follow]
	if world.current_scale_id=="solar_system":
		coordinator.active_scene.set_meta("solar_satellite_selected_key",str(item.get("satellite_key","")))
		if item.has("host_planet"): coordinator.active_scene.builder.set_solar_focus(coordinator.active_scene,int(item.host_planet))
		elif bool(item.get("sun",false)) or bool(item.get("moon",false)):
			coordinator.active_scene.set_meta("solar_subject_frame",8 if bool(item.get("sun",false)) else 2)
			coordinator.active_scene.builder.set_solar_view(coordinator.active_scene,solar_jd,solar_true_distance)
		item=content_targets(false)[_content_follow]
		_direct_content=item.duplicate()
	var framing_owner: int=-1
	var framing_key: String=""
	var framing_stage: Node=coordinator.active_scene
	if world.current_scale_id=="earth_moon": framing_owner=2
	elif framing_stage.has_meta("natural_satellites"): framing_owner=int(framing_stage.get_meta("natural_satellites").index)
	elif item.has("host_planet"): framing_owner=int(item.host_planet)
	elif bool(item.get("moon",false)): framing_owner=2
	if framing_owner>=2:
		framing_key=str(item.get("satellite_key",""))
		SatelliteFraming.detail(framing_stage,framing_owner,framing_key,float(item.distance))
		framing_stage.camera.fov=detail_fov
		if item.node.mesh is SphereMesh: framing_stage.camera.near=maxf(.001,float(item.node.mesh.radius)*absf(item.node.scale.x)*.025)
		if item.has("satellite_key") and item.node.mesh is SphereMesh:
			detail_lens=clampf(rad_to_deg(2.0*atan(2.3*float(item.node.mesh.radius)*absf(item.node.scale.x)/float(item.distance))),.05,50.0)
	elif world.current_scale_id=="solar_system":
		SatelliteFraming.clear(framing_stage); framing_stage.camera.fov=detail_fov; framing_stage.camera.near=.01
	if coordinator.active_scene.has_meta("natural_satellites"): SatelliteBuilder.select(coordinator.active_scene,_content_follow)
	if world.current_scale_id=="solar_system":
		if bool(item.get("sun",false)) or bool(item.get("moon",false)) or item.has("satellite_key"): _begin_solar_close_playback(_content_follow+8)
		else: _end_solar_close_playback()
	if world.current_scale_id=="night_sky":
		GroundSky.focus(coordinator.active_scene,_content_follow)
		_orbit_target=item.node.global_position
		message_label.text=I18n.text(I18n.text("正在观察 · ")+str(item.label)+" · "+spatial_hint(item))
		return
	_orbit_target = item.get("focus_position", item.node.position+Vector3(0,float(item.get("focus_height",0.0)),0))
	var direction: Vector3 = Vector3(0.35,0.28,1).normalized()
	if world.current_scale_id=="earth_moon":
		direction = Orientation.sun_direction(solar_jd).rotated(Vector3.UP,0.7) if _content_follow==0 else -item.node.position.normalized()
	elif world.current_scale_id=="solar_system" and bool(item.get("moon",false)):
		direction = (Orientation.sun_direction(solar_jd).rotated(Vector3.UP,.4)+Vector3.UP*.2).normalized()
	var offset: Vector3 = item.get("view_offset",direction*float(item.distance))
	if item.has("view_offset_local"):
		# Resolve on selection so cached pointer entries use the current heading.
		# Orthonormalization keeps authored camera distance independent of stature.
		offset = item.node.basis.orthonormalized()*Vector3(item.view_offset_local)
	if bool(item.get("view_from_subject_side",false)):
		offset=item.node.global_basis.z*float(item.distance)*float(item.get("view_side_sign",1.0))+Vector3(0,.05,0)
	if world.current_scale_id=="solar_system":
		var arrival: Vector3=coordinator.active_scene.builder.solar_safe_camera(coordinator.active_scene,_orbit_target+offset)
		var rebased: Dictionary=SolarCloseup.rebase(coordinator.active_scene,former)
		if not rebased.is_empty(): previous_target=rebased.target
		_begin_solar_camera(arrival,_orbit_target,previous_target,detail_lens)
	elif framing_owner>=2: _begin_solar_camera(_orbit_target+offset,_orbit_target,previous_target,detail_lens)
	else: coordinator.active_scene.set_pose(_orbit_target+offset,_orbit_target)
	message_label.text = I18n.text(I18n.text("正在观察 · ")+str(item.label)+" · "+spatial_hint(item))

func perform_spatial_action(action: String) -> void:
	if coordinator.is_busy() or not world.foreground or world_guide.visible or size_comparison.visible: return
	match action:
		"runoff_rain":
			if world.current_scale_id!="city" or learning_overlay.topic!="runoff": return
			world.set_runoff_rain(not world.runoff.raining)
			message_label.text=I18n.text(I18n.text("局部实验降雨已")+(I18n.text("开启 · 继续时间观察雨水去向") if world.runoff.raining else I18n.text("关闭 · 原有水量继续排出")))
		"browse_protection":
			if world.current_scale_id!="woodland" or learning_overlay.topic!="browse": return
			world.set_browse_protected(not world.browse.protected_left)
			message_label.text=I18n.text(I18n.text("左侧样方已")+(I18n.text("保护 · 继续时间比较恢复") if world.browse.protected_left else I18n.text("开放 · 继续时间比较取食")))
		"deadwood_condition":
			if world.current_scale_id!="woodland" or learning_overlay.topic!="deadwood": return
			world.set_deadwood_mode((world.deadwood.left_mode+1)%world.Deadwood.MODES.size())
			message_label.text=I18n.text(I18n.text("左侧枯木：")+world.Deadwood.LABELS[world.deadwood.left_mode]+I18n.text(" · 右侧持续干燥，继续时间观察碳去向"))
		"coral_heat":
			if world.current_scale_id not in ["pacific","reef","school","fish"] or learning_overlay.topic!="coral_symbiosis": return
			world.set_coral_heat(not world.symbiosis.heated)
			message_label.text=I18n.text(I18n.text("热压力教学已")+(I18n.text("开启 · 继续时间观察共生颜色") if world.symbiosis.heated else I18n.text("解除 · 此教学例假定仍可恢复")))
		_: return
	soundscape.cue("select")

func focus_earth_reference(id: String) -> void:
	if coordinator.is_busy() or world.current_scale_id!="earth" or ExplorerPanel.Sites.for_scale(id).is_empty(): return
	_pan_offset=Vector3.ZERO
	_earth_reference = id
	_content_follow = -1
	_orbit_target = Vector3.ZERO
	var stage: Node = coordinator.active_scene
	stage.builder.EarthLocator.focus(stage,id)

func _update_exploration() -> void:
	# Only actual common World advancement contributes to rendering exposure.
	# Date buttons/jumps and pause never manufacture a separately rotating body.
	var render_seconds: float = maxf(0.0,world.simulation_time_s-_solar_render_world_time) if _solar_render_world_time>=0.0 else 0.0
	_solar_render_world_time=world.simulation_time_s
	var exposure_days: float = absf(solar_rate)*render_seconds
	var raw_jd: float = _solar_origin_jd+(world.simulation_time_s-_solar_origin_time)*solar_rate
	if Satellites.is_system(world.current_scale_id) and not Satellites.available(_solar_origin_jd):
		_solar_origin_jd=raw_jd
		_solar_origin_time=world.simulation_time_s
		solar_rate=0.0
	if Satellites.is_system(world.current_scale_id) and Satellites.available(_solar_origin_jd) and not Satellites.available(raw_jd):
		_solar_origin_jd=clampf(raw_jd,Satellites.START_JD,Satellites.END_JD)
		_solar_origin_time=world.simulation_time_s
		solar_rate=0.0
		raw_jd=_solar_origin_jd
		message_label.text=I18n.text(I18n.text("已到卫星位置日期边界，天文推演暂停"))
	solar_jd = clampf(raw_jd,Ephemeris.START_JD,Ephemeris.END_JD)
	if raw_jd>Ephemeris.END_JD or raw_jd<Ephemeris.START_JD:
		set_solar_rate(0.0)
		if world.current_scale_id=="solar_system": message_label.text = I18n.text(I18n.text("已到行星位置有效日期边界，天文推演暂停"))
	for stage: Node in scene_host.get_children():
		if stage.get("scale_id")=="galaxy":
			stage.builder.Galactic.update(stage,world.current_scale_id=="galaxy" and learning_overlay.topic=="galactic_structure" and learning_overlay.enabled)
		if stage.get("scale_id")=="solar_system" and stage.has_meta("solar_bodies"):
			stage.set_meta("solar_frame_suppressed",world.current_scale_id=="solar_system" and learning_overlay.topic=="mercury_orbit")
			_sync_solar_physical_context(stage)
			stage.builder.set_solar_view(stage,solar_jd,solar_true_distance,exposure_days)
			stage.builder.EarthSeasonOrbit.set_symbols(stage,learning_overlay.enabled)
			Kepler.update(stage,solar_jd,solar_true_distance,world.current_scale_id=="solar_system" and learning_overlay.topic=="mercury_orbit",learning_overlay.enabled)
			stage.builder.set_solar_moon_focus(stage,world.current_scale_id=="solar_system" and _content_follow==1)
		elif stage.get("scale_id")=="jupiter_moons":
			stage.builder.set_view(stage,solar_jd,solar_true_distance)
		elif stage.has_meta("natural_satellites") and (stage==coordinator.active_scene or stage==_incoming or stage==_outgoing):
			SatelliteBuilder.set_view(stage,solar_jd,solar_true_distance)
		elif stage.get("scale_id")=="earth_moon" and stage.has_meta("lunar"):
			stage.builder.set_lunar_view(stage,solar_jd,solar_true_distance,exposure_days)
		elif stage.get("scale_id")=="earth":
			stage.set_meta("spatial_entry_active", (world.current_scale_id=="earth" and learning_overlay.topic!="earth_daylight") or not _earth_flight.is_empty())
			stage.builder.EarthDaylight.set_active(stage,world.current_scale_id=="earth" and learning_overlay.topic=="earth_daylight")
			stage.builder.EarthDaylight.set_symbols(stage,learning_overlay.enabled)
			stage.builder.set_earth_daylight(stage,solar_jd)
			if stage.has_meta("earth_locator"):
				stage.get_meta("earth_locator").selection = _earth_reference
				stage.builder.EarthLocator.update(stage)
		elif stage.get("scale_id") in ["woodland","city","desert","polar","arctic"]:
			stage.builder.set_daylight(stage,solar_jd,ground_light_preview)
		elif stage.get("scale_id")=="night_sky":
			GroundSky.update(stage,solar_jd)
	_sync_solar_context_playback()
	if coordinator.is_busy(): return
	var stage: Node = coordinator.active_scene
	if world.current_scale_id=="night_sky":
		var targets: Array[Dictionary]=content_targets()
		if _content_follow>=0 and _content_follow<targets.size():
			_orbit_target=targets[_content_follow].node.global_position
			stage.set_pose(GroundSky.EYE,_orbit_target)
		return
	if SatelliteFraming.is_pair(stage):
		var layout: Dictionary={"frame":_solar_observation_frame(),"size":stage.viewport.size}
		if layout!=stage.get_meta("satellite_framing_layout",{}):
			var value: Dictionary=SatelliteFraming.state(stage)
			var data: Dictionary=SatelliteFraming.subjects(stage,int(value.owner),str(value.key))
			if not data.is_empty():
				var reframed: Dictionary=SatelliteFraming.solve(data,Vector2(stage.viewport.size),layout.frame,value.normal)
				SatelliteFraming.configure(stage,data,reframed,value.normal)
			stage.set_meta("satellite_framing_layout",layout)
		var pair: Dictionary=SatelliteFraming.tracked_pose(stage)
		if not pair.is_empty():
			_orbit_target=pair.target; _pan_offset=Vector3.ZERO; stage.camera.h_offset=0.0
			if stage.has_meta("lunar"): stage.get_meta("lunar").orbit.hide()
			if _solar_camera_motion.is_empty():
				stage.camera.fov=pair.fov; stage.camera.near=pair.near; stage.set_pose(pair.position,pair.target,pair.up)
			else:
				_solar_camera_motion.finish=Vector3(pair.position)-_orbit_target
				_solar_camera_motion.up_end=pair.up
				_solar_camera_motion.fov_end=pair.fov
			return
	var target: Vector3 = _orbit_target
	var tracking: bool = false
	if world.current_scale_id=="galaxy" and learning_overlay.topic=="galactic_structure":
		target=Vector3.ZERO
		tracking=true
	elif world.current_scale_id=="earth" and learning_overlay.topic=="earth_daylight":
		target=Vector3.ZERO
		tracking=true
	elif world.current_scale_id=="solar_system" and solar_follow>=0:
		target = Ephemeris.display_position(solar_follow,solar_jd,solar_true_distance)
		tracking = true
	elif world.current_scale_id=="solar_system" and _content_follow<0 and int(stage.get_meta("solar_natural_frame",-1))>=0:
		target=Ephemeris.display_position(int(stage.get_meta("solar_natural_frame")),solar_jd,solar_true_distance)
		tracking=true
	elif world.current_scale_id=="solar_system" and (solar_orbit_focus>=0 or not solar_plane_view.is_empty()):
		target = Vector3.ZERO
		tracking = true
	elif world.current_scale_id=="solar_system" and learning_overlay.topic=="mercury_orbit":
		target = Vector3.ZERO
		tracking = true
	elif world.current_scale_id=="earth_moon" and learning_overlay.topic=="lunar_phases" and lunar_observation_view=="orbit":
		target=Vector3.ZERO
		tracking=true
	elif Satellites.is_system(world.current_scale_id) and _content_follow<0:
		target=stage.default_target
		tracking=true
	elif world.current_scale_id=="city" and learning_overlay.topic=="city_sparrow" and explorer_panel.city_bird_context_view:
		target=ExplorerPanel.CITY_BIRD_CONTEXT_TARGET
		tracking=true
	elif _content_follow>=0:
		var targets: Array[Dictionary] = content_targets()
		if _content_follow<targets.size():
			target = targets[_content_follow].get("focus_position", targets[_content_follow].node.position+Vector3(0,float(targets[_content_follow].get("focus_height",0.0)),0))
			if world.current_scale_id=="solar_system": target=SolarCloseup.physical_position(stage,targets[_content_follow])
			if learning_overlay.topic=="school" and _content_follow==2:
				target=world.schooling.metrics().center
			if learning_overlay.topic=="snapper" and _content_follow==1 and stage.has_meta("snapper_group_center"):
				target = target.lerp(stage.get_meta("snapper_group_center"),.5)
			if learning_overlay.topic in ["monarch","city_monarch"] and stage.has_meta("pollinators"):
				target = stage.builder.Pollinators.tracking_target(stage)
			if learning_overlay.topic=="algae" and stage.has_meta("feeding_patches"):
				var patch_center: Vector3=Vector3.ZERO
				for point: Vector3 in stage.get_meta("feeding_patches"): patch_center+=point/6.
				target=patch_center.lerp(target,.25)
			tracking = true
	if tracking:
		var offset: Vector3 = stage.camera.position-_orbit_target
		target+=_pan_offset
		_orbit_target = target
		if world.current_scale_id=="earth_moon" and learning_overlay.topic=="lunar_phases" and lunar_observation_view=="earth":
			var basis: Basis = Orientation.moon_basis(solar_jd)
			stage.set_pose(target-(target-_pan_offset).normalized()*offset.length(),target,basis.y)
		else: stage.set_pose(target+offset,target,stage.camera.basis.y if is_instance_valid(SolarCloseup.subject(self)) or learning_overlay.topic=="mercury_orbit" or (world.current_scale_id=="solar_system" and not solar_plane_view.is_empty()) else Vector3.UP)
	# Keep the selected subject beside the explanation. This transient camera
	# offset leaves world geometry, orbit controls and saved camera poses intact.
	# Always reset it when selection/panel visibility changes, including cached stages.
	var visible_left: float = guided_journey.get_global_rect().end.x+16.0 if guided_journey.visible else explorer_panel.get_global_rect().end.x+16.0 if explorer_panel.visible and (tracking or world.current_scale_id=="atom") else 0.0
	var height: float = maxf(1.0,get_viewport().get_visible_rect().size.y)
	var distance: float = stage.camera.position.distance_to(_orbit_target)
	stage.camera.h_offset = -(stage.camera.size*.5 if stage.camera.projection==Camera3D.PROJECTION_ORTHOGONAL else distance*tan(deg_to_rad(stage.camera.fov*.5)))*visible_left/height

func open_size_comparison() -> void:
	if coordinator.is_busy() or world.current_scale_id!="solar_system": return
	size_comparison.open()


func select_atom_view(mode: int, section: bool=false) -> void:
	if coordinator.is_busy() or world.current_scale_id!="atom" or mode<0 or mode>=I18n.strings(Oxygen.LABELS).size(): return
	_pan_offset=Vector3.ZERO
	var stage: Node=coordinator.active_scene
	stage.builder.set_atom_view(stage,mode,section)
	_orbit_target=Vector3.ZERO
	_content_follow=-1
	var width: float=get_viewport().get_visible_rect().size.x
	var left: float=explorer_panel.get_global_rect().end.x+16. if explorer_panel.visible else 0.
	var factor: float=clampf(width/maxf(240.,width-left),1.,2.)
	var pose: Vector3=Vector3(.6,.35,1.9) if mode==4 else stage.default_position
	if section and mode!=4: pose=Vector3(0,0,7.2)
	stage.set_pose(pose*factor,Vector3.ZERO)
	message_label.text=I18n.text(I18n.text("原子核已单独放大 · 不与电子云同比例") if mode==4 else I18n.text("轨道形状参考 · 不改变原子或世界状态"))


func _language_changed(_locale: String) -> void:
	get_window().title = I18n.text("孪生宇宙")
	_rebuild_localized_hud.call_deferred()


func _rebuild_localized_hud() -> void:
	if not is_instance_valid(hud): return
	var panels: Dictionary = {}
	for key: String in ["info_panel", "explorer_panel", "sound_panel", "observation_panel", "world_guide", "guided_journey", "size_comparison"]:
		panels[key] = get(key).visible
	var topic_id: String = str(explorer_panel._topic.get("id", ""))
	var section_flags: Array[bool] = [explorer_panel._astro_open, explorer_panel._observation_open, explorer_panel._science_open]
	var explorer_scroll: int = explorer_panel.scroll.scroll_vertical
	var guide_first_visit: bool = world_guide.first_visit_view
	var guide_query: String = world_guide.search.text
	var atlas: Node = world_guide.species_atlas
	var atlas_filter: Dictionary = {"query":atlas.search.text,"area":atlas.area_ids[atlas.area_filter.selected],"kind":atlas.kind_ids[atlas.kind_filter.selected]}
	var ecology_filter: Dictionary = {"branch":world_guide.ecology_map.branch,"selected":world_guide.ecology_map.selected}
	var size_body: int = size_comparison.selected
	var journey_transient: Dictionary = {}
	for key: String in ["pending","_lesson_visit","_framing_factor","_last_width"]: journey_transient[key] = guided_journey.get(key)
	var subpanels: Dictionary = {"solar_comparison":explorer_panel.solar_comparison.visible,"earth_season_controls":explorer_panel.earth_season_controls.visible}
	var guide_page: String = "species" if world_guide.species_atlas.visible else "ecology" if world_guide.ecology_map.visible else "topics"
	var guide_scroll: int = world_guide.scroll.scroll_vertical
	var region: String = earth_entry_panel.selected
	var clean: bool = clean_observation.active
	var marker_topic: String = learning_overlay.topic
	var marker_branch: String = learning_overlay.branch
	var markers_enabled: bool = learning_overlay.enabled
	var origin: Dictionary = navigation_bar.origin.duplicate(true)
	_journey_restore = guided_journey.checkpoint()
	var rate: float = solar_rate
	var old_layer: CanvasLayer = hud.get_parent() as CanvasLayer
	remove_child(old_layer)
	old_layer.free()
	_build_hud()
	earth_entry_panel.selected = region
	navigation_bar.origin = origin
	for key: String in journey_transient: guided_journey.set(key,journey_transient[key])
	size_comparison.select_body(size_body)
	learning_overlay.topic = marker_topic
	learning_overlay.branch = marker_branch
	learning_overlay.enabled = markers_enabled
	for key: String in panels: get(key).visible = panels[key]
	# Refresh text without invoking lesson actions or clearing camera/reference state.
	explorer_panel.restore_localized_topic(topic_id)
	explorer_panel._astro_open = section_flags[0]
	explorer_panel._observation_open = section_flags[1]
	explorer_panel._science_open = section_flags[2]
	explorer_panel._present_sections()
	for key: String in subpanels: explorer_panel.get(key).visible = subpanels[key]
	explorer_panel.scroll.set_deferred("scroll_vertical", explorer_scroll)
	world_guide.refresh_context(guide_first_visit)
	world_guide.search.text = guide_query
	atlas = world_guide.species_atlas
	atlas.area_filter.select(maxi(0,atlas.area_ids.find(atlas_filter.area)))
	atlas.kind_filter.select(maxi(0,atlas.kind_ids.find(atlas_filter.kind)))
	atlas.search.text = str(atlas_filter.query)
	atlas._apply_filters()
	world_guide.ecology_map.set_branch(str(ecology_filter.branch))
	world_guide.ecology_map.select_relation(int(ecology_filter.selected))
	world_guide._show_page(guide_page)
	world_guide.scroll.set_deferred("scroll_vertical", guide_scroll)
	learning_overlay.topic = marker_topic
	learning_overlay.branch = marker_branch
	learning_overlay.enabled = markers_enabled
	_update_ui()
	solar_rate = rate
	clean_observation.set_active(clean)
	_resize()
