extends Node
## One resource request, at most old + incoming scene. No authority writes until commit.

const WorldState = preload("res://scripts/core/world_state.gd")
const Catalog = preload("res://scripts/core/scale_catalog.gd")

signal intent_accepted(request_id: int, target_id: String)
signal resource_ready(request_id: int, incoming: Node)
signal authoring_started(request_id: int, outgoing: Node, incoming: Node, duration_s: float)
signal authoring_progress(request_id: int, normalized: float)
signal interactive(request_id: int, target_id: String, active: Node)
signal transition_failed(request_id: int, reason: String)
signal transition_cancelled(request_id: int, reason: String)
signal recovery_required(reason: String)
signal recovery_changed()
signal metrics_recorded(record: Dictionary)

enum Phase { IDLE, LOADING, PREPARING, AUTHORING, DRAINING }

var phase: Phase = Phase.IDLE
var overlap_budget_mb: float = 3072.0
var wait_for_visible_response: bool = false
var active_scene: Node
var active_estimated_mb: float = 0.0
var latest_metrics: Dictionary = {}
var _world: WorldState
var _host: Node
var _incoming: Node
var _next_request_id: int = 0
var _request_id: int = 0
var _target_id: String = ""
var _path: String = ""
var _target_estimated_mb: float = 0.0
var _intent_us: int = 0
var _resource_ready_us: int = 0
var _authoring_start_us: int = 0
var _authoring_duration_s: float = 0.0
var _timeout_ms: int = 10000
var _drain_start_us: int = 0
var _next_drain_poll_us: int = 0
var _drain_alerted: bool = false
var _source_id: String = ""
var _cache_at_request: bool = false
var _admitted_overlap_mb: float = 0.0
var _first_response_us: int = 0
var _resource_progress: float = -1.0
var _loaded_us: int = 0
var _constructed_us: int = 0
var _last_prepared: bool = false
# One failed target only; keeping this reference keeps CACHE_MODE_REUSE useful.
var _recovery: Dictionary = {}
var _retained_scene: PackedScene
var _loaded_scene: PackedScene


func configure(world: WorldState, scene_host: Node) -> void:
	_world = world
	_host = scene_host


func install_initial(node: Node, scale_id: String, estimated_mb: float = 0.0) -> bool:
	if _world == null or _host == null or active_scene != null or is_busy():
		return false
	if node == null or not Catalog.contains(scale_id) or not is_finite(estimated_mb) or estimated_mb < 0.0 or estimated_mb > overlap_budget_mb:
		return false
	if not _bind(node, scale_id):
		return false
	if node.get_parent() == null:
		_host.add_child(node)
	active_scene = node
	active_estimated_mb = estimated_mb
	_world.current_scale_id = scale_id
	return true


func is_busy() -> bool:
	return phase != Phase.IDLE


func request_transition(target_id: String, scene_path: String, estimated_mb: float,
		authoring_s: float = 1.2, timeout_ms: int = 10000) -> int:
	if is_busy() or _world == null or _host == null or not is_instance_valid(active_scene):
		return -1
	if not Catalog.contains(target_id) or target_id == _world.current_scale_id:
		return -1
	if not is_finite(authoring_s) or authoring_s < 0.0:
		return -1
	# A different request relinquishes the old slot before budget admission.
	if _recovery.get("path", "") != scene_path or _recovery.get("target", "") != target_id:
		_retained_scene = null
	_recovery.clear()
	_next_request_id += 1
	_request_id = _next_request_id
	_target_id = target_id
	_source_id = _world.current_scale_id
	_path = scene_path
	_target_estimated_mb = estimated_mb
	_admitted_overlap_mb = active_estimated_mb + estimated_mb
	_intent_us = Time.get_ticks_usec()
	_resource_ready_us = 0
	_resource_progress = -1.0
	_loaded_us = 0
	_constructed_us = 0
	_last_prepared = false
	_first_response_us = 0
	_authoring_start_us = 0
	_authoring_duration_s = maxf(0.0, authoring_s)
	_timeout_ms = maxi(1, timeout_ms)
	_cache_at_request = ResourceLoader.has_cached(_path)
	# Synchronous listeners can provide immediate UI/audio response to this signal.
	phase = Phase.LOADING
	recovery_changed.emit()
	intent_accepted.emit(_request_id, _target_id)
	if phase != Phase.LOADING:
		return _request_id
	if not is_finite(estimated_mb) or estimated_mb < 0.0 or active_estimated_mb + estimated_mb > overlap_budget_mb:
		_fail("resource_budget_rejected", false)
		return _request_id
	if not ResourceLoader.exists(_path, "PackedScene"):
		_fail("resource_missing", false)
		return _request_id
	var request_error: Error = ResourceLoader.load_threaded_request(_path, "PackedScene", false, ResourceLoader.CACHE_MODE_REUSE)
	if request_error != OK:
		_fail("resource_request_error:%s" % error_string(request_error), false)
	return _request_id


func cancel(reason: String = "user_cancelled") -> void:
	if phase == Phase.IDLE or phase == Phase.DRAINING:
		dismiss_recovery()
		return
	var draining: bool = phase == Phase.LOADING
	_retained_scene = null
	_drop_incoming()
	_record("cancelled", reason)
	_set_recovery_phase(draining)
	transition_cancelled.emit(_request_id, reason)


func loading_status() -> Dictionary:
	# Presentation snapshot only. Resource completion is not whole-transition completion.
	return {"phase":phase,"target":_target_id,"resource_fraction":_resource_progress,
		"cancellable":phase in [Phase.LOADING,Phase.PREPARING,Phase.AUTHORING]}


func reserved_estimated_mb() -> float:
	return active_estimated_mb + (_target_estimated_mb if is_busy() else float(_recovery.get("estimated_mb", 0.0)) if _retained_scene != null else 0.0)


func acknowledge_first_response(request_id: int) -> void:
	# Call after the first actual visual/audio response, not merely on intent reception.
	if request_id == _request_id and _first_response_us == 0:
		_first_response_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	match phase:
		Phase.LOADING:
			_poll_loading()
		Phase.PREPARING:
			_poll_preparing()
		Phase.AUTHORING:
			var elapsed_s: float = float(Time.get_ticks_usec() - _authoring_start_us) / 1000000.0
			var progress: float = 1.0 if _authoring_duration_s <= 0.0 else clampf(elapsed_s / _authoring_duration_s, 0.0, 1.0)
			authoring_progress.emit(_request_id, progress)
			if phase == Phase.AUTHORING and progress >= 1.0:
				_commit()
		Phase.DRAINING:
			_poll_draining()


func _poll_loading() -> void:
	var progress: Array = []
	var load_status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_path, progress)
	if not progress.is_empty() and is_finite(float(progress[0])):
		_resource_progress = clampf(float(progress[0]), 0.0, 1.0)
	if load_status != ResourceLoader.THREAD_LOAD_LOADED and Time.get_ticks_usec() - _intent_us > _timeout_ms * 1000:
		_fail("resource_timeout", true)
		return
	if load_status == ResourceLoader.THREAD_LOAD_FAILED or load_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		if load_status == ResourceLoader.THREAD_LOAD_FAILED:
			# A failed terminal task still owns its request token until get() collects it.
			ResourceLoader.load_threaded_get(_path)
		_fail("resource_load_failed", false)
		return
	if load_status != ResourceLoader.THREAD_LOAD_LOADED:
		return
	# Let the host present its loading feedback before main-thread scene construction.
	# The existing deadline still covers this wait; cancellation can drain the request.
	if wait_for_visible_response and _first_response_us == 0:
		if Time.get_ticks_usec() - _intent_us > _timeout_ms * 1000:
			_fail("resource_timeout", true)
		return
	_loaded_us = Time.get_ticks_usec()
	var loaded: Resource = ResourceLoader.load_threaded_get(_path)
	if not loaded is PackedScene:
		_fail("resource_not_packed_scene", false)
		return
	_loaded_scene = loaded as PackedScene
	_retained_scene = null
	_incoming = _loaded_scene.instantiate()
	if not _bind(_incoming, _target_id):
		_fail("state_binding_failed", false)
		return
	# Instantiation and binding are part of T_resource_ready, never hidden in authoring.
	_host.add_child(_incoming)
	_constructed_us = Time.get_ticks_usec()
	phase = Phase.PREPARING
	_poll_preparing()


func _poll_preparing() -> void:
	if not is_instance_valid(_incoming) or _incoming.get_parent() != _host:
		_fail("incoming_lost_during_preparation", false)
		return
	if _incoming.has_method("is_prepared"):
		var prepared: Variant = _incoming.call("is_prepared")
		if not prepared is bool:
			_fail("invalid_preparation_contract", false)
			return
		_last_prepared = prepared
		if not prepared:
			if Time.get_ticks_usec() - _intent_us > _timeout_ms * 1000:
				_fail("preparation_timeout", false)
			return
	else:
		_last_prepared = true
	# A completed render is usable even when the main loop observed it late.
	# Preserve the elapsed time and deadline violation instead of discarding it.
	_resource_ready_us = Time.get_ticks_usec()
	phase = Phase.AUTHORING
	resource_ready.emit(_request_id, _incoming)
	if phase != Phase.AUTHORING:
		return
	_authoring_start_us = Time.get_ticks_usec()
	authoring_started.emit(_request_id, active_scene, _incoming, _authoring_duration_s)


func _bind(node: Node, scale_id: String) -> bool:
	if node == null or not node.has_method("bind_world"):
		return false
	var result: Variant = node.call("bind_world", _world.snapshot(), scale_id)
	return result is bool and result


func _commit() -> void:
	if not is_instance_valid(_incoming):
		_fail("incoming_lost_before_commit", false)
		return
	var old: Node = active_scene
	active_scene = _incoming
	_incoming = null
	_loaded_scene = null
	active_estimated_mb = _target_estimated_mb
	_world.current_scale_id = _target_id
	# Detach immediately so the old scene cannot receive another process tick.
	if is_instance_valid(old):
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
	phase = Phase.IDLE
	_record("interactive", "")
	interactive.emit(_request_id, _target_id, active_scene)


func _fail(reason: String, drain: bool) -> void:
	_recovery = {"target": _target_id, "path": _path, "estimated_mb": _target_estimated_mb,
		"reason": reason, "ready": not drain}
	_retained_scene = _loaded_scene if reason == "preparation_timeout" else null
	_drop_incoming()
	_record("failed", reason)
	_set_recovery_phase(drain)
	transition_failed.emit(_request_id, reason)
	recovery_changed.emit()


func _drop_incoming() -> void:
	if is_instance_valid(_incoming):
		if _incoming.get_parent() != null:
			_incoming.get_parent().remove_child(_incoming)
		_incoming.queue_free()
	_incoming = null
	_loaded_scene = null


func _set_recovery_phase(drain: bool) -> void:
	phase = Phase.DRAINING if drain else Phase.IDLE
	if drain:
		_drain_start_us = Time.get_ticks_usec()
		_next_drain_poll_us = _drain_start_us
		_drain_alerted = false


func _poll_draining() -> void:
	var now_us: int = Time.get_ticks_usec()
	if now_us < _next_drain_poll_us:
		return
	_next_drain_poll_us = now_us + 500000
	var load_status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_path)
	if load_status == ResourceLoader.THREAD_LOAD_LOADED:
		# No cancellation API: collect only at terminal state. Retain at most one
		# timed-out target until retry, dismissal or replacement; never a live scene.
		var loaded: Resource = ResourceLoader.load_threaded_get(_path)
		if not _recovery.is_empty() and loaded is PackedScene:
			_retained_scene = loaded as PackedScene
		phase = Phase.IDLE
		_finish_recovery()
	elif load_status == ResourceLoader.THREAD_LOAD_FAILED or load_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		if load_status == ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(_path)
		phase = Phase.IDLE
		_finish_recovery()
	elif now_us - _drain_start_us >= 10000000 and not _drain_alerted:
		_drain_alerted = true
		recovery_required.emit("后台资源仍未结束；当前层可继续观察，请稍后重试或退出后重开。")


func recovery_state() -> Dictionary:
	return _recovery.duplicate(true)


func dismiss_recovery() -> void:
	_recovery.clear()
	_retained_scene = null
	recovery_changed.emit()


func _finish_recovery() -> void:
	if not _recovery.is_empty(): _recovery["ready"] = true
	recovery_changed.emit()


func _record(outcome: String, reason: String) -> void:
	var end_us: int = Time.get_ticks_usec()
	var ready_ms: Variant = null if _resource_ready_us == 0 else float(_resource_ready_us - _intent_us) / 1000.0
	var interactive_ms: Variant = float(end_us - _intent_us) / 1000.0 if outcome == "interactive" else null
	var overhead_ms: Variant = null
	if outcome == "interactive" and ready_ms != null:
		overhead_ms = float(interactive_ms) - float(ready_ms) - _authoring_duration_s * 1000.0
	latest_metrics = {
		"request_id": _request_id, "source_id": _source_id, "target_id": _target_id,
		"outcome": outcome, "reason": reason, "resource_path": _path,
		"cache_at_request": _cache_at_request, "intent_accepted_us": _intent_us,
		"first_response_us": _first_response_us,
		"T_first_response_ms": null if _first_response_us == 0 else float(_first_response_us - _intent_us) / 1000.0,
		"resource_ready_us": _resource_ready_us, "authoring_start_us": _authoring_start_us,
		"interactive_us": end_us if outcome == "interactive" else null,
		"T_resource_ready_ms": ready_ms, "T_interactive_ms": interactive_ms,
		"T_resource_loaded_ms": null if _loaded_us == 0 else float(_loaded_us - _intent_us) / 1000.0,
		"T_scene_constructed_ms": null if _constructed_us == 0 else float(_constructed_us - _intent_us) / 1000.0,
		"prepared_at_last_poll": _last_prepared,
		"ready_after_deadline": _resource_ready_us > 0 and _resource_ready_us - _intent_us > _timeout_ms * 1000,
		"D_authoring_approved_ms": _authoring_duration_s * 1000.0,
		"D_pipeline_overhead_ms": overhead_ms,
		"estimated_overlap_mb": _admitted_overlap_mb,
		"target_fish_id": _world.TARGET_FISH_ID, "simulation_time_s": _world.simulation_time_s,
	}
	metrics_recorded.emit(latest_metrics.duplicate(true))
