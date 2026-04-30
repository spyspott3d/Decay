# Data Model

The SavedVariables schema for Decay. Stored in `DecayDB` (account-wide via AceDB).

## Top-level structure

```lua
DecayDB = {
  version = 1,
  global = {
    bars = { ... },          -- list of bar configs
    settings = { ... },      -- global settings (thresholds, colors, visibility rules)
    state = { ... },         -- runtime state that persists across reloads (unlock state)
  },
}
```

V1 uses the AceDB `global` profile only (one profile, account-wide). Per-character profiles are V2.

## Settings

```lua
settings = {
  thresholds = {
    yellow = 0.5,
    red = 0.25,
  },
  colors = {
    green  = { 0.247, 0.749, 0.247, 1.0 },  -- #3FBF3F
    yellow = { 0.898, 0.753, 0.235, 1.0 },  -- #E5C03C
    red    = { 0.816, 0.251, 0.251, 1.0 },  -- #D04040
  },
  visibility = {
    combatOnly      = false,
    inInstanceOnly  = false,
    targetRequired  = true,   -- hide debuff slots when no target
  },
  defaults = {                 -- per-bar visual defaults applied to new bars
    iconSize        = 32,
    barLength       = 100,
    barThickness    = 32,
    spacing         = 4,
    texture         = "Interface\\TargetingFrame\\UI-StatusBar",
    showTimerText   = true,
    timerTextSize   = 12,
    timerTextFormat = "auto",
  },
}
```

## Bar config

Each bar is an entry in the `bars` array, indexed by its position in the array (which is also its display order in the config window). Rearranging bars in the config moves them in the array.

```lua
bars[i] = {
  id           = "bar-1234567890",  -- stable unique identifier
  name         = "Rotation",
  orientation  = "horizontal",  -- or "vertical"
  fadeDirection = "above",       -- "above" | "below" | "left" | "right"
  slotCount    = 4,
  position = {
    point      = "CENTER",
    relativeTo = "UIParent",
    relativePoint = "CENTER",
    x          = 0,
    y          = -100,
  },
  visual = {                     -- overrides settings.defaults; nil keys inherit
    iconSize        = 40,
    barLength       = 120,
    barThickness    = nil,       -- inherits from defaults
    spacing         = nil,
    texture         = nil,
    showTimerText   = nil,
    timerTextSize   = nil,
    timerTextFormat = nil,
  },
  slots = {
    [1] = { ... },               -- slot config; see below
    [2] = nil,                   -- empty slot
    [3] = { ... },
    [4] = { ... },
  },
}
```

The `id` is generated at bar creation time as `"bar-" .. tostring(GetTime() * 1000)`. It is used internally to disambiguate bars even when names duplicate or array indices change.

The `visual` block uses `nil` for values that should inherit from `settings.defaults`. AceDB stores nils as missing keys, so the inheritance is "key not present" rather than "key is nil".

## Slot config

```lua
slots[j] = {
  spellName  = "Rupture",
  spellID    = 1943,
  auraName   = "Rupture",       -- usually equals spellName
  auraType   = "debuff",         -- "buff" or "debuff"
  auraIcon   = "Interface\\Icons\\Ability_Rogue_Rupture",
  pinned     = false,            -- if true, always visible regardless of active state (V2 feature)
}
```

`auraName` defaults to `spellName` at assignment time and can diverge after auto-link (see SPEC section 4.2).

`auraIcon` is cached at assignment time so the slot does not need to call `GetSpellInfo` repeatedly.

`pinned` is reserved for a future feature; in V1 it is always `false` and ignored.

## Runtime state (persisted)

Some runtime state is persisted across reloads to preserve user experience:

```lua
state = {
  unlocked   = false,
  windowOpen = false,
  windowTab  = "bars",
}
```

`unlocked` controls whether bars show their drag handles and configuration mode.

`windowOpen` and `windowTab` are restored on login if AceConfigDialog is integrated to do so; otherwise these are runtime-only.

## Defaults

The full default DB on first load:

```lua
local defaults = {
  global = {
    bars = {},
    settings = {
      thresholds = { yellow = 0.5, red = 0.25 },
      colors = {
        green  = { 0.247, 0.749, 0.247, 1.0 },
        yellow = { 0.898, 0.753, 0.235, 1.0 },
        red    = { 0.816, 0.251, 0.251, 1.0 },
      },
      visibility = {
        combatOnly = false,
        inInstanceOnly = false,
        targetRequired = true,
      },
      defaults = {
        iconSize = 32,
        barLength = 100,
        barThickness = 32,
        spacing = 4,
        texture = "Interface\\TargetingFrame\\UI-StatusBar",
        showTimerText = true,
        timerTextSize = 12,
        timerTextFormat = "auto",
      },
    },
    state = {
      unlocked = false,
    },
  },
}
```

## Migration

V1 has no migrations. When the schema changes in a future version, migrations live in `Core/Database.lua` as a list of upgrade functions, each handling exactly one version step.

```lua
Migrations = {
  [1] = function(db)
    -- migrate from v1 to v2
  end,
  [2] = function(db)
    -- migrate from v2 to v3
  end,
}

function Database:Migrate()
  while DecayDB.version < CURRENT_VERSION do
    Migrations[DecayDB.version](DecayDB)
    DecayDB.version = DecayDB.version + 1
  end
end
```

## Validation

On load, `Database:Validate()` runs through the loaded DB and:
- Replaces missing keys with defaults.
- Discards bars with malformed `position` data.
- Discards slots with no `spellName`.
- Clamps numeric values to their valid ranges (slot counts to 1-12, icon sizes to 16-64, etc.).
- Logs to `/decay logs` any entries discarded.

The validation never throws errors; bad data is replaced or skipped silently.
