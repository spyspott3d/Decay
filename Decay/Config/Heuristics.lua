local Decay = _G.Decay
Decay.Heuristics = Decay.Heuristics or {}
local Heuristics = Decay.Heuristics

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetLocale = GetLocale

local scanTooltip
local function getScanTooltip()
  if not scanTooltip then
    scanTooltip = CreateFrame("GameTooltip", "DecayHeuristicsTooltip", nil, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:Hide()
  end
  return scanTooltip
end

function Heuristics:ClassifySpell(spellID)
  if not spellID or spellID == 0 then return "buff" end

  local tt = getScanTooltip()
  tt:ClearLines()
  tt:SetOwner(UIParent, "ANCHOR_NONE")
  local ok = pcall(tt.SetHyperlink, tt, "spell:" .. spellID)
  if not ok then return "buff" end

  local locale = GetLocale()
  local data = Heuristics[locale] or Heuristics.enUS
  local markers = data and data.debuffMarkers
  if not markers then return "buff" end

  for i = 1, tt:NumLines() do
    local fs = _G["DecayHeuristicsTooltipTextLeft" .. i]
    local line = fs and fs:GetText()
    if line then
      local lower = line:lower()
      for _, marker in ipairs(markers) do
        if lower:find(marker, 1, true) then
          return "debuff"
        end
      end
    end
  end
  return "buff"
end
