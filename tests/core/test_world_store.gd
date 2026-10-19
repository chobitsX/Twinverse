extends SceneTree
const Compare = preload("res://tests/core/test_ecophysiology.gd")
## Bounded persistence checks using isolated real files; no rendering or timing measurements.

const WorldState = preload("res://scripts/core/world_state.gd")
const Store = preload("res://scripts/core/world_store.gd")
var cases: Array[Dictionary] = []
var failures: Array[String] = []
var test_directory: String
var report_path: String = "res://docs/evidence/M1-001/world-store.json"


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, passed: bool) -> void:
	cases.append({"case": label, "passed": passed})
	if not passed: failures.append(label)


func _payload(time_s: float = 12.0) -> Dictionary:
	var world: WorldState = WorldState.new()
	world.current_scale_id = "fish"
	world.simulation_time_s = time_s
	return {"world": world.checkpoint(), "observer": {
		"views": {"fish": {"position": [0.0, 1.0, 2.0], "target": [0.0, 0.0, 0.0], "up": [0.0, 1.0, 0.0],
			"cutaway": true, "heart_region": "", "info_visible": false}},
		"preferences": {"render_ratio": 0.75, "muted": false, "reduced_motion": true,
			"master": 0.2, "environment_volume": 0.5, "music_volume": 0.4, "effects_volume": 0.3},
	}}


func _write(name_value: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(test_directory.path_join(name_value), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world-store-report="): report_path = arg.trim_prefix("--world-store-report=")
	var economy: Dictionary = _payload()
	economy.observer.preferences.render_ratio = 0.5
	_check("economy_preference_is_backwards_compatible", Store.payload_error(economy).is_empty())
	economy.observer.preferences.render_ratio = 0.4
	_check("unsupported_quality_is_rejected", not Store.payload_error(economy).is_empty())
	test_directory = ProjectSettings.globalize_path("res://.local/world-store-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(test_directory)
	var world: WorldState = WorldState.new()
	world.advance(0.025)
	world.set_time_scale(4.0)
	var saved: Dictionary = world.checkpoint()
	var restored: WorldState = WorldState.new()
	var identity: int = restored.get_instance_id()
	_check("restore_preserves_unique_object_and_fractional_step", restored.restore_checkpoint(saved) and Compare.equivalent(restored.checkpoint(), saved) and restored.get_instance_id() == identity)
	world.advance(0.01)
	restored.advance(0.01)
	_check("continuation_matches_uninterrupted_clock", Compare.equivalent(restored.checkpoint(), world.checkpoint()))
	restored.set_paused(true)
	saved = restored.checkpoint()
	restored.advance(7200.0)
	_check("paused_world_does_not_catch_up", Compare.equivalent(restored.checkpoint(), saved))
	restored.set_foreground(false)
	_check("restoring_does_not_restore_stale_window_focus", restored.restore_checkpoint(saved) and not restored.foreground)
	for entry: Array in [["simulation_time_s", -1.0], ["simulation_time_s", INF], ["time_scale", 100.0], ["seed", 1.5], ["target_fish_id", "another_fish"], ["paused", "true"], ["current_scale_id", "missing"], ["accumulator_s", 1.0]]:
		var invalid: Dictionary = saved.duplicate(true)
		invalid[entry[0]] = entry[1]
		_check("invalid_" + str(entry[0]) + "_" + str(entry[1]), not restored.restore_checkpoint(invalid) and Compare.equivalent(restored.checkpoint(), saved))
	var store: Store = Store.new(test_directory)
	_check("new_world_is_missing", store.load_session().status == "missing")
	_check("first_save_writes_real_file", store.save_session(_payload()) == "ok" and FileAccess.file_exists(test_directory.path_join("current.json")))
	var reader: Store = Store.new(test_directory)
	var result: Dictionary = reader.load_session()
	_check("fresh_store_roundtrip", result.status == "ok" and restored.restore_checkpoint(result.payload.world)
		and Compare.equivalent(restored.checkpoint(), _payload().world) and Store.vector(result.payload.observer.views.fish.position) == Vector3(0, 1, 2)
		and result.payload.observer.preferences == _payload().observer.preferences)
	_check("second_save_preserves_previous", store.save_session(_payload(20.0)) == "ok" and FileAccess.file_exists(test_directory.path_join("previous.json")))
	var before: String = FileAccess.get_file_as_string(test_directory.path_join("current.json"))
	_check("stale_session_cannot_overwrite", reader.save_session(_payload(99.0)) == "changed_on_disk" and FileAccess.get_file_as_string(test_directory.path_join("current.json")) == before)
	_write("current.json", "{interrupted")
	reader = Store.new(test_directory)
	result = reader.load_session()
	_check("corrupt_primary_recovers_previous", result.status == "recovered" and result.payload.world.simulation_time_s == 12.0)
	_check("recovered_save_keeps_good_backup", reader.save_session(_payload(13.0)) == "ok")
	_write("current.json", "broken again")
	reader = Store.new(test_directory)
	result = reader.load_session()
	_check("backup_survives_corrupt_primary_replacement", result.status == "recovered" and result.payload.world.simulation_time_s == 12.0)
	reader.save_session(_payload(14.0))
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(test_directory.path_join("current.json")))
	envelope.payload += " "
	_write("current.json", JSON.stringify(envelope))
	reader = Store.new(test_directory)
	_check("checksum_mismatch_recovers_previous", reader.load_session().status == "recovered")
	envelope.version = 999
	_write("current.json", JSON.stringify(envelope))
	reader = Store.new(test_directory)
	_check("future_format_is_not_silently_downgraded", reader.load_session().status == "incompatible" and reader.save_session(_payload()) == "protected")
	_write("current.json", "bad")
	_write("previous.json", "bad")
	reader = Store.new(test_directory)
	_check("all_corrupt_is_protected", reader.load_session().status == "corrupt" and reader.save_session(_payload()) == "protected")
	# A first-save crash after flush but before rename has only a pending file.
	for filename: String in ["current.json", "previous.json"]:
		DirAccess.remove_absolute(test_directory.path_join(filename))
	store = Store.new(test_directory)
	store.load_session()
	store.save_session(_payload(31.0))
	DirAccess.rename_absolute(test_directory.path_join("current.json"), test_directory.path_join("pending.json"))
	reader = Store.new(test_directory)
	result = reader.load_session()
	_check("complete_first_pending_checkpoint_recovers", result.status == "recovered" and result.payload.world.simulation_time_s == 31.0)
	_check("pending_recovery_is_backed_up_before_overwrite", reader.save_session(_payload(32.0)) == "ok" and FileAccess.file_exists(test_directory.path_join("previous.json")))
	var invalid_view: Dictionary = _payload()
	invalid_view.observer.views.fish.position = [NAN, 1.0, 2.0]
	_check("nonfinite_camera_rejected", Store.payload_error(invalid_view) == "invalid_view")
	invalid_view = _payload()
	invalid_view.observer.views.fish.target = invalid_view.observer.views.fish.position.duplicate()
	_check("degenerate_camera_rejected", Store.payload_error(invalid_view) == "invalid_view")
	invalid_view = _payload()
	invalid_view.observer.views.clear()
	_check("missing_current_observer_rejected", Store.payload_error(invalid_view) == "missing_current_view")
	invalid_view = _payload()
	invalid_view.world.model_version = "future-model"
	_check("changed_model_version_rejected", Store.payload_error(invalid_view) == "incompatible")
	# A filesystem failure must leave the committed checkpoint available.
	var blocked_dir: String = test_directory.path_join("not-a-directory")
	_write("not-a-directory", "occupied")
	var blocked: Store = Store.new(blocked_dir)
	blocked.load_session()
	_check("write_failure_reported", blocked.save_session(_payload()) in ["directory_unwritable", "write_failed"])
	var report: Dictionary = {"status": "passed" if failures.is_empty() else "failed", "cases": cases, "failures": failures,
		"scope": "Clock/checkpoint validation and bounded real-file recovery checks; no performance measurements.", "fixture_directory": test_directory}
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("WORLD_STORE_RESULT ", JSON.stringify({"status": report.status, "cases": cases.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
