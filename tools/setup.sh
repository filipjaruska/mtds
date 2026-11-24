#!/bin/sh
# One-time setup for a fresh clone. Run from anywhere inside the repo:
#
#   sh tools/setup.sh                    finds Godot by itself
#   sh tools/setup.sh /path/to/godot     or tell it where Godot is
#
# It turns on the git hooks (tests before commit and push, commit message
# check), adds `git test quick|full`, remembers where Godot is for the tests,
# and imports the project once so the first editor start is quick.
# Safe to run again (for example after installing a new Godot).

set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
. tools/find_godot.sh

godot="${1:-}"
if [ -z "$godot" ]; then
	find_godot
	godot=$GODOT_FOUND
fi
if [ -z "$godot" ] || [ ! -f "$godot" ]; then
	echo "Couldn't find Godot. Install Godot $GODOT_VERSION (.NET/mono build), then run:"
	echo "  sh tools/setup.sh /path/to/godot"
	echo "On macOS the path looks like /Applications/Godot_mono.app/Contents/MacOS/Godot"
	exit 1
fi

# Windows: store C:/... rather than /c/..., which every git client understands.
command -v cygpath >/dev/null 2>&1 && godot=$(cygpath -m "$godot")

version=$("$godot" --version 2>/dev/null | head -n 1)
echo "Godot:  $godot"
echo "        version $version"
case "$version" in
	"$GODOT_VERSION".*) ;;
	*) echo "        warning: the project uses Godot $GODOT_VERSION. Other versions rewrite scene files and make noisy diffs." ;;
esac

git config core.hooksPath .githooks
git config hooks.godot "$godot"
git config alias.test '!sh tests/run.sh'
chmod +x .githooks/* 2>/dev/null
echo "Git:    hooks on, 'git test quick' and 'git test full' added"

echo "Import: importing the project (first time can take a minute)..."
if "$godot" --headless --path . --import >/dev/null 2>&1; then
	echo "        done"
else
	echo "        Godot reported errors during import; open the project in the editor to see them"
fi

echo
echo "All set. Open the project with:  \"$godot\" --path . -e"
echo "Run the tests with:              git test quick"
