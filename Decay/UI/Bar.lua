local Decay = _G.Decay
Decay.UI = Decay.UI or {}
Decay.UI.Bar = Decay.UI.Bar or {}
local Bar = Decay.UI.Bar

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetTime = GetTime
local IsInInstance = IsInInstance
local max = math.max
local huge = math.huge
local sort = table.sort
local ipairs = ipairs

local FRAME_PREFIX = "DecayBarFrame"
local frameCounter = 0
local HANDLE_SIZE = 12

local methods = {}
methods.__index = methods

function methods:GetVisual(key)
  local v = self.config.visual and self.config.visual[key]
  if v ~= nil then return v end
  return Decay.db.global.settings.defaults[key]
end

function methods:ApplyPosition()
  local pos = self.config.position
  self.frame:ClearAllPoints()
  self.frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

function methods:ResetPosition()
  self.config.position.point = "CENTER"
  self.config.position.relativePoint = "CENTER"
  self.config.position.x = 0
  self.config.position.y = -100
  self:ApplyPosition()
end

function methods:HiddenByRules()
  local rules = self.config.visibility
  if not rules then return false end
  if rules.combatOnly and not Decay.State.inCombat then return true end
  if rules.inInstanceOnly then
    local inInstance = IsInInstance()
    if not inInstance then return true end
  end
  return false
end

function methods:ApplyLockState(unlocked)
  self.frame:EnableMouse(unlocked)
  for _, slot in ipairs(self.slots) do
    slot:ApplyLockState(unlocked)
  end
  self.handle:SetShown(unlocked)
  if unlocked then
    self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.frame:SetFrameLevel(200)
  else
    self.frame:SetFrameStrata("MEDIUM")
    self.frame:SetFrameLevel(0)
  end
  if not unlocked and self:HiddenByRules() then
    self.frame:Hide()
  else
    self.frame:Show()
  end
  self:RelayoutIfDynamic()
end

function methods:ApplyVisibilityRules()
  local unlocked = Decay.db.global.state.unlocked
  if not unlocked and self:HiddenByRules() then
    self.frame:Hide()
  else
    self.frame:Show()
  end
end

function methods:CreateSlots()
  local target = self.config.slotCount
  for i = #self.slots + 1, target do
    self.slots[i] = Decay.UI.Slot.New(self, i)
  end
  for i = #self.slots, target + 1, -1 do
    self.slots[i]:Destroy()
    self.slots[i] = nil
  end
end

function methods:GetActiveSlotsSorted()
  local config = self.config
  local activeSlots = Decay.State.activeSlots
  local barId = config.id
  local now = GetTime()

  local order = {}
  for i = 1, config.slotCount do
    local key = barId .. ":" .. i
    if activeSlots[key] then
      order[#order + 1] = i
    end
  end

  sort(order, function(a, b)
    local da = activeSlots[barId..":"..a]
    local db = activeSlots[barId..":"..b]
    local ra = (da.duration == 0) and huge or (da.expirationTime - now)
    local rb = (db.duration == 0) and huge or (db.expirationTime - now)
    return ra > rb
  end)

  return order
end

function methods:LayoutSlots()
  local config = self.config
  local orientation = config.orientation
  local fadeDir = config.fadeDirection
  local horizontal = orientation == "horizontal"
  local iconSize = self:GetVisual("iconSize")
  local barLength = self:GetVisual("barLength")
  local barThickness = self:GetVisual("barThickness")
  local spacing = self:GetVisual("spacing")
  local stride = max(iconSize, barThickness) + spacing

  local locked = not Decay.db.global.state.unlocked
  local order
  if config.sortMode == "byRemaining" and locked then
    order = self:GetActiveSlotsSorted()
  else
    order = {}
    for i = 1, config.slotCount do order[i] = i end
  end

  for displayIdx, slotIdx in ipairs(order) do
    local slot = self.slots[slotIdx]
    if slot then
      slot:Layout(orientation, fadeDir, iconSize, barLength, barThickness)
      slot:ApplyTimerSettings(self:GetVisual("showTimerText"),
        self:GetVisual("timerTextSize"), self:GetVisual("timerTextFormat"))
      slot:ApplyTexture(self:GetVisual("texture"))
      slot.frame:ClearAllPoints()
      if horizontal then
        slot.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (displayIdx - 1) * stride, 0)
      else
        slot.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -(displayIdx - 1) * stride)
      end
    end
  end
end

function methods:Resize()
  local count = self.config.slotCount
  local iconSize = self:GetVisual("iconSize")
  local barLength = self:GetVisual("barLength")
  local barThickness = self:GetVisual("barThickness")
  local spacing = self:GetVisual("spacing")
  if self.config.orientation == "horizontal" then
    local slotW = max(iconSize, barThickness)
    local slotH = iconSize + barLength
    self.frame:SetSize(count * slotW + (count - 1) * spacing, slotH)
  else
    local slotW = iconSize + barLength
    local slotH = max(iconSize, barThickness)
    self.frame:SetSize(slotW, count * slotH + (count - 1) * spacing)
  end
end

function methods:UpdateLayout()
  self:CreateSlots()
  self:LayoutSlots()
  self:Resize()
  local unlocked = Decay.db.global.state.unlocked
  local activeSlots = Decay.State and Decay.State.activeSlots
  for i = 1, self.config.slotCount do
    local slot = self.slots[i]
    slot:ApplyLockState(unlocked)
    if activeSlots and activeSlots[slot:Key()] then
      slot:RefreshActiveDisplay()
    else
      slot:RefreshDisplay()
    end
  end
end

function methods:RelayoutIfDynamic()
  if self.config.sortMode == "byRemaining" then
    self:LayoutSlots()
  end
end

function methods:Destroy()
  for i = 1, #self.slots do
    self.slots[i]:Destroy()
  end
  self.slots = {}
  self.frame:Hide()
  self.frame:EnableMouse(false)
  self.frame:SetScript("OnDragStart", nil)
  self.frame:SetScript("OnDragStop", nil)
  self.frame:SetParent(nil)
  self.frame = nil
  self.handle = nil
end

local function applyDefaults(barConfig)
  barConfig.orientation = barConfig.orientation or "horizontal"
  barConfig.fadeDirection = barConfig.fadeDirection or "above"
  barConfig.slotCount = barConfig.slotCount or 4
  barConfig.slots = barConfig.slots or {}
  barConfig.sortMode = barConfig.sortMode or "fixed"
  barConfig.visual = barConfig.visual or {}
  if not barConfig.visibility then
    barConfig.visibility = {
      combatOnly = false,
      inInstanceOnly = false,
      targetRequired = true,
    }
  end
end

local function savePosition(frame, barConfig)
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  barConfig.position.point = point
  barConfig.position.relativeTo = "UIParent"
  barConfig.position.relativePoint = relativePoint
  barConfig.position.x = x
  barConfig.position.y = y
end

local function createDragHandle(parent, barConfig)
  local handle = CreateFrame("Frame", nil, parent)
  handle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
  handle:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", -2, 2)

  local tex = handle:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints()
  tex:SetTexture("Interface\\Buttons\\WHITE8X8")
  tex:SetVertexColor(1, 0.82, 0, 0.85)

  handle:EnableMouse(true)
  handle:SetMovable(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", function() parent:StartMoving() end)
  handle:SetScript("OnDragStop", function()
    parent:StopMovingOrSizing()
    savePosition(parent, barConfig)
  end)
  handle:Hide()
  return handle
end

function Bar.New(barConfig)
  applyDefaults(barConfig)

  frameCounter = frameCounter + 1
  local frame = CreateFrame("Frame", FRAME_PREFIX..frameCounter, UIParent)

  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if Decay.db.global.state.unlocked then
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition(self, barConfig)
  end)

  local handle = createDragHandle(frame, barConfig)

  local widget = setmetatable({
    frame = frame,
    handle = handle,
    config = barConfig,
    slots = {},
  }, methods)

  widget:UpdateLayout()
  widget:ApplyPosition()
  widget:ApplyLockState(Decay.db.global.state.unlocked)
  return widget
end
