# Multiplayer Top-Down Shooter

- Roguelike progression: at the end of a round the player picks an augment
  (losing weapons and cards). It must interact with the cards rather than be a
  plain buff; the card and multiplier system stays the core of the game.
- Slow time after picking up a card (like Superhot) so the player can see what
  they got and plan. Maybe only in some areas, or only for bullets, so melee
  stays viable.

## Development

Clone:

```sh
git clone https://github.com/filipjaruska/mtds.git
```

then, once per clone (needs Godot 4.7.2 .NET installed; on Windows run it in Git Bash):

```sh
sh tools/setup.sh                   # finds Godot by itself
sh tools/setup.sh /path/to/godot    # or point it at Godot
```

It turns on the git hooks, adds `git test`, remembers where Godot is and
imports the project.

To test:

```sh
git test quick   # import + unit + lobby navigation, ~5 s
git test full    # + smoke match and host/client network test, ~35 s
```

Hooks:

- `pre-commit` runs `quick` when Godot files are staged.
- `pre-push` runs `full`.
- `commit-msg` requires `type: subject` or `type(scope): subject`,
  e.g. `fix: ...` or `feat(weapons): ...`.

## Editing the game in Godot

Most of the game can be changed without code:

| To change | Open |
| --- | --- |
| Match length, max players, respawn, speeds, dash, health, regeneration, camera feel and chat timings | `src/game_rules.tres` |
| A weapon (damage, fire rate, spread, range, ammo...) | `src/entities/weapons/defs/<weapon>.tres` |
| A card (timing, stacking, stat bonuses, ability) | `src/entities/powerups/defs/<card>.tres` |
| The look of the UI (colours, fonts, buttons, panels) | `src/ui/theme/main_theme.tres` (Theme editor) |
| A screen's layout | its scene in `src/ui/menus/` or `src/ui/library/` |

New weapon or card: duplicate an existing `.tres` in its `defs/` folder and
give it a new `id`; it shows up in the game by itself.

### Making a map

Maps are put together from rooms each match: a map is a grid of slots, and
every slot gets one of the rooms you allow it, turned and mirrored at random,
with doorways between rooms opened or walled up so every room stays
reachable. `src/scenes/maps/crypts.tscn` is an example; `catacombs.tscn` is
an older fixed map, painted in one piece.

**A room** (or a block of an open area):

1. Duplicate `src/scenes/rooms/room_template.tscn` (rooms live under
   `src/scenes/rooms/<set>/`) and rename the root node.
2. Paint `Floor` and `Walls` inside the white box (16 x 16 tiles). Walls must
   come from a tile set whose physics layer is on layer 3 "walls", like
   `src/assets/maps/catacombs/tiles.tres`.
3. On the root node, set each side to Wall, Door or Open. A door is the 4
   tiles in the middle of that side's border (shown green): leave them
   without walls. Open sides have no border wall at all; neighbouring open
   blocks run into each other. Doorways that lead nowhere get walled up.
4. Add what the room holds: spawn points (`SpawnPoint` under
   `SpawnLocations`), weapon spots (`WeaponSpawner` under `WeaponDrops`) and
   card areas (`PowerupSpawner` under `CardDrops`).
5. Semi-permanent rooms (closed until an event opens them): tick Gated and
   give the gate a name.

**A map:**

1. Duplicate `src/scenes/map_template.tscn` into `src/scenes/maps/` (every
   scene there is listed in the lobby) and rename the root node.
2. Place `MapSlot` nodes on the grid (corners on multiples of 1024 px) and
   give each the rooms it may use (Room Choices: scene, weight, how many per
   map), a chance to stay empty, and whether its room may be turned or
   mirrored. Layout Rules on the root node set the slot and door size and how
   many extra doorways open.
3. The katana lies in exactly one place per map: give its room
   (`rooms/catacombs/katana_tomb.tscn`) one required slot of its own. Weapons
   marked "One Location" are checked this way.
4. Press "Reroll layout preview" on the root node to see a layout in the
   editor (the output panel prints its seed; set Preview Seed to keep one).

Rooms need 8 spawn points between them. In team matches Red spawns in the
west half of the map and Blue in the east (a spawn point's Team overrides it).

A yellow warning on the root node of a map, room or slot says what is still
missing. `git test` checks every map, tries 40 layouts of each slot map, and
checks every room.
