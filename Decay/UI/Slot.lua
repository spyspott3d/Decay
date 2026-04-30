local Decay = _G.Decay
Decay.UI = Decay.UI or {}
Decay.UI.Slot = Decay.UI.Slot or {}
local Slot = Decay.UI.Slot

local L = LibStub("AceLocale-3.0"):GetLocale("Decay")

local CreateFrame = CreateFrame
local UIParent = UIParent
local IsShiftKeyDown = IsShiftKeyDown
local CursorHasSpell = CursorHasSpell
local EasyMenu = EasyMenu
local max = math.max

local SLOT_FRAME_PREFIX = "DecaySlotFrame"
local PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local ARMED_COLOR = { 0.247, 0.749, 0.247, 1.0 }
local EMPTY_COLOR = { 0.4, 0.4, 0.4, 0.6 }

local menuFrame = CreateFrame("Frame", "DecaySlotContextMenu", UIParent, "UIDropDownMenuTemplate")

local methods = {}
methods.__index = methods

function methods:GetConfig()
  local slots = self.barWidget.config.slots
  return slots and slots[self.index]
end

function methods:Assign(spellName, spellID, icon)
  local bc = self.barWidget.config
  bc.slots = bc.slots or {}
  bc.slots[self.index] = {
    spellName = spellName,
    spellID = spellID,
    auraName = spellName,
    auraIcon = icon,
    auraType = Decay.Heuristics:ClassifySpell(spellID),
  }
  self:RefreshDisplay()
end

function methods:Clear()
  local slots = self.barWidget.config.slots
  if slots then slots[self.index] = nil end
  self:RefreshDisplay()
end

function methods:SetAuraType(t)
  local cfg = self:GetConfig()
  if cfg then cfg.auraType = t end
end

function methods:RefreshDisplay()
  local cfg = self:GetConfig()
  if cfg then
    self.icon:SetTexture(cfg.auraIcon or PLACEHOLDER_ICON)
    self.icon:SetVertexColor(1, 1, 1, 1)
    self.bar:SetStatusBarColor(ARMED_COLOR[1], ARMED_COLOR[2], ARMED_COLOR[3], ARMED_COLOR[4])
  else
    self.icon:SetTexture(PLACEHOLDER_ICON)
    self.icon:SetVertexColor(0.5, 0.5, 0.5, 0.7)
    self.bar:SetStatusBarColor(EMPTY_COLOR[1], EMPTY_COLOR[2], EMPTY_COLOR[3], EMPTY_COLOR[4])
  end
end

function methods:ApplyLockState(unlocked)
  self.frame:EnableMouse(unlocked)
end

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
  if Decay.UI.DragDrop and Decay.UI.DragDrop.heldSlot == self then
    Decay.UI.DragDrop.heldSlot = nil
  end
  self.frame:Hide()
  self.frame:SetParent(nil)
  self.frame:SetAlpha(1.0)
  self.frame = nil
  self.icon = nil
  self.bar = nil
  self.text = nil
end

local function showContextMenu(slot)
  local cfg = slot:GetConfig()
  local items
  if cfg then
    items = {
      { text = L["Clear"], notCheckable = true,
        func = function() slot:Clear() end },
      { text = L["Set as buff"], checked = cfg.auraType == "buff",
        func = function() slot:SetAuraType("buff") end },
      { text = L["Set as debuff"], checked = cfg.auraType == "debuff",
        func = function() slot:SetAuraType("debuff") end },
      { text = L["Move slot"], notCheckable = true,
        func = function() Decay.UI.DragDrop:PickupSlot(slot) end },
      { text = CANCEL, notCheckable = true, func = function() end },
    }
  else
    items = {
      { text = L["Manual entry"], notCheckable = true,
        func = function() Decay.UI.DragDrop:OpenManualEntry(slot) end },
      { text = CANCEL, notCheckable = true, func = function() end },
    }
  end
  EasyMenu(items, menuFrame, "cursor", 0, 0, "MENU")
end

local function slotOnMouseUp(slot, button)
  if not Decay.db.global.state.unlocked then return end

  if button == "RightButton" then
    showContextMenu(slot)
    return
  end

  if button == "LeftButton" then
    if Decay.UI.DragDrop:IsHoldingSlot() then
      Decay.UI.DragDrop:DropSlotOn(slot)
      return
    end
    if CursorHasSpell() then
      Decay.UI.DragDrop:HandleSpellDropOn(slot)
      return
    end
    if IsShiftKeyDown() and not slot:GetConfig() then
      Decay.UI.DragDrop:OpenManualEntry(slot)
      return
    end
  end
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

  local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("CENTER")
  text:SetText("--")

  local widget = setmetatable({
    frame = frame,
    icon = icon,
    bar = bar,
    text = text,
    barWidget = barWidget,
    index = slotIndex,
  }, methods)

  frame:SetScript("OnMouseUp", function(_, button) slotOnMouseUp(widget, button) end)

  widget:RefreshDisplay()
  return widget
end
