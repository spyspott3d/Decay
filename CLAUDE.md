# CLAUDE.md

Instructions for Claude Code when working on the Decay addon. Read this file completely before doing anything.

## Project

Decay is a buff and debuff tracker addon for World of Warcraft 3.3.5a, primarily targeting the Ascension private server. It tracks self-applied buffs on the player and player-applied debuffs on the current target. Spells are added to slots via drag-and-drop from the spellbook. Each tracked aura renders as a color-coded regression bar attached to its spell icon.

## Authoritative documents

The SPEC and ARCHITECTURE files in this repository are authoritative. If something in this CLAUDE.md contradicts SPEC.md or ARCHITECTURE.md, follow the SPEC and ARCHITECTURE and flag the discrepancy. Read these in order before starting any phase:

1. `README.md` for the high-level pitch.
2. `SPEC.md` for functional requirements, every UI behavior, and edge cases.
3. `ARCHITECTURE.md` for module boundaries, file layout, event flow, and the aura matching strategy.
4. `ROADMAP.md` for the phase you are currently working on.
5. `docs/api-reference.md` for the WoW 3.3.5a API surface used.
6. `docs/data-model.md` for SavedVariables schema.
7. `docs/addon-structure.md` for the .toc file, library setup, embedded vs standalone libs.
8. `docs/localization.md` for the locale strategy.
9. `docs/testing-checklist.md` for manual verification steps.

## Working style

Decay is small enough that you can hold the whole codebase in your head. Treat that as a feature. Resist the urge to add abstractions, factories, or registries that exist only to make the code "extensible". The addon has a fixed scope and does not need to anticipate use cases that are not in the SPEC.

When you write code, write it tight. When you write comments, write only what is non-obvious about the WoW API or the Ascension server. Do not narrate what the code is doing in comments.

When in doubt about a WoW API behavior on 3.3.5a, do not guess. The 3.3.5a API differs from retail in many subtle ways (UnitAura return signature, spell ID stability, aura filter strings, GetTime resolution). Reference `docs/api-reference.md` first. If the answer is not there, stop and ask before coding.

## Conventions

### Naming

The addon's Lua namespace is `Decay`. The saved variable is `DecayDB`. Slash commands are `/decay` and `/dc`. Frame names use the prefix `Decay`, for example `DecayBarFrame1`, `DecayConfigFrame`, `DecaySlotButton1_2` (bar 1 slot 2). All globals start with `Decay`. No leaks into the global namespace beyond that prefix and the saved variable.

### Lua style

Local everything that does not need to be global. Cache frequently-used WoW API functions at the top of files: `local UnitAura = UnitAura`, `local GetTime = GetTime`, etc. This is not premature optimization on 3.3.5a, it matters in OnUpdate handlers running 60 times per second.

Use double quotes for strings. Two spaces of indent. No semicolons at end of statements. No trailing whitespace.

Do not use `string.format` inside OnUpdate loops if a simple integer format works with `floor` and `..` concatenation. Allocations in OnUpdate cause hitches.

### Modularity

Each file has one responsibility. The list of files is in `docs/addon-structure.md` and you should not add new files without a clear reason that maps to a SPEC requirement. Do not create utility files, helper files, or shared files unless the SPEC or ARCHITECTURE explicitly calls for them.

### No third-party libraries beyond what is listed

The only embedded libraries are LibStub, CallbackHandler-1.0, AceAddon-3.0, AceConfig-3.0, AceDB-3.0, AceLocale-3.0, AceGUI-3.0. Do not pull in anything else. No LibSharedMedia (use raw textures and color values), no Masque (slot icons are simple textures, not button frames in the usual sense), no LibQTip. If you think you need another library, stop and ask.

## Critical implementation details

### Aura matching

The single most important technical detail in Decay is that the spell you cast may not produce an aura with the same ID. On 3.3.5a, UnitAura matches by name reliably and by spell ID unreliably. Decay stores the spell name as the primary match key and the spell ID as a secondary verification. See `ARCHITECTURE.md` section "Aura matching strategy" for the full algorithm and the list of known mismatches on Ascension.

Do not assume that `GetSpellInfo(spellID)` returns the same name as the aura. Always have a fallback path.

### OnUpdate budget

Each visible bar runs an OnUpdate handler at full frame rate. With six bars of six slots each (worst configured case), that is 36 OnUpdate ticks per frame. Keep each tick under 0.1 ms of CPU work. No string allocations, no table allocations, no `string.format` calls inside the tick. The tick only updates the bar width and the timer text.

The aura scan that determines which slots are active runs only on `UNIT_AURA` events for the player and target, not on OnUpdate. See `ARCHITECTURE.md` section "Event flow".

### Configuration mode visibility

Slots that are armed (have a spell assigned) but not currently active (no matching aura) are hidden in normal play. They become fully visible when the user enters configuration mode (via `/decay`, the slash command, or by clicking the unlock button on a bar). This is essential to the SPEC and you should test both modes after every change to display logic.

### Locale system

All user-facing strings go through `L["..."]` from AceLocale. Five locales ship with the addon: enUS, frFR, deDE, esES, zhCN. Same approach as Iron. See `docs/localization.md` for the locale file structure and string conventions.

## What to do at each phase

The roadmap in `ROADMAP.md` defines the phase boundaries. At the start of each phase, read the phase description, then read the SPEC sections that phase touches, then write the code. At the end of each phase, run through the relevant section of `docs/testing-checklist.md` and check the result yourself in-game before declaring the phase done.

Do not get ahead of the roadmap. If Phase 2 only requires a single hardcoded bar, do not build the multi-bar manager in Phase 2. Build only what Phase 2 specifies. Multi-bar comes in Phase 4.

## What not to do

- Do not write tests with a unit test framework. WoW addons are tested manually in-game, not via headless test runners.
- Do not add a "fake" or "preview" mode that simulates auras without real game data, except where the SPEC specifically calls for it (the configuration mode preview in Phase 5).
- Do not add features not in the SPEC. If you think a feature is obviously needed, stop and ask before coding it.
- Do not refactor working code from previous phases unless the current phase explicitly requires it.
- Do not add Ascension-specific class detection logic. Ascension is classless. Tracking is by spell name only.
- Do not attempt to use modern WoW API features (C_Timer, GetSpellTexture with options table, UnitAura with auraInstanceID, etc.). These do not exist on 3.3.5a.
- Do not embed Ace3 by copy-pasting source files into the addon. Embed via the standard `embeds.xml` pattern documented in `docs/addon-structure.md`.

## Ascension specifics

Ascension differs from retail WotLK in several ways relevant to Decay:

- Classes do not exist in the traditional sense. `UnitClass("player")` may return unexpected values. Do not branch on it.
- Random talents mean any character can have any talent, including talents from another "class". Do not assume tracked spells fit a class profile.
- Mystic enchants modify spell behavior at runtime, sometimes including aura duration. Read the actual aura duration from `UnitAura`, never hardcode durations from a database.
- The Ascension launcher may overwrite the `Interface/AddOns/` folder on patch days. The user is responsible for backing up their addon settings; Decay does not need to handle this.
- Some spells on Ascension are custom and have IDs in ranges not present on retail. Decay must not blacklist or special-case any spell ID, since custom IDs are unpredictable.

## When you finish a feature

Before declaring a feature done, run through these checks. If you cannot tick all of them, the feature is not done.

The slash command works. The config opens. The new feature is visible and reachable from the config or from the bar UI. The feature respects the configuration mode visibility rule. SavedVariables persist across reload. No global namespace pollution beyond the `Decay` prefix. No errors in BugSack or the default error display when entering combat, leaving combat, changing target, dying, resurrecting, entering an instance, leaving an instance.

## How to ask for clarification

If something in the SPEC is ambiguous, do not invent. Stop, list the ambiguity, and propose two or three concrete interpretations. Pick the one most consistent with the rest of the SPEC and proceed only if there is no contradiction. If there is contradiction, wait for human input.

## Git workflow

The repository is hosted at `git@github.com:spyspott3d/Decay.git`. The default branch is `main`. There is no `dev` branch, no PR review process. Work directly on `main`.

### One-time setup

The user runs the bootstrap script once before Claude Code starts Phase 0. Two variants are provided depending on the user's shell:

- Windows PowerShell: `.\scripts\init-github.ps1`
- bash (Linux, macOS, WSL, Git Bash): `bash scripts/init-github.sh`

Both do the same thing: create the GitHub repo, set the remote, configure gh as the git credential helper, make the initial commit, and push. Claude Code does not need to touch these scripts.

### Per-phase commit and push

After completing each phase (and confirming the relevant section of `docs/testing-checklist.md` passes), Claude Code commits and pushes. The commit message format is:

```
phase <N>: <short description>
```

Examples:

```
phase 0: repo setup and empty addon
phase 1: skeleton with /decay command and bar creation
phase 4: aura scanner, regression bars, color thresholds
```

The commit body (optional) lists the SPEC sections implemented and any notable deviations from the plan.

Workflow:

```
git add -A
git commit -m "phase 4: aura scanner, regression bars, color thresholds"
git push origin main
```

Do not amend commits after pushing. Do not force push. If a commit needs correction, make a follow-up commit.

### Within-phase commits

Within a phase, commit as often as makes sense (one logical chunk per commit). Push at the end of each working session even if the phase is not complete. Format for in-phase commits:

```
phase <N> wip: <what changed>
```

Example:

```
phase 4 wip: UNIT_AURA event handler and target swap
phase 4 wip: bar fill computation and color thresholds
phase 4: aura scanner, regression bars, color thresholds   (final commit, marks phase done)
```

### Releasing

Releases are tagged on `main`. The tag name is `vMAJOR.MINOR.PATCH`. The release process is:

- Windows PowerShell: `.\scripts\release.ps1 1.0.0`
- bash: `bash scripts/release.sh 1.0.0`

The script bumps the `.toc` Version, commits, tags, and pushes. The GitHub Action `release.yml` then builds the zip and creates the GitHub Release with the zip attached.

Claude Code does not run the release script autonomously. The user runs it when V1 is ready (after Phase 9 acceptance).

### Linting

The CI runs `luacheck` on every push to `main` and on PRs. If `luacheck` fails, the lint workflow fails. Claude Code should run `luacheck Decay` locally before pushing if the environment supports it. The `.luacheckrc` configuration is at the repo root.

### Branch protection

Branch protection on `main` is not enforced. Trust the developer (and Claude Code) to push working code. The luacheck CI catches syntax errors as a safety net, but it is not gating.

### What not to commit

Never commit:
- The release zip (`Decay-*.zip`).
- IDE files (`.vscode/`, `.idea/`).
- OS files (`.DS_Store`, `Thumbs.db`).
- Lua bytecode (`*.luac`).

These are listed in `.gitignore`. If something slips through, commit a fix to `.gitignore` and remove the file with `git rm --cached <file>`.

### Authentication

Git operations use HTTPS with gh CLI as the credential helper (configured by `init-github.ps1` / `init-github.sh` via `gh auth setup-git`). Claude Code does not need to authenticate; it inherits the user's git config and gh credential cache.

If a push fails with a permission error, do not attempt to switch to SSH or prompt for credentials. Stop and report the error. The user will resolve auth issues outside Claude Code (typically by running `gh auth status` and `gh auth login` again).
