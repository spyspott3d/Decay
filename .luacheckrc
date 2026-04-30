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
  "212",
  "213",
  "611",
}
