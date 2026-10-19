extends RefCounted
## Navigation context, not a claim of causal coupling or simulated scale extent.

const GOLDEN_PATH: Array[String] = [
	"galaxy", "solar_system", "earth", "pacific", "reef", "school", "fish",
	"heart", "cardiomyocyte", "mitochondrion", "molecule", "atom",
]
const EXPLORATION_PATH: Array[String] = [
	"universe", "galaxy", "solar_system", "earth", "atmosphere", "pacific", "reef", "school", "fish",
	"heart", "cardiomyocyte", "mitochondrion", "molecule", "atom",
]
const SCALES: Dictionary = {
	"night_sky": {"label":"地面观星", "extent_m":1.0e4, "kind":"geometric_ground_observer", "anchor":"earth"},
	"universe": {"label":"宇宙结构", "extent_m":1.0e25, "kind":"cosmic_expansion_illustration", "anchor":"galaxy"},
	"mars_moons": {"label":"火星与卫星", "extent_m":6.0e7, "kind":"frozen_geometric_ephemeris", "anchor":"solar_system"},
	"jupiter_moons": {"label":"木星与卫星", "extent_m":6.0e10, "kind":"frozen_geometric_ephemeris", "anchor":"solar_system"},
	"saturn_moons": {"label":"土星与卫星", "extent_m":6.0e10, "kind":"frozen_geometric_ephemeris", "anchor":"solar_system"},
	"uranus_moons": {"label":"天王星与卫星", "extent_m":6.0e10, "kind":"frozen_geometric_ephemeris", "anchor":"solar_system"},
	"neptune_moons": {"label":"海王星与卫星", "extent_m":1.0e11, "kind":"frozen_geometric_ephemeris", "anchor":"solar_system"},
	"desert": {"label":"陆地 · 索诺兰荒漠", "extent_m":280.0, "kind":"educational_habitat", "anchor":"earth"},
	"polar": {"label":"陆地 · 南极海岸", "extent_m":180.0, "kind":"educational_habitat", "anchor":"earth"},
	"arctic": {"label":"北极 · 海冰与夜空", "extent_m":800.0, "kind":"educational_habitat", "anchor":"earth"},
	"earth_moon": {"label":"地月 · 昼夜与季节", "extent_m":8.0e8, "kind":"mean_orbit_observatory", "anchor":"earth"},
	"woodland": {"label":"陆地 · 林地与水边", "extent_m":150.0, "kind":"educational_habitat", "anchor":"earth"},
	"city": {"label":"城市与人类", "extent_m":240.0, "kind":"synthetic_city", "anchor":"earth"},
	"galaxy": {"label": "银河系", "extent_m": 1.0e21, "kind": "visual_context", "anchor": "solar_system"},
	"solar_system": {"label": "太阳系", "extent_m": 1.0e13, "kind": "approximate_ephemeris", "anchor": "earth"},
	"earth": {"label": "地球", "extent_m": 1.3e7, "kind": "visual_context", "anchor": "pacific_reef"},
	"atmosphere": {"label": "地球大气", "extent_m": 1.0e5, "kind": "visual_context", "anchor": "pacific_reef"},
	"pacific": {"label": "太平洋 · 海面", "extent_m": 1.0e4, "kind": "visual_context", "anchor": "reef_patch"},
	"reef": {"label": "珊瑚礁", "extent_m": 30.0, "kind": "reference_model", "anchor": "target_school"},
	"school": {"label": "鱼群", "extent_m": 3.0, "kind": "reference_model", "anchor": "target_fish"},
	"fish": {"label": "目标鱼", "extent_m": 0.15, "kind": "reference_model", "anchor": "target_fish_heart"},
	"heart": {"label": "心脏", "extent_m": 0.004, "kind": "reference_model", "anchor": "cardiomyocyte"},
	"cardiomyocyte": {"label": "心肌细胞", "extent_m": 0.0001, "kind": "reference_model", "anchor": "mitochondrion"},
	"mitochondrion": {"label": "线粒体", "extent_m": 0.000002, "kind": "reference_model", "anchor": "metabolic_molecule"},
	"molecule": {"label": "氧分子 · O₂", "extent_m": 2.0e-9, "kind": "scientific_illustration", "anchor": "representative_atom"},
	"atom": {"label": "原子 · 结构解释", "extent_m": 1.0e-10, "kind": "scientific_illustration", "anchor": "representative_atom"},
}


static func contains(scale_id: String) -> bool:
	return SCALES.has(scale_id)


static func describe(scale_id: String) -> Dictionary:
	return SCALES.get(scale_id, {}).duplicate(true)


static func neighbors(scale_id: String) -> Array[String]:
	if scale_id in ["mars_moons","jupiter_moons","saturn_moons","uranus_moons","neptune_moons"]: return ["solar_system"]
	if scale_id in ["woodland","city","desert","polar","arctic","earth_moon","night_sky"]: return ["earth"]
	var result: Array[String] = []
	if scale_id=="solar_system": result.append_array(["mars_moons","jupiter_moons","saturn_moons","uranus_moons","neptune_moons"])
	if scale_id=="earth": result.append_array(["woodland","city","desert","polar","arctic","earth_moon","night_sky"])
	var index: int = EXPLORATION_PATH.find(scale_id)
	if index > 0:
		result.append(EXPLORATION_PATH[index - 1])
	if index >= 0 and index + 1 < EXPLORATION_PATH.size():
		result.append(EXPLORATION_PATH[index + 1])
	return result


static func breadcrumb(scale_id: String) -> Array[String]:
	if scale_id in ["mars_moons","jupiter_moons","saturn_moons","uranus_moons","neptune_moons"]: return ["universe","galaxy","solar_system",scale_id]
	if scale_id in ["woodland","city","desert","polar","arctic","earth_moon","night_sky"]: return ["universe","galaxy","solar_system","earth",scale_id]
	var index: int = EXPLORATION_PATH.find(scale_id)
	if index < 0:
		return []
	return EXPLORATION_PATH.slice(0, index + 1)

static func relative(scale_id: String, direction: int) -> String:
	if scale_id in ["mars_moons","jupiter_moons","saturn_moons","uranus_moons","neptune_moons"]: return "solar_system" if direction<0 else ""
	if scale_id in ["woodland","city","desert","polar","arctic","earth_moon","night_sky"]: return "earth" if direction<0 else ""
	var index: int = EXPLORATION_PATH.find(scale_id)+direction
	return EXPLORATION_PATH[index] if index>=0 and index<EXPLORATION_PATH.size() else ""
