extends Node
## Export-safe routing: official Release templates can disable --script/--scene.
## Only our user-side --suite argument selects the embedded integration runner.

const Experience: PackedScene = preload("res://scenes/experience.tscn")
const Suite: Script = preload("res://tests/integration/experience_suite.gd")
const WorldResumeSuite: Script = preload("res://tests/integration/world_resume_suite.gd")
const ContinuitySuite: Script = preload("res://tests/integration/continuity_suite.gd")
const OxygenSuite: Script = preload("res://tests/integration/oxygen_suite.gd")
const ObjectPointerSuite = preload("res://tests/integration/object_pointer_suite.gd")
const SpatialExperimentsSuite = preload("res://tests/integration/spatial_experiments_suite.gd")
const SelectedEntrySuite = preload("res://tests/integration/selected_entry_suite.gd")
const SpatialEcologySuite = preload("res://tests/integration/spatial_ecology_suite.gd")
const AtmosphereEntrySuite = preload("res://tests/integration/atmosphere_entry_suite.gd")
const EarthLandmarkVisualSuite = preload("res://tests/integration/earth_landmark_visual_suite.gd")
const ImmersiveUISuite = preload("res://tests/integration/immersive_ui_suite.gd")
const CosmosMotionSuite = preload("res://tests/integration/cosmos_motion_suite.gd")
const SolarObservationSuite = preload("res://tests/integration/solar_observation_suite.gd")
const SolarMotionMoonSuite = preload("res://tests/integration/solar_motion_moon_suite.gd")
const GroundSkySuite = preload("res://tests/integration/ground_sky_suite.gd")
const SolarSpacingSuite = preload("res://tests/integration/solar_spacing_suite.gd")
const SolarVisualSuite = preload("res://tests/integration/solar_visual_suite.gd")
const SolarObservationTimeSuite = preload("res://tests/integration/solar_observation_time_suite.gd")
const SatelliteCoverageSuite = preload("res://tests/integration/satellite_coverage_suite.gd")
const SatelliteExplorationSuite = preload("res://tests/integration/satellite_exploration_suite.gd")
const SolarDragVisibilitySuite = preload("res://tests/integration/solar_drag_visibility_suite.gd")
const SatelliteScaleSuite = preload("res://tests/integration/satellite_scale_suite.gd")
const SolarScaleSuite = preload("res://tests/integration/solar_scale_suite.gd")
const SolarCloseupSuite = preload("res://tests/integration/solar_closeup_suite.gd")
const SolarZoomReturnSuite = preload("res://tests/integration/solar_zoom_return_suite.gd")
const SolarMarkerStabilitySuite = preload("res://tests/integration/solar_marker_stability_suite.gd")
const SatelliteFramingSuite = preload("res://tests/integration/satellite_framing_suite.gd")
const SolarEntryContextSuite = preload("res://tests/integration/solar_entry_context_suite.gd")
const SolarCloseContextSuite = preload("res://tests/integration/solar_close_context_suite.gd")
const PolarEcologySuite = preload("res://tests/integration/polar_ecology_suite.gd")
const EcologyAssetsSuite = preload("res://tests/integration/ecology_assets_suite.gd")
const EcologyAllAssetsSuite = preload("res://tests/integration/ecology_all_assets_suite.gd")
const UIReadabilitySuite = preload("res://tests/integration/ui_readability_suite.gd")
const CameraNavigationSuite = preload("res://tests/integration/camera_navigation_suite.gd")
const SolarOrbitSuite = preload("res://tests/integration/solar_orbit_suite.gd")
const SolarDE440Suite = preload("res://tests/integration/solar_de440_suite.gd")
const SolarTrajectorySuite = preload("res://tests/integration/solar_trajectory_suite.gd")
const LoadingStatusSuite = preload("res://tests/integration/loading_status_suite.gd")
const CleanObservationSuite = preload("res://tests/integration/clean_observation_suite.gd")
const WoodlandRiverSuite = preload("res://tests/integration/woodland_river_suite.gd")
const MonarchLarvaSuite = preload("res://tests/integration/monarch_larva_suite.gd")
const GalacticSuite = preload("res://tests/integration/galactic_suite.gd")
const EclipseSuite = preload("res://tests/integration/eclipse_suite.gd")
const LunarReferenceSuite = preload("res://tests/integration/lunar_reference_suite.gd")
const AlgalGrazingSuite = preload("res://tests/integration/algal_grazing_suite.gd")
const EcologyMapSuite = preload("res://tests/integration/ecology_map_suite.gd")
const OxygenAtomSuite = preload("res://tests/integration/oxygen_atom_suite.gd")
const NavigationSuite = preload("res://tests/integration/navigation_suite.gd")
const GuidedJourneySuite = preload("res://tests/integration/guided_journey_suite.gd")
const RockySurfaceSuite = preload("res://tests/integration/rocky_surface_suite.gd")
const SolarSizeSuite = preload("res://tests/integration/solar_size_suite.gd")
const GuideSearchSuite = preload("res://tests/integration/world_guide_search_suite.gd")
const TurtleSurfaceSuite = preload("res://tests/integration/turtle_surface_suite.gd")
const HumanClothingSuite = preload("res://tests/integration/human_clothing_suite.gd")
const HumanWalkSuite = preload("res://tests/integration/human_walk_suite.gd")
const MarineWaveSuite = preload("res://tests/integration/marine_wave_suite.gd")
const RayWaveSuite = preload("res://tests/integration/ray_wave_suite.gd")
const WoodlandCanopySuite = preload("res://tests/integration/woodland_canopy_suite.gd")
const CityMaterialSuite = preload("res://tests/integration/city_material_suite.gd")
const LandLightingSuite = preload("res://tests/integration/land_lighting_suite.gd")
const ZooplanktonSuite = preload("res://tests/integration/zooplankton_suite.gd")
const GiantClamSuite = preload("res://tests/integration/giant_clam_suite.gd")
const BlackSeaCucumberSuite = preload("res://tests/integration/black_sea_cucumber_suite.gd")
const CitySparrowSuite = preload("res://tests/integration/city_sparrow_suite.gd")
const CityGinkgoSuite = preload("res://tests/integration/city_ginkgo_suite.gd")
const CityGinkgoSeasonSuite = preload("res://tests/integration/city_ginkgo_season_suite.gd")
const RiverWetlandSuite = preload("res://tests/integration/river_wetland_suite.gd")
const FreshwaterSuite = preload("res://tests/integration/freshwater_suite.gd")
const WildCelerySuite = preload("res://tests/integration/wild_celery_suite.gd")
const BandedKillifishSuite = preload("res://tests/integration/banded_killifish_suite.gd")
const FreshwaterVisualSuite = preload("res://tests/integration/freshwater_visual_suite.gd")
const SolarOrbitFrameSuite = preload("res://tests/integration/solar_orbit_frame_suite.gd")
const CityParkGroundSuite = preload("res://tests/integration/city_park_ground_suite.gd")
const CityStreetVarietySuite = preload("res://tests/integration/city_street_variety_suite.gd")
const Stage3VisualAudit189 = preload("res://tests/integration/stage3_visual_audit_189.gd")
const EarthBranchEntrySuite = preload("res://tests/integration/earth_branch_entry_suite.gd")
const CityContextSilhouetteSuite = preload("res://tests/integration/city_context_silhouette_suite.gd")
const CityFabricSuite = preload("res://tests/integration/city_fabric_suite.gd")
const OcotilloSuite = preload("res://tests/integration/ocotillo_suite.gd")
const BrittlebushSuite = preload("res://tests/integration/brittlebush_suite.gd")
const HumanVarietySuite = preload("res://tests/integration/human_variety_suite.gd")
const CityPollinatorSuite = preload("res://tests/integration/city_pollinator_suite.gd")
const CityPondSuite = preload("res://tests/integration/city_pond_suite.gd")
const PolarCoastSuite = preload("res://tests/integration/polar_coast_suite.gd")
const PolarWaterSuite = preload("res://tests/integration/polar_water_suite.gd")
const PolarNightSuite = preload("res://tests/integration/polar_night_suite.gd")
const EarthSeasonOrbitSuite = preload("res://tests/integration/earth_season_orbit_suite.gd")
const RunoffBalanceSuite = preload("res://tests/integration/runoff_balance_suite.gd")
const EarthSpatialEntrySuite = preload("res://tests/integration/earth_spatial_entry_suite.gd")
const EarthEntryContextSuite = preload("res://tests/integration/earth_entry_context_suite.gd")
const CosmosReturnFlightSuite = preload("res://tests/integration/cosmos_return_flight_suite.gd")
const SpatialInputSuite = preload("res://tests/integration/spatial_input_suite.gd")
const SeaCucumberActivitySuite = preload("res://tests/integration/sea_cucumber_activity_suite.gd")
const EarthPolarDaylightSuite = preload("res://tests/integration/earth_polar_daylight_suite.gd")
const SpeciesAtlasSuite = preload("res://tests/integration/species_atlas_suite.gd")
const DayOctopusSuite = preload("res://tests/integration/day_octopus_suite.gd")
const CityStreetObservationSuite = preload("res://tests/integration/city_street_observation_suite.gd")
const PolarSoundSuite = preload("res://tests/integration/polar_sound_suite.gd")
const RedFoxSuite = preload("res://tests/integration/red_fox_suite.gd")
const WorldTourSuite = preload("res://tests/integration/world_tour_suite.gd")
const SolarNamesSuite = preload("res://tests/integration/solar_names_suite.gd")
const WorldTourLessonsSuite = preload("res://tests/integration/world_tour_lessons_suite.gd")
const SolarComparisonSuite = preload("res://tests/integration/solar_comparison_suite.gd")
const PenguinActivitySuite = preload("res://tests/integration/penguin_activity_suite.gd")
const CityParkTreesSuite = preload("res://tests/integration/city_park_trees_suite.gd")
const CityBirdPedestrianSuite = preload("res://tests/integration/city_bird_pedestrian_suite.gd")
const CityBirdObservationSuite = preload("res://tests/integration/city_bird_observation_suite.gd")
const SeagrassSuite = preload("res://tests/integration/seagrass_suite.gd")
const LoadingRecoverySuite = preload("res://tests/integration/loading_recovery_suite.gd")
const SchoolingSuite = preload("res://tests/integration/schooling_suite.gd")
const DeadwoodSuite = preload("res://tests/integration/deadwood_suite.gd")
const RobinSkinSuite = preload("res://tests/integration/robin_skin_suite.gd")
const JovianSuite = preload("res://tests/integration/jovian_suite.gd")
const IguanaSuite = preload("res://tests/integration/iguana_suite.gd")
const DesertSuite = preload("res://tests/integration/desert_suite.gd")
const FungusSuite = preload("res://tests/integration/fungus_suite.gd")
const SymbiosisSuite = preload("res://tests/integration/symbiosis_suite.gd")
const FrogSuite = preload("res://tests/integration/frog_suite.gd")
const LunarPhaseSuite = preload("res://tests/integration/lunar_phase_suite.gd")
const RunoffSuite = preload("res://tests/integration/runoff_suite.gd")
const CoralSuite = preload("res://tests/integration/coral_suite.gd")
const BrowseSuite = preload("res://tests/integration/browse_suite.gd")
const TurtleSuite = preload("res://tests/integration/turtle_suite.gd")
const DeerSkinSuite = preload("res://tests/integration/deer_skin_suite.gd")
const PollinatorSuite = preload("res://tests/integration/pollinator_suite.gd")
const RobinMotionSuite = preload("res://tests/integration/robin_motion_suite.gd")
const CityCrossingSuite = preload("res://tests/integration/city_crossing_suite.gd")
const KeplerObservationSuite = preload("res://tests/integration/kepler_observation_suite.gd")
const UrchinObservationSuite = preload("res://tests/integration/urchin_observation_suite.gd")
const ObservationFramingSuite = preload("res://tests/integration/observation_framing_suite.gd")
const PlantObservationSuite = preload("res://tests/integration/plant_observation_suite.gd")
const SeasonObservationSuite = preload("res://tests/integration/season_observation_suite.gd")
const EarthLocatorSuite = preload("res://tests/integration/earth_locator_suite.gd")
const SnapperSuite = preload("res://tests/integration/snapper_suite.gd")
const UrbanEnvironmentSuite = preload("res://tests/integration/urban_environment_suite.gd")
const ScienceReferenceSuite = preload("res://tests/integration/science_reference_suite.gd")
const LandSoundSuite = preload("res://tests/integration/land_sound_suite.gd")
const GuideSuite = preload("res://tests/integration/world_guide_suite.gd")
const HumanSkinSuite = preload("res://tests/integration/human_skin_suite.gd")
const WoodlandSuite = preload("res://tests/integration/woodland_suite.gd")
const LearningSuite = preload("res://tests/integration/learning_suite.gd")
const Content87Suite = preload("res://tests/integration/content_87_suite.gd")
const LifeAssetsSuite = preload("res://tests/integration/life_assets_suite.gd")
const CelestialSuite = preload("res://tests/integration/celestial_suite.gd")
const ExpansionSuite = preload("res://tests/integration/world_expansion_suite.gd")
const CityPublicGreenSuite = preload("res://tests/integration/city_public_green_suite.gd")
const SolarOrbitViewsSuite = preload("res://tests/integration/solar_orbit_views_suite.gd")
const MonarchLifeStagesSuite = preload("res://tests/integration/monarch_life_stages_suite.gd")
const EarthDaylightSuite = preload("res://tests/integration/earth_daylight_suite.gd")
const BoxTurtleSuite = preload("res://tests/integration/box_turtle_suite.gd")
const TurtleComparisonSuite = preload("res://tests/integration/turtle_comparison_suite.gd")
const LocalRulerSuite = preload("res://tests/integration/local_ruler_suite.gd")
const SolarLightTravelSuite = preload("res://tests/integration/solar_light_travel_suite.gd")
const CityCrossingExperimentSuite = preload("res://tests/integration/city_crossing_experiment_suite.gd")
const Primer: Script = preload("res://scripts/render_feature_primer.gd")


func _ready() -> void:
	_route.call_deferred()


func _route() -> void:
	if "--cosmic285-review" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().show(); get_window().grab_focus.call_deferred()
		print("COSMIC285_PROBE_START")
		var cosmic_primer: Node=Primer.new()
		add_child(cosmic_primer)
		await cosmic_primer.prepare()
		add_child(load("res://tests/integration/cosmic_wide_suite.gd").new())
		cosmic_primer.queue_free()
		return
	if "--performance284-review" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().show(); get_window().grab_focus.call_deferred()
		print("PERFORMANCE284_PROBE_START")
		var performance_primer: Node=Primer.new()
		add_child(performance_primer)
		await performance_primer.prepare()
		add_child(load("res://tests/integration/performance_quality_suite.gd").new())
		performance_primer.queue_free()
		return
	if "--world283-zoom-review" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().unfocusable=false
		get_window().mode=Window.MODE_WINDOWED
		get_window().show(); get_window().grab_focus.call_deferred()
		print("SOLAR283_PROBE_START")
		var zoom_primer: Node=Primer.new()
		add_child(zoom_primer)
		await zoom_primer.prepare()
		add_child(SolarZoomReturnSuite.new())
		zoom_primer.queue_free()
		return
	if "--world282-marker-review" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().unfocusable=false
		get_window().mode=Window.MODE_WINDOWED
		get_window().show(); get_window().grab_focus.call_deferred()
		print("SOLAR282_PROBE_START")
		var marker_primer: Node=Primer.new()
		add_child(marker_primer)
		await marker_primer.prepare()
		add_child(SolarMarkerStabilitySuite.new())
		marker_primer.queue_free()
		return
	if "--world281-closeup-review" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().unfocusable=false
		get_window().mode=Window.MODE_WINDOWED
		get_window().show(); get_window().grab_focus.call_deferred()
		print("SOLAR281_PROBE_START")
		var closeup_primer: Node=Primer.new()
		add_child(closeup_primer)
		await closeup_primer.prepare()
		add_child(SolarCloseupSuite.new())
		closeup_primer.queue_free()
		return
	if "--world280-framing-review" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().unfocusable=false
		get_window().mode=Window.MODE_WINDOWED
		get_window().show(); get_window().grab_focus.call_deferred()
		print("SOLAR280_PROBE_START")
		var framing_primer: Node=Primer.new()
		add_child(framing_primer)
		await framing_primer.prepare()
		add_child(SatelliteFramingSuite.new())
		framing_primer.queue_free()
		return
	if "--world279-entry-review" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().unfocusable=false
		get_window().mode=Window.MODE_WINDOWED
		get_window().show(); get_window().grab_focus.call_deferred()
		print("SOLAR279_PROBE_START")
		var entry_primer: Node = Primer.new()
		add_child(entry_primer)
		await entry_primer.prepare()
		add_child(SolarEntryContextSuite.new())
		entry_primer.queue_free()
		return
	if "--world276-drag-review" in OS.get_cmdline_user_args() or "--world277-close-review" in OS.get_cmdline_user_args() or "--world278-scale-review" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().unfocusable=false
		get_window().mode=Window.MODE_WINDOWED
		get_window().show()
		get_window().grab_focus.call_deferred()
		var close_review: bool = "--world277-close-review" in OS.get_cmdline_user_args()
		var scale_review: bool = "--world278-scale-review" in OS.get_cmdline_user_args()
		print("SOLAR278_PROBE_START" if scale_review else "SOLAR277_PROBE_START" if close_review else "SOLAR276_PROBE_START")
		var drag_primer: Node = Primer.new()
		add_child(drag_primer)
		await drag_primer.prepare()
		add_child(SolarScaleSuite.new() if scale_review else SolarCloseContextSuite.new() if close_review else SolarDragVisibilitySuite.new())
		drag_primer.queue_free()
		return
	if "--world275-satellites-review" in OS.get_cmdline_user_args() or "--world278-satellites-scale" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().unfocusable=false
		get_window().mode=Window.MODE_WINDOWED
		get_window().show()
		get_window().grab_focus.call_deferred()
		print("SATELLITES275_PROBE_START")
		var satellite_primer: Node = Primer.new()
		add_child(satellite_primer)
		await satellite_primer.prepare()
		add_child(SatelliteScaleSuite.new() if "--world278-satellites-scale" in OS.get_cmdline_user_args() else SatelliteExplorationSuite.new())
		satellite_primer.queue_free()
		return
	if "--world273-satellites-review" in OS.get_cmdline_user_args():
		get_window().gui_disable_input=true
		get_window().unfocusable=false
		get_window().mode=Window.MODE_WINDOWED
		get_window().show()
		get_window().grab_focus.call_deferred()
		print("SATELLITES273_PROBE_START")
		var satellite_primer: Node = Primer.new()
		add_child(satellite_primer)
		await satellite_primer.prepare()
		add_child(SatelliteCoverageSuite.new())
		satellite_primer.queue_free()
		return
	if "--world267-polar-review" in OS.get_cmdline_user_args() or "--world268-assets-review" in OS.get_cmdline_user_args() or "--world269-assets-review" in OS.get_cmdline_user_args():
		# Use the same embedded route on source and Release; no external script override.
		var window: Window = get_window()
		window.unfocusable = true
		window.gui_disable_input = true
		var primary: int = DisplayServer.get_primary_screen()
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != primary:
				window.current_screen = screen
				break
		window.position = DisplayServer.screen_get_usable_rect(window.current_screen).position + Vector2i(30,30)
		print("POLAR267_EMBEDDED_START ",JSON.stringify({"screen_count":DisplayServer.get_screen_count(),"primary":primary,"chosen":window.current_screen,"unfocusable":true}))
		var polar_primer: Node = Primer.new()
		add_child(polar_primer)
		await polar_primer.prepare()
		if "--world269-assets-review" in OS.get_cmdline_user_args():add_child(EcologyAllAssetsSuite.new())
		else:add_child(EcologyAssetsSuite.new() if "--world268-assets-review" in OS.get_cmdline_user_args() else PolarEcologySuite.new())
		polar_primer.queue_free()
		return
	var giant_clam_requested: bool = false
	var black_sea_cucumber_requested: bool = false
	var city_sparrow_requested: bool = false
	var city_ginkgo_requested: bool = false
	var city_ginkgo_season_requested: bool = false
	var river_wetland_requested: bool = false
	var freshwater_requested: bool = false
	var wild_celery_requested: bool = false
	var banded_killifish_requested: bool = false
	var freshwater_visual_requested: bool = false
	var solar_orbit_frame_requested: bool = false
	var city_park_ground_requested: bool = false
	var city_street_variety_requested: bool = false
	var stage3_visual_audit_requested: bool = false
	var earth_branch_entry_requested: bool = false
	var city_context_silhouette_requested: bool = false
	var city_fabric_requested: bool = false
	var city_public_green_requested: bool = false
	var solar_orbit_views_requested: bool = false
	var monarch_life_stages_requested: bool = false
	var earth_daylight_requested: bool = false
	var box_turtle_requested: bool = false
	var turtle_comparison_requested: bool = false
	var local_ruler_requested: bool = false
	var city_crossing_experiment_requested: bool = false
	var ocotillo_requested: bool = false
	var brittlebush_requested: bool = false
	var human_variety_requested: bool = false
	var city_pollinator_requested: bool = false
	var city_pond_requested: bool = false
	var polar_coast_requested: bool = false
	var polar_water_requested: bool = false
	var polar_night_requested: bool = false
	var earth_season_requested: bool = false
	var runoff_balance_requested: bool = false
	var earth_spatial_entry_requested: bool = false
	var earth_entry_context_requested: bool = false
	var cosmos_return_flight_requested: bool = false
	var spatial_input_requested: bool = false
	var sea_cucumber_activity_requested: bool = false
	var earth_polar_daylight_requested: bool = false
	var city_park_trees_requested: bool = false
	var city_bird_pedestrian_requested: bool = false
	var city_bird_observation_requested: bool = false
	var zooplankton_requested: bool = false
	var object_pointer_requested: bool = false
	var camera_navigation_requested: bool = false
	var loading_status_requested: bool = false
	var clean_observation_requested: bool = false
	var woodland_river_requested: bool = false
	var monarch_larva_requested: bool = false
	var galactic_requested: bool = false
	var eclipse_requested: bool = false
	var lunar_reference_requested: bool = false
	var algal_grazing_requested: bool = false
	var ecology_map_requested: bool = false
	var oxygen_atom_requested: bool = false
	var navigation_requested: bool = false
	var guided_journey_requested: bool = false
	var rocky_surface_requested: bool = false
	var world_tour_requested: bool = false
	var solar_names_requested: bool = false
	var world_tour_lessons_requested: bool = false
	var solar_comparison_requested: bool = false
	var solar_light_travel_requested: bool = false
	var penguin_activity_requested: bool = false
	var solar_size_requested: bool = false
	var solar_orbit_requested: bool = false
	var solar_de440_requested: bool = false
	var solar_trajectory_requested: bool = false
	var guide_search_requested: bool = false
	var turtle_surface_requested: bool = false
	var human_clothing_requested: bool = false
	var human_walk_requested: bool = false
	var marine_wave_requested: bool = false
	var ray_wave_requested: bool = false
	var woodland_canopy_requested: bool = false
	var city_material_requested: bool = false
	var land_lighting_requested: bool = false
	var seagrass_requested: bool = false
	var loading_recovery_requested: bool = false
	var schooling_requested: bool = false
	var deadwood_requested: bool = false
	var robin_skin_requested: bool = false
	var jovian_requested: bool = false
	var iguana_requested: bool = false
	var desert_requested: bool = false
	var fungus_requested: bool = false
	var symbiosis_requested: bool = false
	var frog_requested: bool = false
	var lunar_phase_requested: bool = false
	var runoff_requested: bool = false
	var coral_requested: bool = false
	var browse_requested: bool = false
	var turtle_requested: bool = false
	var deer_requested: bool = false
	var pollinator_requested: bool = false
	var robin_requested: bool = false
	var crossing_requested: bool = false
	var kepler_requested: bool = false
	var urchin_requested: bool = false
	var observation_framing_requested: bool = false
	var plant_observation_requested: bool = false
	var season_observation_requested: bool = false
	var earth_locator_requested: bool = false
	var snapper_requested: bool = false
	var urban_environment_requested: bool = false
	var science_reference_requested: bool = false
	var land_sound_requested: bool = false
	var guide_requested: bool = false
	var human_skin_requested: bool = false
	var woodland_requested: bool = false
	var learning_requested: bool = false
	var content87_requested: bool = false
	var life_assets_requested: bool = false
	var expansion_requested: bool = false
	var celestial_requested: bool = false
	var suite_requested: bool = false
	var world_check_requested: bool = false
	var continuity_requested: bool = false
	var oxygen_requested: bool = false
	var species_atlas_requested: bool = false
	var day_octopus_requested: bool = false
	var city_street_observation_requested: bool = false
	var polar_sound_requested: bool = false
	var red_fox_requested: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world222-review="): species_atlas_requested = true
		if argument.begins_with("--world223-review="): day_octopus_requested = true
		if argument.begins_with("--world224-review="): city_street_observation_requested = true
		if argument.begins_with("--world225-review="): polar_sound_requested = true
		if argument.begins_with("--world226-review="): red_fox_requested = true
		if argument.begins_with("--world227-review="): world_tour_requested = true
		if argument.begins_with("--world228-review="): solar_names_requested = true
		if argument.begins_with("--world229-review="): world_tour_lessons_requested = true
		if argument.begins_with("--world230-review="): solar_comparison_requested = true
		if argument.begins_with("--world231-review="): penguin_activity_requested = true
		if argument.begins_with("--world233-review="): city_public_green_requested = true
		if argument.begins_with("--world234-review="): solar_orbit_views_requested = true
		if argument.begins_with("--world236-review="): monarch_life_stages_requested = true
		if argument.begins_with("--world237-review="): earth_daylight_requested = true
		if argument.begins_with("--world238-review="): box_turtle_requested = true
		if argument.begins_with("--world239-review="): turtle_comparison_requested = true
		if argument.begins_with("--world240-review="): local_ruler_requested = true
		if argument.begins_with("--world241-review="): solar_light_travel_requested = true
		if argument.begins_with("--world235-review="): city_crossing_experiment_requested = true
		if argument.begins_with("--world168-review="): city_sparrow_requested = true
		if argument.begins_with("--world169-review="): city_ginkgo_requested = true
		if argument.begins_with("--world172-review="): city_ginkgo_season_requested = true
		if argument.begins_with("--world173-review="): river_wetland_requested = true
		if argument.begins_with("--world177-review="): freshwater_requested = true
		if argument.begins_with("--world178-review="): wild_celery_requested = true
		if argument.begins_with("--world181-review="): banded_killifish_requested = true
		if argument.begins_with("--world185-review="): freshwater_visual_requested = true
		if argument.begins_with("--world187-review="): solar_orbit_frame_requested = true
		if argument.begins_with("--world186-review="): city_park_ground_requested = true
		if argument.begins_with("--world188-review="): city_street_variety_requested = true
		if argument.begins_with("--world189-audit="): stage3_visual_audit_requested = true
		if argument.begins_with("--world189-review="): earth_branch_entry_requested = true
		if argument.begins_with("--world190-check="): city_context_silhouette_requested = true
		if argument.begins_with("--world199-review="): city_fabric_requested = true
		if argument.begins_with("--world192-review="): ocotillo_requested = true
		if argument.begins_with("--world203-review="): brittlebush_requested = true
		if argument.begins_with("--world194-review="): human_variety_requested = true
		if argument.begins_with("--world195-review="): city_pollinator_requested = true
		if argument.begins_with("--world196-review="): city_pond_requested = true
		if argument.begins_with("--world197-review="): polar_coast_requested = true
		if argument.begins_with("--world243-review="): polar_water_requested = true
		if argument.begins_with("--world244-review="): polar_night_requested = true
		if argument.begins_with("--world246-review="): earth_season_requested = true
		if argument.begins_with("--world248-review="): runoff_balance_requested = true
		if argument.begins_with("--world249-review="): earth_spatial_entry_requested = true
		if argument.begins_with("--world250-entry-check="): earth_entry_context_requested = true
		if argument.begins_with("--world251-macro-check="): cosmos_return_flight_requested = true
		if argument.begins_with("--world252-input-check="): spatial_input_requested = true
		if argument.begins_with("--world247-review="): sea_cucumber_activity_requested = true
		if argument.begins_with("--world245-review="): earth_polar_daylight_requested = true
		if argument.begins_with("--world175-review="): city_park_trees_requested = true
		if argument.begins_with("--world170-review="): city_bird_pedestrian_requested = true
		if argument.begins_with("--world171-review="): city_bird_observation_requested = true
		if argument.begins_with("--world165-review="): giant_clam_requested = true
		if argument.begins_with("--world184-review="): black_sea_cucumber_requested = true
		if argument.begins_with("--world164-review="): zooplankton_requested = true
		if argument == "--preview-secondary" and DisplayServer.get_name() != "headless":
			for screen: int in range(DisplayServer.get_screen_count()):
				if screen == DisplayServer.get_primary_screen(): continue
				get_window().set_meta("preview_secondary_screen", screen)
				get_window().unfocusable = true
				get_window().always_on_top = true
				get_window().current_screen = screen
				break
		if argument.begins_with("--measurement-screen=") and DisplayServer.get_name() != "headless":
			var screen_text: String = argument.trim_prefix("--measurement-screen=")
			if screen_text.is_valid_int():
				var screen: int = int(screen_text)
				if screen >= 0 and screen < DisplayServer.get_screen_count() and screen != DisplayServer.get_primary_screen():
					# Apply the opt-in secondary policy before the startup primer too.
					get_window().unfocusable = true
					get_window().always_on_top = true
					get_window().current_screen = screen
		if argument.begins_with("--world151-check="): object_pointer_requested = true
		if argument.begins_with("--world152-check="): camera_navigation_requested = true
		if argument.begins_with("--world157-check="): solar_orbit_requested = true
		if argument.begins_with("--world179-review="): solar_de440_requested = true
		if argument.begins_with("--world180-review="): solar_trajectory_requested = true
		if argument.begins_with("--world148-check="): loading_status_requested = true
		if argument.begins_with("--world146-check="): clean_observation_requested = true
		if argument.begins_with("--world145-check="): woodland_river_requested = true
		if argument.begins_with("--world144-check="): monarch_larva_requested = true
		if argument.begins_with("--world142-check="): galactic_requested = true
		if argument.begins_with("--world141-check="): eclipse_requested = true
		if argument.begins_with("--world139-check="): lunar_reference_requested = true
		if argument.begins_with("--world138-check="): algal_grazing_requested = true
		if argument.begins_with("--world137-check="): ecology_map_requested = true
		if argument.begins_with("--world136-check="): oxygen_atom_requested = true
		if argument.begins_with("--world135-check="): navigation_requested = true
		if argument.begins_with("--world134-check="): guided_journey_requested = true
		if argument.begins_with("--world133-check="): rocky_surface_requested = true
		if argument.begins_with("--world132-check="): solar_size_requested = true
		if argument.begins_with("--world131-check="): guide_search_requested = true
		if argument.begins_with("--world130-check="): turtle_surface_requested = true
		if argument.begins_with("--world129-check="): human_clothing_requested = true
		if argument.begins_with("--world128-check="): human_walk_requested = true
		if argument.begins_with("--world127-check="): marine_wave_requested = true
		if argument.begins_with("--world126-check="): ray_wave_requested = true
		if argument.begins_with("--world125-check="): woodland_canopy_requested = true
		if argument.begins_with("--world124-check="): city_material_requested = true
		if argument.begins_with("--world123-check="): land_lighting_requested = true
		if argument.begins_with("--world122-check="): seagrass_requested = true
		if argument.begins_with("--world121-check="): loading_recovery_requested = true
		if argument.begins_with("--world120-check="): schooling_requested = true
		if argument.begins_with("--world119-check="): deadwood_requested = true
		if argument.begins_with("--world118-check="): robin_skin_requested = true
		if argument.begins_with("--world117-check="): jovian_requested = true
		if argument.begins_with("--world116-check="): iguana_requested = true
		if argument.begins_with("--world115-check="): desert_requested = true
		if argument.begins_with("--world114-check="): fungus_requested = true
		if argument.begins_with("--world113-check="): symbiosis_requested = true
		if argument.begins_with("--world112-check="): frog_requested = true
		if argument.begins_with("--world111-check="): lunar_phase_requested = true
		if argument.begins_with("--world110-check="): runoff_requested = true
		if argument.begins_with("--world109-check="): coral_requested = true
		if argument.begins_with("--world108-check="): browse_requested = true
		if argument.begins_with("--world107-check="): turtle_requested = true
		if argument.begins_with("--world105-check="): deer_requested = true
		if argument.begins_with("--world104-check="): pollinator_requested = true
		if argument.begins_with("--world103-check="): robin_requested = true
		if argument.begins_with("--world102-check="): crossing_requested = true
		if argument.begins_with("--world101-check="): kepler_requested = true
		if argument.begins_with("--world100-check="): urchin_requested = true
		if argument.begins_with("--world99-check="): observation_framing_requested = true
		if argument.begins_with("--world98-check="): plant_observation_requested = true
		if argument.begins_with("--world97-check="): season_observation_requested = true
		if argument.begins_with("--world96-check="): earth_locator_requested = true
		if argument.begins_with("--world95-check="): snapper_requested = true
		if argument.begins_with("--world94-check="): urban_environment_requested = true
		if argument.begins_with("--world93-check=") or argument.begins_with("--world106-check="): science_reference_requested = true
		if argument.begins_with("--world92-check="): land_sound_requested = true
		if argument.begins_with("--world91-check="): guide_requested = true
		if argument.begins_with("--world90-check="): human_skin_requested = true
		if argument.begins_with("--world89-check="): woodland_requested = true
		if argument.begins_with("--world88-check="): learning_requested = true
		if argument.begins_with("--world87-check="): content87_requested = true
		if argument.begins_with("--world86-check="): life_assets_requested = true
		if argument.begins_with("--world85-check="): celestial_requested = true
		if argument.begins_with("--world84-check="): expansion_requested = true
		if argument == "--suite" or argument.begins_with("--suite="):
			suite_requested = true
		if argument.begins_with("--world-check="): world_check_requested = true
		if argument.begins_with("--continuity-check="): continuity_requested = true
		if (argument.begins_with("--oxygen-check=") or argument.begins_with("--stage2-check=")): oxygen_requested = true
	if solar_orbit_frame_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar_orbit_frame187","headless":DisplayServer.get_name()=="headless"}))
		var frame_primer: Node=Primer.new()
		add_child(frame_primer)
		await frame_primer.prepare()
		var frame_suite: Node=SolarOrbitFrameSuite.new()
		frame_suite.name="SolarOrbitFrameSuite"
		add_child(frame_suite)
		await get_tree().process_frame
		frame_primer.queue_free()
		return
	if city_street_variety_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_street_variety188","headless":DisplayServer.get_name()=="headless"}))
		var street_primer: Node=Primer.new()
		add_child(street_primer)
		await street_primer.prepare()
		var street_suite: Node=CityStreetVarietySuite.new()
		street_suite.name="CityStreetVarietySuite"
		add_child(street_suite)
		await get_tree().process_frame
		street_primer.queue_free()
		return
	if stage3_visual_audit_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"stage3_visual_audit189","headless":DisplayServer.get_name()=="headless"}))
		var audit_primer: Node=Primer.new()
		add_child(audit_primer)
		await audit_primer.prepare()
		var audit_suite: Node=Stage3VisualAudit189.new()
		audit_suite.name="Stage3VisualAudit189"
		add_child(audit_suite)
		await get_tree().process_frame
		audit_primer.queue_free()
		return
	if earth_branch_entry_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"earth_branch_entry189","headless":DisplayServer.get_name()=="headless"}))
		var earth_primer: Node=Primer.new()
		add_child(earth_primer)
		await earth_primer.prepare()
		var earth_suite: Node=EarthBranchEntrySuite.new()
		earth_suite.name="EarthBranchEntrySuite"
		add_child(earth_suite)
		await get_tree().process_frame
		earth_primer.queue_free()
		return
	if city_context_silhouette_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_context_silhouette190","headless":DisplayServer.get_name()=="headless"}))
		var context_suite: Node=CityContextSilhouetteSuite.new()
		context_suite.name="CityContextSilhouetteSuite"
		add_child(context_suite)
		return
	if city_fabric_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_fabric199","headless":DisplayServer.get_name()=="headless"}))
		var fabric_primer: Node=Primer.new()
		add_child(fabric_primer)
		await fabric_primer.prepare()
		var fabric_suite: Node=CityFabricSuite.new()
		fabric_suite.name="CityFabricSuite"
		add_child(fabric_suite)
		await get_tree().process_frame
		fabric_primer.queue_free()
		return
	if ocotillo_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"ocotillo192","headless":DisplayServer.get_name()=="headless"}))
		var ocotillo_suite: Node=OcotilloSuite.new()
		ocotillo_suite.name="OcotilloSuite"
		add_child(ocotillo_suite)
		return
	if brittlebush_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"brittlebush203","headless":DisplayServer.get_name()=="headless"}))
		var brittlebush_suite: Node=BrittlebushSuite.new()
		brittlebush_suite.name="BrittlebushSuite"
		add_child(brittlebush_suite)
		return
	if human_variety_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"human_variety194","headless":DisplayServer.get_name()=="headless"}))
		var human_variety_suite: Node=HumanVarietySuite.new()
		human_variety_suite.name="HumanVarietySuite"
		add_child(human_variety_suite)
		return
	if city_park_ground_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_park_ground186","headless":DisplayServer.get_name()=="headless"}))
		var park_primer: Node=Primer.new()
		add_child(park_primer)
		await park_primer.prepare()
		var park_suite: Node=CityParkGroundSuite.new()
		park_suite.name="CityParkGroundSuite"
		add_child(park_suite)
		await get_tree().process_frame
		park_primer.queue_free()
		return
	if freshwater_visual_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"freshwater_visual185","headless":DisplayServer.get_name()=="headless"}))
		var fish_primer: Node=Primer.new()
		add_child(fish_primer)
		await fish_primer.prepare()
		var fish_suite: Node=FreshwaterVisualSuite.new()
		fish_suite.name="FreshwaterVisualSuite"
		add_child(fish_suite)
		await get_tree().process_frame
		fish_primer.queue_free()
		return
	if banded_killifish_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"banded_killifish181","headless":DisplayServer.get_name()=="headless"}))
		var killifish_primer: Node=Primer.new()
		add_child(killifish_primer)
		await killifish_primer.prepare()
		var killifish_suite: Node=BandedKillifishSuite.new()
		killifish_suite.name="BandedKillifishSuite"
		add_child(killifish_suite)
		await get_tree().process_frame
		killifish_primer.queue_free()
		return
	if wild_celery_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"wild_celery178","headless":DisplayServer.get_name()=="headless"}))
		var wild_celery_primer: Node=Primer.new()
		add_child(wild_celery_primer)
		await wild_celery_primer.prepare()
		var wild_celery_suite: Node=WildCelerySuite.new()
		wild_celery_suite.name="WildCelerySuite"
		add_child(wild_celery_suite)
		await get_tree().process_frame
		wild_celery_primer.queue_free()
		return
	if freshwater_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"freshwater177","headless":DisplayServer.get_name()=="headless"}))
		var freshwater_primer: Node=Primer.new()
		add_child(freshwater_primer)
		await freshwater_primer.prepare()
		var freshwater_suite: Node=FreshwaterSuite.new()
		freshwater_suite.name="FreshwaterSuite"
		add_child(freshwater_suite)
		await get_tree().process_frame
		freshwater_primer.queue_free()
		return
	if city_park_trees_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_park_trees175","headless":DisplayServer.get_name()=="headless"}))
		var park_primer: Node=Primer.new()
		add_child(park_primer)
		await park_primer.prepare()
		var park_suite: Node=CityParkTreesSuite.new()
		park_suite.name="CityParkTreesSuite"
		add_child(park_suite)
		await get_tree().process_frame
		park_primer.queue_free()
		return
	if city_pollinator_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_pollinator195","headless":DisplayServer.get_name()=="headless"}))
		var garden_primer: Node=Primer.new()
		add_child(garden_primer)
		await garden_primer.prepare()
		var garden_suite: Node=CityPollinatorSuite.new()
		garden_suite.name="CityPollinatorSuite"
		add_child(garden_suite)
		await get_tree().process_frame
		garden_primer.queue_free()
		return
	if city_pond_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_pond196","headless":DisplayServer.get_name()=="headless"}))
		var pond_primer: Node=Primer.new()
		add_child(pond_primer)
		await pond_primer.prepare()
		var pond_suite: Node=CityPondSuite.new()
		pond_suite.name="CityPondSuite"
		add_child(pond_suite)
		await get_tree().process_frame
		pond_primer.queue_free()
		return
	if solar_light_travel_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar_light_travel241","headless":DisplayServer.get_name()=="headless"}))
		var light_primer: Node = Primer.new()
		add_child(light_primer)
		await light_primer.prepare()
		var light_suite: Node = SolarLightTravelSuite.new()
		light_suite.name = "SolarLightTravelSuite"
		add_child(light_suite)
		await get_tree().process_frame
		light_primer.queue_free()
		return
	if local_ruler_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"local_ruler240","headless":DisplayServer.get_name()=="headless"}))
		var ruler_primer: Node = Primer.new()
		add_child(ruler_primer)
		await ruler_primer.prepare()
		var ruler_suite: Node = LocalRulerSuite.new()
		ruler_suite.name = "LocalRulerSuite"
		add_child(ruler_suite)
		await get_tree().process_frame
		ruler_primer.queue_free()
		return
	if turtle_comparison_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"turtle_comparison239","headless":DisplayServer.get_name()=="headless"}))
		var comparison_primer: Node = Primer.new()
		add_child(comparison_primer)
		await comparison_primer.prepare()
		var comparison_suite: Node = TurtleComparisonSuite.new()
		comparison_suite.name = "TurtleComparisonSuite"
		add_child(comparison_suite)
		await get_tree().process_frame
		comparison_primer.queue_free()
		return
	if box_turtle_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"box_turtle238","headless":DisplayServer.get_name()=="headless"}))
		var box_turtle_primer: Node = Primer.new()
		add_child(box_turtle_primer)
		await box_turtle_primer.prepare()
		var box_turtle_suite: Node = BoxTurtleSuite.new()
		box_turtle_suite.name = "BoxTurtleSuite"
		add_child(box_turtle_suite)
		await get_tree().process_frame
		box_turtle_primer.queue_free()
		return
	if earth_daylight_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"earth_daylight237","headless":DisplayServer.get_name()=="headless"}))
		var daylight_primer: Node = Primer.new()
		add_child(daylight_primer)
		await daylight_primer.prepare()
		var daylight_suite: Node = EarthDaylightSuite.new()
		daylight_suite.name = "EarthDaylightSuite"
		add_child(daylight_suite)
		await get_tree().process_frame
		daylight_primer.queue_free()
		return
	if monarch_life_stages_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"monarch_life_stages236","headless":DisplayServer.get_name()=="headless"}))
		var life_stages_primer: Node = Primer.new()
		add_child(life_stages_primer)
		await life_stages_primer.prepare()
		var life_stages_suite: Node = MonarchLifeStagesSuite.new()
		life_stages_suite.name = "MonarchLifeStagesSuite"
		add_child(life_stages_suite)
		await get_tree().process_frame
		life_stages_primer.queue_free()
		return
	if city_crossing_experiment_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_crossing_experiment235","headless":DisplayServer.get_name()=="headless"}))
		var crossing_experiment_primer: Node = Primer.new()
		add_child(crossing_experiment_primer)
		await crossing_experiment_primer.prepare()
		var crossing_experiment_suite: Node = CityCrossingExperimentSuite.new()
		crossing_experiment_suite.name = "CityCrossingExperimentSuite"
		add_child(crossing_experiment_suite)
		await get_tree().process_frame
		crossing_experiment_primer.queue_free()
		return
	if solar_orbit_views_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar_orbit_views234","headless":DisplayServer.get_name()=="headless"}))
		var orbit_views_primer: Node = Primer.new()
		add_child(orbit_views_primer)
		await orbit_views_primer.prepare()
		var orbit_views_suite: Node = SolarOrbitViewsSuite.new()
		orbit_views_suite.name = "SolarOrbitViewsSuite"
		add_child(orbit_views_suite)
		await get_tree().process_frame
		orbit_views_primer.queue_free()
		return
	if city_public_green_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_public_green233","headless":DisplayServer.get_name()=="headless"}))
		var green_primer: Node = Primer.new()
		add_child(green_primer)
		await green_primer.prepare()
		var green_suite: Node = CityPublicGreenSuite.new()
		green_suite.name = "CityPublicGreenSuite"
		add_child(green_suite)
		await get_tree().process_frame
		green_primer.queue_free()
		return
	if penguin_activity_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != DisplayServer.get_primary_screen():
				get_window().current_screen = screen
				get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
				break
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"penguin_activity231","headless":DisplayServer.get_name()=="headless"}))
		var penguin_primer: Node = Primer.new()
		add_child(penguin_primer)
		await penguin_primer.prepare()
		var penguin_suite: Node = PenguinActivitySuite.new()
		penguin_suite.name = "PenguinActivitySuite"
		add_child(penguin_suite)
		await get_tree().process_frame
		penguin_primer.queue_free()
		return
	if solar_comparison_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != DisplayServer.get_primary_screen():
				get_window().current_screen = screen
				get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
				break
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar_comparison230","headless":DisplayServer.get_name()=="headless"}))
		var comparison_primer: Node = Primer.new()
		add_child(comparison_primer)
		await comparison_primer.prepare()
		var comparison_suite: Node = SolarComparisonSuite.new()
		comparison_suite.name = "SolarComparisonSuite"
		add_child(comparison_suite)
		await get_tree().process_frame
		comparison_primer.queue_free()
		return
	if world_tour_lessons_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != DisplayServer.get_primary_screen():
				get_window().current_screen = screen
				get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
				break
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"world_tour_lessons229","headless":DisplayServer.get_name()=="headless"}))
		var tour_lessons_primer: Node = Primer.new()
		add_child(tour_lessons_primer)
		await tour_lessons_primer.prepare()
		var tour_lessons_suite: Node = WorldTourLessonsSuite.new()
		tour_lessons_suite.name = "WorldTourLessonsSuite"
		add_child(tour_lessons_suite)
		await get_tree().process_frame
		tour_lessons_primer.queue_free()
		return
	if solar_names_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != DisplayServer.get_primary_screen():
				get_window().current_screen = screen
				get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
				break
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar_names228","headless":DisplayServer.get_name()=="headless"}))
		var solar_names_primer: Node = Primer.new()
		add_child(solar_names_primer)
		await solar_names_primer.prepare()
		var solar_names_suite: Node = SolarNamesSuite.new()
		solar_names_suite.name = "SolarNamesSuite"
		add_child(solar_names_suite)
		await get_tree().process_frame
		solar_names_primer.queue_free()
		return
	if world_tour_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != DisplayServer.get_primary_screen():
				get_window().current_screen = screen
				get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
				break
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"world_tour227","headless":DisplayServer.get_name()=="headless"}))
		var world_tour_primer: Node=Primer.new()
		add_child(world_tour_primer)
		await world_tour_primer.prepare()
		var world_tour_suite: Node=WorldTourSuite.new()
		world_tour_suite.name="WorldTourSuite"
		add_child(world_tour_suite)
		await get_tree().process_frame
		world_tour_primer.queue_free()
		return
	if red_fox_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != DisplayServer.get_primary_screen():
				get_window().current_screen = screen
				get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
				break
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"red_fox226","headless":DisplayServer.get_name()=="headless"}))
		var red_fox_primer: Node=Primer.new()
		add_child(red_fox_primer)
		await red_fox_primer.prepare()
		var red_fox_suite: Node=RedFoxSuite.new()
		red_fox_suite.name="RedFoxSuite"
		add_child(red_fox_suite)
		await get_tree().process_frame
		red_fox_primer.queue_free()
		return
	if polar_sound_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != DisplayServer.get_primary_screen():
				get_window().current_screen = screen
				get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
				break
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"polar_sound225","headless":DisplayServer.get_name()=="headless"}))
		var polar_sound_primer: Node=Primer.new()
		add_child(polar_sound_primer)
		await polar_sound_primer.prepare()
		var polar_sound_suite: Node=PolarSoundSuite.new()
		polar_sound_suite.name="PolarSoundSuite"
		add_child(polar_sound_suite)
		await get_tree().process_frame
		polar_sound_primer.queue_free()
		return
	if city_street_observation_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != DisplayServer.get_primary_screen():
				get_window().current_screen = screen
				get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
				break
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_street_observation224","headless":DisplayServer.get_name()=="headless"}))
		var street_observation_primer: Node=Primer.new()
		add_child(street_observation_primer)
		await street_observation_primer.prepare()
		var street_observation_suite: Node=CityStreetObservationSuite.new()
		street_observation_suite.name="CityStreetObservationSuite"
		add_child(street_observation_suite)
		await get_tree().process_frame
		street_observation_primer.queue_free()
		return
	if day_octopus_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		for screen: int in range(DisplayServer.get_screen_count()):
			if screen != DisplayServer.get_primary_screen():
				get_window().current_screen = screen
				get_window().position = DisplayServer.screen_get_usable_rect(screen).position + Vector2i(30,30)
				break
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"day_octopus223","headless":DisplayServer.get_name()=="headless"}))
		var octopus_primer: Node=Primer.new()
		add_child(octopus_primer)
		await octopus_primer.prepare()
		var octopus_suite: Node=DayOctopusSuite.new()
		octopus_suite.name="DayOctopusSuite"
		add_child(octopus_suite)
		await get_tree().process_frame
		octopus_primer.queue_free()
		return
	if species_atlas_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"species_atlas222","headless":DisplayServer.get_name()=="headless"}))
		var atlas_primer: Node=Primer.new()
		add_child(atlas_primer)
		await atlas_primer.prepare()
		var atlas_suite: Node=SpeciesAtlasSuite.new()
		atlas_suite.name="SpeciesAtlasSuite"
		add_child(atlas_suite)
		await get_tree().process_frame
		atlas_primer.queue_free()
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world258-ui-review="):
			get_window().unfocusable = true
			get_window().always_on_top = true
			get_viewport().gui_disable_input = true
			print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"immersive_ui258","headless":DisplayServer.get_name()=="headless"}))
			var ui_primer: Node = Primer.new()
			add_child(ui_primer)
			await ui_primer.prepare()
			add_child(ImmersiveUISuite.new())
			await get_tree().process_frame
			ui_primer.queue_free()
			return
		if argument.begins_with("--world266-solar-review="):
			get_window().unfocusable=false; get_window().always_on_top=true
			get_viewport().gui_disable_input=true
			print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar266","headless":DisplayServer.get_name()=="headless"}))
			var time_primer: Node=Primer.new(); add_child(time_primer)
			await time_primer.prepare()
			add_child(SolarObservationTimeSuite.new())
			await get_tree().process_frame; time_primer.queue_free()
			return
		if argument.begins_with("--world265-solar-review="):
			get_window().unfocusable=false; get_window().always_on_top=true
			get_viewport().gui_disable_input=true
			print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar265","headless":DisplayServer.get_name()=="headless"}))
			var visual_primer: Node=Primer.new(); add_child(visual_primer)
			await visual_primer.prepare()
			add_child(SolarVisualSuite.new())
			await get_tree().process_frame; visual_primer.queue_free()
			return
		if argument.begins_with("--world264-solar-review="):
			get_window().unfocusable=true; get_window().always_on_top=true
			get_viewport().gui_disable_input=true
			print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar264","headless":DisplayServer.get_name()=="headless"}))
			var spacing_primer: Node=Primer.new(); add_child(spacing_primer)
			await spacing_primer.prepare()
			add_child(SolarSpacingSuite.new())
			await get_tree().process_frame; spacing_primer.queue_free()
			return
		if argument.begins_with("--world263-ui-review="):
			get_window().unfocusable=true; get_window().always_on_top=true
			get_viewport().gui_disable_input=true
			print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"ui263","headless":DisplayServer.get_name()=="headless"}))
			var readable_primer: Node=Primer.new(); add_child(readable_primer)
			await readable_primer.prepare()
			add_child(UIReadabilitySuite.new())
			await get_tree().process_frame; readable_primer.queue_free()
			return
		if argument.begins_with("--world262-sky-review="):
			get_window().unfocusable=true; get_window().always_on_top=true
			get_viewport().gui_disable_input=true
			print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"ground262","headless":DisplayServer.get_name()=="headless"}))
			var sky_primer: Node=Primer.new(); add_child(sky_primer)
			await sky_primer.prepare()
			add_child(GroundSkySuite.new())
			await get_tree().process_frame; sky_primer.queue_free()
			return
		if argument.begins_with("--world261-solar-review="):
			get_window().unfocusable=true; get_window().always_on_top=true
			get_viewport().gui_disable_input=true
			print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar261","headless":DisplayServer.get_name()=="headless"}))
			var moon_primer: Node=Primer.new(); add_child(moon_primer)
			await moon_primer.prepare()
			add_child(SolarMotionMoonSuite.new())
			await get_tree().process_frame; moon_primer.queue_free()
			return
		if argument.begins_with("--world260-solar-review="):
			get_window().unfocusable=true; get_window().always_on_top=true
			get_viewport().gui_disable_input=true
			print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar260","headless":DisplayServer.get_name()=="headless"}))
			var solar_primer: Node=Primer.new(); add_child(solar_primer)
			await solar_primer.prepare()
			add_child(SolarObservationSuite.new())
			await get_tree().process_frame; solar_primer.queue_free()
			return
		if argument.begins_with("--world259-cosmos-review="):
			get_window().unfocusable = true; get_window().always_on_top = true
			get_viewport().gui_disable_input = true
			print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"cosmos259","headless":DisplayServer.get_name()=="headless"}))
			var cosmos_primer: Node = Primer.new(); add_child(cosmos_primer)
			await cosmos_primer.prepare()
			add_child(CosmosMotionSuite.new())
			await get_tree().process_frame
			cosmos_primer.queue_free()
			return
		if argument.begins_with("--world257-marker-review="):
			get_window().unfocusable = true
			get_window().always_on_top = true
			get_viewport().gui_disable_input = true
			print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"earth_markers257","headless":DisplayServer.get_name()=="headless"}))
			var marker_primer: Node = Primer.new()
			add_child(marker_primer)
			await marker_primer.prepare()
			add_child(EarthLandmarkVisualSuite.new())
			await get_tree().process_frame
			marker_primer.queue_free()
			return
		if argument.begins_with("--world256-review="):
			get_window().unfocusable = true
			get_viewport().gui_disable_input = true
			print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"atmosphere_entry256","headless":DisplayServer.get_name()=="headless"}))
			var atmosphere_primer: Node = Primer.new()
			add_child(atmosphere_primer)
			await atmosphere_primer.prepare()
			add_child(AtmosphereEntrySuite.new())
			await get_tree().process_frame
			atmosphere_primer.queue_free()
			return
		if argument.begins_with("--world255-review="):
			get_window().unfocusable = true
			get_viewport().gui_disable_input = true
			print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"spatial_ecology255","headless":DisplayServer.get_name()=="headless"}))
			var ecology_primer: Node = Primer.new()
			add_child(ecology_primer)
			await ecology_primer.prepare()
			add_child(SpatialEcologySuite.new())
			await get_tree().process_frame
			ecology_primer.queue_free()
			return
		if argument.begins_with("--world254-review="):
			get_window().unfocusable = true
			get_viewport().gui_disable_input = true
			print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"selected_entry254","headless":DisplayServer.get_name()=="headless"}))
			var selected_primer: Node = Primer.new()
			add_child(selected_primer)
			await selected_primer.prepare()
			add_child(SelectedEntrySuite.new())
			await get_tree().process_frame
			selected_primer.queue_free()
			return
		if argument.begins_with("--world253-review="):
			get_window().unfocusable = true
			get_viewport().gui_disable_input = true
			print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"spatial_experiments253","headless":DisplayServer.get_name()=="headless"}))
			var experiment_primer: Node = Primer.new()
			add_child(experiment_primer)
			await experiment_primer.prepare()
			add_child(SpatialExperimentsSuite.new())
			await get_tree().process_frame
			experiment_primer.queue_free()
			return
	if spatial_input_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"spatial_input252","headless":DisplayServer.get_name()=="headless"}))
		var input_primer: Node = Primer.new()
		add_child(input_primer)
		await input_primer.prepare()
		add_child(SpatialInputSuite.new())
		await get_tree().process_frame
		input_primer.queue_free()
		return
	if cosmos_return_flight_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"cosmos_return_flight251","headless":DisplayServer.get_name()=="headless"}))
		var macro_primer: Node = Primer.new()
		add_child(macro_primer)
		await macro_primer.prepare()
		add_child(CosmosReturnFlightSuite.new())
		await get_tree().process_frame
		macro_primer.queue_free()
		return
	if earth_entry_context_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode":"earth_entry_context250","headless":DisplayServer.get_name()=="headless"}))
		var context_primer: Node = Primer.new()
		add_child(context_primer)
		await context_primer.prepare()
		add_child(EarthEntryContextSuite.new())
		await get_tree().process_frame
		context_primer.queue_free()
		return
	if earth_spatial_entry_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"earth_spatial_entry249","headless":DisplayServer.get_name()=="headless"}))
		var spatial_primer: Node = Primer.new()
		add_child(spatial_primer)
		await spatial_primer.prepare()
		var spatial_suite: Node = EarthSpatialEntrySuite.new()
		add_child(spatial_suite)
		await get_tree().process_frame
		spatial_primer.queue_free()
		return
	if runoff_balance_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"runoff_balance248","headless":DisplayServer.get_name()=="headless"}))
		var balance_primer: Node = Primer.new()
		add_child(balance_primer)
		await balance_primer.prepare()
		var balance_suite: Node = RunoffBalanceSuite.new()
		add_child(balance_suite)
		await get_tree().process_frame
		balance_primer.queue_free()
		return
	if sea_cucumber_activity_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"sea_cucumber_activity247","headless":DisplayServer.get_name()=="headless"}))
		var cucumber_primer: Node = Primer.new()
		add_child(cucumber_primer)
		await cucumber_primer.prepare()
		var cucumber_suite: Node = SeaCucumberActivitySuite.new()
		add_child(cucumber_suite)
		await get_tree().process_frame
		cucumber_primer.queue_free()
		return
	if earth_season_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"earth_season_orbit246","headless":DisplayServer.get_name()=="headless"}))
		var season_primer: Node = Primer.new()
		add_child(season_primer)
		await season_primer.prepare()
		var season_suite: Node = EarthSeasonOrbitSuite.new()
		add_child(season_suite)
		await get_tree().process_frame
		season_primer.queue_free()
		return
	if earth_polar_daylight_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"earth_polar_daylight245","headless":DisplayServer.get_name()=="headless"}))
		var earth_polar_primer: Node = Primer.new()
		add_child(earth_polar_primer)
		await earth_polar_primer.prepare()
		var earth_polar_suite: Node = EarthPolarDaylightSuite.new()
		earth_polar_suite.name = "EarthPolarDaylightSuite"
		add_child(earth_polar_suite)
		await get_tree().process_frame
		earth_polar_primer.queue_free()
		return
	if polar_night_requested:
		get_window().unfocusable = true
		get_viewport().gui_disable_input = true
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"polar_night244","headless":DisplayServer.get_name()=="headless"}))
		var night_primer: Node = Primer.new()
		add_child(night_primer)
		await night_primer.prepare()
		var night_suite: Node = PolarNightSuite.new()
		night_suite.name = "PolarNightSuite"
		add_child(night_suite)
		await get_tree().process_frame
		night_primer.queue_free()
		return
	if polar_water_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"polar_water243","headless":DisplayServer.get_name()=="headless"}))
		var water_primer: Node=Primer.new()
		add_child(water_primer)
		await water_primer.prepare()
		var water_suite: Node=PolarWaterSuite.new()
		water_suite.name="PolarWaterSuite"
		add_child(water_suite)
		await get_tree().process_frame
		water_primer.queue_free()
		return
	if polar_coast_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"polar_coast197","headless":DisplayServer.get_name()=="headless"}))
		var polar_primer: Node=Primer.new()
		add_child(polar_primer)
		await polar_primer.prepare()
		var polar_suite: Node=PolarCoastSuite.new()
		polar_suite.name="PolarCoastSuite"
		add_child(polar_suite)
		await get_tree().process_frame
		polar_primer.queue_free()
		return
	if river_wetland_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"river_wetland173","headless":DisplayServer.get_name()=="headless"}))
		var wetland_primer: Node=Primer.new()
		add_child(wetland_primer)
		await wetland_primer.prepare()
		var wetland_suite: Node=RiverWetlandSuite.new()
		wetland_suite.name="RiverWetlandSuite"
		add_child(wetland_suite)
		await get_tree().process_frame
		wetland_primer.queue_free()
		return
	if city_ginkgo_season_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_ginkgo_season172","headless":DisplayServer.get_name()=="headless"}))
		var season_primer: Node=Primer.new()
		add_child(season_primer)
		await season_primer.prepare()
		var season_suite: Node=CityGinkgoSeasonSuite.new()
		season_suite.name="CityGinkgoSeasonSuite"
		add_child(season_suite)
		await get_tree().process_frame
		season_primer.queue_free()
		return
	if city_bird_observation_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_bird_observation171","headless":DisplayServer.get_name()=="headless"}))
		var observation_primer: Node=Primer.new()
		add_child(observation_primer)
		await observation_primer.prepare()
		var observation_suite: Node=CityBirdObservationSuite.new()
		observation_suite.name="CityBirdObservationSuite"
		add_child(observation_suite)
		await get_tree().process_frame
		observation_primer.queue_free()
		return
	if city_bird_pedestrian_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_bird_pedestrian170","headless":DisplayServer.get_name()=="headless"}))
		var bird_primer: Node=Primer.new()
		add_child(bird_primer)
		await bird_primer.prepare()
		var bird_suite: Node=CityBirdPedestrianSuite.new()
		bird_suite.name="CityBirdPedestrianSuite"
		add_child(bird_suite)
		await get_tree().process_frame
		bird_primer.queue_free()
		return
	if city_ginkgo_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_ginkgo169","headless":DisplayServer.get_name()=="headless"}))
		var ginkgo_primer: Node=Primer.new()
		add_child(ginkgo_primer)
		await ginkgo_primer.prepare()
		var ginkgo_suite: Node=CityGinkgoSuite.new()
		ginkgo_suite.name="CityGinkgoSuite"
		add_child(ginkgo_suite)
		await get_tree().process_frame
		ginkgo_primer.queue_free()
		return
	if city_sparrow_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"city_sparrow168","headless":DisplayServer.get_name()=="headless"}))
		var sparrow_primer: Node=Primer.new()
		add_child(sparrow_primer)
		await sparrow_primer.prepare()
		var sparrow_suite: Node=CitySparrowSuite.new()
		sparrow_suite.name="CitySparrowSuite"
		add_child(sparrow_suite)
		await get_tree().process_frame
		sparrow_primer.queue_free()
		return
	if black_sea_cucumber_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"black_sea_cucumber184","headless":DisplayServer.get_name()=="headless"}))
		var holothuria_primer: Node=Primer.new()
		add_child(holothuria_primer)
		await holothuria_primer.prepare()
		var holothuria_suite: Node=BlackSeaCucumberSuite.new()
		holothuria_suite.name="BlackSeaCucumberSuite"
		add_child(holothuria_suite)
		await get_tree().process_frame
		holothuria_primer.queue_free()
		return
	if giant_clam_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"giant_clam165","headless":DisplayServer.get_name()=="headless"}))
		var clam_primer: Node=Primer.new()
		add_child(clam_primer)
		await clam_primer.prepare()
		var clam_suite: Node=GiantClamSuite.new()
		clam_suite.name="GiantClamSuite"
		add_child(clam_suite)
		await get_tree().process_frame
		clam_primer.queue_free()
		return
	if zooplankton_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"zooplankton164","headless":DisplayServer.get_name()=="headless"}))
		var water_primer: Node=Primer.new()
		add_child(water_primer)
		await water_primer.prepare()
		var water_suite: Node=ZooplanktonSuite.new()
		water_suite.name="ZooplanktonSuite"
		add_child(water_suite)
		await get_tree().process_frame
		water_primer.queue_free()
		return
	if solar_trajectory_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar_trajectory180","headless":DisplayServer.get_name()=="headless"}))
		var trajectory_primer: Node=Primer.new()
		add_child(trajectory_primer)
		await trajectory_primer.prepare()
		var trajectory_suite: Node=SolarTrajectorySuite.new()
		trajectory_suite.name="SolarTrajectorySuite"
		add_child(trajectory_suite)
		await get_tree().process_frame
		trajectory_primer.queue_free()
		return
	if solar_de440_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar_de440179","headless":DisplayServer.get_name()=="headless"}))
		var de440_primer: Node=Primer.new()
		add_child(de440_primer)
		await de440_primer.prepare()
		var de440_suite: Node=SolarDE440Suite.new()
		de440_suite.name="SolarDE440Suite"
		add_child(de440_suite)
		await get_tree().process_frame
		de440_primer.queue_free()
		return
	if solar_orbit_requested:
		print("PROJECT_RUNTIME_ENTRY ",JSON.stringify({"mode":"solar_orbit157","headless":DisplayServer.get_name()=="headless"}))
		var orbit_primer: Node=Primer.new()
		add_child(orbit_primer)
		await orbit_primer.prepare()
		var orbit_suite: Node=SolarOrbitSuite.new()
		orbit_suite.name="SolarOrbitSuite"
		add_child(orbit_suite)
		await get_tree().process_frame
		orbit_primer.queue_free()
		return
	var run_mode: String = "camera_navigation152" if camera_navigation_requested else "object_pointer151" if object_pointer_requested else "loading_status148" if loading_status_requested else "clean_observation146" if clean_observation_requested else "woodland_river145" if woodland_river_requested else "monarch_larva144" if monarch_larva_requested else "galactic142" if galactic_requested else "eclipse141" if eclipse_requested else "lunar_reference139" if lunar_reference_requested else "algal_grazing138" if algal_grazing_requested else "ecology_map137" if ecology_map_requested else "oxygen_atom136" if oxygen_atom_requested else "navigation135" if navigation_requested else "guided_journey134" if guided_journey_requested else "rocky_surface133" if rocky_surface_requested else "solar_size132" if solar_size_requested else "guide_search131" if guide_search_requested else "turtle_surface130" if turtle_surface_requested else "human_clothing129" if human_clothing_requested else "human_walk128" if human_walk_requested else "marine_wave127" if marine_wave_requested else "ray_wave126" if ray_wave_requested else "woodland_canopy125" if woodland_canopy_requested else "city_material124" if city_material_requested else "land_lighting123" if land_lighting_requested else "seagrass122" if seagrass_requested else "loading_recovery121" if loading_recovery_requested else "schooling120" if schooling_requested else "deadwood119" if deadwood_requested else "robin118" if robin_skin_requested else "jovian117" if jovian_requested else "iguana116" if iguana_requested else "desert115" if desert_requested else "fungus114" if fungus_requested else "symbiosis113" if symbiosis_requested else "frog112" if frog_requested else "lunar111" if lunar_phase_requested else "runoff110" if runoff_requested else "coral109" if coral_requested else "browse108" if browse_requested else "turtle107" if turtle_requested else "deer105" if deer_requested else "pollinator104" if pollinator_requested else "robin103" if robin_requested else "crossing102" if crossing_requested else "kepler101" if kepler_requested else "urchin100" if urchin_requested else "framing99" if observation_framing_requested else "plants98" if plant_observation_requested else "season97" if season_observation_requested else "earth96" if earth_locator_requested else "snapper95" if snapper_requested else "urban94" if urban_environment_requested else "science93" if science_reference_requested else "sound92" if land_sound_requested else "guide91" if guide_requested else "human90" if human_skin_requested else "woodland89" if woodland_requested else "learning88" if learning_requested else "content87" if content87_requested else "life_assets" if life_assets_requested else "celestial" if celestial_requested else "world_expansion" if expansion_requested else "oxygen_check" if oxygen_requested else ("continuity_check" if continuity_requested else ("world_check" if world_check_requested else ("suite" if suite_requested else "experience")))
	print("PROJECT_RUNTIME_ENTRY ", JSON.stringify({"mode": run_mode, "headless": DisplayServer.get_name() == "headless"}))
	var primer: Node = Primer.new()
	add_child(primer)
	await primer.prepare()
	if camera_navigation_requested or object_pointer_requested or loading_status_requested or clean_observation_requested or woodland_river_requested or monarch_larva_requested or galactic_requested or eclipse_requested or lunar_reference_requested or algal_grazing_requested or ecology_map_requested or oxygen_atom_requested or navigation_requested or guided_journey_requested or rocky_surface_requested or solar_size_requested or guide_search_requested or turtle_surface_requested or human_clothing_requested or human_walk_requested or marine_wave_requested or ray_wave_requested or woodland_canopy_requested or city_material_requested or land_lighting_requested or seagrass_requested or loading_recovery_requested or schooling_requested or deadwood_requested or robin_skin_requested or jovian_requested or iguana_requested or desert_requested or fungus_requested or symbiosis_requested or frog_requested or lunar_phase_requested or runoff_requested or coral_requested or browse_requested or turtle_requested or deer_requested or pollinator_requested or robin_requested or crossing_requested or kepler_requested or urchin_requested or observation_framing_requested or plant_observation_requested or season_observation_requested or earth_locator_requested or snapper_requested or urban_environment_requested or science_reference_requested or land_sound_requested or guide_requested or human_skin_requested or woodland_requested or learning_requested or content87_requested or life_assets_requested or celestial_requested or expansion_requested or suite_requested or world_check_requested or continuity_requested or oxygen_requested:
		var suite: Node = CameraNavigationSuite.new() if camera_navigation_requested else ObjectPointerSuite.new() if object_pointer_requested else LoadingStatusSuite.new() if loading_status_requested else CleanObservationSuite.new() if clean_observation_requested else WoodlandRiverSuite.new() if woodland_river_requested else MonarchLarvaSuite.new() if monarch_larva_requested else GalacticSuite.new() if galactic_requested else EclipseSuite.new() if eclipse_requested else LunarReferenceSuite.new() if lunar_reference_requested else AlgalGrazingSuite.new() if algal_grazing_requested else EcologyMapSuite.new() if ecology_map_requested else OxygenAtomSuite.new() if oxygen_atom_requested else NavigationSuite.new() if navigation_requested else GuidedJourneySuite.new() if guided_journey_requested else RockySurfaceSuite.new() if rocky_surface_requested else SolarSizeSuite.new() if solar_size_requested else GuideSearchSuite.new() if guide_search_requested else TurtleSurfaceSuite.new() if turtle_surface_requested else HumanClothingSuite.new() if human_clothing_requested else HumanWalkSuite.new() if human_walk_requested else MarineWaveSuite.new() if marine_wave_requested else RayWaveSuite.new() if ray_wave_requested else WoodlandCanopySuite.new() if woodland_canopy_requested else CityMaterialSuite.new() if city_material_requested else LandLightingSuite.new() if land_lighting_requested else SeagrassSuite.new() if seagrass_requested else LoadingRecoverySuite.new() if loading_recovery_requested else SchoolingSuite.new() if schooling_requested else DeadwoodSuite.new() if deadwood_requested else RobinSkinSuite.new() if robin_skin_requested else JovianSuite.new() if jovian_requested else IguanaSuite.new() if iguana_requested else DesertSuite.new() if desert_requested else FungusSuite.new() if fungus_requested else SymbiosisSuite.new() if symbiosis_requested else FrogSuite.new() if frog_requested else LunarPhaseSuite.new() if lunar_phase_requested else RunoffSuite.new() if runoff_requested else CoralSuite.new() if coral_requested else BrowseSuite.new() if browse_requested else TurtleSuite.new() if turtle_requested else DeerSkinSuite.new() if deer_requested else PollinatorSuite.new() if pollinator_requested else RobinMotionSuite.new() if robin_requested else CityCrossingSuite.new() if crossing_requested else KeplerObservationSuite.new() if kepler_requested else UrchinObservationSuite.new() if urchin_requested else ObservationFramingSuite.new() if observation_framing_requested else PlantObservationSuite.new() if plant_observation_requested else SeasonObservationSuite.new() if season_observation_requested else EarthLocatorSuite.new() if earth_locator_requested else SnapperSuite.new() if snapper_requested else UrbanEnvironmentSuite.new() if urban_environment_requested else ScienceReferenceSuite.new() if science_reference_requested else LandSoundSuite.new() if land_sound_requested else GuideSuite.new() if guide_requested else HumanSkinSuite.new() if human_skin_requested else WoodlandSuite.new() if woodland_requested else LearningSuite.new() if learning_requested else Content87Suite.new() if content87_requested else LifeAssetsSuite.new() if life_assets_requested else CelestialSuite.new() if celestial_requested else ExpansionSuite.new() if expansion_requested else OxygenSuite.new() if oxygen_requested else (ContinuitySuite.new() if continuity_requested else (WorldResumeSuite.new() if world_check_requested else Suite.new()))
		suite.name = "ExperienceSuite"
		add_child(suite)
		# Suite setup is deferred, so retain the feedback until it owns a real stage.
		await get_tree().process_frame
		primer.queue_free()
	else:
		# Scene replacement also releases this entry and its temporary primer.
		var result: Error = get_tree().change_scene_to_packed(Experience)
		if result != OK:
			push_error("Cannot enter the experience scene: %s" % result)
			get_tree().quit(1)
