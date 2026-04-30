local Decay = _G.Decay
Decay.Events = Decay.Events or {}
local Events = Decay.Events

-- Decay no longer registers any game events. All state tracking happens
-- via AuraScanner.lua's pollFrame OnUpdate. The aggressive Ascension
-- secure check that taints BindEnchant() flagged us as long as ANY
-- event was registered, even events that never fire during a weapon
-- enchant cast. The polling approach side-steps the entire event path.

function Events:RegisterAll() end
function Events:UnregisterAll() end
