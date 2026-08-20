#!/usr/bin/env bash
# Build the lsqlite3 binding (.so is a local cache — gitignored).
# Sources: lsqlite3.c (MIT) + sqlite3.c/.h (public domain), from the
# lsqlite3complete 0.9.5 rock at luarocks.org/lsqlite3complete-0.9.5-1.src.rock
set -euo pipefail
cd "$(dirname "$0")"
LUA_INC="${LUA_INC:-/opt/local/include}"   # MacPorts lua
EXTRA=()
[[ "$(uname)" == "Darwin" ]] && EXTRA=(-undefined dynamic_lookup)
cc -O2 -shared -fPIC -I"$LUA_INC" -DLSQLITE_VERSION='"0.9.5"' \
	-o lsqlite3.so sqlite3.c lsqlite3.c "${EXTRA[@]}"
echo "built $(pwd)/lsqlite3.so"