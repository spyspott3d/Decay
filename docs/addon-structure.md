# Addon Structure

Concrete file layout, .toc content, and library embedding instructions.

## .toc file

`Decay/Decay.toc`:

```
## Interface: 30300
## Title: Decay
## Notes: Self-buff and target-debuff tracker. Drag spells from the spellbook into bars.
## Notes-frFR: Suivi des buffs personnels et debuffs sur cible. Glisse des sorts du livre dans des barres.
## Notes-deDE: Eigenbuff- und Ziel-Debuff-Tracker.
## Notes-esES: Seguidor de buffs propios y debuffs en el objetivo.
## Notes-zhCN: 自身增益和目标减益的追踪器。
## Author: spyspott3d
## Version: 1.0.0
## SavedVariables: DecayDB
## OptionalDeps: Ace3
## DefaultState: enabled

embeds.xml

Locale\enUS.lua
Locale\frFR.lua
Locale\deDE.lua
Locale\esES.lua
Locale\zhCN.lua
Locale\heuristics\enUS.lua
Locale\heuristics\frFR.lua
Locale\heuristics\deDE.lua
Locale\heuristics\esES.lua
Locale\heuristics\zhCN.lua

Core\Database.lua
Core\State.lua
Core\Events.lua
Core\AuraScanner.lua

UI\Slot.lua
UI\Bar.lua
UI\BarManager.lua
UI\DragDrop.lua
UI\Lock.lua

Config\Heuristics.lua
Config\Validation.lua
Config\Options.lua

Decay.lua
```

Load order matters. Locale files first (so `L["..."]` is available throughout). Core before UI (UI uses State and AuraScanner). Config last (Options.lua references everything). `Decay.lua` last so the addon's main entry point runs after every module is loaded.

## embeds.xml

`Decay/embeds.xml`:

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.blizzard.com/wow/ui/..\FrameXML\UI.xsd">
  <Script file="Libs\LibStub\LibStub.lua"/>
  <Include file="Libs\CallbackHandler-1.0\CallbackHandler-1.0.xml"/>
  <Include file="Libs\AceAddon-3.0\AceAddon-3.0.xml"/>
  <Include file="Libs\AceEvent-3.0\AceEvent-3.0.xml"/>
  <Include file="Libs\AceConsole-3.0\AceConsole-3.0.xml"/>
  <Include file="Libs\AceDB-3.0\AceDB-3.0.xml"/>
  <Include file="Libs\AceLocale-3.0\AceLocale-3.0.xml"/>
  <Include file="Libs\AceConfig-3.0\AceConfig-3.0.xml"/>
  <Include file="Libs\AceGUI-3.0\AceGUI-3.0.xml"/>
</Ui>
```

## Where to fetch Ace3

Ace3 source for 3.3.5a is available on WoWAce. Use the latest 3.3.5a-compatible release. As of late 2025 / early 2026, this is r1166 or a fork that targets 3.3.5a explicitly. Some private server addon authors maintain forks of Ace3 with patches for 3.3.5a quirks.

If using an Ace3 release directly from WoWAce, verify the `.toc` `## Interface` field is `30300`. If it is not, edit it. Some recent Ace3 releases target only retail.

## .luacheckrc

`Decay/.luacheckrc`:

```lua
std = "lua51+playerwow"

stds.playerwow = {
  globals = {
    "Decay", "DecayDB", "L",
  },
  read_globals = {
    "LibStub", "GetTime", "UnitAura", "UnitExists", "UnitGUID",
    "UnitClass", "UnitName", "UnitIsPlayer",
    "GetSpellInfo", "GetSpellTexture", "GetSpellBookItemInfo",
    "PickupSpell", "ClearCursor", "CursorHasSpell", "GetCursorInfo",
    "CreateFrame", "InCombatLockdown",
    "UIParent", "GameTooltip",
    "PLAYER_LOGIN", "UNIT_AURA",
    "string", "table", "math", "tostring", "tonumber",
    "pairs", "ipairs", "select", "type", "unpack", "next",
    "format", "floor", "ceil", "min", "max", "abs",
  },
}

ignore = {
  "212",  -- unused argument
  "213",  -- unused loop variable
  "611",  -- whitespace at end of line (sometimes needed in localization)
}
```

## package.sh

`package.sh` at the repo root:

```bash
#!/bin/bash
set -e

VERSION=$(grep "^## Version:" Decay/Decay.toc | awk '{print $3}')
ZIP_NAME="Decay-${VERSION}.zip"

rm -f "$ZIP_NAME"

cd "$(dirname "$0")"
zip -r "$ZIP_NAME" Decay/ \
  -x "Decay/.git*" \
  -x "Decay/*.md" \
  -x "Decay/.luacheckrc"

echo "Built: $ZIP_NAME"
```

The script excludes the source-only files (`.git`, READMEs at the addon root, the linter config) while including everything else needed at runtime.

## Repository layout

The repository root layout:

```
Decay/                    -- the addon (this is what gets zipped)
docs/                     -- spec, architecture, doc references
README.md
SPEC.md
ARCHITECTURE.md
ROADMAP.md
CLAUDE.md
LICENSE
package.sh
.gitignore
.luacheckrc
```

`.gitignore`:

```
*.zip
.DS_Store
*.bak
```

## Saved variables file location

When the user plays, WoW writes the SavedVariables to:

```
WoW/WTF/Account/<account>/SavedVariables/Decay.lua
```

This is auto-managed by WoW; the addon does not interact with the file directly.
