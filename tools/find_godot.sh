#!/bin/sh
# Finds a Godot binary on this machine; sourced by tools/setup.sh and tests/run.sh.
# Sets GODOT_FOUND to the best match (empty if none): the project's version
# (GODOT_VERSION, the same one CI uses) if installed, otherwise any Godot 4.
#
# Looks on PATH (godot, godot4), in /Applications on macOS, and on Windows in
# the Desktop, Downloads and Program Files folders (prefers the _console.exe,
# which prints to the terminal).

GODOT_VERSION="4.7.2"

_godot_candidates() {
	for name in godot godot4 Godot; do
		command -v "$name" 2>/dev/null
	done
	for app in /Applications/Godot*.app "$HOME"/Applications/Godot*.app; do
		[ -d "$app" ] && printf '%s\n' "$app"/Contents/MacOS/Godot
	done
	for dir in "$HOME/Desktop" "$HOME/Downloads" "$HOME" "/c/Program Files" "/c/Program Files/Godot" "/c/Godot"; do
		for exe in "$dir"/Godot_v4*/Godot_v4*_console.exe "$dir"/Godot_v4*_console.exe "$dir"/Godot_v4*/Godot_v4*.exe; do
			[ -f "$exe" ] && printf '%s\n' "$exe"
		done
	done
}

find_godot() {
	GODOT_FOUND=""
	_fallback=""
	_list=$(_godot_candidates)
	_old_ifs=$IFS
	IFS='
'
	for candidate in $_list; do
		[ -f "$candidate" ] || continue
		_version=$("$candidate" --version 2>/dev/null | head -n 1)
		case "$_version" in
			"$GODOT_VERSION".*) GODOT_FOUND=$candidate; break ;;
			4.*) [ -z "$_fallback" ] && _fallback=$candidate ;;
		esac
	done
	IFS=$_old_ifs
	[ -z "$GODOT_FOUND" ] && GODOT_FOUND=$_fallback
	return 0
}
