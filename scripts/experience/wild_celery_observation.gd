extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Submerged plant reference in the existing synthetic woodland channel.
## Positions and subtle sway use the host world time; no flow or growth solver.
const Woodland = preload("res://scripts/experience/woodland_environment.gd")
const SOURCE: String = "https://warcapps.usgs.gov/PlantID/Species/Details/1235"
const CLUMP_COUNT: int = 20

static func placement(index: int) -> Vector3:
	var z: float=8.4+.4*float(index)
	var side: float=1.0 if index%2==0 else -1.0
	var offset: float=2.18+.16*float(index%4)
	var x: float=Woodland.river_center(z)+side*offset
	return Vector3(x,Woodland.height_at(x,z)+.012,z)

static func build(stage: Node) -> void:
	var clumps: Array[Node3D]=[]
	for i: int in range(CLUMP_COUNT):
		var clump: Node3D=stage.assets.american_wild_celery.instantiate()
		clump.name="AmericanWildCelery%02d" % i
		clump.position=placement(i)
		clump.rotation.y=.37*float(i%7)
		clump.scale=Vector3.ONE*(.92+.018*float(i%5))
		clump.set_meta("stable_id","3dworld:teaching:wild-celery:clump:%04d" % i)
		clump.set_meta("activity",I18n.text("美洲苦草 · 河床沉水叶丛（作者布置）"))
		stage.world_root.add_child(clump)
		clumps.append(clump)
	var first: Node3D=clumps[18]
	var whole: Node3D=first.find_child("WildCeleryWholeAnchor",true,false) as Node3D
	var leaf: Node3D=first.find_child("WildCeleryLeafAnchor",true,false) as Node3D
	var rosette: Node3D=first.find_child("WildCeleryRosetteAnchor",true,false) as Node3D
	var runner: Node3D=first.find_child("WildCeleryRunnerAnchor",true,false) as Node3D
	assert(whole!=null and leaf!=null and rosette!=null and runner!=null)
	# Observation navigation reads target.position in stage coordinates. Keep a
	# world-root target near the imported whole-clump anchor for a clear leaf view.
	var leaf_target: Node3D=Node3D.new()
	leaf_target.name="WildCeleryLeafTarget"
	leaf_target.position=whole.global_position+Vector3(0,.06,0)
	leaf_target.set_meta("stable_id","3dworld:teaching:wild-celery:leaf")
	leaf_target.set_meta("activity",I18n.text("美洲苦草 · 同一叶丛的带状叶与走茎"))
	stage.world_root.add_child(leaf_target)
	stage.set_meta("wild_celery",{"clumps":clumps,"first":first,"whole":whole,"leaf":leaf_target,"leaf_anchor":leaf,"rosette":rosette,"runner":runner})
	stage.set_meta("wild_celery_targets",[
		{"node":first,"label":I18n.text("美洲苦草 · Vallisneria americana"),"role":I18n.text("河床上的沉水基生莲座与带状叶；二十处作者叶丛沿同一合成缓流河道布置，并非实测覆盖率。"),"source_url":SOURCE,"distance":1.4,"focus_height":.27,"view_offset":Vector3(.75,.31,.96)},
		{"node":leaf_target,"label":I18n.text("美洲苦草 · 带状叶与基生莲座"),"role":I18n.text("同一叶丛的两处莲座由可见走茎相连；细长叶为原创简化形态，不表示生长、光合速率或水流作用。"),"source_url":SOURCE,"distance":.9,"min_distance":.48,"view_offset":Vector3(.42,.08,.72)}])
	animate(stage,float(stage.world_snapshot.simulation_time_s))

static func animate(stage: Node,time: float) -> void:
	if not stage.has_meta("wild_celery"): return
	var data: Dictionary=stage.get_meta("wild_celery")
	for i: int in range(data.clumps.size()):
		var clump: Node3D=data.clumps[i]
		clump.rotation.z=.014*sin(time*.48+float(i)*.83)
	data.leaf.global_position=data.whole.global_position+Vector3(0,.06,0)

static func readout(_host: Node,topic: String) -> String:
	if topic=="wild_celery_leaf":
		return I18n.text("同一叶丛 · 两座基生莲座、16枚带状叶\n走茎连接形态可见；未模拟生长、光合或真实水流。")
	return I18n.text("20处作者叶丛 · 同一条合成河道\n每处两座基生莲座与带状叶；位置、数量和轻微摆动不是实测水流。")

static func marks(host: Node,topic: String) -> Array[Dictionary]:
	if topic!="wild_celery_leaf": return []
	var stage: Node=host.coordinator.active_scene
	if not stage.has_meta("wild_celery"): return []
	var data: Dictionary=stage.get_meta("wild_celery")
	return [{"at":data.leaf_anchor.global_position,"label":I18n.text("细长带状叶"),"offset":Vector2(74,-83)},
		{"at":data.rosette.global_position,"label":I18n.text("基生莲座"),"offset":Vector2(93,42)},
		{"at":data.runner.global_position,"label":I18n.text("相连走茎"),"offset":Vector2(-112,81)}]
