extends "res://tests/integration/world_expansion_suite.gd"

## Bounded city visual check: four authored body/hair silhouettes, same people and time.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world194-review="):
			directory = argument.trim_prefix("--world194-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless":
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
	var actors: Array = stage.get_meta("actors")
	var variants: Dictionary = {"human_wave":0,"human_tied":0,"human_short":0,"human_long":0}
	for i: int in range(mini(28,actors.size())):
		var key: String = str(actors[i].node.get_meta("appearance_variant",""))
		if variants.has(key): variants[key] += 1
	check("28 people and 12 cars keep their original city routes",actors.size()==40 and stage.get_meta("crossing_people").size()==2)
	check("four visible base silhouettes have seven people each",variants=={"human_wave":7,"human_tied":7,"human_short":7,"human_long":7})
	if actors.size()<2:
		await finish()
		return
	var wave: Node3D = actors[0].node
	var tied: Node3D = actors[1].node
	var wave_hair: MeshInstance3D = wave.find_child("HairWaveCap",true,false) as MeshInstance3D
	var wave_vest: MeshInstance3D = wave.find_child("LayeredVest",true,false) as MeshInstance3D
	var tied_hair: MeshInstance3D = tied.find_child("HairTiedKnot",true,false) as MeshInstance3D
	var tied_scarf: MeshInstance3D = tied.find_child("SoftNeckScarf",true,false) as MeshInstance3D
	check("new wavy hair and waist layer are on the first real person",wave_hair!=null and wave_vest!=null and wave_hair.skin!=null and wave_vest.skin!=null)
	check("new tied hair and scarf are on the second real person",tied_hair!=null and tied_scarf!=null and tied_hair.skin!=null and tied_scarf.skin!=null)
	var wave_shirt: MeshInstance3D = wave.find_child("ContinuousShirt",true,false) as MeshInstance3D
	var tied_shirt: MeshInstance3D = tied.find_child("ContinuousShirt",true,false) as MeshInstance3D
	check("original connected shirts and 15-bone motions remain",wave_shirt!=null and tied_shirt!=null and wave_shirt.skin!=null and tied_shirt.skin!=null and wave.get_meta("human_skin").skeleton.get_bone_count()==15 and tied.get_meta("human_skin").skeleton.get_bone_count()==15)
	var time_before: float = main.world.simulation_time_s
	await capture("city-four-silhouettes-overview")
	main.follow_content(1)
	await capture("city-four-silhouettes-human")
	check("observation preserves paused authoritative time",main.world.paused and main.world.simulation_time_s==time_before)
	await finish()
