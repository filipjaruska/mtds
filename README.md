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
| Match length, max players, respawn, speeds, dash, health, regeneration, camera feel, poker and chat timings | `src/game_rules.tres` |
| A weapon (damage, fire rate, spread, range, ammo...) | `src/entities/weapons/defs/<weapon>.tres` |
| A card (timing, stacking, stat bonuses, ability) | `src/entities/powerups/defs/<card>.tres` |
| The look of the UI (colours, fonts, buttons, panels) | `src/ui/theme/main_theme.tres` (Theme editor) |
| A screen's layout | its scene in `src/ui/menus/` or `src/ui/library/` |

New weapon or card: duplicate an existing `.tres` in its `defs/` folder and
give it a new `id`; it shows up in the game by itself.

### Making a map

1. Duplicate `src/scenes/map_template.tscn` into `src/scenes/maps/` (every
   scene there is listed in the lobby) and rename the root node.
2. Paint the floor on `Floor` and the walls on `Walls` (TileMap panel). Walls
   must come from a tile set whose physics layer is on layer 3 "walls", like
   `src/assets/maps/catacombs/tiles.tres`. To give the map its own tiles, copy
   that folder to `src/assets/maps/<name>/` and point both layers at the copy.
3. Move the spawn points (numbered circles) under `SpawnLocations`: 8, named
   0 to 7. In team matches Red starts on the even ones and Blue on the odd ones.
4. Weapon spots: `WeaponSpawner` nodes under `WeaponDrops`, each with a
   weapon picked. Card areas: `PowerupSpawner` nodes under `CardDrops`.

A yellow warning on the map's root node in the scene tree says what is still
missing. `git test` checks every map the same way.
