# WoW Addon Monorepo

Monorepo for World of Warcraft addons. Retail only (Midnight / 12.x).

## Context Rules

- **Each addon has its own CLAUDE.md** with addon-specific details. Only read into the addon you're actively working on.
- **Do NOT read files from other addon directories** unless explicitly asked. This repo may contain many addons with large files.
- When starting work on an addon, read its CLAUDE.md first.
- **Reference addons live in `examples/`** — use these for patterns, API usage, and code examples. Never browse `/mnt/h/` for addon references.

## Repo Structure

Each top-level directory is a self-contained addon: `AddonName/CLAUDE.md`, `AddonName/AddonName.toc`, etc.

## Scripts

- `./lint.sh [AddonName]` — luacheck static analysis (catch typos, undefined globals, unused vars)
- `./sync.sh [AddonName]` — rsync addon(s) to WoW AddOns folder
- `./watch.sh [AddonName]` — auto-sync on file changes (inotifywait)
- `./backup-wtf.sh [message]` — git backup of WTF/SavedVariables (separate repo)
- `python3 gen-bigwigs-colors.py` — generate BigWigs bar color overrides (see below)

## Development Workflow

1. **Edit** — Make changes to Lua files
2. **Lint** — `./lint.sh [AddonName]` — catch typos, undefined globals, unused vars before loading in-game
3. **Sync** — `./sync.sh [AddonName]` or `./watch.sh [AddonName]` — copy to WoW AddOns folder
4. **Test in-game** — `/reload` in WoW to load changes

Run lint before sync. Fixing a typo in the API name is instant; finding it in-game means a reload cycle, reading the error, guessing the cause, fixing, syncing, reloading again.

## API Changes & Discoveries

- **Read `MIDNIGHT_CHANGES.md`** before working on combat-related or protected API code.
- **Update `MIDNIGHT_CHANGES.md`** whenever you discover a new API change, behavioral difference, or workaround during development. Don't wait — document it immediately so future conversations don't have to rediscover it.
- This includes: protected function changes, new/removed APIs, TOC version bumps, secure handler quirks, taint issues, or anything that differs from pre-Midnight behavior.

## Shared Conventions

- **TOC**: `## Interface` must match current retail build. List files explicitly in load order.
- **Lua**: No globals — use `local AddonName, ns = ...` namespace pattern.
- **Events**: Frame-based `RegisterEvent` / `SetScript("OnEvent", ...)`.
- **Timers**: `C_Timer.After()` over OnUpdate polling.
- **UI**: Relative anchoring only. `hooksecurefunc` over overriding protected funcs.
- **Libs**: `LibStub` for Ace3 and embedded libraries.
- **Naming**: Directories `PascalCase`, locals `camelCase`, SavedVars `AddonNameDB`.
- **Locales**: `enUS` is canonical, others fall back to it.
- **API ref**: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API

## BigWigs Bar Colors

See `BIGWIGS_COLORS.md` for the full process, classification tips, and merge/rollback commands.

Key files: `BigWigs_Color_Guide.md` (palette/rules), `bigwigs_colors.lua` (mappings), `gen-bigwigs-colors.py` (generator).

## Git Commits

Follow `GIT_CONVENTIONS.md`.

## Paths

- WoW AddOns: `/mnt/h/World of Warcraft/_retail_/Interface/addons`
- WTF backup repo: `taco/wow-2024-addons` (GitHub, separate .git)
- This repo: `taco/wow-addons` (GitHub, private)
