extends RefCounted
const Algae = preload("res://scripts/experience/algal_observation.gd")
const Oxygen = preload("res://scripts/core/oxygen_atom.gd")
const RayObservation = preload("res://scripts/experience/ray_observation.gd")
const RobinSkin = preload("res://scripts/experience/robin_skin_motion.gd")
const Jovian = preload("res://scripts/experience/jovian_builder.gd")
const Iguana = preload("res://scripts/experience/iguana_observation.gd")
const Desert = preload("res://scripts/experience/desert_builder.gd")
const KangarooRat = preload("res://scripts/experience/kangaroo_rat_observation.gd")
const CityGinkgo = preload("res://scripts/experience/city_ginkgo.gd")
const CityParkTrees = preload("res://scripts/experience/city_park_trees.gd")
const School = preload("res://scripts/experience/school_observation.gd")
const Zooplankton = preload("res://scripts/core/zooplankton_lesson.gd")
const Deadwood = preload("res://scripts/experience/deadwood_observation.gd")
const Fungi = preload("res://scripts/experience/fungus_observation.gd")
const Frogs = preload("res://scripts/experience/frog_observation.gd")
const RiverWetland = preload("res://scripts/experience/river_wetland_observation.gd")
const FreshwaterFish = preload("res://scripts/experience/freshwater_fish_observation.gd")
const WildCelery = preload("res://scripts/experience/wild_celery_observation.gd")
const BandedKillifish = preload("res://scripts/experience/banded_killifish_observation.gd")
const RedFox = preload("res://scripts/experience/red_fox.gd")
const BoxTurtle = preload("res://scripts/experience/box_turtle.gd")
const TurtleComparison = preload("res://scripts/experience/turtle_comparison.gd")
## Observation actions and provenance. Read-only presentation of the existing world.
const Lunar = preload("res://scripts/experience/lunar_observation.gd")
const Runoff = preload("res://scripts/experience/runoff_observation.gd")
const Seagrass = preload("res://scripts/experience/seagrass_observation.gd")
const Coral = preload("res://scripts/experience/coral_observation.gd")
const Browse = preload("res://scripts/experience/browse_observation.gd")
const Turtle = preload("res://scripts/experience/turtle_motion.gd")
const DeerSkin = preload("res://scripts/experience/deer_skin_motion.gd")
const Crossing = preload("res://scripts/experience/city_crossing.gd")
const CitySparrow = preload("res://scripts/experience/city_sparrow.gd")
const CityPondMallard = preload("res://scripts/experience/city_pond_mallard.gd")
const Polar = preload("res://scripts/experience/polar_builder.gd")
const Krill = preload("res://scripts/experience/polar_krill.gd")
const Kepler = preload("res://scripts/experience/kepler_observation.gd")
const SolarEphemeris = preload("res://scripts/core/solar_ephemeris.gd")
const Solar = preload("res://scripts/core/solar_incidence.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Sites = preload("res://scripts/data/earth_sites.gd")
const Seasons = preload("res://scripts/experience/season_observation.gd")
const Urchin = preload("res://scripts/experience/urchin_observation.gd")
const Clam = preload("res://scripts/experience/giant_clam_observation.gd")
const BlackSeaCucumber = preload("res://scripts/experience/black_sea_cucumber_observation.gd")
const Octopus = preload("res://scripts/experience/day_octopus.gd")
const MonarchStages = preload("res://scripts/experience/monarch_life_stages.gd")
const EarthDaylight = preload("res://scripts/experience/earth_daylight.gd")
const Larva = preload("res://scripts/experience/monarch_larva_observation.gd")
const Pollinators = preload("res://scripts/experience/pollinator_observation.gd")
const Galactic = preload("res://scripts/experience/galactic_observation.gd")
const Plants = preload("res://scripts/experience/plant_observation.gd")

static func for_scale(id: String) -> Array[Dictionary]:
	var topics: Array[Dictionary] = []
	if id=="night_sky":
		topics.append({"id":"ground_sky","title":"站在地球上看银河","follow":0,"observe":"在山地观星台拖动环顾，指向亮星查看名字；点击月球用同一位置的光学视野近看。改变天文日期或开启1小时/世界秒，比较星空的升落与昼夜。银河是从盘内向外看的全天观测图，不是地球上空的一团发光云。","limit":"固定J2000明亮星位及球面地平坐标，不含自行、折射、实时地球定向、遮云或光害预测。银河曝光、亮星光晕和地形为展示表达；月球/太阳保留实际角直径，行星光点放大。","source":"https://heasarc.gsfc.nasa.gov/W3Browse/star-catalog/bsc5p.html"})
	if id=="galaxy":
		topics.append({"id":"galactic_structure","title":"太阳在银河系的哪里？","follow":0,"observe":"沿距离线从银心找到太阳系入口。比较俯视的旋臂与侧视的扁平星盘，再进入同一个太阳系。光年表示距离，并非经过的时间。太阳位于本地臂/猎户支臂附近；图中方位仅为排布。","limit":"采用约2.6万光年银心距离和约10万光年参考盘径。圆环不是银河的硬边界；恒星亮点、旋臂位置、厚度和太阳标记大小为作者示意，不是恒星目录、真实外观照片或银河轨道推演。","source":Galactic.SOURCE})
	if id=="atom":
		topics.append({"id":"oxygen_atom","title":"氧原子：组成与轨道","follow":0,"observe":"用上方菜单比较1s、2s、2p参考云形，查看中心剖面，再单独放大氧-16的原子核。","limit":"电子组态依据NIST；云形用类氢函数示意，不是中性氧精确电子密度，也不是O₂分子轨道。","source":Oxygen.SOURCE})
	if id=="jupiter_moons":
		topics.append({"id":"jovian_periods","title":"木星四卫星：谁绕行得更快？","follow":0,"observe":"先看四条轨迹，再用±3小时比较位置变化。选择单颗卫星近看历史表面拼图；切换真实大小，区分实际空间距离与为了看清而放大的卫星。","limit":"JPL几何矢量缓存覆盖2026-09-01—12-01 TDB。周期按缓存角位移估计，轨迹线取附近一周运动。卫星朝向为理想同步，无食阴影，不模拟潮汐热量、共振形成、火山或地面观测掩食。","source":Jovian.Model.SOURCE})
	elif id=="solar_system":
		topics.append({"id":"mercury_orbit","title":"水星：近处快，远处慢","follow":0,"observe":"橙色近日段与蓝色远日段各8天，太阳连线扫过相同面积。选择区段起点，再前进8天，比较水星的移动。","limit":"橙蓝区段是固定JPL Table 1参考椭圆，实际水星球体使用"+SolarEphemeris.position_source()+"；两者不是完全相同的轨迹。星体大小放大，太阳为此视图缩小。区段日期由近似模型挑选，不是精密近日点预报。","source":Kepler.SOURCE})
	elif id=="earth":
		topics.append({"id":"earth_daylight","title":"两半球与纬度昼长","follow":0,"observe":"在同一地球比较赤道、南北35°与70°。暖色弧段受光，蓝色弧段背光；四个2026参考日期明确改变观察日期。地理坐标固定、北向上，太阳方向随日期变化。","limit":"几何昼长使用点太阳、固定当日赤纬和球面地平线，未计折射、太阳圆盘、地形或天气；不是日出预报或气候模拟。纬线/线宽为教学符号，地表与云仍为NASA历史合成。","source":"https://spaceplace.nasa.gov/seasons/en/"})
	elif id=="earth_moon":
		topics.append({"id":"lunar_phases","title":"月相、天平动与日月食","follow":2,"observe":"选择下一次近似月相，在轨道全景与沿地球方向近看之间切换。太阳照亮的部分随位置变化；同步自转仍伴随天平动，月面参考点和可见边缘会偏移。前进一天可比较月距及地心月面经纬度。日/月食示例按同一日期计算遮挡，±30分钟对照影子移动与明暗；月轨道倾斜，多数新月和满月会错开影子。拖动可自由环绕，再点按钮回到地球方向。","limit":"月球位置为ERFA/Meeus摄动近似，朝向为NAIF IAU_MOON；不是高精度DE月面姿态。遮光按真实物理距离和均匀太阳圆盘计算；无大气折射红月、太阳临边昏暗或精确食路径。太阳位置沿用地月质心近似，示例时刻取整，不作接触时刻预报。1950年前不沿用原算法公布的区间精度。按钮寻找本模型的下一次黄经差阶段，不是实测月相时刻。近看采用沿地球方向的平行投影，不是地面所见角直径；暗面微亮用于辨形，非地球照反演。","source":Lunar.Phase.SOURCE})
	elif id in ["reef","school","fish","pacific"]:
		topics.assign([
			{"id":"black_sea_cucumber","title":"黑海参：砂底的沉积物摄食者","follow":0,"target_id":"3dworld:teaching:holothuria-atra:0001","observe":"看柔软的黑色筒状身体、薄砂覆盖，以及两列露出的黑色皮肤。它是海参类棘皮动物，不是鱼、珊瑚或水层教学亮点；切到摄食端近看同一只个体。","limit":"Holothuria atra原创参考；约21厘米体长、砂覆斑纹、固定身体与12秒触手动作是作者设置，并非实测蜥蜴岛个体。资料支持摄取沉积物有机成分；这里没有模拟处理量、营养循环、活动率或真实种群密度。","source":BlackSeaCucumber.SOURCE},
			{"id":"day_octopus","title":"日间章鱼：礁底的八腕与外套膜","follow":0,"target_id":"3dworld:teaching:octopus-cyanea:0000","observe":"近看日间章鱼的外套膜、头部真眼、八条腕及腕间膜；再切同一条抬起腕上的两列吸盘。它是头足类动物，资料记录它可在白天伸腕搜索礁缝。下方可比较同一模型的褐斑与较浅参考体色。","limit":"Octopus cyanea原创参考；外套膜约12厘米、单只摆放、448个简化吸盘、姿态和16秒腕端微动为作者设置。体色按钮只作形态对照，不模拟环境识别或色素细胞；未实现爬行、喷射、抓取猎物、吸附力、呼吸或种群。","source":Octopus.SOURCE},
			{"id":"day_octopus_suckers","title":"日间章鱼：同一条腕的双列吸盘","follow":0,"target_id":"3dworld:teaching:octopus-cyanea:suckers","observe":"走近同一只章鱼抬起的腕端，沿腹面找到并列的两行吸盘；暂停后比较杯状边缘与连在一起的柔软腕。吸盘与腕一起微动，模型没有被放大。","limit":"每腕两列吸盘有物种资料支持；每列28个只是精简三维几何，不是大型自然个体的真实数量或吸附力测量。腕端活动为连续作者变形，不表示捕食、爬行或真实肌肉控制。","source":Octopus.MORPHOLOGY_SOURCE},
			{"id":"black_sea_cucumber_feeding","title":"黑海参：同一只个体的摄食端","follow":0,"target_id":"3dworld:teaching:holothuria-atra:feeding-end","observe":"从同一只黑海参身体走近前端，看黑色短触手随世界时间伸出/收拢，暂停对照口端附着，再返回整体比较砂覆与露肤。沉积物中的有机成分可被摄入；这一处没有单颗砂粒或营养素追踪。","limit":"12个短触手形状是可观察的作者示意，不作为该物种触手数量的鉴定依据；本体保持真实场景尺寸，镜头走近而非放大模型。12秒伸收仅为作者示意，没有颗粒抓取、肠道消化或沉积物通量求解。","source":BlackSeaCucumber.ACTIVITY_SOURCE},
			{"id":"giant_clam","title":"砗磲：会受光的双壳动物","follow":0,"target_id":"3dworld:teaching:tridacna-maxima:0001","observe":"看两侧外壳的密集鳞片和朝上的蓝绿褐斑驳外套膜。它是双壳类动物，不是珊瑚或海草；外套膜里的共生藻接受阳光并提供营养。可从观察对象再走近同一壳或外套膜。","limit":"Tridacna maxima原创参考；29cm壳长、外鳞片和色斑数量、位置及开度为作者设置。没有测量个体、模拟开合、过滤水量、光合速率或共生藻细胞数。","source":Clam.SOURCE},
			{"id":"giant_clam_mantle","title":"砗磲外套膜：向光的组织","follow":0,"target_id":"3dworld:teaching:tridacna-maxima:mantle","observe":"近看同一只砗磲的斑驳外套膜；沿边缘比较下面的两个壳瓣。铰合侧朝下，外套膜向上接收阳光；可返回整只观察。","limit":"斑纹是原创教学图案，不是个体鉴定特征或共生藻显微图。蓝绿亮斑不直接表示光合产量，当前不模拟遮阴后的开合反应。","source":Clam.LIGHT_SOURCE},
			{"id":"seagrass","title":"海草：海里的开花植物","follow":10,"observe":"观察砂底不规则斑块，和旁边珊瑚、海胆的身体比较。海草是植物，珊瑚是动物；成对叶片从埋在砂中的根茎长出。切到叶片近看，沿中脉看横脉与近叶缘脉相连。","limit":"Halophila ovalis参考；密度、摆放和水流微摆为作者设置，非蜥蜴岛指定坐标调查。海草为绿海龟等提供食物，此例未模拟啃食、生长或光合；未展示花和果实。","source":Seagrass.ECOLOGY_SOURCE},
			{"id":"seagrass_leaf","title":"海草叶片：叶柄与叶脉","follow":11,"observe":"看同株18×9mm参考叶，叶柄连到叶基；沿中央叶脉数两侧横脉，并看它们接到靠近叶缘的纵脉。可暂停和环绕；移动的是镜头，模型没有放大。","limit":"10对横脉是所选作者参考个体，物种叶形、大小和脉数存在变异。叶缘光滑且无叶毛；根与根茎埋在砂中，未显示剖面。微摆不是流体求解。","source":Seagrass.SOURCE},
			{"id":"coral_symbiosis","title":"热压力与珊瑚共生：白化意味着什么？","follow":8,"observe":"点群体近看，再点旁边的教学开关开启热压力并继续时间，观察同一群体颜色逐渐变浅。解除压力后，相对共生藻量在条件允许时逐步恢复；可暂停和切到附着珊瑚虫近看。","limit":"选取仍存活且可恢复的教学例子，现实不保证恢复。0–1代理与速度为作者设置，不是藻细胞数、温度阈值、白化天数或死亡预测；未模拟营养、生长或钙化。实验开关不改变鱼类参考情境。","source":Coral.Symbiosis.SOURCE},
			{"id":"coral_colony","title":"珊瑚是动物：从群体看枝条","follow":8,"observe":"看短枝条表面一排排小杯口；它们对应许多个体珊瑚虫。骨骼共同构成群体，活组织覆盖表面。再选“珊瑚虫近看”，镜头移到同一枝条。","limit":"Acropora millepora参考形态；群体尺寸、枝条和珊瑚虫数量是作者布局，未模拟生长或钙化；共生颜色仅接入另一个热压力教学主题。","source":Coral.MORPHOLOGY_SOURCE},
			{"id":"coral_polyp","title":"珊瑚虫：触手、口与共生","follow":9,"observe":"看触手围绕中央的口，触手帮助捕获食物。共生藻住在活组织内，并提供光合产物；当前颜色表示组织外观，不能直接数出其中的藻细胞。可从群体双指靠近后，点击实际附着的珊瑚虫近看；双击看说明，也可暂停和环绕。","limit":"同一群体上的毫米级结构，镜头靠近，模型未放大。12触手与轻微摆动是作者示意，未模拟摄食、日夜伸缩或共生代谢；共生颜色读取局部教学状态，非实测白化；骨骼仍覆有组织，并非组织切片。","source":Coral.SOURCE},
			{"id":"turtle_surface","title":"海龟为什么要到水面呼吸","follow":4,"view_distance":2.5,"observe":"跟随同一只海龟从礁区上浮，观察鼻端露出海面，然后下潜。水下阶段可调快时间，水面阶段暂停、环绕看鼻端与空气的接触。海龟呼吸空气，不能像鱼那样靠鳃取氧。","limit":"NOAA支持海龟需上浮呼吸。72秒路线、8秒水面停留与抬头角度是作者教学设置，不是实测换气间隔；未计算肺内气体交换、耗氧或浮力。","source":Turtle.SPECIES_SOURCE},
			{"id":"turtle","title":"海龟怎样划水和滑行","follow":4,"view_distance":2.1,"observe":"比较长前鳍肢与短后鳍肢。看前鳍抬起、下划、向身体下方内扫，再舒展滑行；滑行时身体仍向前。可暂停或环绕看背甲与鳍肢。","limit":"运动研究提供参考，8秒节律与72秒路线为教学设置，刚性鳍肢简化，未复现论文关节模型或求解水动力。海龟会沿72秒教学路线周期性上浮；换气姿态不代表实测呼吸节律或气体交换模型。","source":Turtle.SOURCE},
			{"id":"urchin","title":"长刺海胆：棘皮动物的结构","follow":7,"observe":"俯看体壳，沿圆周数出五个白斑，找出中央橙色肛锥环，再切到整只比较长棘与鱼鳍的差别。橙环不是眼睛。","limit":"Diadema setosum参考形态；6cm体壳和棘微动为作者设置。资料记录夜间活动，此处便于观察的摆放不等于日间觅食；未模拟摄食或珊瑚侵蚀。","source":Urchin.SOURCE},
			{"id":"algae","title":"藻毯与食藻鱼：资源怎样改变取食","follow":1,"view_distance":4.6,"observe":"比较六处藻毯的绿色覆盖与相对藻量。褐吊充分接近岩面后才扣减资源；下一轮可依藻量、占用与距离重新选点。停止刮食看恢复，或关闭按藻量选点作对照。","limit":"六斑块收支与鱼的选择由同一世界持有。0–100资源、恢复/摄食率、32秒访问节律与选择规则为作者加速教学设置，未按褐吊标定，也未模拟领地防卫；纹理不是测量覆盖率，未模拟光合、营养盐、食物同化或珊瑚竞争。","source":Algae.Model.SOURCE},
			{"id":"school","title":"鱼群与水层食物：邻居和资源怎样变化？","follow":3,"view_distance":3.0,"observe":"青绿雀鲷在分枝珊瑚上方集群，摄食水层浮游动物。青色线连向代表鱼当前响应的邻居，圆圈是水平范围辅助。切换方向对齐、让代表鱼转向，可比较局部群体规则。继续时间还可看12个放大水层教学单位逐个减少；暂停、离开主题或单独重置可作对照。","limit":"避挤/对齐/聚合是计算机群体规则，24尾、速度和0.55m/300°影响范围均为作者设置。水层12单位、每4世界秒减1也是作者化的有限群体取食示意，并非12只可鉴定动物或实测密度、捕获率；亮点不是实际浮游动物体型，漂动不模拟水流。两种规则共用世界时间，但未模拟个体嘴部捕获、能量摄取、浮游动物繁殖或种群变化。","source":Zooplankton.SPECIES_SOURCE},
			{"id":"snapper","title":"捕食性礁鱼：集群与巡游","follow":2,"view_distance":3.0,"observe":"观察四带笛鲷的四条蓝带、礁旁集群，以及代表鱼离群巡游、转向返回的变化。比较它与食藻鱼的食物角色。","limit":"资料支持礁旁集群及鱼类/甲壳类食性；52秒路线是教学动作，未模拟猎物捕获或种群变化。","source":"https://fishesofaustralia.net.au/home/species/559"},
			{"id":"ray","title":"魟怎样贴底游动","follow":5,"observe":"观察胸鳍前段、中段、后段的起伏：波从头侧向尾侧传播。可暂停并调节时间比较三个标记；扁平体盘与长尾仍可环绕观察。","limit":"蓝斑条尾魟研究支持前向后传播；此处频率、振幅和巡游速度为作者设置，未求解水动力或真实捕食。","source":RayObservation.SOURCE}])
	elif id=="woodland":
		topics.assign([
			{"id":"box_turtle","title":"东部箱龟：林地里的陆生爬行类","follow":0,"target_id":BoxTurtle.STABLE_ID,"observe":"近看同一只箱龟的高拱背甲、黄橙色斑纹和有趾四足，继续或暂停比较短步慢行与停步。后足有四趾，和海龟的鳍肢不同。箱龟吃植物、果实和小型动物等多类食物；腹甲双叶和铰链是结构参考。","limit":"Terrapene carolina carolina原创参考，性别未指定；背甲14厘米、斑纹/甲片分区、骨骼和40秒作者路线不是标本扫描、个体鉴定或实测活动。未演示闭壳反应、冬眠/温度活动、摄食量/捕食、繁殖或种群变化。","source":BoxTurtle.SOURCE},
			{"id":"box_turtle_head","title":"箱龟：同一只的钩状上颌与头颈","follow":0,"target_id":BoxTurtle.HEAD_ID,"observe":"走近同一个体的眼、鼻孔、钩状上颌和有斑纹头颈；观察点随原骨骼更新，暂停或调世界秒比较姿态，镜头靠近时动物尺寸保持。","limit":"原创外形与色纹参考，不是头骨/牙齿解剖或野外鉴别工具；性别未指定，不按模型眼色作性别判断。口器不接摄食量或主动咬合，腹甲铰链仍为静态参考。","source":BoxTurtle.SHAPE_SOURCE},
			{"id":"red_fox","title":"赤狐：林缘犬科的身体与食物角色","follow":0,"target_id":RedFox.STABLE_ID,"observe":"从整体观察红褐毛色、深色下肢、蓬松白尾端及尖耳/尖吻，再走近同一只个体的头部。继续或暂停世界时间比较缓行与停步。赤狐的食物包含小动物和植物，与白尾鹿的植物食物角色不同。","limit":"Vulpes vulpes红褐型形态参考；一个个体、肩高约40厘米、40秒节律及路线为作者设置，不是实测种群、标本或亚种鉴定。没有模拟捕猎、气味/听觉、季节活动或食物收支，也没有把已有鹿/鸟指定为猎物。","source":RedFox.SOURCE},
			{"id":"red_fox_head","title":"赤狐：同一个体的尖吻与尖耳","follow":0,"target_id":RedFox.HEAD_ID,"observe":"走近同一只赤狐的细长尖吻、黑鼻、尖耳和浅色喉部。头部观察点随原骨骼移动，暂停和调节世界秒可对照姿态；镜头靠近时模型尺寸不变。","limit":"参考外形和毛色为教学表达；没有内部牙齿/颅骨解剖、气味或听觉求解，不是野外物种、亚种或个体鉴定工具。","source":RedFox.SHAPE_SOURCE},
			{"id":"monarch_egg","title":"帝王蝶的四个生命阶段：从卵开始","follow":0,"target_id":MonarchStages.EGG_ID,"observe":"从原乳草叶背的一枚卵开始，按1卵、2幼虫、3蛹、4成蝶比较完全变态的四个生命阶段。卵壳奶黄，有纵向脊；近看镜头保留约1.2毫米高、0.9毫米宽的实际模型尺寸。幼虫取食乳草叶，成虫吸食花蜜。","limit":"四个参考是同种的不同阶段/个体；切换按钮不会让当前卵瞬间变成另一只幼虫，也不会推进世界时间。固定卵/绿蛹、原晚龄幼虫与成蝶访花不是孵化、生长、蜕皮、化蛹、羽化、繁殖或温度依赖发育预测；数量/位置/纹样为作者表达。","source":MonarchStages.SOURCE},
			{"id":"monarch_pupa","title":"帝王蝶的蛹：怎样悬挂在叶背？","follow":0,"target_id":MonarchStages.PUPA_ID,"observe":"近看同一只固定玉绿色蛹和黑色尾端悬挂部，它连着原乳草叶背的丝垫参考。蛹期不取食，成体结构在这一阶段继续形成；蝴蝶的蛹称chrysalis，不能把它直接叫成包住蛹的丝茧。","limit":"作者蛹体长约25毫米，纹样/金色外观斑点/丝垫和摆放为原创参考，不是扫描标本或性别鉴定。金色不是金属黄金，其功能不在本项目求解；未模拟内部器官、化蛹/羽化、发育速率或环境依赖。","source":MonarchStages.SOURCE},
			{"id":"monarch_larva","title":"从幼虫到成蝶，食物变了吗？","follow":0,"target_id":Larva.STABLE_ID,"observe":"近看乳草叶上的晚龄帝王蝶幼虫：三对胸足有分节，五对腹足支撑身体。前后两对长丝状突起不是触角；真正触角很短，在头部。切换到成蝶访花，比较幼虫的咀嚼口器与成虫吸花蜜的口器。","limit":"这里比较同一物种的不同个体/生命阶段，不是眼前幼虫瞬间变为那只成蝶。约4.5cm体长、花期、摆动与摆放为作者设置；卵与绿蛹另有固定三维参考；未模拟蜕皮、变态发育、摄食量、叶片消耗或授粉。","source":Larva.SOURCE},
			{"id":"deadwood","title":"枯木分解：水越多越快吗？","follow":15,"observe":"点击木段近看，再点前方条件旋钮切换左侧干燥、湿润或浸水条件；右侧始终干燥，继续时间看变化。对比木材变浅和后期破碎，以及棕、金、青色条的变化。白腐早期可保留外形；干燥或缺氧会限制典型腐朽真菌。","limit":"100相对碳单位与加速速度为教学设置，不是克数、年数或云芝预测。有机留存合并菌体与加工后有机物；呼吸释放计CO₂中的碳，不能把木材损失全部当作植物养分。水分/供氧为预设条件，未模拟温度、菌丝生长或其他分解者；破碎图案也不是质量体积测量。","source":Deadwood.Model.SOURCE},
			{"id":"fungus","title":"枯木与云芝：森林里的分解者","follow":12,"observe":"先看附着枯木的薄扇形子实体，再从观察对象切换到菌盖色带和底面孔口。分解工作主要来自木内菌丝；子实体参与产生孢子，它不是整株植物，也不等于整个真菌。","limit":"原创静态参考，11个子实体不代表11个菌丝个体。孔口为表面示意，未显示内部管层或肉眼不可见的孢子；未模拟生长、木材损失、养分循环或分解速度，不是野外鉴定检索。","source":Fungi.SOURCE},
			{"id":"bullfrog","title":"河岸两栖动物：牛蛙的身体","follow":10,"observe":"找出眼后圆形鼓膜、短耳后褶和黄色喉部。再从观察对象切换到后足，比较前足四趾与后足五趾、趾间的蹼；最长后趾末端伸出蹼缘。","limit":"成年雄性原创参考；体型、两只个体与喉部微动为作者设置。主要夜间活动，当前明亮光照便于观察，不表示典型日间行为；没有模拟鸣叫、呼吸生理、跳跃、捕食、蝌蚪或繁殖。","source":Frogs.SOURCE},
			{"id":"browse","title":"取食与恢复：比较两块植被","follow":9,"observe":"两块样方从相同叶量开始，右侧持续保护。看左侧鹿取食后叶量怎样变化，再点左侧3D门闩保护样方，比较恢复过程；右侧始终保持保护对照。重置对比只重置这两块样方。","limit":"相对叶量与加速过程为教学模型，不对应真实年数、生物量或森林预测；植物为未鉴种示意。取食影响植被有资料，围栏和动作未做碰撞或工程验证。","source":Browse.Model.SOURCE},
			{"id":"monarch","title":"蝴蝶与花：谁在取食什么？","follow":7,"view_distance":1.20,"observe":"观察帝王蝶靠近乳草花序、伸出口器，再收拢口器飞离。成虫取食花蜜，幼虫取食乳草叶片；可在观察对象中近看帝王蝶或整株乳草。","limit":"此视图表现成虫；可切换卵、叶面幼虫和悬挂蛹比较完全变态的阶段与食物。花期、路线、数量和拍翼为作者设置。访花不等于已经完成授粉，未模拟花蜜消耗、花粉转移、变态或迁徙。","source":Pollinators.SOURCE},
			{"id":"oak_leaf","title":"北美白橡：认识圆裂叶","follow":5,"observe":"近看一片仍连接在幼树上的叶子。沿叶柄找到主脉，比较两侧圆裂片和收窄的叶基。可在观察对象中返回整株北美白橡。","limit":"Quercus alba参考形态；叶长18cm为作者尺寸，非实测标本。叶脉细节简化，未模拟落叶、生长或取食。","source":Plants.OAK_SOURCE},
			{"id":"pine_needles","title":"东部白松：五针一束","follow":6,"observe":"从共同的束基部数出五枚针叶，再转动视角看它们怎样分开。与北美白橡宽叶片的轮廓比较。可切回整株查看轮生枝条。","limit":"Pinus strobus参考形态；每针10.5cm为作者尺寸，未表现全部微观结构或针叶更新。五针一束并非该物种独有。","source":Plants.PINE_SOURCE},
			{"id":"season_light","title":"季节怎样改变林地日照","follow":0,"observe":"在同一视角切换6月与12月的近似正午，比较太阳高度、树影和昼长。地轴倾斜使北半球夏季日照更高、白昼更长。","limit":"35°N参考光照；不计折射或地形遮挡的昼长。植被与动物不会随日期变成另一季，尚未模拟周年变化。","source":Seasons.SOURCE},
			{"id":"graze","title":"植物与白尾鹿","follow":1,"observe":"观察成体雌鹿的缓行、头颈配合低头和抬头查看。留意嘴部接近地表植物时颈部、腿与分趾蹄的变化；白尾鹿也吃灌木、草本及其他植物。","limit":"固定夏毛参考；48秒活动、体型和步幅是作者设置，未模拟植物消耗、反刍、季节换毛或完整生物力学。","source":"https://www.nps.gov/bith/learn/nature/white-tailed-deer.htm"},
			{"id":"bird","title":"从地面觅食到飞行","follow":2,"observe":"看成鸟雄性外形参考的知更鸟短行后停步、歪头查看地面，再转身、展翼起飞和伸足落地。内外翼段共同收拢，长飞羽层叠在覆羽后方。可用时间控件暂停观察翼、喙与足。它吃无脊椎动物，也吃果实。","limit":"48秒活动、慢速飞行路线与拍翼节奏均为作者设置；不是实测飞行速度，未计算气动力或猎物捕获。形体、羽片排列和关节运动为教学近似，未标定个体解剖。","source":"https://www.allaboutbirds.org/guide/American_Robin/lifehistory"},
			{"id":"river_wetland","title":"河岸的挺水植物与飞行昆虫","follow":0,"target_id":"3dworld:teaching:river-wetland:overview","observe":"在同一缓水河岸比较宽叶香蒲的叶与花穗、绿纹蜻蜓成年雄虫的四翅和牛蛙的岸边位置。水域连接这些生物的生活史，但镜头中的邻近不等于模拟了捕食。可进一步选香蒲或蜻蜓近看。","limit":"九株香蒲、一只蜻蜓与两只既有牛蛙是作者布局，不是实测群落。绿纹蜻蜓的水生幼体、卵、捕食与种间关系没有建模；河道没有流速或水文求解。","source":RiverWetland.DARNER_SOURCE},
			{"id":"cattail","title":"宽叶香蒲：叶与上下花穗","follow":0,"target_id":"3dworld:teaching:broadleaf-cattail:0002","observe":"从泥滩旁挺立的香蒲向上看宽带状叶和棕色柱状雌穗，再看紧邻的较窄上部雄穗。它不是普通草叶；同一株结构可以从整体切到穗近看。","limit":"Typha latifolia原创开花期参考。叶宽、株高、株数、位置与花穗比例为作者设置；没有模拟授粉、种子飞散、根茎扩展或水分吸收。","source":RiverWetland.CATTAIL_SOURCE},
			{"id":"green_darner","title":"绿纹蜻蜓：四翅与水边活动","follow":0,"target_id":"3dworld:teaching:common-green-darner:0000","observe":"近看两对翅、大复眼、绿色胸部与蓝色雄虫腹部；继续或暂停世界时间比较同一只蜻蜓在水边的短程位置。它的幼体生活在水里，但此场景只展示成虫。","limit":"Anax junius成年雄性原创参考；约9.6厘米翅展与18秒短程路线为作者设置。慢速翅动只供观察，未计算气动力、真实飞速、猎物捕获、卵或水生幼体。","source":RiverWetland.DARNER_SOURCE},
			{"id":"freshwater_school","title":"水面之下：淡水鱼小群","follow":0,"target_id":"3dworld:teaching:freshwater-school:overview","observe":"切到水下视角，比较水面上方的香蒲、蜻蜓、岸边牛蛙与水层中的金色鲦。八尾同种个体随唯一世界时间在合成缓流河道中短程游动；可暂停并近看其中一尾。","limit":"金色鲦是新增的一种，不把八尾计作八种。小群数量、排布、约20厘米体长、32秒路线和尾摆均为作者教学设置；这里的水下镜头不表示真实能见度、水流、鱼类密度或食物网计算。","source":FreshwaterFish.HABITAT_SOURCE},
			{"id":"golden_shiner","title":"金色鲦：身体与缓流生境","follow":0,"target_id":"3dworld:teaching:golden-shiner:0000","observe":"观察深体形、橄榄背、银金侧面、小而上翘的口、鳃盖及叉形尾鳍；暂停和继续世界时间，比较同一尾鱼在小群中的位置。","limit":"Notemigonus crysoleucas原创成鱼形态参考，不是标本扫描。鳍条、侧线、大小与摆尾是简化表达；没有游泳水动力、鳃部摄氧、摄食、繁殖、自然密度或水质模型。","source":FreshwaterFish.SOURCE},
			{"id":"wild_celery","title":"美洲苦草：河床上的沉水叶丛","follow":0,"target_id":"3dworld:teaching:wild-celery:clump:0018","observe":"在同一条缓流河道的水下看二十处作者叶丛。近看从河床生出的两处莲座、细长带状叶和相连走茎，再与水层金色鲦比较沉水植物和鱼的位置。","limit":"Vallisneria americana原创形态参考。叶宽约1.2厘米，长度为作者在资料范围内选择；二十处叶丛、位置和轻微摆动不是自然覆盖率或流速测量。未模拟生长、光合作用、植物—鱼栖息地因果或完整水下群落。","source":WildCelery.SOURCE},
			{"id":"wild_celery_leaf","title":"美洲苦草：同株叶与走茎近看","follow":0,"target_id":"3dworld:teaching:wild-celery:leaf","observe":"靠近同一处沉水叶丛，沿基部看两处莲座与连接走茎，再看约1.2厘米宽的带状叶。镜头只是放近，模型维持真实量级。","limit":"本模型的两莲座与十六叶为作者可编辑形态；没有地下根系、花、光合作用、生长、浮动水动力或真实群落覆盖率。","source":WildCelery.SOURCE}])
		topics.append_array([
			{"id":"freshwater_habitats","title":"同一河道：两种鱼怎样分层？","follow":0,"target_id":"3dworld:teaching:freshwater-habitats:comparison","observe":"在同一水下视角比较较深水层的金色鲦、植被边缘近水面的斑纹鳉和河床的美洲苦草。暂停或推进唯一世界时间，再分别近看两种鱼的身体与位置。NPS记录斑纹鳉常在植被附近浅水边缘、近水面成群；金色鲦常见于缓流有水生植被的水域。","limit":"这只是同一合成河道的空间对照：六尾斑纹鳉、八尾金色鲦、二十处苦草的数量和路线均为作者设定。不能据同框推断鱼选择了这株植物、两鱼种存在竞争或捕食，也未模拟食物、水质、水文、真实能见度或自然群落密度。","source":BandedKillifish.SOURCE},
			{"id":"banded_killifish_shoal","title":"斑纹鳉：植被旁近水面的小群","follow":0,"target_id":"3dworld:teaching:banded-killifish:shoal","observe":"看六尾同种小鱼在河道近水面、沉水植物旁的作者短程路线；与较深处体形更高的金色鲦比较水层位置。","limit":"六尾、约11厘米模型体长、22秒路线及尾摆是作者设置；没有同种协调算法、觅食、繁殖、鱼—草栖息地因果或水流求解。","source":BandedKillifish.SOURCE},
			{"id":"banded_killifish","title":"斑纹鳉：近看体侧横纹","follow":0,"target_id":"3dworld:teaching:banded-killifish:0000","observe":"近看细长鱼体、浅色腹部、眼和体侧一条条深色横纹。NPS描述该物种通常有10–20条斑纹；模型选十六条作易辨的作者参考。","limit":"Fundulus diaphanus原创形态参考，不是标本扫描；长度、鳍形、颜色、斑纹间距和摆尾未经个体标定，不计算游泳水动力、食性或野外密度。","source":BandedKillifish.SOURCE}])
	elif id=="desert":
		topics.assign([
			{"id":"desert_iguana","title":"沙漠鬣蜥：身体与灌丛","follow":5,"observe":"观察浅色网纹、钝头、低矮背中线棱鳞与长尾。看四足短行和停步，再切换头背近看；附近三齿拉瑞阿为其常见生境植物。沙漠鬣蜥以植物为主要食物，也吃少量昆虫。","limit":"原创物种参考；14 cm吻肛长、24 cm尾长、个体数量、路径与步态为作者设置。没有模拟摄食消耗、攀爬、体温、繁殖或耐热阈值；当前活动不表示全天候典型行为。","source":Iguana.SOURCE},
			{"id":"desert_cactus","title":"仙人掌：棱脊与刺座","follow":3,"observe":"先近看肉质茎表面的一道道棱脊和刺座，再从观察对象返回整株，看分枝怎样连在主茎上。褶皱能随储水伸缩，刺从刺座伸出。","limit":"巨柱仙人掌Carnegiea gigantea原创静态参考。内部木质支撑肋未剖开显示；外部棱脊不等于木骨架。形态有资料依据，尺寸和刺数为作者设置，未模拟储水、CAM代谢或生长，不由臂数估算年龄。","source":Desert.CACTUS_SOURCE},
			{"id":"desert_leaf","title":"荒漠灌木：成对的小叶","follow":4,"observe":"观察同株三齿拉瑞阿细枝上的两枚小叶，它们在基部相连。镜头靠近毫米级叶片，模型尺寸不变；可从观察对象返回整株，比较灌木与仙人掌的株形。","limit":"Larrea tridentata原创参考；布局和叶片尺寸为作者设置。叶面树脂外观简化，尚未表现花果、气味、雨后响应、根系或生理过程。","source":Desert.SHRUB_SOURCE},
			{"id":"desert_mesquite","title":"牧豆树：冠层、复叶与荚果","follow":7,"observe":"从整株比较分枝木本与仙人掌、灌木；切换观察对象可近看同株成对小叶和弯曲荚果。冠层投下局部疏荫，荚果和种子可成为夜间食籽动物的资源。","limit":"Prosopis velutina原创年轻树参考；株高、复叶数、荚果数与沟缘位置为作者设置。近景每条叶轴示意18对小叶，不是实测个体。与袋鼠鼠主题共用8枚教学种子单位；未模拟真实结荚、植物生长、地下水、取食或萌发。","source":Desert.MESQUITE_ECOLOGY_SOURCE},
			{"id":"desert_ocotillo","title":"Ocotillo：上举的带刺多茎","follow":12,"target_id":"3dworld:teaching:ocotillo:000","observe":"从同株基部看十六根上举弯曲茎，再近看茎刺和梢端红色管状花序。它与巨柱仙人掌的肉质主茎、牧豆树的木本冠层形成不同株形对照。","limit":"Fouquieria splendens原创带花形态参考；六株位置、模型高约3.35–4.08米及十六根茎、刺/花数量均为作者设置。静态花序不表示当前日期的真实花期或当地降雨；没有发叶、传粉、生长或水分模型。","source":Desert.OCOTILLO_SOURCE},
			{"id":"desert_ocotillo_spine","title":"Ocotillo：同株茎刺近看","follow":13,"target_id":"3dworld:teaching:ocotillo:spine","observe":"放近同一株中段茎刺，观察细长分枝上连续的刺；也可退回整株比较与仙人掌刺座不同的外部形态。","limit":"茎刺位置、长度和数量是原创模型的作者参考，不是测量标本；没有模拟刺的发育或对动物的实际防护效果。","source":Desert.OCOTILLO_SOURCE},
			{"id":"desert_ocotillo_flower","title":"Ocotillo：梢端红色花序","follow":14,"target_id":"3dworld:teaching:ocotillo:flower","observe":"看同一株枝梢聚集的红色管状花，理解为什么这类开花个体能在荒漠全景中形成不同色彩和高度层次。","limit":"这是带花形态样本，不根据观察日期、雨量或温度推断现场开花；花序结构和花数为简化参考，没有花蜜、传粉者或繁殖过程。","source":Desert.OCOTILLO_ECOLOGY_SOURCE},
			{"id":"desert_brittlebush","title":"Brittlebush：银灰叶冠与黄色花头","follow":14,"target_id":"3dworld:teaching:brittlebush:000","observe":"从整株比较圆丘形灰白叶冠与仙人掌、三齿拉瑞阿和Ocotillo的不同株形；黄色头状花序举在叶冠上方。再切到同株叶片和花头近看。","limit":"Encelia farinosa原创静态开花形态参考；八株位置、约一米植株、叶与花头数量均为作者设置。灰白绒毛只用表面色泽示意，不模拟真实叶毛、降雨响应、花期、传粉、结实或生长。","source":Desert.BRITTLEBUSH_SOURCE},
			{"id":"desert_brittlebush_leaf","title":"Brittlebush：同株灰白叶片","follow":15,"target_id":"3dworld:teaching:brittlebush:leaf","observe":"靠近同一株枝端灰白、略呈菱形的叶片；与三齿拉瑞阿基部相连的成对小叶比较。镜头放大，叶片模型保持原尺寸。","limit":"叶形、叶数、灰白色和表面质感是资料启发的原创近似，不是标本扫描或显微绒毛；不随水分改变叶色、大小或数量。","source":Desert.BRITTLEBUSH_ECOLOGY_SOURCE},
			{"id":"desert_brittlebush_flower","title":"Brittlebush：同株黄色头状花序","follow":16,"target_id":"3dworld:teaching:brittlebush:flower","observe":"近看同一株高出叶冠的黄色花头：外圈舌状花围着中央盘状花。它与Ocotillo梢端管状花序的形态不同。","limit":"模型每花头15枚外围舌状花与23个花头为作者形态样本；静态开花不表示当前日期的真实花期、降雨或传粉结果。","source":Desert.BRITTLEBUSH_ECOLOGY_SOURCE},
			{"id":"desert_rat","title":"袋鼠鼠怎样带走牧豆树种子","follow":10,"target_id":"3dworld:teaching:merriams-kangaroo-rat:0000","observe":"用“跟随袋鼠鼠”看大后足、长尾、小耳、大眼和颊囊；用“种子与洞口全景”看搬运路线与两端。点击“切至当地夜间观察”，继续世界时间：它从洞口到落地荚果，每次取走1枚教学单位，以颊囊带回洞穴；地表亮点会减少，洞口旁圆盘里的缓存剖面标记会增加。可重置种子示意重复实验。","limit":"当地夜间由观察日期选择，世界时间单独推进；只有荒漠夜间前台观察时教学过程前进，离开或白天冻结。8单位、24秒路线、单次搬运量与洞口旁缓存标记是作者设置，不是实测种子库存、活动率或真实露天贮藏。全景中的连线只是两端与当帧动物的教学指向，不是实测足迹。未模拟摄食消耗、萌发、植物再结荚或种群扩散；辅助光不是月光。","source":KangarooRat.ECOLOGY_SOURCE},
			{"id":"season_light","title":"荒漠：比较夏冬日照","follow":0,"observe":"切换6月与12月近似正午，比较同一地形上的植物阴影、太阳高度和昼长。观察纬度为32°N。","limit":"32°N / 112°W只是合成生境的光照参考。昼长不计折射和地形遮挡；没有模拟气候、季节物候或干旱变化。","source":Seasons.SOURCE}])
	elif id=="polar":
		topics.assign([
			{"id":"ice_krill_habitat","title":"冰磷虾：海冰旁的近岸水下","follow":2,"target_id":"3dworld:teaching:ice-krill:group","observe":"从海岸进入水下，观察约3厘米成体组成的作者小群，再切到同一只成体和头部近看。冰磷虾Euphausia crystallorophias是南极近岸物种，也是阿德利企鹅近岸食物的一种；它与离岸食物中常见的南极磷虾E. superba不是同一物种。","limit":"12只、浅水位置、26秒游动和海冰旁布局为教学设置，不是实测群密度、水深分布或迁移。资料支持食物联系，当前企鹅没有下水捕食，磷虾也不因企鹅、日期或资源数量而增减；水体照明简化。","source":Krill.FOOD_SOURCE},
			{"id":"ice_krill","title":"冰磷虾：3厘米成体近看","follow":3,"target_id":"3dworld:teaching:ice-krill:0000","view_distance":.070,"observe":"近看同一只成体的大圆眼、长尖额剑、触角、分节腹部、游泳足和尾扇。模型本体约3厘米，触角伸出本体；形态近看隔离显示同一个体，回到小群可看其他个体。暂停可观察半透明浅色身体。","limit":"原创参考不是标本扫描；本体跨度、内部带、半透明度及细附肢均有简化。短程游动和1.8 Hz附肢节律为作者动画，不是实测游速、水动力、摄食或光学模型。","source":Krill.SOURCE},
			{"id":"ice_krill_head","title":"冰磷虾：同一成体的大眼与额剑","follow":4,"target_id":"3dworld:teaching:ice-krill:head","view_distance":.024,"observe":"继续靠近小群里同一只成体的头部，比较黑色大圆眼、眼柄与长尖额剑。冰磷虾的较大眼和长尖额剑是形态识别线索。镜头靠近时个体尺寸不变。","limit":"形态来自物种资料与原始比较研究的启发，不是解剖标本、物种鉴定工具或精密眼部测量。视力、光敏、发光器、雌雄和发育阶段未模拟。","source":Krill.MORPHOLOGY_SOURCE},
			{"id":"polar_coast","title":"南极海岸：裸岩、海水与海冰","follow":0,"target_id":"3dworld:teaching:polar-coast:overview","observe":"沿同一海岸视角比较深色裸岩、海水和不规则海冰，再走近岸上的阿德利企鹅。冰与水亮度差异便于认识海冰的高反照率；海冰块是作者固定空间参考。","limit":"66.5°S只用于日照教学，场景不是已测绘地点。12块冰的形状、位置和数量不是卫星海冰范围，也不随日期融冻、漂移或形成；不能据此推断极地气候趋势。","source":Polar.ICE_SOURCE},
			{"id":"adelie_penguin","title":"阿德利企鹅：形态与岸水活动","follow":1,"target_id":"3dworld:teaching:adelie-penguin:0000","view_distance":1.55,"observe":"形态近看约70厘米成鸟的白眼环、黑背白腹和鳍状翼。跟随往返看原第3只迈足、入水、水平鳍划水与上岸；岸水全景看同一路线。继续或调节世界时间，暂停比较姿态；切镜头不改时间。","limit":"四只同种、岸位、80世界秒往返和鳍足节律是作者演示，不是实测活动率/追踪、浮力或水动力。资料支持步游与鳍推进；未模拟取食、繁殖、筑巢、深潜或日期对应的在场/海冰状态。其他两只短步及一只静态保持原参考。","source":Polar.PENGUIN_SOURCE},
			{"id":"season_light","title":"南极海岸：比较两半球日照","follow":0,"observe":"在同一合成海岸切换6月与12月的近似当地正午，比较太阳高度和昼长。南半球季节与北半球相反；极圈附近的日照变化更强。","limit":"66.5°S是教学纬度而非地点定位；昼长忽略折射、真实地形和天气。裸岩、海冰与企鹅固定，不随日期进入真实季节状态。","source":Seasons.SOURCE}])
		topics.append({"id":"polar_aurora","title":"南极夜空：极光与冰川剪影","follow":7,"target_id":"3dworld:teaching:antarctic-sky:overview","observe":"抬头环绕冰川上方夜空，选择冬季午夜示例，看绿色与紫色极光光幕；继续或暂停世界时间比较其舒展。恒星读取原J2000明亮星表与共同日期，白昼时光幕隐藏。","limit":"极光形状、亮度和摆动是作者演示，不是当日发生概率、空间天气或肉眼曝光。冰川与海冰固定；未模拟粒子、磁场、发射高度或融冻，星位忽略折射与精密地球定向。","source":Polar.PolarEnvironment.AURORA_SOURCE})
	elif id=="arctic":
		topics.assign([
			{"id":"arctic_ice","title":"北冰洋：海冰、冰脊与开阔水面","follow":0,"target_id":"3dworld:teaching:arctic-sea-ice:overview","observe":"环绕积雪海冰，观察蓝冰断面、起伏冰脊与冰间水道。比较地球上北极海洋和南极大陆的不同空间背景，再进入各自的场景。","limit":"78°N/0°用于日照和星位。形体、海冰范围与表面波纹为固定作者参考，没有实时冰况、融冻、海流或漂移，也不是实地定位。未加入北极动物群落。","source":Polar.PolarEnvironment.POLES_SOURCE},
			{"id":"polar_aurora","title":"北极夜空：极光光幕与恒星","follow":1,"target_id":"3dworld:teaching:arctic-sky:overview","observe":"抬头环绕夜空，选择冬季午夜示例，看绿色与紫色极光光幕；继续或暂停世界时间比较其舒展。恒星方向读取原J2000明亮星表与共同日期，白昼时光幕隐藏。","limit":"极光是作者演示，亮度、形状和摆动不是当日发生概率、空间天气或肉眼曝光。氧和氮可产生不同颜色，但这里未模拟粒子、磁场或发射高度。星位忽略折射与精密地球定向。","source":Polar.PolarEnvironment.AURORA_SOURCE},
			{"id":"season_light","title":"北极日照：极昼与极夜","follow":0,"observe":"切换6月与12月的近似当地正午，比较78°N的太阳高度与昼长。再返回地球，到南极观察相反的季节日照。","limit":"经纬度是教学参考，忽略折射、天气、真实地形和精密地球定向。日期不预测海冰范围或极光。","source":Seasons.SOURCE}])
	elif id=="city":
		topics.assign([
			{"id":"runoff","title":"雨水去了哪里：硬地与绿地","follow":7,"observe":"点击3D局部实验阀门开启降雨并继续时间，看同量雨水落在两块9m²地表；用两条水量条比较暂存、土壤现存、累计径流和深排水。硬地较快流出；绿地先入渗，土壤接近饱和后也产生径流。停雨后观察排水继续。","limit":"1世界秒对应1示意分钟，雨强36mm/h、储水容量等均为作者参数。水量条按未舍入水量画占比，升数四舍五入；入渗是内部转移，不再加作第五出口。水滴、湿润面与土层颜色是放大的路径/储量符号，不是实际滴数或水深。未计蒸散、管网或空间汇流，不作城市洪水预测。","source":Runoff.Model.SOURCE},
			{"id":"crossing","title":"步行变慢，路口怎样留出时间？","follow":5,"observe":"在同一条路线比较16秒与24秒方案。选择会重启本路口；继续世界时间，看较慢步行怎样延长清空时段与横向红灯，再用下方时间控件暂停比较同一行人和车队。","limit":"16.4米是包含坡道的平面路线；平均速度不是瞬时步速。16/24秒、48/56秒周期与2秒开始窗口均为作者规则。只有既有直行车，不是实测行为、现实过街指导、配时标准或拥堵预测。","source":Crossing.Lesson.SOURCE},
			{"id":"traffic","title":"信号怎样组织通行","follow":5,"observe":"绿条表示横向通行，蓝条表示纵向与行人时段，灰条表示清空；白线是当前相位。比较两种步行用时，观察实际信号、车辆停等与行人完成过街。","limit":"选择方案或重启只重置本路口，不改世界时间和其他实验；默认48秒、慢行56秒均是作者分相。平均速度用平面路线计算，没有转弯、感知避让、车流校准或安全设计认证。","source":Crossing.Lesson.SOURCE},
			{"id":"solar_roof","title":"太阳角度与屋顶受光","follow":4,"observe":"改变观察时间，比较阳光与面板法线的夹角。法线是垂直于面板的方向。","limit":"只算直射光几何系数0–1；未计天气、遮挡、漫射或设备效率，不是发电量。","source":Solar.SOURCE},
			{"id":"street","title":"街道与步行空间","follow":3,"observe":"环绕临街建筑，找到入口、檐棚、人行道和车道，比较它们如何组织不同活动。","limit":"这是合成街区，建筑与人口不是现实地点的数据。","source":""},
			{"id":"street_walkers","title":"街道人行道：走近同一位行人","follow":0,"target_id":"3dworld:teaching:street-walker:0000","observe":"近看行人的服饰、身体朝向和脚步，再与铺装人行道和车道比较。对象列表可切换六位街道行人；暂停、继续或调整世界时间，镜头仍跟随所选的同一个体。","limit":"六位合成人物的外观、身形、数量和路线为作者设置；不代表现实人口、个人身份、年龄或性别分布。没有模拟避让、社会行为或人体动力学。","source":""},
			{"id":"city_sparrow","title":"城市公园：树麻雀与行人","follow":8,"observe":"近看栗色头顶、白颊黑斑和短圆锥喙。继续世界时间，读出最近公园行人的场景距离；行人靠近时鸟暂停啄食，并在草地内小幅让开。对照行人远离时恢复地面查看。","limit":"Passer montanus原创成鸟形态参考；四只数量、位置、18秒短跳和3.2–3.7米警觉区间及最多0.27米让开均是作者教学参数，不是研究中的起飞距离。这里只表示近距离警觉，不模拟真实惊飞、学习、应激、食物消耗、迁移、繁殖或种群变化；合成城市坐标不是实测分布。","source":CitySparrow.HUMAN_RESPONSE_SOURCE},
			{"id":"city_monarch","title":"城市种植片区：帝王蝶访花","follow":0,"target_id":"3dworld:teaching:city-monarch:0000","view_distance":1.2,"observe":"在公园步道旁的种植片区，近看帝王蝶成虫停在普通乳草花序上，再随同一世界时间飞离、返回。成虫可吸食花蜜；同种幼虫取食乳草叶片，但这里没有幼虫个体。","limit":"两只帝王蝶、四株普通乳草及位置、花期和40秒路线是合成教学设置。普通乳草为北美物种样本，不表示光照参考坐标的本地植物或种植建议。访花不等于已模拟花蜜消耗、花粉转移、授粉、繁殖或迁徙。","source":Pollinators.URBAN_GARDEN_SOURCE},
			{"id":"city_milkweed","title":"城市种植片区：普通乳草","follow":0,"target_id":"3dworld:teaching:city-milkweed:0000","observe":"看同一株普通乳草的对生叶和粉色花序，再观察一只帝王蝶停留的位置。栽植的开花植物可提供成虫花蜜，乳草叶片是帝王蝶幼虫的食物。","limit":"植株是北美普通乳草的原创形态参考；种植片区与带花状态为作者设置，不随城市观察日期变化。不推断本地适种性、幼虫存活率或真实花蜜/授粉量。","source":Pollinators.PLANT_SOURCE},
			{"id":"city_ginkgo_leaf","title":"城市公园的银杏扇叶","follow":10,"observe":"有叶期近看同一株种植幼树上的扇形叶。沿叶柄到扇面，找中央凹口和向外分叉的叶脉；冬季枝形期可用下方按钮切回夏季。","limit":"Ginkgo biloba原创幼树形态参考；两株位置、约5米树高、叶宽与叶数均为作者设置。绿叶、金叶与落叶时段只是教学日历，不是当地实测物候；没有计算树龄、雌雄或结实，也不声称银杏是场景内麻雀的食物。","source":CityGinkgo.SOURCE},
			{"id":"city_ginkgo_season","title":"银杏：绿叶、金黄与落叶","follow":9,"observe":"保持同一株树和同一街区，切换夏季绿叶、深秋金黄与冬季枝形，比较树冠轮廓和地面日照。再选扇叶近看结构。","limit":"NC State与密苏里植物园支持银杏落叶及秋季金黄；具体月界是作者为了35°N合成公园设定的可见阶段，并非气温、日长、品种或当地物候预测。匿名背景树未随日期变化；没有模拟落叶轨迹、堆积、树木生长或繁殖。","source":CityGinkgo.SOURCE},
			{"id":"city_park_trees","title":"城市公园：春花与秋色","follow":11,"observe":"同一公园比较红枫与东部紫荆：春季紫荆先花后叶，夏季看两种叶形，深秋看枫红与紫荆黄叶，冬季看枝形。已有银杏也读取同一观察日期。","limit":"Acer rubrum与Cercis canadensis为原创种植幼树参考；两株的位置、尺寸、叶/花数量和具体季节日界均为作者设置，不是当地实测物候。无气温、雨水、生长、传粉或鸟—树食物关系模拟。","source":CityParkTrees.SOURCE_REDBUD},
			{"id":"city_maple_leaf","title":"红枫：同株掌状裂叶","follow":13,"observe":"在同一株红枫上看对生叶柄、3–5主裂片和粗齿轮廓；可回到整株与紫荆比较。冬季可切到夏季看叶。","limit":"原创示范叶约17.7厘米宽，叶脉与齿缘简化；不是标本扫描或完整野外鉴定，不模拟真实落叶时间。","source":CityParkTrees.SOURCE_MAPLE},
			{"id":"city_redbud_bloom","title":"东部紫荆：叶前粉紫花","follow":15,"observe":"切至春季，近看枝上粉紫花簇；再切夏季比较同株心形叶。花簇是真实模型上的作者示意。","limit":"具体花期、花数及花瓣形状为作者设计，不是当地开花预报；没有传粉、结实或花粉转移计算。","source":CityParkTrees.SOURCE_REDBUD},
			{"id":"city_redbud_leaf","title":"东部紫荆：心形叶","follow":16,"observe":"切至夏季，在同一株紫荆上近看互生心形全缘叶，再与红枫裂叶比较。","limit":"原创示范叶约17厘米宽，叶脉与位置是参考简化；没有模拟生长、温度或实际物候。","source":CityParkTrees.SOURCE_REDBUD},
			{"id":"city_pond","title":"城市池塘：雌雄绿头鸭与岸边植物","follow":0,"target_id":"3dworld:teaching:city-pond:overview","observe":"从池塘全景比较同种绿头鸭雄鸟和雌鸟的羽色，再看岸边挺水香蒲。保留水面参照，观察两只鸟沿有限路线相隔游动。","limit":"一对绿头鸭和三株香蒲为合成公园的教学布局，不能据此推断自然配对、种群或栖息地质量。池水是静态可视面，未计算水深、水质或食物资源；香蒲模型复用既有林地物种。","source":CityPondMallard.SOURCE},
			{"id":"city_mallard_drake","title":"绿头鸭雄鸟：繁殖羽与翼镜","follow":0,"target_id":"3dworld:teaching:city-mallard:0000","view_distance":1.35,"observe":"近看绿色头部、白颈环、栗色前胸、黄色宽扁喙和白边蓝色翼镜；从全景再与雌鸟对照。继续世界时间可见短暂低头接近水面。","limit":"0.64米原创成年繁殖羽形态参考，非扫描标本；静态羽色不随观察日期换羽。48秒池内路线、两只数量和低头间隔是作者设置；低头不表示已捕获食物、消耗资源或模拟真实水动力。","source":CityPondMallard.SOURCE},
			{"id":"city_mallard_hen","title":"绿头鸭雌鸟：斑驳羽色与翼镜","follow":0,"target_id":"3dworld:teaching:city-mallard:0001","view_distance":1.35,"observe":"近看棕褐斑驳体羽、橙黑色宽扁喙和同样带白边的蓝色翼镜，比较同种雄鸟繁殖羽的显著色差。","limit":"原创成年雌鸟参考，非实测个体；斑纹图案、两只数量、游动/低头节律为作者设计。没有求解生殖、配对、换羽、觅食收支、水质或完整城市生态。","source":CityPondMallard.SOURCE}])
	if id in ["reef","woodland"]: topics.append(TurtleComparison.definition(id))
	return topics

static func solar_sample(host: Node) -> Dictionary:
	var stage: Node = host.coordinator.active_scene
	var targets: Array[Dictionary] = stage.get_meta("urban_targets",[])
	if targets.size()<2: return {"valid":false}
	var building: Node3D = targets[1].node
	var normal: Vector3 = building.get_meta("solar_normal_world",Vector3.UP)
	var site: Dictionary = Sites.for_scale("city")
	var sun: Vector3 = Orientation.local_sun(host.solar_jd,site.lat,site.lon)
	var value: Dictionary = Solar.sample(sun,normal)
	value["sun"] = sun
	value["normal"] = normal
	value["anchor"] = building.get_meta("solar_anchor_world",building.position+Vector3(0,16.0,0))
	return value

static func readout(host: Node, topic: String) -> String:
	if topic=="ground_sky": return "24.6272°S / 70.4044°W · 2635米参考海拔\n"+host.Orientation.timestamp(host.solar_jd)+"\n太阳高度 %.1f° · 视野 %.1f°\n8404颗亮星参考 · 银河曝光增强" % [float(host.coordinator.active_scene.get_meta("sun_elevation",0.0)),host.coordinator.active_scene.camera.fov]
	if topic in ["black_sea_cucumber","black_sea_cucumber_feeding"]: return BlackSeaCucumber.Activity.readout(host)
	if topic in TurtleComparison.TOPICS: return TurtleComparison.readout(host,topic)
	if topic == "adelie_penguin": return Polar.Adelie.readout(host)
	if topic in ["red_fox","red_fox_head"]: return RedFox.readout(host,topic)
	if topic in ["box_turtle","box_turtle_head"]: return BoxTurtle.readout(host,topic)
	if topic == "street_walkers": return "六位街道参考人物 · 同一世界时间\n暂停看脚步，继续看步道上的位置变化"
	if topic in ["ice_krill_habitat","ice_krill","ice_krill_head"]: return Krill.readout(host,topic)
	if topic in ["day_octopus","day_octopus_suckers"]: return Octopus.readout(host)
	if topic in ["river_wetland","cattail","green_darner"]: return RiverWetland.readout(host,topic)
	if topic in ["freshwater_school","golden_shiner"]: return FreshwaterFish.readout(host,topic)
	if topic in ["wild_celery","wild_celery_leaf"]: return WildCelery.readout(host,topic)
	if topic in ["freshwater_habitats","banded_killifish_shoal","banded_killifish"]: return BandedKillifish.readout(host,topic)
	if topic=="city_ginkgo_season" or topic=="city_ginkgo_leaf": return Orientation.timestamp(host.solar_jd)+"\n"+CityGinkgo.season_label(CityGinkgo.season(host.solar_jd))+" · 同一天文日期驱动"
	if topic in ["city_park_trees","city_maple_leaf","city_redbud_bloom","city_redbud_leaf"]: return Orientation.timestamp(host.solar_jd)+"\n"+CityParkTrees.phase_label(CityParkTrees.phase(host.solar_jd))+" · 同一天文日期驱动"
	if topic=="algae": return Algae.readout(host)
	if topic=="turtle_surface": return Turtle.readout(host.content_targets()[3].node,host.world.simulation_time_s)
	if topic=="school": return School.readout(host)
	if topic=="deadwood": return Deadwood.readout(host)
	if topic=="fungus": return Fungi.readout(host)
	if topic=="coral_symbiosis": return Coral.symbiosis_readout(host)
	if topic=="jovian_periods": return Jovian.readout(host)
	if topic=="desert_iguana": return Iguana.readout(host)
	if topic=="bullfrog": return Frogs.readout(host)
	if topic=="galactic_structure": return Galactic.readout(host)
	if topic=="lunar_phases": return Lunar.readout(host)
	if topic=="runoff": return Runoff.readout(host)
	if topic=="browse": return Browse.readout(host)
	if topic in MonarchStages.TOPICS: return MonarchStages.readout(host,topic)
	if topic=="city_monarch": return Pollinators.readout(host)
	if topic=="city_milkweed": return "普通乳草 · 对生叶与花序\n四株为合成城市里的种植教学样本；花期固定，不是本地植物推荐"
	if topic in ["city_pond","city_mallard_drake","city_mallard_hen"]: return CityPondMallard.readout(host,topic)
	if topic=="mercury_orbit": return Kepler.readout(host)
	if topic=="desert_rat":
		var stage: Node=host.coordinator.active_scene
		var light_status: String="固定展示光照 · 点击按钮观察夜间" if not host.ground_light_preview else ("当地夜间 · 辅助观察光" if bool(stage.get_meta("kangaroo_rat_night",false)) else "当地白天 · 静态形态参考")
		var time_status: String=" · 按空格继续世界时间" if host.world.paused else ""
		var seeds: Dictionary=host.world.desert_seeds.snapshot()
		return light_status+time_status+"\n地表 %d · 颊囊 %d · 洞穴 %d / %d 教学单位\n%s" % [int(seeds.ground_units),int(seeds.pouch_units),int(seeds.cache_units),host.world.desert_seeds.INITIAL_UNITS,str(stage.get_meta("kangaroo_rat").get_meta("activity","观察结构与空间"))]
	if topic=="season_light": return Seasons.readout(host)
	if topic=="snapper":
		var fish: Node3D = host.content_targets()[1].node
		return "%s\n与其余群体中心距离 %.2f m（场景尺度）" % [fish.get_meta("activity","集群"),float(fish.get_meta("group_distance_m",0.0))]
	if topic=="solar_roof":
		var value: Dictionary = solar_sample(host)
		if not value.get("valid",false): return "面板几何尚未就绪"
		return "入射角 %.1f° · 直射几何系数 %.2f\n%s\n%s" % [value.angle_deg,value.factor,"太阳在地平线上方" if value.above_horizon else "太阳已在地平线下，直射项为0",Seasons.readout(host)]
	if topic=="city_sparrow":
		var sparrows: Array=host.coordinator.active_scene.get_meta("city_sparrows",[])
		if sparrows.is_empty(): return "树麻雀尚未就绪"
		var sparrow: Node3D=sparrows[0]
		return "%s\n最近公园行人 %.2f m（合成场景）\n继续或暂停世界时间，对照行人靠近与远离" % [str(sparrow.get_meta("activity","地面查看")),float(sparrow.get_meta("nearest_pedestrian_m",0.0))]
	if topic in ["traffic","crossing"]: return Crossing.readout(host)
	var targets: Array[Dictionary] = host.content_targets()
	var index: int = host._content_follow
	if topic=="bird" and index>=0 and index<targets.size():
		var bird: Node3D = targets[index].node
		var height: float = float(bird.get_meta("height_above_ground_m",0.0))
		var height_text: String = "<0.01" if height>0 and height<.01 else "%.2f" % height
		return "%s\n路线离地高度 %s m（场景尺度）" % [bird.get_meta("activity","地面观察"),height_text]
	return str(targets[index].node.get_meta("activity","观察结构与空间")) if index>=0 and index<targets.size() else "选择主题开始观察"

static func marks(host: Node, topic: String) -> Array[Dictionary]:
	if topic in TurtleComparison.TOPICS: return TurtleComparison.marks(host,topic)
	if topic=="earth_daylight": return EarthDaylight.marks(host)
	if topic == "adelie_penguin": return Polar.Adelie.marks(host)
	if topic in ["red_fox","red_fox_head"]: return RedFox.marks(host,topic)
	if topic in ["box_turtle","box_turtle_head"]: return BoxTurtle.marks(host,topic)
	if topic in ["ice_krill_habitat","ice_krill","ice_krill_head"]: return Krill.marks(host,topic)
	if topic in ["river_wetland","cattail","green_darner"]: return RiverWetland.marks(host,topic)
	if topic in ["freshwater_school","golden_shiner"]: return FreshwaterFish.marks(host,topic)
	if topic in ["wild_celery","wild_celery_leaf"]: return WildCelery.marks(host,topic)
	if topic in ["freshwater_habitats","banded_killifish_shoal","banded_killifish"]: return BandedKillifish.marks(host,topic)
	if topic=="algae": return Algae.marks(host)
	if topic=="desert_rat":
		var desert: Node=host.coordinator.active_scene
		var seeds: Dictionary=host.world.desert_seeds.snapshot()
		var rat: Node3D=desert.get_meta("kangaroo_rat")
		if desert.camera.position.distance_to(rat.position)<=1.5:
			return [{"at":rat.global_position+Vector3(0,.13,0),"label":"颊囊教学单位 · %d" % int(seeds.pouch_units),"offset":Vector2(85,-90)}]
		var night: bool=bool(desert.get_meta("kangaroo_rat_night",false))
		var carrying: bool=bool(rat.get_meta("motion_sample",{}).get("carrying",false))
		var label: String="袋鼠鼠 · 夜间才搬运"
		if night:
			if carrying: label="袋鼠鼠 · 携种回洞"
			elif int(seeds.ground_units)==0: label="袋鼠鼠 · 搬运完成"
			elif rat.position.distance_to(desert.get_meta("kangaroo_rat_pod").position)<.25: label="袋鼠鼠 · 地表取种"
			else: label="袋鼠鼠 · 前往种子"
		var rat_mark: Dictionary={"at":rat.global_position+Vector3(0,.12,0),"label":label,"offset":Vector2(-150,50)}
		if night and carrying: rat_mark["link"]=1
		elif night and int(seeds.ground_units)>0: rat_mark["link"]=0
		return [{"at":desert.get_meta("kangaroo_rat_pod").global_position+Vector3(0,.025,0),"label":"地表教学种子 · %d" % int(seeds.ground_units),"offset":Vector2(20,-80)},
			{"at":desert.get_meta("kangaroo_rat_cache_display").global_position+Vector3(0,.035,0),"label":"洞穴缓存剖面 · %d" % int(seeds.cache_units),"offset":Vector2(-205,-95)},rat_mark]
	if topic in ["desert_cactus","desert_leaf"]: return Desert.marks(host,topic)
	if topic=="school": return School.marks(host)
	if topic=="deadwood": return Deadwood.marks(host)
	if topic=="fungus": return Fungi.marks(host)
	if topic=="desert_iguana": return Iguana.marks(host)
	if topic=="bullfrog": return Frogs.marks(host)
	if topic=="galactic_structure": return Galactic.marks(host)
	if topic=="lunar_phases": return Lunar.marks(host)
	if topic in ["monarch_egg","monarch_pupa"]: return MonarchStages.marks(host,topic)
	if topic=="monarch_larva": return Larva.marks(host)
	if topic=="monarch": return Pollinators.marks(host)
	if topic=="city_monarch": return Pollinators.marks(host)
	if topic in ["city_pond","city_mallard_drake","city_mallard_hen"]: return CityPondMallard.marks(host,topic)
	if topic=="mercury_orbit": return Kepler.marks(host)
	var marks: Array[Dictionary] = []
	var targets: Array[Dictionary] = host.content_targets()
	var index: int = host._content_follow
	if index<0 or index>=targets.size(): return marks
	var node: Node3D = targets[index].node
	var stage: Node = host.coordinator.active_scene
	match topic:
		"seagrass", "seagrass_leaf":
			return Seagrass.marks(stage,topic=="seagrass_leaf")
		"coral_symbiosis":
			return Coral.symbiosis_marks(stage)
		"runoff":
			return Runoff.marks(stage)
		"coral_colony", "coral_polyp":
			return Coral.marks(stage,topic=="coral_polyp")
		"browse":
			return Browse.marks(stage)
		"turtle_surface":
			return Turtle.surface_marks(node,host.world.simulation_time_s)
		"turtle":
			return Turtle.marks(node)
		"urchin":
			return Urchin.marks(host)
		"giant_clam", "giant_clam_mantle":
			return Clam.marks(host,topic=="giant_clam_mantle")
		"black_sea_cucumber", "black_sea_cucumber_feeding":
			return BlackSeaCucumber.marks(host,topic=="black_sea_cucumber_feeding")
		"day_octopus", "day_octopus_suckers":
			return Octopus.marks(host, topic == "day_octopus_suckers")
		"oak_leaf", "pine_needles", "city_ginkgo_leaf", "city_maple_leaf", "city_redbud_bloom", "city_redbud_leaf", "city_milkweed":
			marks.assign(node.get_meta("plant_markers",[]))
		"snapper":
			marks.append({"at":node.position,"label":"四带笛鲷 · 代表个体","offset":Vector2(45,-85)})
			marks.append({"at":stage.get_meta("snapper_group_center",node.position),"label":"其余11尾的中心 · 观察辅助","offset":Vector2(-100,55),"link":0})
		"school":
			marks.append({"at":node.position,"label":"青绿雀鲷 · 水层取食","offset":Vector2(50,-80)})
		"ray":
			return RayObservation.marks(node)
		"graze":
			var mouth: Vector3 = DeerSkin.muzzle(node)
			marks.append({"at":mouth,"label":"嘴部 · 接近植物" if float(node.get_meta("grazing",0.))>.9 else "嘴部 · 植物食物","offset":Vector2(95,-55)})
			marks.append({"at":DeerSkin.point(node,"ForeLHoof",Vector3(.368,.052,.153)),"label":"分趾蹄 · 支撑与移动","offset":Vector2(-115,65)})
			var ground: Vector3 = Vector3(mouth.x,stage.builder._height(mouth.x,mouth.z)+.04,mouth.z)
			marks.append({"at":ground,"label":"地表植物 · 食物示意","offset":Vector2(115,80),"link":0})
		"bird":
			var bill_at: Vector3 = RobinSkin.point(node,"Head",Vector3(.087,.148,0)) if node.has_meta("robin_skin") else mesh_center(node,"UpperBill",Vector3(.075,.148,0))
			var wing_at: Vector3 = RobinSkin.point(node,"WingLFore",Vector3(-.040,.124,.070)) if node.has_meta("robin_skin") else mesh_center(node,"WingCoverts",Vector3(-.02,.12,.05))
			# Put the wing label away from the head when the animal turns in a narrow view.
			var facing_left: bool = stage.camera.unproject_position(bill_at).x<stage.camera.unproject_position(wing_at).x
			marks.append({"at":bill_at,"label":"喙 · 取食","offset":Vector2(95,-90)})
			marks.append({"at":wing_at,"label":"翼 · 收拢 / 拍动","offset":Vector2(95,-75) if facing_left else Vector2(-140,-55)})
			marks.append({"at":RobinSkin.point(node,"FootL",Vector3(.012,.003,.015)) if node.has_meta("robin_skin") else mesh_center(node,"Toe",Vector3(0,.02,0)),"label":"足 · 收起" if float(node.get_meta("height_above_ground_m",0.0))>.24 else "足 · 伸足接近地面" if float(node.get_meta("height_above_ground_m",0.0))>0 else "足 · 地面支撑","offset":Vector2(45,65)})
		"crossing":
			return Crossing.marks(host)
		"traffic":
			var car: Node3D = host.content_targets()[1].node
			marks.append({"at":car.position+Vector3(0,1.3,0),"label":str(car.get_meta("activity","车辆")),"offset":Vector2(55,-85)})
			marks.append({"at":Vector3(-13.6,.07,3.0),"label":"停止边界 · 人行横道前","offset":Vector2(40,55)})
		"solar_roof":
			var value: Dictionary = solar_sample(host)
			if not value.get("valid",false): return marks
			marks.append({"at":value.anchor,"label":"屋顶面板","offset":Vector2(60,75)})
			marks.append({"at":value.anchor+value.normal*4.0,"label":"面板法线","offset":Vector2(-110,-65),"link":0})
			if value.above_horizon: marks.append({"at":value.anchor+value.sun*5.0,"label":"指向太阳","offset":Vector2(100,-45),"link":0})
		"street":
			marks.append({"at":node.position+Vector3(0,2.6,-5.9),"label":"入口与檐棚","offset":Vector2(45,-40)})
			marks.append({"at":node.position+Vector3(0,.18,-9.5),"label":"步行空间","offset":Vector2(80,55)})
		"city_sparrow":
			marks.append({"at":node.to_global(Vector3(.041,.121,0)),"label":"栗色头顶","offset":Vector2(90,-70)})
			marks.append({"at":node.to_global(Vector3(.039,.101,.026)),"label":"白颊黑斑","offset":Vector2(-145,-25)})
			marks.append({"at":node.to_global(Vector3(.070,.103,0)),"label":"短圆锥喙","offset":Vector2(80,45)})
			var walker_distance: float=float(node.get_meta("nearest_pedestrian_m",INF))
			if walker_distance<5.0:
				var walker_at: Vector3=node.get_meta("nearest_pedestrian_at",Vector3.ZERO)
				marks.append({"at":walker_at+Vector3(0,1.5,0),"label":"最近行人 · %.1f m" % walker_distance,"offset":Vector2(70,-65),"link":0})
	return marks

static func mesh_center(root: Node3D, mesh_name: String, fallback: Vector3) -> Vector3:
	var mesh: MeshInstance3D = root.find_child(mesh_name,true,false) as MeshInstance3D
	return mesh.to_global(mesh.get_aabb().get_center()) if mesh!=null else root.to_global(fallback)
