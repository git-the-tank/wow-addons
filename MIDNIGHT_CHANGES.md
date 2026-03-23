# Midnight (12.x) API & Behavioral Changes

Living document of WoW API changes discovered during Midnight addon development.
Update this as you discover new changes — saves future conversations from relearning.

## Interface Version

- Midnight retail: `120001` (was `110105` in TWW 11.x)
- TOC `## Interface` must use this or the addon shows as "incompatible"

## Protected Functions (Combat Lockdown)

- `SetRaidTarget()` is now **protected** — cannot be called from insecure Lua during combat
  - Workaround under investigation: SecureActionButton with `/tm N` macro, positioned via secure handler restricted Lua
  - Secure handler restricted environment CAN call `SetPoint()`, `Show()`, `Hide()` during combat
  - SRTISmokeTest addon created to validate this approach

## Secure Handler Notes

- `SecureHandlerClickTemplate` snippets run in restricted Lua during combat
- Available in restricted Lua: `self:GetMousePosition()`, `child:SetPoint()`, `child:Show()`, `child:Hide()`
- SecureActionButton with `type="macro"` + `macrotext="/tm N"` can fire protected actions on hardware click
- Status: **implemented** in SRTI — combat ring (`SRTICombatRing`, `SecureHandlerStateTemplate`) with 8 `SRTICombatBtn[1-8]` buttons
  - State driver shows ring when `[combat,mod:X]` matches configured modifiers
  - Pre-positioned static buttons in circle — no dynamic positioning during combat needed
  - Click icon fires `/tm N` macro via `SecureActionButtonTemplate`

## SecureActionButtonTemplate Click Registration

- Must use `RegisterForClicks("AnyDown", "AnyUp")` — registering for only one may not fire
- `SecureActionButton_OnClick` checks the `ActionButtonUseKeyDown` CVar to decide whether to fire on down or up
- If the registration doesn't include the matching click type, the macro/action silently does nothing
- This applies to all SecureActionButton usage, not just our addon
- [WoWUIBugs #282](https://github.com/Stanzilla/WoWUIBugs/issues/282), [WoWUIBugs #268](https://github.com/Stanzilla/WoWUIBugs/issues/268)

## SecureActionButtonTemplate Modifier Attribute Resolution

- `type1`/`macrotext1` attributes are **NOT found** when a modifier key (Ctrl/Alt/Shift) is held during combat
  - The attribute lookup for `type-ctrl-1` does not fall through to `type1` as expected
  - Symptom: `PreClick`/`PostClick` hooks fire but the secure macro action silently does nothing
  - Fix: use `*type1`/`*macrotext1` (star prefix = wildcard, matches any modifier)
  - Example: `btn:SetAttribute("*type1", "macro"); btn:SetAttribute("*macrotext1", "/tm 1")`
  - This is critical when buttons are shown via `[combat,mod:X]` state drivers where the user clicks while holding the modifier
  - Applies to all button numbers (`*type2`/`*macrotext2` for right-click, etc.)

## COMBAT_LOG_EVENT_UNFILTERED Removed for Addons

- `COMBAT_LOG_EVENT_UNFILTERED` **cannot be registered by addons** in 12.x — `RegisterEvent()` throws `ADDON_ACTION_FORBIDDEN`
  - Fails at load time AND deferred (e.g., inside PLAYER_LOGIN handler)
  - Even a full client restart doesn't help — the event is fundamentally blocked
- **Use `UNIT_COMBAT` instead**: `unitTarget, event, flagText, amount, schoolMask`
  - event types: WOUND, DODGE, PARRY, BLOCK, MISS, IMMUNE, RESIST, ABSORB, REFLECT
  - flagText: "-CRITICAL", "-CRUSHING", "-GLANCING", "-BLOCK" etc.
  - Less granular than CLEU (no per-hit absorbed/blocked/resisted breakdown, no spell names/IDs)
  - But it works and fires for all combat in open world + instances
- MidnightBattleText addon (third-party, in repo) confirms UNIT_COMBAT works in 12.x
- Blizzard's stated goal: prevent addons from parsing combat data for decision-making
  - Cosmetic/display addons like SCT still work via UNIT_COMBAT

## C_DamageMeter API

- `C_DamageMeter.GetCombatSessionSourceFromType(sessionIndex, type, guid)` returns outgoing damage data
  - `Enum.DamageMeterType.DamageDone` for damage dealt
  - `source.totalAmount` is a **tainted value** — arithmetic on it directly causes `attempt to perform arithmetic on local (a secret number value tainted by 'AddonName')`
  - `tonumber()` alone does NOT strip taint — it propagates
  - Workaround: `tonumber(tostring(source.totalAmount))` — `tostring()` produces an untainted string, then `tonumber()` parses it back clean
- `C_DamageMeter.ResetAllCombatSessions()` resets accumulated totals
- `DAMAGE_METER_COMBAT_SESSION_UPDATED` event fires when session data changes (during combat)

## Settings.OpenToCategory / OpenSettingsPanel

- `Settings.OpenToCategory()` internally calls `OpenSettingsPanel()` which is **protected** in 12.x
  - Calling from a slash command handler triggers `ADDON_ACTION_BLOCKED` because the chat frame's `ChatEdit_SendText` → `ParseText` execution path is treated as a secure/restricted context
  - Workaround: wrap in `C_Timer.After(0, function() Settings.OpenToCategory(id) end)` to break out of the chat frame's execution path
  - The deferred call runs in a normal insecure context where `OpenSettingsPanel` is allowed

## Aura & Absorb APIs in Combat

Many aura/absorb APIs return nil or SECRET (tainted) values during combat in 12.x. Discovered while building an Ignore Pain absorb bar.

### Blocked in combat

- `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` — returns **nil** in combat (works fine out of combat)
  - Cannot read aura data (points, duration, expirationTime) during combat
  - No error thrown — just silently returns nil
- `UnitGetTotalAbsorbs("player")` — returns a **SECRET/tainted** value in combat
  - `tostring()` on the result throws: `invalid value (secret) at index N in table for 'concat'`
  - Cannot be used for display or arithmetic
  - The `tonumber(tostring(...))` workaround that works for C_DamageMeter does **not** work here — `tostring()` itself errors

### Works in combat

- `CreateUnitHealPredictionCalculator()` + `UnitGetDetailedHealPrediction("player", "player", calc)` + `calc:GetDamageAbsorbs()`
  - Returns a **tainted/secret** number in combat — must strip taint before comparison or arithmetic
  - Use `pcall(format, "%d", secretVal)` then `tonumber()` to get a clean number (see taint stripping below)
  - This is the same API used by UnhaltedUnitFrames/oUF for absorb shields
  - Note: returns total absorbs from ALL shields, not per-spell — no way to isolate a single buff's absorb in combat
  - Create the calculator once at file scope, reuse it each call
- `UNIT_ABSORB_AMOUNT_CHANGED` event — fires in combat when absorb amounts change (e.g., damage taken reduces shield)
- `UNIT_SPELLCAST_SUCCEEDED` event — fires in combat with clean args: `unit, castGUID, spellID`
  - Can detect specific spell casts (e.g., Ignore Pain) and infer buff duration from known constants
  - Useful for timer tracking when aura query is unavailable
- `UNIT_AURA` event — fires in combat (the event itself works, just can't query aura details from it)
- `C_Spell.GetSpellDescription(spellID)` — works out of combat for parsing tooltip values (e.g., max absorb cap)

### Stripping taint from secret numbers

Many combat APIs return "secret number" values that error on comparison, arithmetic, `tostring()`, or `table.concat()`.

- `format("%d", secretVal)` — previously believed to produce untainted strings, but **does NOT reliably strip taint** for absorb APIs. The resulting string and any derived values remain tainted.
- `tostring()` does **NOT** work — it propagates taint or errors
- `tonumber()` alone does **NOT** strip taint
- For `C_DamageMeter` values, `tonumber(tostring(val))` works — but this is API-specific, not a general pattern.

### Workaround: pass tainted values directly to C widgets

**StatusBar:SetValue() accepts tainted numbers.** The C widget code ignores Lua taint and reads the raw number directly. This is the same pattern oUF/UnhaltedUnitFrames use for absorb bars.

Pattern for absorb bars:
1. Parse max absorb from `C_Spell.GetSpellDescription()` (clean, out of combat)
2. `bar:SetMinMaxValues(0, cachedMaxAbsorb)` — clean value
3. `bar:SetValue(rawTaintedAbsorb)` — tainted OK, C widget does the division
4. Hide text overlays during combat (can't format tainted numbers for display)
5. Show text/color interpolation out of combat when `tostring(val)` works

### General absorb tracking pattern

Since aura details are blocked in combat but absorb amounts are readable via heal prediction:
1. Out of combat: use `C_UnitAuras.GetPlayerAuraBySpellID` for full aura data (absorb amount, timer)
2. In combat: use `GetDamageAbsorbs()` for live absorb amount, `UNIT_SPELLCAST_SUCCEEDED` for timer inference
3. Wrap all aura/absorb calls in `pcall` to gracefully handle taint errors
4. Cache the last known `expirationTime` from out-of-combat aura queries for timer continuity
5. Pass tainted absorb values directly to `StatusBar:SetValue()` — C widget handles them fine

## Not Yet Categorized

<!-- Add new discoveries here, then move them to the right section -->
