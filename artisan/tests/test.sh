#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

LUA="${LUA:-lua}"

"$LUA" tests/model.lua
"$LUA" tests/window.lua
ARTISAN_SEED="${ARTISAN_SEED:-8}" "$LUA" tests/resume.lua eng 300
