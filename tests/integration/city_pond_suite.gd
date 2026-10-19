extends "res://tests/integration/world_expansion_suite.gd"

const Mallard = preload("res://scripts/experience/city_pond_mallard.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

## Short, bounded content and real-view check; no performance sampling.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world196-review="):
			directory = argument.trim_prefix("--world196-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name()!="headless":
		main._measurement_screen = get_window().current_screen
		get_window().unfocusable = true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await arrive("city"):
		await finish()
		return
	var stage: Node = main.coordinator.active_scene
	var pond: Dictionary = stage.get_meta("city_pond",{})
	check("pond has two original adult assets and three reused shoreline plants",
		pond.size()==4 and pond.get("birds",[]).size()==2 and pond.get("plants",[]).size()==3)
	if pond.is_empty():
		await finish()
		return
	var male: Node3D = pond.birds[0]
	var female: Node3D = pond.birds[1]
	var female_body: MeshInstance3D = female.find_child("BuoyantLongBody*",true,false) as MeshInstance3D
	if female_body!=null:
		var body_mat: StandardMaterial3D = female_body.mesh.surface_get_material(0) as StandardMaterial3D
		print("CITY196_HEN_MATERIAL ",JSON.stringify({"name":female_body.name,"albedo":body_mat.albedo_color.to_html(),"vertex":body_mat.vertex_color_use_as_albedo,"metallic":body_mat.metallic}))
	check("old city people cars birds and garden stay present",
		stage.get_meta("actors",[]).size()==40 and stage.get_meta("city_sparrows",[]).size()==4 and stage.get_meta("pollinators",[]).size()==2)
	check("sex references use one species and stable identities",
		male.get_meta("stable_id","")=="3dworld:teaching:city-mallard:0000" and
		female.get_meta("stable_id","")=="3dworld:teaching:city-mallard:0001" and
		male.find_child("BlueSpeculumL",true,false)!=null and
		female.find_child("BlueSpeculumL",true,false)!=null and
		male.find_child("NarrowWhiteNeckRing",true,false)!=null and
		female.find_child("NarrowWhiteNeckRing",true,false)==null)
	var bounded: bool = true
	var separated: bool = true
	for seconds: float in [0.0,6.0,10.0,24.0,34.0,47.0]:
		var a: Vector3 = Mallard.sample(seconds,0).position
		var b: Vector3 = Mallard.sample(seconds,1).position
		for p: Vector3 in [a,b]:
			bounded = bounded and p.x>Mallard.WATER_MIN_X+1.0 and p.x<Mallard.WATER_MAX_X-1.0 and p.z>Mallard.WATER_MIN_Z+1.0 and p.z<Mallard.WATER_MAX_Z-1.0
		separated = separated and a.distance_to(b)>3.7
	check("authored swim paths stay inside visible water and apart",bounded and separated)
	var targets: Array[Dictionary] = main.content_targets()
	check("old topic indexes and three appended pond objects resolve",
		targets.size()==21 and targets[16].node==stage.get_meta("pollinators")[0].node and
		targets[18].node==pond.overview and targets[19].node==male and targets[20].node==female)
	await capture("city-pond-overview")
	var panel: Node = main.explorer_panel
	panel.show()
	panel._process(0.0)
	check("pond overview lesson selects real pond",panel.select_topic("city_pond") and main._content_follow==18)
	await capture("city-pond-lesson")
	check("male lesson selects actual individual",panel.select_topic("city_mallard_drake") and main._content_follow==19)
	await at_time(0.0)
	await capture("mallard-drake")
	await at_time(11.0)
	var male_bill: Node3D = male.find_child("BillTipAnchor",true,false) as Node3D
	print("CITY196_DIP ",JSON.stringify({"fraction":male.get_meta("head_dip",0.0),"bill_y":male_bill.global_position.y if male_bill!=null else -1.0,"water_y":Mallard.CENTER.y}))
	check("male head approaches existing water plane without leaving pond",
		male.get_meta("head_dip",0.0)>.9 and male_bill!=null and absf(male_bill.global_position.y-Mallard.CENTER.y)<.08)
	await capture("mallard-drake-dip")
	var paused_at: Vector3 = male.position
	for frame: int in range(3): await get_tree().process_frame
	check("paused authoritative time freezes both bird positions",main.world.paused and main.world.simulation_time_s==11.0 and male.position==paused_at)
	check("female lesson selects actual individual",panel.select_topic("city_mallard_hen") and main._content_follow==20)
	await at_time(24.0)
	await capture("mallard-hen")
	var guide: bool = false
	for button: Button in main.world_guide.route_buttons:
		guide = guide or button.get_meta("guide_topic","")=="city_pond"
	check("guide and primary science links resolve",guide and Reference.allows_url("city",Mallard.SOURCE) and Reference.allows_url("city",Mallard.BEHAVIOR_SOURCE))
	await finish()

func at_time(seconds: float) -> void:
	main.world.simulation_time_s = seconds
	for frame: int in range(3): await get_tree().process_frame
