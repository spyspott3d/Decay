# Decay ARCHITECTURE

Technical architecture for Decay. Describes module boundaries, file layout, event flow, and the algorithms behind aura matching and rendering. Read after `SPEC.md`.

## 1. Stack

The addon is written in Lua 5.1 (the embedded version used by the WoW 3.3.5a client). It uses Ace3 as its framework, embedded via `embeds.xml` following the standard Ace3 pattern.

Embedded libraries:

| Library | Purpose |
|---|---|
| LibStub | library versioning |
| CallbackHandler-1.0 | event callbacks |
| AceAddon-3.0 | addon lifecycle |
| AceEvent-3.0 | game event subscription |
| AceConsole-3.0 | slash commands and printing |
| AceDB-3.0 | SavedVariables management |
| AceConfig-3.0 | declarative options window |
| AceConfigDialog-3.0 | rendering of options window |
| AceLocale-3.0 | localization |
| AceGUI-3.0 | small ad-hoc UI dialogs |

No other libraries. No LibSharedMedia, no Masque, no LibQTip. If a future feature needs more, it gets discussed and added explicitly to this list.

## 2. File layout

```
Decay/
├── Decay.toc
├── embeds.xml
├── Decay.lua              -- addon root, AceAddon definition, init/enable
├── Core/
│   ├── Database.lua       -- AceDB schema, defaults, migration
│   ├── Events.lua         -- event registration and dispatch
│   ├── AuraScanner.lua    -- the heart: matches assigned slots to in-game auras
│   └── State.lua          -- runtime state, active slot map
├── UI/
│   ├── Bar.lua            -- the Bar widget, owns its slots
│   ├── Slot.lua           -- the Slot widget, the regression bar + icon + timer
│   ├── BarManager.lua     -- creates, destroys, repositions bars
│   ├── DragDrop.lua       -- spellbook drag-drop integration
│   └── Lock.lua           -- lock/unlock state and drag handles
├── Config/
│   ├── Options.lua        -- AceConfig schema for the configuration window
│   ├── Heuristics.lua     -- buff vs debuff auto-detection
│   └── Validation.lua     -- input validation for user-set values
├── Libs/
│   ├── LibStub/...
│   ├── CallbackHandler-1.0/...
│   ├── AceAddon-3.0/...
│   ├── AceEvent-3.0/...
│   ├── AceConsole-3.0/...
│   ├── AceDB-3.0/...
│   ├── AceConfig-3.0/...
│   ├── AceConfigDialog-3.0/...
│   ├── AceLocale-3.0/...
│   └── AceGUI-3.0/...
└── Locale/
    ├── enUS.lua
    ├── frFR.lua
    ├── deDE.lua
    ├── esES.lua
    ├── zhCN.lua
    └── heuristics/
        ├── enUS.lua
        ├── frFR.lua
        ├── deDE.lua
        ├── esES.lua
        └── zhCN.lua
```

The `.toc` file load order matches the dependency direction: Libs first, Locale next, Core, UI, Config last. See `docs/addon-structure.md` for the full `.toc` content.

## 3. Module responsibilities

### 3.1 Decay.lua

Defines the addon via `LibStub("AceAddon-3.0"):NewAddon("Decay", "AceEvent-3.0", "AceConsole-3.0")`. Implements `OnInitialize` (load DB, register slash commands, register options window) and `OnEnable` (start event subscriptions).

This file should be small, around 100 lines. It is the entry point and should not contain logic.

### 3.2 Core/Database.lua

Defines the AceDB defaults table and exposes the configured DB on `Decay.db`. The schema is in `docs/data-model.md`. This module also handles version migration (when SavedVariables exists from an older Decay version, migrate the schema in place).

### 3.3 Core/Events.lua

Registers the WoW events Decay listens to. The minimal event set is:

| Event | Reason |
|---|---|
| `PLAYER_LOGIN` | initial setup after the player frame is available |
| `PLAYER_TARGET_CHANGED` | rescan target debuffs |
| `UNIT_AURA` | the player's or target's auras changed; rescan |
| `PLAYER_REGEN_DISABLED` | combat starts |
| `PLAYER_REGEN_ENABLED` | combat ends |
| `PLAYER_ENTERING_WORLD` | zone change, login, reload UI |

Each event handler dispatches to one or more functions in `AuraScanner.lua` or `BarManager.lua`. The handlers themselves are short.

### 3.4 Core/AuraScanner.lua

The most important module. Two main functions:

`ScanUnit(unit)` reads all auras on the unit (player or target) via `UnitAura(unit, i, filter)` in a loop. For each aura, looks up whether any armed slot in any bar matches it. If yes, updates the active slot map for that slot. If no, ignores.

`MatchSlot(slot, auraData)` is the matching predicate. It returns true if the slot's stored data matches the observed aura. The match strategy is described in section 5.

The active slot map is kept on `Decay.state.activeSlots`, indexed by `barId..":"..slotIndex`. When a slot is active, the value contains: `expirationTime`, `duration`, `stackCount`, `auraName`. When a slot becomes inactive, its entry is removed.

### 3.5 Core/State.lua

Holds runtime-only state, distinct from the persisted database. This includes:

- `activeSlots`: map of currently visible (active) slots and their aura data.
- `inCombat`: boolean updated on combat events.
- `unlocked`: boolean for lock state.
- `currentTargetGUID`: for tracking when target changes.
- `pendingMatch`: per-slot post-cast watch state for the auto-link warning.

State is reset on `PLAYER_ENTERING_WORLD`.

### 3.6 UI/Bar.lua

Defines the Bar widget. A Bar is a frame that owns N Slot widgets and arranges them according to its orientation. The Bar handles its own positioning (drag handle in unlock mode), its own slot count changes (creating or destroying slots), and its own visual properties (icon size, bar length, etc.).

The Bar does not know about specific spells or auras. It delegates display logic to its Slots.

### 3.7 UI/Slot.lua

Defines the Slot widget. A Slot consists of three composited frames: an icon button, a regression bar (the actual StatusBar), and a timer FontString. The Slot owns an OnUpdate handler that runs when the slot is active.

The OnUpdate handler reads the active aura data from `Decay.state.activeSlots`, computes the remaining time (`expirationTime - GetTime()`), updates the bar fill width, updates the timer text, and updates the bar color based on the percentage thresholds.

When the Slot becomes inactive, its OnUpdate is unregistered. When active, it is registered.

### 3.8 UI/BarManager.lua

Top-level UI orchestrator. Creates Bars on addon load from the saved configuration. Handles bar creation, deletion, duplication. Knows about the global list of bars.

### 3.9 UI/DragDrop.lua

Hooks the spellbook frame to capture drop events. When a slot in configuration mode receives a drop while the cursor holds a spell, this module reads the spell info via `GetSpellInfo` and calls into the relevant slot to assign it.

### 3.10 UI/Lock.lua

Manages the lock state. Iterates all bars and toggles their drag handles, gear icons, and slot visibility.

### 3.11 Config/Options.lua

Defines the AceConfig schema for the configuration window. This is a single declarative table that AceConfigDialog renders into a frame. Bars are dynamically inserted into the schema based on the current bar list.

### 3.12 Config/Heuristics.lua

Implements the buff vs debuff auto-detection by reading the spell tooltip on assignment and matching against locale-specific verb lists.

### 3.13 Config/Validation.lua

Validates user-set values from the options window: bar names not empty, slot counts in 1-12, threshold values in correct order, color values valid, etc.

## 4. Event flow

The flow is event-driven. The OnUpdate loop only runs for active slots, never for the addon as a whole.

```
PLAYER_LOGIN
  -> Database.Init
  -> BarManager.LoadBarsFromDB
  -> Events.RegisterAll
  -> AuraScanner.InitialScan(player)

UNIT_AURA(player)
  -> AuraScanner.ScanUnit(player)
    -> for each armed slot of type "buff":
      -> MatchSlot(slot, aura) -> update activeSlots
    -> for each newly inactive slot, hide it
    -> for each newly active slot, show it and start its OnUpdate

PLAYER_TARGET_CHANGED
  -> AuraScanner.ScanUnit(target)
    -> as above for armed slots of type "debuff"

UNIT_AURA(target)
  -> if unit == "target": AuraScanner.ScanUnit(target)
  -> else: ignore

OnUpdate (per active slot, 60 Hz)
  -> compute remaining = activeSlot.expirationTime - GetTime()
  -> if remaining <= 0: hide slot, unregister OnUpdate
  -> else: update bar fill, update timer text, update color
```

## 5. Aura matching strategy

The aura matching algorithm is the technical core of Decay. It is invoked from `AuraScanner.MatchSlot(slot, auraData)`.

### 5.1 Stored slot data

When a slot is armed, Decay stores:

| Field | Source |
|---|---|
| `spellName` | `GetSpellInfo(spellID)` returned name |
| `spellID` | the original spell ID from the spellbook drop |
| `auraName` | initially equals `spellName`; can diverge after auto-link |
| `auraType` | `buff` or `debuff`, from heuristic at assignment time |
| `auraIcon` | `GetSpellInfo(spellID)` returned icon path |

### 5.2 Match algorithm

When scanning a unit, for each aura returned by `UnitAura(unit, i, filter)`, Decay reads:

```
name, _, icon, count, _, duration, expirationTime, unitCaster, _, _, spellId = UnitAura(unit, i, filter)
```

A match is declared if all of the following:

```
1. unitCaster == "player"
2. name == slot.auraName
3. (filter == "HELPFUL" and slot.auraType == "buff")
   OR (filter == "HARMFUL" and slot.auraType == "debuff")
```

The `name` comparison is case-sensitive (`UnitAura` returns canonical capitalization).

### 5.3 Why name and not spell ID

Spell ID matching is fragile on 3.3.5a:

- The cast spell ID and the applied aura ID can differ.
- Different ranks of a spell have different spell IDs but the same aura name.
- Glyphs and talents can swap which aura is applied.
- On Ascension, custom spells may not even have stable IDs across server patches.

Name matching is reliable because the in-game tooltip name is what `UnitAura` returns. The user assigns by spell, and spells with the same name and same effect produce the same aura name in the vast majority of cases.

The exceptions are handled by the auto-link mechanism (section 6).

### 5.4 Performance of the scan

The scan iterates all auras on a unit (max 40). For each aura, it iterates all armed slots whose `auraType` matches the filter. With a worst-case 36 armed slots split between buffs and debuffs, that is 40 * 18 = 720 string comparisons per scan. Each scan is sub-millisecond.

UNIT_AURA fires often (every aura change including ticks of HoT/DoT in some 3.3.5a cases), so the scan must be fast. The current design fits the budget.

Optimization: maintain a hash map `auraName -> {slot, slot, ...}` so that scanning iterates auras and looks up by name in O(1). With 40 auras and a hashmap, a scan is 40 lookups instead of 720 comparisons. Implement this in Phase 7 if profiling shows it matters; otherwise the linear scan is fine.

## 6. Auto-link for spell-aura mismatches

When the user casts a spell that has an armed slot, Decay watches for new auras on the relevant unit during a 1.5-second window.

### 6.1 Detecting the cast

Decay listens to `UNIT_SPELLCAST_SUCCEEDED` on the player. When the event fires for a spell whose name matches an armed slot's `spellName`, Decay sets `pendingMatch[slot]` with `start = GetTime()`, `expectedAuraName = slot.auraName`, `auraType = slot.auraType`.

### 6.2 Watching for new auras

During the next UNIT_AURA events on the corresponding unit (player for buff slots, target for debuff slots), Decay records all new auras (auras present that were not present before). After 1.5 seconds, if no aura matching `expectedAuraName` was observed but at least one new aura of the correct type appeared, the slot is flagged with a warning icon in the configuration window.

### 6.3 The auto-link prompt

In the configuration window, slots with a mismatch warning show a small "Auto-link" button. Clicking it sets `slot.auraName` to the most recently observed unfamiliar aura name. The change is persistent.

### 6.4 Edge cases

- The user casts a spell, the aura name matches, no warning. Normal case.
- The user casts a spell, no aura is applied (the cast failed, the target was immune, the player was silenced). No warning, since no aura observation triggers the auto-link.
- The user casts a spell, the aura applied has a name unrelated to the spell (Death Strike triggers a self-heal aura). Warning and auto-link.
- The user casts a spell that produces multiple auras (a Glyph effect plus the main aura). The first observed aura is used. The user can manually edit `auraName` later via the slot context menu.

## 7. Color computation

For an active slot, the bar color is determined as follows.

```lua
local pct = remaining / duration

if pct >= db.thresholds.yellow then
  return db.colors.green
elseif pct >= db.thresholds.red then
  return db.colors.yellow
else
  return db.colors.red
end
```

The colors are stored as `{r, g, b, a}` tables. The thresholds are stored as fractions in `[0, 1]`.

## 8. OnUpdate budget

The OnUpdate handler on each active slot must be tight. Reference implementation:

```lua
local function SlotOnUpdate(self, elapsed)
  self.elapsed = (self.elapsed or 0) + elapsed
  if self.elapsed < 0.05 then return end
  self.elapsed = 0

  local active = state.activeSlots[self.id]
  if not active then
    self:Hide()
    self:SetScript("OnUpdate", nil)
    return
  end

  local remaining = active.expirationTime - GetTime()
  if remaining <= 0 then
    state.activeSlots[self.id] = nil
    self:Hide()
    self:SetScript("OnUpdate", nil)
    return
  end

  local pct = remaining / active.duration
  self.bar:SetValue(pct)

  if pct >= db.thresholds.yellow then
    self.bar:SetStatusBarColor(unpack(db.colors.green))
  elseif pct >= db.thresholds.red then
    self.bar:SetStatusBarColor(unpack(db.colors.yellow))
  else
    self.bar:SetStatusBarColor(unpack(db.colors.red))
  end

  if remaining >= 60 then
    self.text:SetFormattedText("%d:%02d", floor(remaining/60), floor(remaining%60))
  elseif remaining >= 10 then
    self.text:SetFormattedText("%d", remaining)
  else
    self.text:SetFormattedText("%.1f", remaining)
  end
end
```

Note the throttle: the handler returns early if less than 50 ms have elapsed. This caps the update rate at 20 Hz, plenty for a smooth-looking bar without burning CPU. Without the throttle, the handler runs at full frame rate (60+ Hz on modern hardware).

`SetFormattedText` is faster than `SetText` with `string.format` because it avoids the intermediate string allocation.

## 9. Lock and unlock

Lock state is stored in `state.unlocked` (runtime) and persisted to `db.profile.unlocked`. On state change, `Lock.Apply()` iterates all bars and sets:

- Each Bar's mover frame visibility.
- Each Slot's "show even when inactive" flag.
- Each Bar's gear and close icon visibility.

When transitioning from unlocked to locked, slots that were visible only because of unlock state hide themselves immediately if they have no active aura.

## 10. Combat lockdown

WoW 3.3.5a forbids modifying secure frames during combat. Decay slots are not secure frames (they are not action buttons, they do not cast spells), so this restriction does not apply to slot creation, destruction, or movement.

However, Decay defers bar creation, deletion, and slot count changes during combat as a safety measure. Operations queued during combat execute when `PLAYER_REGEN_ENABLED` fires.

## 11. SavedVariables migration

When the saved variables exist from a previous Decay version, the addon checks `DecayDB.version` against the current `Decay.VERSION`. If older, run the corresponding migration steps from `Database.Migrations[]` in order.

V1 has no migrations (it is the first version). Migrations are introduced in V1.1+ when the schema changes.

## 12. Testing strategy

Decay is tested manually in-game. The testing checklist in `docs/testing-checklist.md` lists every test case, organized by phase. There is no automated test suite. Lua linting is run via `luacheck` against the source tree as a CI step (configuration in `.luacheckrc`).

## 13. Distribution

Decay is distributed as a zip file containing the `Decay/` folder. Releases are tagged on GitHub and a built zip is attached to each release. The zip contains exactly the addon folder, no source-only files (`README.md`, `SPEC.md`, `ARCHITECTURE.md`, etc. live at the repo root and are not in the zip).

A `package.sh` script in the repo root builds the release zip, excluding source-only files.
