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

local WATCH_WINDOW = 1.5

local function captureSnapshots()
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

local function processPendingMatchesForUnit(unit, seenNames)
  local pending = Decay.State and Decay.State.pendingMatch
  if not pending then return end
  local now = GetTime()
  for _, pm in pairs(pending) do
    if now - pm.startTime <= WATCH_WINDOW then
      local snapshot = pm.castSnapshots and pm.castSnapshots[unit]
      if snapshot then
        for name in pairs(seenNames) do
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

local function setSlotWarning(key, warning)
  local _, idx, slotCfg = findSlotConfig(key)
  if not slotCfg then return end
  slotCfg.warning = warning
  local barId = key:match("^(.-):%d+$")
  local widget = Decay.UI.BarManager.bars[barId]
  local slot = widget and widget.slots[idx]
  if slot and slot.RefreshDisplay then slot:RefreshDisplay() end
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
local castFrame

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
            if not snapshots then snapshots = captureSnapshots() end
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

function AuraScanner:StartCastListener()
  if castFrame then return end
  castFrame = CreateFrame("Frame", "DecayCastListener")
  castFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  castFrame:SetScript("OnEvent", function(_, _, unit, spellName)
    if Decay.runtimeHalted then return end
    if unit ~= "player" or not spellName then return end
    castQueue[#castQueue + 1] = { spellName = spellName, time = GetTime() }
  end)
end

function AuraScanner:StopCastListener()
  if castFrame then castFrame:UnregisterAllEvents() end
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

  if #castQueue > 0 then drainCastQueue() end
  if Decay.State and Decay.State.pendingMatch and next(Decay.State.pendingMatch) then
    AuraScanner:CheckPendingMatches()
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
