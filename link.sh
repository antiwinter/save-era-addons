#!/usr/bin/env bash
# Symlink every addon in this repo into WoW's Interface/AddOns folder.
# Usage: ./link.sh [TARGET]
#   TARGET defaults to the standard Classic Era install for the detected OS.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin) DEFAULT_TARGET="/Applications/World of Warcraft/_classic_era_" ;;
  Linux)  DEFAULT_TARGET="" ;;
  *)      DEFAULT_TARGET="" ;;
esac

TARGET="${1:-$DEFAULT_TARGET}"
if [ -z "$TARGET" ]; then
  echo "error: no default target for this OS — pass one explicitly:" >&2
  echo "  ./link.sh /path/to/_classic_era_" >&2
  exit 1
fi

ADDONS_DIR="$TARGET/Interface/AddOns"
if [ ! -d "$TARGET" ]; then
  echo "error: target not found: $TARGET" >&2
  exit 1
fi
mkdir -p "$ADDONS_DIR"

linked=0
for toc in "$REPO_DIR"/*/*.toc; do
  [ -e "$toc" ] || continue
  addon_dir="$(dirname "$toc")"
  name="$(basename "$addon_dir")"
  dest="$ADDONS_DIR/$name"

  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -e "$dest" ]; then
    echo "skip: $name — real directory already exists at destination" >&2
    continue
  fi

  ln -s "$addon_dir" "$dest"
  echo "linked: $name -> $dest"
  linked=$((linked + 1))
done

echo "done: $linked addon(s) linked into $ADDONS_DIR"
