# Next Steps — NoMercy 3D

_Last assessed: 2026-04-12_

---

## Completed

| Sprint | Task | Notes |
|--------|------|-------|
| 1 | Fix `lengthXZTo` sqrt bug | Was returning squared distance; broke all AI range checks |
| 1 | Write `BotAI3D` — 4 personality presets | aggressor, flanker, ranged, coward; stuck-detection + height-jump |
| 1 | Wire `EnemyCharacter3D` to `BotAI3D` | Via abstract `BotController3D`; personality passed through spawn chain |
| 1 | `_pickPersonality` in world system | Wave-scaled: aggressors early, full mix by wave 8 |
| 3 | Projectile gravity + platform/obstacle collision | Arc lob with ballistic aim compensation; despawn on ground/platform/obstacle hit |
| Arch | Extract all AI into `ai` module | `engine` keeps thin abstract layer only (see below) |

### AI module architecture

```
nomercy (app)
  ├── ai    → engine → core
  └── engine → core
```

**`modules/ai/`**
- `src/bot/` — `BotAI3D`, `SmartBotAI`, `IntelligentBotAI`, `BotDecision`, `BotState`
- `src/tactic/` — `AggressiveTactic`, `BalancedTactic`, `DefensiveTactic`, `TacticalTactic`, `BerserkerTactic`, `SniperTactic`, `CowardTactic`
- `src/ai_tactic_registry.dart` — full map-based tactic registry (personality + class name lookups)
- `src/ai_module.dart` — `AiModule.register()` wires everything at app startup

**`modules/engine/` (abstract layer only)**
- `BotTactic` abstract + `isUnupgradable` hook
- `BotController3D` abstract
- `BotPersonality3D` enum
- `AiBotRegistry` — single `BotController3D Function(BotPersonality3D)` callback
- `AiTacticProvider` — single `BotTactic? Function(String)` callback

---

## Feature roadmap (priority order)

### Sprint 2 — Feedback & feel
- [ ] **In-game HUD overlay** — wave number, enemy count, score/distance, combo counter. All data exists in state, nothing is shown. (`GameScreen3D` has only a pause button.)
- [ ] **Damage numbers** — floating text on hit. `RewardText` in 2D side is the reference pattern.
- [ ] **Dodge i-frames** — dodge is implemented but grants zero invulnerability. Players learn it's useless immediately.

### Sprint 3 — Combat depth (partial)
- [x] Projectile gravity + platform collision ✅
- [ ] **Sound effects** — `AudioSystem` is wired. Minimum viable: attack swoosh, hit impact, jump, land.
- [ ] **Combo payoff** — `comboCount` tracked in `GameCharacterState`, never consumed. Wire to: damage bonus OR stamina refund OR score multiplier.

### Sprint 4 — Progression
- [ ] **Boss wave at chunk milestones** — `InfiniteWorldSystem3D` wave-spawn hook exists. Every ~10 chunks: 1 boss-tier enemy (3× HP, 2× size, mixed melee+ranged).
- [ ] **Score / distance persistence** — `GameOverEvent` carries all data. Local leaderboard gives replay reason.

---

## System completeness snapshot

| System | State |
|--------|-------|
| 3D physics / collision | ✅ Complete |
| Camera + projection | ✅ Complete |
| Player movement + input | ✅ Complete |
| Character movement strategies (4) | ✅ Complete |
| Infinite world / chunk gen | ✅ Working |
| Obstacle framework | ✅ Working |
| Projectile hit detection | ✅ Fixed |
| Projectile gravity + env collision | ✅ Fixed |
| Enemy AI (4 personalities) | ✅ Complete |
| AI module separation | ✅ Complete |
| HUD | ⚠️ Buttons only |
| Audio | ⚠️ Music only, zero SFX |
| Combo system | ⚠️ Tracked, never rewarded |
| Dodge i-frames | ❌ Missing |
| Damage numbers | ❌ Missing |
| Score / persistence | ❌ Missing |
| Boss system | ❌ Missing |
