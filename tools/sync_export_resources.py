#!/usr/bin/env python3
"""Keep the macOS runtime export inputs explicit; check with --check before export.

The pinned editor did not follow GDScript preloads when exporting selected scenes.
Include runtime scripts/shaders explicitly, while Godot follows scene asset imports.
Dynamic stage and fault-fixture paths remain deliberate seeds below.
"""
from pathlib import Path
import argparse
import re

ROOT = Path(__file__).resolve().parents[1]
SEEDS = {
    'tests/integration/performance_quality_suite.gd',
    'tests/integration/cosmic_wide_suite.gd',
    'tests/diagnostics/performance284_experience.gd',
    'scenes/experience/woodland_stage.tscn',
    'scenes/experience/city_stage.tscn',
    'scenes/experience/deep_space_stage.tscn',
    'scenes/experience/earth_stage.tscn',
    'scenes/experience/earth_moon_stage.tscn',

    'tests/integration/solar_zoom_return_suite.gd',
    'tests/integration/solar_marker_stability_suite.gd',
    'tests/integration/solar_closeup_suite.gd',
    'tests/integration/satellite_framing_suite.gd',
    'tests/integration/solar_entry_context_suite.gd',
    'tests/integration/satellite_scale_suite.gd',
    'tests/integration/solar_scale_suite.gd',
	'tests/integration/solar_close_context_suite.gd',
    'tests/integration/satellite_exploration_suite.gd',
    'tests/integration/solar_drag_visibility_suite.gd',
    'assets/data/satellites275/manifest.json',
    'assets/data/satellites275/major.bin',
    'assets/data/satellites275/outer.json',
    'assets/data/satellites275/outer.bin',
    'scenes/experience/satellites_stage.tscn',
    'tests/integration/satellite_coverage_suite.gd',
    'assets/data/satellites273/catalogue.json',
    'assets/data/satellites273/vectors.bin',
    'tests/integration/ecology_all_assets_suite.gd',
    'tests/diagnostics/ecology269_experience.gd',
    'tests/integration/polar_ecology_suite.gd',
    'tests/integration/ecology_assets_suite.gd',
    'scenes/experience/arctic_stage.tscn',
    'tests/integration/solar_observation_time_suite.gd',
    'tests/integration/solar_visual_suite.gd',
    'tests/integration/solar_spacing_suite.gd',
	'tests/integration/ui_readability_suite.gd',
	'tests/integration/ground_sky_suite.gd',
    'scenes/experience/ground_sky_stage.tscn',
    'assets/data/ground_sky262/bsc-visible.json',
    'assets/data/ground_sky262/manifest.json',
    'tests/integration/solar_motion_moon_suite.gd',
    'tests/integration/solar_observation_suite.gd',
    'tests/integration/immersive_ui_suite.gd',
    'tests/integration/cosmos_motion_suite.gd',
    'tests/integration/atmosphere_entry_suite.gd',
    'tests/integration/earth_landmark_visual_suite.gd',
    'tests/integration/spatial_ecology_suite.gd',
    'tests/integration/selected_entry_suite.gd',
    'tests/integration/spatial_experiments_suite.gd',
    'tests/integration/spatial_input_suite.gd',
    'tests/integration/cosmos_return_flight_suite.gd',
    'tests/integration/earth_entry_context_suite.gd',
    'tests/integration/earth_spatial_entry_suite.gd',
    'tests/integration/runoff_balance_suite.gd',
    'tests/integration/sea_cucumber_activity_suite.gd',
    'tests/integration/earth_season_orbit_suite.gd',
    'tests/integration/earth_polar_daylight_suite.gd',
    'tests/integration/polar_night_suite.gd',
    'tests/integration/polar_water_suite.gd',
    'tests/integration/solar_light_travel_suite.gd',
    'tests/integration/local_ruler_suite.gd',
    'tests/integration/turtle_comparison_suite.gd',
    'tests/integration/box_turtle_suite.gd',
    'tests/integration/earth_daylight_suite.gd',
    'tests/integration/monarch_life_stages_suite.gd',
    'tests/integration/city_crossing_experiment_suite.gd',
    'assets/data/solar_de440_179/planet_0.bin',
    'assets/data/solar_de440_179/planet_1.bin',
    'assets/data/solar_de440_179/planet_2.bin',
    'assets/data/solar_de440_179/planet_3.bin',
    'assets/data/solar_de440_179/planet_4.bin',
    'assets/data/solar_de440_179/planet_5.bin',
    'assets/data/solar_de440_179/planet_6.bin',
    'assets/data/solar_de440_179/planet_7.bin',
    'assets/data/solar_de440_179/manifest.json',
    'tests/integration/object_pointer_suite.gd',
    'tests/integration/camera_navigation_suite.gd',
    'scenes/runtime_entry.tscn', 'scenes/experience.tscn',
    'scenes/experience/ocean_stage.tscn', 'scenes/experience/anatomy_stage.tscn',
    'scenes/experience/cosmos_stage.tscn', 'scenes/experience/micro_stage.tscn',
    'scenes/experience/land_stage.tscn', 'scenes/experience/desert_stage.tscn', 'scenes/experience/polar_stage.tscn', 'scenes/experience/jovian_stage.tscn',
    'tests/integration/experience_suite.gd', 'tests/core/fixture_never_prepared.tscn',
    'tests/integration/world_resume_suite.gd', 'tests/integration/continuity_suite.gd',
    'tests/integration/seagrass_suite.gd',
    'tests/integration/land_lighting_suite.gd',
    'tests/integration/zooplankton_suite.gd',
    'tests/integration/giant_clam_suite.gd',
    'tests/integration/black_sea_cucumber_suite.gd',
    'tests/integration/freshwater_visual_suite.gd',
    'tests/integration/city_park_ground_suite.gd',
    'tests/integration/city_street_variety_suite.gd',
    'tests/integration/stage3_visual_audit_189.gd',
    'tests/integration/earth_branch_entry_suite.gd',
    'tests/integration/city_context_silhouette_suite.gd',
    'tests/integration/city_fabric_suite.gd',
    'tests/integration/ocotillo_suite.gd',
    'tests/integration/brittlebush_suite.gd',
    'tests/integration/human_variety_suite.gd',
    'tests/integration/city_pollinator_suite.gd',
    'tests/integration/city_pond_suite.gd',
    'tests/integration/polar_coast_suite.gd',
    'tests/integration/species_atlas_suite.gd',
    'tests/integration/day_octopus_suite.gd',
    'tests/integration/city_street_observation_suite.gd',
    'tests/integration/polar_sound_suite.gd',
    'tests/integration/red_fox_suite.gd',
    'tests/integration/world_tour_suite.gd',
    'tests/integration/solar_names_suite.gd',
    'tests/integration/world_tour_lessons_suite.gd',
    'tests/integration/solar_comparison_suite.gd',
    'tests/integration/penguin_activity_suite.gd',
    'tests/integration/city_public_green_suite.gd',
    'tests/integration/solar_orbit_views_suite.gd',
    'scripts/experience/earth_entry_panel.gd',
    'tests/integration/solar_orbit_frame_suite.gd',
    'tests/integration/city_sparrow_suite.gd',
    'tests/integration/city_ginkgo_suite.gd',
    'tests/integration/city_ginkgo_season_suite.gd',
    'tests/integration/river_wetland_suite.gd',
    'tests/integration/freshwater_suite.gd',
    'tests/integration/wild_celery_suite.gd',
    'tests/integration/banded_killifish_suite.gd',
    'tests/integration/city_park_trees_suite.gd',
    'tests/integration/city_bird_pedestrian_suite.gd',
    'tests/integration/city_bird_observation_suite.gd',
    'tests/integration/solar_orbit_suite.gd',
    'tests/integration/solar_de440_suite.gd',
    'tests/integration/solar_trajectory_suite.gd',
    'tests/integration/solar_size_suite.gd',
    'tests/integration/rocky_surface_suite.gd',
    'tests/integration/ecology_map_suite.gd',
    'tests/integration/algal_grazing_suite.gd',
    'tests/integration/lunar_reference_suite.gd',
    'tests/integration/eclipse_suite.gd',
    'tests/integration/galactic_suite.gd',
    'tests/integration/monarch_larva_suite.gd',
    'tests/integration/woodland_river_suite.gd',
    'tests/integration/clean_observation_suite.gd',
    'tests/integration/loading_status_suite.gd',
    'tests/integration/oxygen_atom_suite.gd',
    'tests/integration/navigation_suite.gd',
    'tests/integration/guided_journey_suite.gd',
    'tests/integration/world_guide_search_suite.gd',
    'tests/integration/turtle_surface_suite.gd',
    'tests/integration/human_clothing_suite.gd',
    'tests/integration/human_walk_suite.gd',
    'tests/integration/marine_wave_suite.gd',
    'tests/integration/ray_wave_suite.gd',
    'tests/integration/woodland_canopy_suite.gd',
    'tests/integration/city_material_suite.gd', 'tests/integration/loading_recovery_suite.gd', 'tests/integration/schooling_suite.gd', 'tests/integration/deadwood_suite.gd', 'tests/integration/robin_skin_suite.gd', 'tests/integration/jovian_suite.gd', 'tests/integration/iguana_suite.gd', 'tests/integration/desert_suite.gd', 'tests/integration/fungus_suite.gd', 'tests/integration/symbiosis_suite.gd', 'tests/integration/frog_suite.gd', 'tests/integration/lunar_phase_suite.gd', 'tests/integration/runoff_suite.gd', 'tests/integration/coral_suite.gd', 'tests/integration/browse_suite.gd', 'tests/integration/turtle_suite.gd', 'tests/integration/deer_skin_suite.gd', 'tests/integration/pollinator_suite.gd', 'tests/integration/robin_motion_suite.gd', 'tests/integration/city_crossing_suite.gd', 'tests/integration/kepler_observation_suite.gd', 'tests/integration/urchin_observation_suite.gd', 'tests/integration/observation_framing_suite.gd', 'tests/integration/plant_observation_suite.gd', 'tests/integration/season_observation_suite.gd', 'tests/integration/earth_locator_suite.gd', 'tests/integration/snapper_suite.gd', 'tests/integration/urban_environment_suite.gd', 'tests/integration/science_reference_suite.gd', 'tests/integration/land_sound_suite.gd', 'tests/integration/world_guide_suite.gd', 'tests/integration/human_skin_suite.gd', 'tests/integration/woodland_suite.gd', 'tests/integration/learning_suite.gd', 'tests/integration/content_87_suite.gd', 'tests/integration/life_assets_suite.gd', 'tests/integration/celestial_suite.gd', 'tests/integration/world_expansion_suite.gd', 'tests/integration/oxygen_suite.gd', 'tests/integration/ecophysiology_suite.gd',
    'tests/core/test_ecophysiology.gd', 'tests/core/fixture_preparing.gd', 'tests/core/fixture.gd',
    'assets/textures/woodland89/forrest_ground_01_diff_1k.jpg',
    'assets/textures/woodland89/forrest_ground_01_nor_gl_1k.jpg',
    'assets/textures/woodland89/forrest_ground_01_arm_1k.jpg',
    'assets/textures/woodland89/bark_brown_02_diff_1k.jpg',
    'assets/textures/woodland89/bark_brown_02_nor_gl_1k.jpg',
    'assets/textures/woodland89/bark_brown_02_arm_1k.jpg',
    'assets/textures/woodland89/rock_surface_diff_1k.jpg',
    'assets/textures/woodland89/rock_surface_nor_gl_1k.jpg',
    'assets/textures/woodland89/rock_surface_arm_1k.jpg',
    'assets/data/reef/placements_v1.res',
    'assets/textures/cosmos/cloud_shape_v1.res',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Fail on stale export inputs without editing')
    args = parser.parse_args()
    paths = SEEDS | {
        str(p.relative_to(ROOT))
        for folder in ('scripts', 'shaders') for p in (ROOT / folder).rglob('*')
        if p.suffix in {'.gd', '.gdshader', '.gdshaderinc'}
    }
    missing = sorted(p for p in paths if not (ROOT / p).is_file())
    if missing:
        parser.error('Missing runtime export seed: ' + ', '.join(missing))
    config = ROOT / 'export_presets.cfg'
    original = config.read_text()
    files_line = 'export_files=PackedStringArray(' + ', '.join('"res://' + p + '"' for p in sorted(paths)) + ')'
    updated, filters = re.subn(r'^export_filter="[^"]*"$', 'export_filter="resources"', original, count=1, flags=re.M)
    updated, includes = re.subn(r'^include_filter="[^"]*"$', 'include_filter="localization/*.json,data/environment/*.json,assets/data/jovian117/*.json,assets/data/satellites273/*.json,assets/data/satellites273/*.bin,assets/data/satellites275/*.json,assets/data/satellites275/*.bin,assets/data/solar_de440_179/*.bin,assets/data/solar_de440_179/manifest.json,assets/data/ground_sky262/*.json,assets/licenses/*.txt"', updated, count=1, flags=re.M)
    updated, lists = re.subn(r'^export_files=PackedStringArray\(.*\)$', files_line, updated, count=1, flags=re.M)
    if filters != 1 or lists != 1 or includes != 1:
        parser.error('Expected preset.0 export_filter, export_files and include_filter')
    if args.check and updated != original:
        parser.exit(1, 'Runtime export inputs are stale; run python3 tools/sync_export_resources.py\n')
    if not args.check and updated != original:
        config.write_text(updated)
    print(f'Runtime export inputs: {len(paths)} explicit resources; scene import dependencies handled by Godot')


if __name__ == '__main__':
    main()
