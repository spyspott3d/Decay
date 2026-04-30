local Decay = _G.Decay
Decay.UI = Decay.UI or {}
Decay.UI.Slot = Decay.UI.Slot or {}
local Slot = Decay.UI.Slot

local CreateFrame = CreateFrame
local max = math.max

local SLOT_FRAME_PREFIX = "DecaySlotFrame"
local PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local DEFAULT_BAR_COLOR = { 0.247, 0.749, 0.247, 1.0 }

local methods = {}
methods.__index = methods

function methods:Layout(orientation, fadeDirection, iconSize, barLength, barThickness)
  self.icon:ClearAllPoints()
  self.icon:SetSize(iconSize, iconSize)
  self.bar:ClearAllPoints()

  if orientation == "horizontal" then
    self.frame:SetSize(max(iconSize, barThickness), iconSize + barLength)
    self.bar:SetSize(barThickness, barLength)
    self.bar:SetOrientation("VERTICAL")
    if fadeDirection == "below" then
      self.icon:SetPoint("TOP", self.frame, "TOP")
      self.bar:SetPoint("TOP", self.icon, "BOTTOM")
    else
      self.icon:SetPoint("BOTTOM", self.frame, "BOTTOM")
      self.bar:SetPoint("BOTTOM", self.icon, "TOP")
    end
  else
    self.frame:SetSize(iconSize + barLength, max(iconSize, barThickness))
    self.bar:SetSize(barLength, barThickness)
    self.bar:SetOrientation("HORIZONTAL")
    if fadeDirection == "right" then
      self.icon:SetPoint("LEFT", self.frame, "LEFT")
      self.bar:SetPoint("LEFT", self.icon, "RIGHT")
    else
      self.icon:SetPoint("RIGHT", self.frame, "RIGHT")
      self.bar:SetPoint("RIGHT", self.icon, "LEFT")
    end
  end
end

function methods:Destroy()
  self.frame:Hide()
  self.frame:SetParent(nil)
  self.frame = nil
  self.icon = nil
  self.bar = nil
  self.text = nil
end

local slotCounter = 0

function Slot.New(barWidget, slotIndex)
  slotCounter = slotCounter + 1
  local frame = CreateFrame("Frame", SLOT_FRAME_PREFIX..slotCounter, barWidget.frame)
  frame:EnableMouse(false)

  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(PLACEHOLDER_ICON)

  local bar = CreateFrame("StatusBar", nil, frame)
  bar:SetStatusBarTexture(DEFAULT_BAR_TEXTURE)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  bar:SetStatusBarColor(DEFAULT_BAR_COLOR[1], DEFAULT_BAR_COLOR[2], DEFAULT_BAR_COLOR[3], DEFAULT_BAR_COLOR[4])

  local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("CENTER")
  text:SetText("--")

  return setmetatable({
    frame = frame,
    icon = icon,
    bar = bar,
    text = text,
    barWidget = barWidget,
    index = slotIndex,
  }, methods)
end
