extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## A camera-plane reference for the existing metre-authored local scenes.

const SCALES: Array[String] = ["pacific", "reef", "school", "fish", "woodland", "city", "desert", "polar"]
const BAR_LIMIT: float = 140.0
const BOX_SIZE: Vector2 = Vector2(200.0, 72.0)


static func supported(id: String) -> bool:
	return id in SCALES


static func nice_length(value: float) -> float:
	if not is_finite(value) or value <= 0.0: return 0.0
	var power: float = pow(10.0, floor(log(value) / log(10.0)))
	var fraction: float = value / power
	var factor: float = 10.0 if fraction >= 10.0 - 1e-9 else 5.0 if fraction >= 5.0 - 1e-9 else 2.0 if fraction >= 2.0 - 1e-9 else 1.0
	return factor * power


static func length_label(metres: float) -> String:
	var unit: String = I18n.text("米") if metres >= 1.0 else I18n.text("厘米") if metres >= .01 else I18n.text("毫米")
	var value: float = metres if unit == I18n.text("米") else metres * 100.0 if unit == I18n.text("厘米") else metres * 1000.0
	var text: String = "%.3f" % value
	while text.ends_with("0"): text = text.substr(0, text.length() - 1)
	if text.ends_with("."): text = text.substr(0, text.length() - 1)
	return text + " " + unit


static func measure(camera: Camera3D, center: Vector3, display_size: Vector2) -> Dictionary:
	if camera == null or not camera.is_inside_tree() or display_size.x <= 0.0 or display_size.y <= 0.0: return {}
	if camera.projection not in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]: return {}
	var depth: float = -camera.to_local(center).z
	if not is_finite(depth) or depth <= camera.near or depth >= camera.far: return {}
	var horizontal: float = absf(camera.get_camera_projection().x.x)
	if not is_finite(horizontal) or horizontal <= 0.0: return {}
	# Matrix coefficient avoids subtracting tiny world-space lengths at large
	# scene coordinates. scaling_3d_scale changes raster detail, not this plane.
	var width_m: float = 2.0 / horizontal
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE: width_m *= depth
	var metres_per_pixel: float = width_m / display_size.x
	var length_m: float = nice_length(metres_per_pixel * BAR_LIMIT)
	if length_m <= 0.0 or not is_finite(metres_per_pixel): return {}
	return {"length_m": length_m, "pixels": length_m / metres_per_pixel,
		"metres_per_pixel": metres_per_pixel, "depth_m": depth,
		"label": length_label(length_m), "reference": center,
		"projection": camera.projection}


static func layout(display_size: Vector2, reserved: Array[Rect2]) -> Rect2:
	var left: float = maxf(24.0, display_size.x * .5 - BOX_SIZE.x * .5)
	var right: float = display_size.x - BOX_SIZE.x - 24.0
	var candidates: Array[Vector2] = [Vector2(right, 126.0), Vector2(left, 126.0), Vector2(right, 190.0), Vector2(left, 190.0)]
	# Small-object labels can occupy the right corner in a narrow view. Keep
	# the usual corners first, then use the clear strip beside the left panel.
	for y: float in [126.0, 190.0]:
		for x: int in range(24, int(right) + 1, 24): candidates.append(Vector2(x, y))
	var safe: Rect2 = Rect2(Vector2(24.0, 120.0), Vector2(maxf(0.0, display_size.x - 48.0), maxf(0.0, display_size.y - 300.0)))
	for position: Vector2 in candidates:
		var rect: Rect2 = Rect2(position, BOX_SIZE)
		if not safe.encloses(rect): continue
		var free: bool = true
		for blocked: Rect2 in reserved:
			if rect.intersects(blocked.grow(4.0)):
				free = false
				break
		if free: return rect
	return Rect2()
