extends "res://tests/integration/world_expansion_suite.gd"
## Device stream is exercised muted; PCM/listening artifacts are a separate check.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world92-check="): directory = argument.trim_prefix("--world92-check=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if not await ready_stage():
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main._muted = true
	check("actual audio generator is playing",main._audio!=null and main._audio.playing and main._audio_playback!=null)
	for id: String in ["woodland","city"]:
		if not await arrive(id):
			await finish()
			return
		main.sound_panel.show()
		var before: int = main.soundscape._sample_index
		await get_tree().create_timer(.25).timeout
		check(id+" samples reach actual device generator",main.soundscape._sample_index>before+1000)
		var expected: Vector2 = Vector2(1,0) if id=="woodland" else Vector2(0,1)
		check(id+" receives independent environment",main.soundscape._land_target==expected)
		check(id+" source boundary shown",main.sound_context_label.text.contains("合成"))
		await capture(id+"-sound-controls")
	var environment: HSlider = main.sound_panel.find_child("environment_volume",true,false) as HSlider
	var master: HSlider = main.sound_panel.find_child("master",true,false) as HSlider
	environment.value = 0
	await get_tree().create_timer(.2).timeout
	check("environment slider controls terrestrial mix",main.soundscape.environment_volume==0 and main.soundscape._levels.x<.0001)
	master.value = 0
	main.sound_mute_button.pressed.emit()
	await get_tree().create_timer(.2).timeout
	check("master zero keeps unmuted generator silent",not main._muted and main.soundscape._gain<.0001)
	main.sound_mute_button.pressed.emit()
	master.value = .8
	environment.value = .8
	await get_tree().create_timer(.2).timeout
	check("mute holds silence after volume restored",main._muted and main.soundscape._gain<.0001)
	await finish()
