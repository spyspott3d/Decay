local Decay = _G.Decay
Decay.Heuristics = Decay.Heuristics or {}
Decay.Heuristics.enUS = {
  debuffMarkers = {
    "deals", "damage", "reduces", "stuns", "snares", "decreases",
    "lowers", "drains", "burns", "afflicts", "stunned", "rooted",
    "silenced", "fears", "polymorphs", "incapacitates", "disorients",
    "bleeds", "poisoned", "diseased",
  },
}
