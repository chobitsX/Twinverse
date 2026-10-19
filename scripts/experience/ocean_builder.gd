extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const Seagrass = preload("res://scripts/experience/seagrass_observation.gd")
const Coral = preload("res://scripts/experience/coral_observation.gd")
const Urchin = preload("res://scripts/experience/urchin_observation.gd")
const GiantClam = preload("res://scripts/experience/giant_clam_observation.gd")
const BlackSeaCucumber = preload("res://scripts/experience/black_sea_cucumber_observation.gd")
const DayOctopus = preload("res://scripts/experience/day_octopus.gd")
const Biodiversity = preload("res://scripts/experience/biodiversity.gd")
## A single authored reef in metres; all four views share geometry and target identity.

const FishSkinShader = preload("res://shaders/fish_skin.gdshader")
const FishFinShader = preload("res://shaders/fish_fin.gdshader")
const FishFinRootShader = preload("res://shaders/fish_fin_root.gdshader")
const FishFinRayShader = preload("res://shaders/fish_fin_ray.gdshader")
const FishEyeShader = preload("res://shaders/fish_eye.gdshader")
const SurfaceShader = preload("res://shaders/reef_surface.gdshader")
const WaterShader = preload("res://shaders/ocean_water.gdshader")
const ParticleShader = preload("res://shaders/marine_particles.gdshader")
const UnderwaterSkyShader = preload("res://shaders/underwater_sky.gdshader")
const BakedPlacements = preload("res://assets/data/reef/placements_v1.res")
# Offline two-LOD support search; enlarged dry specimen used as authored morphology.
# Original cavity fidelity limits and placement evidence: docs/REEF_POCILLOPORA_V1.md.
const POCILLOPORA_PLACEMENTS: Dictionary = {
	21: {"position": Vector3(-2.101264000, 0.166961133, -1.077720046), "basis": Basis(Vector3(-0.321195036, -0.011965517, -0.305580676), Vector3(-0.026912345, 0.419192165, 0.007661625), Vector3(0.325690329, 0.022838186, -0.300729811))},
	27: {"position": Vector3(-1.373185635, 0.196546659, -0.668318152), "basis": Basis(Vector3(-0.208552510, 0.000759866, -0.074612401), Vector3(-0.003292063, 0.217517436, 0.015534258), Vector3(0.063895985, 0.013687134, -0.242729872))},
	30: {"position": Vector3(-0.200861901, 0.041687038, -1.414106846), "basis": Basis(Vector3(0.621028841, -0.248429269, -0.458454430), Vector3(0.292762607, 0.677914143, -0.074691311), Vector3(0.462757438, -0.095484532, 0.662507534))},
	39: {"position": Vector3(1.965752602, 0.170450300, -1.444641352), "basis": Basis(Vector3(-0.043984227, -0.245054692, 0.696672916), Vector3(0.002924733, 0.727829039, 0.235947847), Vector3(-0.619696796, 0.020828266, -0.048334181))},
	42: {"position": Vector3(2.088941574, 0.233488008, -2.981902599), "basis": Basis(Vector3(-0.021050634, 0.018982418, 0.284095407), Vector3(0.004059788, 0.216047794, -0.024793690), Vector3(-0.283246249, 0.001685874, -0.021469114))},
	50: {"position": Vector3(-1.754896283, 0.207592800, -4.338269234), "basis": Basis(Vector3(0.192491680, -0.013937709, 0.220566571), Vector3(0.026524041, 0.256842345, -0.000056581), Vector3(-0.238249853, 0.017333077, 0.178198308))},
	62: {"position": Vector3(-0.772260427, 0.106801696, -4.632697582), "basis": Basis(Vector3(-0.174536973, -0.066919394, 0.316728026), Vector3(-0.083242439, 0.284136921, 0.048776370), Vector3(-0.311196923, -0.038471941, -0.190686375))},
	86: {"position": Vector3(-1.633166075, 0.131437227, -10.806707382), "basis": Basis(Vector3(0.061114967, 0.112579331, 0.743239522), Vector3(-0.119946636, 0.754360497, -0.097242579), Vector3(-0.680130064, -0.122921653, 0.083935395))},
	89: {"position": Vector3(-1.109466910, 0.164530009, -11.016983032), "basis": Basis(Vector3(0.584385812, 0.044522114, 0.004150554), Vector3(-0.046924669, 0.516317546, -0.140309259), Vector3(-0.014939537, 0.119820423, 0.603063583))},
	98: {"position": Vector3(3.189807415, 0.255115718, -12.823118210), "basis": Basis(Vector3(-0.473743439, 0.031433035, 0.138220206), Vector3(0.033602700, 0.400824368, -0.025318760), Vector3(-0.127503097, -0.011155897, -0.520235837))},
	104: {"position": Vector3(-1.128994703, 0.218793422, 0.495052695), "basis": Basis(Vector3(0.028296391, -0.035204053, -0.363448769), Vector3(-0.012480232, 0.369541198, -0.035491552), Vector3(0.414830536, 0.013519041, 0.023723772))},
	106: {"position": Vector3(1.802488089, 0.062116895, 2.042237520), "basis": Basis(Vector3(0.552731335, 0.071710564, -0.036901604), Vector3(-0.055384036, 0.585594773, 0.168621317), Vector3(0.047214068, -0.152583271, 0.629803777))},
	108: {"position": Vector3(2.024673700, 0.171044499, 1.678021431), "basis": Basis(Vector3(-0.228256524, 0.020007268, -0.503269732), Vector3(0.005706353, 0.434412062, 0.026764842), Vector3(0.392628342, 0.005317704, -0.292967498))},
	110: {"position": Vector3(3.046961069, 0.005478446, 1.259045720), "basis": Basis(Vector3(-0.072350368, 0.019899722, 0.624693096), Vector3(0.074428782, 0.613808990, -0.011301467), Vector3(-0.608886421, 0.072665952, -0.075610049))},
	112: {"position": Vector3(2.531365871, 0.083357684, 0.791308880), "basis": Basis(Vector3(0.379049450, -0.035234194, 0.335722446), Vector3(0.100915000, 0.542885900, -0.067416660), Vector3(-0.321006149, 0.129062429, 0.375232875))},
	115: {"position": Vector3(-2.042615891, 0.141475141, -1.835461617), "basis": Basis(Vector3(0.176667005, 0.087945066, 0.407528788), Vector3(-0.109554946, 0.444167346, -0.051734619), Vector3(-0.447238088, -0.074062899, 0.173653975))},
	119: {"position": Vector3(-0.596611023, 0.182091087, -0.907913625), "basis": Basis(Vector3(-0.393414855, 0.069546632, 0.039145242), Vector3(0.080842435, 0.358449191, 0.040162493), Vector3(-0.033884455, 0.047727495, -0.358674347))},
	122: {"position": Vector3(1.332146525, 0.199279889, -1.820626259), "basis": Basis(Vector3(0.439390630, 0.132401213, -0.151585311), Vector3(-0.121786147, 0.410311997, 0.114284091), Vector3(0.156952500, -0.052280318, 0.513043106))},
	124: {"position": Vector3(1.110530615, 0.175525993, -2.189565182), "basis": Basis(Vector3(-0.338458002, -0.137784541, 0.317434907), Vector3(-0.146975264, 0.498679161, 0.013141930), Vector3(-0.280023485, -0.095203511, -0.390574098))},
	126: {"position": Vector3(2.588377476, 0.214633122, -2.662930250), "basis": Basis(Vector3(-0.542319596, 0.108610742, -0.260834485), Vector3(0.168010905, 0.595460296, -0.096535660), Vector3(0.245037913, -0.167900920, -0.511090755))},
	128: {"position": Vector3(2.389054298, 0.230337247, -1.753591061), "basis": Basis(Vector3(-0.170061931, -0.108218580, 0.468500793), Vector3(0.102529861, 0.499714941, 0.136816084), Vector3(-0.508666396, 0.136906207, -0.129055932))},
	131: {"position": Vector3(-3.652406693, 0.339055687, -4.051927090), "basis": Basis(Vector3(0.160416916, 0.136076927, -0.338825673), Vector3(-0.145391554, 0.320525885, 0.093905352), Vector3(0.324416608, 0.076360770, 0.209626779))},
	135: {"position": Vector3(-0.290867209, 0.279946566, -5.519741058), "basis": Basis(Vector3(-0.027954740, 0.123263001, 0.471894085), Vector3(-0.166913673, 0.410179675, -0.134553954), Vector3(-0.473226130, -0.151957750, 0.019583058))},
	137: {"position": Vector3(0.990132570, 0.317552060, -4.886439800), "basis": Basis(Vector3(0.063493468, 0.105290167, -0.509895027), Vector3(0.206909716, 0.415429801, 0.134255990), Vector3(0.451686531, -0.205101773, 0.010175484))},
	139: {"position": Vector3(0.343648702, 0.358510017, -4.646848202), "basis": Basis(Vector3(0.484186351, -0.002295042, -0.087935954), Vector3(0.035520557, 0.393497735, 0.161446169), Vector3(0.086243130, -0.149183273, 0.427196115))},
}
# Offline conditioned BVH search, including neighbouring corals; never runs per frame.
# Nineteen authored placements; preserve all other identities. See docs/REEF_PLATE_V6.md.
const PLATE_PLACEMENTS: Dictionary = {
	2: {"position": Vector3(-1.48570716381073, 0.16570381820201899, 0.307707369327545), "basis": Basis(Vector3(0.27603855729103099, 0.077207334339618697, 0.19251066446304299), Vector3(-0.034615356475114802, 0.25276085734367398, -0.035386193543672603), Vector3(-0.20165890455245999, 0.0135318823158741, 0.27922806143760698)), "footprint": 0.23382486328482599},
	5: {"position": Vector3(-0.94833683967590299, 0.51468944549560502, 0.74087458848953203), "basis": Basis(Vector3(0.174738749861717, -0.067314550280570998, -0.10859053581953), Vector3(0.0402733907103539, 0.15357515215873699, -0.022863103076815602), Vector3(0.122607499361038, -0.0023335330188274401, 0.17090237140655501)), "footprint": 0.151877565479279},
	6: {"position": Vector3(-1.3690702915191699, 0.14881910383701299, 1.0859621763229399), "basis": Basis(Vector3(-0.279994606971741, -0.018750524148345001, 0.13071221113205), Vector3(-0.010544860735535601, 0.32592535018920898, 0.020115209743380501), Vector3(-0.13039983808994299, 0.0113735580816865, -0.282544255256653)), "footprint": 0.31946272978782703},
	7: {"position": Vector3(-1.11171114444733, 0.58336377143859897, 0.72437953948974598), "basis": Basis(Vector3(-0.058991994708776502, 0.030374541878700301, 0.17981563508510601), Vector3(0.041979927569627797, 0.19404633343219799, -0.018621301278471902), Vector3(-0.174101501703262, 0.031327374279499103, -0.065115228295326205)), "footprint": 0.13755154031515099},
	12: {"position": Vector3(1.62433910369873, 0.073520854115486103, 0.49702107906341603), "basis": Basis(Vector3(0.474071174860001, -0.0042573399841785396, -0.38903960585594199), Vector3(-0.084489390254020705, 0.54590052366256703, -0.11267889291048), Vector3(0.359750926494598, 0.146893635392189, 0.48367559909820601)), "footprint": 0.45258858323097201},
	15: {"position": Vector3(2.7406129837036102, 0.061311535537242903, 1.0115783214569101), "basis": Basis(Vector3(0.19221471250057201, -0.015025077387690501, -0.20686858892440799), Vector3(0.018886445090174699, 0.27145957946777299, -0.0042151524685323204), Vector3(0.22106081247329701, -0.0098604373633861507, 0.18978574872016901)), "footprint": 0.212017966604233},
	17: {"position": Vector3(2.89886403083801, 0.0356737375259399, 1.70728063583374), "basis": Basis(Vector3(0.53376197814941395, -0.024722434580326101, -0.012021140195429301), Vector3(0.018713049590587599, 0.44426450133323703, 0.0068236957304179703), Vector3(0.0153324007987976, -0.0104382252320647, 0.40492174029350297)), "footprint": 0.54259996265172905},
	24: {"position": Vector3(-1.15028023719788, 0.69164806604385398, -1.9378039836883501), "basis": Basis(Vector3(0.14447277784347501, 0.024179030209779701, -0.11300572752952601), Vector3(-0.052300326526165002, 0.19259649515152, -0.022655654698610299), Vector3(0.148264840245247, 0.054854251444339801, 0.15220829844474801)), "footprint": 0.227298963814974},
	28: {"position": Vector3(-0.77689862251281705, 0.13708551228046401, -0.42258441448211698), "basis": Basis(Vector3(0.28355595469474798, 0.0133607443422079, -0.46692639589309698), Vector3(0.061545290052890798, 0.54195356369018599, 0.0465054325759411), Vector3(0.6189826130867, -0.081442981958389296, 0.20860753953456901)), "footprint": 0.49001906371116599},
	37: {"position": Vector3(1.5948779582977299, 0.19215141236782099, -2.9811482429504399), "basis": Basis(Vector3(-0.093310259282589, -0.067591413855552701, -0.15437418222427399), Vector3(-0.025951698422431901, 0.15168032050132799, -0.046401161700487102), Vector3(0.17228503525257099, 0.0060317292809486398, -0.096626773476600605)), "footprint": 0.143230430781841},
	38: {"position": Vector3(1.27647733688354, 0.23540101945400199, -2.57862329483032), "basis": Basis(Vector3(-0.0624763891100883, -0.070962823927402496, -0.319041907787323), Vector3(-0.104851432144642, 0.31792032718658397, -0.052352376282215098), Vector3(0.35609924793243403, 0.101641327142715, -0.043343544006347698)), "footprint": 0.25809618607163398},
	41: {"position": Vector3(1.782958984375, 0.300514876842499, -1.83231890201569), "basis": Basis(Vector3(-0.17918153107166301, -0.0076184002682566599, 0.014069370925426501), Vector3(-0.0057145650498569003, 0.22081165015697499, 0.0160494968295097), Vector3(-0.024258043617010099, 0.017132125794887501, -0.200148195028305)), "footprint": 0.136866547912359},
	51: {"position": Vector3(-2.18525314331055, 0.19915260374546101, -3.40494585037231), "basis": Basis(Vector3(0.29397064447402999, -0.038627065718174002, 0.195095390081406), Vector3(0.014152764342725299, 0.28644466400146501, 0.020990667864680301), Vector3(-0.203964859247208, -0.0138983372598886, 0.28560131788253801)), "footprint": 0.25682865035533903},
	59: {"position": Vector3(0.69940978288650502, 0.33851563930511502, -5.5284500122070304), "basis": Basis(Vector3(-0.029111854732036601, 0.011401498690247499, 0.18723760545253801), Vector3(0.0117057105526328, 0.203079864382744, -0.0088743977248668705), Vector3(-0.19493019580841101, 0.0102578774094582, -0.023647930473089201)), "footprint": 0.201048102751374},
	63: {"position": Vector3(-0.136076435446739, 0.33255490660667397, -4.6770529747009304), "basis": Basis(Vector3(-0.18882723152637501, -0.077361971139907795, 0.269754558801651), Vector3(-0.073985345661640195, 0.41409364342689498, 0.072391375899314894), Vector3(-0.279192745685577, -0.0300789605826139, -0.19494251906871801)), "footprint": 0.25800277123451199},
	70: {"position": Vector3(3.3529324531555198, 0.42393007874488797, -7.1094589233398402), "basis": Basis(Vector3(0.051224410533905002, 0.176236242055893, 0.60723638534545898), Vector3(-0.0536091104149818, 0.60166966915130604, -0.166463673114777), Vector3(-0.69048625230789196, -0.0182505268603563, 0.136382356286049)), "footprint": 0.72731530308723402},
	78: {"position": Vector3(-3.8351616859436, 0.23343117535114299, -6.7028055191040004), "basis": Basis(Vector3(0.26135504245758101, -0.083139307796955095, 0.30508631467819203), Vector3(0.0039398670196533203, 0.323869258165359, 0.073516465723514599), Vector3(-0.333840072154999, -0.0374574884772301, 0.24501636624336201)), "footprint": 0.30437951564788801},
	90: {"position": Vector3(-1.27398693561554, 0.20626941323280301, -9.2252635955810494), "basis": Basis(Vector3(0.0423815660178661, 0.129187822341919, -0.30453577637672402), Vector3(-0.020303608849644699, 0.24182938039302801, 0.107097640633583), Vector3(0.245719194412231, -0.0048639085143804602, 0.063502632081508595)), "footprint": 0.2409294257164},
	95: {"position": Vector3(2.11683249473572, 0.239338845014572, -10.681072235107401), "basis": Basis(Vector3(-0.27514445781707803, -0.031500272452831303, 0.33020451664924599), Vector3(0.00055086985230445905, 0.41770616173744202, 0.039196249097585699), Vector3(-0.32590839266777, 0.025616509839892401, -0.27886527776718101)), "footprint": 0.44660867581367503},
}
const PLACEMENT_VERSION: String = "reef-support-v12-plate-clearance1"
const Habitat = preload("res://scripts/core/local_habitat.gd")
const FISH_POSITION: Vector3 = Habitat.FISH_ORIGIN
const Swell = preload("res://scripts/experience/ocean_swell.gd")
const SEA_LEVEL: float = Swell.MEAN_LEVEL
# Lookdev attenuation, not site-measured water quality. Sky masking stays intact.
const WATER_FOG_DENSITY: float = 0.13
const WATER_VOLUME_DENSITY: float = 0.016
# Authored transforms from dense actual two-LOD support search003; see docs/REEF_CONTACT_V10.md.
# Search runs offline. These 29 entries retain colony identities and assets.
const MASSIVE_PLACEMENTS: Dictionary = {
	3: {"point": Vector2(-0.412340611, 1.430673003), "basis": Basis(Vector3(0.182573155, -0.038537942, 0.298180610), Vector3(0.029098868, 0.383733600, 0.023791756), Vector3(-0.310519218, 0.013301018, 0.177548081)), "footprint": 0.243777973},
	18: {"point": Vector2(2.417799473, 1.885665178), "basis": Basis(Vector3(-0.191128537, -0.007276845, 0.234098464), Vector3(0.039377026, 0.263078868, 0.043162502), Vector3(-0.228913993, 0.051329646, -0.188032568)), "footprint": 0.207314117},
	25: {"point": Vector2(-2.567551613, -0.909029961), "basis": Basis(Vector3(0.591482997, 0.065842785, 0.306941271), Vector3(-0.090773143, 0.579319000, 0.013802702), Vector3(-0.295296699, -0.046196666, 0.610564291)), "footprint": 0.450700743},
	29: {"point": Vector2(-0.810699165, -2.070679188), "basis": Basis(Vector3(-0.067974783, -0.022669110, -0.143268421), Vector3(0.052101985, 0.151360646, -0.040939458), Vector3(0.155930132, -0.060457312, -0.048775781)), "footprint": 0.119983805},
	32: {"point": Vector2(-1.639553428, -0.579821289), "basis": Basis(Vector3(-0.341908038, -0.006029703, -0.156274855), Vector3(-0.033349186, 0.326707214, 0.082605384), Vector3(0.126602694, 0.069775939, -0.400282234)), "footprint": 0.288919285},
	35: {"point": Vector2(0.833199501, -2.052645206), "basis": Basis(Vector3(0.118428998, 0.005562186, 0.158839673), Vector3(-0.012816919, 0.149961084, 0.002598181), Vector3(-0.136503771, -0.009254799, 0.137563407)), "footprint": 0.136593570},
	40: {"point": Vector2(2.807010889, -1.351260900), "basis": Basis(Vector3(0.371977925, -0.050223563, 0.005893541), Vector3(0.049678959, 0.355190456, 0.068490468), Vector3(-0.015534723, -0.066725783, 0.360148102)), "footprint": 0.256361229},
	52: {"point": Vector2(-4.018919945, -4.025831699), "basis": Basis(Vector3(0.085913397, 0.045840435, -0.325696468), Vector3(-0.089603156, 0.326626390, 0.018158780), Vector3(0.288681448, 0.087738372, 0.102565564)), "footprint": 0.233734576},
	56: {"point": Vector2(-2.050591946, -4.479356766), "basis": Basis(Vector3(0.482501328, -0.151271075, 0.251799256), Vector3(0.183161944, 0.534438789, -0.018350862), Vector3(-0.247817084, 0.100478731, 0.476691514)), "footprint": 0.407159252},
	60: {"point": Vector2(1.834701777, -4.765957832), "basis": Basis(Vector3(-0.228983447, -0.021634368, 0.417437613), Vector3(0.042164430, 0.448091924, 0.045859586), Vector3(-0.440338403, 0.054157127, -0.212683350)), "footprint": 0.332239676},
	61: {"point": Vector2(-0.032093950, -5.474437714), "basis": Basis(Vector3(0.131493539, 0.052148715, 0.089020416), Vector3(-0.035625108, 0.157759190, -0.039933089), Vector3(-0.098984100, 0.012497281, 0.132629678)), "footprint": 0.115821687},
	65: {"point": Vector2(-0.255399704, -6.076650143), "basis": Basis(Vector3(-0.162888572, 0.002202824, 0.136823922), Vector3(-0.049301036, 0.193981007, -0.061791159), Vector3(-0.127821311, -0.077626199, -0.150527984)), "footprint": 0.146552665},
	71: {"point": Vector2(4.079912663, -5.367109776), "basis": Basis(Vector3(-0.304925114, 0.017322015, 0.120577849), Vector3(0.059078403, 0.308927357, 0.090224080), Vector3(-0.116652198, 0.111176811, -0.269492745)), "footprint": 0.219622165},
	73: {"point": Vector2(2.478760958, -7.433482170), "basis": Basis(Vector3(-0.148787990, -0.051420167, -0.202434808), Vector3(-0.036116846, 0.215755358, -0.047763310), Vector3(0.208256170, 0.000680410, -0.152912319)), "footprint": 0.181875689},
	75: {"point": Vector2(2.725603104, -7.129685402), "basis": Basis(Vector3(0.253623098, 0.024126470, -0.105388977), Vector3(-0.056256041, 0.232382610, -0.063094907), Vector3(0.096792571, 0.071843274, 0.239477158)), "footprint": 0.187294585},
	80: {"point": Vector2(-2.529954910, -6.932188034), "basis": Basis(Vector3(-0.503902555, 0.029259376, 0.376661271), Vector3(0.084922001, 0.548573911, 0.062856659), Vector3(-0.359284282, 0.088626616, -0.513417065)), "footprint": 0.434917522},
	81: {"point": Vector2(-2.975948095, -8.536520958), "basis": Basis(Vector3(0.066166036, -0.002177519, 0.194629639), Vector3(0.052026261, 0.188047156, -0.018010313), Vector3(-0.173797816, 0.055462793, 0.068705484)), "footprint": 0.137320338},
	82: {"point": Vector2(-4.478412628, -9.231294632), "basis": Basis(Vector3(-0.281720102, -0.137663290, -0.356006324), Vector3(-0.047632843, 0.439758033, -0.141335383), Vector3(0.381082594, -0.046802424, -0.280848116)), "footprint": 0.340102000},
	88: {"point": Vector2(-1.934557676, -9.983437538), "basis": Basis(Vector3(-0.071424872, -0.006818854, -0.163150340), Vector3(-0.009289190, 0.194475025, -0.001717903), Vector3(0.140641406, 0.009381871, -0.082969509)), "footprint": 0.119934944},
	97: {"point": Vector2(4.523345947, -11.938533783), "basis": Basis(Vector3(0.061735503, -0.005787376, -0.409291595), Vector3(0.048134860, 0.369701654, -0.000915671), Vector3(0.466277301, -0.037398886, 0.054285068)), "footprint": 0.308186905},
	102: {"point": Vector2(-1.846480131, 0.779153287), "basis": Basis(Vector3(0.231695294, 0.061541408, -0.239011228), Vector3(-0.069663443, 0.326480865, 0.018808318), Vector3(0.236928046, 0.035812251, 0.239262655)), "footprint": 0.229545874},
	109: {"point": Vector2(1.393468976, 0.845713139), "basis": Basis(Vector3(0.244023293, 0.061263122, -0.169047028), Vector3(-0.094707929, 0.302111059, -0.034026723), Vector3(0.158675343, 0.086104617, 0.239664227)), "footprint": 0.215887009},
	113: {"point": Vector2(1.260857105, 0.642964005), "basis": Basis(Vector3(0.173589885, 0.028427152, -0.165684938), Vector3(-0.059582338, 0.211040020, -0.022825610), Vector3(0.148231462, 0.051538251, 0.184854314)), "footprint": 0.171465096},
	117: {"point": Vector2(-1.759229422, -2.561129093), "basis": Basis(Vector3(0.145288691, -0.020569574, -0.248416200), Vector3(-0.013859759, 0.346067727, -0.027042847), Vector3(0.255818218, 0.030431537, 0.139619678)), "footprint": 0.196025027},
	121: {"point": Vector2(-0.649246216, -2.363432407), "basis": Basis(Vector3(0.101419695, -0.097242236, -0.292579114), Vector3(0.097415611, 0.283173501, -0.078090042), Vector3(0.322875887, -0.054891787, 0.115463808)), "footprint": 0.236573545},
	125: {"point": Vector2(1.653224349, -1.166089177), "basis": Basis(Vector3(-0.375960857, -0.033909060, 0.047902297), Vector3(-0.027893705, 0.314792365, 0.086461417), Vector3(-0.056266632, 0.070517004, -0.362934798)), "footprint": 0.261820150},
	129: {"point": Vector2(1.950763345, -4.077032089), "basis": Basis(Vector3(0.365954638, -0.010861743, 0.252659291), Vector3(0.008574787, 0.369925141, 0.010392250), Vector3(-0.259903103, -0.003089134, 0.356097907)), "footprint": 0.307589991},
	133: {"point": Vector2(-1.533987284, -4.874496460), "basis": Basis(Vector3(0.173865467, -0.013988413, 0.411888927), Vector3(0.086157702, 0.375137538, -0.018834827), Vector3(-0.403837234, 0.074012205, 0.173313662)), "footprint": 0.305438561},
	138: {"point": Vector2(0.395258427, -5.605622292), "basis": Basis(Vector3(0.105701894, 0.061904509, 0.256142884), Vector3(0.016536100, 0.266819239, -0.071028285), Vector3(-0.302773029, 0.036184113, 0.085543469)), "footprint": 0.214114961},
}
const REEF_LOOKDEV_VERSION: String = "reef-lookdev-v17-water-light"
const BRANCH_VARIANTS: Array[String] = ["branching", "branching_bush"]
const PLATE_VARIANTS: Array[String] = ["plate", "plate_cup", "plate_lobed"]
# Conservative XZ radii from both exported LODs, measured about their basal origin.
const PLATE_FOOTPRINTS: Dictionary = {"plate": 1.015, "plate_cup": 0.675, "plate_lobed": 0.716}
# Regional visual composition, not measured reef bathymetry or species cover.
const REEF_PATCHES: Array[Dictionary] = [
	{"center": Vector2(-1.10, 0.65), "radius": 0.82, "rise": 0.22, "count": 10},
	{"center": Vector2(1.85, 1.25), "radius": 0.95, "rise": 0.26, "count": 9},
	{"center": Vector2(-1.20, -1.45), "radius": 1.25, "rise": 0.35, "count": 14},
	{"center": Vector2(1.95, -2.25), "radius": 1.10, "rise": 0.42, "count": 13},
	{"center": Vector2(-2.90, -4.30), "radius": 1.45, "rise": 0.50, "count": 11},
	{"center": Vector2(0.20, -5.10), "radius": 1.32, "rise": 0.44, "count": 10},
	{"center": Vector2(3.60, -6.30), "radius": 1.65, "rise": 0.65, "count": 9},
	{"center": Vector2(-4.00, -8.10), "radius": 1.75, "rise": 0.55, "count": 8},
	{"center": Vector2(-0.80, -10.10), "radius": 1.45, "rise": 0.35, "count": 8},
	{"center": Vector2(2.00, -12.10), "radius": 1.70, "rise": 0.60, "count": 8},
]
const COLONY_PALETTE: Array[Color] = [
	Color(0.91, 0.88, 0.82), Color(0.82, 0.86, 0.84),
	Color(0.86, 0.80, 0.75), Color(0.79, 0.81, 0.78),
]
const POSES: Dictionary = {
	"pacific": {"position": Vector3(2.4, 7.2, 8.0), "target": Vector3(0, 3.0, -2.0)},
	"reef": {"position": Vector3(0.85, 0.91, 2.18), "target": Vector3(0.15, 0.50, -0.65)},
	"school": {"position": Vector3(0.58, 0.55, 0.56), "target": Vector3(0.34, 0.485, 0.06)},
	"fish": {"position": Vector3(0.395, 0.605, 0.247), "target": FISH_POSITION},
}

static func build(stage: Node) -> void:
	stage.semantic_size_m = 0.08 if stage.scale_id == "fish" else 1.0
	stage.target_position = FISH_POSITION
	stage.target_radius = 0.046 if stage.scale_id == "fish" else 0.10
	var pose: Dictionary = POSES.get(stage.scale_id, POSES.reef)
	stage.default_position = pose.position
	stage.default_target = pose.target
	stage.close_position = POSES.fish.position
	stage.camera.near = 0.0007 if stage.scale_id == "fish" else 0.008
	stage.camera.far = 512.0
	stage.camera.fov = 48.0
	stage.environment.ambient_light_color = Color(0.62, 0.75, 0.78)
	stage.environment.ambient_light_energy = 0.65
	stage.environment.ssao_enabled = true
	stage.environment.ssao_radius = 0.23
	stage.environment.ssao_intensity = 1.5
	stage.environment.glow_enabled = true
	stage.environment.glow_intensity = 0.28
	stage.environment.glow_bloom = 0.02
	stage.environment.fog_light_color = Color(0.065, 0.34, 0.40)
	stage.environment.fog_density = WATER_FOG_DENSITY
	stage.environment.background_mode = Environment.BG_SKY
	stage.environment.fog_enabled = true
	stage.environment.volumetric_fog_enabled = true
	stage.environment.fog_sun_scatter = 0.06
	stage.environment.volumetric_fog_density = WATER_VOLUME_DENSITY
	stage.environment.volumetric_fog_albedo = Color(0.30, 0.56, 0.61)
	stage.environment.volumetric_fog_length = 35.0
	stage.environment.volumetric_fog_detail_spread = 2.0
	stage.environment.volumetric_fog_anisotropy = 0.65
	var sky_material: ShaderMaterial = ShaderMaterial.new()
	sky_material.shader = UnderwaterSkyShader
	var sky: Sky = Sky.new()
	# Immersion changes every camera step; incremental filtering shows stale reflections.
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.sky_material = sky_material
	stage.environment.sky = sky
	stage.set_meta("ocean_sky_material", sky_material)
	var sunlight: DirectionalLight3D = stage.add_sun(Vector3(-52, -32, -15), Color(1.0, 0.96, 0.89), 1.25)
	sky_material.set_shader_parameter("light_direction", sunlight.basis.z.normalized())
	var fill: DirectionalLight3D = stage.add_sun(Vector3(-25, 150, 0), Color(0.23, 0.60, 0.78), 0.28)
	fill.shadow_enabled = false
	_build_seabed(stage)
	_build_reef(stage)
	_build_water(stage)
	_build_particles(stage)
	_build_target(stage)
	Biodiversity.build(stage)
	Urchin.build(stage)
	Coral.build(stage)
	Seagrass.build(stage)
	GiantClam.build(stage)
	BlackSeaCucumber.build(stage)
	DayOctopus.build(stage)
	if stage.scale_id == "fish":
		var attributes: CameraAttributesPractical = CameraAttributesPractical.new()
		attributes.dof_blur_far_enabled = true
		attributes.dof_blur_far_distance = 0.22
		attributes.dof_blur_far_transition = 0.45
		attributes.dof_blur_amount = 0.16
		stage.camera.attributes = attributes
	I18n.set_meta_text(stage,"scientific_note","蜥蜴岛北大堡礁代表性生境 · A. percula · 场景布局与运动为作者化示意")
	stage.set_meta("reef_lookdev_version", REEF_LOOKDEV_VERSION)


static func _height(x: float, z: float) -> float:
	var point: Vector2 = Vector2(x, z)
	var relief: float = 0.0
	for patch: Dictionary in REEF_PATCHES:
		var q: Vector2 = (point - patch.center) / float(patch.radius)
		relief += float(patch.rise) * exp(-q.length_squared() * 1.35)
	var channel_x: float = 0.30 + sin((z + 1.0) * 0.48) * 0.85 + sin(z * 0.15) * 0.4
	var width: float = 0.38 + absf(sin(z * 0.32)) * 0.24
	var channel: float = exp(-pow((x - channel_x) / width, 2.0))
	var local_extent: float = (1.0 - smoothstep(6.0, 10.0, absf(x))) * (1.0 - smoothstep(14.0, 20.0, absf(z + 3.0)))
	relief = (relief - channel * 0.10) * local_extent
	var fine: float = (sin(x * 3.1 + z * 0.7) * sin(z * 2.3) * 0.014 + sin(z * 0.8 - x * 0.5) * 0.022) * local_extent
	# Preserve the attached host rock/anemone and both close-camera anchors.
	var host_blend: float = smoothstep(0.60, 1.20, point.distance_to(Vector2(0.34, 0.05)))
	var legacy: float = 0.032 * sin(x * 1.3) * cos(z * 0.7) + 0.015 * sin(z * 2.8 + x)
	return lerpf(legacy, clampf(relief + fine, -0.14, 0.82), host_blend) + _outer_relief(x, z)


static func _outer_relief(x: float, z: float) -> float:
	# Authored shoulders outside the measured-contact hero layout. These are
	# actual terrain, visible from both sides of the surface, not a backdrop card.
	var outer: float = maxf(smoothstep(6.5, 10.0, absf(x)), smoothstep(18.0, 25.0, -z))
	var left: Vector2 = Vector2((x + 10.0) / 6.0, (z + 17.0) / 12.0)
	var right: Vector2 = Vector2((x - 12.0) / 7.0, (z + 22.0) / 15.0)
	var back: Vector2 = Vector2(x / 16.0, (z + 34.0) / 7.0)
	var shoulders: float = exp(-left.length_squared()) * 2.8 + exp(-right.length_squared()) * 2.7 + exp(-back.length_squared()) * 1.7
	var surface: float = 0.90 + sin(x * 0.72 + sin(z * 0.4)) * 0.08 + sin(z * 0.81 - x * 0.35) * 0.04
	return shoulders * surface * outer * 0.70


static func _ground_cover(x: float, z: float) -> float:
	var cover: float = 0.0
	for patch: Dictionary in REEF_PATCHES:
		var q: Vector2 = (Vector2(x, z) - patch.center) / float(patch.radius)
		cover = maxf(cover, exp(-q.length_squared() * 0.9))
	return maxf(smoothstep(0.08, 0.78, cover), smoothstep(0.15, 1.2, _outer_relief(x, z)) * 0.85)


static func _ground_normal(x: float, z: float) -> Vector3:
	var step: float = 0.035
	return Vector3(_height(x - step, z) - _height(x + step, z), step * 2.0, _height(x, z - step) - _height(x, z + step)).normalized()


static func _mesh_coordinate(value: float) -> float:
	# Same 120 m footprint and vertex count, with samples concentrated near the reef.
	return signf(value) * (8.0 * absf(value) + 52.0 * pow(absf(value), 4.0))


static func _extend_horizon(value: float) -> float:
	# Keep all near-reef samples and attachments intact. The sparse outer ring
	# reaches beyond the far clip so the seabed does not end visibly underwater.
	return value if absf(value) <= 40.0 else signf(value) * (40.0 + (absf(value) - 40.0) * 50.0)


static func _build_seabed(stage: Node) -> void:
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2(120, 120)
	mesh.subdivide_width = 100
	mesh.subdivide_depth = 100
	var arrays: Array = mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(vertices.size())
	for i: int in range(vertices.size()):
		vertices[i].x = _extend_horizon(_mesh_coordinate(vertices[i].x / 60.0))
		vertices[i].z = _extend_horizon(_mesh_coordinate(vertices[i].z / 60.0) - 4.0)
		vertices[i].y = _height(vertices[i].x, vertices[i].z)
		colors[i] = Color(_ground_cover(vertices[i].x, vertices[i].z), 0, 0, 0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(vertices.size())
	for i: int in range(0, indices.size(), 3):
		var a: int = indices[i]
		var b: int = indices[i + 1]
		var c: int = indices[i + 2]
		var face: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if face.y < 0.0: face = -face
		normals[a] += face
		normals[b] += face
		normals[c] += face
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	for i: int in range(normals.size()):
		normals[i] = normals[i].normalized()
		var tangent: Vector3 = Vector3(1.0, -normals[i].x / maxf(normals[i].y, 0.001), 0).normalized()
		tangents[i * 4] = tangent.x
		tangents[i * 4 + 1] = tangent.y
		tangents[i * 4 + 2] = tangent.z
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	var terrain: ArrayMesh = ArrayMesh.new()
	terrain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SurfaceShader
	material.set_shader_parameter("base_texture", stage.textures.sand)
	material.set_shader_parameter("cover_rock_texture", stage.textures.substrate_color)
	material.set_shader_parameter("cover_normal_texture", stage.textures.substrate_normal)
	material.set_shader_parameter("cover_arm_texture", stage.textures.substrate_arm)
	material.set_shader_parameter("has_texture", true)
	material.set_shader_parameter("tint", Color(0.70, 0.68, 0.60))
	material.set_shader_parameter("ground_surface", true)
	material.set_shader_parameter("saturation", 0.55)
	material.set_shader_parameter("tile_scale", 1.8)
	material.set_shader_parameter("roughness_value", 0.91)
	material.set_shader_parameter("caustic_strength", 0.21)
	stage.materials.append(material)
	stage.add_mesh(terrain, material).name = "ReefSeabed"
	stage.set_meta("reef_terrain_vertices", vertices)


static func _terrain_height(stage: Node, x: float, z: float) -> float:
	# Query the rendered triangle surface, not the continuous authoring height field.
	var vertices: PackedVector3Array = stage.get_meta("reef_terrain_vertices")
	var row_size: int = 102
	var left: int = 0
	var right: int = row_size - 1
	while right - left > 1:
		var middle: int = (left + right) / 2
		if x <= vertices[middle].x: left = middle
		else: right = middle
	var top: int = 0
	var bottom: int = row_size - 1
	while bottom - top > 1:
		var middle: int = (top + bottom) / 2
		if z <= vertices[middle * row_size].z: top = middle
		else: bottom = middle
	var a: Vector3 = vertices[top * row_size + left]
	var b: Vector3 = vertices[top * row_size + right]
	var c: Vector3 = vertices[bottom * row_size + left]
	var d: Vector3 = vertices[bottom * row_size + right]
	var u: float = clampf((x - a.x) / (b.x - a.x), 0.0, 1.0)
	var v: float = clampf((z - a.z) / (c.z - a.z), 0.0, 1.0)
	if u + v <= 1.0: return a.y + (b.y - a.y) * u + (c.y - a.y) * v
	return d.y + (c.y - d.y) * (1.0 - u) + (b.y - d.y) * (1.0 - v)


static func _collect_mesh_vertices(node: Node3D, parent_transform: Transform3D, points: PackedVector3Array) -> void:
	var local_transform: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D:
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for point: Vector3 in vertices: points.append(local_transform * point)
	for child: Node in node.get_children():
		if child is Node3D: _collect_mesh_vertices(child, local_transform, points)


static func _contact_profile(high: Node3D, low: Node3D, dense: bool = false) -> PackedVector3Array:
	# Read each family's actual imported geometry once. Lowest vertex in each local
	# XZ cell captures the base; including both LODs avoids lifting on an LOD switch.
	var points: PackedVector3Array = PackedVector3Array()
	_collect_mesh_vertices(high, Transform3D.IDENTITY, points)
	_collect_mesh_vertices(low, Transform3D.IDENTITY, points)
	var bounds: AABB = AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points: bounds = bounds.expand(point)
	if dense:
		# Rock edges can fall between coarse profile cells. Keep every distinct
		# basal vertex for colonies; only broad foundation/terrain contacts compress.
		var unique: Dictionary = {}
		for point: Vector3 in points:
			if point.y <= bounds.position.y + bounds.size.y * 0.18: unique[point] = true
		return PackedVector3Array(unique.keys())
	var cells: Dictionary = {}
	for point: Vector3 in points:
		var cell: Vector2i = Vector2i(clampi(int((point.x - bounds.position.x) / bounds.size.x * 12.0), 0, 11), clampi(int((point.z - bounds.position.z) / bounds.size.z * 12.0), 0, 11))
		if not cells.has(cell) or point.y < cells[cell].y: cells[cell] = point
	var profile: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in cells.values():
		if point.y <= bounds.position.y + bounds.size.y * 0.18: profile.append(point)
	return profile


static func _collect_support_faces(node: Node3D, parent: Transform3D, faces: PackedVector3Array) -> void:
	var transform: Transform3D = parent * node.transform
	if node is MeshInstance3D:
		for point: Vector3 in node.mesh.get_faces(): faces.append(transform * point)
	for child: Node in node.get_children():
		if child is Node3D: _collect_support_faces(child, transform, faces)


static func _contact_offsets(stage: Node, holder: Node3D, profiles: Array[PackedVector3Array], support: Array[TriangleMesh]) -> Dictionary:
	var offsets: Array[float] = []
	var pair_heights: Array[float] = []
	var support_samples: int = 0
	for profile: PackedVector3Array in profiles:
		for surface: TriangleMesh in support:
			var highest: float = -INF
			for point: Vector3 in profile:
				var local: Vector3 = holder.basis * point
				var x: float = holder.position.x + local.x
				var z: float = holder.position.z + local.z
				var terrain: float = _terrain_height(stage, x, z)
				var height: float = terrain
				if surface != null:
					var hit: Dictionary = surface.intersect_ray(Vector3(x, 10.0, z), Vector3.DOWN)
					if not hit.is_empty(): height = maxf(height, hit.position.y)
				if height > terrain + 0.0001: support_samples += 1
				var offset: float = height - local.y
				offsets.append(offset)
				highest = maxf(highest, offset)
			pair_heights.append(highest)
	offsets.sort()
	pair_heights.sort()
	return {"offsets": offsets, "support_samples": support_samples,
		"lod_contact_spread_m": pair_heights[-1] - pair_heights[0]}


static func _ground_instance(stage: Node, holder: Node3D, profiles: Array[PackedVector3Array], foundation: bool, support: Array[TriangleMesh], footprint: float) -> Dictionary:
	var previous: Vector3 = holder.position
	var contact: Dictionary = _contact_offsets(stage, holder, profiles, support)
	# Check every colony/foundation LOD combination. On a thin rock edge a tiny
	# horizontal relocation avoids lifting the whole colony on a one-LOD sliver.
	if not foundation and contact.lod_contact_spread_m > 0.024:
		var best: Dictionary = contact
		var best_position: Vector3 = holder.position
		for radius: float in [0.025, 0.050, 0.075, 0.100, 0.125]:
			for direction: int in range(8):
				var angle: float = direction * TAU / 8.0
				var candidate: Vector3 = previous + Vector3(cos(angle), 0.0, sin(angle)) * radius
				if not _clear_of_navigation(Vector2(candidate.x, candidate.z), footprint): continue
				holder.position = candidate
				var trial: Dictionary = _contact_offsets(stage, holder, profiles, support)
				if trial.lod_contact_spread_m < best.lod_contact_spread_m:
					best = trial
					best_position = candidate
				if best.lod_contact_spread_m <= 0.024: break
			if best.lod_contact_spread_m <= 0.024: break
		contact = best
		holder.position = best_position
	var offsets: Array[float] = contact.offsets
	holder.position.y = offsets[int((offsets.size() - 1) * 0.55)] - 0.030 if foundation else offsets[-1] - 0.012
	var intersections: int = 0
	for offset: float in offsets:
		if holder.position.y <= offset: intersections += 1
	return {"sample_count": offsets.size(), "support_samples": contact.support_samples,
		"lod_contact_spread_m": contact.lod_contact_spread_m, "intersections": intersections,
		"min_gap_m": holder.position.y - offsets[-1], "max_gap_m": holder.position.y - offsets[0],
		"adjustment_y_m": holder.position.y - previous.y,
		"adjustment_xz_m": Vector2(holder.position.x - previous.x, holder.position.z - previous.z).length()}


static func _clear_of_navigation(point: Vector2, footprint: float) -> bool:
	if point.distance_to(Vector2(0.34, 0.05)) < 0.58 + footprint * 0.65:
		return false
	var a: Vector2 = Vector2(POSES.reef.position.x, POSES.reef.position.z)
	var b: Vector2 = Vector2(FISH_POSITION.x, FISH_POSITION.z)
	var t: float = clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return point.distance_to(a.lerp(b, t)) > 0.24 + footprint * 0.65


static func reef_layout() -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41037
	var result: Array[Dictionary] = []
	for patch_id: int in range(REEF_PATCHES.size()):
		var patch: Dictionary = REEF_PATCHES[patch_id]
		var center: Vector2 = patch.center
		var radius: float = patch.radius
		for member: int in range(int(patch.count)):
			var foundation: bool = member < 2
			var pick: float = rng.randf()
			var family: String = "rock" if foundation or pick > 0.82 else ("branching" if pick < 0.29 else ("plate" if pick < 0.57 else "massive"))
			# Stable spatial identity selects the same geometry pair at every scale.
			var asset_key: String = family
			if family == "plate": asset_key = PLATE_VARIANTS[(patch_id * 7 + member * 5) % PLATE_VARIANTS.size()]
			elif family == "branching": asset_key = BRANCH_VARIANTS[1 if (patch_id * 7 + member * 5) % 3 == 0 else 0]
			var size: float = lerpf(0.24, 0.90, pow(rng.randf(), 1.6))
			if family == "plate": size *= 0.76
			if family == "massive": size *= 0.72
			if family == "rock": size *= 0.40
			var dimensions: Vector3 = Vector3(size * rng.randf_range(0.82, 1.12), size * rng.randf_range(0.76, 1.12), size * rng.randf_range(0.82, 1.12))
			if foundation:
				# A compressed rock reads as a floating horizontal plate at low angles.
				# Preserve relief and vary the two foundation heights without advancing RNG.
				dimensions = Vector3(radius * 0.72, (0.26 + radius * 0.34) * (0.92 if member == 0 else 1.08), radius * 0.53)
			var radius_factor: float = PLATE_FOOTPRINTS[asset_key] if family == "plate" else {"branching": 0.44, "massive": 0.65, "rock": 1.03}[family]
			var footprint: float = maxf(dimensions.x, dimensions.z) * radius_factor
			var point: Vector2 = center
			var placed: bool = false
			for attempt: int in range(48):
				var angle: float = rng.randf_range(-PI, PI)
				var spread: float = radius * sqrt(rng.randf()) * (0.28 if foundation else 1.08)
				point = center + Vector2(cos(angle) * spread, sin(angle) * spread * 0.82)
				if not _clear_of_navigation(point, footprint): continue
				var separated: bool = true
				if not foundation:
					for previous: Dictionary in result:
						if previous.foundation: continue
						if point.distance_to(Vector2(previous.position.x, previous.position.z)) < (footprint + float(previous.footprint)) * 0.55:
							separated = false
							break
				if separated:
					placed = true
					break
			if not placed:
				# Bounded rejection never pushes a colony into the host or camera path.
				point = center + Vector2(radius * 1.35, -radius * 0.35)
				if not _clear_of_navigation(point, footprint): point.x += radius
			var normal: Vector3 = Vector3.UP.lerp(_ground_normal(point.x, point.y), 0.62 if family == "rock" else 0.28).normalized()
			var yaw: float = rng.randf_range(-PI, PI)
			var basis: Basis = Basis(Quaternion(Vector3.UP, normal)).rotated(normal, yaw).scaled(dimensions)
			var tint_value: Color = COLONY_PALETTE[rng.randi_range(0, COLONY_PALETTE.size() - 1)]
			tint_value *= rng.randf_range(0.92, 1.05)
			tint_value.a = 1.0
			result.append({"family": family, "asset_key": asset_key, "patch": patch_id, "foundation": foundation,
				"position": Vector3(point.x, _height(point.x, point.y) - (0.12 if foundation else 0.035), point.y),
				"basis": basis, "scale": dimensions, "footprint": footprint, "tint": tint_value,
				"rejection_fallback": not placed})
	_append_patch_growth(result)
	for index: int in MASSIVE_PLACEMENTS:
		var authored: Dictionary = MASSIVE_PLACEMENTS[index]
		result[index].position.x = authored.point.x
		result[index].position.z = authored.point.y
		result[index].basis = authored.basis
		result[index].footprint = authored.footprint
	for index: int in POCILLOPORA_PLACEMENTS:
		result[index].position = POCILLOPORA_PLACEMENTS[index].position
		result[index].basis = POCILLOPORA_PLACEMENTS[index].basis
	for index: int in PLATE_PLACEMENTS:
		result[index].position = PLATE_PLACEMENTS[index].position
		result[index].basis = PLATE_PLACEMENTS[index].basis
		result[index].footprint = PLATE_PLACEMENTS[index].footprint
	return result


static func _append_patch_growth(layout: Array[Dictionary]) -> void:
	# A separate stream preserves the existing 100 colony identities. Near and
	# middle reef shoulders gain smaller clusters, with no new far-field wall.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 69197
	for patch_id: int in range(6):
		var patch: Dictionary = REEF_PATCHES[patch_id]
		var anchors: Array[Vector2] = []
		for placement: Dictionary in layout:
			if placement.patch == patch_id and placement.foundation:
				anchors.append(Vector2(placement.position.x, placement.position.z))
		for member: int in range(8 if patch_id < 4 else 5):
			var family: String = "massive" if member % 4 == 3 else "branching"
			var key: String = BRANCH_VARIANTS[(patch_id + member) % 2] if family == "branching" else "massive"
			var size: float = rng.randf_range(0.34, 0.64) * (0.68 if family == "massive" else 1.0)
			var dimensions: Vector3 = Vector3(size * rng.randf_range(0.86, 1.12), size * rng.randf_range(0.82, 1.12), size * rng.randf_range(0.86, 1.12))
			var footprint: float = maxf(dimensions.x, dimensions.z) * (0.44 if family == "branching" else 0.65)
			var point: Vector2 = Vector2.ZERO
			var placed: bool = false
			for attempt: int in range(80):
				var angle: float = rng.randf_range(-PI, PI)
				var spread: float = float(patch.radius) * rng.randf_range(0.12, 0.82)
				point = anchors[member % anchors.size()] + Vector2(cos(angle), sin(angle) * 0.78) * spread
				if not _clear_of_navigation(point, footprint): continue
				# Continue the clear sightline behind the target: a new dark mound
				# immediately behind the two fish would obscure their silhouettes.
				var host: Vector2 = Vector2(FISH_POSITION.x, FISH_POSITION.z)
				var back: Vector2 = (host - Vector2(POSES.reef.position.x, POSES.reef.position.z)).normalized()
				var t: float = clampf((point - host).dot(back), 0.0, 2.5)
				if point.distance_to(host + back * t) < 0.20 + footprint: continue
				var separated: bool = true
				for previous: Dictionary in layout:
					if previous.foundation: continue
					if point.distance_to(Vector2(previous.position.x, previous.position.z)) < (footprint + float(previous.footprint)) * 0.68:
						separated = false
						break
				if separated:
					placed = true
					break
			# Failure omits a decorative colony instead of forcing an overlap.
			if not placed: continue
			var normal: Vector3 = Vector3.UP.lerp(_ground_normal(point.x, point.y), 0.18).normalized()
			var basis: Basis = Basis(Quaternion(Vector3.UP, normal)).rotated(normal, rng.randf_range(-PI, PI)).scaled(dimensions)
			var tint_value: Color = [Color(0.95, 0.86, 0.71), Color(0.80, 0.84, 0.69), Color(0.85, 0.72, 0.64), Color(0.92, 0.91, 0.81)][(patch_id + member) % 4]
			layout.append({"family": family, "asset_key": key, "patch": patch_id, "foundation": false,
				"position": Vector3(point.x, _height(point.x, point.y), point.y), "basis": basis,
				"scale": dimensions, "footprint": footprint, "tint": tint_value, "rejection_fallback": false})


static func _bake_matches(stage: Node) -> bool:
	if BakedPlacements.layout_version != PLACEMENT_VERSION or BakedPlacements.layout.size() != 140:
		return false
	if BakedPlacements.rubble_by_patch.size() != REEF_PATCHES.size(): return false
	# The baked layout depends on its original placement assets, not later
	# independently placed animals or plants in the same stage.
	for key: String in BakedPlacements.asset_paths:
		if not stage.assets.has(key) or BakedPlacements.asset_paths[key] != stage.assets[key].resource_path: return false
	return true


static func _build_reef(stage: Node) -> void:
	var cache: Dictionary = {}
	var lod_objects: Array[Dictionary] = []
	# The same authored recipe remains available to the offline baker. Stale
	# version/path data falls back to computation, never to an empty reef.
	var baking: bool = bool(stage.get_meta("reef_bake_requested", false)) or not _bake_matches(stage)
	var layout: Array[Dictionary] = reef_layout() if baking else BakedPlacements.layout.duplicate(true)
	stage.set_meta("reef_placement_mode", "computed" if baking else "baked")
	var contact_cache: Dictionary = {}
	var support_faces: Dictionary = {"high": PackedVector3Array(), "low": PackedVector3Array()}
	var support: Array[TriangleMesh] = []
	var terrain_only: Array[TriangleMesh] = [null]
	lod_objects.resize(layout.size())
	for foundations_only: bool in [true, false]:
		if not foundations_only and baking:
			for quality: String in ["high", "low"]:
				var mesh: TriangleMesh = TriangleMesh.new()
				mesh.create_from_faces(support_faces[quality])
				support.append(mesh)
			support_faces.clear()
		for i: int in range(layout.size()):
			var placement: Dictionary = layout[i]
			if bool(placement.foundation) != foundations_only: continue
			var key: String = placement.family
			var asset_key: String = placement.asset_key
			var model: Node3D = Node3D.new()
			model.name = "ReefGrowth_%03d" % i
			model.transform = Transform3D(placement.basis, placement.position)
			model.set_meta("reef_patch", placement.patch)
			model.set_meta("reef_family", key)
			model.set_meta("reef_asset_key", asset_key)
			stage.world_root.add_child(model)
			var high: Node3D = stage.asset_instance(("growth_rock" if key == "rock" else asset_key) + "_high")
			var low: Node3D = stage.asset_instance(("growth_rock" if key == "rock" else asset_key) + "_low")
			model.add_child(high)
			model.add_child(low)
			if baking:
				var contact_key: String = asset_key + (":foundation" if foundations_only else ":colony")
				if not contact_cache.has(contact_key):
					var profiles: Array[PackedVector3Array] = []
					if foundations_only: profiles.append(_contact_profile(high, low))
					else:
						profiles.append(_contact_profile(high, high, true))
						profiles.append(_contact_profile(low, low, true))
					contact_cache[contact_key] = profiles
				placement["contact"] = _ground_instance(stage, model, contact_cache[contact_key], placement.foundation, terrain_only if foundations_only else support, placement.footprint)
				placement.position = model.position
				if foundations_only:
					_collect_support_faces(high, model.transform, support_faces.high)
					_collect_support_faces(low, model.transform, support_faces.low)
			_replace_opaque_materials(stage, high, cache, key, 0.0, placement.tint)
			_replace_opaque_materials(stage, low, cache, key, 0.0, placement.tint)
			var proxy: MeshInstance3D
			if key == "branching":
				proxy = _make_proxy(stage, asset_key, placement.tint)
				model.add_child(proxy)
			lod_objects[i] = {"identity": "reef:growth:%03d" % i, "holder": model, "high": high, "low": low, "proxy": proxy, "visual_radius_m": placement.footprint}
	_build_rubble(stage, cache, support, baking)
	var rock: Node3D = stage.asset_instance("rock_high")
	rock.name = "HostAttachmentRock"
	rock.position = Vector3(0.34, 0.015, 0.05)
	rock.scale = Vector3(0.40, 0.40, 0.40)
	stage.world_root.add_child(rock)
	_replace_opaque_materials(stage, rock, cache, "rock", 0.0)
	var anemone: Node3D = Node3D.new()
	anemone.name = "HostAnemone"
	anemone.position = Vector3(0.33, 0.342, 0.06)
	anemone.scale = Vector3.ONE * 1.3
	stage.world_root.add_child(anemone)
	var anemone_high: Node3D = stage.asset_instance("anemone_high")
	var anemone_low: Node3D = stage.asset_instance("anemone_low")
	anemone.add_child(anemone_high)
	anemone.add_child(anemone_low)
	anemone_low.visible = false
	_replace_opaque_materials(stage, anemone, cache, "anemone", 0.004)
	# One stage-owned host; both LODs share attachment, materials and world time.
	stage.set_meta("host_anemone_lod", {"holder": anemone, "high": anemone_high,
		"low": anemone_low, "local_radius_m": 0.202})
	stage.set_meta("reef_material_cache", cache)
	stage.set_meta("lod_objects", lod_objects)
	stage.set_meta("reef_layout", layout)


static func _build_rubble(stage: Node, cache: Dictionary, support: Array[TriangleMesh], baking: bool) -> void:
	# Reuse the existing 3D low rock, grouped per patch for bounded draw/culling
	# regions. Small rubble softens the transition from reef shoulders to sand.
	var prototype: Node3D = stage.asset_instance("rock_low")
	_replace_opaque_materials(stage, prototype, cache, "rock", 0.0)
	var source: MeshInstance3D = prototype.get_child(0) as MeshInstance3D
	assert(source != null and source.transform == Transform3D.IDENTITY and prototype.transform == Transform3D.IDENTITY)
	var profile: PackedVector3Array = _contact_profile(prototype, prototype, true) if baking else PackedVector3Array()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73109
	var placements: Array[Transform3D] = []
	var groups: Array[Dictionary] = []
	for patch_id: int in range(REEF_PATCHES.size()):
		var patch: Dictionary = REEF_PATCHES[patch_id]
		var transforms: Array[Transform3D] = []
		if baking:
			var wanted: int = 30 if patch_id < 4 else 16
			for attempt: int in range(wanted * 8):
				if transforms.size() == wanted: break
				var angle: float = rng.randf_range(-PI, PI)
				var spread: float = float(patch.radius) * rng.randf_range(0.62, 1.48)
				var point: Vector2 = patch.center + Vector2(cos(angle), sin(angle) * 0.82) * spread
				var size: float = rng.randf_range(0.026, 0.073)
				if not _clear_of_navigation(point, size * 1.03): continue
				var terrain_y: float = _terrain_height(stage, point.x, point.y)
				var on_foundation: bool = false
				for surface: TriangleMesh in support:
					var hit: Dictionary = surface.intersect_ray(Vector3(point.x, 10.0, point.y), Vector3.DOWN)
					if not hit.is_empty() and hit.position.y > terrain_y + size * 0.2:
						on_foundation = true
						break
				if on_foundation: continue
				var normal: Vector3 = _ground_normal(point.x, point.y)
				var basis: Basis = Basis(Quaternion(Vector3.UP, normal)).rotated(normal, rng.randf_range(-PI, PI)).scaled(Vector3(size, size * rng.randf_range(0.65, 1.0), size))
				var y: float = -INF
				for vertex: Vector3 in profile:
					var local: Vector3 = basis * vertex
					y = maxf(y, _terrain_height(stage, point.x + local.x, point.y + local.z) - local.y)
				var transform: Transform3D = Transform3D(basis, Vector3(point.x, y - 0.004, point.y))
				transforms.append(transform)
		else:
			transforms.assign(BakedPlacements.rubble_by_patch[patch_id].transforms)
		groups.append({"patch": patch_id, "transforms": transforms})
		placements.append_array(transforms)
		var instances: MultiMesh = MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = source.mesh
		instances.instance_count = transforms.size()
		for index: int in range(transforms.size()): instances.set_instance_transform(index, transforms[index])
		var rubble: MultiMeshInstance3D = MultiMeshInstance3D.new()
		rubble.name = "ReefRubble_%02d" % patch_id
		rubble.multimesh = instances
		rubble.material_override = source.get_active_material(0)
		stage.world_root.add_child(rubble)
	stage.set_meta("reef_rubble_placements", placements)
	stage.set_meta("reef_rubble_groups", groups)
	prototype.free()


static func _make_proxy(stage: Node, asset_key: String, colony_tint: Color = Color.WHITE) -> MeshInstance3D:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(1.2, 1.2)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = stage.textures.coral_bush_proxy if asset_key == "branching_bush" else stage.textures.coral_proxy
	material.albedo_color = colony_tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.35
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(0, 0.38, 0)
	instance.rotation.x = deg_to_rad(-5.71)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func _replace_opaque_materials(stage: Node, node: Node, cache: Dictionary, family: String, flex: float, colony_tint: Color = Color.WHITE) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node
		instance.set_instance_shader_parameter("colony_tint", colony_tint)
		for surface: int in range(instance.mesh.get_surface_count()):
			var original: Material = instance.get_active_material(surface)
			if not original is StandardMaterial3D:
				continue
			var standard: StandardMaterial3D = original
			if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var key: String = family + ":" + standard.resource_name
			if not cache.has(key):
				var material: ShaderMaterial = ShaderMaterial.new()
				material.shader = SurfaceShader
				material.set_shader_parameter("tint", standard.albedo_color)
				var color_modulation: Color = {"branching": Color(0.95, 0.94, 0.91), "plate": Color(0.96, 0.90, 0.86), "massive": Color(0.91, 0.94, 0.90), "rock": Color(0.98, 0.88, 0.76), "anemone": Color(1.0, 0.96, 0.85)}.get(family, Color.WHITE)
				material.set_shader_parameter("tint", standard.albedo_color * color_modulation)
				material.set_shader_parameter("roughness_value", standard.roughness)
				material.set_shader_parameter("surface_normal_depth", 1.2 if family == "plate" else 0.6)
				material.set_shader_parameter("caustic_strength", 0.18 if family != "anemone" else 0.26)
				material.set_shader_parameter("saturation", 1.0 if family == "anemone" else 0.90)
				material.set_shader_parameter("rock_surface", family == "rock" and not standard.resource_name.begins_with("coast_rocks_05"))
				material.set_shader_parameter("mottle_strength", 0.0 if family == "anemone" or standard.resource_name.begins_with("coast_rocks_05") else 0.12)
				material.set_shader_parameter("flex_strength", flex)
				if standard.albedo_texture != null:
					material.set_shader_parameter("base_texture", standard.albedo_texture)
					material.set_shader_parameter("has_texture", true)
				if standard.normal_texture != null:
					material.set_shader_parameter("normal_texture", standard.normal_texture)
					material.set_shader_parameter("has_normal", true)
				if standard.roughness_texture != null:
					material.set_shader_parameter("roughness_texture", standard.roughness_texture)
					material.set_shader_parameter("roughness_channel", standard.roughness_texture_channel)
					material.set_shader_parameter("has_roughness", true)
				cache[key] = material
				stage.materials.append(material)
			instance.set_surface_override_material(surface, cache[key])
	for child: Node in node.get_children():
		_replace_opaque_materials(stage, child, cache, family, flex, colony_tint)


static func _build_target(stage: Node) -> void:
	var fish_material_cache: Dictionary = {}
	var fish: Node3D = stage.asset_instance("fish_high")
	_configure_fish_materials(fish, fish_material_cache)
	fish.name = "TargetFish"
	fish.position = FISH_POSITION
	fish.set_meta("target_fish_id", stage.world_snapshot.target_fish_id)
	stage.world_root.add_child(fish)
	stage.animated_nodes.append({"node": fish, "kind": "target_fish"})
	# A local anemone association, not a migratory school of anemonefish.
	var companion: Node3D = stage.asset_instance("fish_low")
	_configure_fish_materials(companion, fish_material_cache)
	companion.position = Vector3(0.16, 0.55, -0.08)
	companion.rotation.y = 0.5
	companion.scale = Vector3.ONE * 0.67
	stage.world_root.add_child(companion)
	stage.animated_nodes.append({"node": companion, "kind": "habitat_companion"})
	# Keep shared surface overrides alive until all stage mesh instances are gone.
	stage.set_meta("fish_material_cache", fish_material_cache)
	stage.set_meta("target_node", fish)


static func _configure_fish_materials(node: Node, cache: Dictionary) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var source: StandardMaterial3D = instance.get_active_material(surface) as StandardMaterial3D
			if source == null: continue
			var thin_fin: bool = source.resource_name == "Percula_v3_Fin_Thin_Edge"
			var root_fin: bool = source.resource_name == "Percula_v3_Fin_Membrane"
			var fin_ray: bool = source.resource_name == "Fin_rays"
			var skin: bool = source.resource_name == "Percula_v3_Pigment_PBR"
			var eye: bool = source.resource_name == "Percula_v3_Living_Eye"
			var cornea: bool = source.resource_name == "Corneal_surface"
			var soft_detail: bool = source.resource_name in ["Living_lip_tissue", "Soft_black_pigment"]
			if not thin_fin and not root_fin and not fin_ray and not skin and not eye and not cornea and not soft_detail: continue
			var key: int = source.get_instance_id()
			if not cache.has(key):
				if skin:
					# UV-anchored pigment removes the baked periodic colour ripple;
					# retain the imported scale normal map and the shared ownership.
					var skin_material: ShaderMaterial = ShaderMaterial.new()
					skin_material.shader = FishSkinShader
					skin_material.resource_name = "Percula_Underwater_Skin"
					skin_material.set_shader_parameter("normal_texture", source.normal_texture)
					skin_material.set_shader_parameter("has_roughness_texture", source.roughness_texture != null)
					if source.roughness_texture != null:
						skin_material.set_shader_parameter("roughness_texture", source.roughness_texture)
						skin_material.set_shader_parameter("roughness_channel", source.roughness_texture_channel)
					skin_material.set_shader_parameter("normal_strength", clampf(source.normal_scale, 0.35, 0.55))
					cache[key] = skin_material
				elif thin_fin or root_fin or fin_ray or eye:
					var surface_material: ShaderMaterial = ShaderMaterial.new()
					surface_material.resource_name = source.resource_name
					if thin_fin: surface_material.shader = FishFinShader
					elif root_fin: surface_material.shader = FishFinRootShader
					elif fin_ray: surface_material.shader = FishFinRayShader
					else: surface_material.shader = FishEyeShader
					# v6 rays retain the rig/UV2 and carry the membrane UV in COLOR_0.
					# High and low instances share this stage-owned material cache.
					cache[key] = surface_material
				else:
					var material: StandardMaterial3D = source.duplicate() as StandardMaterial3D
					if soft_detail:
						material.metallic_specular = 0.18
					if cornea:
						material.metallic_specular = 0.48
						material.roughness = 0.08
						material.albedo_color = Color(0.08, 0.10, 0.10, 0.025)
					cache[key] = material
			instance.set_surface_override_material(surface, cache[key])
	for child: Node in node.get_children():
		_configure_fish_materials(child, cache)


static func _build_water(stage: Node) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(160, 160)
	plane.subdivide_width = 180
	plane.subdivide_depth = 180
	var arrays: Array = plane.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index: int in range(vertices.size()):
		vertices[index].x = _extend_horizon(vertices[index].x)
		vertices[index].z = _extend_horizon(vertices[index].z)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = WaterShader
	material.set_shader_parameter("light_direction", (stage.get_meta("ocean_sky_material") as ShaderMaterial).get_shader_parameter("light_direction"))
	stage.materials.append(material)
	stage.set_meta("ocean_surface_material", material)
	stage.add_mesh(mesh, material, Vector3(0, SEA_LEVEL, 0)).name = "OceanSurface"


static func _build_particles(stage: Node) -> void:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = ParticleShader
	material.set_shader_parameter("particle_texture", stage.textures.snow)
	stage.materials.append(material)
	mesh.material = material
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = 240
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8309
	for i: int in range(multimesh.instance_count):
		var position: Vector3 = Vector3(rng.randf_range(-5, 5), rng.randf_range(0.2, 4.8), rng.randf_range(-9, 4))
		var size: float = rng.randf_range(0.006, 0.028)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), position))
		multimesh.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf_range(0.18, 0.50)))
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.world_root.add_child(instance)


static func update_camera(stage: Node) -> void:
	# Only the actual close polyp camera needs a submillimetre near plane.
	var close_polyp: bool = false
	var coral_targets: Array = stage.get_meta("coral_targets",[])
	if coral_targets.size()>1: close_polyp=stage.camera.position.distance_to(coral_targets[1].node.position)<.10
	stage.camera.near=.0007 if stage.scale_id=="fish" or close_polyp else .008
	var immersion: float = smoothstep(SEA_LEVEL + 0.15, SEA_LEVEL - 0.15, stage.camera.position.y)
	stage.is_underwater = immersion >= 0.5
	var water: ShaderMaterial = stage.get_meta("ocean_surface_material")
	# Orbiting fully above/below water does not change this state. Rewriting
	# the same sky uniform dirties its radiance cubemap on every mouse event.
	if immersion != float(stage.get_meta("water_immersion", -1.0)):
		stage.set_meta("water_immersion", immersion)
		water.set_shader_parameter("immersion", immersion)
		(stage.get_meta("ocean_sky_material") as ShaderMaterial).set_shader_parameter("immersion", immersion)
		stage.environment.fog_density = WATER_FOG_DENSITY * immersion
		water.set_shader_parameter("underwater_fog_density", stage.environment.fog_density)
		stage.environment.volumetric_fog_density = WATER_VOLUME_DENSITY * immersion
		stage.environment.fog_sky_affect = immersion
		stage.environment.volumetric_fog_sky_affect = immersion
	# Authored lens crossing: 6cm covers the full 5.4cm wave amplitude.
	# Restore the surface outside 22cm; this is a visual blend, not optical simulation.
	var surface_visibility: float = smoothstep(0.06, 0.22, absf(stage.camera.position.y - SEA_LEVEL))
	if surface_visibility != float(stage.get_meta("water_surface_visibility", -1.0)):
		water.set_shader_parameter("surface_visibility", surface_visibility)
		stage.set_meta("water_surface_visibility", surface_visibility)
	var eye: Vector3 = stage.camera.global_position
	var half_fov_tangent: float = tan(deg_to_rad(stage.camera.fov) * 0.5)
	var host: Dictionary = stage.get_meta("host_anemone_lod")
	var host_holder: Node3D = host.holder
	var host_center: Vector3 = host_holder.to_global(Vector3(0, 0.055, 0))
	var host_scale: Vector3 = host_holder.global_basis.get_scale().abs()
	var host_radius: float = float(host.local_radius_m) * maxf(host_scale.x, maxf(host_scale.y, host_scale.z))
	var host_distance: float = maxf(eye.distance_to(host_center), 0.001)
	var host_fraction: float = host_radius / (host_distance * half_fov_tangent)
	# Hysteresis prevents camera jitter from alternating the two rounded meshes.
	var host_high: bool = host_fraction >= (0.28 if host.high.visible else 0.35)
	host.high.visible = host_high
	host.low.visible = not host_high
	stage.set_meta("host_anemone_visible_lod", "high" if host_high else "low")
	var count: Dictionary = {"high": 0, "low": 0, "proxy": 0}
	for item: Dictionary in stage.get_meta("lod_objects", []):
		var holder: Node3D = item.holder
		var distance: float = holder.global_position.distance_to(eye)
		var show_high: bool = distance < 1.8
		if holder.get_meta("reef_family") == "rock":
			# Large foundations still occupy hundreds of pixels beyond 1.8 m.
			# Estimate diameter / viewport height from the authored XZ radius;
			# preserve engine mesh auto-LOD inside the selected geometry resource.
			var screen_fraction: float = float(item.visual_radius_m) / (maxf(distance, 0.001) * half_fov_tangent)
			show_high = show_high or screen_fraction >= 0.22
		var show_proxy: bool = false
		if item.proxy != null and distance > 12.0:
			var local_eye: Vector3 = holder.to_local(eye) - Vector3(0, 0.38, 0)
			var azimuth: float = absf(rad_to_deg(atan2(local_eye.x, local_eye.z)))
			var elevation: float = rad_to_deg(atan2(local_eye.y, Vector2(local_eye.x, local_eye.z).length()))
			show_proxy = azimuth <= 12.0 and absf(elevation - 5.71) <= 10.0
		item.high.visible = show_high
		item.low.visible = not show_high and not show_proxy
		if item.proxy != null: item.proxy.visible = show_proxy
		count["high" if show_high else ("proxy" if show_proxy else "low")] += 1
	stage.set_meta("lod_visible_counts", count)


static func animate(stage: Node, _time: float) -> void:
	Biodiversity.animate(stage, _time)
	Coral.animate(stage, _time)
	DayOctopus.animate(stage, _time)
	BlackSeaCucumber.Activity.animate(stage, _time)
	if stage.has_meta("target_node"):
		var fish: Node3D = stage.get_meta("target_node")
		stage.target_position = fish.transform * Vector3(0.018, -0.007, 0) if stage.scale_id == "fish" else fish.position


static func entry_pose(stage: Node, source_id: String) -> Dictionary:
	if source_id == "atmosphere":
		return _atmosphere_boundary_pose()
	if POSES.has(source_id):
		return POSES[source_id].duplicate()
	if source_id == "heart":
		var fish: Node3D = stage.get_meta("target_node")
		return {"position": fish.transform * Vector3(0.019, -0.006, 0.008), "target": fish.transform * Vector3(0.018, -0.007, 0)}
	return POSES.pacific.duplicate()


static func exit_pose(stage: Node, target_id: String) -> Dictionary:
	if target_id == "atmosphere":
		return _atmosphere_boundary_pose()
	if POSES.has(target_id):
		return POSES[target_id].duplicate()
	if target_id == "heart":
		var fish: Node3D = stage.get_meta("target_node")
		return {"position": fish.transform * Vector3(0.019, -0.006, 0.008), "target": fish.transform * Vector3(0.018, -0.007, 0)}
	return {"position": Vector3(3, 12, 14), "target": Vector3(0, 4, 0)}


static func _atmosphere_boundary_pose() -> Dictionary:
	# Cosmos atmosphere uses kilometres and sea level zero; this reef uses
	# metres with a sea surface at SEA_LEVEL. Both look toward the same anchor.
	return {"position": Vector3(0, SEA_LEVEL + 8.0, 22.0), "target": Vector3(0, SEA_LEVEL, 0)}
