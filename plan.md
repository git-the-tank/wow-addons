# GRT Gear Audit Feature — Implementation Plan

## Overview

Add a gear audit window to GitRaidTools that scans raid members and shows a quick visual report of item levels, tier set pieces, and enhancement compliance (enchants/gems). Opened via `/grt audit`. Fully independent — no MRT dependency.

## Decisions Made

- **Gear enchants/gems only** — consumables (flask, food, oil) deferred; data model will accommodate them later
- **Own inspection scan** — uses WoW's `NotifyInspect()` API directly, no MRT coupling
- **Hardcoded Midnight tier IDs** — ~65 item IDs (5 slots × 13 classes), updated each tier
- **Slash command only** — `/grt audit` opens the window and starts scanning

---

## New Files

| File | Purpose |
|------|---------|
| `src/AuditData.lua` | Enhancement data tables (enchant IDs, gem IDs, tier item IDs, socket bonus IDs), evaluation functions, item link parsing |
| `src/Audit.lua` | Scan engine (inspect queue, event handling), UI frame (table display, mode tabs), slash command handler |

Both added to `GitRaidTools.toc` before `Options.lua`. Settings for the audit added to the existing Options.lua as a new subcategory.

## Modified Files

| File | Change |
|------|--------|
| `GitRaidTools.toc` | Add `src\AuditData.lua` and `src\Audit.lua` to load list |
| `GitRaidTools.lua` | Add audit config defaults to `ns.CONFIG`, add `/grt audit` to slash router |
| `src/Options.lua` | Add "Audit" subcategory panel with enhancement threshold settings |

---

## Phase 1: Data Foundation — `src/AuditData.lua`

### Enchantable Slots for Midnight

Based on MRT's `isSlotForEnchant` logic (InspectViewer.lua:1397-1409), verified for level 81+:

```
Back(15), Chest(5), Wrist(9), Legs(7), Feet(8), Ring1(11), Ring2(12), Weapon(16), Offhand(17*)
```

*Offhand only for dual-wield specs (from MRT's `specHasOffhand` table: Arms, Fury, Frost DK, Unholy DK, all three Rogues, Enhancement, Brewmaster, Windwalker, Havoc, Vengeance).

### Data Tables

**`ns.ENCHANT_DATA`** — Maps enchant ID → `{ level = "low"|"high", quality = 1|2|3 }`

Source: MRT's IS_MN block (InspectViewer.lua:132-179). The 7948-8047 range are enchant IDs. IDs also in `topEnchGemsCheap` are `level = "low"`, others are `level = "high"`. Quality values transfer directly. Also includes DK runeforging IDs (3368, 3370, 3847) which always pass.

**`ns.GEM_DATA`** — Maps gem item ID → `{ level = "low"|"high", quality = 1|2|3 }`

Source: Same IS_MN block. The 240855-240983 range are gem item IDs. Same cheap/non-cheap → low/high mapping.

**`ns.TIER_ITEMS`** — Maps item ID → set key string

Hardcoded ~65 entries for current Midnight tier. 5 tier slots (Head, Shoulder, Chest, Hands, Legs) × 13 classes. Need to source from Wowhead game data. Structure: `[itemID] = "CLASS_T1"`.

**`ns.SOCKET_BONUS_IDS`** — Maps bonus ID → `true`

Copied from MRT InspectViewer.lua:59-118. Used to detect whether an item has a gem socket via its bonus IDs in the item link.

**`ns.ENCHANTABLE_SLOTS`** — Ordered list of slot IDs that should have enchants:
`{ 15, 5, 9, 7, 8, 11, 12, 16, 17 }` (Back, Chest, Wrist, Legs, Feet, Ring1, Ring2, MH, OH)

**`ns.DUAL_WIELD_SPECS`** — Set of spec IDs that use an offhand weapon (from MRT's `specHasOffhand`).

**`ns.SLOT_NAMES`** — Display names: `{ [15] = "Back", [5] = "Chest", ... }`

**`ns.TIER_SLOTS`** — `{ 1, 3, 5, 10, 7 }` (Head, Shoulder, Chest, Hands, Legs)

### Evaluation Functions

```lua
-- Parse item link into components
ns.ParseItemLink(link) → { itemID, enchantID, gems = {id, id, ...}, bonusIDs = {id, ...} }

-- Check if enchant meets current threshold settings
ns.EvaluateEnchant(enchantID, slotID) → "pass" | "fail"
  - DK runeforging IDs always pass
  - Look up in ENCHANT_DATA
  - Compare level against ns.db.auditEnchantLevel
  - Compare quality against ns.db.auditEnchantMinQuality
  - Unknown ID with enchantID > 0 = "pass" (assume valid, avoids false negatives from incomplete data)
  - enchantID == 0 = "fail"

-- Check if gem meets current threshold settings
ns.EvaluateGem(gemID) → "pass" | "fail"
  - Same pattern as enchant evaluation but using GEM_DATA and gem settings
  - Unknown gem ID > 0 = "pass"

-- Check if item has unfilled gem socket
ns.HasEmptySocket(link) → boolean
  - Parse bonusIDs from link, check against SOCKET_BONUS_IDS
  - Count sockets from bonus IDs, compare to gem count in link

-- Get item level from tooltip
ns.GetItemIlvlFromTooltip(unit, slotID) → number
  - Use C_TooltipInfo.GetInventoryItem(unit, slotID)
  - Parse ITEM_LEVEL pattern from tooltip lines
```

---

## Phase 2: Scan Engine — `src/Audit.lua` (first half)

### Scan State

```lua
ns.auditData = {}         -- name → scan result table
ns.auditQueue = {}        -- ordered list of names to inspect
ns.auditScanActive = false
ns.auditScanCurrent = nil -- name currently being inspected
ns.auditScanTicker = nil  -- C_Timer ticker handle
ns.auditScanCount = 0     -- completed count for progress display
ns.auditScanTotal = 0     -- total to scan
```

### Scan Result Per Player

```lua
{
    name = "Playername",
    class = "WARRIOR",         -- English token for RAID_CLASS_COLORS
    spec = 71,                 -- spec ID (for offhand detection)
    avgIlvl = 623.45,          -- average equipped ilvl (2 decimal places)
    itemIlvl = { [1] = 626, [5] = 619, ... },  -- per-slot ilvl
    tierCount = 3,             -- tier pieces equipped (0-5)
    tierSlots = { [1] = true, [5] = true, [7] = true },
    enchants = { [15] = "pass", [5] = "fail", ... },  -- per enchantable slot
    gems = { filled = 3, sockets = 4, passing = 2 },  -- gem summary
    status = "scanned",        -- "pending" | "scanning" | "scanned" | "failed" | "offline"
}
```

### Scan Flow

1. **`ns.StartAuditScan()`**:
   - Check `IsInRaid()` or `IsInGroup()` — bail with message if solo
   - Build queue from `GetNumGroupMembers()` + `UnitName("raid"..i)` / `UnitName("party"..i)`
   - Include `"player"` (self — can read own gear without NotifyInspect)
   - Initialize each entry with `status = "pending"`
   - Set `auditScanActive = true`
   - Start ticker: `C_Timer.NewTicker(1.5, ScanNext)`

2. **`ScanNext()`** (ticker callback):
   - If no pending entries, cancel ticker, set `auditScanActive = false`, done
   - Pop next pending name
   - If name is player: call `ProcessPlayerData(name, "player")` directly (no inspect needed)
   - Else: check `CanInspect(name)` — if false, mark "failed", continue
   - Call `NotifyInspect(name)`, set `status = "scanning"`, store `auditScanCurrent = name`

3. **`INSPECT_READY` event handler**:
   - `C_Timer.After(0.5, function() ProcessInspectData(auditScanCurrent) end)`
   - The 0.5s delay lets item data populate (MRT uses 0.65-1.3s)

4. **`ProcessInspectData(name)`**:
   - `unit = "raid"..N` (find the unit ID for this name)
   - Iterate all 16 equipment slots via `GetInventoryItemLink(unit, slotID)`
   - For each item: parse link, extract ilvl, check tier set membership, evaluate enchant, evaluate gems
   - Compute `avgIlvl` as sum / 16 (2H weapon counts for both 16 and 17)
   - Count tier pieces, evaluate enchantable slots, summarize gems
   - Store in `ns.auditData[name]`, set `status = "scanned"`
   - Increment `auditScanCount`, call `ns.RefreshAuditUI()`

5. **`ClearInspectData()`**: Called after processing to free the inspection slot

### Combat Handling

- On `PLAYER_REGEN_DISABLED` (enter combat): pause ticker (cancel it, set flag)
- On `PLAYER_REGEN_ENABLED` (leave combat): restart ticker if scan was in progress

### Self-Inspection

For the player character, use `"player"` as the unit — `GetInventoryItemLink("player", slotID)` works without NotifyInspect. Process immediately, no queue delay.

---

## Phase 3: UI Frame — `src/Audit.lua` (second half)

### Window Structure

```
┌─ GRT Gear Audit ────────────────────────────────── [X] ┐
│ [Scan]  Scanning... 7/20     [iLvl] [Tier] [Ench]      │
│─────────────────────────────────────────────────────────│
│ Name          iLvl   Back Chest Wrist Legs Feet R1 R2 W │  ← header row
│─────────────────────────────────────────────────────────│
│ Playername    623.45  ✓    ✓     ✓    ✓    ✓   ✓  ✓  ✓ │  ← class-colored
│ Otherguy      618.12  ✓    ✗     ✓    ✓    ✗   ✓  ✓  ✓ │
│ ...                                                      │
│ (scrollable)                                             │
└─────────────────────────────────────────────────────────┘
```

### Frame Details

- **Main frame**: `BackdropTemplate`, ~750×450, centered, movable (via title bar drag), closeable
- **Backdrop**: Same dark tooltip style as Invite.lua copy frame (`UI-Tooltip-Background`, `UI-Tooltip-Border`)
- **Title**: "GRT Gear Audit" FontString, left side of title bar
- **Close button**: `UIPanelCloseButtonNoScripts` template, top-right
- **Scan button**: Standard button template, triggers `ns.StartAuditScan()`
- **Progress text**: FontString next to scan button, "Scanning... 7/20" or "Complete" or "Idle"
- **Mode tabs**: Three text buttons (iLvl / Tier / Ench), active one highlighted, switch column sets

### Scroll Area

- `UIPanelScrollFrameTemplate` with a scroll child frame
- Row pool: 30 pre-created row frames (enough for mythic + bench without recycling complexity)
- Each row: 110px name cell + up to 11 value cells at ~45px each
- Alternating row background: subtle dark/darker bands for readability

### Column Sets by Mode

**iLvl mode**: Name, Avg iLvl, then per-slot iLvl for all 16 slots (scrollable width)
- iLvl color coding: compare to raid average — green if ≥ avg, yellow if within 10, red if > 10 below

**Tier mode**: Name, Avg iLvl, Tier Count (0-5), then iLvl for each of the 5 tier slots (Head, Shoulder, Chest, Hands, Legs)
- Tier count color: green 4-5, yellow 2-3, red 0-1

**Ench mode** (default): Name, Avg iLvl, one column per enchantable slot (Back, Chest, Wrist, Legs, Feet, R1, R2, Wpn), plus Gems summary column
- ✓ in green (`|TInterface/RaidFrame/ReadyCheck-Ready:0|t`) for pass
- ✗ in red (`|TInterface/RaidFrame/ReadyCheck-NotReady:0|t`) for fail
- "—" in gray for not applicable (e.g., no offhand for 2H spec)
- Gems column: "3/4" format (passing/total sockets)

### Row Sorting

Sort by: class name alphabetically, then player name alphabetically within class. This groups same-class players together for quick scanning.

### Row Population

`ns.RefreshAuditUI()`:
1. Collect all entries from `ns.auditData`
2. Sort by class + name
3. For each entry, populate a row from the pool
4. Set name text with class color: `"|c" .. RAID_CLASS_COLORS[class].colorStr .. name .. "|r"`
5. Set value cells based on active mode
6. Hide unused rows
7. Update scroll child height

### Pending/Failed States

- Players still scanning: show name + "..." in gray italic
- Failed (out of range, offline): show name + "Out of range" in red

---

## Phase 4: Config & Settings

### New Defaults in `ns.CONFIG` (GitRaidTools.lua)

```lua
auditEnchantLevel = "high",       -- "low" or "high"
auditGemLevel = "high",           -- "low" or "high"
auditEnchantMinQuality = 1,       -- 1, 2, or 3
auditGemMinQuality = 1,           -- 1, 2, or 3
```

### Slash Command (GitRaidTools.lua)

Add to the slash router:
```lua
elseif cmd == "audit" then
    ns.ToggleAuditWindow()
```

And add to help text.

### Options Subcategory (Options.lua)

New "Audit" subcategory panel after "Dispatch" with:

- **Header**: "Enhancement Thresholds"
- **Dropdown**: Enchant Level — "Low Level (any)" / "High Level"
- **Dropdown**: Min Enchant Quality — "★ (Rank 1)" / "★★ (Rank 2)" / "★★★ (Rank 3)"
- **Dropdown**: Gem Level — "Low Level (any)" / "High Level"
- **Dropdown**: Min Gem Quality — "★ (Rank 1)" / "★★ (Rank 2)" / "★★★ (Rank 3)"
- **Label**: Dynamic text showing current setting in plain English, e.g., "Checking for: High-level enchants, any quality; High-level gems, any quality"

Changing these settings calls `ns.RefreshAuditUI()` if the window is open (live update).

---

## Phase 5: Polish & Edge Cases

- **2H weapons**: If player has a 2H weapon (slot 17 empty or not a weapon), skip OH enchant check — show "—"
- **DK runeforging**: Enchant IDs 3368, 3370, 3847 always pass (not in the enchant quality system)
- **Cross-realm names**: Store full "Name-Realm" as key, display short name only
- **Stale data**: If scan data is > 5 min old, dim the row slightly and show age in tooltip
- **Empty raid**: If not in a group, print a message instead of opening an empty window
- **Rescan**: Clicking "Scan" while window is open re-scans all players (clears old data first)
- **GROUP_ROSTER_UPDATE**: If roster changes while window is open, add new players as "pending" but don't remove departed ones (so you can still see their data)

---

## Implementation Order

1. `src/AuditData.lua` — data tables + evaluation functions (can be tested with known item links)
2. `src/Audit.lua` scan engine — inspect queue + data collection
3. `src/Audit.lua` UI frame — display with all three modes
4. `GitRaidTools.lua` + `GitRaidTools.toc` — config defaults, slash command, TOC entries
5. `src/Options.lua` — Audit settings subcategory
6. Lint + sync + in-game testing

## Data Population Note

The enchant/gem ID tables need to be populated from MRT's IS_MN data block (InspectViewer.lua:132-179) with the cheap/non-cheap distinction applied. The tier item IDs need to be sourced from Wowhead for the current Midnight raid tier. I'll extract the MRT data programmatically and ask for the tier set item IDs.

---

## Pre-Mortem: What Went Wrong

### 1. INSPECT_READY Never Fires (Queue Stall)

**Scenario**: `NotifyInspect()` silently fails — player is loading, phased, or the server drops the request. Our ticker called NotifyInspect and is waiting for INSPECT_READY, but it never comes. The entire scan stalls on one player forever.

**Fix**: Add a per-inspection timeout. When we call `NotifyInspect()`, record `GetTime()`. In the next ticker tick (1.5s later), if we're still in "scanning" state for that player, mark them "failed" and move on. The ticker itself acts as the timeout — no separate timer needed.

### 2. INSPECT_READY Fires for Wrong Player (Data Crosswire)

**Scenario**: Another addon (MRT, Details, oInspect) or the player opening the inspect panel calls `NotifyInspect()` for a different target. We receive INSPECT_READY with someone else's GUID. If we blindly process it, we store wrong data under the wrong name.

**Fix**: INSPECT_READY passes a GUID argument. When we call `NotifyInspect()`, store the expected GUID via `UnitGUID(unit)`. In the INSPECT_READY handler, compare the received GUID against expected. If mismatch: ignore the event, and re-queue our current target for retry on the next tick.

### 3. GetInventoryItemLink Returns Nil After INSPECT_READY

**Scenario**: INSPECT_READY fires but item data isn't fully cached yet. `GetInventoryItemLink()` returns nil for some slots, giving us incomplete data. The 0.5s delay helps but isn't a guarantee.

**Fix**: After the delay, count how many non-nil items we got. If < 12 (most characters have 15-16 items), wait another 0.5s and retry once. If still incomplete after retry, process what we have — some data is better than none. Empty slots legitimately exist (e.g., no offhand for 2H users), so don't require all 16.

### 4. Old-Expansion Enchants Pass as "Unknown" (False Negatives)

**Scenario**: A player has a TWW enchant from last expansion. Its enchant ID isn't in our Midnight ENCHANT_DATA table. The current plan says "unknown ID > 0 = pass" which means old/bad enchants silently pass. This defeats the audit's purpose.

**Fix**: Change the three-state evaluation to include "unknown":
- `"pass"` — known enchant that meets threshold
- `"fail"` — no enchant (ID = 0) or known enchant below threshold
- `"unknown"` — non-zero ID not in our data table

Display "unknown" as a yellow "?" in the UI. This tells the raid leader "something is enchanted but I can't verify the quality — inspect manually." Avoids both false positives and false negatives.

Also: include TWW-era enchant/gem IDs in our data tables as `level = "low"` (sourced from MRT's `topEnchGemsCheap`). This way, last-expansion enchants properly fail the "high level" check instead of being unknown.

### 5. Scan Takes 30+ Seconds for a Full Raid

**Scenario**: User expects "fast audit at start of raid." With 1.5s per player and 20 players, the scan takes 30 seconds minimum. This feels slow.

**Mitigations** (not a single fix — multiple improvements):
- Self-scan is instant (no NotifyInspect needed) — always process "player" first
- Reduce ticker interval to 1.0s (MRT uses 1.0s in force mode, safe)
- Skip offline/out-of-range players immediately (no wasted ticks)
- Show data progressively as each player completes — user can start reading before scan finishes
- Sort completed players to the top, pending to the bottom

### 6. iLvl Mode Is Unusably Wide (16 Slot Columns)

**Scenario**: Showing per-slot ilvl for all 16 equipment slots at 45px each = 720px of columns + name = 830px+ total. Doesn't fit on 1080p screens. Even if it fits, it's a wall of numbers nobody wants to read.

**Fix**: Redesign iLvl mode. Show: Name, Avg iLvl, Lowest Slot iLvl + which slot, Highest Slot iLvl + which slot. That's 4 columns — compact and actually useful. If the user wants per-slot detail, they can hover for a tooltip showing the full breakdown. The point of the audit is flagging problems fast, not displaying every number.

### 7. Ticker Runs During Combat (Taint/Error)

**Scenario**: Player enters combat while scan is running. `NotifyInspect()` might be protected in combat (needs verification), and even if it isn't, inspection API calls during combat could taint the action queue, causing "interface action failed" errors.

**Fix**: Register `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`. On combat start: cancel ticker immediately, store remaining queue. On combat end: restart ticker with remaining queue. Already in the plan but elevating priority — this must be in the initial implementation, not polish.

### 8. 40-Person Raids Exceed Row Pool

**Scenario**: Community events, legacy raids, or large flex groups can have up to 40 players. The plan's 30-row pool runs out, and players 31-40 aren't displayed.

**Fix**: Use 40 rows (WoW's hard cap for raid size). The memory cost is trivial — 40 frames with FontStrings is nothing. If the group is somehow larger (e.g., world boss groups where GetNumGroupMembers returns high numbers), cap at 40 and note "showing first 40."

### 9. Cross-Realm Name Inconsistency

**Scenario**: `UnitName("raid5")` returns `"Name", "Realm"` (two return values) for cross-realm, or `"Name", nil` for same realm. If we use `UnitFullName()` vs `UnitName()` inconsistently, our lookup keys don't match, and we can't find the player's data.

**Fix**: Build a canonical name function early:
```lua
local function FullName(unit)
    local name, realm = UnitName(unit)
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end
```
Use this everywhere. Store `fullName` as key, store `shortName` for display. Also store `unitID` ("raid5") in the scan result so we don't have to reverse-lookup later.

### 10. RefreshAuditUI Hammers Performance During Scan

**Scenario**: `RefreshAuditUI()` rebuilds all rows from scratch. Called once per player scanned = 20 times during a scan. Each call re-sorts, re-populates all rows, recalculates scroll height. On a slow machine, this causes visible stuttering.

**Fix**: Two-tier refresh:
- `UpdateSingleRow(name)` — called after each player scan, only touches that one row. No re-sort.
- `RefreshAuditUI()` — full rebuild. Called on: mode change, settings change, scan complete, window open.

During scanning, use `UpdateSingleRow`. After scan completes, do one final `RefreshAuditUI()` to sort everything properly.

---

## Edge Cases Walkthrough

### Empty Gear Slot
- `GetInventoryItemLink()` returns nil
- **iLvl**: Skip slot in average calculation, count only equipped slots (divide by equipped count, not 16)
- **Tier**: nil slot can't be tier — no action
- **Ench**: If the slot is enchantable (e.g., Ring2) but empty, show "—" not "✗" (can't enchant what isn't there)
- **ilvl average**: What if someone has only 1 item equipped (naked toon)? Guard: if equipped < 1, show 0.00

### Player Is Self
- No `NotifyInspect` needed — use `"player"` unit directly
- `GetInspectSpecialization()` doesn't work on self — use `GetSpecializationInfo(GetSpecialization())` instead
- Process first (instant), shown at top of results

### Dual-Wield vs 2H vs Ranged
- **2H users**: Slot 17 (OH) is empty or a held-in-offhand (not a weapon). Don't flag missing OH enchant.
- **Check**: `ns.DUAL_WIELD_SPECS[spec]` — if false, skip slot 17 enchant check (show "—")
- **Tanks with shield**: Shield in slot 17 — shields aren't enchantable in Midnight. Show "—" for OH.
- **DK runeforging**: Detected by enchant ID (3368, 3370, 3847). Always "pass" regardless of settings.

### Player Leaves Mid-Scan
- If a player leaves raid while we're scanning them: `GetInventoryItemLink(unit)` returns nil for all slots
- INSPECT_READY may never fire
- **Guard**: The timeout in point 1 catches this. Also check `UnitExists(unit)` before processing.

### Player Joins Mid-Scan
- `GROUP_ROSTER_UPDATE` fires
- Don't re-queue everyone — just add the new player as "pending" if scan is active
- Don't remove departed players from `ns.auditData` (their data is still useful to view)

### No Sockets on Any Gear
- Gem summary shows "0/0" — all items lack sockets
- This is valid (no action needed), display as gray "—" not "0/0"

### All Enchants Unknown
- If our data tables are completely outdated (new patch, all new enchant IDs), everything shows yellow "?"
- This is correct behavior — signals that data tables need updating
- Consider: log a message once per session "GRT: Some enchant IDs not recognized — data tables may need updating"

### Inspecting Yourself While Scan Runs
- If the player opens Blizzard's inspect panel on themselves during our scan, it doesn't call NotifyInspect, so no conflict
- If they inspect another player via Blizzard UI: handled by GUID check (point 2 above)

---

## Code Quality Audit

### 1. DRY: Shared Evaluation Function

The plan has separate `EvaluateEnchant()` and `EvaluateGem()` with near-identical logic. Factor out:

```lua
local function EvaluateEnhancement(id, dataTable, levelSetting, minQuality)
    if id == 0 then return "fail" end
    if ns.DK_RUNE_IDS[id] then return "pass" end  -- only relevant for enchants, harmless for gems
    local data = dataTable[id]
    if not data then return "unknown" end
    if levelSetting == "high" and data.level == "low" then return "fail" end
    if data.quality < minQuality then return "fail" end
    return "pass"
end

function ns.EvaluateEnchant(enchantID)
    return EvaluateEnhancement(enchantID, ns.ENCHANT_DATA, ns.db.auditEnchantLevel, ns.db.auditEnchantMinQuality)
end

function ns.EvaluateGem(gemID)
    return EvaluateEnhancement(gemID, ns.GEM_DATA, ns.db.auditGemLevel, ns.db.auditGemMinQuality)
end
```

### 2. Scan State: Group Into a Table

Loose `ns.auditScanActive`, `ns.auditQueue`, `ns.auditScanCurrent`, etc. pollute the namespace. Group them:

```lua
ns.scan = {
    active = false,
    queue = {},
    current = nil,      -- { name, unit, guid }
    ticker = nil,
    count = 0,
    total = 0,
}
```

Benefits: easy to reset (`wipe(ns.scan)` + re-set defaults), clear ownership, self-documenting. `ns.auditData` stays separate since it persists across scans.

### 3. Unit ID Mapping: Build Once, Reuse

Don't reverse-lookup "which raidN is this name?" repeatedly. Build a name→unitID map at scan start:

```lua
ns.scan.units = {}  -- fullName → unitID
for i = 1, GetNumGroupMembers() do
    local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
    local name = FullName(unit)
    if name then ns.scan.units[name] = unit end
end
ns.scan.units[FullName("player")] = "player"
```

### 4. Data Table Comments

AuditData.lua will be a wall of numeric IDs. Each group must have a comment:

```lua
ns.ENCHANT_DATA = {
    -- DK Runeforging (always pass, handled separately)
    -- Weapon enchants: Authority of... (Midnight)
    [7972] = { level = "high", quality = 2 }, -- Authority of Air
    [7973] = { level = "high", quality = 3 },
    ...
    -- Ring enchants: Radiant (Midnight)
    [7948] = { level = "high", quality = 2 },
    ...
    -- Previous expansion (TWW) — flagged as "low" for threshold checks
    [7596] = { level = "low", quality = 1 },
    ...
}
```

### 5. Data Version Guard

Add a constant for when data was last updated:

```lua
ns.AUDIT_DATA_PATCH = "12.0.5"  -- Last updated for this patch
ns.AUDIT_DATA_INTERFACE = 120001
```

On PLAYER_LOGIN, check `select(4, GetBuildInfo())` against this. If game interface > data interface, print a one-time warning:
"GRT Audit: Enchant/gem data was built for patch 12.0.5 — some new items may show as unknown."

### 6. Avoid Frame Pollution

Don't create named global frames unnecessarily. The audit window doesn't need a global name (nobody externally references it). Use:
```lua
local auditFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
ns.auditFrame = auditFrame  -- accessible via namespace only
```

Only create a global name if we need it for slash command toggle or similar. Even then, prefer `ns.auditFrame` over `GitRaidToolsAudit`.

### 7. Row Pool: Lazy Creation

Don't pre-create 40 rows at addon load time — create them on first use. The audit window may never be opened in most play sessions. Use a simple pool:

```lua
local rows = {}
local function GetRow(index)
    if not rows[index] then
        rows[index] = CreateRow(index)  -- create frame, font strings, textures
    end
    return rows[index]
end
```

This also avoids the "how many to pre-create?" question entirely.

### 8. iLvl Average: Count Equipped Slots, Not Fixed 16

The original plan divides by 16. But a player with an empty slot (or using a 2H weapon with no offhand) would get a deflated average. MRT divides by 16 too, but that's because they count 2H weapons double. Be explicit:

```lua
local total, count = 0, 0
for _, slotID in ipairs(ALL_SLOTS) do
    local ilvl = data.itemIlvl[slotID]
    if ilvl and ilvl > 0 then
        total = total + ilvl
        count = count + 1
        -- For 2H: if slot 16 has a 2H and slot 17 is empty, count slot 16 twice
        if slotID == 16 and not ns.DUAL_WIELD_SPECS[data.spec] then
            total = total + ilvl
            count = count + 1
        end
    end
end
data.avgIlvl = count > 0 and (total / count) or 0
```

This gives the same result as the character sheet's average ilvl.

---

## Revised Implementation Order

1. `src/AuditData.lua` — data tables (with comments, version guard, TWW fallback IDs) + shared evaluation function
2. `src/Audit.lua` scan engine — scan state table, unit mapping, inspect queue with timeout + GUID check, combat pause, progressive data collection
3. `src/Audit.lua` UI — lazy row pool, two-tier refresh, three modes (with redesigned compact iLvl mode), "unknown" yellow indicator
4. `GitRaidTools.lua` + `GitRaidTools.toc` — config defaults, slash command, TOC
5. `src/Options.lua` — Audit settings subcategory
6. Lint + sync + in-game test
