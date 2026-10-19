extends RefCounted
## Beam projection geometry only; no weather, irradiance input or electricity model.
## NREL PVWatts v5 manual, section 7: beam POA = DNI * cos(AOI).
const SOURCE: String = "https://pvwatts.nlr.gov/downloads/pvwattsv5.pdf"

static func sample(sun_direction: Vector3, surface_normal: Vector3) -> Dictionary:
	if not sun_direction.is_finite() or not surface_normal.is_finite() or sun_direction.length_squared()<1e-12 or surface_normal.length_squared()<1e-12:
		return {"valid":false,"angle_deg":0.0,"factor":0.0,"above_horizon":false}
	var sun: Vector3 = sun_direction.normalized()
	var normal: Vector3 = surface_normal.normalized()
	var cosine: float = clampf(sun.dot(normal),-1,1)
	return {"valid":true,"angle_deg":rad_to_deg(acos(cosine)),"factor":maxf(0,cosine) if sun.y>0 else 0.0,"above_horizon":sun.y>0}
