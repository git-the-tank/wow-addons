# BigWigs Bar Color Override Process

Canonical color system for boss ability timeline bars. Colors are assigned by **player response**, not spell school or boss theme.

## Files

- `BigWigs_Color_Guide.md` — canonical palette, decision rules, design philosophy
- `bigwigs_colors.lua` — spell ID → color category mapping for all bosses
- `gen-bigwigs-colors.py` — generator script that produces SavedVariables overrides

## Full Update Cycle

This is the end-to-end process for when BigWigs or LittleWigs updates (new bosses, mythic abilities added, spell changes, new season rotation, etc).

### Step 1: Update addons on H:

BigWigs and LittleWigs are managed by CurseForge/WowUp/etc. After an addon update lands:

- Open WoW or your addon manager to pull the latest versions
- The updated addons live at:
  - `/mnt/h/World of Warcraft/_retail_/Interface/addons/BigWigs_TheVoidspire/`
  - `/mnt/h/World of Warcraft/_retail_/Interface/addons/BigWigs_TheDreamrift/`
  - `/mnt/h/World of Warcraft/_retail_/Interface/addons/BigWigs_MarchOnQuelDanas/`
  - `/mnt/h/World of Warcraft/_retail_/Interface/addons/LittleWigs/`

### Step 2: Copy updated modules into examples/

```bash
# Raid tiers
rsync -av --delete '/mnt/h/World of Warcraft/_retail_/Interface/addons/BigWigs_TheVoidspire/' examples/BigWigs_TheVoidspire/
rsync -av --delete '/mnt/h/World of Warcraft/_retail_/Interface/addons/BigWigs_TheDreamrift/' examples/BigWigs_TheDreamrift/
rsync -av --delete '/mnt/h/World of Warcraft/_retail_/Interface/addons/BigWigs_MarchOnQuelDanas/' examples/BigWigs_MarchOnQuelDanas/

# Dungeons (LittleWigs — all expansions for season rotation)
rsync -av --delete '/mnt/h/World of Warcraft/_retail_/Interface/addons/LittleWigs/' examples/LittleWigs/
```

Or ask Claude to do it.

### Step 3: Ask Claude to diff for new/changed spells

Tell Claude: "BigWigs updated, check for new spells to color"

Claude will:
1. Read the updated boss modules in `examples/`
2. Compare spell IDs against what's already in `bigwigs_colors.lua`
3. Report any new spells, removed spells, or boss modules not yet covered
4. Classify new spells using `BigWigs_Color_Guide.md` decision rules
5. Update `bigwigs_colors.lua`

### Step 4: Merge into SavedVariables

**IMPORTANT: Confirm you are logged out of your character before merging.** WoW writes SavedVariables on character logout, so merging while logged into a character is useless — the changes get overwritten on next logout. You can be at the character select screen or have WoW fully closed.

```bash
python3 gen-bigwigs-colors.py --merge '/mnt/h/World of Warcraft/_retail_/WTF/Account/PRIESTH8ER/SavedVariables/BigWigs.lua'
```

### Step 5: Verify in-game

Log in and check bars on a boss pull. If wrong:

```bash
python3 gen-bigwigs-colors.py --rollback '/mnt/h/World of Warcraft/_retail_/WTF/Account/PRIESTH8ER/SavedVariables/BigWigs.lua'
```

## When to run this

- **After BigWigs/LittleWigs addon updates** — new spells, mythic abilities, bug fixes
- **New M+ season** — different dungeon rotation means new LittleWigs bosses to cover
- **New raid tier** — new BigWigs raid modules
- **After re-evaluating a color** — edit `bigwigs_colors.lua` directly, re-merge

## Current M+ Season 1 Dungeons

Midnight: Magister's Terrace, Maisara Caverns, Nexus-Point Xenas, Windrunner Spire
Legacy: Algeth'ar Academy (DF), Seat of the Triumvirate (Legion), Skyreach (WoD), Pit of Saron (WotLK)

## Script usage

```bash
# Preview snippet (stdout)
python3 gen-bigwigs-colors.py

# Merge into SavedVariables (creates timestamped .bak automatically)
python3 gen-bigwigs-colors.py --merge <BigWigs.lua path>

# Rollback to most recent backup
python3 gen-bigwigs-colors.py --rollback <BigWigs.lua path>

# Rollback to specific backup
python3 gen-bigwigs-colors.py --rollback <BigWigs.lua path> --from <bakfile>
```

## Color categories

| Color  | Hex     | Brightness | Meaning                              |
|--------|---------|------------|--------------------------------------|
| gray   | #6B7280 | dark       | Default / Info / Phase               |
| red    | #FF3333 | bright     | Raid Damage                          |
| orange | #E67300 | med-high   | Dodge / Move                         |
| yellow | #FFD700 | very bright| Soak / Stack / Positioning           |
| green  | #22BB55 | medium     | Adds / Target Swap / Kicks           |
| blue   | #4488FF | bright     | Knockback / Forced Movement          |
| purple | #BB44EE | medium     | Beams / Debuffs / Magic              |
| brown  | #7A3B10 | low        | Tank Buster / Tank Swap              |

## Classification tips

When reading a BigWigs boss module to classify spells:

- `CL.soak`, `CL.orbs`, `CL.pools`, `CL.marks` with spread sound → **yellow**
- `CL.adds`, "Kicks" label → **green**
- `CL.dodge`, `CL.breath` (if targeted/dodgeable) → **orange**
- `CL.raid_damage`, `CL.full_energy` → **red**
- `CL.knockback` → **blue**
- `{spellID, "TANK"}` or `{spellID, "TANK_HEALER"}` annotation in GetOptions → **brown**
- Beams, dispels, targeted debuffs → **purple**
- Phase markers, berserk, intermission timers → **gray**
- When ambiguous, follow the priority order in `BigWigs_Color_Guide.md`

## What the script touches

The merge only replaces `barColor` and `barEmphasized` tables inside `BigWigs_Plugins_Colors` → `profiles` → `Default`. Everything else is preserved: `barBackground`, `barText`, named color overrides, other profiles, all other namespaces.
