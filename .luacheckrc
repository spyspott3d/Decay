std = "lua51+playerwow"

exclude_files = {
  "Decay/Libs/",
}

stds.playerwow = {
  globals = {
    "Decay", "DecayDB", "L", "StaticPopupDialogs",
  },
  read_globals = {
    "LibStub", "GetTime", "UnitAura", "UnitExists", "UnitGUID",
    "UnitClass", "UnitName", "UnitIsPlayer",
    "GetSpellInfo", "GetSpellTexture", "GetSpellBookItemInfo",
    "GetSpellLink", "GetSpellBookItemName",
    "PickupSpell", "ClearCursor", "CursorHasSpell", "GetCursorInfo",
    "CreateFrame", "InCombatLockdown", "GetLocale", "IsInInstance",
    "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown",
    "EasyMenu", "StaticPopup_Show", "LoadAddOn",
    "UIParent", "GameTooltip", "ACCEPT", "CANCEL",
    "PLAYER_LOGIN", "UNIT_AURA",
    "string", "table", "math", "tostring", "tonumber",
    "pairs", "ipairs", "select", "type", "unpack", "next",
    "format", "floor", "ceil", "min", "max", "abs",
    "_G", "pcall",
  },
}

ignore = {
  "212",
  "213",
  "611",
}
