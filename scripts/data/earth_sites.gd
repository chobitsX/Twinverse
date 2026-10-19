extends RefCounted
## Regional context and authored lighting references have deliberately different meanings.
const REEF_LAT: float = -14.6666666667
const REEF_LON: float = 145.4666666667
const SITES: Array[Dictionary] = [
	{"scale":"arctic","label":"北极 · 北冰洋海冰合成参考","lat":78.0,"lon":0.0,"kind":"lighting","description":"北冰洋积雪、海冰、冰脊与开阔水面的合成观察点。78°N/0°仅用于太阳和星位；不是实测海冰范围、当日天气或极光预报，没有南极企鹅。"},
	{"scale":"night_sky","label":"观星 · 阿塔卡马高原","lat":-24.6272,"lon":-70.4044,"kind":"astronomy","description":"Paranal附近的参考经纬度与2635米海拔用于观星方向；山脊、平台与望远镜为合成场景。天空读取同一天文日期，不是实地天气、肉眼曝光或精密观测预报。"},
	{"scale":"reef","label":"海洋 · 蜥蜴岛区域","lat":REEF_LAT,"lon":REEF_LON,"kind":"regional","description":"大堡礁蜥蜴岛周边的区域资料锚点。礁区摆放与鱼的位置为教学场景，不是个体实测位置。"},
	{"scale":"woodland","label":"林地 · 合成生态示意","lat":35.0,"lon":-75.0,"kind":"lighting","description":"合成林地，无真实场景地址。35°N / 75°W仅用于太阳光照推演；地球上显示参考纬度带。"},
	{"scale":"city","label":"城市 · 合成街区","lat":35.0,"lon":120.0,"kind":"lighting","description":"合成街区，无真实城市地址。35°N / 120°E仅用于太阳光照推演；地球上显示参考纬度带。"},
	{"scale":"desert","label":"荒漠 · 索诺兰参考生境","lat":32.0,"lon":-112.0,"kind":"lighting","description":"索诺兰低地灌丛参考的合成生境。32°N / 112°W仅用于光照，非国家公园测绘或植物定位；地球上显示参考纬度带。"},
	{"scale":"polar","label":"极地 · 南极海岸合成参考","lat":-66.5,"lon":0.0,"kind":"lighting","description":"南极海岸裸岩、海水、海冰与阿德利企鹅的合成教学剖面。66.5°S仅用于太阳光照；没有实测场景地址、当日海冰范围或企鹅位置。"}]

static func latitude_label(latitude: float) -> String:
	return "%.1f°%s" % [absf(latitude), "S" if latitude < 0.0 else "N"]

static func for_scale(id: String) -> Dictionary:
	for site: Dictionary in SITES:
		if site.scale==id: return site
	return {}

static func normal(latitude: float, longitude: float) -> Vector3:
	var lat: float = deg_to_rad(latitude)
	var lon: float = deg_to_rad(longitude)
	return Vector3(cos(lat)*sin(lon),sin(lat),cos(lat)*cos(lon))
