local Decay = _G.Decay
Decay.AuraScanner = Decay.AuraScanner or {}
local AuraScanner = Decay.AuraScanner

local UnitAura = UnitAura
local UnitExists = UnitExists
local CreateFrame = CreateFrame
local GetTime = GetTime
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber

local WATCH_WINDOW = 1.5
local WATCH_TICK = 0.25

local function slotKey(barId, idx)
  return barId .. ":" .. idx
end

local function findSlotConfig(key)
  local barId, idxStr = key:match("^(.-):(%d+)$")
  local idx = tonumber(idxStr)
  if not barId or not idx then return nil, nil, nil end
  for _, bar in ipairs(Decay.db.global.bars) do
    if bar.id == barId then
      local slotCfg = bar.slots and bar.slots[idx]
      return bar, idx, slotCfg
    end
  end
  return nil, nil, nil
end

function AuraScanner:CaptureSnapshots()
  local snapshots = {}
  for _, unit in ipairs({ "player", "target" }) do
    local filter = (unit == "player") and "HELPFUL" or "HARMFUL"
    local set = {}
    if UnitExists(unit) then
      for i = 1, 40 do
        local name, _, _, _, _, _, _, unitCaster = UnitAura(unit, i, filter)
        if not name then break end
        if unitCaster == "player" then set[name] = true end
      end
    end
    snapshots[unit] = set
  end
  return snapshots
end

local function processPendingMatchesForUnit(unit, seenAuras)
  local pending = Decay.State.pendingMatch
  if not pending then return end
  local now = GetTime()
  for key, pm in pairs(pending) do
    if now - pm.startTime <= WATCH_WINDOW then
      local snapshot = pm.castSnapshots and pm.castSnapshots[unit]
      if snapshot then
        for name in pairs(seenAuras) do
          if not snapshot[name] then
            if name == pm.expectedAuraName then
              local expectedUnit = (pm.auraType == "buff") and "player" or "target"
              if unit == expectedUnit then
                pm.matched = true
              else
                pm.typeMismatch = { observedUnit = unit, observedName = name }
              end
            else
              pm.observedNew = pm.observedNew or {}
              if not pm.observedNew[name] then
                pm.observedNew[name] = unit
              end
            end
          end
        end
      end
    end
  end
end

function AuraScanner:ScanUnit(unit)
  local desiredType = (unit == "player") and "buff" or "debuff"
  local filter = (unit == "player") and "HELPFUL" or "HARMFUL"

  local seenAuras = {}
  local seenNames = {}
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
        seenNames[name] = true
      end
    end
  end

  processPendingMatchesForUnit(unit, seenNames)

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

local function setSlotWarning(key, warning)
  local _, idx, slotCfg = findSlotConfig(key)
  if not slotCfg then return end
  slotCfg.warning = warning
  local barId = key:match("^(.-):%d+$")
  local widget = Decay.UI.BarManager.bars[barId]
  local slot = widget and widget.slots[idx]
  if slot then slot:RefreshDisplay() end
end

function AuraScanner:CheckPendingMatches()
  local pending = Decay.State.pendingMatch
  if not pending then return end
  local now = GetTime()
  for key, pm in pairs(pending) do
    if now - pm.startTime >= WATCH_WINDOW then
      pending[key] = nil
      if not pm.matched then
        if pm.typeMismatch then
          setSlotWarning(key, {
            type = "type",
            observedName = pm.typeMismatch.observedName,
            observedUnit = pm.typeMismatch.observedUnit,
          })
        elseif pm.observedNew then
          local name, observedUnit = next(pm.observedNew)
          if name then
            setSlotWarning(key, {
              type = "name",
              observedName = name,
              observedUnit = observedUnit,
            })
          end
        end
      end
    end
  end
end

local castQueue = {}

function AuraScanner:QueuePlayerCast(spellName, timestamp)
  castQueue[#castQueue + 1] = { spellName = spellName, time = timestamp }
end

local function drainCastQueue()
  if #castQueue == 0 then return end
  local items = castQueue
  castQueue = {}
  local snapshots
  for _, cast in ipairs(items) do
    for _, bar in ipairs(Decay.db.global.bars) do
      if bar.slots then
        for slotIdx, slotCfg in pairs(bar.slots) do
          if slotCfg.spellName == cast.spellName then
            if not snapshots then snapshots = AuraScanner:CaptureSnapshots() end
            local key = slotKey(bar.id, slotIdx)
            Decay.State.pendingMatch[key] = {
              startTime = cast.time,
              expectedAuraName = slotCfg.auraName,
              auraType = slotCfg.auraType,
              spellName = cast.spellName,
              castSnapshots = snapshots,
              observedNew = {},
            }
          end
        end
      end
    end
  end
end

local watchFrame = CreateFrame("Frame")
watchFrame.elapsed = 0
watchFrame:SetScript("OnUpdate", function(self, elapsed)
  if #castQueue > 0 then drainCastQueue() end
  self.elapsed = self.elapsed + elapsed
  if self.elapsed < WATCH_TICK then return end
  self.elapsed = 0
  if Decay.State and Decay.State.pendingMatch and next(Decay.State.pendingMatch) then
    AuraScanner:CheckPendingMatches()
  end
end)
