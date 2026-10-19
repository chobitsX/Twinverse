extends "res://tests/integration/observation_framing_suite.gd"
const Fox = preload("res://scripts/experience/red_fox.gd")
const Species = preload("res://scripts/experience/species_catalog.gd")
const Science = preload("res://scripts/experience/science_reference.gd")
var observations: Dictionary = {}

func at_time(value: float) -> void:
	main.world.simulation_time_s = value
	await settle()

func slot_for(identity: String) -> int:
	var entries: Array[Dictionary] = main.content_targets(false)
	for index: int in range(entries.size()):
		if str(entries[index].node.get_meta("stable_id","")) == identity: return index
	return -1

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world226-review="): directory = argument.trim_prefix("--world226-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size = Vector2i(1280,800)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	check("diagnostic cannot take focus or desktop input",get_window().unfocusable and get_viewport().gui_disable_input)
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	main = Experience.instantiate()
	add_child(main)
	main._audio.volume_db = -80.0
	main._measurement_screen = get_window().current_screen
	if not await ready_stage():
		await finish(); return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	if not await arrive("woodland"):
		await finish(); return
	await at_time(5.0)
	var stage: Node = main.coordinator.active_scene
	var data: Dictionary = stage.get_meta("red_fox",{})
	check("one named fox is present in the actual woodland",not data.is_empty())
	if data.is_empty():
		await finish(); return
	var root: Node3D = data.root
	var head: Node3D = data.head_view
	var skin: Dictionary = root.get_meta("fox_skin",{})
	var skeleton: Skeleton3D = skin.get("skeleton") as Skeleton3D
	var coat: MeshInstance3D = root.find_child("FoxContinuousCoat",true,false) as MeshInstance3D
	check("authored continuous coat includes feet and twenty-two bones",coat!=null and skeleton!=null and skeleton.get_bone_count()==22 and skin.bones.has("ForeLPaw") and skin.bones.has("ForeRPaw") and skin.bones.has("HindLPaw") and skin.bones.has("HindRPaw") and root.find_children("FoxPaw*","MeshInstance3D",true,false).is_empty())
	if coat==null or skeleton==null:
		await finish(); return
	var format: int = coat.mesh.surface_get_format(0)
	check("actual coat is bound and carries blend weights and pigment",coat.skin!=null and format&Mesh.ARRAY_FORMAT_BONES and format&Mesh.ARRAY_FORMAT_WEIGHTS and format&Mesh.ARRAY_FORMAT_COLOR)
	var coat_span: float = coat.mesh.get_aabb().size.x
	check("unscaled head-body reference stays in metre units",root.scale.is_equal_approx(Vector3.ONE) and coat_span>.62 and coat_span<.75)
	var deer_count: int = 0
	var birds: int = 0
	for actor: Dictionary in stage.get_meta("actors",[]):
		if actor.kind=="deer": deer_count+=1
		if actor.kind=="bird": birds+=1
	check("old deer birds river and teaching models remain present",deer_count==8 and birds==12 and stage.has_meta("browse_plots") and stage.has_meta("deadwood_plots") and stage.has_meta("banded_killifish"))
	check("fox rests on existing dry land outside the river",root.position.y>Fox.Woodland.WATER_Y+.18 and absf(root.position.y-Fox.Woodland.height_at(root.position.x,root.position.z)+.004)<.001)
	var whole_index: int = slot_for(Fox.STABLE_ID)
	var head_index: int = slot_for(Fox.HEAD_ID)
	var targets: Array[Dictionary] = main.content_targets(false)
	check("two appended views keep the same animal identity",whole_index==targets.size()-2 and head_index==targets.size()-1 and targets[whole_index].node==root and targets[head_index].node==head and head.get_meta("fox_root")==root)
	if whole_index<0 or head_index<0:
		await finish(); return
	var panel: Node = main.explorer_panel
	panel.show()
	await settle()
	check("real menu exposes whole fox and same-fox head",panel.object_picker.item_count==targets.size()+1 and panel.object_picker.get_item_text(whole_index+1).contains("赤狐") and panel.object_picker.get_item_text(head_index+1).contains("同一只"))
	main.object_pointer.rebuild(stage)
	check("existing model picker registers the new actual root",main.object_pointer.choices.get(root.get_instance_id(),{}).get("index",-1)==whole_index)
	panel.object_picker.item_selected.emit(whole_index+1)
	await settle()
	check("real object selection follows same root",main._content_follow==whole_index and main.message_label.text.contains("赤狐"))
	check("whole fox topic uses real subject and author boundary",panel.select_topic("red_fox") and panel.lesson_text.text.contains("Vulpes vulpes") and panel.lesson_text.text.contains("没有模拟捕猎") and panel.lesson_source.visible)
	await settle()
	check("whole rest geometry is clear of explanation and window edges",subject_visible(root) and main.learning_overlay.last_visible_marks==2)
	await capture("fox-whole")
	var original: Transform3D = root.transform
	var original_head: Vector3 = head.position
	var old_date: float = main.solar_jd
	var knee_id: int = int(skin.bones.ForeLKnee.id)
	var knee_pose: Quaternion = skeleton.get_bone_pose_rotation(knee_id)
	await settle()
	check("pause preserves root head and actual knee pose",main.world.paused and main.world.simulation_time_s==5.0 and root.transform.is_equal_approx(original) and head.position.is_equal_approx(original_head) and skeleton.get_bone_pose_rotation(knee_id).is_equal_approx(knee_pose))
	var offset: Vector3 = stage.camera.position-main._orbit_target
	await at_time(9.0)
	check("world seconds drive actual root and knee without changing date",not root.position.is_equal_approx(original.origin) and not skeleton.get_bone_pose_rotation(knee_id).is_equal_approx(knee_pose) and float(root.get_meta("sampled_world_time_s"))==9.0 and main.solar_jd==old_date)
	check("following camera preserves distance as the same fox moves",(stage.camera.position-main._orbit_target).is_equal_approx(offset) and main._orbit_target.is_equal_approx(root.position+Vector3(0,.33,0)))
	await capture("fox-walk-time9")
	await at_time(20.0)
	var stop: Transform3D = root.transform
	await at_time(23.0)
	check("authored stop keeps root fixed while head can turn",root.transform.is_equal_approx(stop) and float(Fox.sample(23.0).moving)==0 and root.get_meta("activity").contains("停步"))
	var foot_min: float = INF
	var foot_max: float = -INF
	for time: float in [0.,3.,6.,13.,20.,39.]:
		await at_time(time)
		for key: String in ["ForeL","ForeR","HindL","HindR"]:
			var ankle: Vector3 = skin.bones[key+"Paw"].origin
			var foot: Vector3 = Fox.point(root,key+"Paw",Vector3(ankle.x+.019,0,ankle.z))
			var height: float = foot.y-Fox.Woodland.height_at(foot.x,foot.z)
			foot_min = minf(foot_min,height)
			foot_max = maxf(foot_max,height)
	check("twenty-four posed paw references stay near existing ground",foot_min>-.02 and foot_max<.065)
	await at_time(5.0)
	check("same world second restores same root head and knee",root.transform.is_equal_approx(original) and head.position.is_equal_approx(original_head) and skeleton.get_bone_pose_rotation(knee_id).is_equal_approx(knee_pose))
	check("head topic uses original specimen and allowed source",panel.select_topic("red_fox_head") and main._content_follow==head_index and head.get_meta("fox_root")==root and Science.allows_url("woodland",Fox.SOURCE) and Science.allows_url("woodland",Fox.SHAPE_SOURCE))
	await settle()
	var projected: Vector2 = stage.camera.unproject_position(head.global_position)
	check("actual head observer and two marks fit beside explanation",not stage.camera.is_position_behind(head.global_position) and projected.x>panel.get_global_rect().end.x+40 and projected.x<1240 and projected.y>140 and projected.y<650 and main.learning_overlay.last_visible_marks==2)
	await capture("fox-head")
	panel.markers_toggle.button_pressed = false
	await settle()
	check("marks hide without changing world or animal",not main.learning_overlay.enabled and root.transform.is_equal_approx(original) and main.world.simulation_time_s==5.0)
	panel.markers_toggle.button_pressed = true
	get_window().size = Vector2i(900,650)
	panel.select_topic("red_fox")
	await settle()
	check("compact whole fox and topic actions stay usable",panel.is_visible_in_tree() and subject_visible(root) and panel.topic_picker.get_global_rect().end.y<650)
	await capture("fox-compact")
	get_window().size = Vector2i(1280,800)
	if not await arrive("earth"):
		await finish(); return
	main._open_guide()
	main.world_guide.species_button.pressed.emit()
	await settle()
	var atlas: Node = main.world_guide.species_atlas
	atlas.search.text = "VULPES VULPES"
	atlas.search.text_changed.emit(atlas.search.text)
	await settle()
	check("atlas lists forty species once and finds the fox scientific name",Species.ENTRIES.size()==40 and atlas.cards.size()==40 and atlas.visible_ids()==["vulpes"])
	check("guide has eight groups and eighty-six real actions",main.world_guide.cards.size()==8 and main.world_guide.route_buttons.size()==86)
	await capture("fox-atlas")
	for card: Dictionary in atlas.cards:
		if card.entry.id=="vulpes": card.button.pressed.emit(); break
	if not await ready_stage():
		await finish(); return
	await settle()
	stage = main.coordinator.active_scene
	check("atlas action enters actual fox with unchanged time and date",main.world.current_scale_id=="woodland" and main.learning_overlay.topic=="red_fox" and stage.get_meta("red_fox").root.get_meta("stable_id")==Fox.STABLE_ID and main.world.simulation_time_s==5.0 and main.solar_jd==old_date)
	await capture("fox-atlas-visit")
	if not await arrive("earth"):
		await finish(); return
	main._open_guide()
	var head_button: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="red_fox_head": head_button=button; break
	check("guide exposes direct same-specimen head entry",head_button!=null)
	if head_button!=null: head_button.pressed.emit()
	if not await ready_stage():
		await finish(); return
	await settle()
	check("real guide head visit uses same model and world authority",main.world.current_scale_id=="woodland" and main.learning_overlay.topic=="red_fox_head" and main.content_targets()[main._content_follow].node.get_meta("fox_root")==main.coordinator.active_scene.get_meta("red_fox").root and main.world.simulation_time_s==5.0 and main.solar_jd==old_date)
	await capture("fox-guide-head")
	main.previous_button.pressed.emit()
	if not await ready_stage():
		await finish(); return
	check("normal Earth return clears fox observation with paused clock",main.world.current_scale_id=="earth" and main._content_follow==-1 and main.world.paused and main.world.simulation_time_s==5.0 and main.solar_jd==old_date)
	observations={"species_count":40,"woodland_species":14,"guide_actions":86,"fox_instances":1,"bones":22,
		"coat_rest_span_m":coat_span,"paw_reference_samples":24,"paw_reference_min_m":foot_min,"paw_reference_max_m":foot_max,
		"world_time_s":5.0,"date_unchanged":true,"native_input_disabled":get_viewport().gui_disable_input,
		"screen_count":DisplayServer.get_screen_count(),"window_screen":get_window().current_screen,"primary_screen":DisplayServer.get_primary_screen()}
	await finish()

func finish() -> void:
	var report: Dictionary={"cases":cases,"failures":failures,"captures":captures,"observations":observations,
		"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,
		"native_input_tested":false,"native_ime_tested":false,"population_or_predation_tested":false}
	var file: FileAccess=FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("RED_FOX_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
