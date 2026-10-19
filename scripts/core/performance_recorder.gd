extends RefCounted
## Per-loop sampling, buffered disk writes, explicit missing data. Call finish before exit.

const FORMAT_VERSION: int = 2
const ClockCalibration = preload("res://scripts/core/clock_calibration.gd")
const VERIFIED_METAL_HASH: String = "ed1daf0bf001b61586d9930840f2f1394092c079"
const METAL_TIMESTAMP_UNIMPLEMENTED: String = "backend_unimplemented_godot_metal_timestamps"
const METAL_TIMESTAMP_SOURCE: String = "https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/metal/rendering_device_driver_metal.cpp#L2335-L2355"
const CHUNK_FRAME_LIMIT: int = 240
const CHUNK_INTERVAL_US: int = 2000000
const MAX_PENDING_CHUNKS: int = 8
const VIEWPORT_WARMUP_FRAMES: int = 8
const FRAME_COLUMNS: PackedStringArray = [
	"sample_index", "t_us", "elapsed_s", "engine_process_frame", "engine_drawn_frame",
	"main_interval_ms", "supplied_delta_ms", "cpu_setup_ms", "cpu_viewport_sum_ms", "cpu_render_total_ms",
	"gpu_viewport_sum_ms", "gpu_timestamp_frame", "gpu_timestamp_count", "gpu_validity",
	"viewport_count", "output_width_px", "output_height_px", "window_scale",
	"gpu_resource_bytes", "gpu_texture_bytes", "gpu_buffer_bytes", "godot_static_bytes",
	"sample_collection_us", "viewports_json", "context_json",
]

class BufferSizeProbe extends CompositorEffect:
	var _mutex: Mutex = Mutex.new()
	var _latest: Dictionary = {}

	func _init() -> void:
		effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
		access_resolved_color = false
		access_resolved_depth = false
		needs_motion_vectors = false
		needs_normal_roughness = false
		needs_separate_specular = false

	func _render_callback(_callback_type: int, render_data: RenderData) -> void:
		var buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers() as RenderSceneBuffersRD
		if buffers == null:
			return
		var internal: Vector2i = buffers.get_internal_size()
		var target: Vector2i = buffers.get_target_size()
		_mutex.lock()
		_latest = {"internal_width_px": internal.x, "internal_height_px": internal.y,
			"target_width_px": target.x, "target_height_px": target.y, "render_callback_us": Time.get_ticks_usec()}
		_mutex.unlock()

	func read() -> Dictionary:
		_mutex.lock()
		var result: Dictionary = _latest.duplicate()
		_mutex.unlock()
		return result

var _running: bool = false
var _out_dir: String = ""
var _metadata: Dictionary = {}
var _rows: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _start_us: int = 0
var _last_sample_us: int = 0
var _last_chunk_us: int = 0
var _samples: int = 0
var _last_gpu_frame: int = -1
var _last_drawn_frame: int = -1
var _viewport_seen: Dictionary = {}
var _dimension_probes: Dictionary = {}
var _last_viewport_key: String = ""
var _stable_viewport_samples: int = 0
var _headless: bool = false
var _gpu_backend_status: String = "runtime_validation_required"
var _rd: RenderingDevice
var _queue: Array[Dictionary] = []
var _queue_mutex: Mutex = Mutex.new()
var _semaphore: Semaphore = Semaphore.new()
var _writer: Thread = Thread.new()
var _stop_writer: bool = false
var _writer_errors: Array[String] = []
var _chunks_written: int = 0
var _rows_dropped: int = 0
var _pid: int = 0
var _clock_helper: String = ""
var _clock_start: Dictionary = {}
var _clock_end: Dictionary = {}
var _clock_summary: Dictionary = {"status": "not_requested"}


func begin(output_dir: String, metadata: Dictionary) -> Error:
	if _running or _writer.is_started():
		return ERR_ALREADY_IN_USE
	_out_dir = ProjectSettings.globalize_path(output_dir)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(_out_dir)
	if directory_error != OK:
		return directory_error
	if FileAccess.file_exists(_out_dir.path_join("capture.json")):
		return ERR_ALREADY_EXISTS
	_headless = DisplayServer.get_name() == "headless"
	_rd = null if _headless else RenderingServer.get_rendering_device()
	_gpu_backend_status = gpu_backend_status(_headless, "headless" if _headless else RenderingServer.get_current_rendering_driver_name(), Engine.get_version_info())
	_pid = OS.get_process_id()
	_metadata = metadata.duplicate(true)
	_clock_helper = str(metadata.get("clock_helper_path", ""))
	_clock_start = {}
	_clock_end = {}
	_clock_summary = {"status": "pending" if not _clock_helper.is_empty() else "not_requested"}
	_metadata.merge({
		"format_version": FORMAT_VERSION, "engine": Engine.get_version_info(),
		"os": OS.get_name(), "os_version": OS.get_version(), "model": OS.get_model_name(),
		"cpu": OS.get_processor_name(), "logical_cpu_count": OS.get_processor_count(),
		"physical_memory_bytes": OS.get_memory_info().get("physical", null), "pid": _pid,
		"display_server": DisplayServer.get_name(), "headless": _headless,
		"debug_build": OS.is_debug_build(), "features_release": OS.has_feature("release"),
		"features_arm64": OS.has_feature("arm64"), "features_x86_64": OS.has_feature("x86_64"),
		"rendering_method": "headless" if _headless else RenderingServer.get_current_rendering_method(),
		"rendering_driver": "headless" if _headless else RenderingServer.get_current_rendering_driver_name(),
		"gpu_name": null if _headless else RenderingServer.get_video_adapter_name(),
		"gpu_api": null if _headless else RenderingServer.get_video_adapter_api_version(),
		"vsync_mode": null if _headless else DisplayServer.window_get_vsync_mode(),
		"engine_max_fps": Engine.max_fps, "started_utc": Time.get_datetime_string_from_system(true),
		"cpu_scope": "frame_setup + all supplied drawn viewports; excludes script/physics/other engine CPU",
		"gpu_scope": "sum of viewport measured intervals; may overlap; not whole-device busy time or presentation",
		"gpu_backend_status": _gpu_backend_status,
		"gpu_backend_source": METAL_TIMESTAMP_SOURCE if _gpu_backend_status == METAL_TIMESTAMP_UNIMPLEMENTED else null,
		"gpu_raw_scope": "per-viewport raw API values retained for diagnostics; zero is never a valid duration; GPU aggregate requires every supplied viewport valid",
		"gpu_freshness": "requires new RenderingDevice captured timestamp frame plus stable viewport set; source is delayed, not matched to current CPU frame",
		"rss_scope": "macOS/Linux ps rss in KiB converted to bytes, sampled on writer thread",
		"gpu_memory_scope": "Godot RenderingServer resource allocation estimates; may overlap process unified memory; never sum with RSS",
		"chunk_frame_limit": CHUNK_FRAME_LIMIT, "chunk_interval_s": 2.0,
	}, true)
	_start_us = Time.get_ticks_usec()
	_last_chunk_us = _start_us
	_last_sample_us = 0
	_samples = 0
	_last_gpu_frame = -1
	_last_drawn_frame = -1
	_viewport_seen.clear()
	_dimension_probes.clear()
	_last_viewport_key = ""
	_stable_viewport_samples = 0
	_rows.clear()
	_events.clear()
	_queue.clear()
	_writer_errors.clear()
	_chunks_written = 0
	_rows_dropped = 0
	_stop_writer = false
	_metadata["capture_start_us"] = _start_us
	_metadata["clock_calibration"] = {"requested": not _clock_helper.is_empty(),
		"scope": "process clock origin only; does not supply GPU duration or frame assignment",
		"execution": "writer thread at start and after final frame collection; exclude warmup",
		"helper_sha256": FileAccess.get_sha256(_clock_helper) if not _clock_helper.is_empty() and FileAccess.file_exists(_clock_helper) else ""}
	var initial: Dictionary = {"status": "running", "metadata": _metadata}
	var file: FileAccess = FileAccess.open(_out_dir.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(initial, "\t"))
	file.close()
	var thread_error: Error = _writer.start(_writer_loop)
	if thread_error != OK:
		return thread_error
	_running = true
	return OK


func sample(delta: float, viewports: Array[Viewport], context: Dictionary = {}) -> void:
	if not _running:
		return
	var now_us: int = Time.get_ticks_usec()
	var frame_index: int = Engine.get_process_frames()
	var drawn_frame: int = Engine.get_frames_drawn()
	var drawing_advanced: bool = drawn_frame != _last_drawn_frame
	_last_drawn_frame = drawn_frame
	var interval: Variant = null if _last_sample_us == 0 else float(now_us - _last_sample_us) / 1000.0
	_last_sample_us = now_us
	var viewport_rows: Array[Dictionary] = []
	var key_parts: PackedStringArray = []
	var cpu_sum: float = 0.0
	var gpu_sum: float = 0.0
	var all_cpu_valid: bool = not _headless and not viewports.is_empty() and drawing_advanced
	var all_gpu_valid: bool = all_cpu_valid and _rd != null
	var gpu_frame: int = -1
	var gpu_timestamp_count: int = 0
	var gpu_validity: String = "fresh_delayed_timestamp_frame"
	if _rd != null:
		gpu_frame = _rd.get_captured_timestamps_frame()
		gpu_timestamp_count = _rd.get_captured_timestamps_count()
	if _headless:
		gpu_validity = "headless_unavailable"
	elif _gpu_backend_status == METAL_TIMESTAMP_UNIMPLEMENTED:
		gpu_validity = METAL_TIMESTAMP_UNIMPLEMENTED
		all_gpu_valid = false
	elif not drawing_advanced:
		gpu_validity = "no_new_drawn_frame"
		all_gpu_valid = false
	elif _rd == null or gpu_timestamp_count == 0:
		gpu_validity = "timestamps_unavailable"
		all_gpu_valid = false
	elif gpu_frame == _last_gpu_frame:
		gpu_validity = "stale_timestamp_frame"
		all_gpu_valid = false
	_last_gpu_frame = gpu_frame
	var seen_this_sample: Dictionary = {}
	for viewport: Viewport in viewports:
		if not is_instance_valid(viewport) or seen_this_sample.has(viewport.get_instance_id()):
			continue
		var instance_id: int = viewport.get_instance_id()
		seen_this_sample[instance_id] = true
		key_parts.append(str(instance_id))
		var viewport_rid: RID = viewport.get_viewport_rid()
		if not _viewport_seen.has(instance_id):
			_viewport_seen[instance_id] = frame_index
			if not _headless:
				RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
		var age: int = frame_index - int(_viewport_seen[instance_id])
		var enabled: bool = true
		var update_mode: Variant = null
		if viewport is SubViewport:
			update_mode = (viewport as SubViewport).render_target_update_mode
			enabled = update_mode != SubViewport.UPDATE_DISABLED
		var measured_cpu: float = 0.0 if _headless else RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		var measured_gpu: float = 0.0 if _headless else RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		var cpu_valid: bool = enabled and age >= 2 and is_finite(measured_cpu) and measured_cpu > 0.0
		var viewport_gpu_reason: String = classify_gpu_sample(null if _headless else measured_gpu, enabled, age, gpu_validity)
		var gpu_valid: bool = viewport_gpu_reason == "fresh_delayed_timestamp_frame"
		all_cpu_valid = all_cpu_valid and cpu_valid
		all_gpu_valid = all_gpu_valid and gpu_valid
		cpu_sum += measured_cpu if cpu_valid else 0.0
		gpu_sum += measured_gpu if gpu_valid else 0.0
		var size: Vector2 = viewport.get_texture().get_size()
		var internal_ratio: float = viewport.scaling_3d_scale
		var actual_dimensions: Dictionary = _read_dimensions(viewport, now_us)
		viewport_rows.append({
			"id": instance_id, "name": String(viewport.name), "path": String(viewport.get_path()),
			"viewport_class": viewport.get_class(), "has_camera_3d": viewport.get_camera_3d() != null,
			"width_px": int(size.x), "height_px": int(size.y), "scaling_3d_scale": internal_ratio,
			"internal_width_px_from_settings": int(size.x * internal_ratio), "internal_height_px_from_settings": int(size.y * internal_ratio),
			"actual_render_buffers": actual_dimensions,
			"scaling_3d_mode": viewport.scaling_3d_mode, "msaa_3d": viewport.msaa_3d,
			"screen_space_aa": viewport.screen_space_aa, "use_taa": viewport.use_taa,
			"visible_draw_calls": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"shadow_draw_calls": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"visible_primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
			"shadow_primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
			"update_mode": update_mode, "enabled": enabled, "measurement_age_frames": age,
			"cpu_ms": measured_cpu if cpu_valid else null, "gpu_ms": measured_gpu if gpu_valid else null,
			"raw_cpu_ms": measured_cpu if not _headless and is_finite(measured_cpu) else null,
			"raw_gpu_ms": measured_gpu if not _headless and is_finite(measured_gpu) else null,
			"gpu_validity": viewport_gpu_reason,
		})
	key_parts.sort()
	for old_id: int in _viewport_seen.keys():
		if not seen_this_sample.has(old_id):
			_viewport_seen.erase(old_id)
			_remove_dimension_probe(old_id)
	var viewport_key: String = ",".join(key_parts)
	_stable_viewport_samples = _stable_viewport_samples + 1 if viewport_key == _last_viewport_key else 0
	_last_viewport_key = viewport_key
	if _stable_viewport_samples < VIEWPORT_WARMUP_FRAMES:
		all_gpu_valid = false
		if gpu_validity == "fresh_delayed_timestamp_frame":
			gpu_validity = "viewport_set_warming_up"
	if not all_gpu_valid and gpu_validity == "fresh_delayed_timestamp_frame":
		gpu_validity = "zero_missing_or_unprepared_viewport"
	for viewport_row: Dictionary in viewport_rows:
		viewport_row["gpu_aggregate_validity"] = gpu_validity
		if _stable_viewport_samples < VIEWPORT_WARMUP_FRAMES and viewport_row["gpu_validity"] == "fresh_delayed_timestamp_frame":
			viewport_row["gpu_validity"] = "viewport_set_warming_up"
			viewport_row["gpu_ms"] = null
	if viewport_rows.is_empty():
		all_cpu_valid = false
		all_gpu_valid = false
	var setup_ms: float = 0.0 if _headless else RenderingServer.get_frame_setup_time_cpu()
	all_cpu_valid = all_cpu_valid and is_finite(setup_ms) and setup_ms >= 0.0
	var window_size: Vector2i = Vector2i.ZERO if _headless else DisplayServer.window_get_size()
	var texture_bytes: int = 0 if _headless else RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var buffer_bytes: int = 0 if _headless else RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
	var video_bytes: int = 0 if _headless else RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var row: Dictionary = {
		"sample_index": _samples, "t_us": now_us, "elapsed_s": float(now_us - _start_us) / 1000000.0,
		"engine_process_frame": frame_index, "engine_drawn_frame": drawn_frame,
		"main_interval_ms": interval, "supplied_delta_ms": delta * 1000.0,
		"cpu_setup_ms": setup_ms if not _headless else null,
		"cpu_viewport_sum_ms": cpu_sum if all_cpu_valid else null,
		"cpu_render_total_ms": setup_ms + cpu_sum if all_cpu_valid else null,
		"gpu_viewport_sum_ms": gpu_sum if all_gpu_valid else null,
		"gpu_timestamp_frame": gpu_frame if gpu_frame >= 0 else null,
		"gpu_timestamp_count": gpu_timestamp_count, "gpu_validity": gpu_validity,
		"viewport_count": viewport_rows.size(), "output_width_px": window_size.x,
		"output_height_px": window_size.y, "window_scale": null if _headless else DisplayServer.screen_get_scale(DisplayServer.window_get_current_screen()),
		"gpu_resource_bytes": video_bytes if video_bytes > 0 else null,
		"gpu_texture_bytes": texture_bytes if texture_bytes > 0 else null,
		"gpu_buffer_bytes": buffer_bytes if buffer_bytes > 0 else null,
		"godot_static_bytes": OS.get_static_memory_usage() if OS.is_debug_build() else null,
		"viewports_json": viewport_rows, "context_json": context.duplicate(true),
	}
	row["sample_collection_us"] = Time.get_ticks_usec() - now_us
	_rows.append(row)
	_samples += 1
	if _rows.size() >= CHUNK_FRAME_LIMIT or now_us - _last_chunk_us >= CHUNK_INTERVAL_US:
		_queue_chunk(now_us)


static func gpu_backend_status(headless: bool, driver: String, engine: Dictionary) -> String:
	if headless:
		return "headless_unavailable"
	# Scope this source-backed diagnosis to the exact inspected binary revision.
	if driver == "metal" and String(engine.get("hash", "")) == VERIFIED_METAL_HASH:
		return METAL_TIMESTAMP_UNIMPLEMENTED
	return "runtime_validation_required"


static func classify_gpu_sample(raw_ms: Variant, enabled: bool, age_frames: int, source_validity: String) -> String:
	if source_validity != "fresh_delayed_timestamp_frame":
		return source_validity
	if not enabled:
		return "viewport_disabled"
	if age_frames < VIEWPORT_WARMUP_FRAMES:
		return "viewport_warming_up"
	if raw_ms == null:
		return "viewport_metric_missing"
	if not is_finite(float(raw_ms)):
		return "viewport_metric_non_finite"
	if float(raw_ms) <= 0.0:
		return "viewport_metric_zero_or_negative"
	return "fresh_delayed_timestamp_frame"


func record_transition(record: Dictionary) -> void:
	if _running:
		_events.append(record.duplicate(true))


func finish() -> Dictionary:
	if not _running:
		return {"status": "not_running"}
	var finished_us: int = Time.get_ticks_usec()
	_queue_chunk(finished_us)
	_queue_mutex.lock()
	_stop_writer = true
	_queue_mutex.unlock()
	_semaphore.post()
	_writer.wait_to_finish()
	for viewport_id: int in _dimension_probes.keys():
		_remove_dimension_probe(viewport_id)
	_running = false
	var summary: Dictionary = {
		"status": "complete" if _writer_errors.is_empty() and _rows_dropped == 0 else "capture_error",
		"metadata": _metadata, "samples": _samples, "chunks": _chunks_written,
		"capture_end_us": finished_us, "duration_s": float(finished_us - _start_us) / 1000000.0,
		"dropped_rows": _rows_dropped, "errors": _writer_errors,
		"clock_calibration": _clock_summary,
	}
	var file: FileAccess = FileAccess.open(_out_dir.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()
	else:
		summary["status"] = "capture_error"
		summary["errors"].append("cannot_finalize_capture_json")
	return summary


func _queue_chunk(now_us: int) -> void:
	if _rows.is_empty() and _events.is_empty():
		return
	_queue_mutex.lock()
	if _queue.size() >= MAX_PENDING_CHUNKS:
		_rows_dropped += _rows.size()
		_writer_errors.append("writer_queue_full; frame/event chunk dropped")
	else:
		_queue.append({"rows": _rows, "events": _events})
	_queue_mutex.unlock()
	_rows = []
	_events = []
	_last_chunk_us = now_us
	_semaphore.post()


func _writer_loop() -> void:
	var chunk_index: int = 0
	if not _clock_helper.is_empty():
		_clock_start = ClockCalibration.measure(_clock_helper)
		_write_clock_file("clock-start.json", _clock_start)
	while true:
		_semaphore.wait()
		while true:
			_queue_mutex.lock()
			var job: Dictionary = {} if _queue.is_empty() else _queue.pop_front()
			var should_stop: bool = _stop_writer and _queue.is_empty() and job.is_empty()
			_queue_mutex.unlock()
			if should_stop:
				_finish_clock_calibration()
				return
			if job.is_empty():
				break
			_write_chunk(job, chunk_index)
			chunk_index += 1
			_chunks_written = chunk_index


func _write_clock_file(name: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(_out_dir.path_join(name), FileAccess.WRITE)
	if file == null:
		_note_writer_error("cannot_write_" + name)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()


func _finish_clock_calibration() -> void:
	if _clock_helper.is_empty(): return
	_clock_end = ClockCalibration.measure(_clock_helper)
	_write_clock_file("clock-end.json", _clock_end)
	if _clock_start.get("status") != "bounded" or _clock_end.get("status") != "bounded":
		_clock_summary = {"status": "failed", "reason": "start_or_end_failed",
			"start_reason": _clock_start.get("reason", ""), "end_reason": _clock_end.get("reason", "")}
	else:
		var samples: Array[Dictionary] = []
		samples.append_array(_clock_start.samples)
		samples.append_array(_clock_end.samples)
		_clock_summary = ClockCalibration.fit(samples)
		_clock_summary["start_bounds"] = _clock_start.bounds
		_clock_summary["end_bounds"] = _clock_end.bounds
		if _clock_start.helper_sha256_before != _clock_end.helper_sha256_after:
			_clock_summary = {"status": "failed", "reason": "helper_changed_between_batches"}
	_write_clock_file("clock-calibration.json", _clock_summary)
	if _clock_summary.status != "bounded":
		_note_writer_error("clock_calibration_failed:" + str(_clock_summary.get("reason", "unknown")))


func _write_chunk(job: Dictionary, index: int) -> void:
	var file: FileAccess = FileAccess.open(_out_dir.path_join("frames-%05d.csv" % index), FileAccess.WRITE)
	if file == null:
		_note_writer_error("cannot_write_frame_chunk:%d" % index)
		return
	file.store_csv_line(FRAME_COLUMNS)
	for row: Dictionary in job["rows"]:
		var values: PackedStringArray = []
		for column: String in FRAME_COLUMNS:
			var value: Variant = row.get(column)
			values.append("" if value == null else (JSON.stringify(value) if value is Array or value is Dictionary else str(value)))
		file.store_csv_line(values)
	file.close()
	var events: FileAccess = FileAccess.open(_out_dir.path_join("transitions-%05d.json" % index), FileAccess.WRITE)
	if events != null:
		events.store_string(JSON.stringify(job["events"], "\t"))
		events.close()
	else:
		_note_writer_error("cannot_write_transitions:%d" % index)
	var rss: Variant = null
	var rss_status: String = "unsupported_platform"
	if OS.get_name() == "macOS" or OS.get_name() == "Linux":
		var ps_output: Array = []
		var ps_status: int = OS.execute("/bin/ps", ["-o", "rss=", "-p", str(_pid)], ps_output, true)
		if ps_status == 0 and not ps_output.is_empty() and String(ps_output[0]).strip_edges().is_valid_int():
			rss = String(ps_output[0]).strip_edges().to_int() * 1024
			rss_status = "ps_rss_kib"
		else:
			rss_status = "ps_failed:%d" % ps_status
	var memory: FileAccess = FileAccess.open(_out_dir.path_join("memory-%05d.json" % index), FileAccess.WRITE)
	if memory != null:
		memory.store_string(JSON.stringify({"t_us": Time.get_ticks_usec(), "rss_bytes": rss, "rss_status": rss_status}, "\t"))
		memory.close()
	else:
		_note_writer_error("cannot_write_memory:%d" % index)


func _note_writer_error(message: String) -> void:
	_queue_mutex.lock()
	_writer_errors.append(message)
	_queue_mutex.unlock()


func _read_dimensions(viewport: Viewport, now_us: int) -> Dictionary:
	if _headless or _rd == null:
		return {}
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return {}
	var viewport_id: int = viewport.get_instance_id()
	if _dimension_probes.has(viewport_id) and _dimension_probes[viewport_id]["camera"].get_ref() != camera:
		_remove_dimension_probe(viewport_id)
	if not _dimension_probes.has(viewport_id):
		var original: Compositor = camera.compositor
		var effective: Compositor = original
		if effective == null:
			for candidate: Node in viewport.find_children("*", "WorldEnvironment", true, false):
				if candidate.get_viewport() == viewport:
					effective = (candidate as WorldEnvironment).compositor
					if effective != null:
						break
		var compositor: Compositor = Compositor.new()
		var effects: Array[CompositorEffect] = []
		if effective != null:
			effects.assign(effective.compositor_effects)
		var probe: BufferSizeProbe = BufferSizeProbe.new()
		effects.append(probe)
		compositor.compositor_effects = effects
		camera.compositor = compositor
		_dimension_probes[viewport_id] = {"camera": weakref(camera), "original": original, "installed": compositor, "probe": probe}
	var result: Dictionary = (_dimension_probes[viewport_id]["probe"] as BufferSizeProbe).read()
	if result.is_empty() or now_us - int(result["render_callback_us"]) > 100000:
		return {}
	result["source"] = "RenderSceneBuffersRD render callback"
	return result


func _remove_dimension_probe(viewport_id: int) -> void:
	if not _dimension_probes.has(viewport_id):
		return
	var entry: Dictionary = _dimension_probes[viewport_id]
	var camera: Camera3D = entry["camera"].get_ref() as Camera3D
	if camera != null and camera.compositor == entry["installed"]:
		camera.compositor = entry["original"]
	_dimension_probes.erase(viewport_id)
