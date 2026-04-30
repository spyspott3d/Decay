local Decay = _G.Decay
Decay.UI = Decay.UI or {}
Decay.UI.BarManager = Decay.UI.BarManager or {}
local BarManager = Decay.UI.BarManager

local GetTime = GetTime

BarManager.bars = {}

local idCounter = 0
local function generateId()
  idCounter = idCounter + 1
  return "bar-" .. tostring(math.floor(GetTime() * 1000)) .. "-" .. idCounter
end

local function defaultBarConfig(index)
  return {
    id = generateId(),
    name = "Bar " .. index,
    position = {
      point = "CENTER",
      relativeTo = "UIParent",
      relativePoint = "CENTER",
      x = 0,
      y = -100,
    },
  }
end

function BarManager:RestoreAll()
  for _, barConfig in ipairs(Decay.db.global.bars) do
    self.bars[barConfig.id] = Decay.UI.Bar.New(barConfig)
  end
end

function BarManager:CreateBar()
  local barConfig = defaultBarConfig(#Decay.db.global.bars + 1)
  table.insert(Decay.db.global.bars, barConfig)
  self.bars[barConfig.id] = Decay.UI.Bar.New(barConfig)
  return barConfig
end

function BarManager:DeleteBar(barId)
  for i, bc in ipairs(Decay.db.global.bars) do
    if bc.id == barId then
      table.remove(Decay.db.global.bars, i)
      break
    end
  end
  if self.bars[barId] then
    self.bars[barId]:Destroy()
    self.bars[barId] = nil
  end
end

function BarManager:ApplyLockState()
  local unlocked = Decay.db.global.state.unlocked
  for _, widget in pairs(self.bars) do
    widget:ApplyLockState(unlocked)
  end
end
