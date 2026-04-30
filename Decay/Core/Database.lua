local Decay = _G.Decay
Decay.Database = Decay.Database or {}
local Database = Decay.Database

local defaults = {
  global = {
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

function Database:Init()
  self.aceDB = LibStub("AceDB-3.0"):New("DecayDB", defaults, true)
  Decay.db = self.aceDB
end
