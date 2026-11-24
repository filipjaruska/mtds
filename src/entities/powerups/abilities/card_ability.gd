extends Resource
class_name CardAbility
## What a card does besides stat bonuses. Each ability is its own small script
## in this folder (RiotShieldAbility, BurstAbility, ...) with its settings as
## inspector fields. On a card, pick one under Effect > Ability > New ....
##
## To add an ability: copy one of these scripts, give it a new class_name and
## kind, and add its behaviour where it acts (see CardEffects for examples).

## The name the game code uses to find this ability on the active cards.
func get_kind() -> StringName:
	return &""
