local Decay = _G.Decay
Decay.Config = Decay.Config or {}
Decay.Config.Options = Decay.Config.Options or {}
local Options = Decay.Config.Options

local L = LibStub("AceLocale-3.0"):GetLocale("Decay")

local APP = "Decay"

local HORIZONTAL_FADES = { above = true, below = true }
local VERTICAL_FADES = { left = true, right = true }

local function fadeValuesFor(orientation)
  if orientation == "horizontal" then
    return { above = L["Above"], below = L["Below"] }
  end
  return { left = L["Left"], right = L["Right"] }
end

local function defaultFadeFor(orientation)
  return orientation == "horizontal" and "above" or "left"
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
    delete = {
      type = "execute",
      name = L["Delete"],
      order = 99,
      confirm = true,
      confirmText = L["Delete this bar?"],
      func = function()
        Decay.UI.BarManager:DeleteBar(barId)
        Options:Refresh()
      end,
    },
  }
end

local function buildOptionsTable()
  local opts = {
    type = "group",
    name = "Decay",
    args = {
      bars = {
        type = "group",
        name = L["Bars"],
        order = 1,
        args = {
          newBar = {
            type = "execute",
            name = L["New bar"],
            order = 1,
            func = function()
              Decay.UI.BarManager:CreateBar()
              Options:Refresh()
            end,
          },
          unlockToggle = {
            type = "toggle",
            name = L["Unlock bars"],
            order = 2,
            get = function() return Decay.UI.Lock:IsUnlocked() end,
            set = function(_, val) Decay.UI.Lock:Set(val) end,
          },
        },
      },
    },
  }

  for i, bc in ipairs(Decay.db.global.bars) do
    local key = "bar_" .. (bc.id:gsub("-", "_"))
    opts.args.bars.args[key] = {
      type = "group",
      name = bc.name,
      order = 10 + i,
      inline = true,
      args = buildBarArgs(bc),
    }
  end

  return opts
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
