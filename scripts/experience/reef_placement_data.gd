extends Resource
## Authored, immutable placement data. No world state, nodes, meshes or timers.
@export var layout_version: String = ""
@export var layout: Array[Dictionary] = []
@export var rubble_by_patch: Array[Dictionary] = []
@export var asset_paths: Dictionary = {}
@export var source_sha256: Dictionary = {}
