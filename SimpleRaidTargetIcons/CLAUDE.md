# SimpleRaidTargetIcons

Displays a widget on modifier+left click or double-click on a unit to assign Raid Target Icons.

## Authors

- Original: Zimzarina, Roadblock
- Credits: ghostduke, Brodrick (aka Kirov), Qzot

## Files

- `SimpleRaidTargetIcons.toc` — Addon manifest (Interface 120001)
- `SimpleRaidTargetIcons.lua` — All addon logic (single file)
- `Bindings.xml` — Key binding definitions
- `Locales/` — Localization files (enUS, zhCN, zhTW, deDE, frFR, koKR, ruRU)

## SavedVariables

- `SRTISaved` — per-character settings
- `SRTIExternalUF` — per-character external unit frame config

## Luacheck

Addon-specific globals are declared in the root `.luacheckrc` under `files['SimpleRaidTargetIcons/**']`:
- **SavedVariables**: `SRTISaved`, `SRTIExternalUF`
- **Global table**: `SRTI`
- **Locale strings**: `SRTI_TITLE`, `SRTI_OPTIONS_*`, `SRTI_BINDINGS_*`, `BINDING_NAME_SRTI_*`, etc.
- **Template-created globals**: `SRTIcb*Text`, `SRTIslider*Text`, etc. (created at runtime by WoW UI templates)

## Status

Migrated to this monorepo. Needs Interface version update for Midnight (12.x) when available.
