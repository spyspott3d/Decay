local Decay = _G.Decay
Decay.AuraScanner = Decay.AuraScanner or {}
local AuraScanner = Decay.AuraScanner

local UnitAura = UnitAura
local UnitExists = UnitExists
local ipairs = ipairs
local pairs = pairs

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
