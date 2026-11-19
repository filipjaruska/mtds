extends RefCounted
class_name PowerupDefs
## Registry of every PowerupDef in DEFS_DIR, keyed by id. Ids are what goes over
## the network and what poker mode features.

const DEFS_DIR := "res://src/entities/powerups/defs/"

static var _by_id: Dictionary = {}
static var _ids: Array[StringName] = []

static func get_def(id: StringName) -> PowerupDef:
	_ensure_loaded()
	return _by_id.get(id)

static func has(id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(id)

## All ids in a stable (alphabetical) order, identical on every peer.
static func ids() -> Array[StringName]:
	_ensure_loaded()
	return _ids

static func random_id() -> StringName:
	return ids().pick_random()

static func _ensure_loaded() -> void:
	if not _by_id.is_empty():
		return
	for file in ResourceLoader.list_directory(DEFS_DIR):
		if not file.ends_with(".tres") and not file.ends_with(".res"):
			continue
		var def := load(DEFS_DIR + file) as PowerupDef
		if def == null:
			push_warning("PowerupDefs: %s is not a PowerupDef" % file)
			continue
		if _by_id.has(def.id):
			push_error("PowerupDefs: duplicate powerup id '%s' in %s" % [def.id, file])
			continue
		_by_id[def.id] = def
	_ids.assign(_by_id.keys())
	_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
