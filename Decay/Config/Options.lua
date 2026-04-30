local Decay = _G.Decay
Decay.Config = Decay.Config or {}
Decay.Config.Options = Decay.Config.Options or {}
local Options = Decay.Config.Options

local APP = "Decay"

local function buildOptionsTable()
  local opts = {
    type = "group",
    name = "Decay",
    args = {
      bars = {
        type = "group",
        name = "Bars",
        order = 1,
        args = {
          newBar = {
            type = "execute",
            name = "New bar",
            order = 1,
            func = function()
              Decay.UI.BarManager:CreateBar()
              Options:Refresh()
            end,
          },
          unlockToggle = {
            type = "toggle",
            name = "Unlock bars",
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
    local barId = bc.id
    opts.args.bars.args[key] = {
      type = "group",
      name = bc.name,
      order = 10 + i,
      inline = true,
      args = {
        delete = {
          type = "execute",
          name = "Delete",
          confirm = true,
          confirmText = "Delete this bar?",
          func = function()
            Decay.UI.BarManager:DeleteBar(barId)
            Options:Refresh()
          end,
        },
      },
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
