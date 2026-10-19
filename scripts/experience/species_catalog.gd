extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Curated entries point to existing observations and own no simulation state.
const AREAS: Dictionary = {"reef":"海洋", "woodland":"林地与河岸", "desert":"荒漠", "city":"城市", "polar":"南极海岸"}
const KINDS: Dictionary = {"fish":"鱼类", "mammal":"哺乳类", "bird":"鸟类", "reptile":"爬行类", "amphibian":"两栖类", "insect":"昆虫", "invertebrate":"其他无脊椎动物", "plant":"植物", "fungus":"真菌"}
const ENTRIES: Array[Dictionary] = [
	{"id":"percula", "name":"海葵双锯鱼", "scientific":"Amphiprion percula", "kind":"fish", "scale":"fish", "topic":"", "detail":"近看目标鱼，再沿它深入心脏与细胞。", "view":"观察鱼体"},
	{"id":"scopas", "name":"褐吊", "scientific":"Zebrasoma scopas", "kind":"fish", "scale":"reef", "topic":"algae", "detail":"比较深浅体色、尾柄与藻毯取食入口。", "view":"观察鱼体"},
	{"id":"kasmira", "name":"四带笛鲷", "scientific":"Lutjanus kasmira", "kind":"fish", "scale":"reef", "topic":"snapper", "detail":"观察黄色身体、蓝色纵纹与小群活动。", "view":"观察鱼群"},
	{"id":"viridis", "name":"青绿雀鲷", "scientific":"Chromis viridis", "kind":"fish", "scale":"reef", "topic":"school", "detail":"走近水层小鱼群，比较邻近响应。", "view":"观察鱼群"},
	{"id":"mydas", "name":"绿海龟", "scientific":"Chelonia mydas", "kind":"reptile", "scale":"reef", "topic":"turtle", "detail":"观察背甲、四鳍与划水、滑行姿态。", "view":"观察海龟"},
	{"id":"lymma", "name":"蓝斑条尾魟", "scientific":"Taeniura lymma", "kind":"fish", "scale":"reef", "topic":"ray", "detail":"比较贴底身体、蓝斑与胸鳍波动。", "view":"观察魟"},
	{"id":"setosum", "name":"长刺海胆", "scientific":"Diadema setosum", "kind":"invertebrate", "scale":"reef", "topic":"urchin", "detail":"看长棘、顶端白斑与橙色环。", "view":"观察海胆"},
	{"id":"maxima", "name":"砗磲", "scientific":"Tridacna maxima", "kind":"invertebrate", "scale":"reef", "topic":"giant_clam", "detail":"看两侧壳瓣、外鳞片与朝上的外套膜。", "view":"观察砗磲"},
	{"id":"atra", "name":"黑海参", "scientific":"Holothuria atra", "kind":"invertebrate", "scale":"reef", "topic":"black_sea_cucumber", "detail":"看筒状身体、砂覆与露肤，再走近摄食端。", "view":"观察海参"},
	{"id":"cyanea", "name":"日间章鱼", "scientific":"Octopus cyanea", "kind":"invertebrate", "scale":"reef", "topic":"day_octopus", "detail":"近看八腕、外套膜与同一条腕的双列吸盘。", "view":"观察章鱼"},
	{"id":"millepora", "name":"分枝石珊瑚", "scientific":"Acropora millepora", "kind":"invertebrate", "scale":"reef", "topic":"coral_colony", "detail":"从分枝群体继续走近单个珊瑚虫。", "view":"观察珊瑚群体"},
	{"id":"ovalis", "name":"卵叶喜盐草", "scientific":"Halophila ovalis", "kind":"plant", "scale":"reef", "topic":"seagrass_leaf", "detail":"看成对叶片与叶脉，它是海洋开花植物。", "view":"观察海草叶片"},
	{"id":"virginianus", "name":"白尾鹿", "scientific":"Odocoileus virginianus", "kind":"mammal", "scale":"woodland", "topic":"graze", "detail":"比较身体、四足与林地低头、短行活动。", "view":"观察鹿"},
	{"id":"vulpes", "name":"赤狐", "scientific":"Vulpes vulpes", "kind":"mammal", "scale":"woodland", "topic":"red_fox", "detail":"看林缘犬科的尖吻、深色下肢、白尾端和同一个体近景。", "view":"观察赤狐"},
	{"id":"carolina", "name":"东部箱龟", "scientific":"Terrapene carolina carolina", "kind":"reptile", "scale":"woodland", "topic":"box_turtle", "detail":"看高拱背甲、黄橙斑纹与有趾足，再走近同一只头部。", "view":"观察箱龟"},
	{"id":"migratorius", "name":"美洲知更鸟", "scientific":"Turdus migratorius", "kind":"bird", "scale":"woodland", "topic":"bird", "detail":"看胸腹羽色与起降、展收翼姿态。", "view":"观察鸟"},
	{"id":"plexippus", "name":"帝王蝶", "scientific":"Danaus plexippus", "kind":"insect", "scale":"woodland", "topic":"monarch_egg", "detail":"比较卵、叶面幼虫、悬挂蛹与成蝶四阶段；同种只列一次。", "view":"观察生命阶段"},
	{"id":"alba", "name":"北美白橡", "scientific":"Quercus alba", "kind":"plant", "scale":"woodland", "topic":"oak_leaf", "detail":"走近参考幼树上的圆裂片叶。", "view":"观察叶片"},
	{"id":"strobus", "name":"东部白松", "scientific":"Pinus strobus", "kind":"plant", "scale":"woodland", "topic":"pine_needles", "detail":"看同一枝上的五针一束，与阔叶比较。", "view":"观察针叶"},
	{"id":"syriaca", "name":"普通乳草", "scientific":"Asclepias syriaca", "kind":"plant", "scale":"city", "topic":"city_milkweed", "detail":"近看对生叶与花序；林地也有同种参考。", "view":"观察植株"},
	{"id":"catesbeianus", "name":"美洲牛蛙", "scientific":"Lithobates catesbeianus", "kind":"amphibian", "scale":"woodland", "topic":"bullfrog", "detail":"成年雄性参考：鼓膜、黄色喉部与后足。", "view":"观察牛蛙"},
	{"id":"latifolia", "name":"宽叶香蒲", "scientific":"Typha latifolia", "kind":"plant", "scale":"woodland", "topic":"cattail", "detail":"比较带状叶与相邻的上下花穗。", "view":"观察叶与花穗"},
	{"id":"junius", "name":"绿纹蜻蜓", "scientific":"Anax junius", "kind":"insect", "scale":"woodland", "topic":"green_darner", "detail":"成年雄性参考：大复眼、绿色胸部与四翅。", "view":"观察蜻蜓"},
	{"id":"crysoleucas", "name":"金色鲦", "scientific":"Notemigonus crysoleucas", "kind":"fish", "scale":"woodland", "topic":"golden_shiner", "detail":"近看水下深体形、鳃盖与叉形尾鳍。", "view":"观察鱼体"},
	{"id":"diaphanus", "name":"斑纹鳉", "scientific":"Fundulus diaphanus", "kind":"fish", "scale":"woodland", "topic":"banded_killifish", "detail":"比较浅水鱼的细长身体与体侧横纹。", "view":"观察鱼体"},
	{"id":"americana", "name":"美洲苦草", "scientific":"Vallisneria americana", "kind":"plant", "scale":"woodland", "topic":"wild_celery_leaf", "detail":"看河床上的带状叶、基生莲座与走茎。", "view":"观察叶与走茎"},
	{"id":"versicolor", "name":"云芝", "scientific":"Trametes versicolor", "kind":"fungus", "scale":"woodland", "topic":"fungus", "detail":"看枯木上的扇形子实体、色带与孔面。", "view":"观察真菌"},
	{"id":"gigantea", "name":"巨柱仙人掌", "scientific":"Carnegiea gigantea", "kind":"plant", "scale":"desert", "topic":"desert_cactus", "detail":"比较柱状株形、棱脊与刺座。", "view":"观察仙人掌"},
	{"id":"tridentata", "name":"三齿拉瑞阿", "scientific":"Larrea tridentata", "kind":"plant", "scale":"desert", "topic":"desert_leaf", "detail":"走近同一灌木的成对小叶。", "view":"观察叶片"},
	{"id":"velutina", "name":"绒毛牧豆树", "scientific":"Prosopis velutina", "kind":"plant", "scale":"desert", "topic":"desert_mesquite", "detail":"比较树冠、叶轴与枝上的荚果。", "view":"观察树与荚果"},
	{"id":"splendens", "name":"Ocotillo", "scientific":"Fouquieria splendens", "kind":"plant", "scale":"desert", "topic":"desert_ocotillo", "detail":"比较多根长茎、茎刺与梢端红花。", "view":"观察植株"},
	{"id":"farinosa", "name":"Brittlebush", "scientific":"Encelia farinosa", "kind":"plant", "scale":"desert", "topic":"desert_brittlebush", "detail":"看灰绿叶丛与静态黄色花头。", "view":"观察植株"},
	{"id":"dorsalis", "name":"沙漠鬣蜥", "scientific":"Dipsosaurus dorsalis", "kind":"reptile", "scale":"desert", "topic":"desert_iguana", "detail":"观察头背轮廓、四足与长尾。", "view":"观察鬣蜥"},
	{"id":"merriami", "name":"梅氏袋鼠鼠", "scientific":"Dipodomys merriami", "kind":"mammal", "scale":"desert", "topic":"desert_rat", "detail":"看后足、长尾与夜间教学种子搬运入口。", "view":"观察袋鼠鼠"},
	{"id":"adeliae", "name":"阿德利企鹅", "scientific":"Pygoscelis adeliae", "kind":"bird", "scale":"polar", "topic":"adelie_penguin", "detail":"近看白眼环、黑背白腹与鳍状翼。", "view":"观察企鹅"},
	{"id":"crystallorophias", "name":"冰磷虾", "scientific":"Euphausia crystallorophias", "kind":"invertebrate", "scale":"polar", "topic":"ice_krill", "detail":"近看约3厘米成体的大圆眼、分节腹部与尾扇。", "view":"观察磷虾"},
	{"id":"montanus", "name":"欧亚树麻雀", "scientific":"Passer montanus", "kind":"bird", "scale":"city", "topic":"city_sparrow", "detail":"近看栗色头顶、白颊黑斑与草地短跳。", "view":"观察麻雀"},
	{"id":"platyrhynchos", "name":"绿头鸭", "scientific":"Anas platyrhynchos", "kind":"bird", "scale":"city", "topic":"city_mallard_drake", "detail":"先近看雄鸟，再从主题切换同种雌鸟比较。", "view":"观察绿头鸭"},
	{"id":"biloba", "name":"银杏", "scientific":"Ginkgo biloba", "kind":"plant", "scale":"city", "topic":"city_ginkgo_leaf", "detail":"近看同一株种植幼树的扇形叶与分叉叶脉。", "view":"观察扇叶"},
	{"id":"rubrum", "name":"红枫", "scientific":"Acer rubrum", "kind":"plant", "scale":"city", "topic":"city_maple_leaf", "detail":"比较同株掌状裂叶与紫荆心形叶。", "view":"观察裂叶"},
	{"id":"canadensis", "name":"东部紫荆", "scientific":"Cercis canadensis", "kind":"plant", "scale":"city", "topic":"city_redbud_leaf", "detail":"近看同株心形叶，另可切至叶前春花。", "view":"观察心形叶"}
]

static func area(entry: Dictionary) -> String:
	return "reef" if entry.scale == "fish" else str(entry.scale)

static func searchable(entry: Dictionary) -> String:
	return ("%s %s %s %s %s" % [entry.name, entry.scientific, I18n.dictionary(KINDS)[entry.kind], I18n.dictionary(AREAS)[area(entry)], entry.detail]).to_lower()
