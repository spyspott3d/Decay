local Decay = _G.Decay
Decay.State = Decay.State or {}
local State = Decay.State

State.activeSlots = {}
State.inCombat = false
State.currentTargetGUID = nil
State.pendingMatch = {}

function State:Reset()
  self.activeSlots = {}
  self.pendingMatch = {}
  self.currentTargetGUID = nil
end
