local Decay = _G.Decay
Decay.UI = Decay.UI or {}
Decay.UI.BarManager = Decay.UI.BarManager or {}
local BarManager = Decay.UI.BarManager

local L = LibStub("AceLocale-3.0"):GetLocale("Decay")
local GetTime = GetTime

BarManager.bars = {}

local idCounter = 0
local function generateId()
  idCounter = idCounter + 1
  return "bar-" .. tostring(math.floor(GetTime() * 1000)) .. "-" .. idCounter
end

local function defaultName(index)
  return L["Bar"] .. " " .. index
end

local function isDefaultName(name)
  if not name then return false end
  local prefix = L["Bar"] .. " "
  if name:sub(1, #prefix) ~= prefix then return false end
  return name:sub(#prefix + 1):match("^%d+$") ~= nil
end

local function defaultBarConfig(index)
  return {
    id = generateId(),
    name = defaultName(index),
    orientation = "horizontal",
    fadeDirection = "above",
    slotCount = 4,
    slots = {},
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
  self:RenameDefaults()
end

function BarManager:RenameDefaults()
  for i, bc in ipairs(Decay.db.global.bars) do
    if isDefaultName(bc.name) then
      bc.name = defaultName(i)
    end
  end
end

function BarManager:UpdateBar(barId)
  local widget = self.bars[barId]
  if not widget then return end
  widget:UpdateLayout()
  if Decay.AuraScanner then
    Decay.AuraScanner:RescanAll()
  end
end

function BarManager:ApplyLockState()
  local unlocked = Decay.db.global.state.unlocked
  for _, widget in pairs(self.bars) do
    widget:ApplyLockState(unlocked)
  end
end
