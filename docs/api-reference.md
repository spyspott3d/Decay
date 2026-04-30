# API Reference

Reference for the WoW 3.3.5a API surface used by Decay. The 3.3.5a API differs from retail and from Classic Era. When in doubt, this document is the source of truth for what Decay assumes about the API. If the actual game behavior contradicts this document, the document is wrong and must be updated, and the related code revisited.

## UnitAura

```
name, rank, icon, count, debuffType, duration, expirationTime,
unitCaster, isStealable, shouldConsolidate, spellId =
  UnitAura(unit, index, filter)
```

The 3.3.5a return signature has 11 fields. Retail has more (auraInstanceID, etc.) which do not exist here.

`unit`: `"player"`, `"target"`, `"focus"`, `"pet"`, `"party1..4"`, `"raid1..40"`. Decay only uses `"player"` and `"target"`.

`index`: 1-based. Iterate from 1 until name is nil.

`filter`: a string of optional flags. Decay uses two distinct calls:
- `"HELPFUL"` for buffs.
- `"HARMFUL"` for debuffs.

The `"PLAYER"` filter token can be appended (`"HELPFUL PLAYER"`) to filter to auras applied by the player. Decay does not use this filter token because it filters by `unitCaster == "player"` after the fact, which is more reliable on Ascension where some custom auras have inconsistent caster attribution.

`unitCaster`: returns the unit token of the caster. Can be `"player"`, `"pet"`, `"party1"`, etc., or `nil` if the caster is unknown or no longer present. For Decay's matching, only `"player"` matters.

`duration`: total duration in seconds at cast time. `0` for permanent auras.

`expirationTime`: a `GetTime()`-comparable timestamp when the aura ends. `0` for permanent auras.

`spellId`: the aura's spell ID. May or may not equal the cast spell ID. Use `name` for matching, not `spellId`.

## GetSpellInfo

```
name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID or spellName)
```

Returns nil if the spell is not in the player's spellbook (sometimes; the API has quirks).

Used at slot assignment time to:
- Confirm the spell exists.
- Get the icon path.
- Get the canonical name (used as the initial `auraName`).

## GetTime

```
seconds = GetTime()
```

Returns a high-precision floating-point timestamp in seconds. Resolution is approximately 1 ms. Used in OnUpdate to compute `remaining = expirationTime - GetTime()`.

## PickupSpell and ClearCursor

```
PickupSpell(spellID, "spell")  -- 3.3.5a signature; second arg may be optional or different
ClearCursor()
```

`PickupSpell` is the API the Blizzard spellbook uses internally when the user clicks a spell to pick it up. Decay does not call `PickupSpell` directly; instead it hooks the spellbook frame's drop logic.

## CursorHasSpell, GetCursorInfo

```
hasSpell = CursorHasSpell()
type, slot, spellName = GetCursorInfo()
```

Used by Slot widgets to detect when the cursor holds a spell ready to be dropped. `GetCursorInfo` returns `("spell", spellSlot, spellName)` for a held spell. The spell ID can be derived from the `spellSlot` via `GetSpellBookItemInfo` if needed.

## Frame and Region API

The standard Blizzard frame API is used throughout. Key methods:

- `frame:CreateFontString`, `frame:CreateTexture`, `frame:CreateLine`.
- `frame:SetPoint`, `frame:ClearAllPoints`, `frame:SetSize`, `frame:SetWidth`, `frame:SetHeight`.
- `frame:SetScript("OnUpdate", fn)`, `frame:SetScript("OnEvent", fn)`.
- `frame:RegisterEvent`, `frame:UnregisterEvent`.
- `frame:Show`, `frame:Hide`, `frame:SetShown`, `frame:IsShown`.
- `frame:EnableMouse(true)` for click handling.
- `frame:RegisterForDrag("LeftButton")` for drag handles.

## StatusBar

```
bar = CreateFrame("StatusBar", name, parent)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0.5)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(r, g, b, a)
bar:SetOrientation("HORIZONTAL")  -- or "VERTICAL"
```

For Decay, the StatusBar's orientation is the orientation of the regression bar itself: HORIZONTAL when the spell bar is vertical (and bars extend horizontally to the left or right), VERTICAL when the spell bar is horizontal (and bars extend vertically above or below).

The StatusBar fills from a configurable side via `SetReverseFill(boolean)`. Used to make the bar's "0" point be at the icon side regardless of orientation.

## FontString

```
fs = frame:CreateFontString(name, "OVERLAY", "GameFontNormal")
fs:SetText("12s")
fs:SetFormattedText("%d", 12)
fs:SetPoint("CENTER")
fs:SetTextColor(1, 1, 1, 1)
```

Use `SetFormattedText` over `SetText` with `string.format` in OnUpdate paths.

## Events

The events Decay subscribes to:

| Event | Args | Notes |
|---|---|---|
| `PLAYER_LOGIN` | none | initial setup |
| `PLAYER_ENTERING_WORLD` | none | login, reload, zone change |
| `UNIT_AURA` | unitId | fires for the unit whose auras changed |
| `PLAYER_TARGET_CHANGED` | none | target swapped |
| `PLAYER_REGEN_DISABLED` | none | combat starts |
| `PLAYER_REGEN_ENABLED` | none | combat ends |
| `UNIT_SPELLCAST_SUCCEEDED` | unitId, spellName, spellRank, lineId, spellId | for cast detection |

`UNIT_AURA` fires often. Keep the handler fast.

## Combat lockdown

Secure frames cannot be modified during combat. Decay's frames are not secure. The lockdown rules do not apply. However, Decay defers structural changes during combat (bar creation, slot count change) to be safe.

`InCombatLockdown()` returns boolean; check before structural changes if uncertain.

## Common pitfalls on 3.3.5a

The retail `C_Timer.After` does not exist. Use a frame with an OnUpdate handler that fires once after a delay, then unregisters itself.

The retail `C_Spell` namespace does not exist. Use `GetSpellInfo`, `GetSpellBookItemInfo`, `GetSpellTexture`, etc.

`UnitAura` returns `nil` for the first index when the unit has no auras of the requested type. Iterate until name is nil.

`expirationTime == 0` and `duration == 0` mean a permanent aura. Decay handles this by showing a full bar with no regression and the infinity symbol where the timer would be.

The `unit` parameter in events is sometimes `"target"` even when the previous target became invalid (the player retargeted). Verify the unit still exists with `UnitExists(unit)` before scanning.

`UnitGUID(unit)` returns a stable ID per unit. Decay uses this in `state.currentTargetGUID` to detect when target swaps to a unit with auras already on it (so a fresh scan is needed).

The string returned by `UnitAura` for `name` is locale-specific. The user's client locale determines the language. Match-by-name implicitly assumes the spellbook drag-drop also returned a locale-matched name, which is true.

`GetSpellInfo` with a spellID that does not exist in the current locale returns nil. Decay should handle this defensively (probably should not happen for spells the player owns, but might happen for manually-entered names mapped to incorrect IDs).
