extends Resource
class_name PowerupDef
## A powerup card as plain data.
##
## A card's effect is stat bonuses (Effect > Modifiers, see CardModifiers)
## and/or an ability (Effect > Ability: pick one of the CardAbility types, e.g.
## RiotShieldAbility, and set its fields).
##
## To add a powerup: duplicate a file in res://src/entities/powerups/defs/ and
## give it a new `id`. It is registered automatically (see PowerupDefs).

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## The card image (src/assets/cards/<id> (tmp).png while it is a placeholder).
## Replace the PNG (and drop "(tmp)" from its name) to change the art.
@export var card_texture: Texture2D
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
## Stat bonuses while the card is active.
@export var modifiers: CardModifiers
## What the card does besides stats (optional).
@export var ability: CardAbility

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else String(id).capitalize()

func get_type_description() -> String:
	return description

## The stat bonuses by name, e.g. {"damage_resist": 0.15}.
func modifier_values() -> Dictionary:
	return modifiers.to_dict() if modifiers else {}

## The ability's name (&"riot_shield", ...), or &"" for none.
func ability_kind() -> StringName:
	return ability.get_kind() if ability else &""
