# Testing Checklist

Manual test cases for Decay, organized by phase. Run the checklist for the current phase at the end of that phase, and re-run the previous phases' checklists before each release to catch regressions.

There is no automated test suite. WoW addons are tested in-game.

## Pre-test setup

For all tests, have:
- A character on Ascension or another 3.3.5a server.
- The Decay addon installed in `Interface/AddOns/Decay/`.
- BugSack or `/console scriptErrors 1` enabled to catch errors.
- A target dummy or a sparring partner for casting tests.

## Phase 0 (setup)

- The addon appears in the AddOns list at character select.
- Logging in produces no errors.
- `/run print(Decay)` in chat returns a non-nil table.
- `/decay` is recognized (even if it does nothing yet).

## Phase 1 (skeleton)

- `/decay` opens a configuration window.
- The window has a "Bars" tab with a "New bar" button.
- Clicking "New bar" creates a placeholder rectangle on screen.
- The rectangle is at the center of the screen on first creation.
- Right-click drag on the rectangle moves it.
- Reload UI. The rectangle is in the same position.
- Create three bars. All three appear, all three move independently.
- Delete a bar via the config. The rectangle disappears.
- Delete the addon from `AddOns/`, log in, no SavedVariables errors.

## Phase 2 (static layout)

- Create a horizontal bar with 4 slots, fade direction `above`.
- Verify visual: 4 icon-sized squares in a row, with bar-shaped placeholders above each.
- Switch fade direction to `below`. Bars move below the icons.
- Switch orientation to `vertical`. Icons stack vertically.
- Switch fade direction to `left` then `right`. Bars move to the corresponding side.
- Change slot count to 1. The bar shrinks to a single slot.
- Change slot count to 12. The bar expands to 12 slots.
- Change icon size to 16, 32, 48, 64. Verify each size renders cleanly.

## Phase 3 (drag-drop)

- Open spellbook (P). Pick up a known spell (Slice and Dice if rogue, or any spell with a clear icon).
- Drop on slot 1 of bar 1. Slot 1 shows the spell icon.
- Reload UI. Slot 1 still shows the spell icon.
- Right-click slot 1, choose "Clear". Slot 1 empties.
- Right-click slot 1 (now empty). The "Clear" option is disabled or absent.
- Drop a spell, then right-click and select "Set as buff". The slot's auraType is "buff".
- Drop a spell, then right-click and select "Set as debuff". The slot's auraType is "debuff".
- Shift-click an empty slot. A dialog asks for an aura name. Type "Power Word: Fortitude". The slot is armed with that name.
- Drop a spell on slot 1, then drop another spell on slot 1. The first is replaced by the second.
- Try dropping a non-spell (a bag item). The slot does not accept it.

## Phase 4 (live tracking)

- Arm a slot with a known buff with short duration (5 to 10 seconds). Cast it. The slot becomes visible with a regression bar.
- The bar starts at full width and shrinks over time.
- The timer text matches `remaining` in seconds (with one decimal under 10s).
- The bar is green at full, transitions to yellow at 50%, transitions to red at 25%.
- The slot disappears when the aura expires.
- Cast the same spell twice in a row before the first expires. The bar refills to the new duration.
- Lock the UI. The slot is invisible when no aura is active. Cast the spell. The slot becomes visible. Aura expires. Slot invisible again.
- Unlock the UI. The slot is visible regardless of activation state, with an empty bar when inactive.
- Arm a slot with a debuff. Target a dummy. Cast the debuff. The slot tracks correctly.
- Untarget the dummy (target nothing). The debuff slot becomes inactive (debuffs are tied to the current target).
- Retarget the dummy. The slot reactivates if the debuff is still present.
- Cast a debuff on dummy A, target dummy B. The slot for the debuff is inactive (no debuff on dummy B).
- Apply 5 stacks of a stacking debuff (Sunder Armor). The stack count "5" appears in the corner.
- The stack count updates as stacks change.

## Phase 5 (multi-bar config)

- Create three bars with different settings. All three render independently.
- Set bar 1 to size 48, bar 2 to size 24. Both update; the other bar is unaffected.
- Change global threshold yellow to 0.6. All three bars now transition to yellow at 60%.
- Open color picker for green. Pick a different color. The bars update live.
- Click "Reset to defaults". A confirmation dialog appears. Confirm. Settings revert.
- Reload UI. The reset settings persist.
- Lock the UI. Drag handles disappear. Can no longer drag bars.
- Unlock the UI. Drag handles return.

## Phase 6 (auto-link)

- Arm a slot with a spell whose aura name matches (Rupture). Cast it. The slot tracks normally. No warning.
- Arm a slot with a spell whose aura has a different name. Cast it. After 1.5s, a warning icon appears in the config window on that slot.
- Click the auto-link button on the warning. The aura name updates to the observed name. Cast the spell again. The slot tracks correctly.
- Arm a slot, classify as debuff. Cast a spell that produces a self-buff only. After 1.5s, type-mismatch warning appears.
- Click "flip type". The slot's auraType becomes "buff". Cast again. Tracks correctly.
- Cast multiple spells in quick succession (within 1.5s of each other). Each one's pending watch resolves correctly without crosstalk.
- Cast a spell that fails (out of range, target immune, silenced). No warning is generated (no aura observation).

## Phase 7 (locales)

- Set the client locale to French. Open `/decay`. All UI text is in French.
- Spot check translations against in-game equivalents. No string is in English by accident.
- Drag-drop a French-language damage spell. Auto-detection classifies as debuff.
- Drag-drop a French-language buff spell. Auto-detection classifies as buff.
- Switch to German, repeat.
- Switch to Spanish, repeat.
- Switch to Chinese, repeat (focus on rendering, layout, and that Chinese characters fit in expected widths).
- Switch to Russian (a locale not shipped). UI falls back to English with no errors.

## Phase 8 (performance)

Profile with `/run collectgarbage("collect"); print(collectgarbage("count"))` before and after one hour of play. Memory should grow by less than 1 MB.

Profile OnUpdate with the BugSack profiler or `/run` time measurements. Each slot's OnUpdate should be under 0.1 ms. With 36 active slots, total OnUpdate time per frame should be under 4 ms.

Profile aura scan: time `AuraScanner.ScanUnit("target")` with a target carrying 30+ auras. Should be under 1 ms.

Open and close the config window 10 times in a row. No memory leak (memory should return to baseline after garbage collection).

## Pre-release smoke test

Run before tagging V1:

- Fresh install on a clean WoW: download the release zip, extract, log in, addon loads.
- Create a typical configuration (2 bars, 4 slots each, mix of buffs and debuffs).
- Play for 30 minutes (questing or instance). No errors.
- Use the auto-link prompt at least once. Works.
- Lock and unlock several times. No visual glitches.
- Reload UI 3 times. Settings preserved each time.
- Switch characters. Settings are account-wide and apply to the new character.

## Regression test before any release

Re-run all previous phase checklists. Catches breakage from new features.

## Known issues to watch for

- WoW 3.3.5a sometimes fires `UNIT_AURA` for `unit == nil` or unexpected unit IDs. The handler must guard against this.
- Combat lockdown is not a problem for Decay's frames (they are not secure), but `InCombatLockdown()` should still be respected before structural changes.
- The Ascension launcher may overwrite the `AddOns/` folder on patch days. Document this in the README.
- Some Ascension custom auras have no duration (`duration == 0`). The infinity rendering must work.
- The spellbook on 3.3.5a has multiple tabs. Drag-drop must work from any tab, not just the General tab.
