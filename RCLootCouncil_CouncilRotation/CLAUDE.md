# RCLootCouncil - Council Rotation

RCLootCouncil plugin that rotates raid members into temporary council seats each raid night, democratizing the loot council process.

## Dependencies

- **RCLootCouncil** (required) — parent addon, provides council management API
- **GitRaidTools** (optional) — provides raid start time for auto-rotation and mute feature

## Architecture

Ace3 module registered via `addon:NewModule("RCCouncilRotation")`. SavedVariables stored as AceDB namespace under RCLootCouncil's database.

## Files

- `CouncilRotation.lua` — Main module: rotation logic, pool building, council modification, announcements
- `Options.lua` — AceConfig tabbed UI registered under RCLootCouncil settings
- `Locale/enUS.lua` — Localization strings

## Key APIs Used

### RCLootCouncil Council API
```lua
-- Council is array of GUIDs in addon.db.profile.council
table.insert(addon.db.profile.council, guid)
addon:CouncilChanged()  -- Must call after any modification
```

### GitRaidTools Integration
- `GitRaidToolsDB.raidHour/raidMinute/raidDays` — raid schedule
- `GitRaidToolsDB.muted` — announcements suppressed when true

## Slash Commands

- `/rc rotate` — manually trigger council rotation
- `/rc councilrotation` — open options panel

## Options Tabs

1. **General** — Enable/disable, seat count, guild rank selection, auto-rotate toggle
2. **Announcements** — Raid announce template, whisper instruction message, mute indicator
3. **History** — Rotation log with class-colored names, clear/reset buttons

## How Rotation Works

1. Build eligible pool: raid members with selected guild ranks, excluding permanent council and self
2. Filter out anyone already selected this cycle (fair cycling)
3. If all eligible members have been selected, auto-reset the cycle
4. Fisher-Yates shuffle the pool, pick N members
5. Remove previous rotating members from council, add new ones
6. Call `addon:CouncilChanged()` to sync to raid
7. Record in history, announce to raid, whisper instructions

## Constraints

- Requires Master Looter (or group leader) to modify council
- Only one rotation per trigger (no re-rolling without explicit action)
