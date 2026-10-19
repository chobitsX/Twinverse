extends RefCounted
const Sites = preload("res://scripts/data/earth_sites.gd")
const RADIUS: float = 3.0

static func build(stage: Node) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(.30,.94,.87)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = .028
	sphere.height = .056
	sphere.radial_segments = 16
	sphere.rings = 8
	var normal: Vector3 = Sites.normal(Sites.REEF_LAT,Sites.REEF_LON)
	var marker: MeshInstance3D = stage.add_mesh(sphere,material,normal*3.07)
	marker.name = "LizardRegionalMarker"
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label: Label3D = _label(stage,"蜥蜴岛 · 海洋区域",Color(.64,1.0,.92))
	label.position = normal*3.13+Vector3.UP*.08
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for index: int in range(181): mesh.surface_add_vertex(Sites.normal(35.0,index*2.0)*(RADIUS+.045))
	mesh.surface_end()
	var band_material: StandardMaterial3D = material.duplicate()
	band_material.albedo_color = Color(1.0,.76,.35)
	var band: MeshInstance3D = stage.add_mesh(mesh,band_material)
	band.name = "TeachingLatitude35N"
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var band_label: Label3D = _label(stage,"35°N · 教学参考纬度",Color(1.0,.83,.53))
	stage.set_meta("earth_locator",{"marker":marker,"region_label":label,"band":band,"band_label":band_label,"selection":"reef","latitude":35.0})
	update(stage)

static func _label(stage: Node, text: String, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC","SF Pro Display","Arial"])
	label.font = font
	label.font_size = 40
	label.outline_size = 8
	label.pixel_size = .0025
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	stage.world_root.add_child(label)
	return label

static func update(stage: Node) -> void:
	if not stage.has_meta("earth_locator"): return
	var data: Dictionary = stage.get_meta("earth_locator")
	if stage.get_meta("earth_daylight",{}).get("active",false) or stage.get_meta("spatial_entry_active",false):
		for node: Node3D in [data.marker,data.region_label,data.band,data.band_label]: node.hide()
		return
	var site: Dictionary = Sites.for_scale(str(data.selection))
	var regional: bool = site.kind=="regional"
	if not regional and not is_equal_approx(float(data.latitude),float(site.lat)):
		var mesh: ImmediateMesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for index: int in range(181): mesh.surface_add_vertex(Sites.normal(float(site.lat),index*2.0)*(RADIUS+.045))
		mesh.surface_end()
		data.band.mesh=mesh
		data.latitude=float(site.lat)
	data.band_label.text="%s · 教学参考纬度" % Sites.latitude_label(float(data.latitude))
	data.marker.visible = regional
	data.region_label.visible = regional and front_facing(data.marker.position,stage.camera.position)
	data.band.visible = not regional
	var longitude: float = rad_to_deg(atan2(stage.camera.position.x,stage.camera.position.z))
	data.band_label.position = Sites.normal(float(data.latitude),longitude)*3.15+Vector3.UP*.10
	data.band_label.visible = not regional and front_facing(data.band_label.position,stage.camera.position)

static func front_facing(point: Vector3, camera: Vector3) -> bool:
	return point.normalized().dot(camera-point)>0.0

static func focus(stage: Node, id: String) -> void:
	var site: Dictionary = Sites.for_scale(id)
	if site.is_empty() or not stage.has_meta("earth_locator"): return
	stage.get_meta("earth_locator").selection = id
	var direction: Vector3 = Sites.normal(site.lat,site.lon) if site.kind=="regional" else Sites.normal(float(site.lat)-5.0,rad_to_deg(atan2(stage.camera.position.x,stage.camera.position.z)))
	if stage.has_meta("earth_entry_markers"): direction=Sites.normal(float(site.lat),float(site.lon))
	stage.set_pose(direction*9.6,Vector3.ZERO)
	update(stage)
