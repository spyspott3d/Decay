local Decay = _G.Decay
Decay.Events = Decay.Events or {}
local Events = Decay.Events

local CreateFrame = CreateFrame

-- All Decay events are dispatched through a native Frame:RegisterEvent
-- + SetScript("OnEvent") rather than AceEvent's CallbackHandler-1.0
-- dispatch. CallbackHandler taints the secure call chain on 3.3.5a
-- Ascension when a UNIT_AURA / PLAYER_REGEN_* fires during a cast that
-- ends in a secure prompt (BindEnchant from a weapon enchant), which
-- blocks the prompt from completing. The native dispatcher below has
-- no Lua-side wrapper, so the secure path stays clean.

local handlers = {
  PLAYER_ENTERING_WORLD = "OnEnterWorld",
  UNIT_AURA             = "OnUnitAura",
  PLAYER_TARGET_CHANGED = "OnTargetChanged",
  PLAYER_REGEN_DISABLED = "OnEnterCombat",
  PLAYER_REGEN_ENABLED  = "OnLeaveCombat",
  ZONE_CHANGED_NEW_AREA = "OnZoneChanged",
}

local eventFrame = CreateFrame("Frame", "DecayEventFrame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
  local methodName = handlers[event]
  local fn = methodName and Decay[methodName]
  if fn then fn(Decay, event, ...) end
end)

function Events:RegisterAll()
  for event in pairs(handlers) do
    eventFrame:RegisterEvent(event)
  end
end
