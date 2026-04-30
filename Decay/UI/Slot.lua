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
local GetTime = GetTime
local floor = math.floor
local max = math.max
local unpack = unpack
local tostring = tostring

local SLOT_FRAME_PREFIX = "DecaySlotFrame"
local PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local INACTIVE_BAR_COLOR = { 0.4, 0.4, 0.4, 0.6 }
local EMPTY_BAR_COLOR = { 0.3, 0.3, 0.3, 0.4 }
local THROTTLE = 0.05
local TIMER_FONT = "Fonts\\FRIZQT__.TTF"

local menuFrame = CreateFrame("Frame", "DecaySlotContextMenu", UIParent, "UIDropDownMenuTemplate")

local methods = {}
methods.__index = methods

function methods:Key()
  return self.barWidget.config.id .. ":" .. self.index
end

function methods:GetConfig()
  local slots = self.barWidget.config.slots
  return slots and slots[self.index]
end

local function setTimerText(widget, remaining)
  if not widget.showTimerText then
    widget.text:SetText("")
    return
  end
  local format = widget.timerFormat or "auto"
  if format == "seconds" then
    widget.text:SetFormattedText("%d", remaining)
  elseif format == "mm:ss" then
    widget.text:SetFormattedText("%d:%02d", floor(remaining/60), floor(remaining%60))
  else
    if remaining >= 60 then
      widget.text:SetFormattedText("%d:%02d", floor(remaining/60), floor(remaining%60))
    elseif remaining >= 10 then
      widget.text:SetFormattedText("%d", remaining)
    else
      widget.text:SetFormattedText("%.1f", remaining)
    end
  end
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
  self:UpdateVisibility()
  Decay.AuraScanner:ScanUnit(bc.slots[self.index].auraType == "buff" and "player" or "target")
end

function methods:Clear()
  local key = self:Key()
  Decay.State.activeSlots[key] = nil
  local slots = self.barWidget.config.slots
  if slots then slots[self.index] = nil end
  self.frame:SetScript("OnUpdate", nil)
  self:RefreshDisplay()
  self:UpdateVisibility()
  self.barWidget:RelayoutIfDynamic()
end

function methods:SetAuraType(t)
  local cfg = self:GetConfig()
  if not cfg then return end
  cfg.auraType = t
  cfg.warning = nil
  Decay.State.activeSlots[self:Key()] = nil
  self.frame:SetScript("OnUpdate", nil)
  self:RefreshDisplay()
  self:UpdateVisibility()
  Decay.AuraScanner:ScanUnit(t == "buff" and "player" or "target")
end

function methods:SetAuraName(name)
  local cfg = self:GetConfig()
  if not cfg or not name or name == "" then return end
  cfg.auraName = name
  Decay.State.activeSlots[self:Key()] = nil
  self.frame:SetScript("OnUpdate", nil)
  self:RefreshDisplay()
  self:UpdateVisibility()
  Decay.AuraScanner:RescanAll()
end

function methods:RefreshDisplay()
  if self.fillLength then self:RestoreFullBarSize() end
  local cfg = self:GetConfig()
  if cfg then
    self.icon:SetTexture(cfg.auraIcon or PLACEHOLDER_ICON)
    self.icon:SetVertexColor(1, 1, 1, 1)
    self.bar:SetValue(0)
    self.bar:SetStatusBarColor(unpack(INACTIVE_BAR_COLOR))
    self.text:SetText("")
  else
    self.icon:SetTexture(PLACEHOLDER_ICON)
    self.icon:SetVertexColor(0.5, 0.5, 0.5, 0.7)
    self.bar:SetValue(0)
    self.bar:SetStatusBarColor(unpack(EMPTY_BAR_COLOR))
    self.text:SetText("")
  end
  self.stackText:Hide()
end

function methods:RefreshActiveDisplay()
  local data = Decay.State.activeSlots[self:Key()]
  local cfg = self:GetConfig()
  if not data or not cfg then return end

  self.icon:SetTexture(data.auraIcon or cfg.auraIcon or PLACEHOLDER_ICON)
  self.icon:SetVertexColor(1, 1, 1, 1)

  if self.fillLength then
    self.bar:SetValue(1)
    local settings = Decay.db.global.settings
    local colors = settings.colors
    if data.duration == 0 then
      self:SetFill(1)
      self.bar:SetStatusBarColor(unpack(colors.green))
      if self.showTimerText then self.text:SetText("∞") else self.text:SetText("") end
    else
      local remaining = data.expirationTime - GetTime()
      if remaining < 0 then remaining = 0 end
      local pct = remaining / data.duration
      self:SetFill(pct)
      local thresholds = settings.thresholds
      if pct >= thresholds.yellow then
        self.bar:SetStatusBarColor(unpack(colors.green))
      elseif pct >= thresholds.red then
        self.bar:SetStatusBarColor(unpack(colors.yellow))
      else
        self.bar:SetStatusBarColor(unpack(colors.red))
      end
      setTimerText(self, remaining)
    end
  end

  if data.stackCount and data.stackCount > 1 then
    self.stackText:SetText(tostring(data.stackCount))
    self.stackText:Show()
  else
    self.stackText:Hide()
  end

  self.barWidget:RelayoutIfDynamic()
end

local function slotOnUpdate(frame, elapsed)
  local widget = frame.decSlotWidget
  if not widget then
    frame:SetScript("OnUpdate", nil)
    return
  end

  widget.elapsed = (widget.elapsed or 0) + elapsed
  if widget.elapsed < THROTTLE then return end
  widget.elapsed = 0

  local data = Decay.State.activeSlots[widget:Key()]
  if not data then
    frame:SetScript("OnUpdate", nil)
    widget:UpdateVisibility()
    return
  end

  local settings = Decay.db.global.settings
  local colors = settings.colors

  if data.duration == 0 then
    widget:SetFill(1)
    widget.bar:SetValue(1)
    widget.bar:SetStatusBarColor(unpack(colors.green))
    if widget.showTimerText then widget.text:SetText("∞") else widget.text:SetText("") end
    return
  end

  local remaining = data.expirationTime - GetTime()
  if remaining <= 0 then
    Decay.State.activeSlots[widget:Key()] = nil
    frame:SetScript("OnUpdate", nil)
    widget:Deactivate()
    return
  end

  local pct = remaining / data.duration
  widget:SetFill(pct)
  widget.bar:SetValue(1)

  local thresholds = settings.thresholds
  if pct >= thresholds.yellow then
    widget.bar:SetStatusBarColor(unpack(colors.green))
  elseif pct >= thresholds.red then
    widget.bar:SetStatusBarColor(unpack(colors.yellow))
  else
    widget.bar:SetStatusBarColor(unpack(colors.red))
  end

  setTimerText(widget, remaining)
end

function methods:Activate()
  self:RefreshActiveDisplay()
  self:UpdateVisibility()
  self.elapsed = 0
  self.frame:SetScript("OnUpdate", slotOnUpdate)
  self.barWidget:RelayoutIfDynamic()
end

function methods:Deactivate()
  self.frame:SetScript("OnUpdate", nil)
  self:RefreshDisplay()
  self:UpdateVisibility()
  self.barWidget:RelayoutIfDynamic()
end

function methods:UpdateVisibility()
  local active = Decay.State.activeSlots[self:Key()]
  local unlocked = Decay.db.global.state.unlocked
  if active or unlocked then
    self.frame:Show()
  else
    self.frame:Hide()
  end
end

function methods:ApplyLockState(unlocked)
  self.frame:EnableMouse(unlocked)
  self:UpdateVisibility()
end

function methods:Layout(orientation, fadeDirection, iconSize, barLength, barThickness)
  self.icon:ClearAllPoints()
  self.icon:SetSize(iconSize, iconSize)
  self.bar:ClearAllPoints()

  self.fillLength = barLength
  self.fillThickness = barThickness

  if orientation == "horizontal" then
    self.frame:SetSize(max(iconSize, barThickness), iconSize + barLength)
    self.fillAxis = "height"
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
    self.fillAxis = "width"
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

  local data = Decay.State and Decay.State.activeSlots[self:Key()]
  if data then
    if data.duration == 0 then
      self:SetFill(1)
    else
      local remaining = data.expirationTime - GetTime()
      if remaining < 0 then remaining = 0 end
      self:SetFill(remaining / data.duration)
    end
  end
end

function methods:ApplyTimerSettings(showText, size, format)
  self.showTimerText = showText and true or false
  self.timerFormat = format or "auto"
  self.text:SetFont(TIMER_FONT, size or 12, "OUTLINE")
end

function methods:ApplyTexture(texture)
  self.bar:SetStatusBarTexture(texture or DEFAULT_BAR_TEXTURE)
end

function methods:SetFill(pct)
  if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
  if self.fillAxis == "height" then
    self.bar:SetHeight(pct * self.fillLength)
  else
    self.bar:SetWidth(pct * self.fillLength)
  end
end

function methods:RestoreFullBarSize()
  if self.fillAxis == "height" then
    self.bar:SetHeight(self.fillLength)
  else
    self.bar:SetWidth(self.fillLength)
  end
end

function methods:Destroy()
  if Decay.UI.DragDrop and Decay.UI.DragDrop.heldSlot == self then
    Decay.UI.DragDrop.heldSlot = nil
  end
  Decay.State.activeSlots[self:Key()] = nil
  self.frame:SetScript("OnUpdate", nil)
  self.frame.decSlotWidget = nil
  self.frame:Hide()
  self.frame:SetParent(nil)
  self.frame:SetAlpha(1.0)
  self.frame = nil
  self.icon = nil
  self.bar = nil
  self.text = nil
  self.stackText = nil
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
      { text = L["Edit aura name"], notCheckable = true,
        func = function() Decay.UI.DragDrop:OpenAuraNameEdit(slot) end },
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
  bar:SetValue(0)

  local text = bar:CreateFontString(nil, "OVERLAY")
  text:SetFont(TIMER_FONT, 12, "OUTLINE")
  text:SetPoint("CENTER")
  text:SetText("")

  local stackText = frame:CreateFontString(nil, "OVERLAY")
  stackText:SetFont(TIMER_FONT, 12, "OUTLINE")
  stackText:SetTextColor(1, 1, 1, 1)
  stackText:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 2, 2)
  stackText:Hide()

  local widget = setmetatable({
    frame = frame,
    icon = icon,
    bar = bar,
    text = text,
    stackText = stackText,
    barWidget = barWidget,
    index = slotIndex,
    elapsed = 0,
    showTimerText = true,
    timerFormat = "auto",
  }, methods)

  frame.decSlotWidget = widget
  frame:SetScript("OnMouseUp", function(_, button) slotOnMouseUp(widget, button) end)

  widget:RefreshDisplay()
  return widget
end
