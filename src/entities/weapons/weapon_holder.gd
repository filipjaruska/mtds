extends Node2D
class_name WeaponHolder
## Imperative shell around the pure LoadoutRules / WeaponRules.
##
## On the owning peer it reads input, asks the rules for the next loadout and
## turns the result into side effects (views, shots, events, network sync).
## Other peers only mirror the loadout they receive and play effects.
## No gameplay decisions are made here; they live in the rules.

const SWITCH_COOLDOWN_MSEC := 300
const DROP_COOLDOWN_MSEC := 1000
const DUAL_WIELD_VERTICAL_SPACING := 18.0

@onready var player: Node2D = $"../.."
@onready var player_controller: Node2D = get_parent()
@onready var powerup_manager: PowerupManager = player.get_node_or_null("PowerupManager")
@onready var health: HealthComponent = player.get_node_or_null("HealthComponent")

## The single source of truth for this player's weapons (see LoadoutRules).
var loadout: Dictionary = LoadoutRules.empty()

var _views: Array[WeaponView] = []
var _view_defs: Array[StringName] = []
var _offhand_view: WeaponView = null
var _offhand_view_def: StringName = &""
var _rng := RandomNumberGenerator.new()
var _next_switch_at: int = 0
var _next_drop_at: int = 0

func _ready() -> void:
	_rng.randomize()
	if powerup_manager:
		powerup_manager.active_changed.connect(_on_powerups_changed)
	# Authority is assigned before the player enters the tree; wait one frame so
	# every peer has spawned its copy of this player before syncing.
	call_deferred("_initialize")

func _initialize() -> void:
	if is_multiplayer_authority():
		_commit(LoadoutRules.with_weapon(WeaponDefs.default_def()), true)
	else:
		_request_sync.rpc_id(get_multiplayer_authority())

# --- Owner loop -------------------------------------------------------------

func _process(_delta: float) -> void:
	if not is_multiplayer_authority() or (health and health.is_dead):
		return
	var now := Time.get_ticks_msec()
	_handle_inventory_input(now)
	_tick_hands(now)
	_handle_fire_input(now)
	if LoadoutRules.dual_magazines_empty(loadout) and not LoadoutRules.any_bursting(loadout):
		_end_dual_wield()

func _handle_inventory_input(now: int) -> void:
	if LoadoutRules.is_dual(loadout):
		return
	if InputManager.is_weapon_switch_pressed() and now >= _next_switch_at:
		_next_switch_at = now + SWITCH_COOLDOWN_MSEC
		_equip(LoadoutRules.switch_next(loadout))
	if InputManager.is_weapon_1_pressed():
		_equip(LoadoutRules.equip(loadout, 0))
	if InputManager.is_weapon_2_pressed():
		_equip(LoadoutRules.equip(loadout, 1))
	if InputManager.is_drop_weapon_pressed() and now >= _next_drop_at:
		_next_drop_at = now + DROP_COOLDOWN_MSEC
		var result := LoadoutRules.drop(loadout, loadout.active)
		_drop_on_ground(result.dropped)
		_commit(result.loadout, true)

func _equip(next: Dictionary) -> void:
	if next.active == loadout.active:
		return
	_commit(next, true)
	var def := WeaponDefs.get_def(LoadoutRules.active(loadout).def)
	EventManager.emit_event(EventManager.Events.WEAPON_SWITCHED, [player, loadout.active, def])

## Advances reloads and bursts of the hands currently in use.
func _tick_hands(now: int) -> void:
	for hand in _hands():
		var state := LoadoutRules.hand_state(loadout, hand)
		var stats := _stats_for(state)
		var result := WeaponRules.tick(state, stats, now, _rng)
		if result.events.is_empty():
			continue
		loadout = LoadoutRules.with_hand_state(loadout, hand, result.state)
		_apply_result(hand, result, stats)

func _handle_fire_input(now: int) -> void:
	var primary := LoadoutRules.active(loadout)
	if primary.is_empty() or LoadoutRules.any_bursting(loadout):
		return

	if InputManager.is_shoot_pressed():
		if not _stats_for(primary).melee and _try_start_burst(now):
			return
		if LoadoutRules.is_dual(loadout) and _stats_for(primary).melee:
			_swing_both_blades(now)
			return
		var hand: StringName = &"primary"
		if LoadoutRules.is_dual(loadout):
			hand = LoadoutRules.pick_dual_hand(loadout, now)
			if hand == &"":
				return
		var state := LoadoutRules.hand_state(loadout, hand)
		var stats := _stats_for(state)
		var result := WeaponRules.fire(state, stats, now, _rng)
		if result.shots.is_empty():
			return
		loadout = LoadoutRules.with_hand_state(loadout, hand, result.state)
		if LoadoutRules.is_dual(loadout):
			loadout = LoadoutRules.after_dual_shot(loadout, hand, WeaponRules.interval_msec(stats.fire_rate), now)
		_apply_result(hand, result, stats)
	elif InputManager.is_reload_pressed() and not LoadoutRules.is_dual(loadout):
		var stats := _stats_for(primary)
		var result := WeaponRules.start_reload(primary, stats, now)
		if not result.events.is_empty():
			loadout = LoadoutRules.with_active_state(loadout, result.state)
			_apply_result(&"primary", result, stats)

## Dual blades strike together (one swing each), so a double kill is possible.
func _swing_both_blades(now: int) -> void:
	for hand in _hands():
		var state := LoadoutRules.hand_state(loadout, hand)
		var stats := _stats_for(state)
		var result := WeaponRules.fire(state, stats, now, _rng)
		if result.shots.is_empty():
			continue
		loadout = LoadoutRules.with_hand_state(loadout, hand, result.state)
		_apply_result(hand, result, stats)

## Consumes a Burst powerup use (if one is active) and starts bursts on every
## hand that can fire.
func _try_start_burst(now: int) -> bool:
	if powerup_manager == null:
		return false
	var ready_hands: Array[StringName] = []
	for hand in _hands():
		var state := LoadoutRules.hand_state(loadout, hand)
		if state.ammo > 0 and WeaponRules.is_idle(state, now):
			ready_hands.append(hand)
	if ready_hands.is_empty():
		return false
	var burst: Dictionary = powerup_manager.try_consume_burst()
	if burst.is_empty():
		return false
	for hand in ready_hands:
		var result := WeaponRules.start_burst(LoadoutRules.hand_state(loadout, hand), now, burst.spread_degrees, burst.shots_per_second)
		loadout = LoadoutRules.with_hand_state(loadout, hand, result.state)
	_tick_hands(now) # fire the first burst shot this frame
	return true

## Turns a rules result into side effects.
func _apply_result(hand: StringName, result: Dictionary, stats: Dictionary) -> void:
	if not result.shots.is_empty():
		_fire_shots(hand, result.shots, stats)
	if result.events.has(&"reload_started"):
		EventManager.emit_event(EventManager.Events.WEAPON_RELOADED, [player, true, float(stats.reload_time)])
	if result.events.has(&"reloaded"):
		EventManager.emit_event(EventManager.Events.WEAPON_RELOADED, [player, false, 0.0])
	_emit_hud()

func _fire_shots(hand: StringName, offsets: Array[float], stats: Dictionary) -> void:
	var view := _view_for(hand)
	var origin := view.muzzle_position() if view else global_position
	if view:
		view.play_fire()
	_play_fire_fx.rpc(hand)
	var rotations := PackedFloat32Array()
	for offset in offsets:
		rotations.append(global_rotation + offset)
	var state := LoadoutRules.hand_state(loadout, hand)
	var combat: CombatServer = player.get_parent().get_node_or_null("Combat")
	if combat:
		combat.fire(player, origin, rotations, state.def, stats.max_range)
	player_controller.apply_fire_slow(stats.move_speed_mult, stats.slow_duration)
	EventManager.emit_event(EventManager.Events.WEAPON_FIRED, [player, int(state.ammo), int(stats.mag_size)])

func _end_dual_wield() -> void:
	_commit(LoadoutRules.disable_dual(loadout), true)
	if powerup_manager:
		powerup_manager.expire_ability(&"dual_wield")

## Dual wielding follows the Dual Wield powerup: derive it instead of being told.
func _on_powerups_changed(_active: Array) -> void:
	if not is_multiplayer_authority():
		return
	var spread := powerup_manager.get_dual_wield_spread()
	var is_dual := LoadoutRules.is_dual(loadout)
	if spread < 0.0:
		if is_dual:
			_commit(LoadoutRules.disable_dual(loadout), true)
		return
	if is_dual and is_equal_approx(spread, loadout.dual_spread):
		return
	var next := LoadoutRules.enable_dual(loadout, spread)
	if LoadoutRules.is_dual(next):
		_commit(next, true)
	else:
		# Nothing to mirror (e.g. empty magazine): the powerup ends right away.
		powerup_manager.expire_ability(&"dual_wield")

# --- Helpers ----------------------------------------------------------------

func _hands() -> Array[StringName]:
	if LoadoutRules.active(loadout).is_empty():
		return []
	if LoadoutRules.is_dual(loadout):
		return [&"primary", &"offhand"]
	return [&"primary"]

func _stats_for(state: Dictionary) -> Dictionary:
	return stats_for(state.def)

## Current stats of a weapon for this player, modifiers included. The host uses
## its mirror of other players to compute their damage.
func stats_for(def_id: StringName) -> Dictionary:
	return WeaponRules.effective_stats(WeaponDefs.get_def(def_id), _modifiers())

func _modifiers() -> Dictionary:
	var mods: Dictionary = powerup_manager.get_modifiers() if powerup_manager else {}
	mods["spread_mult"] = loadout.dual_spread if LoadoutRules.is_dual(loadout) else 0.0
	mods["pierce"] = PowerupRules.pierce(powerup_manager.active) if powerup_manager else 0
	return mods

## Replaces the loadout and refreshes everything derived from it.
func _commit(next: Dictionary, sync: bool) -> void:
	loadout = next
	_reconcile_views()
	_emit_hud()
	if sync and is_multiplayer_authority():
		_receive_loadout.rpc(loadout)

func _emit_hud() -> void:
	if not is_multiplayer_authority():
		return
	var primary := LoadoutRules.active(loadout)
	if primary.is_empty():
		EventManager.emit_event(EventManager.Events.UI_AMMO_UPDATED, [player, 0, 0, -1, -1])
	else:
		var primary_def := WeaponDefs.get_def(primary.def)
		if primary_def.melee:
			# Breakable blades show the hits they have left; others show nothing.
			var most: int = primary_def.durability if primary_def.durability > 0 else -1
			var left: int = int(primary.ammo) if most > 0 else -1
			var off_left: int = int(loadout.offhand.ammo) if most > 0 and LoadoutRules.is_dual(loadout) else -1
			EventManager.emit_event(EventManager.Events.UI_AMMO_UPDATED, [player, left, most, off_left, most if off_left >= 0 else -1])
			_emit_slots()
			return
		var mag: int = WeaponDefs.get_def(primary.def).mag_size
		var off_ammo: int = loadout.offhand.ammo if LoadoutRules.is_dual(loadout) else -1
		var off_mag: int = mag if LoadoutRules.is_dual(loadout) else -1
		EventManager.emit_event(EventManager.Events.UI_AMMO_UPDATED, [player, int(primary.ammo), mag, off_ammo, off_mag])
	_emit_slots()

func _emit_slots() -> void:
	var names: Array = []
	for i in range(LoadoutRules.MAX_SLOTS):
		var def := WeaponDefs.get_def(loadout.slots[i].def) if i < loadout.slots.size() else null
		names.append(def.get_display_name() if def else "")
	EventManager.emit_event(EventManager.Events.UI_WEAPON_SLOTS_UPDATED, [player, names])

# --- Views ------------------------------------------------------------------

func _view_for(hand: StringName) -> WeaponView:
	if hand == &"offhand":
		return _offhand_view
	if loadout.active < _views.size():
		return _views[loadout.active]
	return null

## Makes the child view nodes match the loadout.
func _reconcile_views() -> void:
	while _views.size() > loadout.slots.size():
		var extra: WeaponView = _views.pop_back()
		_view_defs.pop_back()
		if extra:
			extra.queue_free()
	for i in range(loadout.slots.size()):
		var def_id: StringName = loadout.slots[i].def
		if i >= _views.size():
			_views.append(null)
			_view_defs.append(&"")
		if _view_defs[i] != def_id or not is_instance_valid(_views[i]):
			if is_instance_valid(_views[i]):
				_views[i].queue_free()
			_views[i] = _make_view(def_id)
			_view_defs[i] = def_id
	for i in range(_views.size()):
		if _views[i]:
			_reset_view_transform(_views[i])
			_views[i].visible = i == loadout.active

	var offhand_def: StringName = loadout.offhand.def if LoadoutRules.is_dual(loadout) else &""
	if offhand_def != _offhand_view_def or (offhand_def != &"" and not is_instance_valid(_offhand_view)):
		if is_instance_valid(_offhand_view):
			_offhand_view.queue_free()
		_offhand_view = _make_view(offhand_def) if offhand_def != &"" else null
		_offhand_view_def = offhand_def
	if LoadoutRules.is_dual(loadout):
		_apply_dual_offsets()

func _make_view(def_id: StringName) -> WeaponView:
	var def := WeaponDefs.get_def(def_id)
	if def == null or def.view_scene == null:
		return null
	var view := def.view_scene.instantiate() as WeaponView
	add_child(view)
	return view

func _reset_view_transform(view: WeaponView) -> void:
	view.position = Vector2.ZERO
	view.rotation = 0.0
	view.scale = Vector2.ONE
	view.z_index = 0

## Stacks both guns vertically. Some art is offset inside its scene (the shotgun
## sprite sits at (40, -10)); compensate so the pair stays centered.
func _apply_dual_offsets() -> void:
	var half_spacing := DUAL_WIELD_VERTICAL_SPACING * 0.5
	var primary_view := _view_for(&"primary")
	if primary_view:
		primary_view.position = Vector2(0.0, half_spacing - primary_view.sprite_offset().y)
	if _offhand_view:
		_reset_view_transform(_offhand_view)
		_offhand_view.position = Vector2(0.0, -half_spacing - _offhand_view.sprite_offset().y)
		_offhand_view.z_index = 1
		_offhand_view.visible = true

# --- API for other systems --------------------------------------------------

func can_pick_up() -> bool:
	return LoadoutRules.can_pick_up(loadout)

func has_weapon(def_id: StringName) -> bool:
	return LoadoutRules.has_weapon(loadout, def_id) or (LoadoutRules.is_dual(loadout) and loadout.offhand.def == def_id)

func is_dual_wield_active() -> bool:
	return LoadoutRules.is_dual(loadout)

## Drops one random non-default weapon and resets to the default loadout.
func reset_on_death() -> void:
	if not is_multiplayer_authority():
		return
	var candidates: Array[StringName] = []
	for state in loadout.slots:
		if state.def != WeaponDefs.DEFAULT_ID:
			candidates.append(state.def)
	if not candidates.is_empty():
		_drop_on_ground([candidates.pick_random()])
	_commit(LoadoutRules.with_weapon(WeaponDefs.default_def()), true)

func _drop_on_ground(def_ids: Array[StringName]) -> void:
	var map := player.get_parent()
	for def_id in def_ids:
		if map and map.has_method("request_weapon_drop"):
			map.request_weapon_drop.rpc_id(1, def_id, player.global_position)
		EventManager.emit_event(EventManager.Events.WEAPON_DROPPED, [player, WeaponDefs.get_def(def_id)])

# --- Network ----------------------------------------------------------------

## Host -> owner: the host approved a pickup.
@rpc("any_peer", "call_local", "reliable")
func grant_weapon(def_id: StringName) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	var def := WeaponDefs.get_def(def_id)
	if def == null:
		return
	var result := LoadoutRules.add(loadout, WeaponRules.new_state(def))
	if not result.accepted:
		return
	_drop_on_ground(result.dropped)
	_commit(result.loadout, true)
	EventManager.emit_event(EventManager.Events.WEAPON_PICKED_UP, [player, def])

## Host -> owner: a melee swing landed. A breakable blade loses a use and
## shatters at zero (it is gone, not dropped). With two blades the off-hand one
## goes first; once it breaks Dual Wield ends, since there is nothing left to mirror.
@rpc("any_peer", "call_local", "reliable")
func melee_hit_landed(def_id: StringName) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	var def := WeaponDefs.get_def(def_id)
	var primary := LoadoutRules.active(loadout)
	if def == null or def.durability <= 0 or primary.is_empty() or primary.def != def_id:
		return
	var hand: StringName = &"offhand" if LoadoutRules.is_dual(loadout) else &"primary"
	var result := WeaponRules.use_durability(LoadoutRules.hand_state(loadout, hand))
	if not result.broken:
		_commit(LoadoutRules.with_hand_state(loadout, hand, result.state), true)
		return
	_play_break_fx.rpc(player.global_position + Vector2.RIGHT.rotated(global_rotation) * 40.0, global_rotation)
	if hand == &"offhand":
		_commit(LoadoutRules.disable_dual(loadout), true)
		if powerup_manager:
			powerup_manager.expire_ability(&"dual_wield")
		return
	var remaining: Dictionary = LoadoutRules.drop(loadout, loadout.active).loadout
	if LoadoutRules.active(remaining).is_empty():
		remaining = LoadoutRules.with_weapon(WeaponDefs.default_def()) # never empty-handed
	_commit(remaining, true)
	var now_held := LoadoutRules.active(loadout)
	EventManager.emit_event(EventManager.Events.WEAPON_SWITCHED, [player, loadout.active, WeaponDefs.get_def(now_held.def) if not now_held.is_empty() else null])

@rpc("authority", "call_local", "reliable")
func _play_break_fx(at: Vector2, rotation_value: float) -> void:
	ImpactFx.shatter(player.get_parent(), at, Vector2.RIGHT.rotated(rotation_value))

## Host -> owner: Kill Reload. Every hand in use gets a full magazine.
@rpc("any_peer", "call_local", "reliable")
func refill_magazines() -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	var refilled := loadout
	for hand in _hands():
		var state := LoadoutRules.hand_state(refilled, hand)
		refilled = LoadoutRules.with_hand_state(refilled, hand, WeaponRules.refill(state, _stats_for(state)))
	_commit(refilled, true)
	EventManager.emit_event(EventManager.Events.WEAPON_RELOADED, [player, false, 0.0])

@rpc("authority", "call_remote", "reliable")
func _receive_loadout(data: Dictionary) -> void:
	loadout = data
	_reconcile_views()

@rpc("any_peer", "call_remote", "reliable")
func _request_sync() -> void:
	if is_multiplayer_authority():
		_receive_loadout.rpc_id(multiplayer.get_remote_sender_id(), loadout)

@rpc("authority", "call_remote", "unreliable_ordered")
func _play_fire_fx(hand: StringName) -> void:
	var view := _view_for(hand)
	if view:
		view.play_fire()
