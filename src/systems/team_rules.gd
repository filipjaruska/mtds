extends RefCounted
class_name TeamRules
## Pure functions for team matches. `players` is GameManager.players:
## {peer id: {id, name, color, team}}. Nothing here touches nodes or the network.

const TEAM_COUNT := 2
const NAMES := ["Red", "Blue"]
const COLORS := [Color("e74c3c"), Color("3498db")]

static func team_of(players: Dictionary, player_id: int) -> int:
	return int(players.get(player_id, {}).get("team", 0))

## Team for a newly joined player: the smaller one (Red on a tie).
static func pick_team(players: Dictionary) -> int:
	var sizes := team_sizes(players)
	return 1 if sizes[1] < sizes[0] else 0

static func team_sizes(players: Dictionary) -> Array[int]:
	var sizes: Array[int] = [0, 0]
	for id in players:
		sizes[team_of(players, id)] += 1
	return sizes

static func other_team(team: int) -> int:
	return (team + 1) % TEAM_COUNT

static func is_friendly(players: Dictionary, a: int, b: int, team_mode: bool) -> bool:
	return team_mode and a != b and team_of(players, a) == team_of(players, b)

## Spawn point for a player's first spawn. In team matches Red takes the even
## spawn points and Blue the odd ones, so each team starts on its own side.
static func spawn_index(players: Dictionary, player_id: int, team_mode: bool) -> int:
	var ids := players.keys()
	ids.sort()
	if not team_mode:
		return ids.find(player_id)
	var team := team_of(players, player_id)
	var rank := 0
	for id in ids:
		if id == player_id:
			break
		if team_of(players, id) == team:
			rank += 1
	return rank * TEAM_COUNT + team

## Spawn point indices a player may respawn at.
static func respawn_indices(team: int, spawn_count: int, team_mode: bool) -> Array[int]:
	var indices: Array[int] = []
	for i in range(spawn_count):
		if not team_mode or i % TEAM_COUNT == team:
			indices.append(i)
	if indices.is_empty(): # map with a single spawn point
		for i in range(spawn_count):
			indices.append(i)
	return indices

## Sums per-player results ({team, kills, deaths, damage_dealt}) per team,
## best team first (most kills, then damage).
static func team_totals(results: Array) -> Array[Dictionary]:
	var totals: Array[Dictionary] = []
	for team in range(TEAM_COUNT):
		totals.append({"team": team, "kills": 0, "deaths": 0, "damage_dealt": 0.0})
	for entry in results:
		var total: Dictionary = totals[int(entry.get("team", 0))]
		total.kills += int(entry.get("kills", 0))
		total.deaths += int(entry.get("deaths", 0))
		total.damage_dealt += float(entry.get("damage_dealt", 0.0))
	totals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.kills != b.kills:
			return a.kills > b.kills
		return a.damage_dealt > b.damage_dealt)
	return totals

## Winning team index, or -1 on a draw (same kills and damage).
static func winner(totals: Array[Dictionary]) -> int:
	var a := totals[0]
	var b := totals[1]
	if a.kills == b.kills and is_equal_approx(a.damage_dealt, b.damage_dealt):
		return -1
	return a.team
