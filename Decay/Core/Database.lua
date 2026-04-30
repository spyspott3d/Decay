local Decay = _G.Decay
Decay.Database = Decay.Database or {}
local Database = Decay.Database

local defaults = {
  global = {
    bars = {},
    state = {
      unlocked = false,
    },
  },
}

function Database:Init()
  self.aceDB = LibStub("AceDB-3.0"):New("DecayDB", defaults, true)
  Decay.db = self.aceDB
end
