local Decay = _G.Decay
Decay.UI = Decay.UI or {}
Decay.UI.Bar = Decay.UI.Bar or {}
local Bar = Decay.UI.Bar

local CreateFrame = CreateFrame
local UIParent = UIParent
local max = math.max

local FRAME_PREFIX = "DecayBarFrame"
local frameCounter = 0

local ICON_SIZE = 32
local BAR_LENGTH = 100
local BAR_THICKNESS = 32
local SPACING = 4

local methods = {}
methods.__index = methods

function methods:ApplyPosition()
  local pos = self.config.position
  self.frame:ClearAllPoints()
  self.frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

function methods:ApplyLockState(unlocked)
  self.frame:EnableMouse(unlocked)
end

function methods:CreateSlots()
  local target = self.config.slotCount
  for i = #self.slots + 1, target do
    self.slots[i] = Decay.UI.Slot.New(self, i)
  end
  for i = #self.slots, target + 1, -1 do
    self.slots[i]:Destroy()
    self.slots[i] = nil
  end
end

function methods:LayoutSlots()
  local config = self.config
  local orientation = config.orientation
  local fadeDir = config.fadeDirection
  local horizontal = orientation == "horizontal"

  for i = 1, config.slotCount do
    local slot = self.slots[i]
    slot:Layout(orientation, fadeDir, ICON_SIZE, BAR_LENGTH, BAR_THICKNESS)
    slot.frame:ClearAllPoints()
    if horizontal then
      local x = (i - 1) * (max(ICON_SIZE, BAR_THICKNESS) + SPACING)
      slot.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, 0)
    else
      local y = -(i - 1) * (max(ICON_SIZE, BAR_THICKNESS) + SPACING)
      slot.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, y)
    end
  end
end

function methods:Resize()
  local count = self.config.slotCount
  if self.config.orientation == "horizontal" then
    local slotW = max(ICON_SIZE, BAR_THICKNESS)
    local slotH = ICON_SIZE + BAR_LENGTH
    self.frame:SetSize(count * slotW + (count - 1) * SPACING, slotH)
  else
    local slotW = ICON_SIZE + BAR_LENGTH
    local slotH = max(ICON_SIZE, BAR_THICKNESS)
    self.frame:SetSize(slotW, count * slotH + (count - 1) * SPACING)
  end
end

function methods:UpdateLayout()
  self:CreateSlots()
  self:LayoutSlots()
  self:Resize()
end

function methods:Destroy()
  for i = 1, #self.slots do
    self.slots[i]:Destroy()
  end
  self.slots = {}
  self.frame:Hide()
  self.frame:EnableMouse(false)
  self.frame:SetScript("OnDragStart", nil)
  self.frame:SetScript("OnDragStop", nil)
  self.frame:SetParent(nil)
  self.frame = nil
end

local function applyDefaults(barConfig)
  barConfig.orientation = barConfig.orientation or "horizontal"
  barConfig.fadeDirection = barConfig.fadeDirection or "above"
  barConfig.slotCount = barConfig.slotCount or 4
end

function Bar.New(barConfig)
  applyDefaults(barConfig)

  frameCounter = frameCounter + 1
  local frame = CreateFrame("Frame", FRAME_PREFIX..frameCounter, UIParent)

  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if Decay.db.global.state.unlocked then
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    barConfig.position.point = point
    barConfig.position.relativeTo = "UIParent"
    barConfig.position.relativePoint = relativePoint
    barConfig.position.x = x
    barConfig.position.y = y
  end)

  local widget = setmetatable({
    frame = frame,
    config = barConfig,
    slots = {},
  }, methods)

  widget:UpdateLayout()
  widget:ApplyPosition()
  widget:ApplyLockState(Decay.db.global.state.unlocked)
  return widget
end
