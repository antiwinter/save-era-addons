#!/usr/bin/env bash
# tests/run.sh — regression gate. Runs the Monte Carlo emulator over each
# fine-tuned profession at a fixed seed and fails if any plan comes up SHORT.
# Because emu.lua loads the SAME planner.lua that ships in-game, a green run
# here means the shipped algorithm reaches the target off-client.
set -euo pipefail
cd "$(dirname "$0")/.."   # addon root

LUA="${LUA:-lua}"
SEED="${SKM_SEED:-1}"

fail=0
for prof in eng tailor; do
	echo "== $prof =="
	if ! SKM_SEED="$SEED" SKM_NOPLAN=1 "$LUA" tests/emu.lua "$prof" 300; then
		echo "FAIL: $prof did not reach target" >&2
		fail=1
	fi
	echo
done

exit $fail
