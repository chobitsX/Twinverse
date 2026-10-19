extends "res://tests/integration/observation_framing_suite.gd"
## Visible shadow coverage regression at the real overview camera; no performance sampling.
const ScienceReference = preload("res://scripts/experience/science_reference.gd")
const LocalSun = preload("res://scripts/core/celestial_orientation.gd")
const CityTraffic = preload("res://scripts/core/city_traffic.gd")
const CityPark = preload("res://scripts/experience/city_walk_path.gd")
const CityStreetWalk = preload("res://scripts/experience/city_street_walk_path.gd")
const RatTopics = preload("res://scripts/experience/learning_topics.gd")
const DesertTerrain = preload("res://scripts/experience/desert_terrain.gd")
var comparisons: Dictionary = {}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world123-check="): directory=argument.trim_prefix("--world123-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main=Experience.instantiate()
	add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if "--city-human-candidates" in OS.get_cmdline_user_args():
		await review_city_human_candidates()
		return
	if "--city-street-candidates" in OS.get_cmdline_user_args():
		await review_city_street_candidates()
		return
	if "--city-street-walkers-review" in OS.get_cmdline_user_args():
		await review_city_street_walkers()
		return
	if "--city-human-review" in OS.get_cmdline_user_args() or "--city-street-review" in OS.get_cmdline_user_args():
		await review_city_human_view()
		return
	if "--city-diversity-review" in OS.get_cmdline_user_args():
		await review_city_people_diversity()
		return
	if "--mesquite-review" in OS.get_cmdline_user_args():
		await review_mesquite()
		return
	if "--kangaroo-rat-review" in OS.get_cmdline_user_args():
		await review_kangaroo_rat()
		return
	if "--kangaroo-rat-night-action" in OS.get_cmdline_user_args():
		await review_kangaroo_rat_night_action()
		return
	if "--seed-transfer-review" in OS.get_cmdline_user_args():
		await review_seed_transfer()
		return
	if "--city-park-night-review" in OS.get_cmdline_user_args():
		await review_city_park_night()
		return
	if "--desert-landform-review" in OS.get_cmdline_user_args():
		await review_desert_landform()
		return
	if "--landscape-review" in OS.get_cmdline_user_args():
		await review_landscapes()
		return
	if not await arrive("city"):
		await finish()
		return
	await at_time(9.)
	main.ground_light_preview=false
	main._reset_camera()
	await settle()
	var stage: Node = main.coordinator.active_scene
	var sun: DirectionalLight3D = stage.get_meta("daylight_sun")
	var context: MultiMeshInstance3D = stage.world_root.get_node("UrbanSurroundings/ContextBuildings")
	var expected_range: float = sun.directional_shadow_max_distance
	var actors: int = stage.get_meta("actors").size()
	var city_camera: Transform3D = stage.camera.transform
	sun.directional_shadow_max_distance=32.
	context.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var before: Image = await frame_image(stage)
	await capture("city-legacy-shadow-range")
	sun.directional_shadow_max_distance=expected_range
	context.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var after: Image = await frame_image(stage)
	comparisons.city=shadow_change(before,after)
	check("real overview gains visible shade without changing camera or actors",comparisons.city.darkened>1000 and stage.camera.transform.is_equal_approx(city_camera) and stage.get_meta("actors").size()==actors and main.world.simulation_time_s==9.)
	await capture("city-shadowed-overview")
	main.explorer_panel.show()
	await settle()
	check("crossing lesson still selects actual street observation",main.explorer_panel.select_topic("crossing"))
	get_window().size=Vector2i(900,650)
	await settle()
	check("compact crossing controls remain reachable",main.explorer_panel.markers_toggle.get_global_rect().end.y<main.explorer_panel.get_global_rect().end.y)
	await capture("city-crossing-compact")
	get_window().size=Vector2i(1280,720)
	main.explorer_panel.hide()
	main._reset_camera()
	var old_direction: Vector3 = sun.global_basis.z
	main.ground_light_preview=true
	var night_jd: float = Ephemeris.DEFAULT_JD
	for fraction: float in [0.,.25,.5,.75]:
		var jd: float = Ephemeris.DEFAULT_JD+fraction
		if stage.builder.Orientation.local_sun(jd,35,120).y<-.2: night_jd=jd; break
	main.set_solar_date(night_jd)
	await settle()
	check("astronomy date still drives sun and night windows",not sun.global_basis.z.is_equal_approx(old_direction) and sun.light_energy==0. and float(context.material_override.get_shader_parameter("night_amount"))>.9)
	await capture("city-night-preserved")
	main.ground_light_preview=false
	if not await arrive("woodland"):
		await finish()
		return
	main._reset_camera()
	await at_time(22.)
	stage=main.coordinator.active_scene
	sun=stage.get_meta("daylight_sun")
	expected_range=sun.directional_shadow_max_distance
	sun.directional_shadow_max_distance=32.
	before=await frame_image(stage)
	sun.directional_shadow_max_distance=expected_range
	after=await frame_image(stage)
	comparisons.woodland=shadow_change(before,after)
	check("woodland overview gains visible tree shade beyond old cutoff",comparisons.woodland.darkened>150)
	await capture("woodland-shadowed-overview")
	if not await arrive("earth") or not await arrive("city"):
		await finish()
		return
	stage=main.coordinator.active_scene
	check("return retains world time and deterministic city population",main.world.simulation_time_s==22. and stage.get_meta("actors").size()==actors and stage.get_meta("building_counts")=={"shops":9,"homes":10,"offices":8})
	await finish()

func review_city_human_candidates() -> void:
	if main.world.current_scale_id!="city" and not await arrive("city"):
		await finish(); return
	await at_time(9.)
	main.ground_light_preview=false
	main.world.set_paused(true)
	main._reset_camera()
	await settle()
	var stage: Node=main.coordinator.active_scene
	var world_time: float=main.world.simulation_time_s
	var actors: int=stage.get_meta("actors").size()
	await capture("city-human-baseline")
	var poses: Array[Dictionary]=[
		{"name":"park-northeast","position":Vector3(56,5.5,48),"target":Vector3(32,1.4,31)},
		{"name":"park-southwest","position":Vector3(10,5.5,49),"target":Vector3(32,1.4,29)},
		{"name":"park-east","position":Vector3(58,4.2,30),"target":Vector3(32,1.5,30)}]
	for pose: Dictionary in poses:
		stage.set_pose(pose.position,pose.target)
		await settle()
		await capture(str(pose.name))
	comparisons["city_human_candidates"]={"poses":poses,"world_time_s":world_time,"actors":actors}
	check("camera candidates preserve 28 people 12 cars and world time",actors==40 and stage.get_meta("actors").size()==actors and main.world.simulation_time_s==world_time)
	await finish()

func review_city_street_candidates() -> void:
	if main.world.current_scale_id!="city" and not await arrive("city"):
		await finish(); return
	await at_time(9.)
	main.world.set_paused(true)
	main.ground_light_preview=false
	main._reset_camera()
	await settle()
	var stage: Node=main.coordinator.active_scene
	var world_time: float=main.world.simulation_time_s
	var actor_count: int=stage.get_meta("actors").size()
	await capture("city-default-overview")
	var poses: Array[Dictionary]=[
		{"name":"north-green-axis","position":Vector3(-96,4,-80),"target":Vector3(-96,8,-330)},
		{"name":"north-green-diagonal","position":Vector3(-90,4,-48),"target":Vector3(-45,8,-220)},
		{"name":"north-green-promenade","position":Vector3(-138,4,80),"target":Vector3(-100,7,-150)},
		{"name":"park-to-street","position":Vector3(20,4,55),"target":Vector3(-70,7,-150)}]
	for pose: Dictionary in poses:
		stage.set_pose(pose.position,pose.target)
		await settle()
		await capture(str(pose.name))
	comparisons["city_street_candidates"]={"poses":poses,"world_time_s":world_time,"actors":actor_count}
	check("street camera candidates keep actors and one paused world time",actor_count==40 and stage.get_meta("actors").size()==actor_count and main.world.simulation_time_s==world_time)
	await finish()

func review_city_human_view() -> void:
	get_window().size=Vector2i(1280,800)
	if main.world.current_scale_id!="city" and not await arrive("city"):
		await finish(); return
	await at_time(9.)
	main.set_solar_rate(0.)
	main.ground_light_preview=false
	main.world.set_paused(true)
	main._reset_camera()
	await settle()
	var stage: Node=main.coordinator.active_scene
	var world_time: float=main.world.simulation_time_s
	var actors: Array=stage.get_meta("actors")
	var people: int=0
	var cars: int=0
	var park_routes: Array[int]=[0,0]
	var park_positions_match: bool=true
	for actor: Dictionary in actors:
		if actor.kind=="person":
			people+=1
			if actor.index<CityTraffic.PARK_PEOPLE:
				var park_pose: Dictionary=CityPark.itinerary(world_time,actor.index,CityTraffic.PARK_PEOPLE)
				park_routes[park_pose.route]+=1
				park_positions_match=park_positions_match and Vector2(actor.node.position.x,actor.node.position.z).distance_to(Vector2(park_pose.position.x,park_pose.position.z))<.001
		elif actor.kind=="car": cars+=1
	check("city entry preserves 28 walkers and 12 cars",people==28 and cars==12 and actors.size()==40)
	check("park scene uses both authored pedestrian loops",park_routes==[13,13] and park_positions_match)
	comparisons["city_park_routes"]={"counts":park_routes,"scene_positions_match":park_positions_match}
	check("city action offers human-scale view",not main.next_button.disabled and main.next_button.text=="走近人群")
	var overview: Transform3D=stage.camera.transform
	var wide: Dictionary=_city_people_on_screen(stage)
	await capture("city-human-overview")
	main.next_button.pressed.emit()
	await settle()
	var near: Dictionary=_city_people_on_screen(stage)
	comparisons["city_human_view"]={"overview":wide,"human_view":near}
	check("action moves to standard park view with more readable people",main._city_people_view and not main._city_street_view and main.next_button.text=="从街道看城市" and stage.camera.position.is_equal_approx(Vector3(58,4.2,30)) and main._orbit_target.is_equal_approx(Vector3(32,1.5,30)) and near.visible>=5 and near.max_height>wide.max_height*2.0)
	check("camera switch preserves people cars and paused world time",stage.get_meta("actors").size()==40 and main.world.simulation_time_s==world_time)
	await capture("city-human-near")
	main._remember_view()
	check("observer save accepts the city camera mode",main.WorldStore.valid_view(main._views.city) and bool(main._views.city.city_people_view))
	main._reset_camera()
	main._apply_saved_view(stage)
	await settle()
	check("saved park view restores camera and action label",main._city_people_view and not main._city_street_view and stage.camera.position.is_equal_approx(Vector3(58,4.2,30)) and main.next_button.text=="从街道看城市")
	check("Esc releases human view before leaving city",main._clear_observation_selection() and main.world.current_scale_id=="city" and not main._city_people_view and stage.camera.transform.is_equal_approx(overview))
	main.next_button.pressed.emit()
	await settle()
	main.next_button.pressed.emit()
	await settle()
	check("street action shows near buildings road and distant district",main._city_street_view and not main._city_people_view and main.next_button.text=="街区全景" and stage.camera.position.is_equal_approx(Vector3(-5,3,90)) and main._orbit_target.is_equal_approx(Vector3(-72,10,-170)) and stage.get_meta("actors").size()==40 and main.world.simulation_time_s==world_time)
	await capture("city-street-view")
	main._remember_view()
	check("observer save accepts distinct street view",main.WorldStore.valid_view(main._views.city) and bool(main._views.city.city_street_view) and not bool(main._views.city.city_people_view))
	var legacy_city_view: Dictionary=main._views.city.duplicate()
	legacy_city_view.erase("city_street_view")
	check("older saved city view stays valid without street flag",main.WorldStore.valid_view(legacy_city_view))
	var conflicting_city_view: Dictionary=main._views.city.duplicate()
	conflicting_city_view.city_people_view=true
	check("two simultaneous city modes are rejected",not main.WorldStore.valid_view(conflicting_city_view))
	main._reset_camera()
	main._apply_saved_view(stage)
	await settle()
	check("saved street view restores camera and action label",main._city_street_view and stage.camera.position.is_equal_approx(Vector3(-5,3,90)) and main.next_button.text=="街区全景")
	check("Esc releases street view before leaving city",main._clear_observation_selection() and main.world.current_scale_id=="city" and not main._city_street_view and stage.camera.transform.is_equal_approx(overview))
	main.next_button.pressed.emit()
	await settle()
	main.next_button.pressed.emit()
	await settle()
	main.next_button.pressed.emit()
	await settle()
	check("three view actions return to same overview",not main._city_people_view and not main._city_street_view and main.next_button.text=="走近人群" and stage.camera.transform.is_equal_approx(overview) and main.world.simulation_time_s==world_time)
	await capture("city-human-return")
	await finish()

func _city_people_on_screen(stage: Node) -> Dictionary:
	var viewport: Vector2=stage.camera.get_viewport().get_visible_rect().size
	var visible: int=0
	var max_height: float=0.
	for actor: Dictionary in stage.get_meta("actors"):
		if actor.kind!="person": continue
		var foot: Vector3=actor.node.global_position
		var head: Vector3=foot+Vector3.UP*1.7
		if stage.camera.is_position_behind(foot) or stage.camera.is_position_behind(head): continue
		var lower: Vector2=stage.camera.unproject_position(foot)
		var upper: Vector2=stage.camera.unproject_position(head)
		if lower.x<0. or lower.x>viewport.x or upper.y<0. or lower.y>viewport.y: continue
		visible+=1
		max_height=maxf(max_height,upper.distance_to(lower))
	return {"visible":visible,"max_height":max_height,"viewport":viewport}

func review_city_street_walkers() -> void:
	get_window().size=Vector2i(1280,800)
	if main.world.current_scale_id!="city" and not await arrive("city"):
		await finish(); return
	await at_time(9.)
	main.set_solar_rate(0.)
	main.ground_light_preview=false
	main.world.set_paused(true)
	main._reset_camera()
	await settle()
	var stage: Node=main.coordinator.active_scene
	var original_actors: Array=stage.get_meta("actors",[])
	var walkers: Array=stage.get_meta("street_walkers",[])
	check("original park crossing and traffic cohort stays intact",original_actors.size()==40 and stage.get_meta("crossing_people",[]).size()==2)
	var rigged: bool=walkers.size()==CityStreetWalk.COUNT
	for person: Node3D in walkers:
		rigged=rigged and person.has_meta("human_skin") and person.has_meta("stable_id")
	check("six street walkers reuse the articulated four-person family",rigged)
	var route_valid: bool=true
	var max_step: float=0.0
	for index: int in range(CityStreetWalk.COUNT):
		var previous: Vector3=CityStreetWalk.sample(0.,index).position
		for step: int in range(1,401):
			var pose: Dictionary=CityStreetWalk.sample(float(step)*.5,index)
			var p: Vector3=pose.position
			var movement: float=Vector2(previous.x,previous.z).distance_to(Vector2(p.x,p.z))
			max_step=maxf(max_step,movement)
			route_valid=route_valid and movement<.46 and p.z>=CityStreetWalk.MIN_Z-.001 and p.z<=CityStreetWalk.MAX_Z+.001 and absf(p.x)>=CityStreetWalk.INNER_X-.001 and absf(p.x)<=CityStreetWalk.OUTER_X+.001 and ((p.x<0.)==(index<3))
			previous=p
	check("authored loops stay on both paved sidewalks with continuous travel",route_valid)
	var initial_positions: Array[Vector3]=[]
	var pose_match: bool=true
	for index: int in range(walkers.size()):
		var person: Node3D=walkers[index]
		var expected: Dictionary=CityStreetWalk.sample(9.,index)
		initial_positions.append(person.position)
		pose_match=pose_match and Vector2(person.position.x,person.position.z).distance_to(Vector2(expected.position.x,expected.position.z))<.001 and absf(angle_difference(person.rotation.y,expected.heading))<.001
	check("street people occupy their route at the one paused world time",pose_match and main.world.simulation_time_s==9.)
	main.next_button.pressed.emit()
	await settle()
	main.next_button.pressed.emit()
	await settle()
	var on_screen: int=0
	var viewport: Vector2=stage.camera.get_viewport().get_visible_rect().size
	for person: Node3D in walkers:
		var head: Vector3=person.global_position+Vector3.UP*1.5
		if stage.camera.is_position_behind(head): continue
		var pixel: Vector2=stage.camera.unproject_position(head)
		if pixel.x>=0. and pixel.x<=viewport.x and pixel.y>=0. and pixel.y<=viewport.y: on_screen+=1
	check("street action reveals several actual walkers",main._city_street_view and on_screen>=2)
	comparisons["street_walkers"]={"on_screen":on_screen,"route_max_half_second_m":max_step,"count":walkers.size()}
	await capture("city-street-walkers-9s")
	await at_time(22.)
	var moved: bool=true
	for index: int in range(walkers.size()):
		var expected: Dictionary=CityStreetWalk.sample(22.,index)
		var person: Node3D=walkers[index]
		moved=moved and person.position.distance_to(initial_positions[index])>.5 and Vector2(person.position.x,person.position.z).distance_to(Vector2(expected.position.x,expected.position.z))<.001
	check("all six advance from the authoritative time without changing old actors",moved and original_actors.size()==40 and main.world.simulation_time_s==22.)
	await capture("city-street-walkers-22s")
	await finish()

func review_city_people_diversity() -> void:
	get_window().size=Vector2i(1280,800)
	if main.world.current_scale_id!="city" and not await arrive("city"):
		await finish(); return
	await at_time(9.)
	main.ground_light_preview=false
	main.world.set_paused(true)
	main._reset_camera()
	main.next_button.pressed.emit()
	await settle()
	var stage: Node=main.coordinator.active_scene
	var actors: Array=stage.get_meta("actors")
	var shirt_colors: Dictionary={}
	var trouser_colors: Dictionary={}
	var hair_colors: Dictionary={}
	var statures: Dictionary={}
	var widths: Dictionary={}
	var people: int=0
	var cars: int=0
	var skin_valid: bool=true
	for actor: Dictionary in actors:
		if actor.kind=="car":
			cars+=1
			continue
		if actor.kind!="person": continue
		people+=1
		var person: Node3D=actor.node
		var shirt: MeshInstance3D=person.find_child("ContinuousShirt",true,false) as MeshInstance3D
		var trousers: MeshInstance3D=person.find_child("ContinuousLegL",true,false) as MeshInstance3D
		var hair: MeshInstance3D=person.find_child("HairCap",true,false) as MeshInstance3D
		skin_valid=skin_valid and shirt!=null and trousers!=null and hair!=null and person.get_meta("human_skin").skeleton.get_bone_count()==15
		if shirt==null or trousers==null or hair==null: continue
		shirt_colors[(shirt.get_surface_override_material(0) as StandardMaterial3D).albedo_color.to_html()]=true
		trouser_colors[(trousers.get_surface_override_material(0) as StandardMaterial3D).albedo_color.to_html()]=true
		hair_colors[(hair.get_surface_override_material(0) as StandardMaterial3D).albedo_color.to_html()]=true
		statures[person.scale.y]=true
		widths[person.scale.z]=true
	comparisons["city_people_diversity"]={"shirts":shirt_colors.size(),"trousers":trouser_colors.size(),"hair":hair_colors.size(),"statures":statures.size(),"widths":widths.size()}
	check("28 original rigged people and 12 cars remain",people==28 and cars==12 and skin_valid and actors.size()==40)
	check("near walkers have distinct garments hair and stature",shirt_colors.size()>=12 and trouser_colors.size()>=7 and hair_colors.size()>=7 and statures.size()>=7 and widths.size()>=5)
	check("forward stride scale stays unchanged",all_people_keep_stride(actors))
	await capture("city-people-diverse")
	var crossing: Array=stage.get_meta("crossing_people")
	await at_time(32.)
	var ankle_before: Vector3=_city_ankle(crossing[0],"FootL")
	var root_before: Vector3=crossing[0].position
	await at_time(32.02)
	var ankle_after: Vector3=_city_ankle(crossing[0],"FootL")
	comparisons["city_people_diversity"]["planted_ankle_drift_m"]=ankle_before.distance_to(ankle_after)
	check("crossing foot stays planted while body travels",ankle_before.distance_to(ankle_after)<.003 and crossing[0].position.distance_to(root_before)>.02)
	check("world time and actor count follow existing city route",is_equal_approx(main.world.simulation_time_s,32.02) and stage.get_meta("actors").size()==40)
	await capture("city-people-crossing")
	await finish()

func all_people_keep_stride(actors: Array) -> bool:
	for actor: Dictionary in actors:
		if actor.kind=="person" and not is_equal_approx(actor.node.scale.x,1.): return false
	return true

func _city_ankle(person: Node3D, key: String) -> Vector3:
	var skin: Dictionary=person.get_meta("human_skin")
	return skin.skeleton.to_global(skin.skeleton.get_bone_global_pose(skin.bones[key].id).origin)

func review_mesquite() -> void:
	get_window().size=Vector2i(1280,800)
	if main.world.current_scale_id!="desert" and not await arrive("desert"):
		await finish(); return
	await at_time(9.)
	main.ground_light_preview=false
	main.world.set_paused(true)
	main._reset_camera()
	await settle()
	var stage: Node=main.coordinator.active_scene
	var hero: Node3D=stage.get_meta("desert_mesquite",null)
	var targets: Array=stage.get_meta("desert_targets",[])
	check("four mesquite trees join existing desert species",hero!=null and stage.get_meta("desert_mesquite_count",0)==4 and targets.size()==9 and stage.has_meta("iguana") and stage.has_meta("desert_cactus") and stage.has_meta("desert_shrub"))
	await capture("mesquite-desert-overview")
	if hero==null or targets.size()!=9:
		await finish(); return
	main.explorer_panel.show()
	main.follow_content(7)
	await settle()
	check("actual tree has wood leaflets pods and two attached observation anchors",hero.find_child("MesquiteForkedWood",true,false)!=null and hero.find_child("MesquitePairedLeaflets",true,false)!=null and hero.find_child("MesquiteCurvedSeedPods",true,false)!=null and hero.find_child("CompoundLeafAnchor",true,false)!=null and hero.find_child("SeedPodAnchor",true,false)!=null)
	await capture("mesquite-whole-tree")
	main.follow_content(8)
	await settle()
	check("same-tree compound leaf remains at its real anchor",targets[7].node.get_meta("reference_root")==hero and main._orbit_target.distance_to(hero.find_child("CompoundLeafAnchor",true,false).global_position)<.001)
	await capture("mesquite-leaflets")
	main.follow_content(9)
	await settle()
	check("same-tree pod and world time remain stable",targets[8].node.get_meta("reference_root")==hero and main.world.simulation_time_s==9.)
	await capture("mesquite-pod")
	check("mesquite lesson enters the existing whole-tree observer",main.explorer_panel.select_topic("desert_mesquite") and main._content_follow==6)
	var science: Dictionary=ScienceReference.describe("desert")
	check("desert science states the fourth species and limitations",science.basis.contains("Prosopis velutina") and science.limit.contains("地下水") and science.sources.size()>=10)
	var guide_found: bool=false
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="desert_mesquite": guide_found=true
	check("world guide includes a mesquite route",guide_found)
	await finish()

func review_kangaroo_rat() -> void:
	get_window().size=Vector2i(1280,800)
	if main.world.current_scale_id!="desert" and not await arrive("desert"):
		await finish(); return
	main.world.set_paused(true)
	main.ground_light_preview=false
	await at_time(2.)
	var stage: Node=main.coordinator.active_scene
	var rat: Node3D=stage.get_meta("kangaroo_rat",null)
	var targets: Array=stage.get_meta("desert_targets",[])
	check("kangaroo rat joins four other desert species and existing tree",rat!=null and targets.size()==11 and stage.get_meta("desert_mesquite_count",0)==4 and stage.has_meta("iguana"))
	if rat==null or targets.size()!=11:
		await finish(); return
	check("imported anatomy has tail connected hind feet and cheek pouches",rat.find_child("TailPivot",true,false)!=null and rat.find_child("HindLegPivotL",true,false)!=null and rat.find_child("HindShinL",true,false)!=null and rat.find_child("HindShinR",true,false)!=null and rat.find_child("FurLinedCheekPouchR",true,false)!=null)
	main.explorer_panel.show()
	main.follow_content(10)
	await settle()
	var day_position: Vector3=rat.position
	check("daytime is explicitly a stationary anatomy reference",not stage.get_meta("kangaroo_rat_night") and str(rat.get_meta("activity")).contains("静态"))
	await capture("rat-day-anatomy")
	await at_time(8.)
	check("daytime reference remains stationary",rat.position.distance_to(day_position)<.001)
	var night_jd: float=Ephemeris.DEFAULT_JD
	for fraction: float in [0.,.25,.5,.75]:
		var jd: float=Ephemeris.DEFAULT_JD+fraction
		if LocalSun.local_sun(jd,32.,-112.).y<-.2:
			night_jd=jd
			break
	main.ground_light_preview=true
	main.set_solar_date(night_jd)
	await at_time(2.)
	await settle()
	check("date-based night drives route and local observation light",stage.get_meta("kangaroo_rat_night") and stage.get_meta("kangaroo_rat_observation_light").light_energy>.5 and rat.get_meta("motion_sample").moving)
	var outbound: Vector3=rat.position
	await capture("rat-night-outbound")
	main.follow_content(11)
	await settle()
	await capture("rat-night-habitat")
	main.follow_content(10)
	await settle()
	await at_time(5.)
	check("rat pauses beside real fallen pod",rat.position.distance_to(stage.get_meta("kangaroo_rat_pod").position)<.25 and not rat.get_meta("motion_sample").carrying)
	await capture("rat-night-seed")
	await at_time(8.)
	check("same rat carries seed home with enlarged cheek pouches",rat.get_meta("motion_sample").carrying and rat.position.distance_to(outbound)>.25 and (rat.find_child("FurLinedCheekPouchL",true,false) as Node3D).scale.x>1.1)
	await capture("rat-night-carry")
	var before_return: Vector3=rat.position
	for frame: int in range(5): await get_tree().process_frame
	check("paused world freezes the animal and seed route",rat.position.distance_to(before_return)<.001 and main.world.simulation_time_s==8.)
	await at_time(12.)
	check("route ends at the burrow without inventing a seed inventory",rat.position.distance_to(stage.get_meta("kangaroo_rat_den").position)<.25 and not rat.get_meta("motion_sample").carrying)
	await capture("rat-night-burrow")
	check("rat learning topic selects actual moving individual",main.explorer_panel.select_topic("desert_rat") and main._content_follow==9)
	var science: Dictionary=ScienceReference.describe("desert")
	check("science explains nocturnality and author route",science.basis.contains("Dipodomys merriami") and science.limit.contains("种子库存"))
	var guide_found: bool=false
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="desert_rat": guide_found=true
	check("world guide reaches nocturnal seed lesson",guide_found)
	if not await arrive("earth") or not await arrive("desert"):
		await finish(); return
	stage=main.coordinator.active_scene
	rat=stage.get_meta("kangaroo_rat")
	check("return uses same world time and route phase",main.world.simulation_time_s==12. and stage.get_meta("kangaroo_rat_night") and not rat.get_meta("motion_sample").carrying)
	await finish()

func review_kangaroo_rat_night_action() -> void:
	get_window().size=Vector2i(1280,800)
	if main.world.current_scale_id!="earth" and not await arrive("earth"):
		await finish(); return
	main._open_guide()
	var route: Button=null
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="desert_rat": route=button; break
	check("night lesson remains reachable from world guide",route!=null)
	if route==null:
		await finish(); return
	route.pressed.emit()
	var arrival_deadline: int=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<arrival_deadline and (main.world.current_scale_id!="desert" or main.explorer_panel._topic.get("id","")!="desert_rat"):
		await get_tree().process_frame
	if main.world.current_scale_id!="desert" or main.explorer_panel._topic.get("id","")!="desert_rat":
		check("guide actually completes desert lesson transition",false)
		await finish(); return
	if not await ready_stage():
		await finish(); return
	for frame: int in range(2): await get_tree().process_frame
	await at_time(2.)
	var stage: Node=main.coordinator.active_scene
	var panel=main.explorer_panel
	check("guide selects real rat and exposes explicit night action",main.world.current_scale_id=="desert" and panel._topic.get("id","")=="desert_rat" and main._content_follow==9 and panel.rat_night_button.visible)
	check("night action appears in initial panel viewport",panel.rat_night_button.get_global_rect().end.y<panel.get_global_rect().end.y-8.)
	check("guide entry preserves fixed daylight and world time",not main.ground_light_preview and not stage.get_meta("kangaroo_rat_night") and main.world.simulation_time_s==2.)
	panel._process(0.)
	check("topic readout explains why route is still",panel.lesson_readout.text.contains("固定展示光照"))
	await capture("rat-topic-before-night")
	var date_before: float=main.solar_jd
	panel.rat_night_button.pressed.emit()
	await settle()
	panel._process(0.)
	check("explicit action selects next local night without advancing world",main.solar_jd>date_before and main.solar_jd-date_before<1. and main.world.simulation_time_s==2. and main.solar_rate==0.)
	check("date night turns on actual local light and moving route",main.ground_light_preview and LocalSun.local_sun(main.solar_jd,32.,-112.).y<sin(deg_to_rad(-8.)) and stage.get_meta("kangaroo_rat_night") and stage.get_meta("kangaroo_rat_observation_light").light_energy>0. and stage.get_meta("kangaroo_rat").get_meta("motion_sample").moving)
	check("topic readout identifies local night and authored activity",panel.lesson_readout.text.contains("当地夜间") and panel.lesson_readout.text.contains("夜间出洞"))
	await capture("rat-topic-local-night")
	var active_before: float=main.world.desert_seeds.active_elapsed_s
	await at_time(5.)
	check("paused world seconds do not advance authoritative seed route",stage.get_meta("kangaroo_rat_night") and main.world.simulation_time_s==5. and main.world.desert_seeds.active_elapsed_s==active_before and stage.get_meta("kangaroo_rat").position.distance_to(stage.get_meta("kangaroo_rat_den").position)<.25 and main.world.desert_seeds.snapshot().ground_units==8)
	await capture("rat-topic-seed")
	var chosen_date: float=main.solar_jd
	if not await arrive("earth") or not await arrive("desert"):
		await finish(); return
	stage=main.coordinator.active_scene
	check("scale return preserves selected date light and world time",absf(main.solar_jd-chosen_date)<.00001 and main.ground_light_preview and stage.get_meta("kangaroo_rat_night") and main.world.simulation_time_s==5.)
	await finish()

func _advance_seed_to(target: float) -> bool:
	main.world.set_time_scale(4.0)
	main.world.set_paused(false)
	var deadline: int=Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<deadline and main.world.desert_seeds.active_elapsed_s<target:
		await get_tree().process_frame
	main.world.set_paused(true)
	await settle()
	return main.world.desert_seeds.active_elapsed_s>=target

func _visible_seed_count(items: Array) -> int:
	var total: int=0
	for item: MeshInstance3D in items:
		if item.visible: total+=1
	return total

func review_seed_transfer() -> void:
	get_window().size=Vector2i(1280,800)
	var stable: int=Time.get_ticks_msec()
	var startup_deadline: int=stable+10000
	while Time.get_ticks_msec()-stable<1800 and Time.get_ticks_msec()<startup_deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw(): stable=Time.get_ticks_msec()
	check("native window stays drawable before desert request",main.world.foreground and DisplayServer.window_can_draw())
	if main.world.current_scale_id!="desert" and not await arrive("desert"):
		await finish();return
	main.world.set_paused(true)
	var stage: Node=main.coordinator.active_scene
	var panel: Node=main.explorer_panel
	panel.show()
	await settle()
	check("desert topic picker is ready",panel.select_topic("desert_rat"))
	var before_view_time: float=main.world.simulation_time_s
	var before_view_state: Dictionary=main.world.desert_seeds.checkpoint()
	check("explicit near and relationship views fit above lesson text",panel.rat_view_controls.visible and panel.rat_view_controls.get_global_rect().end.y<panel.get_global_rect().end.y)
	(panel.rat_view_controls.get_child(0) as Button).pressed.emit()
	await settle()
	check("near-view button follows the real rat and retains cheek-only mark",main._content_follow==9 and stage.camera.position.distance_to(stage.get_meta("kangaroo_rat").position)<1.5 and main.learning_overlay.last_visible_marks==1)
	await capture("seed-view-close")
	(panel.rat_view_controls.get_child(1) as Button).pressed.emit()
	await settle()
	var first: Dictionary=main.world.desert_seeds.snapshot()
	check("real desert starts with eight bounded teaching units",first.ground_units==8 and first.pouch_units==0 and first.cache_units==0 and _visible_seed_count(stage.get_meta("kangaroo_rat_ground_units"))==8)
	check("habitat button locates seed, cache and actual rat",main._content_follow==10 and stage.get_meta("kangaroo_rat_cache_display").visible and main.learning_overlay.last_visible_marks==3)
	check("switching observation views leaves world time and seed authority unchanged",main.world.simulation_time_s==before_view_time and main.world.desert_seeds.checkpoint()==before_view_state)
	var rat_screen: Vector2=stage.camera.unproject_position(stage.get_meta("kangaroo_rat").global_position+Vector3(0,.12,0))
	check("actual rat projects into unobstructed scene area",rat_screen.x>panel.get_global_rect().end.x+16. and rat_screen.x<get_window().size.x-20. and rat_screen.y>140. and rat_screen.y<get_window().size.y-85.)
	panel.markers_toggle.button_pressed=false
	await settle()
	check("relationship overlay can be hidden without changing scene",not main.learning_overlay.enabled and main.learning_overlay.last_visible_marks==0 and main.world.desert_seeds.checkpoint()==before_view_state)
	panel.markers_toggle.button_pressed=true
	await settle()
	check("relationship overlay restores all three live anchors",main.learning_overlay.enabled and main.learning_overlay.last_visible_marks==3)
	var map: Dictionary=preload("res://scripts/experience/ecology_relations.gd").for_branch("desert")
	check("ecology map links mesquite resource to rat topic",map.edges.size()==2 and map.edges[1].from=="mesquite" and map.edges[1].to=="rat" and panel.rat_reset_button.visible)
	panel.rat_night_button.pressed.emit()
	await settle()
	check("night input is explicit and does not advance a paused world",stage.get_meta("kangaroo_rat_night") and main.world.desert_seeds.active and main.world.desert_seeds.snapshot().ground_units==8)
	var departure_marks: Array[Dictionary]=RatTopics.marks(main,"desert_rat")
	check("night relation line points from actual rat toward surface seeds",departure_marks.size()==3 and int(departure_marks[2].get("link",-1))==0 and departure_marks[2].at.distance_to(stage.get_meta("kangaroo_rat").global_position+Vector3(0,.12,0))<.001)
	await capture("seed-night-start")
	check("world clock reaches actual pickup",await _advance_seed_to(7.0))
	var pouch: Dictionary=main.world.desert_seeds.snapshot()
	check("visible source and cheek follow authoritative one-unit transfer",pouch.ground_units==7 and pouch.pouch_units==1 and pouch.cache_units==0 and _visible_seed_count(stage.get_meta("kangaroo_rat_ground_units"))==7 and stage.get_meta("kangaroo_rat").get_meta("motion_sample").carrying)
	panel._process(0.)
	check("readout reports current ground pouch cache budget",panel.lesson_readout.text.contains("地表 7 · 颊囊 1 · 洞穴 0"))
	var carrying_marks: Array[Dictionary]=RatTopics.marks(main,"desert_rat")
	check("carrying relation line now points toward the cache",carrying_marks.size()==3 and int(carrying_marks[2].get("link",-1))==1 and str(carrying_marks[2].label).contains("携种回洞"))
	await capture("seed-cheek-transfer")
	var frozen: Dictionary=main.world.desert_seeds.checkpoint()
	for frame: int in range(5): await get_tree().process_frame
	check("paused native scene keeps same transfer state",main.world.desert_seeds.checkpoint()==frozen)
	main.ground_light_preview=false
	await settle()
	check("switching to day holds a visible pouch unit for later night",not stage.get_meta("kangaroo_rat_night") and not main.world.desert_seeds.active and main.world.desert_seeds.snapshot().pouch_units==1 and stage.get_meta("kangaroo_rat").get_meta("motion_sample").carrying and not stage.get_meta("kangaroo_rat").get_meta("motion_sample").moving)
	await capture("seed-day-retained-pouch")
	panel.rat_night_button.pressed.emit()
	await settle()
	check("world clock reaches actual deposit",await _advance_seed_to(11.0))
	var cached: Dictionary=main.world.desert_seeds.snapshot()
	check("burrow shows one cache unit and total remains eight",cached.ground_units==7 and cached.pouch_units==0 and cached.cache_units==1 and _visible_seed_count(stage.get_meta("kangaroo_rat_cache_units"))==1 and cached.ground_units+cached.pouch_units+cached.cache_units==8)
	await capture("seed-burrow-cache")
	main.ground_light_preview=false
	await settle()
	check("day display switches off resource experiment",not main.world.desert_seeds.active and not stage.get_meta("kangaroo_rat_night"))
	var elapsed: float=main.world.desert_seeds.active_elapsed_s
	main.world.set_paused(false)
	var deadline: int=Time.get_ticks_msec()+5000
	var beginning: float=main.world.simulation_time_s
	while Time.get_ticks_msec()<deadline and main.world.simulation_time_s<beginning+2.:
		await get_tree().process_frame
	main.world.set_paused(true)
	check("day advances world clock without hidden seed transfer",main.world.simulation_time_s>=beginning+2. and main.world.desert_seeds.active_elapsed_s==elapsed and main.world.desert_seeds.snapshot().cache_units==1)
	panel.rat_night_button.pressed.emit()
	await settle()
	var retained: Dictionary=main.world.desert_seeds.snapshot()
	if not await arrive("earth") or not await arrive("desert"):
		await finish();return
	stage=main.coordinator.active_scene
	check("scene reconstruction keeps the same authoritative seed budget",main.world.desert_seeds.snapshot().cache_units==retained.cache_units and main.world.desert_seeds.snapshot().ground_units==retained.ground_units and _visible_seed_count(stage.get_meta("kangaroo_rat_cache_units"))==1)
	panel.show()
	await settle()
	check("returned desert topic is available",panel.select_topic("desert_rat"))
	var world_time: float=main.world.simulation_time_s
	panel.rat_reset_button.pressed.emit()
	await settle()
	check("explicit local reset only replenishes teaching stock",main.world.simulation_time_s==world_time and main.world.desert_seeds.snapshot().ground_units==8 and main.world.desert_seeds.snapshot().cache_units==0 and _visible_seed_count(stage.get_meta("kangaroo_rat_ground_units"))==8)
	check("animal close view shows pouch without a cropped cache cutaway",not stage.get_meta("kangaroo_rat_cache_display").visible and main.learning_overlay.last_visible_marks==1)
	await capture("seed-reset")
	await finish()

func review_city_park_night() -> void:
	get_window().size=Vector2i(1280,800)
	await at_time(9.)
	main.set_solar_rate(0.)
	if not await arrive("city"):
		await finish(); return
	main._reset_camera()
	var stage: Node=main.coordinator.active_scene
	var actor_count: int=stage.get_meta("actors").size()
	var fixtures: Node3D=stage.world_root.get_node("ParkLights")
	check("two park fixtures are present and city actors remain intact",fixtures.get_child_count()==2 and actor_count==40)
	main.ground_light_preview=true
	var site: Dictionary=stage.builder.Sites.for_scale("city")
	for fraction: float in [0.,.25,.5,.75]:
		var jd: float=Ephemeris.DEFAULT_JD+fraction
		if stage.builder.Orientation.local_sun(jd,site.lat,site.lon).y<-.2:
			main.set_solar_date(jd); break
	await settle()
	var lamps: Array=stage.get_meta("night_lamps")
	check("shared astronomy date turns on two shadowless park lamps",stage.get_meta("daylight_sun").light_energy==0. and lamps.size()==10 and lamps[-1].light.light_energy>2. and lamps[-2].light.light_energy>2. and not lamps[-1].light.shadow_enabled and not lamps[-2].light.shadow_enabled)
	var road_lamps: Array=lamps.slice(0,lamps.size()-2)
	stage.set_meta("night_lamps",road_lamps)
	for index: int in [lamps.size()-2,lamps.size()-1]:
		var lamp: Dictionary=lamps[index]
		lamp.light.light_energy=0.
		lamp.material.emission=Color.BLACK
	await settle()
	var dark: Image=get_viewport().get_texture().get_image()
	await capture("city-park-night-unlit")
	stage.set_meta("night_lamps",lamps)
	await settle()
	var lit: Image=get_viewport().get_texture().get_image()
	comparisons.park=brightened_pixels(dark,lit)
	check("park and walkers gain visible light in actual night frame",comparisons.park>250)
	await capture("city-park-night-overview")
	stage.set_pose(Vector3(61,17,54),Vector3(33,1,31))
	await settle()
	await capture("city-park-night-near")
	main.ground_light_preview=false
	main._reset_camera()
	await settle()
	check("park fixtures turn off in daylight",lamps[-1].light.light_energy==0. and lamps[-2].light.light_energy==0. and stage.get_meta("daylight_sun").light_energy>0.)
	await capture("city-park-day")
	check("observation keeps paused time and city actors",main.world.simulation_time_s==9. and stage.get_meta("actors").size()==actor_count)
	await finish()

func brightened_pixels(before: Image, after: Image) -> int:
	var changed: int=0
	for y: int in range(before.get_height()*45/100,before.get_height()*95/100,4):
		for x: int in range(before.get_width()*20/100,before.get_width()*95/100,4):
			if after.get_pixel(x,y).get_luminance()-before.get_pixel(x,y).get_luminance()>.025: changed+=1
	return changed

func review_landscapes() -> void:
	# Reuse the existing native lighting runner for four review frames, without
	# a new suite, performance sampling or unrelated biome regression loops.
	get_window().size=Vector2i(1280,800)
	await at_time(9.)
	main.set_solar_rate(0.)
	main.ground_light_preview=false
	if not await arrive("city"):
		await finish(); return
	main._reset_camera(); await settle()
	await capture("city-overview")
	var stage: Node=main.coordinator.active_scene
	var site: Dictionary=stage.builder.Sites.for_scale("city")
	main.ground_light_preview=true
	for fraction: float in [0.,.25,.5,.75]:
		var jd: float=Ephemeris.DEFAULT_JD+fraction
		if stage.builder.Orientation.local_sun(jd,site.lat,site.lon).y<-.2:
			main.set_solar_date(jd); break
	await settle()
	check("night still follows the shared astronomy date",stage.get_meta("daylight_sun").light_energy==0. and float(stage.get_meta("sun_elevation"))<0.)
	await capture("city-night")
	main.ground_light_preview=false
	if not await arrive("desert"):
		await finish(); return
	main._reset_camera(); await settle()
	await capture("desert-overview")
	main.explorer_panel.show(); await settle()
	check("existing desert close observation remains reachable",main.explorer_panel.select_topic("desert_iguana"))
	await settle()
	await capture("desert-iguana")
	if not await arrive("earth"):
		await finish(); return
	check("return preserves paused world time",main.world.simulation_time_s==9.)
	await finish()

func review_desert_landform() -> void:
	get_window().size=Vector2i(1280,800)
	await at_time(9.)
	main.set_solar_rate(0.); main.ground_light_preview=false
	if not await arrive("desert"):
		await finish(); return
	var stage: Node=main.coordinator.active_scene
	var west_height: float=DesertTerrain.height_at(-43.,-46.)
	var east_height: float=DesertTerrain.height_at(47.,-52.)
	var wash_height: float=DesertTerrain.height_at(8.+3.*sin(-46.*.055),-46.)
	comparisons.basin={"west_m":west_height,"east_m":east_height,"wash_m":wash_height}
	check("low wash remains between two broad authored basin shoulders",west_height>wash_height+2.5 and east_height>wash_height+1.5)
	var cactus: Node3D=stage.get_meta("desert_cactus")
	var mesquite: Node3D=stage.get_meta("desert_mesquite")
	check("existing teaching plants remain grounded on shared terrain",absf(cactus.position.y-DesertTerrain.height_at(cactus.position.x,cactus.position.z))<.025 and absf(mesquite.position.y-DesertTerrain.height_at(mesquite.position.x,mesquite.position.z))<.025)
	var hills: MeshInstance3D=stage.world_root.get_node("AuthoredDistantFoothills")
	var arrays: Array=hills.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var upward: bool=not normals.is_empty()
	for normal: Vector3 in normals: upward=upward and normal.is_finite() and normal.y>0.
	check("distant terrain faces remain visible from above",upward)
	comparisons.landform={"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"indices":arrays[Mesh.ARRAY_INDEX].size(),"surfaces":hills.mesh.get_surface_count()}
	main._reset_camera(); await settle()
	await capture("desert-overview")
	var eye: Vector3=stage.camera.position
	main._orbit_target=stage.default_target
	stage.set_pose(eye.rotated(Vector3.UP,2.1),stage.default_target)
	await settle(); await capture("desert-orbit")
	main.explorer_panel.show(); await settle()
	main.follow_content(1); await settle()
	await capture("desert-cactus")
	check("existing animal lesson remains reachable",main.explorer_panel.select_topic("desert_iguana"))
	await settle(); await capture("desert-iguana")
	var animal: Node3D=stage.get_meta("iguana")
	var identity: String=animal.get_meta("stable_id")
	var pose: Transform3D=animal.transform
	if not await arrive("earth") or not await arrive("desert"):
		await finish(); return
	stage=main.coordinator.active_scene
	check("return preserves paused time and actual animal pose",main.world.simulation_time_s==9. and stage.get_meta("iguana").get_meta("stable_id")==identity and stage.get_meta("iguana").transform.is_equal_approx(pose))
	await finish()

func ready_stage() -> bool:
	var deadline: int = Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if stage_available(): return true
	# A synchronous first render can consume the wall-clock window. process_frame
	# resumes before coordinator._process; let its prepare/author/commit phases run
	# for a bounded four event turns before declaring an observation failure.
	print("LAND_READY_DEADLINE ",JSON.stringify(readiness()))
	for frame: int in range(4):
		await get_tree().process_frame
		if stage_available(): return true
	print("LAND_READY_UNRESOLVED ",JSON.stringify(readiness()))
	check("stage ready",false)
	return false

func stage_available() -> bool:
	return not main.coordinator.is_busy() and main.coordinator.active_scene.is_prepared() and main.world.foreground and DisplayServer.window_can_draw()

func readiness() -> Dictionary:
	var incoming: Node = main.coordinator._incoming
	return {"phase":main.coordinator.phase,"scale":main.world.current_scale_id,"incoming_prepared":is_instance_valid(incoming) and incoming.is_prepared(),"metrics":main.coordinator.latest_metrics}

func frame_image(stage: Node) -> Image:
	for frame: int in range(5): await RenderingServer.frame_post_draw
	return stage.viewport.get_texture().get_image()

func shadow_change(before: Image, after: Image) -> Dictionary:
	var count: int = 0
	var samples: int = 0
	for y: int in range(before.get_height()/5,before.get_height()*9/10,3):
		for x: int in range(before.get_width()/10,before.get_width()*9/10,3):
			if before.get_pixel(x,y).get_luminance()-after.get_pixel(x,y).get_luminance()>.035: count+=1
			samples+=1
	print("LAND_SHADOW_PIXELS ",count," / ",samples)
	return {"darkened":count,"sampled":samples,"stride":3,"luminance_threshold":.035}

func capture(label: String) -> void:
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var path: String = directory.path_join(label+".png")
	var status: Error = get_viewport().get_texture().get_image().save_png(path)
	print("LAND_LIGHT_CAPTURE ",path," status=",status," open_error=",FileAccess.get_open_error())
	check("capture "+label,status==OK)
	if status==OK: captures.append(label+".png")

func finish() -> void:
	var result: Dictionary = {"cases":cases,"failures":failures,"captures":captures,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"screen":get_window().current_screen,"performance_test":false,"comparisons":comparisons,"last_transition":main.coordinator.latest_metrics,"last_scale":main.world.current_scale_id,"busy":main.coordinator.is_busy(),"foreground":main.world.foreground,"prepared":main.coordinator.active_scene.is_prepared()}
	var file: FileAccess = FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	if file==null:
		print("LAND_LIGHT_REPORT_WRITE_FAILURE ",FileAccess.get_open_error()," ",JSON.stringify(result))
		main._quit(2)
		return
	file.store_string(JSON.stringify(result,"\t")+"\n")
	file.close()
	print("LAND_LIGHT_FINISHED ",failures)
	main._quit(0 if failures.is_empty() else 1)
