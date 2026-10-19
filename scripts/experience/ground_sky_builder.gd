extends RefCounted
## One ground observer and the existing date authority; authored terrain/exposure.
const Geometry = preload("res://scripts/core/ground_sky.gd")
const Orientation = preload("res://scripts/core/celestial_orientation.gd")
const Orbit = preload("res://scripts/core/solar_ephemeris.gd")
const DOME = preload("res://shaders/ground_sky_dome.gdshader")
const STARS = preload("res://shaders/ground_sky_stars.gdshader")
const GROUND = preload("res://shaders/ground_sky_ground.gdshader")
const MOON = preload("res://shaders/moon_surface.gdshader")
const EYE: Vector3 = Vector3(0,1.7,0)
const RADIUS: float = 1200.0
const CATALOG: String = "res://assets/data/ground_sky262/bsc-visible.json"
const NAMES: Dictionary = {2491:"天狼星",2326:"老人星",5459:"南门二",5460:"南门二伴星",5340:"大角星",7001:"织女星",1708:"五车二",1713:"参宿七",2943:"南河三",2061:"参宿四",5267:"马腹一",7557:"河鼓二",472:"水委一",5056:"角宿一",6134:"心宿二",2990:"北河三",8728:"北落师门",7924:"天津四",424:"北极星",4853:"十字架二",4730:"十字架一",1903:"参宿二",1948:"参宿一",1852:"参宿三"}

static func _shader(stage: Node, shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial=ShaderMaterial.new()
	material.shader=shader
	stage.materials.append(material)
	return material

static func _plain(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D=StandardMaterial3D.new()
	material.albedo_color=color; material.roughness=.83
	if glow>0:
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled=true; material.emission=color; material.emission_energy_multiplier=glow
	return material

static func _sphere(radius: float, segments: int = 48, rings: int = 24) -> SphereMesh:
	var mesh: SphereMesh=SphereMesh.new()
	mesh.radius=radius; mesh.height=radius*2.0; mesh.radial_segments=segments; mesh.rings=rings
	return mesh

static func build(stage: Node) -> void:
	stage.camera.near=.05; stage.camera.far=8000; stage.camera.fov=78.0
	stage.default_position=EYE; stage.default_target=EYE+Vector3(-.7,.5,-.5).normalized()*10.0
	stage.target_position=stage.default_target; stage.close_position=EYE
	stage.semantic_size_m=10000.0
	stage.environment.ambient_light_energy=.15
	stage.environment.ambient_light_color=Color(.22,.29,.43)
	stage.environment.glow_enabled=true; stage.environment.glow_intensity=.3; stage.environment.glow_bloom=.03
	stage.environment.tonemap_exposure=1.0
	stage.set_meta("local_unit_m",1.0)
	stage.set_meta("scientific_label","固定J2000明亮星表 · 同日地平坐标\n合成地形与增强曝光；非肉眼亮度或实时天气。")
	var dome_material: ShaderMaterial=_shader(stage,DOME)
	dome_material.render_priority=-128
	if stage.textures.has("galaxy_map"):
		dome_material.set_shader_parameter("galaxy_map",stage.textures.galaxy_map)
		dome_material.set_shader_parameter("use_galaxy_map",true)
	var dome: MeshInstance3D=stage.add_mesh(_sphere(1800,128,64),dome_material,EYE)
	dome.name="TopocentricSky_GalacticCoordinates"
	dome.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var root: Node3D=Node3D.new(); root.name="J2000Catalog_DateRotation"; root.position=EYE; stage.world_root.add_child(root)
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var stars_material: ShaderMaterial=_shader(stage,STARS)
	var batch: MultiMeshInstance3D=MultiMeshInstance3D.new()
	batch.name="BSC5P_8404_Stars"
	var mesh: QuadMesh=QuadMesh.new(); mesh.size=Vector2.ONE
	var mm: MultiMesh=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_colors=true
	mm.mesh=mesh; mm.instance_count=catalog.rows.size()
	var targets: Array[Dictionary]=[]
	for index: int in range(catalog.rows.size()):
		var row: Array=catalog.rows[index]
		var direction: Vector3=Geometry.star_direction(float(row[1]),float(row[2]))
		var size: float=clampf(2.5-float(row[3])*.29,.55,3.2)
		mm.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),direction*RADIUS))
		var color: Color=Color(.73,.84,1.0).lerp(Color(1.0,.70,.43),clampf((float(row[4])+.25)/2.1,0.0,1.0))
		color.a=clampf(pow(10.0,-.18*float(row[3]))*1.35,.22,2.5)
		mm.set_instance_color(index,color)
		if NAMES.has(int(row[0])):
			var anchor: Node3D=Node3D.new(); anchor.name="HR_"+str(int(row[0])); anchor.position=direction*RADIUS; root.add_child(anchor)
			targets.append({"node":anchor,"label":NAMES[int(row[0])],"sky":true,"hr":int(row[0]),"vmag":float(row[3]),"ra":float(row[1]),"dec":float(row[2]),"distance":RADIUS,"role":"固定J2000星位 · 星光增强显示"})
	batch.multimesh=mm; batch.material_override=stars_material; batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(batch)
	var center: Node3D=Node3D.new(); center.name="MilkyWayCenterReference"; center.position=Geometry.local_from_galactic(Orbit.DEFAULT_JD)*Vector3.RIGHT*RADIUS+EYE; stage.world_root.add_child(center)
	targets.append({"node":center,"label":"银河中心方向","sky":true,"galactic":true,"distance":RADIUS,"role":"我们从银河内部看向盘面 · 增强曝光"})
	var moon_material: ShaderMaterial=_shader(stage,MOON)
	moon_material.set_shader_parameter("moon_map",stage.textures.moon)
	var moon: MeshInstance3D=stage.add_mesh(_sphere(1.,64,32),moon_material)
	moon.name="TopocentricMoon_ActualAngularDiameter"
	moon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	targets.append({"node":moon,"label":"月球","sky":true,"body":8,"distance":RADIUS,"role":"同日月位与月相 · 月面沿用IAU姿态"})
	var sun: MeshInstance3D=stage.add_mesh(_sphere(1.0),_plain(Color(1.0,.91,.67),3.0))
	sun.name="TopocentricSun_ActualAngularDiameter"; sun.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	targets.append({"node":sun,"label":"太阳","sky":true,"body":9,"distance":RADIUS,"role":"同日期太阳方向 · 几何地平线"})
	var planets: Dictionary={}
	for index: int in range(8):
		if index==2: continue
		var point_material: ShaderMaterial=_shader(stage,STARS)
		var point: MeshInstance3D=stage.add_mesh(mesh,point_material)
		point.name="TopocentricPlanet_"+str(index)
		point.scale=Vector3.ONE*(3.5 if index in [1,4] else 2.0)
		point_material.set_shader_parameter("night_strength",1.0)
		point.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		planets[index]=point
		targets.append({"node":point,"label":Orbit.NAMES[index],"sky":true,"body":index,"distance":RADIUS,"role":"同日几何行星方向 · 亮度光点增强显示"})
	var light: DirectionalLight3D=DirectionalLight3D.new(); stage.world_root.add_child(light)
	light.name="CommonDateSunAndNightFill"; light.shadow_enabled=false
	stage.set_meta("ground_sky",{"site":Geometry.PARANAL.duplicate(),"root":root,"batch":batch,"catalog_count":catalog.rows.size(),"targets":targets,"moon":moon,"sun":sun,"planets":planets,"center":center,"dome_material":dome_material,"stars_material":stars_material,"light":light,"jd":-1.,"selected":-1,"samples":{},"credit":stage.textures.has("galaxy_map")})
	_terrain(stage)
	update(stage,Orbit.DEFAULT_JD)
	reset_view(stage)

static func _terrain(stage: Node) -> void:
	var surface: SurfaceTool=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const RADII: Array[float]=[0.,12.,45.,180.,550.,1400.,3500.]
	for ring: int in range(RADII.size()-1):
		for segment: int in range(240):
			var a: float=TAU*segment/240.0; var b: float=TAU*(segment+1)/240.0
			var p: Vector3=_terrain_point(RADII[ring],a)
			var q: Vector3=_terrain_point(RADII[ring+1],a)
			var r: Vector3=_terrain_point(RADII[ring+1],b)
			var t: Vector3=_terrain_point(RADII[ring],b)
			for v: Vector3 in [p,r,q,p,t,r]: surface.add_vertex(v)
	surface.generate_normals(); surface.index()
	stage.add_mesh(surface.commit(),_shader(stage,GROUND)).name="AuthoredAtacamaRidges_NotSurveyTerrain"
	var platform: CylinderMesh=CylinderMesh.new(); platform.top_radius=6.5; platform.bottom_radius=6.6; platform.height=.13; platform.radial_segments=96
	stage.add_mesh(platform,_plain(Color(.17,.18,.19)),Vector3(0,.045,0)).name="StoneObservationPlatform"
	for index: int in range(4):
		var label: Label3D=Label3D.new(); label.text=["北 N","东 E","南 S","西 W"][index]
		label.font_size=32; label.pixel_size=.018; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate=Color(.35,.43,.48); label.no_depth_test=false
		label.position=Vector3(sin(TAU*index/4.0)*18.,.45,-cos(TAU*index/4.0)*18.)
		stage.world_root.add_child(label)
	var metal: StandardMaterial3D=_plain(Color(.045,.055,.075)); metal.metallic=.7; metal.roughness=.35
	var telescope: Vector3=Vector3(-4.3,0,-3.6)
	for index: int in range(3):
		var angle: float=TAU*index/3.0
		_cylinder(stage,telescope+Vector3(sin(angle)*.6,.14,cos(angle)*.6),telescope+Vector3(0,1.1,0),.025,metal)
	_cylinder(stage,telescope+Vector3(0,1.1,0),telescope+Vector3(0,1.8,0),.07,metal)
	_cylinder(stage,telescope+Vector3(-.22,1.45,-.25),telescope+Vector3(.22,1.95,.25),.14,metal)

static func _terrain_point(radius: float, angle: float) -> Vector3:
	var rise: float=smoothstep(40.,1600.,radius)*(.48+.23*sin(angle*3.0+.9)+.16*sin(angle*7.0)+.09*sin(angle*19.0))
	var height: float=rise*(32.0+radius*.046)-.04
	return Vector3(sin(angle)*radius,height,-cos(angle)*radius)

static func _cylinder(stage: Node, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh: CylinderMesh=CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=a.distance_to(b); mesh.radial_segments=16
	var node: MeshInstance3D=stage.add_mesh(mesh,material,(a+b)*.5)
	var axis: Vector3=(b-a).normalized(); var side: Vector3=axis.cross(Vector3.BACK).normalized()
	if side.length_squared()<.1: side=Vector3.RIGHT
	node.basis=Basis(side,axis,side.cross(axis))

static func update(stage: Node, jd: float) -> void:
	if not stage.has_meta("ground_sky"): return
	var data: Dictionary=stage.get_meta("ground_sky")
	if absf(float(data.jd)-jd)<1.0e-10: return
	data.jd=jd
	var local: Basis=Geometry.inertial_to_local(jd,data.site)
	data.root.basis=local
	data.center.position=Geometry.local_from_galactic(jd,data.site)*Vector3.RIGHT*RADIUS+EYE
	var sun: Dictionary=Geometry.body(jd,9,data.site)
	var moon: Dictionary=Geometry.body(jd,8,data.site)
	var night: float=1.0-smoothstep(-18.,-2.,float(sun.altitude))
	var moon_light: float=Orientation.illumination(jd)*smoothstep(0.0,.4,float(moon.direction.y))
	data.dome_material.set_shader_parameter("galactic_from_local",Geometry.local_from_galactic(jd,data.site).transposed())
	data.dome_material.set_shader_parameter("sun_direction",sun.direction)
	data.dome_material.set_shader_parameter("moon_direction",moon.direction)
	data.dome_material.set_shader_parameter("moon_light",moon_light)
	data.dome_material.set_shader_parameter("night_strength",night)
	data.stars_material.set_shader_parameter("night_strength",night*(1.0-.45*moon_light))
	data.sun.position=EYE+sun.direction*RADIUS
	data.sun.scale=Vector3.ONE*(RADIUS*tan(float(sun.angular_radius)))
	data.sun.visible=float(sun.altitude)>-.4
	data.moon.position=EYE+moon.direction*RADIUS
	data.moon.basis=local*Orientation.moon_basis(jd)
	data.moon.scale=Vector3.ONE*(RADIUS*tan(float(moon.angular_radius)))
	data.moon.visible=float(moon.altitude)>-.3
	var material: ShaderMaterial=data.moon.material_override
	material.set_shader_parameter("planet_center",data.moon.position)
	material.set_shader_parameter("sun_direction",local*Orientation.sun_direction(jd))
	data.samples={8:moon,9:sun}
	for index: int in data.planets:
		var sample: Dictionary=Geometry.body(jd,index,data.site)
		data.samples[index]=sample
		data.planets[index].position=EYE+sample.direction*RADIUS
		data.planets[index].visible=sample.altitude>1.5 and night>.08
		data.planets[index].material_override.set_shader_parameter("night_strength",night)
	data.light.light_color=Color(.37,.47,.72).lerp(Color(1.0,.91,.79),1.0-night)
	data.light.light_energy=lerpf(.18+moon_light*.08,2.0,1.0-night)
	var light_direction: Vector3=Vector3(-.4,.55,-.7) if night>.9 else Vector3(sun.direction)
	data.light.look_at(-light_direction,Vector3.UP)
	stage.environment.ambient_light_energy=lerpf(.17,.42,1.0-night)
	stage.set_meta("sun_elevation",float(sun.altitude))
	stage.set_meta("night_strength",night)

static func targets(stage: Node) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	result.assign(stage.get_meta("ground_sky").targets)
	return result

static func reset_view(stage: Node) -> void:
	var center: Vector3=stage.get_meta("ground_sky").center.position-EYE
	var direction: Vector3=center.normalized()
	if direction.y<.1: direction=Vector3(-.6,.47,-.6).normalized()
	else:
		var pitch: float=clampf(asin(clampf(direction.y,-1.,1.))*.42,.20,.46)
		direction=Vector3(direction.x,0,direction.z).normalized()*cos(pitch)+Vector3.UP*sin(pitch)
	stage.camera.fov=78.0; stage.default_target=EYE+direction*10.0
	stage.set_pose(EYE,stage.default_target)

static func focus(stage: Node, index: int) -> void:
	var data: Dictionary=stage.get_meta("ground_sky")
	if index<0 or index>=data.targets.size(): return
	var item: Dictionary=data.targets[index]
	stage.camera.fov=2.4 if int(item.get("body",-1))==8 else 18.0 if not item.get("galactic",false) else 78.0
	stage.set_pose(EYE,item.node.global_position)

static func rotate_view(stage: Node, relative: Vector2) -> void:
	var direction: Vector3=-stage.camera.basis.z
	var yaw: float=atan2(direction.x,-direction.z)-relative.x*.004
	var pitch: float=clampf(asin(clampf(direction.y,-1.,1.))+relative.y*.0035,-.08,1.5)
	stage.set_pose(EYE,EYE+Vector3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))*10.0)

static func pick(stage: Node, point: Vector2) -> Dictionary:
	var camera: Camera3D=stage.camera
	var ray: Vector3=camera.project_ray_normal(point)
	var best: float=0.0; var choice: Dictionary={}
	var threshold: float=cos(deg_to_rad(camera.fov)*12.0/maxf(float(stage.viewport.size.y),1.))
	var data: Dictionary=stage.get_meta("ground_sky")
	for index: int in range(data.targets.size()):
		var item: Dictionary=data.targets[index]
		var direction: Vector3=(item.node.global_position-EYE).normalized()
		if direction.y<.025 or camera.is_position_behind(item.node.global_position): continue
		if item.node is MeshInstance3D and not item.node.visible: continue
		if not item.has("body") and float(stage.get_meta("night_strength",0.0))<.08: continue
		var score: float=ray.dot(direction)
		if score>threshold and score>best:
			choice=item.duplicate(); choice.index=index; best=score
	return choice

static func animate(_stage: Node, _time: float) -> void:
	pass # Catalog orientation is updated only from the common date.

static func update_camera(stage: Node) -> void:
	if stage.has_meta("ground_sky"):
		stage.get_meta("ground_sky").dome_material.set_shader_parameter("view_exposure",smoothstep(6.,45.,stage.camera.fov))
