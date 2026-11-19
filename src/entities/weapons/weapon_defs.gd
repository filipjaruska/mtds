extends RefCounted
class_name WeaponDefs
## Registry of every WeaponDef in DEFS_DIR, keyed by id. Ids are what goes over
## the network, so peers never send resource paths or scenes to each other.

const DEFS_DIR := "res://src/entities/weapons/defs/"
const DEFAULT_ID := &"pistol"

static var _by_id: Dictionary = {}

static func get_def(id: StringName) -> WeaponDef:
	_ensure_loaded()
	return _by_id.get(id)

static func has(id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(id)

static func default_def() -> WeaponDef:
	return get_def(DEFAULT_ID)

static func all() -> Array:
	_ensure_loaded()
	return _by_id.values()

static func _ensure_loaded() -> void:
	if not _by_id.is_empty():
		return
	for file in ResourceLoader.list_directory(DEFS_DIR):
		if not file.ends_with(".tres") and not file.ends_with(".res"):
			continue
		var def := load(DEFS_DIR + file) as WeaponDef
		if def == null:
			push_warning("WeaponDefs: %s is not a WeaponDef" % file)
			continue
		if _by_id.has(def.id):
			push_error("WeaponDefs: duplicate weapon id '%s' in %s" % [def.id, file])
			continue
		_by_id[def.id] = def
