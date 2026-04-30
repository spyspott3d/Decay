local Decay = _G.Decay
Decay.UI = Decay.UI or {}
Decay.UI.DragDrop = Decay.UI.DragDrop or {}
local DragDrop = Decay.UI.DragDrop

local L = LibStub("AceLocale-3.0"):GetLocale("Decay")

local GetCursorInfo = GetCursorInfo
local GetSpellLink = GetSpellLink
local GetSpellInfo = GetSpellInfo
local GetSpellBookItemName = GetSpellBookItemName
local ClearCursor = ClearCursor
local CursorHasSpell = CursorHasSpell
local tonumber = tonumber

DragDrop.heldSlot = nil

local function readCursorSpell()
  local cursorType, slot, bookType = GetCursorInfo()
  if cursorType ~= "spell" then return nil end
  bookType = bookType or "spell"

  local link = GetSpellLink(slot, bookType)
  local spellID = link and tonumber(link:match("spell:(%d+)"))
  if not spellID then return nil end

  local name, _, icon = GetSpellInfo(spellID)
  if not name and GetSpellBookItemName then
    name = GetSpellBookItemName(slot, bookType)
  end
  if not name then return nil end

  return name, spellID, icon
end

function DragDrop:HandleSpellDropOn(slot)
  if not CursorHasSpell() then return end
  local name, spellID, icon = readCursorSpell()
  ClearCursor()
  if not name or not spellID then return end
  slot:Assign(name, spellID, icon)
end

function DragDrop:PickupSlot(slot)
  if not slot:GetConfig() then return end
  if self.heldSlot then
    self.heldSlot.frame:SetAlpha(1.0)
  end
  self.heldSlot = slot
  slot.frame:SetAlpha(0.4)
end

function DragDrop:DropSlotOn(targetSlot)
  local source = self.heldSlot
  self.heldSlot = nil
  if not source or not source.frame then return end
  source.frame:SetAlpha(1.0)
  if source == targetSlot then return end

  local sourceCfg = source:GetConfig()
  local targetCfg = targetSlot:GetConfig()
  source.barWidget.config.slots[source.index] = targetCfg
  targetSlot.barWidget.config.slots[targetSlot.index] = sourceCfg
  source:RefreshDisplay()
  targetSlot:RefreshDisplay()
end

function DragDrop:IsHoldingSlot()
  return self.heldSlot ~= nil
end

local pendingManualSlot = nil

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["DECAY_MANUAL_ENTRY"] = {
  text = L["Aura name to track:"],
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  maxLetters = 64,
  OnShow = function(self) self.editBox:SetFocus() end,
  OnAccept = function(self)
    local name = self.editBox:GetText()
    local slot = pendingManualSlot
    pendingManualSlot = nil
    if not slot or not slot.frame then return end
    if not name or name == "" then return end
    local _, _, icon = GetSpellInfo(name)
    icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    slot:Assign(name, 0, icon)
  end,
  OnCancel = function() pendingManualSlot = nil end,
  EditBoxOnEnterPressed = function(self)
    self:GetParent().button1:Click()
  end,
  EditBoxOnEscapePressed = function(self)
    self:GetParent():Hide()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

function DragDrop:OpenManualEntry(slot)
  pendingManualSlot = slot
  StaticPopup_Show("DECAY_MANUAL_ENTRY")
end
