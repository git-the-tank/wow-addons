# RaidPerformance

Historical raider analytics dashboard powered by Warcraft Logs data. Two-part system: a Node/TypeScript CLI pulls data from WCL and writes to SavedVariables, and the in-game addon displays it.

## What It Does

Gives raid leaders multi-dimensional performance insights:
- **Roster Overview**: all raiders with median parse, trend, consistency, boss count
- **Boss Detail**: select a boss, see every raider's performance on it with vs-raid-average
- **Player Detail**: click a player, see per-boss breakdown with recent parse history
- **Tooltip**: hover a raid member for quick parse summary

## Architecture

```
Companion CLI (tools/raid-perf/)      In-Game Addon (RaidPerformance/)
  Blizzard API -> guild roster          Reads RaidPerformanceData from SavedVariables
  WCL API v2   -> parse data            Displays dashboard, tooltips
  Computes metrics (median, trend)      No external dependencies
  Writes .lua to WTF/SavedVariables     Pure WoW API
```

## File Structure

- `RaidPerformance.toc` — addon manifest
- `RaidPerformance.lua` — namespace, events, slash commands, data loading
- `src/Colors.lua` — WCL parse color mapping, formatting helpers
- `src/Dashboard.lua` — main dashboard frame, tab system, row pool
- `src/RosterView.lua` — roster overview with sortable columns
- `src/BossView.lua` — per-boss breakdown with boss selector dropdown
- `src/PlayerView.lua` — per-player view with all bosses + recent parses
- `src/Tooltip.lua` — GameTooltip hook for raid members

## Slash Commands

- `/rp` — toggle dashboard
- `/rp roster` — roster overview
- `/rp boss <name>` — boss detail (fuzzy matches)
- `/rp player <name>` — player detail (fuzzy matches)
- `/rp help` — list commands

## SavedVariables

- `RaidPerformanceData` (global) — written by companion CLI, contains all WCL data
- `RaidPerformanceDB` (per-character) — user settings (tooltipEnabled, etc.)

## Key APIs Used

- `TooltipDataProcessor.AddTooltipPostCall` — tooltip hook
- `UIDropDownMenu*` — boss selector
- `RAID_CLASS_COLORS` — class coloring
- Standard frame/fontstring/scrollframe APIs

## Companion CLI

Lives in `tools/raid-perf/`. See its own README for setup.

Commands:
- `npx tsx src/cli.ts roster` — show filtered guild roster
- `npx tsx src/cli.ts sync` — pull WCL data and write SavedVariables
- `npx tsx src/cli.ts sync --dry-run` — write to local file instead

## Workflow

1. Run `npx tsx src/cli.ts sync` from `tools/raid-perf/`
2. Start WoW or `/reload` to pick up new data
3. `/rp` in-game to open dashboard
