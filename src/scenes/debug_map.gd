extends "res://src/scenes/scene_manager.gd"
## The dev sandbox (debug.tscn, listed only in debug builds). On top of the
## normal map behaviour it builds two rows of stations from the data, so every
## weapon and every card is always there to grab, including ones added later:
##   Armory  one WeaponSpawner per WeaponDef, respawning quickly
##   Cards   one PowerupSpawner per PowerupDef, restocked as soon as it's taken
## Stations are built in the same order on every peer, so their names (and the
## RPC paths of their pickups) match everywhere.
## Shady Fella is always around (an event in debug.tscn due every second, one
## at a time): when he runs off or leaves, the next one turns up right away.

const WEAPON_SPAWNER := preload("res://src/entities/weapons/weapon_spawner.tscn")
const POWERUP_SPAWNER := preload("res://src/entities/powerups/powerup_spawner.tscn")
const STATION_GAP := 128.0
const WEAPON_RESPAWN := 1.5
const CARD_RESTOCK := 1.5

## Centre of each row (set in debug.tscn).
@export var armory_center := Vector2(0, -300)
@export var cards_center := Vector2(0, 300)

func _ready() -> void:
	_build_armory()
	_build_card_bar()
	super._ready()
	print("[dev] debug map: %d players, %d weapons, %d cards" % [
		get_tree().get_nodes_in_group("Player").size(), WeaponDefs.all().size(), PowerupDefs.ids().size()])

func _build_armory() -> void:
	var row := Node2D.new()
	row.name = "Armory"
	add_child(row)
	var defs := WeaponDefs.all()
	defs.sort_custom(func(a, b): return String(a.id) < String(b.id))
	for i in range(defs.size()):
		var spawner = WEAPON_SPAWNER.instantiate()
		spawner.name = String(defs[i].id)
		spawner.position = _slot(armory_center, i, defs.size())
		spawner.weapon_def = defs[i]
		spawner.respawn_time = WEAPON_RESPAWN
		row.add_child(spawner)
		_label(row, defs[i].get_display_name(), spawner.position)

func _build_card_bar() -> void:
	var row := Node2D.new()
	row.name = "Cards"
	add_child(row)
	var ids := PowerupDefs.ids()
	ids.sort()
	for i in range(ids.size()):
		var def := PowerupDefs.get_def(ids[i])
		var spawner = POWERUP_SPAWNER.instantiate()
		spawner.name = String(ids[i])
		spawner.position = _slot(cards_center, i, ids.size())
		spawner.powerup_def = def
		spawner.spawn_frequency = CARD_RESTOCK
		spawner.max_powerups = 1
		spawner.use_spawn_area = false
		row.add_child(spawner)
		_label(row, def.get_display_name(), spawner.position)

func _slot(center: Vector2, index: int, count: int) -> Vector2:
	return center + Vector2((index - (count - 1) / 2.0) * STATION_GAP, 0)

func _label(parent: Node, text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPalette.world_text(label, UiPalette.S, UiPalette.TEXT_DIM)
	label.size = Vector2(STATION_GAP, 20)
	label.position = at + Vector2(-STATION_GAP / 2.0, 46)
	label.z_index = -1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
