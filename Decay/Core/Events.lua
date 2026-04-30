local Decay = _G.Decay
Decay.Events = Decay.Events or {}
local Events = Decay.Events

function Events:RegisterAll()
  Decay:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
  Decay:RegisterEvent("UNIT_AURA", "OnUnitAura")
  Decay:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetChanged")
  Decay:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
  Decay:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")
end
