local Decay = LibStub("AceAddon-3.0"):NewAddon("Decay", "AceConsole-3.0")
_G.Decay = Decay

Decay.VERSION = "1.0.0"

local L = LibStub("AceLocale-3.0"):GetLocale("Decay")

function Decay:OnInitialize()
  self.Database:Init()
  self:RegisterChatCommand("decay", "OnSlashCommand")
  self:RegisterChatCommand("dc", "OnSlashCommand")
end

function Decay:OnEnable()
  self.UI.BarManager:RestoreAll()
  self.AuraScanner:StartPolling()
  self.Config.Options:Init()
  self.Events:RegisterAll()
end

function Decay:OnEnterWorld()
  self.State:Reset()
  self.AuraScanner:InitialScan()
  self.UI.BarManager:ApplyVisibilityRules()
end

function Decay:OnUnitAura(_, unit)
  if unit == "player" or unit == "target" then
    self.AuraScanner:ScanUnit(unit)
  end
end

function Decay:OnTargetChanged()
  self.AuraScanner:ScanUnit("target")
end

function Decay:OnEnterCombat()
  self.State.inCombat = true
  self.UI.BarManager:ApplyVisibilityRules()
end

function Decay:OnLeaveCombat()
  self.State.inCombat = false
  self.UI.BarManager:ApplyVisibilityRules()
end

function Decay:OnZoneChanged()
  self.UI.BarManager:ApplyVisibilityRules()
end


function Decay:ResetAll()
  self.db:ResetDB()
  for _, widget in pairs(self.UI.BarManager.bars) do
    widget:Destroy()
  end
  self.UI.BarManager.bars = {}
  self.State:Reset()
  self.UI.BarManager:RestoreAll()
  if self.Config and self.Config.Options and self.Config.Options.Refresh then
    self.Config.Options:Refresh()
  end
end

function Decay:OnSlashCommand(input)
  input = input and input:lower():match("^%s*(.-)%s*$") or ""
  if input == "" then
    self.Config.Options:Toggle()
  elseif input == "lock" then
    self.UI.Lock:Set(false)
  elseif input == "unlock" then
    self.UI.Lock:Set(true)
  elseif input == "reset" then
    self:ResetAll()
    self:Print(L["All settings reset to defaults"])
  elseif input == "logs" then
    self:Print(L["Logs are not yet implemented"])
  elseif input == "debug" then
    self.debugLog = not self.debugLog
    self:Print("debug = " .. tostring(self.debugLog))
  elseif input == "halt" then
    self.runtimeHalted = true
    self.Events:UnregisterAll()
    self.AuraScanner:StopPolling()
    for _, widget in pairs(self.UI.BarManager.bars) do
      for _, slot in ipairs(widget.slots) do
        if slot.frame then slot.frame:SetScript("OnUpdate", nil) end
      end
    end
    self:Print("halted: events + poll unregistered, slot OnUpdates cleared")
  elseif input == "resume" then
    self.runtimeHalted = false
    self.Events:RegisterAll()
    self.AuraScanner:StartPolling()
    self.AuraScanner:RescanAll()
    self:Print("resumed")
  else
    self:Print(L["Unknown command: %s"]:format(input))
  end
end
