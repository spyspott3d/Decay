# Decay ROADMAP

Phase-by-phase plan for building Decay from scratch to V1 release. Each phase has a goal, a list of deliverables, an acceptance criterion (what must be true to declare the phase done), and a typical effort estimate.

The phases are sequential. Do not start phase N+1 before phase N's acceptance is met. Do not skip phases.

## Phase 0: Repository setup

Goal: a clean, empty addon that loads in WoW without errors, hosted on GitHub with CI in place.

Deliverables:
- The user runs the bootstrap script to create the GitHub repo, set the remote, configure git credentials, and push the initial commit. PowerShell: `.\scripts\init-github.ps1`. bash: `bash scripts/init-github.sh`. (One-time user action, not Claude Code's responsibility.)
- `Decay/` folder with `Decay.toc`, `embeds.xml`, and an empty `Decay.lua` that creates the AceAddon namespace.
- `Libs/` folder with all embedded Ace3 libraries fetched from upstream (use the latest 3.3.5a-compatible Ace3 release, which is r1166 or compatible).
- `Locale/` folder with empty `enUS.lua`, etc.
- `package.sh` script that produces a release zip (already in handoff).
- `.luacheckrc` with WoW globals declared.
- The CI workflows (`lint.yml`, `release.yml`) and the `.gitattributes`, `.gitignore`, `scripts/init-github.sh`, `scripts/release.sh` files are already in the handoff package; verify they are present after the initial push.
- First Claude Code commit at the end of Phase 0 with message `phase 0: repo setup and empty addon`.

Acceptance: place the addon in `Interface/AddOns/`, launch the client, log in, see "Decay" in the AddOns list, no errors in BugSack or default error display, `print(Decay)` in chat returns a non-nil table. The repo is visible at `https://github.com/spyspott3d/Decay`. The lint CI runs green on the initial commit.

Effort: 2 to 4 hours.

## Phase 1: Static simulator skeleton

Goal: a configuration window that opens, lists "bars" (none yet), and lets the user create an empty bar that appears on screen as a placeholder rectangle.

Deliverables:
- Slash command `/decay` opens the AceConfigDialog window.
- Database schema with `bars = {}` and global settings.
- Bars tab in the config window, with a `New bar` button.
- Clicking `New bar` creates a Bar entry in the DB and a placeholder Bar frame on screen.
- The Bar frame is a simple gray rectangle, positioned at center of screen, draggable when unlocked.
- `/decay unlock` and `/decay lock` toggle the drag state.
- Bar position is persisted across reloads.

Acceptance:
- Open `/decay`, click `New bar`, see a gray rectangle on screen.
- Unlock, drag the rectangle, lock, reload UI, the rectangle is in the same position.
- Create three bars, all three appear, all three are independently draggable.
- Delete a bar via the config window, the rectangle disappears.

Effort: 1 to 2 days.

## Phase 2: Single static bar with hardcoded slots

Goal: a Bar with N slots, each rendered as an icon placeholder and a regression bar placeholder. No spell assignment yet, no aura tracking, just the layout.

Deliverables:
- Bar holds slot count from DB (default 4).
- Bar lays out N Slot widgets according to its orientation and fade direction.
- Slot widget has icon area, bar area, timer text area, all rendered in default colors.
- Bar orientation and fade direction selectable in the config window.
- Slot count selectable in the config window (1 to 12).
- All four orientation/fade-direction combinations render correctly with correct geometry (verify against the SPEC mockup).

Acceptance:
- Create a horizontal bar with 6 slots, fade direction `above`. See 6 icon placeholders in a row, with bar placeholders above each.
- Switch to `below`, the bars move below.
- Switch to vertical, fade direction `left`. The icons stack vertically, bars to the left.
- Switch to fade direction `right`. The bars move to the right.
- Change slot count to 3, see 3 slots. Change to 8, see 8 slots.

Effort: 2 to 4 days.

## Phase 3: Spellbook drag-drop and slot assignment

Goal: the user can pick a spell from the spellbook and drop it on a slot. The slot stores the spell info and renders the spell icon.

Deliverables:
- Hook spellbook drag-pick to set the cursor with spell info.
- Slot accepts drop when cursor holds a spell.
- Slot stores `spellName`, `spellID`, `auraIcon` from `GetSpellInfo`.
- Slot renders the spell icon in the icon area.
- Slot supports right-click context menu in unlock mode with `Clear`, `Set as buff`, `Set as debuff`, `Move slot`, `Cancel`.
- Buff vs debuff auto-detection runs at drop time (Heuristics module).
- Manual entry dialog via Shift-click on empty slot (allows typing a spell name to track auras the player does not own).
- Slot data persists across reloads.

Acceptance:
- Open spellbook, pick a spell (Eviscerate), drop on slot 1 of bar 1. The slot shows the Eviscerate icon. Reload UI. The icon is still there.
- Right-click the slot, choose Clear. The slot empties.
- Right-click an armed slot, choose `Set as buff`. The slot's auraType updates.
- Shift-click an empty slot, type "Power Word: Fortitude", confirm. The slot is armed with that aura name.

Effort: 3 to 5 days.

## Phase 4: Aura scanner and live regression

Goal: when an armed slot's aura is present on the corresponding unit, the slot becomes active and the regression bar shows the remaining time. When the aura expires, the slot becomes inactive.

Deliverables:
- AuraScanner module per `ARCHITECTURE.md` section 4 and 5.
- UNIT_AURA event subscription for player and target.
- PLAYER_TARGET_CHANGED event subscription.
- Active slots are stored in `state.activeSlots`.
- Slot OnUpdate handler running at 20 Hz on active slots.
- Regression bar fill proportional to `remaining / duration`.
- Timer text in the format specified in SPEC section 2.2.
- Color thresholds applied per SPEC section 5.
- Configuration mode visibility rule applied (armed-inactive slots hidden in normal play, visible in unlock).

Acceptance:
- Arm a slot with Slice and Dice (5-second buff at rank 1 with no points). Cast Slice and Dice. The slot becomes visible with a regression bar at 100% green. Watch the bar shrink, change to yellow at 2.5s remaining, red at 1.25s remaining, disappear at 0.
- Arm a slot with Rupture. Target a dummy. Cast Rupture. The slot becomes visible with a 16s regression bar.
- Lock the UI. The Slice and Dice slot is invisible when not active, visible when active. Confirmed.
- Unlock. The slot is always visible (with empty bar when inactive).
- Stack count: arm a slot with Sunder Armor. Apply 5 stacks on a target dummy. The slot shows "5" in the corner. Stack count updates as stacks change.

Effort: 4 to 7 days.

## Phase 5: Multiple bars and full configuration UI

Goal: full configuration window per SPEC section 6, supporting multiple bars with independent settings.

Deliverables:
- Bars tab with list of bars, expandable rows showing all properties.
- Display tab with global visual defaults and threshold settings.
- General tab with lock/unlock, visibility rules, reset.
- Per-bar editing of all properties: name, orientation, fade direction, slot count, position, icon size, bar length, bar thickness, spacing, texture, timer settings.
- Threshold sliders with live preview.
- Color pickers for the three threshold colors.
- Reset to defaults with confirmation dialog.

Acceptance:
- Create three bars. Configure each independently: bar 1 horizontal-above with 4 slots tracking buffs, bar 2 vertical-right with 6 slots tracking debuffs, bar 3 horizontal-below with 2 slots for cooldown trackers (using manual entry).
- Change global thresholds from 50/25 to 60/30. All three bars update color transitions live.
- Change bar 1 icon size to 48. Bar 1 icons grow, bars 2 and 3 unchanged.
- Reload UI. All settings restored.

Effort: 4 to 6 days.

## Phase 6: Auto-link and mismatch detection

Goal: detect when a cast spell's aura name differs from the spell name, prompt the user to auto-link, and apply the link.

Deliverables:
- UNIT_SPELLCAST_SUCCEEDED subscription to detect player casts.
- pendingMatch state per slot when player casts an armed slot's spell.
- Watch window of 1.5s after cast for new auras on the relevant unit.
- Mismatch detection: no aura matching `auraName` appeared, but a new aura did.
- Warning icon on the slot in the config window when mismatch is detected.
- Auto-link button that updates `auraName` to the observed name.
- Aura type mismatch detection (cast classified as debuff but the new aura is on the player as a buff, or vice versa) with a separate warning.

Acceptance:
- Arm a slot with a spell whose aura name matches (Rupture). Cast Rupture. No warning. The slot tracks normally.
- Arm a slot with a spell that produces a differently-named aura. Cast it. After 1.5s, a warning icon appears on the slot in the config window.
- Click auto-link. The slot's auraName updates. Cast the spell again. The slot tracks correctly.
- Arm a slot, classify as debuff. Cast a spell that only produces a self-buff. Warning icon for type mismatch. Click "flip type". The slot now classifies as buff and tracks correctly.

Effort: 2 to 4 days.

## Phase 7: Localization

Goal: all five locales present, all user-facing strings localized, the buff/debuff heuristic supports all five locales.

Deliverables:
- Locale files for enUS, frFR, deDE, esES, zhCN with all UI strings.
- Heuristic verb lists for each locale.
- AceLocale fallback to enUS for missing keys.
- Spot check translations against in-game tooltips for accuracy.

Acceptance:
- Set the client locale to French. Open `/decay`. All UI text is in French.
- Test the heuristic on a French client by drag-dropping a known damage spell. The auto-detection correctly classifies as debuff.
- Switch to German, Spanish, Chinese clients (or fake the locale via `GetLocale` override during testing). Spot check.
- Switch to a locale not shipped (Russian). UI falls back to English. No errors.

Effort: 2 to 3 days for the strings (most translation can be machine-assisted then human-reviewed).

## Phase 8: Performance pass and polish

Goal: meet the performance budget in SPEC section 13, polish the UX, prepare for release.

Deliverables:
- Profile the OnUpdate handler with worst-case 36 active slots. Confirm under 0.1 ms per slot.
- Profile the aura scan with 40 auras and 36 armed slots. Confirm under 1 ms.
- Add the auraName hashmap optimization if profiling shows the linear scan is hot.
- Verify memory footprint stays under 1 MB after one hour of play.
- Polish: smooth transitions between states, clean up any rough edges in the config window, add tooltips on every config option explaining what it does.
- Final pass on the testing checklist.

Acceptance:
- Full pass on `docs/testing-checklist.md`.
- No errors during one hour of typical play (questing, instance, dueling).
- Memory and CPU profiles within budget.

Effort: 2 to 4 days.

## Phase 9: Release prep

Goal: ship V1.

Deliverables:
- Final commit of any release polish.
- Update README with screenshots.
- The user runs the release script. PowerShell: `.\scripts\release.ps1 1.0.0`. bash: `bash scripts/release.sh 1.0.0`. The script bumps the `.toc` version, commits, tags `v1.0.0`, and pushes. The GitHub Action `release.yml` builds the zip and creates the GitHub Release with the zip attached.
- Verify the release page on GitHub shows the zip and the changelog auto-generated from commits.
- Post in Ascension Discord with the release URL.

Acceptance: release page exists at `https://github.com/spyspott3d/Decay/releases/tag/v1.0.0`, zip downloads, fresh install on a clean WoW install works end to end.

Effort: 1 day.

## Total estimate

Calendar time depends entirely on hours per day. At full-time pace (6 hours of focused coding daily), V1 is reachable in 4 to 6 weeks. At part-time pace (1 to 2 hours per day), 8 to 12 weeks.

The phases that historically take longer than estimated in WoW addon development:

- Phase 4 (aura scanner): the WoW API has subtle behaviors around aura filters and unitCaster that catch first-time addon developers. Budget the high end.
- Phase 5 (config UI): AceConfig is powerful but verbose. Per-bar dynamic schema generation has edge cases.
- Phase 6 (auto-link): seems simple, gets messy when the player casts multiple spells in quick succession.

The phases that are usually faster than estimated:

- Phase 0 and 1: setup is mostly mechanical.
- Phase 7: mostly translation, can be machine-assisted then reviewed.
- Phase 9: ship it.

## Out-of-roadmap items

These are not part of V1 and are listed here so they do not get added mid-development:

- Profile system.
- Sound alerts.
- Glow animations.
- Custom textures via LibSharedMedia.
- Importing from NeedToKnow.
- Per-bar threshold overrides.

Each of these is a candidate for V1.1 or V2 and gets evaluated after V1 ships and receives user feedback.
