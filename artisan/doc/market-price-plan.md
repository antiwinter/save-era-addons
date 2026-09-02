# Market price and auction-house scan implementation plan

## Purpose and boundaries

Add a runtime market-price layer so Artisan can plan from recent auction-house
values while keeping the generated Era data reproducible. The work has two
explicitly separate stages:

1. **Price stage** — load cached Auctionator/TSM values or run `/art scan` and
   update the market database.
2. **Planner stage** — when the user opens or rebuilds a plan, read the current
   market layer and recompute recipe output values and recursive costs.

Updating a price never implicitly creates or replans a plan. The first command
is a debugging interface; a UI can be added later without changing scanner
contracts.

The generated `data/era/item_prices.lua` remains checked-in, immutable output
from the data generator. It is a fallback for items with no runtime record,
not a second mutable market database.

## Persisted market schema

Store the overlay in the account SavedVariables table (alongside the existing
character plan state):

```lua
artisanDB.market[realmKey][itemID] = {
    price = { min, max, count },
    source = "at" | "tsm" | "scan",
    updatedAt = timestamp,
}
```

- `itemID` is a numeric item ID. Do not key by localized item name or item
  link.
- `realmKey` is produced by one helper used by every adapter. Use the realm
  name and include the player faction when the source is faction-scoped (for
  example, `Realm-Faction`); never let each provider invent its own key.
- `price[1]` and `price[2]` are minimum and maximum **unit buyout** values in
  copper for the sample. For Auctionator and TSM cached records there is one
  value, so write `{ value, value, nil }`.
- `price[3]` is the stack quantity of the relevant live listing (the listing
  that establishes the minimum when a first-page range is collected). It is
  not the total number of items for sale. A missing or cached stack quantity
  is `nil`; it is a market-status hint, not an input quantity for the planner.
- `source` identifies the last writer: `at` (Auctionator cached data), `tsm`
  (TSM cached data), or `scan` (a live AH observation).
- `updatedAt` is a comparable Unix timestamp. A record replaces an existing
  record only when `new.updatedAt > old.updatedAt`. Equal timestamps are
  ignored; no source-priority tie-breaker is needed.

Put validation and replacement in one `Market:Put(realmKey, itemID, record)`
function. Reject malformed IDs, prices, or timestamps at that boundary so
adapters remain small and deterministic. Keep a `Market:Get` helper that
returns the record and a `Market:GetUnitPrice` helper that returns `price[1]`
plus its source/freshness metadata.

## Runtime data and planner integration

Introduce a small market module (for example `artisan/market.lua`) and load it
before `data.lua` in `artisan/artisan.toc`. On addon load it should:

1. Create/validate `artisanDB.market` and the current realm bucket.
2. After the provider addons are loaded (or on the next login/update event),
   ask each available adapter for cached values for the complete Artisan item
   universe and merge them with `Market:Put`.
3. Report provider availability and record counts to the debug log.

This load pass must not call the planner. Provider adapters must use public
interfaces only:

- **Auctionator adapter:** use `Auctionator.API.v1.GetAuctionPriceByItemID`
  (and `GetAuctionAgeByItemID` when available) and register with
  `RegisterForDBUpdate` for later cache changes. Auctionator's normal-search
  completion can be signalled before its asynchronous DB processing finishes;
  defer the read by one frame (or until the provider callback) before writing
  records.
- **TSM adapter:** use `TSM_API.GetCustomPriceValue("DBMinBuyout", itemString)`
  as the preferred cached value. `DBRecent` may be used only as an explicitly
  labelled fallback because it is a recent-market statistic, not necessarily
  the current minimum. Do not depend on TSM internals or assume TSM exposes a
  public Classic by-item scan API. If TSM has no value, leave the item for the
  other provider/live scanner.

Refactor `data.lua` so each profession DB has a price provider rather than
permanently cached `avgbuyout`/`cost` values. Before every `Planner.BuildPlan`
call, perform a planner-stage refresh that:

- resolves each item price from the current market minimum, falling back to
  the generated static value only when no market value exists;
- recursively recomputes every craftable row's `cost` from those resolved
  prices; and
- updates output `avgbuyout` values used by ROI scoring and summary display.

The refresh is called by the planner model immediately before building (and
when resuming summary values), never by a scanner callback. Unknown prices must
remain distinguishable from a real zero price; they must not silently make a
recipe free. Expose source and age in debug output so a plan can be explained.

## Complete scan universe

Build one deduplicated item-ID set for the selected profession keys. The set
contains:

- every recipe output in `skills[pk]`, including rows that are not currently
  craftable but whose recipes participate in recursive costs;
- every reagent reached recursively from those recipes; and
- every positive `scroll_id` (teaching item) used by a recipe.

`/art scan all` scans the union for all registered professions. A profession
argument such as `eng` or `tailor` scans only that profession's closure. The
collector is shared by cached-load and live-scan paths, ensuring that a future
shopping list cannot accidentally define the price universe.

## Live scan contract

Add a scanner coordinator (for example `artisan/scanner.lua`) with a provider-
neutral callback interface:

```lua
scanner:Start(itemIDs, function(result) ... end)
-- result: { itemID, min, max, stackCount, updatedAt, providerStatus }
```

For each item, normalize the provider's auction rows to unit copper buyout:
`floor(totalBuyout / stackQuantity)`. Ignore zero-buyout/invalid rows and, when
the API exposes an owner, ignore the player's own auctions. Restrict the
sample to the first page of valid listings; record the minimum and maximum unit
prices found and the stack quantity belonging to the minimum listing as
`price[3]`. If no valid listing exists, emit a `no-auction` status and do not
overwrite a newer market record.

Auctionator live searches/full-scan results and the Blizzard/TSM listing view
are adapted behind this contract. Respect AH throttling and asynchronous
events; process one provider operation at a time, show progress, and make a
single `Market:Put(..., source = "scan")` call per completed item. A cancelled,
throttled, or unavailable provider must produce a diagnostic status rather
than a fabricated price.

## `/art scan` debugging command

Extend `artisan/ui/cli.lua` while retaining existing `/art plan` and `/art hide`:

- `/art scan` is exactly `/art scan all`.
- `/art scan all` scans every registered profession's complete item closure.
- `/art scan eng`, `/art scan tailor`, etc. scan one stable profession key.
- Print the selected profession(s), item count, provider in use, progress, and
  a final summary of updated, skipped (newer record), no-auction, unavailable,
  and failed items. For each updated item print item ID, min/max copper,
  stack count, source, and timestamp in debug mode.
- Reject unknown keys with a usage line; do not open the planner or alter
  `ns.store.plans`.
- A second scan request while one is active should report that the scanner is
  busy (or explicitly cancel the prior run); it must not interleave AH queries.

Keep this command as the sole trigger for live scans until a UI is designed.

## Failure and freshness policy

- Missing Auctionator/TSM: continue with available providers and report the
  missing dependency.
- Missing cached value: retain any existing market value; use the static
  fallback only when no market record exists, and mark that fallback in
  diagnostics.
- A scan result with `updatedAt <= old.updatedAt` is ignored by `Market:Put`.
- Never delete a valid record because a provider temporarily returns no data.
- Keep timestamps in seconds and display age (`now - updatedAt`) to make stale
  data visible. A provider's known data age should be converted to its source
  timestamp; when no age is available, use the observation time and state that
  precision in diagnostics.

## Fake client support and tests

Extend `fake-wow/` only with generic API/event stubs needed to exercise the
shared modules; do not add fake-versus-real branches to addon code. Cover:

- market schema validation and `updatedAt > old.updatedAt` replacement,
  including equal and older timestamps;
- realm/faction key stability and item-universe closure (outputs, recursive
  reagents, and teaching scrolls, with duplicate removal);
- Auctionator and TSM adapters with absent addons, cached values, source age,
  and Auctionator's deferred callback behavior;
- live normalization (unit buyout, first-page min/max, minimum-listing stack
  count, zero/own-auction filtering, and no-auction status);
- planner refresh proving a newly written market value changes recursive costs,
  ROI/action selection, and summary values without the scanner invoking a
  replan;
- `/art scan` argument parsing, busy handling, and diagnostic totals.

Run the existing unit/window/resume checks plus these market tests. Keep the
Monte Carlo progression tests deterministic with the static fallback when no
fake market is seeded.

## Suggested implementation order

1. Add the market schema, realm key, merge rule, item-universe collector, and
   migration/validation for existing SavedVariables.
2. Refactor `data.lua` and the planner model to refresh prices/costs at planner
   entry, preserving immutable generated data and explicit unknown-price
   handling.
3. Implement Auctionator and TSM cached adapters and load-time merge logging.
4. Implement the provider-neutral live scanner and fake-wow auction fixtures.
5. Add `/art scan` output, progress, cancellation/busy behavior, and tests.
6. Run the full test suite, then verify in-game with one profession and a
   controlled AH sample before enabling scans for all professions.

## Acceptance criteria

- A clean login imports available Auctionator/TSM cached prices into
  `artisanDB.market` without creating or changing a plan.
- `/art scan` scans the complete selected item closure, writes normalized
  `scan` records, and prints actionable diagnostics; `/art scan all` covers all
  registered professions.
- Every write obeys `new.updatedAt > old.updatedAt`; no source-priority branch
  exists for equal timestamps.
- `price[3]` is always a stack quantity from the selected live listing or
  `nil` for cached sources and is never treated as total inventory.
- Reopening/rebuilding a plan after a scan uses the new market values in output
  prices, recursive costs, ROI, and summaries, while scanning alone never
  triggers planning.
- Generated Era price files remain unchanged by runtime scans, and all tests
  pass in fake-wow and in the live addon load path.
