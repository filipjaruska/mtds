#!/bin/sh
# Runs the headless test suites. Shared by the git hooks and CI.
#
#   sh tests/run.sh quick      import + compile + unit + lobby navigation   (~8 s)
#   sh tests/run.sh full       quick + smoke match + Esc menu + network test (~60 s)
#   sh tests/run.sh unit smoke ...   individual steps: import compile unit nav smoke pause net
#
# Godot binary, first match wins:
#   $GODOT, `git config hooks.godot`, `godot` on PATH.
# Set it once per clone with:  git config hooks.godot "/path/to/godot"

set -u
cd "$(dirname "$0")/.." || exit 1

GODOT_BIN="${GODOT:-}"
if [ -z "$GODOT_BIN" ]; then
	GODOT_BIN=$(git config --get hooks.godot 2>/dev/null || true)
fi
if [ -z "$GODOT_BIN" ]; then
	GODOT_BIN=godot
fi
if [ ! -f "$GODOT_BIN" ] && ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "tests/run.sh: Godot not found ('$GODOT_BIN')." >&2
	echo "Point it at your Godot binary once per clone:" >&2
	echo "  git config hooks.godot \"/path/to/godot\"   (or set the GODOT environment variable)" >&2
	exit 1
fi

LOG_DIR=$(mktemp -d)
trap 'rm -rf "$LOG_DIR"' EXIT

# GNU `timeout` is missing on stock macOS and in GitHub Desktop's bundled Git,
# where `timeout` may even resolve to the unrelated Windows timeout.exe.
# Only use it when it is the GNU tool; otherwise run without a limit.
if timeout --version >/dev/null 2>&1; then
	HAS_TIMEOUT=1
else
	HAS_TIMEOUT=0
fi

limit() {
	seconds=$1
	shift
	if [ "$HAS_TIMEOUT" -eq 1 ]; then
		timeout "$seconds" "$@"
	else
		"$@"
	fi
}

# Runs a test script headless with a time limit: script SECONDS RES_PATH [ARGS...]
script() {
	seconds=$1
	shift
	limit "$seconds" "$GODOT_BIN" --headless --path . -s "$@"
}

# Runs a step quietly; prints its log only when it fails.
step() {
	name=$1
	shift
	log="$LOG_DIR/$name.log"
	if "$@" >"$log" 2>&1; then
		echo "  ok    $name"
		return 0
	fi
	echo "  FAIL  $name" >&2
	cat "$log" >&2
	return 1
}

run_import() {
	# Registers class_name scripts, which the tests rely on. Its exit code is
	# unreliable (it reports unrelated editor warnings), so it never fails a run.
	limit 300 "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
	echo "  ok    import"
}

run_net() {
	script 90 res://tests/net_match.gd -- --role=host >"$LOG_DIR/net-host.log" 2>&1 &
	host_pid=$!
	# Head start for the host; the client also retries until the host is up.
	if command -v sleep >/dev/null 2>&1; then
		sleep 2
	fi
	client_exit=0
	script 90 res://tests/net_match.gd -- --role=client >"$LOG_DIR/net-client.log" 2>&1 || client_exit=$?
	host_exit=0
	wait "$host_pid" || host_exit=$?
	if [ "$host_exit" -eq 0 ] && [ "$client_exit" -eq 0 ]; then
		echo "  ok    net"
		return 0
	fi
	echo "  FAIL  net (host exit $host_exit, client exit $client_exit)" >&2
	echo "--- host ---" >&2
	cat "$LOG_DIR/net-host.log" >&2
	echo "--- client ---" >&2
	cat "$LOG_DIR/net-client.log" >&2
	return 1
}

run() {
	case "$1" in
		import) run_import ;;
		compile) step compile script 60 res://tests/compile_check.gd ;;
		unit) step unit script 60 res://tests/run_tests.gd ;;
		nav) step nav script 60 res://tests/lobby_nav.gd ;;
		smoke) step smoke script 120 res://tests/smoke_match.gd ;;
		pause) step pause script 60 res://tests/pause_menu.gd ;;
		net) run_net ;;
		quick) run import && run compile && run unit && run nav ;;
		full) run quick && run smoke && run pause && run net ;;
		*) echo "tests/run.sh: unknown step '$1'" >&2; return 2 ;;
	esac
}

[ $# -gt 0 ] || set -- quick
for target in "$@"; do
	run "$target" || exit 1
done
