# Multiplayer Top-Down Shooter

## Ideas

- Roguelike progression system, at the end of the round player gets a new augment (loses weapons and cards), has to directly interact with the cards, cannot be a buff by its own, would prefer if the card system with multipliers stayed the core of the game.
- after picking up the card slow time like in supperhot, so that the player can register what they picked up and have a bit of time to strategize. Perhaps slow down time in just some areas and only for bullets so that melee would still be an option to kill.

## Development

### Tests

Headless tests live in `tests/` (no plugin needed). Run them with:

```sh
sh tests/run.sh quick   # import + unit + lobby navigation, ~5 s
sh tests/run.sh full    # + smoke match and host/client network test, ~35 s
```

### Git hooks

Once per clone:

```sh
git config core.hooksPath .githooks
git config hooks.godot "/path/to/godot"   # e.g. the *_console.exe on Windows
```

- `pre-commit` runs the quick tests when the commit touches Godot files.
- `pre-push` runs the full tests.
- `commit-msg` requires `type: subject` or `type(scope): subject`,
  e.g. `fix: ...` or `feat(weapons): ...`.
