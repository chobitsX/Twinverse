extends RefCounted
const I18n = preload("res://scripts/core/app_text.gd")
## Resolution is presentation only: never change simulation, assets or UI pixels.
const ECONOMY: float = 0.5
const BALANCED: float = 0.75
const CLEAR: float = 1.0
const BALANCED_PIXELS: float = 1920.0 * 1200.0
const ECONOMY_PIXELS: float = 1280.0 * 800.0

static func effective_scale(size: Vector2i, requested: float) -> float:
	if requested >= CLEAR: return CLEAR
	var budget: float = ECONOMY_PIXELS if requested <= ECONOMY else BALANCED_PIXELS
	return clampf(minf(requested, sqrt(budget / maxf(1.0, float(size.x) * size.y))), 0.1, 1.0)

static func label(requested: float) -> String:
	return I18n.text("清晰") if requested >= CLEAR else I18n.text("节能") if requested <= ECONOMY else I18n.text("流畅")

static func apply(viewport: Viewport, size: Vector2i, requested: float) -> void:
	viewport.scaling_3d_scale = effective_scale(size, requested)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if requested <= ECONOMY else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.fsr_sharpness = 0.5
