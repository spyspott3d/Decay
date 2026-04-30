local Decay = LibStub("AceAddon-3.0"):NewAddon("Decay", "AceEvent-3.0", "AceConsole-3.0")
_G.Decay = Decay

Decay.VERSION = "1.0.0"

function Decay:OnInitialize()
  self.Database:Init()
  self.UI.BarManager:RestoreAll()
  self.Config.Options:Init()

  self:RegisterChatCommand("decay", "OnSlashCommand")
  self:RegisterChatCommand("dc", "OnSlashCommand")
end

function Decay:OnEnable()
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
    self:Print("/decay reset is not implemented yet")
  elseif input == "logs" then
    self:Print("/decay logs is not implemented yet")
  else
    self:Print("Unknown command: " .. input)
  end
end
