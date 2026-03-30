# Git Commit Conventions

## Format

```
Prefix: Short description of change
```

**Prefix** is the addon abbreviation (see registry below) or `repo` for cross-cutting changes.

## Examples

```
SRTI: Add party frame support
SRTI: Fix nil error when solo
repo: Update lint config
repo: Add new addon scaffold script
```

## Rules

1. **One addon per commit** — if a change spans multiple addons, make separate commits.
2. **Prefix is required** — every commit starts with `Abbrev:` or `repo:`.
3. **Imperative mood** — "Add feature" not "Added feature" or "Adds feature".
4. **Short subject** — aim for under 60 characters after the prefix.
5. **Body is optional** — use it for _why_, not _what_ (the diff shows what).

## Addon Abbreviation Registry

| Addon | Abbreviation |
|-------|-------------|
| SimpleRaidTargetIcons | SRTI |
| TankBattleText | TBT |
| GitRaidTools | GRT |
| RCLootCouncil_CouncilRotation | RCRC |

When adding a new addon, register its abbreviation here.

## Cross-Cutting Prefixes

| Prefix | Use for |
|--------|---------|
| `repo` | Scripts, CI, root config, documentation, multi-addon tooling |

## Releases & Changelogs

Each addon that gets published (e.g. to wago.io) maintains a `CHANGELOG.md` in its directory.

- **Format:** `## X.Y.Z — Title` followed by bullet points.
- **When to update:** Every version bump / release. Add the new section at the top.
- **Purpose:** Copy-paste into wago.io (or other distribution site) release notes.
- Bump the `## Version` in the `.toc` file to match.

## Workflow

- No PRs — commit and push directly to main.
- Use simple `git commit -m "subject" -m "body"` — no HEREDOC/subshell wrappers.
- Never add Co-Authored-By trailers.
