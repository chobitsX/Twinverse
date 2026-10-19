extends "res://tests/integration/land_lighting_suite.gd"
var pointed: Array[Dictionary]=[]

func move_mouse(point: Vector2, mask: int=0) -> void:
	var event: InputEventMouseMotion=InputEventMouseMotion.new()
	event.position=point; event.global_position=point
	event.relative=Vector2(12,0) if mask!=0 else Vector2.ZERO
	event.button_mask=mask
	get_viewport().push_input(event,true)
	await settle()

func button(point: Vector2, down: bool, twice: bool=false) -> void:
	var event: InputEventMouseButton=InputEventMouseButton.new()
	event.position=point; event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
	event.double_click=twice
	get_viewport().push_input(event,true)
	await get_tree().process_frame

func click(point: Vector2) -> void:
	await move_mouse(point)
	await button(point,true)
	await button(point,false)
	await settle()

func visible_choice(id: String) -> Dictionary:
	var picker: Node=main.object_pointer
	var stage: Node=main.coordinator.active_scene
	picker.rebuild(stage)
	for choice: Dictionary in picker.choices.values():
		var node: Node3D=choice.node
		if id=="city" and not str(choice.label).contains("行人"): continue
		if id=="woodland" and not str(choice.label).contains("白尾鹿"): continue
		if id=="reef" and not str(choice.label).contains("褐吊"): continue
		if id=="desert" and not str(choice.label).contains("鬣蜥"): continue
		for height: float in [float(choice.get("focus_height",0.)),.5,0.]:
			var position: Vector3=node.global_position+Vector3(0,height,0)
			if stage.camera.is_position_behind(position): continue
			var point: Vector2=stage.camera.unproject_position(position)
			if not Rect2(30,160,1220,470).has_point(point): continue
			var result: Dictionary=picker.pick(point)
			if result.get("node")==node:
				return {"choice":result,"point":point}
	return {}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world151-check="): directory=argument.trim_prefix("--world151-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	# A script error must not leave an unattended diagnostic rendering forever.
	get_tree().create_timer(150.).timeout.connect(func() -> void:
		push_error("Object pointer diagnostic exceeded its bounded runtime")
		get_tree().quit(2))
	main=Experience.instantiate(); add_child(main)
	main._measurement_screen=get_window().current_screen
	get_window().unfocusable=true; get_window().size=Vector2i(1280,800)
	if not await ready_stage(): await finish(); return
	main._reduced_motion=true; main.world.set_paused(true); main.set_solar_rate(0.)
	main.world_guide.hide(); main.explorer_panel.hide()
	var authority: RefCounted=main.world
	var scene_ids: Array[String]=["solar_system","city","woodland","reef","desert","earth_moon","jupiter_moons"]
	if "--world151-primary-only" in OS.get_cmdline_user_args(): scene_ids.clear()
	for id: String in scene_ids:
		if main.world.current_scale_id!=id and not await arrive(id): await finish(); return
		main.explorer_panel.hide(); main.info_panel.hide(); main._reset_camera()
		await settle()
		var found: Dictionary=visible_choice(id)
		check("visible direct target in "+id,not found.is_empty())
		if found.is_empty(): continue
		var choice: Dictionary=found.choice
		var point: Vector2=found.point
		var clock_before: float=main.world.simulation_time_s
		if id=="city":
			await button(point,true)
			await move_mouse(point+Vector2(18,0),MOUSE_BUTTON_MASK_LEFT)
			await button(point,false); await settle()
			check("actual viewport drag never selects a person",main._content_follow==-1)
			main._reset_camera(); await settle()
			found=visible_choice(id); choice=found.choice; point=found.point
		var camera_before: Transform3D=main.coordinator.active_scene.camera.transform
		await move_mouse(point)
		check("unhandled hover identifies actual object in "+id,main.object_pointer.hovered.get("node")==choice.node and main.object_pointer.tooltip.is_visible_in_tree())
		check("hover keeps the camera stationary in "+id,main.coordinator.active_scene.camera.transform.is_equal_approx(camera_before))
		if id=="solar_system":
			comparisons.solar_hover_camera={"before":str(camera_before),"after":str(main.coordinator.active_scene.camera.transform),"default":str(main.coordinator.active_scene.default_position)}
			check("solar overview starts at its authored angle",main.coordinator.active_scene.camera.position.is_equal_approx(main.coordinator.active_scene.default_position))
		if id=="solar_system": await capture("solar-pointer-hover")
		await click(point)
		var selected: bool=main.solar_follow==int(choice.planet) if choice.has("planet") else main._content_follow==int(choice.index) and main.content_targets()[main._content_follow].node==choice.node
		check("click follows exact object and keeps authority in "+id,selected and main.explorer_panel.visible and main.world==authority and main.world.simulation_time_s==clock_before)
		pointed.append({"scale":id,"label":choice.label,"node":str(choice.node.get_path()),"index":choice.get("index",choice.get("planet"))})
		if id in ["city","reef"]: await capture(id+"-pointer-selected")
		if id=="city":
			var info_button: Button
			for node: Node in main.hud.find_children("*","Button",true,false):
				if node.text.begins_with("科学说明"): info_button=node; break
			if info_button!=null:
				await click(info_button.get_global_rect().get_center())
				check("GUI button cannot select a scene object underneath",main.info_panel.visible and main.content_targets()[main._content_follow].node==choice.node)
				main.info_panel.hide()
	comparisons.pointer_targets=pointed
	# Use a camera that exposes the primary fish; verify the actual input route,
	# including the second click after the first one changes the view.
	if await arrive("fish"):
		main.explorer_panel.hide(); main._reset_camera(); await settle()
		var stage: Node=main.coordinator.active_scene
		var fish: Node3D=stage.get_meta("target_node")
		var point: Vector2=stage.camera.unproject_position(fish.global_position)
		check("primary fish remains directly selectable",main.object_pointer.pick(point).get("node")==fish)
		await click(point)
		check("primary fish click uses the real target individual",main._content_follow>=0 and main.content_targets()[main._content_follow].node==fish)
		await button(point,true,true); await button(point,false)
		if await ready_stage(): check("primary fish double click still enters the heart",main.world.current_scale_id=="heart")
	await finish()
