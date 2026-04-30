# Decay

A self-buff and player-applied debuff tracker for World of Warcraft 3.3.5a (Wrath of the Lich King), designed primarily for the Ascension private server but compatible with any 3.3.5a client.

## What it does

Decay shows the remaining duration of buffs you have on yourself and debuffs you have applied on your current target. You configure one or more "spell bars" by drag-dropping spells from your spellbook into slots. Each tracked aura renders as a regression bar attached to the spell icon, with a numeric timer and a color that shifts from green to yellow to red as time runs out.

## Why another tracker

Most WotLK trackers (NeedToKnow, ClassTimer, SBF) date from 2009 to 2012 and assume a fixed class system. Ascension breaks that assumption with classless characters, random talents, and mystic enchants, which means tracking by spell name is more robust than tracking by class-keyed presets. Decay is built name-first, with no class assumptions, and ships only what is needed for tracking. No buff icons, no nameplates, no party frames.

## Status

V1.

## Install

1. Download the latest release zip from the GitHub releases page.
2. Extract into `Interface/AddOns/` so you have `Interface/AddOns/Decay/Decay.toc`.
3. Restart the client or reload UI with `/console reloadui`.
4. Open the config with `/decay` or `/dc`.

## Usage

- `/decay` or `/dc` opens the config window.
- `/decay unlock` makes bars draggable and reveals empty slots; `/decay lock` hides them again.
- Drag a spell from your spellbook onto an empty slot to track it. Right-click an armed slot for Clear / Set as buff / Set as debuff / Edit aura name / Move slot.
- Shift-click an empty slot in unlock mode to type an aura name manually (useful when the cast spell name and the applied aura name differ).

## Known limitation on Ascension

Applying a weapon enchant (poison, sharpening stone, etc.) to a non-soulbound weapon may show "AddOn 'Decay' tainted the call of the secure function 'BindEnchant()'" and block the prompt. This is a side effect of Ascension's particularly strict secure-function validator interacting with any addon that polls auras; the `/decay halt` slash command stops Decay's runtime in-place without a /reload as a quick workaround. Reload to resume.

## Compatibility

Tested on Ascension launcher. Should work on any 3.3.5a client (Warmane, Atlantiss, Tauri, custom Trinity-based servers). Not compatible with retail WoW or Classic Era. Interface version: 30300.

## License

MIT.

## Author

spyspott3d
