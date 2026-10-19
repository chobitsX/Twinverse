extends RefCounted
## Species pigment corrections keep the source PBR texture and the host motion.
const SURFACE=preload("res://shaders/ecology_source_surface.gdshader")
static func prepare_mesh(mesh: MeshInstance3D) -> void:
	var kind: int=0
	if str(mesh.name).begins_with("merriams_kangaroo_rat_referenceBody"):kind=1
	elif str(mesh.name).begins_with("mallard_henBody"):kind=2
	elif str(mesh.name).begins_with("brown_tangBody"):kind=3
	if kind==0:return
	for slot: int in range(mesh.mesh.get_surface_count()):
		var source: StandardMaterial3D=mesh.mesh.surface_get_material(slot) as StandardMaterial3D
		if source==null or source.albedo_texture==null:return
		var material: ShaderMaterial=ShaderMaterial.new()
		material.shader=SURFACE
		material.set_shader_parameter("species",kind)
		material.set_shader_parameter("albedo_map",source.albedo_texture)
		material.set_shader_parameter("has_normal",source.normal_texture!=null)
		if source.normal_texture!=null:material.set_shader_parameter("normal_map",source.normal_texture)
		mesh.set_surface_override_material(slot,material)
