extends Resource
class_name GameRules
## The game's tuning numbers in one place. The values are in
## res://src/game_rules.tres: open it in Godot and change them in the inspector.
## They are read when the game starts, so restart the game after a change.
##
## Weapon and card numbers are not here: they live in each weapon and card file
## (src/entities/weapons/defs, src/entities/powerups/defs).

@export_group("Match")
## Length of a match.
@export_range(30.0, 3600.0, 10.0, "suffix:s") var match_seconds: float = 300.0
## Players per match, host included. Every map needs this many spawn points;
## the top bar has room for 8.
@export_range(2, 8) var max_players: int = 8
## Time between dying and coming back.
@export_range(0.0, 10.0, 0.1, "suffix:s") var respawn_seconds: float = 1.0

@export_group("Weapons")
## Minimum time between weapon switches.
@export_range(0.0, 2.0, 0.05, "suffix:s") var switch_cooldown_seconds: float = 0.3
## Minimum time between dropping weapons.
@export_range(0.0, 5.0, 0.1, "suffix:s") var drop_cooldown_seconds: float = 1.0

@export_group("Poker")
## Time between board cards (the board has 4).
@export_range(1.0, 60.0, 0.5, "suffix:s") var poker_reveal_seconds: float = 15.0
## A new board is dealt this often. Keep it at 4 x the reveal time or more.
@export_range(4.0, 300.0, 1.0, "suffix:s") var poker_round_seconds: float = 60.0

@export_group("Chat")
## Longest message, in characters.
@export_range(10, 200) var chat_max_length: int = 80
## Spam guard: at most this many messages...
@export_range(1, 20) var chat_rate_count: int = 3
## ...per this many seconds, per player.
@export_range(1.0, 30.0, 0.5, "suffix:s") var chat_rate_window_seconds: float = 4.0
## How fast a message types out.
@export_range(5.0, 200.0, 1.0, "suffix:chars/s") var chat_chars_per_second: float = 32.0
## How long a typed-out message stays: this...
@export_range(0.5, 20.0, 0.1, "suffix:s") var chat_hold_seconds: float = 3.0
## ...plus this per character.
@export_range(0.0, 0.5, 0.01, "suffix:s") var chat_hold_per_char: float = 0.04
## Fade-out time of a message.
@export_range(0.0, 3.0, 0.05, "suffix:s") var chat_fade_seconds: float = 0.4
## Messages that can wait behind the one being shown.
@export_range(0, 10) var chat_max_queued: int = 3

@export_group("Practice targets")
@export_range(1.0, 1000.0, 1.0) var target_hp: float = 100.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var target_respawn_seconds: float = 1.5
