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

## Index of the spawn point for a player's first spawn. `spawn_teams` is the
## team of every spawn point (see GameMap.spawn_teams_of). Players take spawn
## points in id order; in team matches only their own team's, so each team
## starts on its own side. -1 when the map has none.
static func first_spawn(players: Dictionary, player_id: int, team_mode: bool, spawn_teams: Array) -> int:
	if spawn_teams.is_empty():
		return -1
	var ids := players.keys()
	ids.sort()
	if not team_mode:
		return maxi(ids.find(player_id), 0) % spawn_teams.size()
	var team := team_of(players, player_id)
	var rank := 0
	for id in ids:
		if id == player_id:
			break
		if team_of(players, id) == team:
			rank += 1
	var own := respawn_choices(team, spawn_teams, true)
	return own[rank % own.size()]

## Indices of the spawn points a player may respawn at: their team's in team
## matches (all of them when the team has none), any otherwise.
static func respawn_choices(team: int, spawn_teams: Array, team_mode: bool) -> Array[int]:
	var indices: Array[int] = []
	for i in range(spawn_teams.size()):
		if not team_mode or spawn_teams[i] == team:
			indices.append(i)
	if indices.is_empty():
		for i in range(spawn_teams.size()):
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
