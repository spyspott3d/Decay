local Decay = _G.Decay
Decay.Config = Decay.Config or {}
Decay.Config.Options = Decay.Config.Options or {}
local Options = Decay.Config.Options

local L = LibStub("AceLocale-3.0"):GetLocale("Decay")

local APP = "Decay"

local HORIZONTAL_FADES = { above = true, below = true }
local VERTICAL_FADES = { left = true, right = true }

local TEXTURE_VALUES = {
  ["Interface\\TargetingFrame\\UI-StatusBar"] = L["Default texture"],
  ["Interface\\Buttons\\WHITE8X8"] = L["Solid"],
}

local TIMER_FORMATS = {
  auto = L["Auto"],
  seconds = L["Seconds only"],
  ["mm:ss"] = L["MM:SS"],
}

local function fadeValuesFor(orientation)
  if orientation == "horizontal" then
    return { above = L["Above"], below = L["Below"] }
  end
  return { left = L["Left"], right = L["Right"] }
end

local function defaultFadeFor(orientation)
  return orientation == "horizontal" and "above" or "left"
end

local function colorGet(key)
  local c = Decay.db.global.settings.colors[key]
  return c[1], c[2], c[3], c[4]
end

local function colorSet(key, r, g, b, a)
  Decay.db.global.settings.colors[key] = { r, g, b, a }
end

local function visualGetter(bc, key)
  return function()
    local v = bc.visual and bc.visual[key]
    if v == nil then return Decay.db.global.settings.defaults[key] end
    return v
  end
end

local function visualSetter(bc, key)
  return function(_, val)
    bc.visual = bc.visual or {}
    bc.visual[key] = val
    Decay.UI.BarManager:UpdateBar(bc.id)
  end
end

local function buildBarArgs(bc)
  local barId = bc.id
  return {
    name = {
      type = "input",
      name = L["Name"],
      order = 1,
      width = "double",
      get = function() return bc.name end,
      set = function(_, val)
        if val and val ~= "" then
          bc.name = val
          Options:Refresh()
        end
      end,
    },
    orientation = {
      type = "select",
      name = L["Orientation"],
      order = 2,
      values = function()
        return { horizontal = L["Horizontal"], vertical = L["Vertical"] }
      end,
      get = function() return bc.orientation end,
      set = function(_, val)
        bc.orientation = val
        local validFades = val == "horizontal" and HORIZONTAL_FADES or VERTICAL_FADES
        if not validFades[bc.fadeDirection] then
          bc.fadeDirection = defaultFadeFor(val)
        end
        Decay.UI.BarManager:UpdateBar(barId)
        Options:Refresh()
      end,
    },
    fadeDirection = {
      type = "select",
      name = L["Fade direction"],
      order = 3,
      values = function() return fadeValuesFor(bc.orientation) end,
      get = function() return bc.fadeDirection end,
      set = function(_, val)
        bc.fadeDirection = val
        Decay.UI.BarManager:UpdateBar(barId)
      end,
    },
    slotCount = {
      type = "range",
      name = L["Slot count"],
      order = 4,
      min = 1, max = 12, step = 1,
      get = function() return bc.slotCount end,
      set = function(_, val)
        bc.slotCount = val
        Decay.UI.BarManager:UpdateBar(barId)
      end,
    },
    sortMode = {
      type = "select",
      name = L["Sort mode"],
      desc = L["FIXED_DESC"],
      order = 5,
      values = function()
        return { fixed = L["Fixed"], byRemaining = L["By remaining time"] }
      end,
      get = function() return bc.sortMode or "fixed" end,
      set = function(_, val)
        bc.sortMode = val
        Decay.UI.BarManager:UpdateBar(barId)
      end,
    },
    visualHeader = { type = "header", name = L["Visual"], order = 10 },
    iconSize = {
      type = "range", name = L["Icon size"], order = 11,
      min = 16, max = 64, step = 1,
      get = visualGetter(bc, "iconSize"),
      set = visualSetter(bc, "iconSize"),
    },
    barLength = {
      type = "range", name = L["Bar length"], order = 12,
      min = 40, max = 200, step = 1,
      get = visualGetter(bc, "barLength"),
      set = visualSetter(bc, "barLength"),
    },
    barThickness = {
      type = "range", name = L["Bar thickness"], order = 13,
      min = 16, max = 64, step = 1,
      get = visualGetter(bc, "barThickness"),
      set = visualSetter(bc, "barThickness"),
    },
    spacing = {
      type = "range", name = L["Spacing"], order = 14,
      min = 0, max = 20, step = 1,
      get = visualGetter(bc, "spacing"),
      set = visualSetter(bc, "spacing"),
    },
    texture = {
      type = "select", name = L["Texture"], order = 15,
      values = function() return TEXTURE_VALUES end,
      get = visualGetter(bc, "texture"),
      set = visualSetter(bc, "texture"),
    },
    timerHeader = { type = "header", name = L["Timer"], order = 20 },
    showTimerText = {
      type = "toggle", name = L["Show timer text"], order = 21,
      get = visualGetter(bc, "showTimerText"),
      set = visualSetter(bc, "showTimerText"),
    },
    timerTextSize = {
      type = "range", name = L["Timer text size"], order = 22,
      min = 8, max = 24, step = 1,
      get = visualGetter(bc, "timerTextSize"),
      set = visualSetter(bc, "timerTextSize"),
    },
    timerTextFormat = {
      type = "select", name = L["Timer text format"], order = 23,
      desc = L["TIMER_FORMAT_DESC"],
      values = function() return TIMER_FORMATS end,
      get = visualGetter(bc, "timerTextFormat"),
      set = visualSetter(bc, "timerTextFormat"),
    },
    visibilityHeader = { type = "header", name = L["Visibility rules"], order = 30 },
    combatOnly = {
      type = "toggle", name = L["Combat only"], order = 31,
      desc = L["Hide bars when out of combat"],
      get = function() return bc.visibility.combatOnly end,
      set = function(_, val)
        bc.visibility.combatOnly = val
        local widget = Decay.UI.BarManager.bars[bc.id]
        if widget then widget:ApplyVisibilityRules() end
      end,
    },
    inInstanceOnly = {
      type = "toggle", name = L["In instance only"], order = 32,
      desc = L["Hide bars when not in a dungeon or raid"],
      get = function() return bc.visibility.inInstanceOnly end,
      set = function(_, val)
        bc.visibility.inInstanceOnly = val
        local widget = Decay.UI.BarManager.bars[bc.id]
        if widget then widget:ApplyVisibilityRules() end
      end,
    },
    actionsHeader = { type = "header", name = "", order = 90 },
    resetPosition = {
      type = "execute", name = L["Reset position"], order = 91,
      func = function()
        local widget = Decay.UI.BarManager.bars[barId]
        if widget then widget:ResetPosition() end
      end,
    },
    duplicate = {
      type = "execute", name = L["Duplicate"], order = 92,
      func = function()
        Decay.UI.BarManager:DuplicateBar(barId)
        Options:Refresh()
      end,
    },
    delete = {
      type = "execute", name = L["Delete"], order = 99,
      confirm = true, confirmText = L["Delete this bar?"],
      func = function()
        Decay.UI.BarManager:DeleteBar(barId)
        Options:Refresh()
      end,
    },
  }
end

local function buildBarsTabArgs()
  local args = {
    newBar = {
      type = "execute", name = L["New bar"], order = 1,
      func = function()
        Decay.UI.BarManager:CreateBar()
        Options:Refresh()
      end,
    },
  }
  for i, bc in ipairs(Decay.db.global.bars) do
    local key = "bar_" .. (bc.id:gsub("-", "_"))
    args[key] = {
      type = "group", name = bc.name, order = 10 + i, inline = true,
      args = buildBarArgs(bc),
    }
  end
  return args
end

local function buildDisplayTabArgs()
  return {
    thresholdsHeader = { type = "header", name = L["Thresholds"], order = 1 },
    yellowThreshold = {
      type = "range", name = L["Upper threshold"], order = 2,
      desc = L["Above this remaining-time percentage, the bar uses the high color."],
      min = 0.05, max = 0.95, step = 0.01, isPercent = true,
      get = function() return Decay.db.global.settings.thresholds.yellow end,
      set = function(_, val)
        local red = Decay.db.global.settings.thresholds.red
        if val <= red then val = red + 0.05 end
        if val > 0.95 then val = 0.95 end
        Decay.db.global.settings.thresholds.yellow = val
      end,
    },
    redThreshold = {
      type = "range", name = L["Lower threshold"], order = 3,
      desc = L["Below this remaining-time percentage, the bar uses the low color."],
      min = 0.01, max = 0.9, step = 0.01, isPercent = true,
      get = function() return Decay.db.global.settings.thresholds.red end,
      set = function(_, val)
        local yellow = Decay.db.global.settings.thresholds.yellow
        if val >= yellow then val = yellow - 0.05 end
        if val < 0.01 then val = 0.01 end
        Decay.db.global.settings.thresholds.red = val
      end,
    },
    colorsHeader = { type = "header", name = L["Colors"], order = 10 },
    greenColor = {
      type = "color", name = L["High color"], order = 11, hasAlpha = true,
      get = function() return colorGet("green") end,
      set = function(_, r, g, b, a) colorSet("green", r, g, b, a) end,
    },
    yellowColor = {
      type = "color", name = L["Mid color"], order = 12, hasAlpha = true,
      get = function() return colorGet("yellow") end,
      set = function(_, r, g, b, a) colorSet("yellow", r, g, b, a) end,
    },
    redColor = {
      type = "color", name = L["Low color"], order = 13, hasAlpha = true,
      get = function() return colorGet("red") end,
      set = function(_, r, g, b, a) colorSet("red", r, g, b, a) end,
    },
  }
end

local function buildGeneralTabArgs()
  return {
    unlockToggle = {
      type = "toggle", name = L["Unlock bars"], order = 1,
      get = function() return Decay.UI.Lock:IsUnlocked() end,
      set = function(_, val) Decay.UI.Lock:Set(val) end,
    },
    resetHeader = { type = "header", name = "", order = 90 },
    reset = {
      type = "execute", name = L["Reset to defaults"], order = 91,
      confirm = true, confirmText = L["Reset all bars and settings to defaults?"],
      func = function() Decay:ResetAll() end,
    },
  }
end

local function buildOptionsTable()
  return {
    type = "group", name = "Decay", childGroups = "tab",
    args = {
      bars = { type = "group", name = L["Bars"], order = 1, args = buildBarsTabArgs() },
      display = { type = "group", name = L["Display"], order = 2, args = buildDisplayTabArgs() },
      general = { type = "group", name = L["General"], order = 3, args = buildGeneralTabArgs() },
    },
  }
end

function Options:Init()
  LibStub("AceConfig-3.0"):RegisterOptionsTable(APP, buildOptionsTable)
  self.dialog = LibStub("AceConfigDialog-3.0")
end

function Options:Open()
  self.dialog:Open(APP)
end

function Options:Close()
  self.dialog:Close(APP)
end

function Options:Toggle()
  if self.dialog.OpenFrames[APP] then
    self:Close()
  else
    self:Open()
  end
end

function Options:Refresh()
  LibStub("AceConfigRegistry-3.0"):NotifyChange(APP)
end
