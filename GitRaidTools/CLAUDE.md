# GitRaidTools

Raid countdown timer and guild invite announcer.

## Overview

- Countdown timer: displays "Raid in MM:SS" 30 minutes before configured raid time on configured weekdays
- Invite announcer: posts themed raid invite to guild chat with rotating flavor text
- Both features share raid time config (raidHour, raidMinute, raidDays)
- Settings panel accessible via `/grt config` (General, Invites, Countdown subcategories)
- Countdown is dismissible via X button; re-shows on zone change or /reload
- Countdown frame movable via WoW's HUD Edit Mode (LibEditMode)
- SavedVariablesPerCharacter: GitRaidToolsDB (all settings, position, unseen pool)

## Slash Commands

- `/grt` — Show help
- `/grt config` — Open settings panel
- `/grt inv [n]` — Send raid invite to guild chat (optional variation index)
- `/grt render [n]` — Preview invite locally
- `/grt flavor` — Show all flavor text variations in copyable popup
- `/grt unseen` — Show unseen variation pool status
- `/grt clear` — Reset unseen pool

## File Structure

- `GitRaidTools.lua` — Namespace, DB init, slash commands, shared CONFIG defaults
- `src/Countdown.lua` — Countdown timer frame, synthetic seconds, Edit Mode registration
- `src/Invite.lua` — Raid invite announcer, flavor text variations, unseen pool, copy frame
- `src/Options.lua` — Settings panels (General, Invites, Countdown), font discovery, UI helpers
- `lib/LibEditMode/` — Embedded library for Edit Mode integration (includes LibStub)

## Config

Defaults in `ns.CONFIG` (GitRaidTools.lua). Runtime values stored in `ns.db` (SavedVariables).
Settings panel writes to `ns.db`; defaults applied on PLAYER_LOGIN for any missing keys.
