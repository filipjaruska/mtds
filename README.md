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

A map is one scene with its rooms painted in place (`src/scenes/maps/catacombs.tscn`
is the example). Each match the corridors between the rooms are carved anew,
and rooms in a swap group may trade places, so no two matches look the same.

1. Duplicate `src/scenes/map_template.tscn` into `src/scenes/maps/` (every
   scene there is listed in the lobby) and rename the root node.
2. **Rooms:** under `Rooms`, one `MapRoom` node per room (duplicate one), on
   the tile grid. Paint each room's `Floor` and `Walls` (TileMap panel), any
   size and shape. Walls must come from a tile set whose physics layer is on
   layer 3 "walls", like `src/assets/maps/catacombs/tiles.tres`. Put what the
   room holds inside it: spawn points (`SpawnPoint` under `SpawnLocations`),
   weapon spots (`WeaponSpawner` under `WeaponDrops`), card areas
   (`PowerupSpawner` under `CardDrops`).
3. **Doorways:** a `RoomDoor` under the room's `Doors` at each gap in its
   border wall, arrow pointing out. The gap is 3 tiles wide (the map's corridor
   width): green while clear, red while a wall is in it. Doorways no corridor
   uses that match are walled up.
4. **Links:** a `RoomLink` under `Links` for each pair of rooms that should
   get a corridor (pick From and To; Chance below 1 for one that only
   sometimes appears). Rooms left unreachable get the closest corridor that
   fits anyway.
5. **Swap groups:** rooms with the same Swap Group trade places each match.
   `RoomSpot` nodes add more places for a group. Places where a room would
   overlap another are skipped.
6. **Semi-permanent rooms** (closed until an event opens them): tick Gated
   and give the gate a name. Their doorways get gates; nobody spawns inside.
7. The katana lies in exactly one place per map (weapons marked One Location).

Press "Reroll layout preview" on the root node to see a layout drawn over the
map (the output panel prints its seed; set Preview Seed under Layout Rules to
keep one). Layout Rules also set the corridor width, how much corridors avoid
turning and their tiles. Maps need 8 spawn points outside semi-permanent rooms.

A yellow warning on the root node, a room, a doorway or a link says what is
still missing. `git test` checks every map and tries 30 layouts of each.
