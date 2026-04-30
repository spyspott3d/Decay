# Decay SPEC

Functional specification for the Decay addon. This document describes what Decay does from the user's perspective, every UI interaction, every visible state, and every edge case. Implementation details live in `ARCHITECTURE.md`.

## 1. Scope

Decay tracks two things and only two things.

The first is buffs that the player has applied to the player. A "buff" here means any positive aura whose `unitCaster` field returns `"player"` from the `UnitAura` API call. This excludes buffs cast on the player by other units (raid buffs from a paladin, food and drink, world buffs).

The second is debuffs that the player has applied to the player's current target. A "debuff" means any negative aura on the target whose `unitCaster` field returns `"player"`. This excludes debuffs applied by other group members on the same target.

Decay does not track friendly target buffs (heals over time on a tank, shields), enemy target buffs (an enemy's self-buffs), pet auras, focus auras, or any combat log derived data. The scope is intentionally narrow.

## 2. Spell bars

A "spell bar" is the fundamental UI unit in Decay. Each bar has its own orientation, its own slots, its own position on the screen, and its own configuration. The user may create as many bars as they want. Each bar is independent.

### 2.1 Bar properties

A bar has a name (user-defined, free-form text, defaults to `Bar 1`, `Bar 2`, etc.).

A bar has an orientation: `horizontal` or `vertical`. Horizontal means the slot icons are arranged in a row, left to right. Vertical means the slot icons are arranged in a column, top to bottom.

A bar has a fade direction. The fade direction defines on which side of each icon the regression bar appears.

For a horizontal spell bar, the fade direction is `above` or `below`.

For a vertical spell bar, the fade direction is `left` or `right`.

A bar has a slot count, a positive integer between 1 and 12. Default is 4.

A bar has a position, stored as an anchor point and an offset. The default anchor point is `CENTER` of the screen with offset `0, -100`. The user may drag the bar in unlock mode to reposition it.

A bar has a slot list. Each slot is either empty (no spell assigned) or filled (a spell is assigned). The slot list has length equal to the slot count.

### 2.2 Per-bar visual settings

Each bar exposes the following visual settings, with the defaults shown.

| Setting | Default | Range |
|---|---|---|
| Icon size | 32 px | 16 to 64 |
| Bar length | 100 px | 40 to 200 |
| Bar thickness | matches icon size | 16 to 64 |
| Spacing between slots | 4 px | 0 to 20 |
| Texture | `Interface\TargetingFrame\UI-StatusBar` | from a small built-in list |
| Show timer text | true | boolean |
| Timer text size | 12 px | 8 to 24 |
| Timer text format | `auto` | `auto`, `seconds`, `mm:ss` |

The bar thickness defaults to matching the icon size so the bar visually aligns with the icon. The user can break that alignment if they want a thinner or thicker bar.

The timer text format `auto` means: when remaining time is at least 60 seconds, display as `m:ss`. When remaining time is below 60 seconds, display as `s` with one decimal under 10 seconds (`9.4s`) and as integer at or above 10 seconds (`12s`).

## 3. Slots

A slot is a fixed-position cell within a bar that may hold a spell assignment. Slots are indexed from 1 to the bar's slot count. The visual order of slots follows the bar's orientation: slot 1 is leftmost (horizontal) or topmost (vertical).

### 3.1 Slot states

A slot has three visual states.

**Empty.** The slot has no spell assigned. In configuration mode, the empty slot is shown as a gray dashed square. In normal play, the empty slot is invisible.

**Armed and inactive.** The slot has a spell assigned, but the corresponding aura is not currently present on the target unit (player for buffs, target for debuffs). In configuration mode, the slot shows the spell icon in full color and the regression bar in dashed outline (the maximum length, no fill). In normal play, the entire slot is invisible. This is critical: the user does not see armed-but-inactive slots during gameplay. They appear only when the aura activates.

**Armed and active.** The slot has a spell assigned and the aura is present on the target unit. The slot shows the spell icon, the regression bar with a fill proportional to the remaining duration, and the timer text. The fill color depends on the remaining duration as a percentage of the total duration (see section 5).

### 3.2 Slot assignment

The user assigns a spell to a slot by drag-dropping from the spellbook. The interaction is as follows.

The user opens the configuration window via `/decay` or `/dc`. The configuration window displays all bars with their slots fully visible (all slots show, including empty and armed-inactive ones).

The user opens the spellbook with the default key (`P`) or the spellbook button on the action bar.

The user picks up a spell icon from the spellbook by clicking it. The cursor now holds the spell.

The user drops the spell on a target slot by clicking the slot. The slot becomes armed.

The slot stores three pieces of information: the spell name, the spell ID, and the auto-detected aura type (buff or debuff). The aura type is determined heuristically (see section 4).

### 3.3 Slot manipulation in configuration mode

In configuration mode, slots support these actions:

**Right-click an armed slot:** opens a small contextual menu with `Clear`, `Set as buff`, `Set as debuff`, `Edit aura name`, `Move slot`, `Cancel`. `Set as buff` or `Set as debuff` overrides the auto-detected aura type if it was wrong. `Edit aura name` lets the user manually change the matched aura name (used when the spell name and aura name differ).

**Drag an armed slot to another slot in the same bar:** swaps the two slots.

**Drag an armed slot to a slot in a different bar:** moves the slot's contents to the destination bar's slot.

**Hold Shift and click an empty slot:** opens a manual entry dialog where the user can type a spell name. Used when the aura is not from a spell the player owns (a raid buff received from a paladin that the player wants to track).

## 4. Aura tracking

Decay matches assigned slots to in-game auras by name. The full algorithm is in `ARCHITECTURE.md`. From the user's perspective, the visible behavior is as follows.

### 4.1 Auto-detection of buff vs debuff

When the user drops a spell into a slot, Decay attempts to determine whether the spell produces a buff or a debuff. The detection runs at slot assignment time and is heuristic, not authoritative.

The heuristic is: if the spell's tooltip text contains common debuff verbs in the current locale (such as "deals", "damage", "reduces", "stuns", "snares", "decreases" in English; equivalent translations in other locales), classify as debuff. Otherwise classify as buff.

This heuristic is wrong sometimes. The user can override the type via the slot context menu (section 3.3) at any time, and the override is remembered.

### 4.2 Aura name vs spell name mismatch

For most spells, the aura name matches the spell name. For some spells, it does not. Examples on 3.3.5a Ascension:

| Cast spell | Aura applied |
|---|---|
| Slice and Dice (with Glyph) | Slice and Dice (different rank/ID) |
| Death Strike | Blood Presence buff (self-heal trigger) |
| Mind Flay | Mind Flay (channeled debuff, name often correct) |
| Custom Ascension procs | Often unrelated names |

Decay does not maintain a database of known mismatches. Instead, when a slot is armed and the user casts the spell, Decay watches for new auras appearing on the corresponding unit (player for buffs, target for debuffs) within a 1.5 second window. If no aura matching the spell name appears but an unfamiliar aura does, Decay flags the slot in the configuration window with a warning icon and offers a one-click "auto-link" action that sets the aura name to the observed name.

If the user has set the aura type to debuff but the auto-link only sees buffs appear on the player after the cast, Decay shows a different warning ("aura type mismatch?") and offers to flip the type.

### 4.3 Refresh and pandemic

If an aura is refreshed (the spell is cast again before the previous aura expires), Decay reads the new duration from `UnitAura` and resets the bar fill accordingly. Decay does not implement any pandemic awareness or refresh-window highlighting in V1. This is a candidate feature for V2.

### 4.4 Stack count

Some auras have stacks (Sunder Armor, Lacerate, etc.). When an aura has more than one stack, the stack count is displayed as a small number in the top-right corner of the icon, in white text with a black outline.

When the stack count changes, the bar fill resets to the new duration (Blizzard behavior: a stack added refreshes the duration).

## 5. Color thresholds

Each bar fill has a color that reflects the remaining duration as a percentage of the aura's total duration.

The default thresholds are:

| Range (remaining %) | Color | Hex |
|---|---|---|
| 50% to 100% | green | `#3FBF3F` |
| 25% to 50% | yellow | `#E5C03C` |
| 0% to 25% | red | `#D04040` |

The thresholds are configurable globally (one set of thresholds for the entire addon, not per bar, not per slot). The user can change the two threshold values (yellow trigger and red trigger) and the three colors. Thresholds must satisfy `0 < red < yellow < 100`.

For an aura with total duration `D`, the time spent in each color is:

```
time in green  = D * (1 - yellow_threshold)
time in yellow = D * (yellow_threshold - red_threshold)
time in red    = D * red_threshold
```

For Rupture (D = 16s) with default thresholds (yellow = 0.5, red = 0.25):

```
time in green  = 16 * 0.5  = 8 seconds
time in yellow = 16 * 0.25 = 4 seconds
time in red    = 16 * 0.25 = 4 seconds
```

Total: 16s, consistent.

The color transition is instantaneous at threshold crossings, no interpolation.

## 6. Configuration window

The configuration window is opened by `/decay`, `/dc`, or the `Decay` entry in the standard Interface > AddOns Blizzard panel.

The window has three tabs.

### 6.1 Bars tab

The Bars tab lists all configured bars by name. Each row shows the bar name, orientation, slot count, and a small preview of the bar's current state.

The user can:
- Click `New bar` to create a new bar with default settings. A new entry appears in the list, and the bar appears on screen at the default position.
- Click a bar row to expand it. The expanded view shows all editable properties (orientation, fade direction, slot count, position, visual settings, slot list).
- Click `Delete` on a bar row, then confirm in a dialog. The bar is removed.
- Click `Duplicate` on a bar row to create a copy of the bar with `(copy)` appended to the name.

Editing an orientation or fade direction updates the live bar immediately. Editing slot count to a smaller value first prompts a confirmation if any slot at the truncated indices is armed.

### 6.2 Display tab

The Display tab contains global visual defaults that apply to bars where the user has not overridden them.

It also contains the global threshold settings (yellow trigger, red trigger, and three colors). Changing thresholds applies live to all bars.

### 6.3 General tab

The General tab contains:
- Lock/unlock UI button. When unlocked, all bars become draggable and show a small handle and a "settings" gear in the corner.
- Visibility rules: combat-only mode (hide bars when not in combat), in-instance-only mode, target-required mode (hide debuff slots when no target is selected).
- Reset to defaults button.

## 7. Slash commands

| Command | Effect |
|---|---|
| `/decay` | toggles the configuration window |
| `/dc` | alias for `/decay` |
| `/decay lock` | locks all bars (no drag) |
| `/decay unlock` | unlocks all bars (drag enabled, slots shown) |
| `/decay reset` | resets all settings to defaults after confirmation |
| `/decay logs` | dumps recent error and warning messages to a copyable window |

## 8. Lock and unlock

When unlocked, every bar shows:
- All slots fully visible (empty and armed-inactive included).
- A drag handle on the top-left corner of the bar.
- A gear icon on the top-right corner that opens the bar's settings inline.
- A close icon next to the gear that deletes the bar after confirmation.

When locked, every bar shows:
- Only active slots.
- No handle, no gear, no close.

The unlocked state persists across sessions. Combat lockdown applies: if combat starts while unlocked, the unlock state is preserved but drag operations are blocked until combat ends.

## 9. SavedVariables

Decay's saved variables are described in `docs/data-model.md`. From the user's perspective, settings persist across sessions, across characters (account-wide), and across UI reloads. There is no per-character profile system in V1; all bars and settings are global to the account. Profile system is a candidate for V2.

## 10. Error handling

Decay does not throw errors visible to the user under normal operation. The following conditions produce a logged warning visible via `/decay logs`:

- An armed slot whose spell name resolves to no aura within 1.5s after a player cast (potential mismatch).
- A bar with all slots empty (cosmetic, not blocking).
- An aura with `duration == 0` (a permanent aura, which Decay shows as full bar with no regression and `infinity` symbol where the timer would be).
- A `UNIT_AURA` event for a unit that is not `player` or `target` (silently ignored, not logged).

## 11. Out of scope for V1

The following features are explicitly out of scope for V1 and may be considered for V2 or later.

- Pet, focus, mouseover unit tracking.
- Group member auras (tracking debuffs applied by other players).
- Combat log derived events (real-time DoT damage display, snapshot).
- Pandemic refresh window highlighting.
- Profile system (per-character or per-spec).
- Sharing configurations between players.
- Sound alerts on aura expiration.
- Glow or pulse animations on threshold crossings.
- Custom textures from LibSharedMedia.
- Per-bar threshold overrides.
- Conditional visibility (talents, stance, form).
- Importing settings from NeedToKnow or other trackers.

## 12. Localization

V1 ships with five locales: enUS (default), frFR, deDE, esES, zhCN. All user-facing strings flow through the locale system. Locale files are in `Locale/` and follow the AceLocale-3.0 pattern. The default fallback is enUS.

Spell tooltips for the buff vs debuff heuristic (section 4.1) need locale-specific verb lists. These are in `Locale/heuristics/` as separate files per locale.

## 13. Performance budget

Decay must not introduce visible frame drops on a baseline 3.3.5a setup (mid-range hardware from circa 2010, modern hardware capable of running the client at 60 fps). Performance constraints:

- Maximum 36 active slots simultaneously (6 bars × 6 slots, the realistic upper bound).
- OnUpdate per slot: under 0.1 ms.
- Aura scan on UNIT_AURA: under 1 ms for a target with 40 auras.
- Configuration window open/close: under 50 ms.
- Memory footprint: under 1 MB after one hour of active play.

## 14. Acceptance criteria for V1 release

A V1 release is ready when:

The addon installs cleanly into `Interface/AddOns/`, loads without errors, and `/decay` opens the configuration window.

The user can create a bar, drag-drop a spell from the spellbook into a slot, cast the spell, and see the regression bar appear with correct duration and color transitions.

Multiple bars work independently with all four orientation/fade-direction combinations.

The lock/unlock toggle works and persists across reload.

Five locales are present and string resolution falls back to enUS for missing keys.

No errors logged in BugSack across one hour of typical play (questing, instance, dueling).

The testing checklist in `docs/testing-checklist.md` passes end to end.
