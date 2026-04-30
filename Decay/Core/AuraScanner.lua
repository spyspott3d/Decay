local Decay = _G.Decay
Decay.AuraScanner = Decay.AuraScanner or {}
local AuraScanner = Decay.AuraScanner

local UnitAura = UnitAura
local UnitExists = UnitExists
local UnitGUID = UnitGUID
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

  for _, bar in ipairs(Decay.db.global.bars) do
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

-- OnUpdate poll replaces UNIT_AURA + PLAYER_TARGET_CHANGED event
-- registration. Running at render time keeps our scan code out of the
-- secure call chain that BindEnchant() validates against, so applying
-- weapon poisons on Ascension is no longer blocked. 100ms latency is
-- well below the visible threshold for a regression bar.
local pollFrame = CreateFrame("Frame", "DecayPollFrame")
pollFrame.elapsed = 0
pollFrame.lastTargetGUID = nil

pollFrame:SetScript("OnUpdate", function(self, elapsed)
  if Decay.runtimeHalted then return end
  self.elapsed = self.elapsed + elapsed
  if self.elapsed < POLL_INTERVAL then return end
  self.elapsed = 0
  if not Decay.db then return end

  AuraScanner:ScanUnit("player")

  local guid = UnitGUID("target")
  if guid ~= self.lastTargetGUID then
    self.lastTargetGUID = guid
  end
  AuraScanner:ScanUnit("target")
end)

AuraScanner.pollFrame = pollFrame
