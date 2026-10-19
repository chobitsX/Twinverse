extends RefCounted
## Versioned scientific/authoring data. Every numeric input has units and provenance.
## No species-calibrated physiological parameters are claimed by this definition.

const ID: String = "reef-oxygen-reference-v1"
const TARGET_SPECIES: String = "Amphiprion percula"
const STATUS: String = "reference_model_species_uncalibrated"
const SOURCES: Array[Dictionary] = [
	{"id": "nilsson2004", "title": "Nilsson & Östlund-Nilsson · 2004",
		"url": "https://doi.org/10.1098/rsbl.2003.0087",
		"basis": "蜥蜴岛多种礁鱼的临界氧与摄氧调节研究；未包含目标鱼的专属标定。"},
	{"id": "hess2017", "title": "Hess et al. · 2017",
		"url": "https://doi.org/10.1098/rspb.2017.1279",
		"basis": "包含A. percula幼鱼的悬沙/耗氧实验；不能据此推出80 mm个体的低氧阈值。"},
]
const PARAMETERS: Dictionary = {
	"reference_temperature": {"value": 30.0, "unit": "degC", "origin": "reference_condition", "source": "nilsson2004"},
	"critical_oxygen": {"value": 25.0, "unit": "percent_air_saturation", "origin": "author_assumption", "source": "nilsson2004"},
	"sensitivity_low": {"value": 20.0, "unit": "percent_air_saturation", "origin": "author_sensitivity_case", "source": "nilsson2004"},
	"sensitivity_high": {"value": 30.0, "unit": "percent_air_saturation", "origin": "author_sensitivity_case", "source": "nilsson2004"},
	"scenario_period": {"value": 300.0, "unit": "world_seconds", "origin": "author_scenario", "source": ""},
	"sample_interval": {"value": 5.0, "unit": "world_seconds", "origin": "observation_sampling", "source": ""},
}
# Piecewise linear imposed water boundary: world seconds, % air saturation.
# This is a teaching scenario, not a measured local diel cycle or a forecast.
const BOUNDARY: Array[Vector2] = [Vector2(0, 100), Vector2(30, 100), Vector2(120, 15),
	Vector2(180, 15), Vector2(270, 100), Vector2(300, 100)]


static func value(key: String) -> float:
	return float(PARAMETERS[key].value)
