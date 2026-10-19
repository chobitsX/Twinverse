extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const Galactic = preload("res://scripts/experience/galactic_observation.gd")
const Satellites = preload("res://scripts/core/natural_satellites.gd")
const Oxygen = preload("res://scripts/core/oxygen_atom.gd")
const SolarSizes = preload("res://scripts/experience/solar_size_comparison.gd")
const SolarEphemeris = preload("res://scripts/core/solar_ephemeris.gd")
const LightTravel = preload("res://scripts/core/solar_light_travel.gd")
const Iguana = preload("res://scripts/experience/iguana_observation.gd")
const Desert = preload("res://scripts/experience/desert_builder.gd")
const KangarooRat = preload("res://scripts/experience/kangaroo_rat_observation.gd")
const School = preload("res://scripts/core/schooling.gd")
const Deadwood = preload("res://scripts/core/deadwood_decomposition.gd")
const Fungi = preload("res://scripts/experience/fungus_observation.gd")
const Frogs = preload("res://scripts/experience/frog_observation.gd")
const RiverWetland = preload("res://scripts/experience/river_wetland_observation.gd")
const FreshwaterFish = preload("res://scripts/experience/freshwater_fish_observation.gd")
const WildCelery = preload("res://scripts/experience/wild_celery_observation.gd")
const BandedKillifish = preload("res://scripts/experience/banded_killifish_observation.gd")
## Presentation of already frozen project sources, not a new scientific model.
const Browse = preload("res://scripts/core/woodland_browse.gd")
const RedFox = preload("res://scripts/experience/red_fox.gd")
const Pollinators = preload("res://scripts/experience/pollinator_observation.gd")
const Marine = preload("res://scripts/experience/biodiversity.gd")
const Deer = preload("res://scripts/experience/deer_skin_motion.gd")
const Runoff = preload("res://scripts/experience/runoff_observation.gd")
const CitySparrow = preload("res://scripts/experience/city_sparrow.gd")
const CityPondMallard = preload("res://scripts/experience/city_pond_mallard.gd")
const CityGinkgo = preload("res://scripts/experience/city_ginkgo.gd")
const CityParkTrees = preload("res://scripts/experience/city_park_trees.gd")
const Seagrass = preload("res://scripts/experience/seagrass_observation.gd")
const Coral = preload("res://scripts/experience/coral_observation.gd")
const Urchin = preload("res://scripts/experience/urchin_observation.gd")
const Clam = preload("res://scripts/experience/giant_clam_observation.gd")
const BlackSeaCucumber = preload("res://scripts/experience/black_sea_cucumber_observation.gd")
const Octopus = preload("res://scripts/experience/day_octopus.gd")
const Model = preload("res://scripts/core/ecophysiology.gd")
const Solar = preload("res://scripts/core/solar_incidence.gd")
const Polar = preload("res://scripts/experience/polar_builder.gd")
const Krill = preload("res://scripts/experience/polar_krill.gd")
const BODY_SOURCE: String = "https://onlinelibrary.wiley.com/doi/10.1002/ar.1111"
const ATOM_SOURCE: String = "https://ocw.mit.edu/courses/8-04-quantum-physics-i-spring-2016/e34ceed6a6ec944a3c761fcbbf48be5f_MIT8_04S16_LecNotes22.pdf"

static func describe(id: String) -> Dictionary:
	return I18n.dictionary(_describe_source(id))

static func _describe_source(id: String) -> Dictionary:
	var data: Dictionary = {"kind":I18n.text("科学示意"), "basis":I18n.text("作者化结构与观察表达。"), "limit":I18n.text("不能当作实测重建或预测结果。"), "sources":[]}
	if Satellites.is_system(id):
		var parent: String = Satellites.host_for_scale(id)
		data.kind=I18n.text("行星中心几何星历与完整卫星名录")
		data.basis=I18n.text("%s的%d颗卫星列入2026-10-13冻结的JPL/IAU发现名录；有公开星历的卫星使用Horizons几何位置/速度双精度离线缓存和Hermite插值，2026-09-01—12-01 TDB。全部读取同一个世界日期/倍率；平均轨道参数仅描述形状，不用来推算位置。已知朝向采用NAIF pck00011，木星四大卫星沿用USGS拼图及理想同步姿态。") % [Satellites.name(parent),Satellites.count(parent)]
		data.limit=I18n.text("宿主与已知卫星平均半径、距离始终同比，不默认放大卫星实体。小卫星识别点标不代表半径；中性球不是实测形状或表面。半径/自转/轨道缺测均留空，土卫七未强设简单同步自转。线条仅为有效缓存内采样弧；范围外不外推，也不独立积分动力学、不预报掩食。数量会随新发现变化。完整八行星名录456，冥王星5另列，不声称覆盖太阳系全部矮行星/小天体的卫星。")
		data.sources=[[I18n.text("JPL · IAU认可发现名录"),"https://ssd.jpl.nasa.gov/sats/discovery.html"],[I18n.text("JPL · Horizons星历"),"https://ssd.jpl.nasa.gov/horizons/"],[I18n.text("JPL · 卫星物理参数"),"https://ssd.jpl.nasa.gov/sats/phys_par/"],[I18n.text("NAIF · 参考朝向"),"https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/"]]
		return data
	match id:
		"night_sky":
			data.kind=I18n.text("地面观星 · 日期与几何方向")
			data.basis=I18n.text("Paranal附近参考地点：24.6272°S、70.4044°W、2635米。NASA HEASARC BSC5P明亮星表选取星等≤6.5的8404颗恒星，使用固定J2000星位；地球IAU姿态把它们转至当地东/天顶/南坐标。太阳、行星沿用DE440地月质心几何位置，月球沿用ERFA/Meeus与IAU姿态，扣除球面地面观察者位置。银河为ESA Gaia EDR3银道坐标全天图；随同一日期转动。")
			data.limit=I18n.text("山脊、平台、望远镜为合成场景；银河曝光、星光光晕和夜间地面补光增强，非肉眼亮度。太阳/月球保留实际角直径，行星为放大光点。未计恒星自行、FK5/ICRS微小差别、地球实时定向、UTC转换、光行时、折射、椭球地形、天气或光害；不是精密地面观测预报。自动初次进入会明确切至本日约21时的地方太阳时参考夜空；手动日期和保存日期保持。下方为TDB日期。")
			data.sources=[[I18n.text("NASA HEASARC · 明亮星表"),"https://heasarc.gsfc.nasa.gov/W3Browse/star-catalog/bsc5p.html"],[I18n.text("ESA Gaia EDR3 · 全天银道图"),"https://sci.esa.int/web/gaia/-/the-colour-of-the-sky-from-gaia-s-early-data-release-3-equirectangular-projection"],[I18n.text("ESO · Paranal观测地点"),"https://www.hq.eso.org/sci/facilities/paranal/astroclimate/site.html"],[I18n.text("ERFA · 赤道与银道坐标"),"https://github.com/liberfa/erfa/blob/master/src/icrs2g.c"],[I18n.text("Gaia图像许可 · CC BY-SA 3.0 IGO"),"https://creativecommons.org/licenses/by-sa/3.0/igo/"]]
		"universe":
			data.kind = I18n.text("宇宙结构与膨胀示意")
			data.basis = I18n.text("星系、星系团常沿丝状结构分布，形成宇宙网。每次进入播放相对间距增加的教学演示；星系内部尺寸不随膨胀增加。")
			data.limit = I18n.text("原创结构示意，没有实测星系位置、真实年代或数值宇宙模拟。银河仅作为观察参考，不代表宇宙中心；丝状结构的颜色和亮度是显示增强，并非肉眼所见。")
			data.sources = [[I18n.text("NASA · 宇宙大型结构"),"https://science.nasa.gov/universe/galaxies/large-scale-structures/"],[I18n.text("NASA · 宇宙膨胀"),"https://science.nasa.gov/mission/hubble/science/science-behind-the-discoveries/hubble-constant-and-tension/"]]
		"galaxy":
			data.kind = I18n.text("空间结构示意")
			data.basis = I18n.text("NASA科普参考：太阳距银心约2.6万光年、星盘参考直径约10万光年；距离线与实际太阳系入口一致。")
			data.sources = [[I18n.text("NASA · 太阳绕银心约2.3亿年"),"https://science.nasa.gov/solar-system/solar-system-facts/"],[I18n.text("NASA · 太阳系与银河位置"),Galactic.SOURCE],[I18n.text("NASA · 银河尺度"),Galactic.SIZE_SOURCE]]
			data.limit = I18n.text("未加载实测恒星目录；旋臂、星点、方位、厚度与亮度为作者示意，太阳标记放大。参考盘径不是硬边界，采用理想化恒星差速转动与旋臂图案转动，速度大幅压缩，非实测银河动力学或实际外观照片。")
		"solar_system":
			data.kind = I18n.text("DE440离线位置/日期轨迹与近似轨道教学")
			data.basis = I18n.text(SolarEphemeris.position_source()) + I18n.text("：1800–2050 TDB，日心J2000黄道坐标。青实线是选中行星在当前日期附近一名义周期的DE440等时间采样折线；橙虚线和十二等时点另用JPL Table 1冻结近似椭圆。自转取自NAIF姿态系数。水星为MESSENGER灰度历史拼图，火星为NASA Ames / USGS着色Viking MDIM2.1。")
			data.basis += I18n.text(" 同日期表按日心几何距离÷真空光速显示单程分钟：c=299792.458 km/s，AU沿用IAU固定149597870.7 km。1 AU光程约8分19秒；数值与显示距离压缩无关。")
			data.basis += I18n.text(" 太阳、八行星与月球的朝向/位置共用同一观察日期和倍率；木星参考自转约9.925小时、土星约10.656小时，采用IAU/NAIF参考系而非所有纬度云带的固体转速。月球使用ERFA Moon98位置级数与IAU_MOON周期姿态，平均自转和绕地球恒星周期约27.32天，月相周期约29.53天。")
			data.limit = I18n.text("地球点为地月质心，其余外行星亦为行星系统质心；青线是有界日期折线，不是闭合解析轨道或独立动力学积分，橙线仍可能与球体偏离。默认轨道分别缩放；真实距离模式中的天体仍各自放大，不能由轨道画面比较天体大小。同比例大小对照使用JPL平均半径与IAU太阳名义半径，球体间距仅作排布。不用于精密事件、导航或碰撞判断。表面拼图不是实时观测或真实颜色测量；水星极区拼接痕迹保留，火星含原始影像光照，不提供三维地形。")
			data.limit += I18n.text(" 单程光时仅取同日期太阳中心到对应质心的距离÷c；未解传播中天体移动、引力延迟或地面视位置，不是太阳表面到地面实际到达、往返通信或飞船用时。")
			data.limit += I18n.text(" 快进时只对无法逐帧分辨的纹理做有限经向滤波，实际IAU姿态没有减速；该显示滤波不是精确曝光积分。全景为距离压缩、大小放大的示意；近景宿主与卫星距离、平均半径同比。近景1995—2050补正行星系统质心到本体中心，地球从EMB补正到地心；远方天体按真实几何方向和视大小投影，识别点不代表实体大小。超出本体中心偏移覆盖时保留系统质心近似，不冒称精密本体位置。月球原有近似/1950年前精度与非精密事件边界保持；全景未新增地月食阴影，使用地月观察台查看。")
			data.limit += I18n.text(" 全景与近景只调整镜头、显示曝光和材质层次，不改变星历位置、IAU自转或统一时间倍率；太阳光球纹理、日冕、土星环带细节和背景星点为作者视觉，非当日观测或太阳活动预报。水星浏览图边框的接缝作显示处理，原分辨率和观测覆盖不变。")
			data.sources = [[I18n.text("JPL · DE440行星星历"),"https://ssd.jpl.nasa.gov/planets/eph_export.html"],[I18n.text("NAIF · 官方DE440 SPK"),"https://naif.jpl.nasa.gov/pub/naif/pds/wgc/kernels/spk/de440.bsp"],[I18n.text("USGS · 水星历史表面"),"https://astrogeology.usgs.gov/search/map/mercury_messenger_mdis_global_mosaic_250m"],[I18n.text("USGS / NASA Ames · 火星着色表面"),"https://astrogeology.usgs.gov/search/map/mars_viking_colorized_global_mosaic_232m"],[I18n.text("JPL · 近似轨道要素"),"https://ssd.jpl.nasa.gov/planets/approx_pos.html"],[I18n.text("JPL · 物理参数"),"https://ssd.jpl.nasa.gov/planets/phys_par.html"],[I18n.text("IAU · 太阳名义半径"),SolarSizes.SUN_SOURCE],[I18n.text("NAIF · 姿态系数"),"https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc"]]
			data.sources += [[I18n.text("BIPM · 真空光速"),LightTravel.C_SOURCE],[I18n.text("IAU · AU定义"),LightTravel.AU_SOURCE],[I18n.text("NAIF · 几何与校正光时"),LightTravel.CORRECTION_SOURCE]]
			data.sources += [[I18n.text("NASA · 木星公转与自转"),"https://science.nasa.gov/jupiter/facts/"],[I18n.text("NASA · 土星公转与自转"),"https://science.nasa.gov/saturn/facts/"],[I18n.text("NASA · 月球周期"),"https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html"],[I18n.text("ERFA · Moon98位置算法"),"https://github.com/liberfa/erfa/blob/v2.0.1/src/moon98.c"]]
		"earth", "atmosphere":
			data.kind = I18n.text("历史影像与光照示意")
			data.basis = I18n.text("NASA地表为2004年1月合成；云层为2002年发布的MODIS多日合成。日期控制只改变天文观察。")
			data.limit = I18n.text("影像日期不同，不能读取当前天气；大气散射和云体是显示模型。")
			data.sources = [[I18n.text("NASA · Blue Marble地表"),"https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-map/"],[I18n.text("NASA · 云层合成背景"),"https://science.nasa.gov/earth/earth-observatory/the-blue-marble-2181/"]]
		"jupiter_moons":
			data.kind=I18n.text("离线几何星历与历史拼图")
			data.basis=I18n.text("四颗伽利略卫星采用JPL Horizons相对木星中心的几何位置/速度，每小时缓存与Hermite插值；尺寸取JPL平均半径，木星自转沿用IAU模型。")
			data.limit=I18n.text("仅2026-09-01—12-01 TDB；宿主、卫星距离与平均半径同比。不是地球视角的光行时位置或掩食预报。历史地图有分辨率差异，Io彩色融合，其余为灰度；理想同步朝向忽略天平动与实测极向。")
			data.sources=[["JPL Horizons","https://ssd.jpl.nasa.gov/horizons/"],[I18n.text("JPL平均半径"),"https://ssd.jpl.nasa.gov/sats/phys_par/"],[I18n.text("USGS全球拼图"),"https://astrogeology.usgs.gov/search/map/jupiter-voyager-and-galileo-global-mosaics"]]
		"earth_moon":
			data.kind = I18n.text("月轨道摄动近似与周期姿态")
			data.basis = I18n.text("ERFA Moon98位置级数与NAIF IAU_MOON周期朝向；地球保留IAU姿态。月面采用NASA 2025显示颜色图。")
			data.limit = I18n.text("默认距离与平均半径同比，轨迹取日期前后约14天；可见天平动，但不是高精度DE月面姿态。地月场景已按物理距离计算直射光遮挡，采用均匀太阳圆盘，无大气折射红月/临边昏暗或实时地球定向。太阳为地月质心近似；不能作精确日月食路径或接触时刻预报。1950年前不沿用原算法公布的区间精度，少量JPL抽样不保证整个日期区间；月相按钮不是实际事件预报。")
			data.sources = [[I18n.text("ERFA · Moon98位置算法"),"https://github.com/liberfa/erfa/blob/v2.0.1/src/moon98.c"],[I18n.text("NAIF · 姿态系数"),"https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc"],["NASA · CGI Moon Kit","https://svs.gsfc.nasa.gov/4720/"],[I18n.text("NASA · 月相与同步旋转"),"https://science.nasa.gov/moon/moon-phases/"],[I18n.text("NASA · 日月食几何"),"https://science.nasa.gov/eclipses/geometry/"]]
		"woodland":
			data.kind = I18n.text("物种参考与合成生境")
			data.basis = I18n.text("白尾鹿、赤狐、美洲知更鸟、帝王蝶、北美白橡、东部白松、普通乳草、美洲牛蛙、宽叶香蒲、绿纹蜻蜓、金色鲦、斑纹鳉、美洲苦草和东部箱龟为十四种具名动植物参考，另有真菌云芝，共十五种。云芝附于枯木，可见子实体与木内菌丝的分工不同。原叶背毫米卵、晚龄幼虫、悬挂蛹与成蝶是四个独立参考，按钮切换不推进发育；成虫吸花蜜、幼虫吃乳草叶。牛蛙为成年雄性，鼓膜、黄色喉部与趾蹼有形态资料；河岸香蒲的宽叶和上下花穗、绿纹蜻蜓成虫的四翅与绿胸蓝腹也可近看。较深水层的金色鲦有深体形、橄榄背、银金侧面和上翘小口；斑纹鳉在植被边缘近水面，细长鱼体和体侧横纹可近看；美洲苦草的基生莲座、带状叶和走茎在同一河床可近看；其余背景植被未鉴种。")
			data.limit = I18n.text("赤狐的一个个体、尺寸、红褐型毛色、40秒缓行/停步和头尾活动是作者设置，未模拟捕猎、气味/听觉或把现有鹿/鸟指定为猎物；35°N、75°W仅教学光照，非实测生态。地形、数量和活动是作者设置；夏毛与花期固定。牛蛙主要夜间活动，当前光照用于观察；喉部微动不代表实测呼吸或鸣叫。九株香蒲、一只蜻蜓、八尾金色鲦、六尾斑纹鳉、二十处美洲苦草叶丛及18/32/22秒短程路线为作者设置；未模拟蜻蜓水中幼体、捕食或真实飞行，香蒲未模拟授粉和种子扩散；水下视角不代表实测能见度、密度、水流、鱼类摄食或鳃部摄氧，两种鱼同场也不证明鱼—草栖息地因果、竞争或捕食；苦草轻微摆动不代表流速或生长。成对叶量样方模拟未标定的取食与恢复；另有枯木水分/供氧预设对照，以100相对碳单位区分木材、有机留存和呼吸释放，不是实测年数或云芝速率。其余未模拟植物消耗、传粉、物候、真实养分流、完整生物力学或种群预测。孔口只作表面示意，不是内部显微结构。")
			data.limit += I18n.text(" 东部箱龟14厘米同体与40秒慢行/停步为作者参考，腹甲静态；没有闭壳、冬季休眠或摄食求解。帝王蝶四阶段不模拟孵化、生长或羽化。")
			data.sources = [[I18n.text("NPS · 赤狐形态与林缘食物"),RedFox.SOURCE],[I18n.text("NPS · 赤狐尖吻与深色下肢"),RedFox.SHAPE_SOURCE],[I18n.text("NPS · 白尾鹿"),Deer.SOURCE],[I18n.text("Cornell · 美洲知更鸟"),"https://www.allaboutbirds.org/guide/American_Robin/lifehistory"],[I18n.text("Oregon State · 北美白橡"),"https://landscapeplants.oregonstate.edu/plants/quercus-alba"],[I18n.text("NC State · 东部白松"),"https://plants.ces.ncsu.edu/plants/pinus-strobus/"],[I18n.text("NPS · 帝王蝶"),Pollinators.SOURCE],[I18n.text("NC State · 普通乳草"),Pollinators.PLANT_SOURCE],[I18n.text("NPS · 鹿取食与保护样方"),Browse.SOURCE],[I18n.text("NPS · 美洲牛蛙"),Frogs.SOURCE],[I18n.text("Virginia DWR · 雄性牛蛙形态"),Frogs.MALE_SOURCE],[I18n.text("NPS · 宽叶香蒲"),RiverWetland.CATTAIL_SOURCE],[I18n.text("NPS · 绿纹蜻蜓"),RiverWetland.DARNER_SOURCE],[I18n.text("NPS · 金色鲦形态与小群"),FreshwaterFish.SOURCE],[I18n.text("NPS · 金色鲦缓流生境"),FreshwaterFish.HABITAT_SOURCE],[I18n.text("NPS · 斑纹鳉形态与浅水生境"),BandedKillifish.SOURCE],[I18n.text("USGS · 美洲苦草形态与生境"),WildCelery.SOURCE],[I18n.text("NPS · 分解真菌"),Fungi.SOURCE],[I18n.text("USFS · 真菌形态"),Fungi.STRUCTURE_SOURCE],[I18n.text("USFS · 木材腐朽条件"),Deadwood.SOURCE],[I18n.text("DOE · 真菌与碳释放"),Deadwood.CARBON_SOURCE]]
			data.sources += [[I18n.text("Smithsonian · 东部箱龟"),"https://nationalzoo.si.edu/animals/eastern-box-turtle"]]
		"desert":
			data.kind = I18n.text("物种参考与合成干旱生境")
			data.basis = I18n.text("七种具名动植物：沙漠鬣蜥Dipsosaurus dorsalis、巨柱仙人掌Carnegiea gigantea、三齿拉瑞阿Larrea tridentata、绒毛牧豆树Prosopis velutina、Ocotillo（Fouquieria splendens）、Brittlebush（Encelia farinosa）与梅氏袋鼠鼠Dipodomys merriami。可比较肉质茎、成对小叶、木本荚果、上举带刺茎、灰白叶丛与高出叶冠的黄色头状花序；地表参考索诺兰低地干旱灌丛、砾质山麓和岩石山体。")
			data.limit = I18n.text("32°N / 112°W仅用于教学光照；合成地形、株数、尺寸与布局不是国家公园测绘。Ocotillo与Brittlebush的花序是静态形态样本，不以当前日期推断花期、降雨或雨后发叶，也不模拟传粉/生长；Brittlebush灰白绒毛只以材质色泽示意。牧豆树沿沟布置和疏荫/荚果为作者参考；袋鼠鼠白天仅静态展示，当地夜间前台观察才按世界时间运行有限种子搬运。8单位、每24秒一次、洞口旁缓存剖面圆盘与辅助光均是作者教学设置，不是实测库存/搬运率、露天缓存或月光；不模拟摄食、萌发、植物结荚、地下水、物候或动物真实活动分布。鬣蜥路线/步态亦为作者设置；无植物储水/生长、动物体温、气候或完整生态。内部仙人掌木质肋未剖开，不由臂数估算年龄。")
			data.sources = [[I18n.text("NPS · 沙漠鬣蜥"),Iguana.SOURCE],[I18n.text("Desert Museum · 鬣蜥形态"),Iguana.SHAPE_SOURCE],[I18n.text("NPS · 巨柱仙人掌"),Desert.CACTUS_SOURCE],[I18n.text("NPS · 三齿拉瑞阿"),Desert.SHRUB_SOURCE],[I18n.text("NPS · 绒毛牧豆树"),Desert.MESQUITE_SOURCE],[I18n.text("USFS · 牧豆树生态"),Desert.MESQUITE_ECOLOGY_SOURCE],[I18n.text("NPS · Ocotillo形态"),Desert.OCOTILLO_SOURCE],[I18n.text("USFS · Ocotillo生境"),Desert.OCOTILLO_ECOLOGY_SOURCE],[I18n.text("NPS · Brittlebush形态"),Desert.BRITTLEBUSH_SOURCE],[I18n.text("USFS · Brittlebush生态"),Desert.BRITTLEBUSH_ECOLOGY_SOURCE],[I18n.text("NPS · 袋鼠鼠"),KangarooRat.SOURCE],[I18n.text("NPS · 梅氏袋鼠鼠"),KangarooRat.SPECIES_SOURCE],[I18n.text("USGS · 索诺兰生境"),Desert.HABITAT_SOURCE],[I18n.text("NPS · 山体与砾质山麓"),Desert.GEOLOGY_SOURCE],[I18n.text("NPS · 仙人掌适应"),"https://www.nps.gov/sagu/learn/nature/cacti-and-desert-succulents.htm"],[I18n.text("NC State · 成对小叶"),"https://plants.ces.ncsu.edu/plants/larrea-tridentata/common-name/chaparral/"]]
		"polar":
			data.kind = I18n.text("南极海岸合成生境与企鹅/冰磷虾形态参考")
			data.basis = I18n.text("澳大利亚南极计划支持约70厘米阿德利企鹅的白眼环、裸岩海岸与近岸食物中的冰磷虾；Naturalis支持Euphausia crystallorophias成体23–35毫米、大圆眼和长尖额剑，原始形态研究支持其相对较大眼。NSIDC说明海冰的季节变化。可近看约3厘米磷虾，或用共同日期比较66.5°S日照。")
			data.limit = I18n.text("66.5°S/0°只作日照与星位参考。12块教学海冰、背景冰川/碎冰、4只企鹅与12只磷虾、位置和路线均为作者设置，不是卫星冰缘、群密度或追踪数据。磷虾内部带/透明度/附肢和水下照明有简化；没有海流、水动力、企鹅捕食、食物消耗或种群模型。日期不预测融冻、繁殖季或动物在场。")
			data.sources = [[I18n.text("澳大利亚南极计划 · 企鹅与近岸食物"),Polar.PENGUIN_SOURCE],[I18n.text("Naturalis · 冰磷虾形态与生境"),Krill.SOURCE],[I18n.text("Tarling等 · 磷虾原始形态比较"),Krill.MORPHOLOGY_SOURCE],[I18n.text("NSIDC · 海冰形态与季节"),Polar.ICE_SOURCE]]
			data.basis += I18n.text(" 冰川大形体与雪/蓝冰表面为作者环境；夜空沿用原J2000明亮星表和日期坐标变换。极光为绿色/紫色光幕参考演示。")
			data.limit += I18n.text(" 极光并非当日预报；日期仅驱动日照与星位，不决定极光是否发生，光幕亮度和动画不用于定量读数。")
			data.sources += [[I18n.text("NOAA · 极光颜色与成因"),Polar.PolarEnvironment.AURORA_SOURCE],[I18n.text("NASA HEASARC · 明亮星表"),"https://heasarc.gsfc.nasa.gov/W3Browse/star-catalog/bsc5p.html"]]
		"arctic":
			data.kind = I18n.text("北冰洋海冰合成参考与极光演示")
			data.basis = I18n.text("NSIDC区分北极海洋与南极大陆的地理背景；78°N/0°用于共同日期日照与原J2000明亮星表方向。NOAA说明氧和氮可产生绿色/红色及蓝色/紫色极光。")
			data.limit = I18n.text("海冰、积雪、冰脊、水面与极光形状/亮度均为作者展示，非现场、融冻、当日冰况或空间天气预报。极光不模拟粒子、磁场、发射高度或发生概率；星位忽略折射与精密地球定向。没有把南极企鹅放到北极，也未模拟北极动物群落。")
			data.sources = [[I18n.text("NSIDC · 南北极海冰与地理背景"),Polar.PolarEnvironment.POLES_SOURCE],[I18n.text("NSIDC · 海冰形态与季节"),Polar.ICE_SOURCE],[I18n.text("NOAA · 极光颜色与成因"),Polar.PolarEnvironment.AURORA_SOURCE],[I18n.text("NASA HEASARC · 明亮星表"),"https://heasarc.gsfc.nasa.gov/W3Browse/star-catalog/bsc5p.html"],[I18n.text("NASA · 地球日照"),"https://science.nasa.gov/earth/facts/"]]
		"city":
			data.kind = I18n.text("合成街区与几何教学")
			data.basis = I18n.text("建筑、行人与交通按作者规则活动；26人走两条公园步道、2人在西侧过街、6人走街道人行道，48秒分相及直行车队为教学设置。四只欧亚树麻雀是原创成鸟形态参考，草地短跳/啄食仅作作者活动。两只帝王蝶与四株普通乳草在步道内侧的教学种植片区复用林地原创模型，可近看成蝶和花序。两株银杏、一株红枫与一株东部紫荆是原创种植幼树参考；扇叶、掌状裂叶、心形叶和叶前粉紫花可近看，同一观察日期切换作者季节外观。屋顶使用实际面板法线计算直射光几何系数。")
			data.limit = I18n.text("35°N、120°E仅用于教学光照；不是城市数字测绘或鸟、树、蝴蝶、乳草的实测分布。普通乳草是北美物种教学样本，不代表该光照坐标的本地植物或种植建议；片区尺寸、株数、个体与访花路线为作者设置。静态乳草花序不随日期变化，访花不等于模拟花蜜消耗、花粉转移、授粉、繁殖或迁徙。树木株数、位置、大小、叶/花数量及季节日界为作者设置；不模拟实地物候日期、气温/降水、树龄、雌雄、结实、落叶轨迹/堆积或鸟—树食物关系。匿名背景树仍不随日期改变。没有真实食物/鸟类种群、转弯车、行人决策或交通安全验证。受光系数不是发电量，未计天气、遮挡或设备效率。两块雨水示意台以作者参数比较入渗/径流，未标定真实土壤/排水管网，不能预测城市洪水。")
			data.sources = [[I18n.text("Cornell · 绿头鸭形态与城市池塘"),CityPondMallard.SOURCE],[I18n.text("Cornell · 绿头鸭水面活动"),CityPondMallard.BEHAVIOR_SOURCE],[I18n.text("NPS · 宽叶香蒲"),RiverWetland.CATTAIL_SOURCE],[I18n.text("FWS · 花园中的乳草与成虫蜜源"),Pollinators.URBAN_GARDEN_SOURCE],[I18n.text("NPS · 帝王蝶成虫与幼虫食物"),Pollinators.SOURCE],[I18n.text("NC State · 普通乳草形态"),Pollinators.PLANT_SOURCE],[I18n.text("NC State · 银杏扇叶与城市种植"),CityGinkgo.SOURCE],[I18n.text("Missouri Botanical Garden · 银杏用途"),CityGinkgo.GARDEN_SOURCE],[I18n.text("NC State · 红枫裂叶与秋色"),CityParkTrees.SOURCE_MAPLE],[I18n.text("NC State · 东部紫荆心形叶与叶前花"),CityParkTrees.SOURCE_REDBUD],[I18n.text("Cornell · 欧亚树麻雀识别"),CitySparrow.SOURCE],[I18n.text("NParks · 城市树麻雀"),CitySparrow.URBAN_SOURCE],[I18n.text("Avian Research · 树麻雀人类接近行为"),CitySparrow.HUMAN_RESPONSE_SOURCE],[I18n.text("NREL · PVWatts v5直射投影依据"),Solar.SOURCE],[I18n.text("USGS · 不透水地表与径流"),Runoff.Model.SOURCE],[I18n.text("EPA · 绿色基础设施"),Runoff.GREEN_SOURCE]]
		"pacific", "reef", "school", "fish":
			data.kind = I18n.text("地域/物种参考与未标定生理模型")
			data.basis = I18n.text("十二种具名参考：日间章鱼Octopus cyanea、黑海参Holothuria atra、海葵双锯鱼、褐吊、四带笛鲷、青绿雀鲷、绿海龟、蓝斑条尾魟、长刺海胆、砗磲Tridacna maxima、Acropora millepora石珊瑚与卵叶喜盐草Halophila ovalis。仅80mm作者目标海葵鱼连接WOA23区域边界及氧输送/利用参考链。")
			data.limit = I18n.text("物种形态与食性有资料；青绿雀鲷以局部避挤/对齐/聚合规则更新位置，参数未按物种标定；鱼群主题中的12枚放大水层亮点是有限教学资源、每4世界秒减少1单位，不是可鉴定浮游动物个体、实测密度或捕获率。仅在主题前台观察时推进，无水流、繁殖、能量摄取或种群预测。砗磲的双壳、外鳞片和外套膜为原创静态形态参考，不计算开合、光合或过滤量。黑海参的约21厘米体长、砂覆与摄食端为原创参考，不计算沉积物处理量、营养循环或种群。日间章鱼外套膜约12厘米、448个简化吸盘、16秒腕端微动和两种体色为作者参考，不模拟爬行、抓取、吸附力或自动伪装。其余数量、路径和活动是教学规则，没有完整食物网。区域历史均值不是礁区实时测量，生理参数未按目标鱼标定，也不套用给其他物种。珊瑚骨骼/触手与组织内共生藻有资料，微动是作者设置；共生颜色接入局部热压力教学实验，非物种白化或死亡预测，未模拟生长或共生代谢。")
			data.sources = [[I18n.text("澳大利亚博物馆 · 日间章鱼"),Octopus.SOURCE],[I18n.text("FAO · 章鱼八腕与双列吸盘"),Octopus.MORPHOLOGY_SOURCE],[I18n.text("澳大利亚博物馆 · 蜥蜴岛章鱼现场"),Octopus.FIELD_SOURCE],[I18n.text("Fishes of Australia · 目标物种"),"https://fishesofaustralia.net.au/home/species/317"],[I18n.text("NOAA · WOA23历史区域数据"),I18n.dictionaries(Model.SOURCES)[0].url],[I18n.text("Fishes of Australia · 褐吊"),Marine.SOURCES[0]],[I18n.text("Fishes of Australia · 四带笛鲷"),Marine.SOURCES[1]],[I18n.text("Fishes of Australia · 青绿雀鲷"),Marine.SOURCES[2]],[I18n.text("NOAA · 浮游动物"), "https://oceanservice.noaa.gov/facts/plankton.html"],[I18n.text("Reynolds · 局部群体规则"),School.SOURCE],[I18n.text("NOAA · 绿海龟"),Marine.SOURCES[3]],[I18n.text("van der Geest等 · 海龟运动"),Marine.TurtleMotion.SOURCE],[I18n.text("Fishes of Australia · 蓝斑条尾魟"),Marine.SOURCES[4]],[I18n.text("Chow等 · 长刺海胆结构"),Urchin.SOURCE],[I18n.text("澳大利亚博物馆 · 海胆地区记录"),Urchin.FIELD_SOURCE],[I18n.text("澳大利亚博物馆 · 黑海参浅水形态"),BlackSeaCucumber.SOURCE],[I18n.text("西澳博物馆 · 黑海参与触手"),BlackSeaCucumber.FEEDING_SOURCE],[I18n.text("Moriarty · 大堡礁沉积物取食"),BlackSeaCucumber.RESEARCH_SOURCE],[I18n.text("Jia等2022 · 触手与沉积物食物"),BlackSeaCucumber.ACTIVITY_SOURCE],[I18n.text("澳大利亚博物馆 · 砗磲形态"),Clam.SOURCE],[I18n.text("NOAA · 砗磲向光与共生"),Clam.LIGHT_SOURCE],[I18n.text("NOAA · 珊瑚虫"),Coral.SOURCE],[I18n.text("NOAA · 组织内共生藻"),Coral.SYMBIOSIS_SOURCE],[I18n.text("NOAA · 白化与死亡的区别"),Coral.Symbiosis.SOURCE],[I18n.text("Xu等 · A. millepora结构"),Coral.MORPHOLOGY_SOURCE],[I18n.text("Kew · 海草叶片形态"),Seagrass.SOURCE],[I18n.text("Reef Authority · 海草生态"),Seagrass.ECOLOGY_SOURCE],[I18n.text("Seagrass-Watch · 形态识别"),Seagrass.FIELD_SOURCE]]
		"heart", "cardiomyocyte", "mitochondrion":
			data.kind = I18n.text("跨物种结构示意与参考模型")
			data.basis = I18n.text("一般硬骨鱼结构与公开细胞/线粒体研究用于解释；参考链读取同一世界的生理状态。")
			data.limit = I18n.text("不是目标鱼的扫描或实测生理预测。形状、颜色和运动简化；参数待物种标定，粒子不是分子计数。")
			data.sources = [[I18n.text("Hu 2001 · 成年斑马鱼心脏"),BODY_SOURCE],[I18n.text("Scientific Reports 2017 · 线粒体结构"),"https://www.nature.com/articles/srep45474"]]
		"molecule":
			data.kind = I18n.text("分子结构符号")
			data.basis = I18n.text("O₂显示两个氧原子中心和连接；身份参考NIST记录。")
			data.limit = I18n.text("连接棒、颜色和显示间距不是实测外观或精确键长；未计算分子动力学。")
			data.sources = [[I18n.text("NIST · O₂物种记录"),"https://webbook.nist.gov/cgi/cbook.cgi?ID=C7782447&Mask=1000"]]
		"atom":
			data.kind = I18n.text("氧原子组成与参考轨道形状")
			data.basis = I18n.text("中性氧基态为1s² 2s² 2p⁴，共8个电子。核组成以氧-16示例：8质子与8中子。可比较1s球对称、2s径向节点与2p节点平面。")
			data.limit = I18n.text("云形用类氢解析函数和任意显示长度；组态总览按2:2:4混合，2p取方向平均，不是氧原子多电子计算。单个2p两瓣不是两个电子。核单独放大且排布任意。不是O₂分子轨道或解离模拟，颜色/亮度不是实测光学外观。")
			data.sources = [[I18n.text("NIST · 中性氧基态"),Oxygen.SOURCE],[I18n.text("NIST · 氧同位素"),Oxygen.ISOTOPE_SOURCE],[I18n.text("MIT · 类氢参考函数"),Oxygen.SHAPE_SOURCE]]
	if id in ["city","woodland","polar","reef","pacific"]:
		data.basis += I18n.text(" 本轮人物采用两种基础虚拟角色与服装色彩/身形复用；阿德利企鹅、白尾鹿雌成体、赤狐和绿海龟为生成物种形态参考，已本地适配同一世界时间下的动作。")
		data.limit += I18n.text(" 生成模型不是人体或动物扫描、标本解剖或实测运动；角色不对应真实个人，甲片/鳞片、毛羽和关节仍有简化。")
		data.sources.append([I18n.text("Tripo · 生成形态模型来源"),"https://studio.tripo3d.ai/"])
	return data

static func text_for(id: String) -> String:
	var data: Dictionary = describe(id)
	if id in ["solar_system","earth_moon"] or Satellites.is_system(id):
		data.basis+=I18n.text(" 同框视图只改变观察者位置和镜头视野：观察者靠近卫星、远离行星，因此屏幕视大小不等于实体大小比。随行镜头跟随行星—卫星方向，不是固定视点；拉远后的轨道全景用于观察空间分布和运行。点击任一星体分别近看，再拉远回到同框。")
	var text: String = I18n.text("[b]依据与表达方式[/b]\n[color=#98dfcf]%s[/color]\n\n%s\n\n[b]适用边界[/b]\n%s\n\n[b]参考入口[/b]") % [data.kind,data.basis,data.limit]
	if data.sources.is_empty(): text += I18n.text("\n本场景为作者化空间背景，无实测目录输入。")
	for source: Array in data.sources: text += "\n[url=%s]%s ↗[/url]" % [source[1],source[0]]
	if id in ["pacific","reef","school","fish","heart","cardiomyocyte","mitochondrion"]:
		text += I18n.text("\n\n参考链的逐项假设与生理来源：打开“影响链 / 记录”。物种资料和活动边界：打开“对象 / 主题”。")
	return text

static func allows_url(id: String, url: String) -> bool:
	for source: Array in describe(id).sources:
		if source[1]==url: return true
	return false
