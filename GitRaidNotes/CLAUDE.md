# GitRaidNotes

Personal raid boss notes and fight reminders for tank/RL.

## Overview

- Compact, always-visible frame with boss fight reminders
- 9 bosses across 3 Midnight S1 raids: Voidspire (6), Dreamrift (1), March on Quel'Danas (2)
- 3 tabs per boss: TANK (mechanics), CALLS (RL callouts), NOTES (scratchpad)
- Auto-detects difficulty via GetInstanceInfo() and boss via ENCOUNTER_START
- Terse, color-coded format using line prefixes: >> swap, [] position, !! defensive, ++ adds, ~~ movement, << calls, ** hero
- User-editable notes with reset-to-default
- LibEditMode for positioning, no Ace3

## Slash Commands

- `/grn` -- toggle frame
- `/grn edit` -- edit current boss/tab
- `/grn lock` -- toggle click-through
- `/grn reset` -- reset current note to default
- `/grn next` / `/grn prev` -- cycle boss
- `/grn diff N|H|M` -- manual difficulty

## File Structure

- `GitRaidNotes.lua` -- Namespace, DB init, slash commands
- `src/BossData.lua` -- Boss roster, encounter IDs, default notes (tank + calls) for all 9 bosses
- `src/Detection.lua` -- Instance/difficulty detection, ENCOUNTER_START auto-boss select
- `src/Frame.lua` -- Main display frame: header, tabs, scrollable colored content, drag
- `src/Editor.lua` -- Edit popup with MultiLineEditBox, save/reset/cancel
- `lib/LibEditMode/` -- Embedded library for Edit Mode integration

## Config

Defaults in `ns.CONFIG`. Runtime values in `ns.db` (SavedVariablesPerCharacter: GitRaidNotesDB).
No settings panel -- all config via slash commands and in-frame editing.

## Note Format

Lines prefixed with markers get auto-colored:
- `>>` Orange -- swap triggers
- `[]` Cyan -- positioning
- `!!` Red -- defensive/danger
- `++` Green -- adds
- `~~` Yellow -- movement
- `<<` White -- raid calls
- `**` Yellow -- hero timing
- `[M]` Purple -- mythic-only
- No prefix: gray continuation text
