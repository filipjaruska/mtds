# Docs

## Contribute

Read [this](/docs/contribute.md) before hand.

## Components

### Global

Are autoload scripts. These scripts are loaded when the game starts and persist across all scenes.

- `game_manager`:
- `input_manager`:
- `event_manager`:
  A centralized event bus system that facilitates communication between different parts of the game through a publish/subscribe pattern. See the [Event Manager](/docs/docs/event-manager.md).

### Multiplier

Multiplier components handle game mechanics that affect multiple entities

### Player

### Weapons

The weapon system

## Server Guide

run in a container or vm using the `--server` flag. cmd example:

```bash
"project name.exe" --server
```

or

```bash
"project name.exe" --server --headless
```
