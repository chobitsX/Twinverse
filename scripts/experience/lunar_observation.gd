extends RefCounted
const Phase = preload("res://scripts/core/lunar_phase.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Eclipse = preload("res://scripts/core/eclipse_geometry.gd")

static func readout(host: Node) -> String:
	var view: String = "地球上的月影" if host.lunar_observation_view=="shadow" else "沿地球方向近看" if host.lunar_observation_view=="earth" else "轨道全景" if host.lunar_observation_view=="orbit" else "自由环绕"
	var libration: Vector2=Orientation.lunar_libration(host.solar_jd)
	var state: Dictionary=Eclipse.sample(host.solar_jd)
	var time: String=Time.get_time_string_from_unix_time(int(round((host.solar_jd-2440587.5)*86400.0)))
	return "%s %s TDB · %s\n月相几何受光约 %.0f%% · 月心直射日光 %.0f%%\n月距 %.0f km · %s\n月面经/纬度 %+.1f° / %+.1f° · %s" % [Eclipse.Orbit.date_label(host.solar_jd).trim_suffix(" TDB"),time,Phase.phase_name(host.solar_jd),Orientation.illumination(host.solar_jd)*100.0,float(state.moon_center_visibility)*100.0,Orientation.moon_position_km(host.solar_jd).length(),"月距真实" if host.solar_true_distance else "月距压缩，影子仍按真实距离",libration.x,libration.y,view]

static func marks(host: Node) -> Array[Dictionary]:
	var stage: Node = host.coordinator.active_scene
	var data: Dictionary = stage.get_meta("lunar")
	var moon: Node3D = data.moon
	var near: Vector3 = moon.position+moon.basis.z*.274
	if host.lunar_observation_view=="shadow":
		return [{"at":Eclipse.solar_axis_surface(stage.get_meta("eclipse_geometry"))/Eclipse.Orbit.RADII_KM[2],"label":"地球上的月影 · 几何近似","offset":Vector2(35,-50)}]
	if host.lunar_observation_view=="earth":
		return [{"at":near,"label":"同一月面参考点 · 天平动偏移","offset":Vector2(-160,150)}]
	var scale: float = 7.5 if host.solar_true_distance else 1.0
	return [{"at":Vector3.ZERO,"label":"地球","offset":Vector2(-70,45)},
		{"at":near,"label":"月球 · 同步自转与天平动","offset":Vector2(20,-65),"link":0},
		{"at":Orientation.sun_direction(host.solar_jd)*9.5*scale,"label":"朝太阳 · 只表示方向","offset":Vector2(-90,-65),"link":0}]
