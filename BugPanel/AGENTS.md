# BugPanel

Current-session Lua error viewer. A lean replacement for BugSack's display —
capture is delegated to `!BugGrabber`, we only render.

## Why this exists
BugSack (v3-era) calls `BugGrabber.RegisterCallback(...)`, an API dropped by
BugGrabber v12 (which now fires through Blizzard's `EventRegistry`). That
mismatch throws `core.lua:166: attempt to call a nil value`. BugSack's window
also forced nav buttons to `FULLSCREEN` strata, so it drew over the game menu.
BugPanel avoids both: correct EventRegistry wiring, `DIALOG` strata only.

## Architecture
- `core.lua` — SavedVariables init, BugGrabber wiring, `/bugpanel` + `/bugs`.
  `ns.SessionErrors()` returns only the live session's slice of `BugGrabber:GetDB()`.
- `panel.lua` — the accordion window. Rows are pooled in `rows[]`; `expanded[]`
  tracks which errors are open. Left-click a row to expand stack+locals,
  right-click to pop a select-all EditBox for copy (Classic has no clipboard API).
- `minimap.lua` — hand-rolled minimap button (no LibDBIcon). Click opens the
  panel, shift-click reloads the UI; icon is red with session bugs, green when
  clean. Position stored as an angle in `db.minimapAngle`, draggable round the ring.

## Dependencies
`!BugGrabber` (declared in the .toc). It owns error capture and cross-session
persistence in `BugGrabberDB`; we never write to it. Error object shape:
`{ message, stack, locals, session, time, counter, source? }`.
