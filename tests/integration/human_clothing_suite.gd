extends "res://tests/integration/human_walk_suite.gd"
## Reuse the real city route and captures with the new production characters.
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world129-check="): directory=argument.trim_prefix("--world129-check=")
	await super.run()

func finish() -> void:
	if is_instance_valid(main) and not main.coordinator.is_busy() and main.world.current_scale_id=="city":
		var actors: Array = main.coordinator.active_scene.get_meta("actors",[])
		for index: int in range(mini(2,actors.size())):
			var person: Node3D = actors[index].node
			var shirt: MeshInstance3D = person.find_child("ContinuousShirt",true,false) as MeshInstance3D
			check("variant %d uses connected skinned shirt" % index,shirt!=null and shirt.skin!=null and person.find_child("Sleeve",true,false)==null)
			if shirt==null: continue
			var blended: int = 0
			var valid: bool = true
			for surface: int in range(shirt.mesh.get_surface_count()):
				var arrays: Array = shirt.mesh.surface_get_arrays(surface)
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				for offset: int in range(0,weights.size(),4):
					var sum: float = 0.
					var influences: int = 0
					for slot: int in range(4):
						sum+=weights[offset+slot]
						if weights[offset+slot]>.001: influences+=1
					valid=valid and absf(sum-1.)<.0001
					if influences==2: blended+=1
			check("variant %d retains normalized blended shoulders in imported mesh" % index,valid and blended>100)
			check("variant %d retains neckline hem and original skeleton" % index,person.find_child("NecklineBinding",true,false)!=null and person.find_child("ShirtHem",true,false)!=null and person.get_meta("human_skin").skeleton.get_bone_count()==15)
	await super.finish()
