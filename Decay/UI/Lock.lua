local Decay = _G.Decay
Decay.UI = Decay.UI or {}
Decay.UI.Lock = Decay.UI.Lock or {}
local Lock = Decay.UI.Lock

function Lock:Set(unlocked)
  Decay.db.global.state.unlocked = unlocked and true or false
  Decay.UI.BarManager:ApplyLockState()
end

function Lock:Toggle()
  self:Set(not Decay.db.global.state.unlocked)
end

function Lock:IsUnlocked()
  return Decay.db.global.state.unlocked
end
