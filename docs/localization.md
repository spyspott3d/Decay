# Localization

Decay ships with five locales: enUS, frFR, deDE, esES, zhCN. The default fallback is enUS.

## Locale system

The standard AceLocale-3.0 pattern is used. Each locale file looks like:

```lua
local L = LibStub("AceLocale-3.0"):NewLocale("Decay", "frFR")
if not L then return end

L["Bars"] = "Barres"
L["New bar"] = "Nouvelle barre"
L["Slot count"] = "Nombre d'emplacements"
-- ... etc
```

Inside Decay code, strings are accessed via:

```lua
local L = LibStub("AceLocale-3.0"):GetLocale("Decay")
print(L["Bars"])
```

Missing keys in non-default locales fall back to enUS automatically. Missing keys in enUS print the key itself in red as a developer warning.

## What gets localized

Every user-facing string flows through `L[...]`:
- Configuration window labels.
- Slash command help text.
- Tooltips on options.
- Error and warning messages in `/decay logs`.
- Confirmation dialog text.

What does NOT get localized:
- Internal log messages (developer-facing).
- Bar names entered by the user (they are user-defined free text).
- Spell and aura names (these come from WoW itself, already locale-correct).

## Heuristic verb lists

The buff vs debuff auto-detection (SPEC section 4.1) reads the spell tooltip and looks for verbs that suggest a debuff. The verb lists are locale-specific.

`Locale/heuristics/enUS.lua`:

```lua
local Heuristics = Decay.Heuristics or {}
Decay.Heuristics = Heuristics

Heuristics.enUS = {
  debuffMarkers = {
    "deals",
    "damage",
    "reduces",
    "stuns",
    "snares",
    "decreases",
    "lowers",
    "drains",
    "burns",
    "afflicts",
    "stunned",
    "rooted",
    "silenced",
    "fears",
    "polymorphs",
    "incapacitates",
    "disorients",
    "bleeds",
    "poisoned",
    "diseased",
  },
}
```

`Locale/heuristics/frFR.lua`:

```lua
Heuristics.frFR = {
  debuffMarkers = {
    "inflige",
    "dégâts",
    "réduit",
    "étourdit",
    "ralentit",
    "diminue",
    "abaisse",
    "draine",
    "brûle",
    "afflige",
    "étourdi",
    "enraciné",
    "réduit au silence",
    "effraie",
    "métamorphose",
    "incapacite",
    "désoriente",
    "saigne",
    "empoisonné",
    "malade",
  },
}
```

Similar lists for deDE, esES, zhCN. The lists are hand-curated based on actual WoW 3.3.5a tooltip text in each locale. Translations should be reviewed by a native speaker familiar with the WoW UI in that language before release.

## Locale detection

`GetLocale()` returns the current client locale. Decay uses this to:
1. Pick the right `L` table (handled by AceLocale).
2. Pick the right heuristics list at slot assignment time:

```lua
local clientLocale = GetLocale()
local heuristics = Decay.Heuristics[clientLocale] or Decay.Heuristics.enUS
```

## Translation workflow

1. The enUS file is the source of truth. Add new strings there first.
2. For each new string, generate translations via machine translation as a starting point.
3. Have a native speaker review translations before merging. Pay attention to UI conventions in each language (German tends to use longer compound words; Chinese uses shorter strings; French uses "-" as conjunction with care).
4. Test the locale in-game by setting the client locale and visually inspecting all UI text for overflow or wrapping issues.

## Strings glossary

A consistent translation glossary across all locales prevents drift:

| Concept | enUS | frFR | deDE | esES | zhCN |
|---|---|---|---|---|---|
| spell bar | Bar | Barre | Leiste | Barra | 条 |
| slot | Slot | Emplacement | Platz | Hueco | 槽位 |
| aura | Aura | Aura | Aura | Aura | 光环 |
| buff | Buff | Buff | Buff | Beneficio | 增益 |
| debuff | Debuff | Debuff | Debuff | Perjuicio | 减益 |
| threshold | Threshold | Seuil | Schwelle | Umbral | 阈值 |
| timer | Timer | Minuteur | Timer | Temporizador | 计时器 |
| orientation | Orientation | Orientation | Ausrichtung | Orientación | 方向 |
| fade direction | Fade direction | Sens de la barre | Auslaufrichtung | Dirección de fade | 淡出方向 |
| unlock | Unlock | Déverrouiller | Entsperren | Desbloquear | 解锁 |
| lock | Lock | Verrouiller | Sperren | Bloquear | 锁定 |

When translating new strings, refer to this glossary first. Do not introduce new translations for existing concepts.

## Testing locales

To test a non-default locale on a client running a different locale:

1. Set `Decay.forcedLocale = "frFR"` via the in-game console.
2. Reload the UI.
3. AceLocale will use the forced locale instead of `GetLocale()`.

This bypass exists in code only via a test hook; it is not exposed in the user-facing options. Reset by removing the hook or setting it to `nil`.
