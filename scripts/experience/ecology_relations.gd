extends RefCounted
## Read-only feeding examples, not a second ecosystem simulation.
const BRANCHES: Array[String] = ["reef", "woodland", "desert", "polar"]
const LABELS: Array[String] = ["海洋生命", "林地生态", "荒漠生境", "南极海岸"]
const SOURCES: Dictionary = {
	"surgeon":"https://fishesofaustralia.net.au/home/species/2204",
	"snapper":"https://fishesofaustralia.net.au/home/species/559",
	"chromis":"https://fishesofaustralia.net.au/home/species/329",
	"turtle":"https://www.fisheries.noaa.gov/species/green-turtle",
	"monarch":"https://www.nps.gov/articles/monarch-butterfly.htm",
	"fungi":"https://www.nps.gov/muwo/learn/nature/decomposing-fungi.htm",
	"deer":"https://www.nps.gov/articles/000/forest-health-deer-browsing.htm",
	"iguana":"https://www.desertmuseum.org/books/nhsd_desert_iguana.php",
	"mesquite":"https://research.fs.usda.gov/feis/species-reviews/provel",
	"adelie":"https://www.antarctica.gov.au/about-antarctica/animals/penguins/adelie-penguin/"
}

static func node(id: String, label: String, topic: String, row: int, consumer: bool=false) -> Dictionary:
	return {"id":id,"label":label,"topic":topic,"row":row,"consumer":consumer}

static func edge(a: String, b: String, title: String, note: String, source: String) -> Dictionary:
	return {"from":a,"to":b,"title":title,"note":note,"source":SOURCES[source]}

static func for_branch(id: String) -> Dictionary:
	if id=="reef":
		return {"nodes":[
			node("algae","藻类 · 生产者","algae",0),
			node("seagrass","海草 · 生产者","seagrass",1),
			node("plankton","浮游动物 · 有限水层教学资源","school",2),
			node("prey","小鱼 / 甲壳类 · 食物类别","",3),
			node("surgeon","褐吊 · 食藻消费者","algae",0,true),
			node("turtle","绿海龟 · 成体食性参考","turtle",1,true),
			node("school","青绿雀鲷 · 浮游食性","school",2,true),
			node("snapper","四带笛鲷 · 捕食消费者","snapper",3,true)],
		"edges":[
			edge("algae","surgeon","藻类 → 褐吊","褐吊摄食藻类；进入主题可看六斑块资源随摄食减少与恢复，并比较下一轮选点。速率和选择规则未按物种标定。","surgeon"),
			edge("algae","turtle","藻类 → 绿海龟","成体绿海龟主要取食海草与藻类；幼体食性不同。图中没有计算摄食量。","turtle"),
			edge("seagrass","turtle","海草 → 绿海龟","海草表示食物类型。场景卵叶喜盐草是形态参考，连线不声称这只龟正在摄食该株。","turtle"),
			edge("plankton","school","浮游动物 → 青绿雀鲷","进入鱼群主题可看水层教学单位逐个减少；12单位/4秒是作者参数，不是可鉴定动物数、实测密度或个体捕获计算。鱼群邻近规则另行运行。","chromis"),
			edge("prey","snapper","小鱼 / 甲壳类 → 四带笛鲷","只连资料支持的食物类别，不擅自指定场景中某一种小鱼为实际猎物。","snapper")]}
	if id=="woodland":
		return {"nodes":[
			node("nectar","花蜜 · 植物的产物","monarch",0),
			node("milkweed","乳草叶 · 生产者组织","monarch_larva",1),
			node("leaves","叶 / 嫩枝 · 植物组织","browse",2),
			node("wood","枯木 · 死有机物","deadwood",3),
			node("adult","帝王蝶成虫 · 消费者","monarch",0,true),
			node("larva","帝王蝶幼虫 · 消费者","monarch_larva",1,true),
			node("deer","白尾鹿 · 植食消费者","browse",2,true),
			node("fungus","云芝 · 分解者","fungus",3,true)],
		"edges":[
			edge("nectar","adult","花蜜 → 帝王蝶成虫","成虫从花中吸食花蜜；访花动作不代表已经模拟花粉转移或完成授粉。","monarch"),
			edge("milkweed","larva","乳草叶 → 帝王蝶幼虫","同一物种在不同生命阶段吃不同食物。进入主题可比较实际叶片上的幼虫与访花成虫；未模拟叶片消耗或变态发育。","monarch"),
			edge("leaves","deer","叶 / 嫩枝 → 白尾鹿","进入取食与恢复可观察双样方的局部教学反馈；不把未鉴种样方当作白橡或乳草。","deer"),
			edge("wood","fungus","枯木有机物 → 云芝","菌丝利用木材中的有机物；子实体不是整个真菌。木材损失不能全部当成植物养分，碳去向可在枯木分解主题查看。","fungi")]}
	if id=="desert":
		return {"nodes":[node("plants","植物材料 · 食物类别","",0),node("mesquite","牧豆树种子 · 有限教学资源","desert_mesquite",1),node("iguana","沙漠鬣蜥 · 以植物为主","desert_iguana",0,true),node("rat","梅氏袋鼠鼠 · 夜间食籽","desert_rat",1,true)],
		"edges":[edge("plants","iguana","植物材料 → 沙漠鬣蜥","主要摄食植物。场景展示灌丛与鬣蜥身体，不展示不存在的花果或计算摄食消耗。","iguana"),edge("mesquite","rat","牧豆树种子 → 梅氏袋鼠鼠","进入夜间主题可看地表教学单位经颊囊移入洞穴缓存；总量守恒，搬运节律与8单位由作者设定。不是实测取食、萌发或种群扩散。","mesquite")]}
	if id=="polar":
		return {"nodes":[node("krill","冰磷虾 · 近岸浮游动物","ice_krill",0),node("penguin","阿德利企鹅 · 消费者","adelie_penguin",0,true)],
		"edges":[edge("krill","penguin","冰磷虾 → 阿德利企鹅","冰磷虾Euphausia crystallorophias是阿德利企鹅近岸食物的一种，离岸食物中的南极磷虾E. superba是另一物种。两端可进入本场景实际模型；连线只是资料支持的食物关系，未模拟企鹅下水捕食、磷虾减少或能量转移。","adelie")]}
	return {"nodes":[],"edges":[]}
