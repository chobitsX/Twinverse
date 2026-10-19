extends "res://tests/integration/observation_framing_suite.gd"
const ProductionSound = preload("res://scripts/experience/soundscape.gd")
var observations: Dictionary = {}
var audio_sections: Array[Dictionary] = []
var audio_files: Array[String] = []

func sample_audio(sound: RefCounted, seconds: float, wav_name: String = "") -> Dictionary:
	var count: int = int(seconds*ProductionSound.SAMPLE_RATE)
	var raw: PackedByteArray = PackedByteArray()
	if not wav_name.is_empty(): raw.resize(count*4)
	var peak: float = 0.0
	var squares: float = 0.0
	for index: int in range(count):
		var frame: Vector2 = sound.next_frame()
		peak = maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		squares += frame.length_squared()/2.0
		if not wav_name.is_empty():
			# Only the file's final 20 ms fades for a clean preview ending.
			# Measurements retain the unchanged production output.
			var tail: float = minf(1.0,float(count-1-index)/(ProductionSound.SAMPLE_RATE*.02))
			raw.encode_s16(index*4,int(clampf(frame.x*tail,-1,1)*32767))
			raw.encode_s16(index*4+2,int(clampf(frame.y*tail,-1,1)*32767))
	var result: Dictionary = {"seconds":seconds,"peak":peak,"rms":sqrt(squares/count)}
	if not wav_name.is_empty():
		var wav: AudioStreamWAV = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(ProductionSound.SAMPLE_RATE)
		wav.stereo = true
		wav.data = raw
		check("save production PCM "+wav_name,wav.save_to_wav(directory.path_join(wav_name)) == OK)
		audio_files.append(wav_name)
		result["file"] = wav_name
		audio_sections.append(result)
	return result

func inspect_audio() -> void:
	var sound: RefCounted = ProductionSound.new()
	sound.music_volume = 0.0
	sound.effects_volume = 0.0
	sound.set_context("polar","polar",0.0,0.0)
	var polar: Dictionary = sample_audio(sound,6.0,"polar-reference.wav")
	check("polar environment alone produces bounded nonzero output", polar.rms > .001 and polar.peak < .4 and sound._polar_weight > .99)
	check("polar does not reuse ocean bird or traffic profile", sound._weights == Vector4.ZERO and sound._land_weights == Vector2.ZERO and sound._desert_weight == 0.0)
	sound.environment_volume = 0.0
	sample_audio(sound,.8)
	check("environment zero silences polar layer independently", sample_audio(sound,.2).peak < .0000001)
	sound.music_volume = .3
	sample_audio(sound,.4)
	check("music remains independently audible with environment zero", sample_audio(sound,.3).rms > .0002)
	sound.music_volume = 0.0
	sound.effects_volume = 1.0
	sample_audio(sound,.5)
	sound.cue("select")
	check("effect remains independent of polar environment and music", sample_audio(sound,.3).peak > .005)
	sample_audio(sound,.6)
	check("effect decays without residual environment leak", sample_audio(sound,.2).peak < .0000001)
	sound.effects_volume = 0.0
	sound.environment_volume = .8
	sample_audio(sound,.5)
	sound.muted = true
	sample_audio(sound,.6)
	check("mute settles polar output to silence", sample_audio(sound,.1).peak < .0000001)
	sound.muted = false
	sample_audio(sound,.5)
	check("unmute restores the same polar layer", sample_audio(sound,.3).rms > .001)
	sound.set_context("polar","galaxy",.5,0.0)
	var blend: Dictionary = sample_audio(sound,2.0,"polar-to-space-reference.wav")
	check("crossfade uses half polar weight and bounded output", absf(sound._polar_target-.5) < .000001 and absf(sound._polar_weight-.5) < .000001 and blend.rms > .0005 and blend.peak < .4)
	sound.set_context("galaxy","galaxy",0.0,0.0)
	sample_audio(sound,2.0)
	check("space removes polar wind water and terrestrial weight", sound._polar_target == 0.0 and sound._polar_weight < .0000001 and sound._land_weights == Vector2.ZERO and sound._weights.x == 0.0)
	sound.set_context("desert","desert",0.0,0.0)
	var desert: Dictionary = sample_audio(sound,.6)
	check("existing desert environment remains separate and bounded", sound._polar_target == 0.0 and sound._desert_target == 1.0 and desert.rms > .0005 and desert.peak < .4)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world225-review="): directory = argument.trim_prefix("--world225-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size = Vector2i(1280,800)
	get_window().unfocusable = true
	get_viewport().gui_disable_input = true
	check("diagnostic ignores native desktop input", get_window().unfocusable and get_viewport().gui_disable_input)
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	inspect_audio()
	main = Experience.instantiate()
	add_child(main)
	main._measurement_screen = get_window().current_screen
	# Sampling and control checks do not need to interrupt desktop listening.
	main._audio.volume_db = -80.0
	if not await ready_stage():
		await finish(); return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await arrive("polar"):
		await finish(); return
	await at_time(9.0)
	main.sound_panel.show()
	await settle()
	var old_date: float = main.solar_jd
	var checkpoint: Dictionary = main.world.checkpoint()
	check("actual host mixer receives polar context", main.soundscape._polar_target == 1.0 and main.soundscape._polar_weight > .99 and main._audio.playing)
	check("sound panel describes synthetic wind and nearshore water", main.sound_context_label.text.contains("合成") and main.sound_context_label.text.contains("近岸海水") and main.sound_context_label.text.contains("日期天气"))
	check("panel fits in the actual window", main.sound_panel.get_global_rect().end.x < 1280 and main.sound_panel.get_global_rect().position.y > 110 and main.sound_context_label.get_global_rect().end.y < main.sound_panel.get_global_rect().end.y)
	await capture("polar-sound-panel")
	var environment: HSlider = main.sound_panel.find_child("environment_volume",true,false) as HSlider
	var master: HSlider = main.sound_panel.find_child("master",true,false) as HSlider
	check("existing master and environment sliders are present", environment != null and master != null)
	if environment == null or master == null:
		await finish(); return
	var old_environment: float = environment.value
	var old_master: float = master.value
	environment.value = 0.0
	await settle()
	check("actual environment slider removes new layer", main.soundscape.environment_volume == 0.0 and main.soundscape._levels.x < .000001)
	environment.value = old_environment
	await settle()
	master.value = 0.0
	await settle()
	check("actual master slider silences polar host mix", main.soundscape.master == 0.0 and main.soundscape._gain < .000001)
	master.value = old_master
	await settle()
	main.sound_mute_button.pressed.emit()
	await settle()
	check("actual mute button controls polar and existing layers", main._muted and main.soundscape.muted and main.soundscape._gain < .000001)
	await capture("polar-sound-muted")
	main.sound_mute_button.pressed.emit()
	await settle()
	var checkpoint_unchanged: bool = main.world.checkpoint() == checkpoint and main.solar_jd == old_date
	check("actual unmute restores volume with same world checkpoint", not main._muted and not main.soundscape.muted and main.soundscape._gain > .1 and checkpoint_unchanged)
	if not await arrive("earth"):
		await finish(); return
	main.sound_panel.show()
	await settle()
	var return_before_tail: Dictionary = {"target":main.soundscape._polar_target,"weight":main.soundscape._polar_weight,"world_time_s":main.world.simulation_time_s,"paused":main.world.paused,"same_date":main.solar_jd == old_date,"sample_index":main.soundscape._sample_index}
	print("POLAR_RETURN_BEFORE_TAIL ",JSON.stringify(return_before_tail))
	# The production fade is measured in audio samples, not rendering frames.
	# Allow its existing quiet tail to decay without changing the mixer.
	var tail_deadline: int = Time.get_ticks_msec()+3000
	while main.soundscape._polar_target == 0.0 and main.soundscape._polar_weight >= .000001 and Time.get_ticks_msec() < tail_deadline:
		await get_tree().process_frame
	check("actual return removes polar atmosphere and keeps paused authority", main.soundscape._polar_target == 0.0 and main.soundscape._polar_weight < .000001 and main.world.simulation_time_s == 9.0 and main.solar_jd == old_date and main.world.paused)
	check("space panel keeps its listening aid boundary", main.sound_context_label.text.contains("非真空传声"))
	await capture("polar-sound-earth-return")
	observations = {"pcm_files":audio_files,"pcm_sections":audio_sections,"sample_rate":int(ProductionSound.SAMPLE_RATE),"world_time_s":main.world.simulation_time_s,"world_checkpoint_unchanged_by_audio_controls":checkpoint_unchanged,"return_before_tail":return_before_tail,"returned_polar_weight":main.soundscape._polar_weight,"audio_samples_after_return_measurement":main.soundscape._sample_index-int(return_before_tail.sample_index),"native_input_disabled":get_viewport().gui_disable_input,"screen_count":DisplayServer.get_screen_count(),"window_screen":get_window().current_screen,"primary_screen":DisplayServer.get_primary_screen(),"diagnostic_playback_db":main._audio.volume_db}
	await finish()

func finish() -> void:
	var report: Dictionary = {"cases":cases,"failures":failures,"captures":captures,"observations":observations,"debug":OS.is_debug_build(),"renderer":RenderingServer.get_current_rendering_driver_name(),"performance_test":false,"native_input_tested":false,"human_listening_tested":false,"device_playback_tested":false}
	var file: FileAccess = FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("POLAR_SOUND_SUITE ",cases.size()," failures=",JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
