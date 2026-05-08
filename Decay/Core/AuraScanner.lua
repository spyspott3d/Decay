local Decay = _G.Decay
Decay.AuraScanner = Decay.AuraScanner or {}
local AuraScanner = Decay.AuraScanner

local UnitAura = UnitAura
local UnitExists = UnitExists
local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs

local POLL_INTERVAL = 0.1

local function slotKey(barId, idx)
  return barId .. ":" .. idx
end

function AuraScanner:ScanUnit(unit)
  local desiredType = (unit == "player") and "buff" or "debuff"
  local filter = (unit == "player") and "HELPFUL" or "HARMFUL"

  local seenAuras = {}
  if UnitExists(unit) then
    for i = 1, 40 do
      local name, _, icon, count, _, duration, expirationTime, unitCaster = UnitAura(unit, i, filter)
      if not name then break end
      if unitCaster == "player" then
        seenAuras[name] = {
          expirationTime = expirationTime,
          duration = duration,
          stackCount = count,
          auraIcon = icon,
        }
      end
    end
  end

  local activeSlots = Decay.State.activeSlots
  local barWidgets = Decay.UI.BarManager.bars

  for _, bar in ipairs(Decay.db.profile.bars) do
    local slots = bar.slots
    if slots then
      for slotIdx, slotCfg in pairs(slots) do
        if slotCfg.auraType == desiredType then
          local key = slotKey(bar.id, slotIdx)
          local newData = seenAuras[slotCfg.auraName]
          local oldData = activeSlots[key]
          local widget = barWidgets[bar.id]
          local slot = widget and widget.slots[slotIdx]
          if newData then
            activeSlots[key] = newData
            if slot then
              if oldData then
                slot:RefreshActiveDisplay()
              else
                slot:Activate()
              end
            end
          elseif oldData then
            activeSlots[key] = nil
            if slot then slot:Deactivate() end
          end
        end
      end
    end
  end
end

function AuraScanner:InitialScan()
  self:ScanUnit("player")
  self:ScanUnit("target")
end

function AuraScanner:RescanAll()
  self:ScanUnit("player")
  self:ScanUnit("target")
end

-- All event-based reactions have been replaced by polling here. Decay
-- registers no game events at all on the Ascension client because the
-- BindEnchant() secure validator flagged us as tainted as long as any
-- event was registered, even events that never fire during a weapon
-- enchant cast. OnUpdate runs at render time after the secure chain
-- has closed, so it cannot poison BindEnchant.

local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local SLOW_POLL_INTERVAL = 1.0

local pollFrame
local pollScript = function(self, elapsed)
  if Decay.runtimeHalted then return end
  if not Decay.db then return end

  if not self.initialScanDone then
    self.initialScanDone = true
    if Decay.UI and Decay.UI.BarManager then
      Decay.UI.BarManager:ApplyVisibilityRules()
    end
  end

  self.fastElapsed = self.fastElapsed + elapsed
  if self.fastElapsed >= POLL_INTERVAL then
    self.fastElapsed = 0
    AuraScanner:ScanUnit("player")
    AuraScanner:ScanUnit("target")
  end

  self.slowElapsed = self.slowElapsed + elapsed
  if self.slowElapsed >= SLOW_POLL_INTERVAL then
    self.slowElapsed = 0
    local inCombat = InCombatLockdown()
    local inInstance = IsInInstance()
    if inCombat ~= self.lastInCombat or inInstance ~= self.lastInInstance then
      self.lastInCombat = inCombat
      self.lastInInstance = inInstance
      Decay.State.inCombat = inCombat
      if Decay.UI and Decay.UI.BarManager then
        Decay.UI.BarManager:ApplyVisibilityRules()
      end
    end
  end
end

function AuraScanner:StartPolling()
  if pollFrame then return end
  pollFrame = CreateFrame("Frame", "DecayPollFrame")
  pollFrame.fastElapsed = 0
  pollFrame.slowElapsed = 0
  pollFrame.initialScanDone = false
  pollFrame:SetScript("OnUpdate", pollScript)
  AuraScanner.pollFrame = pollFrame
end

function AuraScanner:StopPolling()
  if pollFrame then
    pollFrame:SetScript("OnUpdate", nil)
  end
end
