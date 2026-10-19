extends "res://tests/integration/solar_size_suite.gd"
const Store = preload("res://scripts/core/world_store.gd")
var resume_mode: bool=false
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world134-check="): directory=argument.trim_prefix("--world134-check=")
		if argument=="--journey-resume": resume_mode=true
	if not directory.is_absolute_path() or not ("--world-dir="+directory.path_join("world")) in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,720)
	if native: root.unfocusable=true
	main=Experience.instantiate(); root.add_child(main)
	if native: main._measurement_screen=root.current_screen
	if not await ready_scale("earth"):
		finish_journey(); return
	main._reduced_motion=true
	main.world.set_paused(true)
	main.set_solar_rate(0.)
	main.world_guide.hide()
	var journey: Node=main.guided_journey
	var authority: int=main.world.get_instance_id()
	var time_before: float=main.world.simulation_time_s
	if resume_mode:
		check("new process restores optional guide progress",journey.started and journey.step==2 and not journey.completed and not journey.visible)
		main._open_guide()
		check("world guide offers saved continuation",main.world_guide.journey_button.text.contains("第3步"))
		main.world_guide.journey_button.pressed.emit()
		await frames()
		check("resume preserves restored current view and time",journey.visible and journey.step==2 and main.world.simulation_time_s==time_before)
		journey.advance_button.pressed.emit()
		journey.suspend()
		await ready_scale("earth")
		await frames()
		check("cancelled transition leaves guide step uncommitted",journey.step==2 and journey.pending==-1 and not journey.visible)
		check("same authority retained after cancellation",main.world.get_instance_id()==authority and main.world.simulation_time_s==time_before)
		journey.open()
		journey.advance_button.grab_focus()
		var enter: InputEventKey=InputEventKey.new()
		enter.keycode=KEY_ENTER; enter.pressed=true
		root.push_input(enter,true)
		enter.pressed=false; root.push_input(enter,true)
		if await ready_scale("atmosphere"):
			await frames()
			check("focused guide button accepts Enter without global shortcut conflict",journey.step==3 and main.world.paused)
			journey.previous_button.pressed.emit()
			await ready_scale("earth"); await frames()
			check("previous step returns without rewinding world",journey.step==2 and main.world.simulation_time_s==time_before)
		journey.suspend()

	else:
		check("fresh world does not force guided playback",not journey.started and not journey.visible and journey.route.size()==25)
		for i: int in range(journey.route.size()-1):
			check("route uses real adjacent scales "+str(i),main.Catalog.neighbors(journey.route[i]).has(journey.route[i+1]))
		main._open_guide(); main.world_guide.journey_button.pressed.emit()
		for index: int in range(journey.route.size()):
			if not await ready_scale(journey.route[index]):
				finish_journey(); return
			await frames()
			check("actual route step "+str(index),journey.step==index and journey.pending==-1 and main.world.get_instance_id()==authority and main.world.simulation_time_s==time_before)
			if index in [0,8,12]:
				if index==8: root.size=Vector2i(900,650)
				await frames()
				check("guide panel fits "+str(index),journey.get_global_rect().end.y<=root.size.y-130 and journey.get_global_rect().end.x<=root.size.x)
				await capture("journey-"+str(index))
			if index<journey.route.size()-1:
				if index==1: journey.skip_button.pressed.emit()
				else: journey.advance_button.pressed.emit()
		journey.advance_button.pressed.emit()
		check("explicit finish marks route complete",journey.completed and journey.status.text.contains("路线已结束"))
		journey.restart_button.pressed.emit()
		await ready_scale("galaxy"); await frames()
		check("replay resets only observation progress",journey.step==0 and not journey.completed and main.world.simulation_time_s==time_before and main.world.get_instance_id()==authority)
		journey.advance_button.pressed.emit(); await ready_scale("solar_system"); await frames()
		journey.advance_button.pressed.emit(); await ready_scale("earth"); await frames()
		journey.suspend()
		check("pausing guidance keeps same world pause state",not journey.visible and main.world.paused)
		var status: String=main.save_world(false)
		var saved: Dictionary=Store.new(directory.path_join("world")).load_session()
		check("actual save contains guide progress and world",status=="ok" and saved.status=="ok" and saved.payload.observer.preferences.guided_journey.step==2 and saved.payload.world.simulation_time_s==time_before)
		var before: Dictionary=journey.checkpoint()
		journey.restore({"version":1,"step":99999,"started":true,"completed":false})
		check("invalid optional preference cannot corrupt progress",journey.checkpoint()==before)
	finish_journey()
func finish_journey() -> void:
	FileAccess.open(directory.path_join("resume-checks.json" if resume_mode else "checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"captures":captures,"native":native,"debug_build":OS.is_debug_build(),"resume":resume_mode,"performance_test":false},"\t")+"\n")
	print("GUIDED_JOURNEY_FINISHED ",cases.size()," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
