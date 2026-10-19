extends RefCounted
## Geometric topocentric directions using the existing common TDB date.
## Fixed FK5/J2000 stars; no EOP, UTC conversion, refraction or light-time.
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
const Seasons = preload("res://scripts/experience/season_observation.gd")
const PARANAL: Dictionary = {"name":"阿塔卡马高原", "lat":-24.6272, "lon":-70.4044, "alt_m":2635.0}
const SITES: Array[Dictionary] = [PARANAL, {"name":"北方观星点", "lat":35.0, "lon":120.0, "alt_m":0.0}, {"name":"南极观星点", "lat":-66.5, "lon":0.0, "alt_m":0.0}]
# ERFA/SOFA ICRS -> Galactic rotation. Basis constructor takes columns.
const EQUATORIAL_TO_GALACTIC: Basis = Basis(Vector3(-.0548755604162154,.4941094278755837,-.8676661490190047),Vector3(-.8734370902348850,-.4448296299600112,-.1980763734312015),Vector3(-.4838350155487132,.7469822444972189,.4559837761750669))

static func tangent(latitude: float, longitude: float) -> Basis:
	var lat: float=deg_to_rad(latitude)
	var lon: float=deg_to_rad(longitude)
	return Basis(Vector3(cos(lon),0,-sin(lon)),Vector3(cos(lat)*sin(lon),sin(lat),cos(lat)*cos(lon)),Vector3(sin(lat)*sin(lon),-cos(lat),sin(lat)*cos(lon)))

static func inertial_to_local(jd: float, site: Dictionary = PARANAL) -> Basis:
	return tangent(float(site.lat),float(site.lon)).transposed()*Orientation.body_basis(2,jd).transposed()

static func observer_world_km(jd: float, site: Dictionary = PARANAL) -> Vector3:
	return Orientation.body_basis(2,jd)*tangent(float(site.lat),float(site.lon)).y*(Orbit.RADII_KM[2]+float(site.alt_m)/1000.0)

static func star_direction(ra_deg: float, dec_deg: float) -> Vector3:
	var ra: float=deg_to_rad(ra_deg)
	var dec: float=deg_to_rad(dec_deg)
	return Orientation.equatorial_to_world(Vector3(cos(dec)*cos(ra),cos(dec)*sin(ra),sin(dec)))

static func local_from_galactic(jd: float, site: Dictionary = PARANAL) -> Basis:
	var eq_world: Basis=Basis(Orientation.equatorial_to_world(Vector3.RIGHT),Orientation.equatorial_to_world(Vector3.UP),Orientation.equatorial_to_world(Vector3.BACK))
	return inertial_to_local(jd,site)*eq_world*EQUATORIAL_TO_GALACTIC.transposed()

static func body(jd: float, index: int, site: Dictionary = PARANAL) -> Dictionary:
	var vector: Vector3
	var radius: float
	var label: String
	if index==8:
		vector=Orientation.moon_position_km(jd)
		radius=Orientation.MOON_RADIUS_KM
		label="月球"
	else:
		var earth: Vector3=Orbit.position_au(2,jd)
		var au: Vector3=-earth if index==9 else Orbit.position_au(index,jd)-earth
		vector=Vector3(au.x,au.z,-au.y)*Orbit.AU_KM
		radius=695700.0 if index==9 else Orbit.RADII_KM[index]
		label="太阳" if index==9 else Orbit.NAMES[index]
	vector-=observer_world_km(jd,site)
	var distance: float=vector.length()
	var direction: Vector3=inertial_to_local(jd,site)*vector.normalized()
	return {"label":label,"direction":direction,"distance_km":distance,"angular_radius":asin(clampf(radius/distance,0.,1.)),"altitude":rad_to_deg(asin(clampf(direction.y,-1.,1.))),"azimuth":fposmod(rad_to_deg(atan2(direction.x,-direction.z)),360.0)}

static func night_date(jd: float, site: Dictionary = PARANAL) -> float:
	# Explicit observer preset, not a new clock or an unannounced daily loop.
	var candidate: float=Seasons.noon(jd,float(site.lon))+.375
	return clampf(candidate,Orbit.START_JD,Orbit.END_JD)
