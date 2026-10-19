extends RefCounted
## Keep imported PBR detail when an existing teaching shader controls a surface.
const FOLIAGE = preload("res://shaders/ecology_foliage.gdshader")

static func copy_maps(source: StandardMaterial3D, target: ShaderMaterial) -> void:
	target.set_shader_parameter("has_albedo",source.albedo_texture!=null)
	target.set_shader_parameter("has_normal",source.normal_texture!=null)
	if source.albedo_texture!=null: target.set_shader_parameter("albedo_map",source.albedo_texture)
	if source.normal_texture!=null: target.set_shader_parameter("normal_map",source.normal_texture)
	target.set_shader_parameter("normal_strength",minf(source.normal_scale,.24))

static func seasonal(source: StandardMaterial3D, color: Color) -> Material:
	if source.albedo_texture==null and source.normal_texture==null:
		var plain: StandardMaterial3D = source.duplicate() as StandardMaterial3D
		plain.vertex_color_use_as_albedo=false
		plain.albedo_color=color
		return plain
	var surface: ShaderMaterial = ShaderMaterial.new()
	surface.shader=FOLIAGE
	surface.set_shader_parameter("season_color",color)
	copy_maps(source,surface)
	return surface
