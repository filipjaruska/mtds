extends Resource
class_name PowerupDef
## A powerup card as plain data.
##
## Most powerups are just stat modifiers: put the stat key and its base value in
## `modifiers` and the systems that own those stats pick it up (see
## PowerupRules.modifiers). Known keys:
##   damage_mult              +0.2  => +20% weapon damage        (WeaponHolder)
##   reload_mult              +0.3  => reloads 30% faster        (WeaponHolder)
##   damage_resist            0.15  => 15% less damage taken     (HealthComponent)
##   max_health_mult          0.25  => +25% max health           (HealthComponent)
##   dash_cooldown_reduction  0.25  => 25% shorter dash cooldown (PlayerController)
##
## Powerups that change behaviour instead set `ability` (&"burst", &"dual_wield")
## with their tuning in `ability_params`.
##
## To add a powerup: duplicate a file in res://src/entities/powerups/defs/ and
## give it a new `id`. It is registered automatically (see PowerupDefs).

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon_texture: Texture2D
@export var rarity_color: Color = Color.WHITE

@export_group("Timing")
@export var duration: float = 30.0
## 0 = unlimited uses while active.
@export var max_uses: int = 0
@export var uses_per_stack: int = 0
## Spend a use every time the owner fires.
@export var consume_use_on_fire: bool = false

@export_group("Stacking")
@export var max_stack_count: int = 4
## Effect scale for 2 stacks; every further stack adds stack_bonus_per_card.
@export var stack_multiplier: float = 2.0
@export var stack_bonus_per_card: float = 0.1

@export_group("Effect")
@export var modifiers: Dictionary = {}
@export var ability: StringName = &""
@export var ability_params: Dictionary = {}

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else String(id).capitalize()

func get_type_description() -> String:
	return description
