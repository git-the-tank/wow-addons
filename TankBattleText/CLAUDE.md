# TankBattleText

POC addon — scrolling combat text for tanks showing incoming damage with full mitigation breakdown.

## Overview

- Parses `UNIT_COMBAT` for damage and miss events targeting the player
- Displays damage with absorbed/blocked/resisted breakdown
- Shows avoidance events (parry, dodge, miss, reflect, deflect, immune)
- Separate stats frame with avoidance %, DTPS, rolling DPS, and combat DPS side by side
- Outgoing DPS tracked via C_DamageMeter API (Midnight 12.x)
- Both frames movable via WoW's HUD Edit Mode (LibEditMode)
- Edit Mode checkboxes to toggle each stat independently
- SavedVariablesPerCharacter: `TankBattleTextDB` (frame positions + stat toggles)

## Slash Commands

- `/tbt` — Toggle display on/off

## File Structure

- `TankBattleText.lua` — Namespace, color constants, slash command, PLAYER_LOGIN init, DB init
- `src/Tracker.lua` — Circular buffers for damage history, averages, spike detection, mitigation rate, outgoing DPS
- `src/Display.lua` — Column-aligned row display (right-aligned numbers + info column), fade system, formatting
- `src/Stats.lua` — Stats frame with 4 toggleable stats: avoidance, DTPS, rolling DPS, combat DPS
- `src/Compat.lua` — Startup workarounds for other addons (BCM positioning fix)
- `src/EditMode.lua` — LibEditMode registration for both frames + 4 stat toggle checkboxes
- `src/Events.lua` — UNIT_COMBAT parsing, DAMAGE_METER_COMBAT_SESSION_UPDATED, combat enter/leave
- `src/Options.lua` — Font/texture lists, global defaults
- `lib/LibEditMode/` — Embedded library for Edit Mode integration (includes LibStub)

## Key Design Decisions

- Uses UNIT_COMBAT over CLEU because CLEU is protected in 12.x
- Custom row pool with two-column FontStrings replaces ScrollingMessageFrame for column alignment
- Stats frame is separate from scrolling damage frame for independent positioning
- Stats use fixed LEFT/RIGHT anchoring so changing numbers don't shift layout
- Both frames registered with LibEditMode for standard WoW Edit Mode positioning
