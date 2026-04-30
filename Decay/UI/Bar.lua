local Decay = _G.Decay
Decay.UI = Decay.UI or {}
Decay.UI.Bar = Decay.UI.Bar or {}
local Bar = Decay.UI.Bar

local CreateFrame = CreateFrame
local UIParent = UIParent

local PLACEHOLDER_W = 200
local PLACEHOLDER_H = 40
local FRAME_PREFIX = "DecayBarFrame"
local frameCounter = 0

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

function methods:Destroy()
  self.frame:Hide()
  self.frame:EnableMouse(false)
  self.frame:SetScript("OnDragStart", nil)
  self.frame:SetScript("OnDragStop", nil)
  self.frame:SetParent(nil)
  self.frame = nil
end

function Bar.New(barConfig)
  frameCounter = frameCounter + 1
  local frame = CreateFrame("Frame", FRAME_PREFIX..frameCounter, UIParent)
  frame:SetSize(PLACEHOLDER_W, PLACEHOLDER_H)

  local tex = frame:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints()
  tex:SetTexture("Interface\\Buttons\\WHITE8X8")
  tex:SetVertexColor(0.4, 0.4, 0.4, 0.85)

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

  local widget = setmetatable({ frame = frame, config = barConfig }, methods)
  widget:ApplyPosition()
  widget:ApplyLockState(Decay.db.global.state.unlocked)
  return widget
end
