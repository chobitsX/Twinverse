extends "res://tests/integration/world_expansion_suite.gd"

const Pollinators = preload("res://scripts/experience/pollinator_observation.gd")
const Reference = preload("res://scripts/experience/science_reference.gd")

## Bounded city observation of one planted strip, using the existing 104 assets.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world195-review="):
			directory = argument.trim_prefix("--world195-review=")
	if not directory.is_absolute_path() or not "--no-save" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	main = Experience.instantiate()
	add_child(main)
	if DisplayServer.get_name() != "headless":
		# A one-screen diagnostic can lose keyboard focus even while its window
		# draws. Use the same unfocusable 5-FPS observation mode as a side screen.
		main._measurement_screen = get_window().current_screen
		get_window().unfocusable = true
	if not await ready_stage():
		print("CITY195_WINDOW ",JSON.stringify({"can_draw":DisplayServer.window_can_draw(),"focus":get_window().has_focus(),"foreground":main.world.foreground,"screen":get_window().current_screen}))
		await finish()
		return
	main._reduced_motion = true
	main.world.set_paused(true)
	main.world_guide.hide()
	main.explorer_panel.hide()
	if not await arrive("city"):
		await finish()
		return
	var stage: Node = main.coordinator.active_scene
	var plants: Array = stage.get_meta("milkweed_plants",[])
	var butterflies: Array = stage.get_meta("pollinators",[])
	check("original city people traffic trees and sparrows remain",stage.get_meta("actors",[]).size()==40 and stage.get_meta("city_sparrows",[]).size()==4 and stage.get_meta("city_ginkgos",[]).size()==2 and stage.get_meta("city_park_trees",{}).size()==7)
	check("bounded four-plant and two-butterfly display is in the real park",plants.size()==4 and butterflies.size()==2 and stage.get_meta("city_pollinator_bed",Vector3.ZERO)==Pollinators.CITY_BED_CENTER)
	if plants.size()!=4 or butterflies.size()!=2:
		await finish()
		return
	var plant: Node3D = plants[0]
	var butterfly: Node3D = butterflies[0].node
	check("original imported flower leaf and wing meshes are reused",plant.find_child("MilkweedFlowers",true,false)!=null and plant.find_child("MilkweedOppositeLeaves",true,false)!=null and butterfly.find_child("ForeWingSurfaceL",true,false)!=null)
	check("new patch clears paved walks and teaching platforms",not Pollinators.city_reserved(17.0,22.4) and not Pollinators.city_reserved(33.0,22.4) and not Pollinators.city_reserved(25.0,17.0) and not Pollinators.city_reserved(22.0,43.0))
	var targets: Array[Dictionary] = main.content_targets()
	check("existing city topic indices survive two appended choices",targets.size()==18 and targets[8].node==stage.get_meta("city_ginkgos")[0] and targets[10].node==stage.get_meta("city_park_tree_targets")[0].node and targets[16].node==butterfly and targets[17].node==plant)
	await capture("city-garden-overview")
	var panel: Node = main.explorer_panel
	panel.show()
	panel._process(0.0)
	check("milkweed lesson selects its actual planted individual",panel.select_topic("city_milkweed") and main._content_follow==17 and main.learning_overlay.topic=="city_milkweed")
	await capture("city-garden-milkweed")
	check("butterfly lesson selects the adult and flower pair",panel.select_topic("city_monarch") and main._content_follow==16 and main.learning_overlay.topic=="city_monarch")
	await at_time(3.0)
	check("adult mouth reaches existing flower anchor",float(butterfly.get_meta("flower_distance_m",INF))<.0001 and butterflies[0].joints.ProboscisExtended.visible)
	await capture("city-garden-monarch-visit")
	var visit_at: Vector3 = butterfly.position
	await at_time(22.0)
	check("same world clock moves the adult without new state",butterfly.position.distance_to(visit_at)>.05 and main.world.paused and main.world.simulation_time_s==22.0)
	await capture("city-garden-monarch-flight")
	var guide_monarch: bool = false
	var guide_milkweed: bool = false
	for button: Button in main.world_guide.route_buttons:
		guide_monarch = guide_monarch or button.get_meta("guide_topic","")=="city_monarch"
		guide_milkweed = guide_milkweed or button.get_meta("guide_topic","")=="city_milkweed"
	check("two guide entries and primary science links resolve",guide_monarch and guide_milkweed and Reference.allows_url("city",Pollinators.URBAN_GARDEN_SOURCE) and Reference.allows_url("city",Pollinators.SOURCE) and Reference.allows_url("city",Pollinators.PLANT_SOURCE))
	if not await arrive("woodland"):
		await finish()
		return
	var woodland: Node = main.coordinator.active_scene
	var original_actors: Array = woodland.get_meta("pollinators",[])
	check("original woodland four adults and six milkweeds survive shared code",original_actors.size()==4 and woodland.get_meta("milkweed_plants",[]).size()==6 and original_actors[0].node.get_meta("stable_id","")=="3dworld:teaching:monarch:0000")
	check("woodland returns on the same authoritative time",main.world.paused and main.world.simulation_time_s==22.0)
	await finish()

func at_time(seconds: float) -> void:
	main.world.simulation_time_s = seconds
	for frame: int in range(3): await get_tree().process_frame
