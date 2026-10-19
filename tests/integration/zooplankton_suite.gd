extends "res://tests/integration/schooling_suite.gd"
const Lesson = preload("res://scripts/core/zooplankton_lesson.gd")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world164-review="): directory=argument.trim_prefix("--world164-review=")
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
	var stable_since: int=Time.get_ticks_msec()
	var deadline: int=stable_since+10000
	while Time.get_ticks_msec()-stable_since<2000 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not main.world.foreground or not DisplayServer.window_can_draw(): stable_since=Time.get_ticks_msec()
	main._reduced_motion=true
	main.world.set_paused(true)
	main.world_guide.hide()
	get_window().size=Vector2i(1280,720)
	if not await arrive("reef"):
		await finish()
		return
	var stage: Node=main.coordinator.active_scene
	main.world_guide.open()
	var action: Button
	for button: Button in main.world_guide.route_buttons:
		if button.get_meta("guide_topic","")=="school": action=button
	check("guide still has a real reef school entry",action!=null)
	if action!=null: action.pressed.emit()
	var panel: Node=main.explorer_panel
	var until: int=Time.get_ticks_msec()+5000
	while panel._topic.get("id","")!="school" and Time.get_ticks_msec()<until:
		await get_tree().process_frame
	check("guide selects the schooling and resource lesson",panel._topic.get("id","")=="school")
	panel.zooplankton_reset.pressed.emit()
	await settle()
	var motes: Array=stage.get_meta("zooplankton_motes",[])
	check("twelve magnified water units are separate visible scene objects",motes.size()==Lesson.INITIAL_UNITS and visible_motes(motes)==12)
	check("authoritative v14 budget is visible in school lesson",main.world.zooplankton.active and main.world.zooplankton.taken==0 and panel.lesson_readout.text.contains("剩余12 / 12"))
	check("species and magnification boundary are stated",panel.lesson_text.text.contains("12只可鉴定动物") and panel.lesson_text.text.contains("作者"))
	check("school fish still use their sole world trajectories",school_nodes().size()==24 and positions_match(school_nodes()))
	await capture("water-school-start")
	await forward(4.)
	check("world time removes exactly one teaching unit",main.world.zooplankton.taken==1 and main.world.zooplankton.snapshot().water_units==11 and visible_motes(motes)==11)
	check("readout follows the authoritative amount",panel.lesson_readout.text.contains("剩余11 / 12") and panel.lesson_readout.text.contains("已取1"))
	await capture("water-school-one-taken")
	var frozen: Dictionary=main.world.zooplankton.checkpoint()
	await settle()
	check("paused scene leaves finite budget unchanged",main.world.zooplankton.checkpoint()==frozen and visible_motes(motes)==11)
	panel.select_topic("algae")
	await settle()
	check("leaving lesson hides magnified markers",not main.world.zooplankton.active and visible_motes(motes)==0)
	await forward(8.)
	check("other reef lesson does not secretly consume water budget",main.world.zooplankton.taken==1 and main.world.zooplankton.active_elapsed_s==4.)
	panel.select_topic("school")
	await settle()
	check("return to lesson restores same eleven units",main.world.zooplankton.active and visible_motes(motes)==11)
	await forward(4.)
	check("resumed observation reaches second finite event",main.world.zooplankton.taken==2 and visible_motes(motes)==10)
	await capture("water-school-resumed")
	var before_reset: float=main.world.simulation_time_s
	panel.zooplankton_reset.pressed.emit()
	await settle()
	check("explicit local reset replenishes only this resource",main.world.zooplankton.taken==0 and visible_motes(motes)==12 and main.world.simulation_time_s==before_reset)
	check("reset is reflected in the visible lesson readout",panel.lesson_readout.text.contains("剩余12 / 12") and panel.lesson_readout.text.contains("已取0"))
	await capture("water-school-reset")
	if not await arrive("earth") or not await arrive("reef"):
		await finish()
		return
	check("scene reconstruction retains authoritative twelve units",main.world.zooplankton.snapshot().water_units==12 and main.world.checkpoint().version==14)
	panel.show()
	panel.select_topic("school")
	await settle()
	check("returned reef can reach the same lesson control",panel.school_controls.visible and panel.zooplankton_reset.is_visible_in_tree())
	await finish()

func visible_motes(motes: Array) -> int:
	var total: int=0
	for mote: Node3D in motes:
		if mote.is_visible_in_tree(): total+=1
	return total
