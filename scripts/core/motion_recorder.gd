extends RefCounted
## Observes the rendered root viewport. Never changes simulation delta, time or quality.

const INTERVAL_US: int = 33334
const MAX_QUEUE_FRAMES: int = 4
const MAX_QUEUE_BYTES: int = 64 * 1024 * 1024
const MAX_DURATION_S: float = 120.0
const MAX_CAPTURE_FRAMES: int = 3600
const MAX_OUTPUT_BYTES: int = 4 * 1024 * 1024 * 1024
const COLUMNS: PackedStringArray = ["capture_index", "file", "t_us", "elapsed_s", "context_sample_us", "context_age_us", "readback_us", "process_frame", "drawn_frame", "width", "height", "image_format", "raw_bytes", "png_bytes", "png_encode_us", "file_write_us", "context_json"]

var _running: bool = false
var _headless_test: bool = false
var _viewport: Viewport
var _out_dir: String = ""
var _metadata: Dictionary = {}
var _context: Dictionary = {}
var _context_sample_us: int = 0
var _pending_capture: bool = false
var _start_us: int = 0
var _next_due_us: int = 0
var _last_capture_us: int = 0
var _last_sample_us: int = 0
var _attempts: int = 0
var _rate_limited_samples: int = 0
var _missed_due_slots: int = 0
var _dropped_backpressure: int = 0
var _dropped_invalid_image: int = 0
var _pending_at_finish: int = 0
var _readback_total_us: int = 0
var _readback_max_us: int = 0
var _max_duration_s: float = 90.0
var _max_frames: int = 2700
var _max_output_bytes: int = MAX_OUTPUT_BYTES
var _queue_frame_limit: int = MAX_QUEUE_FRAMES
var _queue_byte_limit: int = MAX_QUEUE_BYTES
var _queue: Array[Dictionary] = []
var _mutex: Mutex = Mutex.new()
var _semaphore: Semaphore = Semaphore.new()
var _writer: Thread = Thread.new()
var _stop_writer: bool = false
var _pending_frames: int = 0
var _pending_bytes: int = 0
var _peak_pending_frames: int = 0
var _peak_pending_bytes: int = 0
var _written_frames: int = 0
var _written_bytes: int = 0
var _dropped_write_or_limit: int = 0
var _limit_reason: String = ""
var _limit_us: int = 0
var _writer_errors: Array[String] = []
var _first_written_us: int = 0
var _last_written_us: int = 0
var _final_summary: Dictionary = {}


func begin(output_dir: String, root_viewport: Viewport, metadata: Dictionary = {}) -> Error:
	if _running or _writer.is_started() or not _final_summary.is_empty(): return ERR_ALREADY_IN_USE
	if not is_instance_valid(root_viewport): return ERR_INVALID_PARAMETER
	_headless_test = DisplayServer.get_name() == "headless" and bool(metadata.get("headless_test_images", false))
	if DisplayServer.get_name() == "headless" and not _headless_test: return ERR_UNAVAILABLE
	_out_dir = ProjectSettings.globalize_path(output_dir)
	if not _out_dir.is_absolute_path(): return ERR_INVALID_PARAMETER
	if DirAccess.dir_exists_absolute(_out_dir):
		var existing: DirAccess = DirAccess.open(_out_dir)
		if existing == null or not existing.get_files().is_empty() or not existing.get_directories().is_empty(): return ERR_ALREADY_EXISTS
	var error: Error = DirAccess.make_dir_recursive_absolute(_out_dir.path_join("frames"))
	if error != OK: return error
	_viewport = root_viewport
	_metadata = metadata.duplicate(true)
	_max_duration_s = clampf(float(metadata.get("max_duration_s", 90.0)), 0.1, MAX_DURATION_S)
	_max_frames = clampi(int(metadata.get("max_frames", 2700)), 1, MAX_CAPTURE_FRAMES)
	_max_output_bytes = clampi(int(metadata.get("max_output_bytes", MAX_OUTPUT_BYTES)), 1, MAX_OUTPUT_BYTES)
	_queue_frame_limit = clampi(int(metadata.get("queue_frame_limit", MAX_QUEUE_FRAMES)), 1, MAX_QUEUE_FRAMES)
	_queue_byte_limit = clampi(int(metadata.get("queue_byte_limit", MAX_QUEUE_BYTES)), 1, MAX_QUEUE_BYTES)
	_start_us = Time.get_ticks_usec()
	_next_due_us = _start_us
	_metadata.merge({"schema_version": 1, "source": "generated_headless_test_images" if _headless_test else "actual_root_viewport_after_frame_post_draw",
		"headless": DisplayServer.get_name() == "headless", "engine": Engine.get_version_info(),
		"rendering_driver": "headless" if _headless_test else RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": "headless" if _headless_test else RenderingServer.get_current_rendering_method(),
		"debug_build": OS.is_debug_build(), "pid": OS.get_process_id(), "start_us": _start_us,
		"started_utc": Time.get_datetime_string_from_system(true), "target_max_hz": 30.0, "minimum_interval_us": INTERVAL_US,
		"max_duration_s": _max_duration_s, "max_frames": _max_frames, "max_output_bytes": _max_output_bytes,
		"queue_frame_limit": _queue_frame_limit, "queue_raw_byte_limit": _queue_byte_limit,
		"timestamp_scope": "frame_post_draw callback before synchronous image readback, monotonic ticks; not OS presentation timestamps",
		"context_scope": "latest host-supplied sample; context_age_us exposes its age at capture",
		"overhead_scope": "GPU readback blocks caller; PNG encoding and file IO run on one writer thread; this run is not a performance baseline",
		"capture_effects": "no changes to viewport size, scaling, quality, application delta, world time, authoring duration or engine fps",
		"audio_captured": false, "memory_scope": "queued plus in-flight raw images; excludes viewport/renderer and one temporary compressed PNG buffer"}, true)
	error = _write_manifest({"status": "running", "metadata": _metadata})
	if error != OK: return error
	error = _writer.start(_writer_loop)
	if error != OK:
		_write_manifest({"status": "error", "metadata": _metadata, "error": error_string(error)})
		return error
	_running = true
	if not _headless_test: RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	return OK


func sample(context: Dictionary) -> void:
	if not _running: return
	var now: int = Time.get_ticks_usec()
	_context = context.duplicate(true)
	_context_sample_us = now
	_last_sample_us = now
	if float(now - _start_us) / 1000000.0 >= _max_duration_s:
		_set_limit("max_duration")
		return
	if _attempts >= _max_frames:
		_set_limit("max_frames")
		return
	if now < _next_due_us:
		_rate_limited_samples += 1
		return
	if _get_limit().is_empty(): _pending_capture = true


func is_running() -> bool:
	return _running


func _on_frame_post_draw() -> void:
	if not _running or not _pending_capture: return
	_pending_capture = false
	var now: int = Time.get_ticks_usec()
	if now < _next_due_us or not _get_limit().is_empty(): return
	if float(now - _start_us) / 1000000.0 >= _max_duration_s:
		_set_limit("max_duration")
		return
	var capture_index: int = _attempts
	_attempts += 1
	if _last_capture_us > 0:
		_missed_due_slots += maxi(0, int((now - _last_capture_us) / INTERVAL_US) - 1)
	_last_capture_us = now
	_next_due_us = now + INTERVAL_US
	if not is_instance_valid(_viewport):
		_set_limit("viewport_lost")
		return
	var texture: ViewportTexture = _viewport.get_texture()
	var expected_bytes: int = texture.get_width() * texture.get_height() * 4
	if not _has_capacity(expected_bytes):
		_dropped_backpressure += 1
		return
	var readback_start: int = Time.get_ticks_usec()
	var captured: Image = _read_frame_image()
	var readback_us: int = Time.get_ticks_usec() - readback_start
	_readback_total_us += readback_us
	_readback_max_us = maxi(_readback_max_us, readback_us)
	if captured == null or captured.is_empty():
		_dropped_invalid_image += 1
		return
	# Keep the actual SDR pixels. Do not silently tonemap/convert an HDR frame.
	if captured.get_format() not in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
		_dropped_invalid_image += 1
		_set_limit("unsupported_image_format")
		return
	var raw_bytes: int = captured.get_data_size()
	var record: Dictionary = {"capture_index": capture_index, "file": "frames/frame-%06d.png" % capture_index,
		"t_us": now, "elapsed_s": float(now - _start_us) / 1000000.0,
		"context_sample_us": _context_sample_us, "context_age_us": now - _context_sample_us,
		"readback_us": readback_us, "process_frame": Engine.get_process_frames(), "drawn_frame": Engine.get_frames_drawn(),
		"width": captured.get_width(), "height": captured.get_height(), "image_format": captured.get_format(),
		"raw_bytes": raw_bytes, "context_json": JSON.stringify(_context)}
	_mutex.lock()
	if _pending_frames >= _queue_frame_limit or _pending_bytes + raw_bytes > _queue_byte_limit:
		_mutex.unlock()
		_dropped_backpressure += 1
		return
	_queue.append({"image": captured, "record": record})
	_pending_frames += 1
	_pending_bytes += raw_bytes
	_peak_pending_frames = maxi(_peak_pending_frames, _pending_frames)
	_peak_pending_bytes = maxi(_peak_pending_bytes, _pending_bytes)
	_mutex.unlock()
	_semaphore.post()


func _read_frame_image() -> Image:
	return _viewport.get_texture().get_image()


func _has_capacity(bytes: int) -> bool:
	_mutex.lock()
	var result: bool = _limit_reason.is_empty() and _pending_frames < _queue_frame_limit and _pending_bytes + bytes <= _queue_byte_limit
	_mutex.unlock()
	return result


func _set_limit(reason: String) -> void:
	_mutex.lock()
	if _limit_reason.is_empty():
		_limit_reason = reason
		_limit_us = Time.get_ticks_usec()
	_mutex.unlock()


func _get_limit() -> String:
	_mutex.lock()
	var value: String = _limit_reason
	_mutex.unlock()
	return value


func _writer_loop() -> void:
	var csv: FileAccess = FileAccess.open(_out_dir.path_join("frames.csv"), FileAccess.WRITE)
	if csv == null:
		_mutex.lock()
		_writer_errors.append("Cannot open frames.csv: " + error_string(FileAccess.get_open_error()))
		_limit_reason = "writer_error"
		_limit_us = Time.get_ticks_usec()
		_mutex.unlock()
	else:
		csv.store_csv_line(COLUMNS)
	var last_flush_us: int = Time.get_ticks_usec()
	while true:
		_semaphore.wait()
		_mutex.lock()
		var item: Dictionary = {} if _queue.is_empty() else _queue.pop_front()
		var should_stop: bool = _stop_writer and item.is_empty()
		_mutex.unlock()
		if should_stop: break
		if item.is_empty(): continue
		var captured: Image = item.image
		var record: Dictionary = item.record
		var wrote: bool = false
		if csv != null and _written_bytes < _max_output_bytes:
			var encode_start: int = Time.get_ticks_usec()
			var encoded: PackedByteArray = captured.save_png_to_buffer()
			record["png_encode_us"] = Time.get_ticks_usec() - encode_start
			record["png_bytes"] = encoded.size()
			if encoded.is_empty():
				_writer_errors.append("PNG encoding failed: " + str(record.file))
				_set_limit("writer_error")
			elif _written_bytes + encoded.size() > _max_output_bytes:
				_set_limit("max_output_bytes")
			else:
				var write_start: int = Time.get_ticks_usec()
				var png_file: FileAccess = FileAccess.open(_out_dir.path_join(record.file), FileAccess.WRITE)
				var write_error: Error = FileAccess.get_open_error()
				if png_file != null:
					png_file.store_buffer(encoded)
					write_error = png_file.get_error()
					png_file.close()
				record["file_write_us"] = Time.get_ticks_usec() - write_start
				if write_error == OK:
					var values: PackedStringArray = []
					for column: String in COLUMNS: values.append(str(record.get(column, "")))
					csv.store_csv_line(values)
					_written_frames += 1
					_written_bytes += encoded.size()
					if _first_written_us == 0: _first_written_us = record.t_us
					_last_written_us = record.t_us
					wrote = true
				else:
					_writer_errors.append("PNG write failed: %s %s" % [record.file, error_string(write_error)])
					_set_limit("writer_error")
		captured = null
		item.clear()
		_mutex.lock()
		_pending_frames -= 1
		_pending_bytes -= int(record.raw_bytes)
		if not wrote: _dropped_write_or_limit += 1
		_mutex.unlock()
		if csv != null and (Time.get_ticks_usec() - last_flush_us > 2000000 or _written_frames % 30 == 0):
			csv.flush()
			last_flush_us = Time.get_ticks_usec()
	if csv != null:
		csv.flush()
		if csv.get_error() != OK: _writer_errors.append("CSV write failed: " + error_string(csv.get_error()))
		csv.close()


func finish() -> Dictionary:
	if not _final_summary.is_empty(): return _final_summary.duplicate(true)
	if not _running: return {"status": "not_started"}
	_running = false
	var finish_us: int = Time.get_ticks_usec()
	_pending_at_finish = 1 if _pending_capture else 0
	_pending_capture = false
	if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw): RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)
	_mutex.lock()
	_stop_writer = true
	_mutex.unlock()
	_semaphore.post()
	var flush_start: int = Time.get_ticks_usec()
	if _writer.is_started(): _writer.wait_to_finish()
	var reason: String = _get_limit()
	_final_summary = {"status": "completed" if _writer_errors.is_empty() else "error", "metadata": _metadata,
		"stop_reason": "finish_requested" if reason.is_empty() else reason,
		"finish_requested_us": finish_us, "capture_end_us": mini(mini(finish_us, _limit_us if _limit_us > 0 else finish_us), _start_us + int(_max_duration_s * 1000000.0)),
		"writer_flush_us": Time.get_ticks_usec() - flush_start, "elapsed_s": float(finish_us - _start_us) / 1000000.0,
		"attempted_frames": _attempts, "written_frames": _written_frames, "written_png_bytes": _written_bytes,
		"first_written_us": _first_written_us, "last_written_us": _last_written_us,
		"rate_limited_main_samples": _rate_limited_samples, "missed_due_slots_estimate": _missed_due_slots,
		"dropped_backpressure": _dropped_backpressure, "dropped_invalid_image": _dropped_invalid_image,
		"dropped_write_or_limit": _dropped_write_or_limit, "pending_request_cancelled_at_finish": _pending_at_finish,
		"peak_pending_frames_including_writer": _peak_pending_frames, "peak_pending_raw_bytes_including_writer": _peak_pending_bytes,
		"readback_total_us": _readback_total_us, "readback_max_us": _readback_max_us,
		"writer_errors": _writer_errors, "last_host_sample_us": _last_sample_us,
		"all_attempted_frames_written": _attempts == _written_frames, "capture_truncated_by_limit": not reason.is_empty(),
		"performance_baseline_eligible": false}
	if _write_manifest(_final_summary) != OK: _final_summary["status"] = "error_manifest_write"
	_viewport = null
	return _final_summary.duplicate(true)


func _write_manifest(value: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(_out_dir.path_join("motion.json"), FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	var error: Error = file.get_error()
	file.close()
	return error
