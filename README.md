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
