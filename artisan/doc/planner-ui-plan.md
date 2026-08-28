# Planner UI implementation plan

## State and ownership

Make `ns.store.plans[pk]` the only source of truth for planner inputs. `ns.store`
is a view over the current character's `artisanDB[char]` table:

```lua
ns.store.plans[pk] = {
    target = <number>,
    wishlist = { [itemId] = amount },
    preferExisting = <boolean>,
    noAH = <boolean>,
}
```

Remove parallel planner/plan input state. The UI reads and writes this object;
derived actions, BOM rows, and summary values are rebuilt from it. Persist the
same structure in the character SavedVariables and restore it by profession
key.

Keep the pure planner responsible for action/material calculations. Keep the
planner controller responsible for opening, parenting, tabs, and refresh
coordination. Keep content code responsible for controls and rendering.

## Planner window and tabs

- Keep the skill and planner tabs on `TradeSkillFrame`.
- Skill-tab click hides the planner frame and selects the skill tab.
- Planner-tab click shows the planner frame and selects the planner tab.
- `active` is a one-shot request consumed by `Attach`, then cleared.
- `Attach` only establishes parenting/layout and tab handlers; visibility is
  controlled by the tab handlers.
- Standalone `Open` reparents and shows the planner directly.
- `Close` closes the Era trade-skill window and hides the planner.
- The planner's Start Crafting button sets `cur_pk` and calls `CraftUI:Show()`;
  profession selection is not exposed by the craft panel.
- `CraftUI:Show()` rebuilds the session from `plans[cur_pk]` and shows the
  panel only when `cur_pk` is set. Addon load delegates to this same entrypoint.

## Target level

- Initialize the target from the current profession state and persisted state.
- The slider's full scale is always 1 through 300.
- The selectable interval is the live profession's current `[skill, cap]`
  region. The thumb cannot move below the current skill or above the returned
  profession cap (for example, `[5, 150]` or `[35, 300]`).
- Visually distinguish the selectable interval from the rest of the 1–300
  track.
- Clamp a persisted or newly invalid target into the current `[skill, cap]`
  interval before rebuilding the plan.
- Rebuild the plan and all derived values whenever the target changes.

## Data and wishlist search

- In `data.lua`, add the item/recipe name beside each `skill_id` in the runtime
  profession records.
- Build the search index from those names; search is case-insensitive and
  matches substrings.
- While typing, show an in-place dropdown of matching names, such as
  `Target Dummy` and `Advanced Target Dummy` for `dummy`.
- Selecting a result adds or edits its wishlist amount.
- Clicking a wishlist icon opens the stack-size-style amount editor.
- Setting the amount to zero removes the item.
- If an item's required skill level is above the current target, raise the
  target to that required level.
- Refuse the addition when the required level is above the player's permitted
  profession cap.

## Craft and BOM output

- Pass the persisted wishlist and target into the planner calculation.
- Render Craft rows as `item`, amount, and target skill level (`to`).
- Render BOM rows as item and available/required quantity.
- Read existing material quantities from the bags for the available side.
- Keep all row calculations derived from the current `ns.store.plans[pk]` and live bag
  state; do not maintain a second editable copy in the frame.

## Prefer existing materials

- Build an existing-material map from the current bags.
- Pass that map into `artisan/planner.lua`.
- When scoring candidate actions, apply a reduced buyout weight to items in
  that map (for example `0.8 * buyoutPrice`) so actions using existing stock
  are preferred.
- Keep the actual BOM and summary accounting exact; the weight affects action
  selection, not displayed prices.

## Summary and auction-house mode

Display:

- Existing materials
- Buy materials
- Junk returns
- AH returns
- Net cost

Use the WoW gold texture for each value.

When `noAH` is enabled:

- Treat crafted outputs that remain after reserving downstream reagent usage as
  junk.
- Value those outputs at vendor sell price.
- Do not count auction-house returns.

If vendor sell price or another client value is missing from fake-wow, add the
corresponding API stub there. Do not add fake-versus-real branches to addon
code.

## Refresh and persistence

- Recalculate after target, wishlist, `preferExisting`, or `noAH` changes.
- Refresh after skill, bag, recipe, and profession-window events where those
  inputs can change.
- Persist the complete `ns.store.plans[pk]` object whenever the user changes it.
- Keep the active session and craft controls derived from the selected
  profession state rather than a duplicate plan-input structure.

## Tests

- Keep `tests/run.sh` focused on the emulator progression runs only.
- Add `tests/test.sh` for all unit tests plus the existing `window.lua` and
  `resume.lua` checks.
- Add UI-independent tests for:
  - profession item names and substring search;
  - target-cap rules, including level 5 -> 150 and level 35 -> 300;
  - wishlist add/edit/remove and required-level validation;
  - existing-material weighting and action selection;
  - BOM available/required calculations;
  - no-AH junk/vendor-return accounting;
  - persistence and restoration of `ns.store.plans[pk]`.
- Do not implement real UI behavior in fake-wow. Add only client API stubs
  needed to execute shared, UI-independent code.
- Finish by running both `tests/test.sh` and `tests/run.sh`.
