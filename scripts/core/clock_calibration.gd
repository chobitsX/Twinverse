extends RefCounted
## Optional local diagnostic, run outside measured frames (or on a worker).
## Intersect causal brackets; never use wall time or pretend a midpoint is exact.

const ENGINE_HASH: String = "ed1daf0bf001b61586d9930840f2f1394092c079"
const MAGIC: int = 0x0031564b4c435654
const PACKET_BYTES: int = 120
const MAX_SAMPLES: int = 256

static func fit(samples: Array[Dictionary]) -> Dictionary:
	if samples.is_empty(): return {"status": "invalid", "reason": "no_samples"}
	var lower: int = -9223372036854775807
	var upper: int = 9223372036854775807
	var boot_uuid: String = str(samples[0].get("boot_uuid", ""))
	var source_pid: int = int(samples[0].get("godot_pid", 0))
	var min_rtt: int = 9223372036854775807
	for sample: Dictionary in samples:
		for key: String in ["godot_before_us", "godot_after_us", "absolute_before_us", "absolute_after_us", "godot_pid"]:
			if not sample.has(key) or not sample[key] is int:
				return {"status": "invalid", "reason": "missing_integer_" + key}
		if boot_uuid.is_empty() or sample.get("boot_uuid") != boot_uuid or source_pid <= 0 or sample.godot_pid != source_pid:
			return {"status": "invalid", "reason": "mixed_or_missing_clock_identity"}
		if sample.godot_before_us < 0 or sample.godot_after_us < sample.godot_before_us or sample.absolute_before_us < 0 or sample.absolute_after_us < sample.absolute_before_us:
			return {"status": "invalid", "reason": "nonmonotonic_sample"}
		var lo: int = sample.absolute_before_us - sample.godot_after_us
		var hi: int = sample.absolute_after_us - sample.godot_before_us
		lower = maxi(lower, lo)
		upper = mini(upper, hi)
		min_rtt = mini(min_rtt, sample.godot_after_us - sample.godot_before_us)
	if lower > upper: return {"status": "invalid", "reason": "empty_offset_intersection"}
	return {"status": "bounded", "godot_pid": source_pid, "boot_uuid": boot_uuid,
		"offset_us_lower": lower, "offset_us_upper": upper, "width_us": upper - lower,
		"minimum_round_trip_us": min_rtt, "sample_count": samples.size(),
		"mapping": "absolute_clock_us = godot_ticks_us + offset_us; same PID and boot only",
		"scope": "clock_origin_only_not_GPU_frame_assignment_or_duration"}

static func measure(helper_path: String, sample_count: int = 64, timeout_ms: int = 2000) -> Dictionary:
	var result: Dictionary = {"status": "failed", "samples": [], "kind": "clock_origin_calibration",
		"godot_pid": OS.get_process_id(), "engine": Engine.get_version_info(), "helper_path": helper_path}
	if OS.get_name() != "macOS" or str(Engine.get_version_info().hash) != ENGINE_HASH:
		result.reason = "unsupported_clock_implementation"
		return result
	if not helper_path.is_absolute_path() or not FileAccess.file_exists(helper_path):
		result.reason = "helper_not_found"
		return result
	if sample_count < 1 or sample_count > MAX_SAMPLES or timeout_ms < 1 or timeout_ms > 10000:
		result.reason = "invalid_limits"
		return result
	var started: int = Time.get_ticks_usec()
	result.started_us = started
	result.helper_sha256_before = FileAccess.get_sha256(helper_path)
	var deadline: int = started + timeout_ms * 1000
	var child: Dictionary = OS.execute_with_pipe(helper_path, PackedStringArray(["--stdio"]), false)
	if child.is_empty():
		result.reason = "helper_launch_failed"
		return result
	var pipe: FileAccess = child.stdio as FileAccess
	var error_pipe: FileAccess = child.stderr as FileAccess
	var pid: int = int(child.pid)
	result.helper_pid = pid
	var samples: Array[Dictionary] = []
	for index: int in range(sample_count):
		var request: PackedByteArray = PackedByteArray()
		request.resize(8)
		request.encode_u64(0, index + 1)
		var before: int = Time.get_ticks_usec()
		if before >= deadline:
			result.reason = "deadline"
			break
		if not pipe.store_buffer(request):
			result.reason = "request_write_failed"
			break
		var reply: PackedByteArray = PackedByteArray()
		while reply.size() < PACKET_BYTES and Time.get_ticks_usec() < deadline:
			var available: int = pipe.get_length()
			if available > 0:
				reply.append_array(pipe.get_buffer(mini(available, PACKET_BYTES - reply.size())))
			elif not OS.is_process_running(pid): break
			else: OS.delay_usec(10)
		var after: int = Time.get_ticks_usec()
		if reply.size() != PACKET_BYTES:
			result.reason = "deadline_or_incomplete_reply"
			break
		if reply.decode_u64(0) != MAGIC or reply.decode_u64(8) != index + 1 or reply.decode_u64(16) != pid:
			result.reason = "invalid_reply_identity"
			break
		var numer: int = reply.decode_u64(48)
		var denom: int = reply.decode_u64(56)
		var abs_before: int = reply.decode_u64(24)
		var abs_after: int = reply.decode_u64(40)
		if numer <= 0 or denom <= 0 or abs_before < 0 or abs_after < abs_before:
			result.reason = "invalid_native_clock"
			break
		var before_us: int = reply.decode_u64(64)
		var after_us: int = reply.decode_u64(72)
		var scale: float = (float(numer) / float(denom)) / 1000.0
		if before_us != int(float(abs_before) * scale) or after_us != int(float(abs_after) * scale):
			result.reason = "native_conversion_mismatch"
			break
		samples.append({"godot_before_us": before, "godot_after_us": after,
			"absolute_before_ticks": abs_before, "absolute_after_ticks": abs_after,
			"continuous_ticks": reply.decode_u64(32), "absolute_before_us": before_us,
			"absolute_after_us": after_us, "timebase_numer": numer, "timebase_denom": denom,
			"boot_uuid": reply.slice(80, 116).get_string_from_ascii(), "godot_pid": OS.get_process_id(), "sequence": index + 1})
	# Closing our own pipes sends EOF even if sampling failed; native idle timeout
	# is an independent fallback. Never look up or terminate processes by name.
	pipe.close()
	error_pipe.close()
	var cleanup_deadline: int = Time.get_ticks_usec() + 250000
	while OS.is_process_running(pid) and Time.get_ticks_usec() < cleanup_deadline: OS.delay_usec(1000)
	result.helper_killed = false
	if OS.is_process_running(pid):
		result.helper_kill_error = OS.kill(pid)
		result.helper_killed = true
		# Pinned OS_Unix::kill waits for/reaps the child without updating its
		# cached ProcessInfo. Querying it again would waitpid an already reaped
		# PID (ECHILD), and get_process_exit_code would misleadingly return 0.
		result.helper_still_running = false if result.helper_kill_error == OK else OS.is_process_running(pid)
		result.helper_exit_code = null
		result.helper_cleanup = "killed_and_reaped" if result.helper_kill_error == OK else "kill_failed"
	else:
		result.helper_still_running = false
		result.helper_exit_code = OS.get_process_exit_code(pid)
		result.helper_cleanup = "exited_and_reaped"
	result.elapsed_us = Time.get_ticks_usec() - started
	result.helper_sha256_after = FileAccess.get_sha256(helper_path)
	result.samples = samples
	if result.helper_sha256_before != result.helper_sha256_after:
		result.reason = "helper_changed_during_calibration"
		return result
	if samples.size() != sample_count or result.helper_killed or result.helper_exit_code != 0:
		if not result.has("reason"): result.reason = "incomplete_or_failed_helper"
		return result
	var bounds: Dictionary = fit(samples)
	result.bounds = bounds
	result.status = "bounded" if bounds.status == "bounded" else "failed"
	if bounds.status != "bounded": result.reason = bounds.reason
	return result
