enum BotState {
  idle,
  approach,
  retreat,
  strafe,
  attack,
  defend,
  evade,
  reposition
}

enum BotPersonality {
  aggressive,   // High risk, high reward
  defensive,    // Cautious, prioritizes survival
  balanced,     // Mix of offense and defense
  tactical,     // Smart positioning, combos
  berserker,    // All-in attacks, no defense
}