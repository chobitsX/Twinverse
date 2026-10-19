extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
const Model = preload("res://scripts/core/algal_grazing.gd")
static func readout(host: Node) -> String:
	var data: Dictionary=host.world.algal_grazing.snapshot()
	var values: PackedStringArray=[]
	var grown: float=0.;var eaten: float=0.
	for i: int in range(6):
		values.append("%d: %.0f" % [i+1,data.stock[i]])
		grown+=float(data.grown[i]);eaten+=float(data.eaten[i])
	return I18n.text("六处藻量（各自上限100）\n%s\n累计恢复 %.1f · 累计摄食 %.1f\n代表鱼选择：斑块%d\n相对资源单位；速度与选点规则为加速教学设置") % ["  /  ".join(values),grown,eaten,int(data.targets[0])+1]

static func marks(host: Node) -> Array[Dictionary]:
	var stage: Node=host.coordinator.active_scene
	if not stage.has_meta("marine_actors") or not stage.has_meta("feeding_patches"): return []
	var target: int=host.world.algal_grazing.targets[0]
	var fish: Node3D=stage.get_meta("marine_actors")[0].node
	return [{"at":fish.position,"label":I18n.text("褐吊 · 代表个体"),"offset":Vector2(35,-75)},
		{"at":stage.get_meta("feeding_patches")[target],"label":I18n.text("斑块%d · 藻量%.0f / 100") % [target+1,host.world.algal_grazing.stock[target]],"offset":Vector2(70,55),"link":0}]
