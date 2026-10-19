extends RefCounted
## Shared visual language for the actual application controls.
const INK: Color = Color(.055, .067, .084, .97)
const TEXT: Color = Color(.91, .93, .95)
const MUTED: Color = Color(.60, .66, .72)
const ACCENT: Color = Color(.59, .77, .81)
const BODY_SIZE: int = 18
const SECONDARY_SIZE: int = 16
const CONTROL_HEIGHT: float = 44.0
const HEADER_HEIGHT: float = 76.0

static func readable_size(requested: int) -> int:
	if requested <= 14: return SECONDARY_SIZE
	if requested <= 18: return BODY_SIZE
	if requested <= 22: return 24
	return requested

static func fit_fonts(theme: Theme, display_scale: float) -> void:
	# Rasterize at the display density instead of enlarging a 1x glyph bitmap.
	for font: Font in [theme.default_font,theme.get_font("font","Heading")]:
		if font is SystemFont: font.oversampling = display_scale
		for fallback: Font in font.fallbacks:
			if fallback is SystemFont: fallback.oversampling = display_scale

static func _short_number(value: float) -> String:
	var text: String=String.num(value,3)
	return text.rstrip("0").trim_suffix(".") if text.contains(".") else text

static func astronomy_rate(days_per_second: float) -> String:
	if is_zero_approx(days_per_second): return "日期保持"
	if days_per_second < 1.0/24.0: return "每世界秒 %s 分钟" % _short_number(days_per_second*1440.0)
	if days_per_second < 1.0: return "每世界秒 %s 小时" % _short_number(days_per_second*24.0)
	return "每世界秒 %s 天" % _short_number(days_per_second)

static func fit_popups(root: Node, display_scale: float) -> void:
	# Popups are separate Windows and do not inherit their Control parent's scale.
	if root is MenuButton or root is OptionButton:
		var popup: PopupMenu = root.get_popup()
		popup.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		popup.content_scale_factor = display_scale
	for child: Node in root.get_children(): fit_popups(child,display_scale)

class IconButton extends Button:
	var symbol: String = "menu"
	var caption: String = ""
	func _draw() -> void:
		var c: Vector2 = Vector2(22,size.y*.5) if not caption.is_empty() else size * .5
		var color: Color = Color(.91,.93,.95,.35 if disabled else .95)
		var width: float = 1.6
		match symbol:
			"search":
				draw_arc(c-Vector2(2,2),6,0,TAU,24,color,width,true)
				draw_line(c+Vector2(2,2),c+Vector2(8,8),color,width,true)
			"book":
				for side: float in [-1.0,1.0]:
					draw_polyline(PackedVector2Array([c+Vector2(0,-6),c+Vector2(side*8,-8),c+Vector2(side*8,7),c+Vector2(0,9),c+Vector2(0,-6)]),color,width,true)
			"back":
				draw_polyline(PackedVector2Array([c+Vector2(3,-7),c+Vector2(-4,0),c+Vector2(3,7)]),color,width,true)
			"return":
				draw_arc(c+Vector2(1,1),7,-PI*.9,PI*.65,20,color,width,true)
				draw_polyline(PackedVector2Array([c+Vector2(-7,-7),c+Vector2(-7,0),c+Vector2(0,0)]),color,width,true)
			"close":
				draw_line(c-Vector2(5,5),c+Vector2(5,5),color,width,true)
				draw_line(c+Vector2(-5,5),c+Vector2(5,-5),color,width,true)
			"pause":
				draw_line(c+Vector2(-3,-6),c+Vector2(-3,6),color,2.3,true)
				draw_line(c+Vector2(3,-6),c+Vector2(3,6),color,2.3,true)
			"play":
				draw_colored_polygon(PackedVector2Array([c+Vector2(-4,-7),c+Vector2(7,0),c+Vector2(-4,7)]),color)
			"info":
				draw_arc(c,8,0,TAU,28,color,1.2,true)
				draw_line(c+Vector2(0,-1),c+Vector2(0,5),color,width,true)
				draw_circle(c+Vector2(0,-5),1,color)
			_:
				for x: float in [-6.0,0.0,6.0]: draw_circle(c+Vector2(x,0),1.5,color)
		if not caption.is_empty():
			var font: Font = get_theme_default_font()
			draw_string(font,Vector2(42,(size.y+font.get_ascent(17)-font.get_descent(17))*.5),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,17,color)

static func icon(symbol: String, hint: String, action: Callable) -> Button:
	var button: IconButton = IconButton.new()
	button.symbol = symbol
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(CONTROL_HEIGHT,CONTROL_HEIGHT)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	# Legacy callers can still assign accessible button text; icons own rendering.
	button.add_theme_color_override("font_color",Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color",Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color",Color.TRANSPARENT)
	button.add_theme_color_override("font_focus_color",Color.TRANSPARENT)
	button.add_theme_color_override("font_disabled_color",Color.TRANSPARENT)
	button.add_theme_font_size_override("font_size",1)
	return button

static func surface(color: Color = INK, padding: float = 22.0, radius: int = 12) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(.76,.83,.90,.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.shadow_color = Color(0,0,0,.14)
	style.shadow_size = 8
	return style

static func flat_button(button: Button) -> void:
	var normal: StyleBoxEmpty = StyleBoxEmpty.new()
	normal.set_content_margin_all(7)
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("disabled",normal)
	button.add_theme_stylebox_override("focus",normal)

static func build(display_scale: float = 1.0) -> Theme:
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC","SF Pro Text","Arial"])
	font.oversampling = display_scale
	# macOS can resolve the PingFang collection to its HK face; cover SC glyphs
	# explicitly without copying Apple's system fonts into product assets.
	var chinese_fallback: SystemFont=SystemFont.new()
	chinese_fallback.font_names=PackedStringArray(["Heiti SC","Arial Unicode MS"])
	chinese_fallback.oversampling=display_scale
	font.fallbacks=[chinese_fallback]
	theme.default_font = font
	theme.default_font_size = BODY_SIZE
	var heading: SystemFont = font.duplicate() as SystemFont
	heading.font_weight=600
	theme.set_type_variation("Heading","Label")
	theme.set_font("font","Heading",heading)
	var normal: StyleBoxFlat = surface(Color(.16,.19,.23,.52),11,9)
	normal.content_margin_left = 12; normal.content_margin_right = 12
	normal.shadow_size = 0; normal.set_border_width_all(0)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(.26,.31,.36,.76)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(.25,.35,.40,.9)
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(.15,.18,.22,.22)
	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color.TRANSPARENT; focus.border_color = ACCENT; focus.set_border_width_all(1)
	for type: String in ["Button","OptionButton","CheckButton","CheckBox"]:
		theme.set_stylebox("normal",type,normal)
		theme.set_stylebox("hover",type,hover)
		theme.set_stylebox("pressed",type,pressed)
		theme.set_stylebox("disabled",type,disabled)
		theme.set_stylebox("focus",type,focus)
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: theme.set_color(state,type,TEXT)
		theme.set_color("font_disabled_color",type,Color(.49,.54,.59))
	theme.set_color("font_color","Label",TEXT)
	theme.set_color("default_color","RichTextLabel",TEXT)
	theme.set_color("font_color","LinkButton",ACCENT)
	theme.set_stylebox("panel","PanelContainer",surface())
	theme.set_stylebox("panel","PopupMenu",surface(INK,10,10))
	theme.set_stylebox("hover","PopupMenu",hover)
	theme.set_color("font_color","PopupMenu",TEXT)
	theme.set_constant("v_separation","PopupMenu",12)
	theme.set_font_size("font_size","PopupMenu",BODY_SIZE)
	for key: String in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"]: theme.set_font_size(key,"RichTextLabel",BODY_SIZE)
	theme.set_constant("line_spacing","RichTextLabel",5)
	theme.set_constant("line_spacing","Label",3)
	theme.set_stylebox("normal","LineEdit",surface(Color(.10,.12,.15,.95),10,7))
	theme.set_stylebox("focus","LineEdit",focus)
	theme.set_color("font_color","LineEdit",TEXT)
	theme.set_color("font_placeholder_color","LineEdit",MUTED)
	theme.set_color("caret_color","LineEdit",ACCENT)
	theme.set_stylebox("panel","TabContainer",surface(Color(.04,.05,.065,.45),8,6))
	for type: String in ["TabContainer","TabBar"]:
		theme.set_stylebox("tab_selected",type,pressed)
		theme.set_stylebox("tab_unselected",type,normal)
		theme.set_color("font_selected_color",type,TEXT)
		theme.set_color("font_unselected_color",type,MUTED)
	var track: StyleBoxFlat = surface(Color(.20,.24,.29,.6),0,3)
	track.set_border_width_all(0); track.shadow_size = 0
	var fill: StyleBoxFlat = track.duplicate() as StyleBoxFlat
	fill.bg_color = ACCENT
	theme.set_stylebox("background","ProgressBar",track)
	theme.set_stylebox("fill","ProgressBar",fill)
	var slider_track: StyleBoxFlat = track.duplicate() as StyleBoxFlat
	slider_track.content_margin_top = 2; slider_track.content_margin_bottom = 2
	var slider_fill: StyleBoxFlat = slider_track.duplicate() as StyleBoxFlat
	slider_fill.bg_color = ACCENT
	theme.set_stylebox("slider","HSlider",slider_track)
	theme.set_stylebox("grabber_area","HSlider",slider_fill)
	theme.set_stylebox("grabber_area_highlight","HSlider",slider_fill)
	for type: String in ["VScrollBar","HScrollBar"]:
		var scroll_track: StyleBoxFlat = track.duplicate() as StyleBoxFlat
		if type=="VScrollBar": scroll_track.content_margin_left = 2; scroll_track.content_margin_right = 2
		else: scroll_track.content_margin_top = 2; scroll_track.content_margin_bottom = 2
		var scroll_fill: StyleBoxFlat = scroll_track.duplicate() as StyleBoxFlat
		scroll_fill.bg_color = ACCENT
		theme.set_stylebox("scroll",type,StyleBoxEmpty.new())
		theme.set_stylebox("grabber",type,scroll_track)
		theme.set_stylebox("grabber_highlight",type,scroll_fill)
	theme.set_stylebox("panel","TooltipPanel",surface(INK,9,6))
	theme.set_color("font_color","TooltipLabel",TEXT)
	return theme
