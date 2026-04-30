local Decay = LibStub("AceAddon-3.0"):NewAddon("Decay", "AceEvent-3.0", "AceConsole-3.0")
_G.Decay = Decay

Decay.VERSION = "1.0.0"

local L = LibStub("AceLocale-3.0"):GetLocale("Decay")

function Decay:OnInitialize()
  self.Database:Init()
  self.UI.BarManager:RestoreAll()
  self.Config.Options:Init()

  self:RegisterChatCommand("decay", "OnSlashCommand")
  self:RegisterChatCommand("dc", "OnSlashCommand")
end

function Decay:OnEnable()
  self.Events:RegisterAll()
end

function Decay:OnEnterWorld()
  self.State:Reset()
  self.AuraScanner:InitialScan()
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
end

function Decay:OnLeaveCombat()
  self.State.inCombat = false
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
    self:Print(L["Reset is not yet implemented"])
  elseif input == "logs" then
    self:Print(L["Logs are not yet implemented"])
  else
    self:Print(L["Unknown command: %s"]:format(input))
  end
end
