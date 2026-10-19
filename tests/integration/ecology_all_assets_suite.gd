extends "res://tests/integration/ecology_assets_suite.gd"
## Bounded checks of the replacement assets in their actual World-owned scenes.
const BoxFootProbe=preload("res://tests/integration/box_turtle_suite.gd")
const BackgroundExperience=preload("res://tests/diagnostics/ecology269_experience.gd")
var scope: String="woodland"

func ready_stage() -> bool:
	var deadline: int=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		if not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground:return true
	check("stage ready",false)
	return false

func capture(label: String) -> void:
	for frame: int in range(3):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	var picture: Image=main.coordinator.active_scene.viewport.get_texture().get_image()
	check("capture "+label,picture!=null and not picture.is_empty() and picture.save_png(directory.path_join(label+".png"))==OK)
	captures.append(label+".png")

func mesh_count(root: Node,name: String) -> int:
	return root.find_children(name,"MeshInstance3D",true,false).size()

func finish() -> void:
	if is_instance_valid(main):
		main.queue_free();main=null
		for frame: int in range(3):
			await get_tree().process_frame
			RenderingServer.force_draw(false)
	await super.finish()

func check_imports(stage: Node) -> void:
	var replacements: int=0
	for key: String in stage.assets:
		var scene: PackedScene=stage.assets[key]
		if scene.resource_path.contains("/ecology269/"):replacements+=1
	check("actual scene loads replacement resources",replacements>0)
	observations.replacement_resources_in_scene=replacements

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--assets269-output="):directory=argument.trim_prefix("--assets269-output=")
		if argument.begins_with("--assets269-scope="):scope=argument.trim_prefix("--assets269-scope=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().unfocusable=true;get_viewport().gui_disable_input=true
	get_window().size=Vector2i(1280,800);Engine.max_fps=5
	main=Experience.instantiate();main.set_script(BackgroundExperience);add_child(main)
	main._measurement_screen=get_window().current_screen;main._muted=true
	get_window().mode=Window.MODE_MINIMIZED
	get_tree().create_timer(75.).timeout.connect(func() -> void:get_tree().quit(2))
	if not await ready_stage():await finish();return
	if main._audio!=null:main._audio.volume_db=-80.
	main._reduced_motion=true;main.world.set_paused(true);main.set_solar_rate(0.)
	main.world_guide.hide();main.explorer_panel.hide()
	var authority: int=main.world.get_instance_id()
	var destination: String={"woodland":"woodland","city":"city","desert":"desert","ocean":"reef","polar":"polar"}.get(scope,"")
	if destination.is_empty() or not await arrive(destination):await finish();return
	var stage: Node=main.coordinator.active_scene
	check_imports(stage)
	match scope:
		"woodland":await woodland(stage)
		"city":await city(stage)
		"desert":await desert(stage)
		"ocean":await ocean(stage)
		"polar":await polar(stage)
	var time: float=main.world.simulation_time_s
	var date: float=main.solar_jd
	if await arrive("earth"):
		check("return keeps the one World and paused date",main.world.get_instance_id()==authority and main.world.paused and main.world.simulation_time_s==time and main.solar_jd==date)
	budget_check()
	observations.scope=scope;observations.world_time_s=time
	observations.species_shapes_are_references=true
	await finish()

func woodland(stage: Node) -> void:
	var birds: Array[Node3D]=[]
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind=="bird":birds.append(actor.node)
	check("twelve robins retain stable identities",birds.size()==12 and birds[0].get_meta("stable_id")=="3dworld:teaching:robin:0000")
	var robin: Node3D=birds[0]
	var robin_data: Dictionary=robin.get_meta("robin_skin")
	check("one robin skeleton controls the two new display poses",robin_data.skeleton.get_bone_count()==17 and mesh_count(robin,"RobinPerchedSurface")==1 and mesh_count(robin,"RobinFlightSurface")==1)
	await at_time(0.)
	check("ground activity shows the folded source body",robin_data.perched_surfaces[0].visible and not robin_data.flight_surfaces[0].visible)
	await focus(robin,.10,Vector3(.28,.10,.32),"美洲知更鸟 · 地面")
	await capture("robin-ground")
	await at_time(29.)
	check("flight activity shows the same bird's new spread wings",robin_data.flight_surfaces[0].visible and not robin_data.perched_surfaces[0].visible)
	var wing: Quaternion=bone_rotation(robin,"robin_skin","WingL")
	var phase: float=robin_data.cloud_surfaces[0].get_shader_parameter("world_phase")
	await at_time(29.04)
	check("flight wing and source surface move with World time",not wing.is_equal_approx(bone_rotation(robin,"robin_skin","WingL")) and robin_data.cloud_surfaces[0].get_shader_parameter("world_phase")!=phase)
	await capture("robin-flight")
	var frog: Node3D=stage.get_meta("frogs")[0]
	var throat: Dictionary=frog.get_meta("frog_skin")
	check("two bullfrogs retain original fifteen-bone skins",stage.get_meta("frogs").size()==2 and throat.skeleton.get_bone_count()==15)
	await at_time(0.)
	var throat_at: Vector3=throat.skeleton.get_bone_pose_position(throat.throat)
	await at_time(1.4)
	check("new frog throat deforms with the original clock",not throat_at.is_equal_approx(throat.skeleton.get_bone_pose_position(throat.throat)))
	await focus(frog,.035,Vector3(.20,.12,.24),"美洲牛蛙 · 皮肤与趾蹼")
	await capture("bullfrog")
	var box: Node3D=stage.get_meta("box_turtle").root
	await at_time(5.)
	var probe: Node=BoxFootProbe.new();probe.main=main
	var feet: Dictionary=probe.foot_metrics(box);probe.free()
	observations.box_turtle_feet=feet
	check("new box turtle's actual sole vertices reach terrain",box.get_meta("turtle_skin").skeleton.get_bone_count()==16 and feet.worst_lift_error_m<.001)
	await focus(box,.055,Vector3(.25,.14,.32),"东部箱龟 · 慢行")
	await capture("box-turtle")
	var pollinator: Dictionary=stage.get_meta("pollinators")[0]
	await at_time(3.)
	check("four new butterfly wings retain nectar contact and walking legs",mesh_count(pollinator.node,"*WingSurface*")==4 and pollinator.node.get_meta("flower_distance_m")<.00001 and pollinator.joints.size()==11)
	await focus(pollinator.node,.004,Vector3(.11,.14,.19),"帝王蝶 · 同株访花")
	await capture("monarch-flower")
	var stages: Dictionary=stage.get_meta("monarch_life_stages")
	var larva: Dictionary=stage.get_meta("monarch_larva")
	check("egg larva and pupa stay attached to actual host leaves",stages.egg.leaf!=null and stages.pupa.leaf!=null and larva.leaf!=null and stages.egg.node.get_meta("stable_id").contains("egg"))
	var pine: Node3D=stage.assets.eastern_white_pine_young.instantiate()
	check("five pine needles retain their real close parts",mesh_count(pine,"ReferenceNeedle*")==5)
	pine.free()
	check("freshwater fish plants and four darner wings are retained",stage.get_meta("freshwater_school").fish.size()==8 and stage.get_meta("banded_killifish").fish.size()==6 and stage.get_meta("river_wetland").wings.size()==4)
	var fungus: Node3D=stage.get_meta("fungus_root")
	var bark: MeshInstance3D=fungus.find_child("DeadwoodBark",true,false) as MeshInstance3D
	print("FUNGUS269_MATERIAL ",bark.get_active_material(0).get_class()," override=",bark.get_surface_override_material(0)," root=",fungus.scene_file_path)
	check("new fungus log retains the same cap underside and anchors",fungus.find_child("ReferenceCap",true,false)!=null and fungus.find_child("PoreSurfaceAnchor",true,false)!=null and stage.get_meta("fungus_pore_material")!=null)
	await focus(fungus,.14,Vector3(.70,.30,.80),"云芝 · 附木子实体")
	await capture("fungus-log")
	var frozen: Vector3=throat.skeleton.get_bone_pose_position(throat.throat)
	await settle()
	check("pause freezes the new skins",frozen.is_equal_approx(throat.skeleton.get_bone_pose_position(throat.throat)) and main.world.simulation_time_s==3.)

func city(stage: Node) -> void:
	var sparrows: Array=stage.get_meta("city_sparrows")
	check("four sparrows retain correct three-front one-back toes",sparrows.size()==4 and mesh_count(sparrows[0],"Toe*")==8 and sparrows[0].find_child("BlackCheekSpotL",true,false)==null)
	await at_time(4.)
	await focus(sparrows[0],.045,Vector3(.17,.10,.23),"欧亚树麻雀 · 毛羽")
	await capture("sparrow")
	var pond: Dictionary=stage.get_meta("city_pond")
	check("two distinct source duck sexes retain HeadPivot skins",pond.birds.size()==2 and pond.birds[0].has_meta("ecology_motion_skin") and pond.birds[1].has_meta("ecology_motion_skin") and pond.birds[0].scene_file_path!=pond.birds[1].scene_file_path)
	await at_time(7.)
	var head: Transform3D=pond.heads[0].transform
	await at_time(11.)
	check("original duck activity deforms the new continuous neck",not head.is_equal_approx(pond.heads[0].transform))
	await focus(pond.birds[0],.23,Vector3(.80,.30,.95),"绿头鸭 · 雄鸭")
	await capture("mallard-drake")
	await focus(pond.birds[1],.23,Vector3(.80,.30,.95),"绿头鸭 · 雌鸭")
	await capture("mallard-hen")
	await at_time(35.)
	var hen: MeshInstance3D=pond.birds[1].find_child("mallard_henBody",true,false) as MeshInstance3D
	check("hen color boundaries retain rest coordinates during feeding",bool(hen.mesh.surface_get_format(0)&Mesh.ARRAY_FORMAT_TEX_UV2))
	await focus(pond.birds[1],.23,Vector3(.80,.30,.95),"绿头鸭 · 雌鸭低头")
	await capture("mallard-hen-feeding")
	var trees: Dictionary=stage.get_meta("city_park_trees")
	main.ground_light_preview=true;main.set_solar_date(2451717.5);await settle()
	check("summer keeps the same ginkgo maple and redbud leaves",trees.maple_leaves[0].visible and trees.redbud_leaves[0].visible and stage.get_meta("city_ginkgos")[0].get_meta("ginkgo_leaf_parts")[0].visible)
	main.set_solar_date(2451545.);await settle()
	check("winter hides the same deciduous crowns",not trees.maple_leaves[0].visible and not trees.redbud_leaves[0].visible and not stage.get_meta("city_ginkgos")[0].get_meta("ginkgo_leaf_parts")[0].visible)
	main.set_solar_date(2451717.5);await settle()
	await focus(trees.maple,2.2,Vector3(4.2,2.0,5.0),"城市公园 · 叶形与树皮")
	await capture("park-trees")

func desert(stage: Node) -> void:
	var cactus: Node3D=stage.get_meta("desert_cactus")
	check("source saguaro retains attached areoles and real spines",cactus.find_child("WoollyAreoles",true,false)!=null and cactus.find_child("RadialAndCentralSpines",true,false)!=null and cactus.find_child("AreoleAnchor",true,false)!=null)
	var ground_gap: float=INF
	for node: Node in cactus.find_children("saguaroTripoSurface*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D=node as MeshInstance3D
		for slot: int in range(mesh.mesh.get_surface_count()):
			for vertex: Vector3 in mesh.mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX]:
				var at: Vector3=mesh.to_global(vertex)
				ground_gap=minf(ground_gap,at.y-stage.builder.height_at(at.x,at.z))
	observations.saguaro_minimum_ground_gap_m=ground_gap
	check("new saguaro base meets the actual terrain",absf(ground_gap)<.05)
	await focus(cactus,2.8,Vector3(4.0,2.4,10.0),"巨柱仙人掌 · 新外形与刺座")
	await capture("saguaro")
	var iguana: Node3D=stage.get_meta("iguana")
	await at_time(3.)
	var leg: Quaternion=bone_rotation(iguana,"iguana_skin","ForeL")
	await at_time(3.2)
	check("iguana keeps its original skeleton and weighted gait",iguana.get_meta("iguana_skin").skeleton.get_bone_count()==23 and not leg.is_equal_approx(bone_rotation(iguana,"iguana_skin","ForeL")))
	await focus(iguana,.04,Vector3(.32,.20,.48),"沙漠鬣蜥 · 保留科学结构")
	await capture("iguana")
	main.ground_light_preview=true;main.set_solar_date(2451545.);await settle()
	var rat: Node3D=stage.get_meta("kangaroo_rat")
	print("RAT269_SKIN ",JSON.stringify({"drivers":rat.get_meta("ecology_motion_skin").drivers.size(),"toes":mesh_count(rat,"HindToe*"),"names":rat.get_meta("ecology_motion_skin").drivers.map(func(d: Dictionary) -> String:return str(d.node.name))}))
	check("one source rat retains its seven original motion drivers and four-toed feet",rat.has_meta("ecology_motion_skin") and rat.get_meta("ecology_motion_skin").drivers.size()==7 and mesh_count(rat,"HindToe*")==8)
	await at_time(3.)
	var tail: Node3D=rat.find_child("TailPivot",true,false) as Node3D
	var before: Transform3D=tail.transform
	var skin: Skeleton3D=rat.get_meta("ecology_motion_skin").skeleton
	var tail_bone: int=skin.find_bone("Skin_TailPivot")
	var skin_before: Quaternion=skin.get_bone_pose_rotation(tail_bone)
	await at_time(3.2)
	check("night route and replacement tail use the same world clock",bool(stage.get_meta("kangaroo_rat_night")) and not before.is_equal_approx(tail.transform) and not skin_before.is_equal_approx(skin.get_bone_pose_rotation(tail_bone)))
	await focus(rat,.07,Vector3(.32,.14,.38),"梅氏袋鼠鼠 · 夜间")
	await capture("kangaroo-rat")

func ocean(stage: Node) -> void:
	var actors: Array=stage.get_meta("marine_actors")
	check("existing marine actors keep counts and stable identities",actors.size()==44 and stage.get_meta("marine_counts")["褐吊"]==6 and stage.get_meta("marine_counts")["四带笛鲷"]==12 and stage.get_meta("marine_counts")["青绿雀鲷"]==24)
	await at_time(2.)
	var target: Node3D=stage.world_root.get_node("TargetFish")
	var players: Array=target.find_children("*","AnimationPlayer",true,false)
	check("new anemonefish keeps the imported tail animation",players.size()==1 and players[0].get_animation_list().size()>0 and players[0].speed_scale==0.)
	var animation_at: float=players[0].current_animation_position
	var skeleton: Skeleton3D=target.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var before: Array[Quaternion]=[]
	for bone: int in range(skeleton.get_bone_count()):before.append(skeleton.get_bone_pose_rotation(bone))
	# The fish reads World.science.swim_phase, which is integrated by advance,
	# rather than the test's direct pose-time assignments used by other actors.
	main.world.set_paused(false);main.world.advance(.2);main.world.set_paused(true)
	await settle()
	var moved: bool=false
	for bone: int in range(skeleton.get_bone_count()):
		if not before[bone].is_equal_approx(skeleton.get_bone_pose_rotation(bone)):moved=true
	check("World seek advances the new fish animation and weighted skin",players[0].current_animation_position!=animation_at and moved)
	await focus(target,0.,Vector3(.16,.06,.20),"海葵双锯鱼 · 新皮肤")
	await capture("percula")
	var tang: Node3D=actors[0].node
	var mouth: Node3D=tang.find_child("FeedingMouthAnchor",true,false) as Node3D
	check("brown tang feeding uses a real new mesh mouth anchor",mouth!=null and actors[0].meshes[0].get_active_material(0).get_shader_parameter("brown_tang_pigment"))
	var phase: float=actors[0].meshes[0].get_instance_shader_parameter("swim_phase")
	await at_time(2.4)
	check("new marine surfaces share World swim phase",phase!=actors[0].meshes[0].get_instance_shader_parameter("swim_phase"))
	await focus(tang,0.,Vector3(.38,.13,.48),"褐吊 · 游动")
	await capture("brown-tang")
	var coral: Node3D=stage.get_meta("coral_root")
	check("source coral retains twelve real attached hero tentacles",stage.get_meta("coral_tentacles").size()==12 and coral.find_child("PolypMouthAnchor",true,false)!=null)
	check("source coral texture participates in original symbiosis shader",stage.get_meta("coral_tissue_materials").any(func(m: ShaderMaterial) -> bool:return m.get_shader_parameter("has_albedo")==true))
	await focus(coral,.07,Vector3(.28,.17,.34),"分枝石珊瑚 · 同一群体")
	await capture("coral")
	var octopus: Node3D=stage.get_meta("day_octopus").root
	check("octopus retains eight continuous arms and eight double sucker rows",mesh_count(octopus,"ContinuousArm*")==8 and mesh_count(octopus,"DoubleSuckerRows*")==8)
	var urchin: Node3D=stage.get_meta("benthic_targets")[0].node
	check("urchin retains five spots and the anal ring",mesh_count(urchin,"WhiteSpot*")==5 and urchin.find_child("AnalRingAnchor",true,false)!=null)
	check("sea cucumber clam and marine plant close parts remain",stage.get_meta("holothuria_root").find_child("FeedingTentacle00",true,false)!=null and stage.get_meta("clam_root").find_child("LightFacingMantle",true,false)!=null and stage.get_meta("seagrass_patch").multimesh.instance_count==360)
	await focus(octopus,.07,Vector3(.65,.50,.82),"日间章鱼 · 八腕与吸盘")
	await capture("octopus")
	await focus(stage.get_meta("clam_root"),.05,Vector3(.38,.21,.43),"砗磲 · 双壳与外套膜")
	await capture("clam")
	check("same seagrass reference clears the octopus arm span",stage.get_meta("seagrass_root").global_position.distance_to(octopus.global_position)>.65)
	await focus(stage.get_meta("seagrass_root"),.02,Vector3(.07,.07,.09),"卵叶喜盐草 · 三对叶")
	await capture("seagrass")

func polar(stage: Node) -> void:
	var krill: Dictionary=stage.get_meta("ice_krill")
	check("twelve krill retain five real swimming leg pairs",krill.animals.size()==12 and krill.pleopods[0].size()==5 and krill.animals[0].get_meta("stable_id")=="3dworld:teaching:ice-krill:0000")
	await at_time(4.)
	var leg: Transform3D=krill.pleopods[0][0].transform
	await at_time(4.2)
	check("original krill limbs and route share World time",not leg.is_equal_approx(krill.pleopods[0][0].transform) and main.world.simulation_time_s==4.2)
	await focus(krill.animals[0],0.,Vector3(.010,.014,.075),"冰磷虾 · 真实尺寸近看")
	await capture("ice-krill")
