local Decay = _G.Decay
Decay.Database = Decay.Database or {}
local Database = Decay.Database

local defaults = {
  profile = {
    bars = {},
    state = {
      unlocked = false,
    },
    settings = {
      thresholds = {
        yellow = 0.5,
        red = 0.25,
      },
      colors = {
        green  = { 0.247, 0.749, 0.247, 1.0 },
        yellow = { 0.898, 0.753, 0.235, 1.0 },
        red    = { 0.816, 0.251, 0.251, 1.0 },
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
  },
}

-- V1.0.0 called AceDB:New(..., true) which forced every character onto the
-- shared "Default" profile. AceDB persisted that choice into sv.profileKeys
-- on each login, so on update those mappings keep redirecting all characters
-- to "Default". Drop them before AceDB:New so per-character profiles take over.
local function clearLegacyDefaultMappings(sv)
  if not sv or not sv.profileKeys then return end
  for charKey, prof in pairs(sv.profileKeys) do
    if prof == "Default" then sv.profileKeys[charKey] = nil end
  end
end

-- Recursively writes src into dest, overwriting dest values with src values
-- and creating subtables as needed.
local function deepMerge(dest, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dest[k]) ~= "table" then dest[k] = {} end
      deepMerge(dest[k], v)
    else
      dest[k] = v
    end
  end
end

-- Adds keys missing from dest that exist in src, recursing into subtables.
-- Used to repair profiles where keys may have been stripped (AceDB removes
-- values matching defaults at logout, and a wholesale table assignment can
-- bypass AceDB's lazy refill).
local function ensureDefaults(dest, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dest[k]) ~= "table" then dest[k] = {} end
      ensureDefaults(dest[k], v)
    elseif dest[k] == nil then
      dest[k] = v
    end
  end
end

local function migrateLegacyData(db)
  local sv = _G.DecayDB
  if not sv then return end

  local profile = db.profile
  local profileEmpty = (not profile.bars or #profile.bars == 0)

  if profileEmpty then
    local source
    if sv.global and sv.global.bars and #sv.global.bars > 0 then
      source = sv.global
    elseif sv.profiles and sv.profiles["Default"] then
      local d = sv.profiles["Default"]
      if d.bars and #d.bars > 0 then source = d end
    end

    if source then
      profile.bars = source.bars
      if source.state    then deepMerge(profile.state,    source.state)    end
      if source.settings then deepMerge(profile.settings, source.settings) end

      local L = LibStub("AceLocale-3.0"):GetLocale("Decay", true)
      local msg = (L and L["Settings migrated to character profile: %s"]) or "Settings migrated to character profile: %s"
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDecay|r: " .. msg:format(db.keys.profile))
      end
    end
  end

  if sv.global then
    sv.global.bars = nil
    sv.global.state = nil
    sv.global.settings = nil
  end
  if sv.profiles then sv.profiles["Default"] = nil end

  ensureDefaults(profile, defaults.profile)
end

function Database:Init()
  clearLegacyDefaultMappings(_G.DecayDB)
  self.aceDB = LibStub("AceDB-3.0"):New("DecayDB", defaults)
  Decay.db = self.aceDB
  migrateLegacyData(self.aceDB)
end
