# Next Steps — NoMercy 3D

_Last assessed: 2026-04-12_

---

## Bugs to fix first

| # | File | Issue |
|---|------|-------|
| 1 | `player_character_3d.dart` | `lengthXZTo` returns squared distance — missing `sqrt`. Breaks enemy chase/attack range. |
| 2 | `smart_bot_ai.dart` / `intelligent_bot_ai.dart` | Designed for 2D `Vector2`/`GameCharacter`. Fully incompatible with 3D. Dead weight. |

---

## Feature roadmap (priority order)

### Sprint 1 — Make it a game
- [ ] **Fix `lengthXZTo`** — unblocks all AI range checks
- [ ] **Write `BotAI3D`** — 3–4 personality presets (aggressor, flanker, ranged, coward). Current enemy only chases straight. Biggest gap between tech demo and game.

### Sprint 2 — Feedback & feel
- [ ] **In-game HUD overlay** — wave number, enemy count, score/distance, combo counter. All data exists in state, nothing is shown. (`GameScreen3D` has only a pause button.)
- [ ] **Damage numbers** — floating text on hit. `RewardText` in 2D side is the reference pattern.
- [ ] **Dodge i-frames** — dodge is implemented but grants zero invulnerability. Players learn it's useless immediately.

### Sprint 3 — Combat depth
- [ ] **Projectile gravity + platform collision** — flat infinite travel makes ranged unreadable. Small downward arc + despawn on platform contact.
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
| Enemy AI | ⚠️ Hardcoded chase only |
| HUD | ⚠️ Buttons only |
| Projectile physics | ⚠️ No gravity, no platform collision |
| Audio | ⚠️ Music only, zero SFX |
| Combo system | ⚠️ Tracked, never rewarded |
| Dodge i-frames | ❌ Missing |
| Damage numbers | ❌ Missing |
| Score / persistence | ❌ Missing |
| Boss system | ❌ Missing |
| SmartBotAI (3D) | ❌ Broken / incompatible |
