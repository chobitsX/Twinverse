extends RefCounted
## Same-date geometric distance / c. No retarded positions or simulation state.
const Ephemeris = preload("res://scripts/core/solar_ephemeris.gd")
const C_KM_S: float = 299792.458
const C_SOURCE: String = "https://www.bipm.org/en/si-base-units/metre"
const AU_SOURCE: String = "https://iauarchive.eso.org/public/themes/measuring/"
const CORRECTION_SOURCE: String = "https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/req/abcorr.html"


static func seconds(distance_au: float) -> float:
	if not is_finite(distance_au) or distance_au < 0.0: return INF
	var value: float = distance_au * Ephemeris.AU_KM / C_KM_S
	return value if is_finite(value) else INF


static func row(distance_au: float, distance_source: String) -> Dictionary:
	var value: float = seconds(distance_au)
	if not is_finite(value) or distance_source not in ["de440", "approximate"]:
		return {"seconds": INF, "minutes": INF, "text": "—", "source": "unavailable"}
	return {"seconds": value, "minutes": value / 60.0,
		"text": ("%.2f" % (value / 60.0)) + ("*" if distance_source == "approximate" else ""),
		"source": distance_source + "-geometric"}
