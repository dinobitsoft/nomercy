# NoMercy: Flutter/Flame → Godot 4.7 Migration Design

**Date:** 2026-08-26
**Status:** Approved design, pending implementation plan
**Scope:** Full engine migration of the NoMercy 2D action platformer

---

## 1. Context

### Current state

22,220 LOC of Dart across 163 files, in five local path-packages plus a thin root app:

| Package | LOC | Contents |
|---|---:|---|
| `modules/engine` | 14,025 | Game loop, entities, systems, AI, map generation |
| `modules/ui` | 3,247 | Flutter widget screens (8) |
| `modules/core` | 2,879 | EventBus, configs, 3D math, item models, perf utils |
| `modules/gamepad` | 789 | Controller detection + menu navigation |
| `modules/service` | 303 | Audio, achievements |
| `lib/` (root app) | 571 | `main.dart` + debug/weapon extensions |

Stack: Flutter 3.10.4, Flame 1.17, flame_forge2d 0.17, flame_audio, socket_io_client, gamepads 0.1.9.

### Two games in one repo

The repo contains a **complete 2D platformer** (`ActionGame`) and a **half-built pseudo-3D corridor runner** (`ActionGame3D`, 2,916 LOC across 11 files) side by side. Branch `3d_last` is active; the last six commits are 3D work.

The "3D" is fake 3D: hand-rolled `WorldPos` (x/y/z), `AABB3D` collision, and `IsoProjection` — an oblique projection with hardcoded `kZX = -0.30`, `kZY = 0.40`, painting into Flame's 2D canvas with depth sorting faked via render priority. It exists solely because Flame has no 3D.

**Decision: the 3D branch is written off.** The mature 2D `ActionGame` is the porting source.

### Documentation state

- `AGENTS.md` and `.claude/CLAUDE.md` are **the same 1,350-line document**, describing a "v2.0 2D Edition" with a flat `lib/` layout (`lib/action_game.dart`, `lib/game/character/knight.dart`) that **no longer exists**. Their API reference, file tree, and architecture diagram are all stale.
- `PROJECT_OVERVIEW.md` describes only the 2D game.
- **`.claude/NEXT_STEPS.md` (2026-04-12) is the only accurate document.**

Both stale documents must be rewritten at cutover (Phase 7).

### Test coverage

Effectively zero. `test/widget_test.dart` is Flutter's untouched default; `test/map_generator_examples.dart` is a demo script, not a test. There is currently no way to detect a behavioural regression.

---

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | 2D or 3D target? | **Godot 2D.** Port `ActionGame`; discard the pseudo-3D branch. |
| 2 | Shape of "done"? | **Vertical slice first**, with headless golden-value discipline on two subsystems: map generation and combat/stat math. |
| 3 | Does Flutter stay alive? | **Hard cutover, same repo.** Dart frozen as reference, deleted at cutover. |
| 4 | Input model? | **All three devices from day one**, every input routed through `InputMap` actions. |
| 5 | Language? | **GDScript.** (C#'s mobile export story is the weakest link, and mobile is in scope.) |
| 6 | Multiplayer? | **Godot high-level multiplayer.** Node/socket.io server retired. |
| 7 | Map data? | **Godot-native.** Hand-authored maps become `.tscn`; `map-editor.html` retires. |
| 8 | Project structure? | **Scene-first, plus autoloads for cross-cutting services, `Resource` files for balance data, and a `scripts/` layer of pure logic.** |

### Acknowledged tension

Decisions 6 and 7 both add scope and pull against decision 2. Godot-native multiplayer requires the slice to be MP-shaped from the first character; Godot-native maps require the procedural generator to build scenes rather than emit data. Both buy a better end state. The design below mitigates each explicitly (§4.2 authority model, §6 generator/builder split).

---

## 3. Repo layout

```
nomercy/
├── assets/                  shared, unchanged (51 PNG, 8 WAV)
├── lib/ modules/            Dart — frozen, reference-only, deleted at cutover
├── tools/dart_fixtures/     throwaway Dart harness → golden JSON
├── docs/superpowers/specs/  this document
└── godot/                   Godot 4.7 project
    ├── scenes/              entities, maps, effects
    ├── ui/                  Control-node screens
    ├── autoload/            GameState, AudioService, EventBus
    ├── resources/           .tres balance data
    ├── scripts/             pure logic, no node deps ← tests target this
    └── test/                GUT suites + committed fixtures
```

Two `.gitignore` blocks: `.godot/` and `.dart_tool/`.

Project settings: `stretch_mode = canvas_items`, `aspect = keep`, base resolution 1280×720 (matching the current `GameConfig.cameraWidth = 1280`), landscape orientation.

---

## 4. Runtime architecture

### 4.1 Character scenes — composition over inheritance

```
Character (CharacterBody2D)          # one base scene for all four classes
├── AnimatedSprite2D
├── CollisionShape2D
├── HurtBox (Area2D)                 # receives damage
├── HitBox  (Area2D)                 # deals damage
├── StateMachine (Node)              # ports character_state_machine.dart
└── MultiplayerSynchronizer
    @export stats:  CharacterStats   # .tres — Knight/Thief/Wizard/Trader
    @export attack: AttackBehavior   # .tres — melee vs projectile
```

The four classes become four `.tres` pairs, not four subclasses. The existing
`knight_movement_strategy` / `knight_action_strategy` / `knight_skills` triads (and their
Thief/Wizard/Trader equivalents) collapse into exported resources — same data, no class explosion.

### 4.2 Authority owns state (the MP-shaped inversion)

Today `CombatSystem.processAttack()` holds a `game` reference and mutates characters from
outside. That cannot replicate. The port inverts it:

- **`scripts/combat.gd`** — pure functions. `calc_damage(base, combo, blocking) -> float`.
  No nodes, no state. Golden-fixture tested.
- **The character node** — owns and mutates its own `health` / `stamina` / `combo`, and only
  when `is_multiplayer_authority()`. `MultiplayerSynchronizer` replicates those properties.

Bot AI decisions and damage application both run on the authority only; peers see replicated
results.

This is the single largest structural change in the port, and the reason the vertical slice
must be MP-shaped from the first character — retrofitting it reaches back through every entity.

### 4.3 EventBus shrinks

Of the 60+ event classes in `core/lib/src/events/` (982 LOC) served by a 399-LOC bus, roughly
50 become plain signals on the emitting node (`character.died`, `character.landed`) — local,
typed, zero infrastructure. The autoload `EventBus` keeps only the genuinely global:
`game_over`, `wave_started`, `achievement_unlocked`, `play_sfx`.

---

## 5. Input, UI, localization

### Input: one indirection, three devices

Every input routes through `InputMap` actions: `move_left`, `move_right`, `jump`, `attack`,
`block`, `dodge`, `crouch`, `pause`. **Nothing reads a device directly.**

- **Keyboard + gamepad**: free. Both bound to the same actions;
  `Input.get_axis("move_left", "move_right")` handles a WASD key and an analog thumbstick
  identically.
- **Touch**: a `VirtualJoystick` Control (~60 lines) emitting `InputEventAction` via
  `Input.parse_input_event()`, feeding the same actions. Shown only when `DisplayServer`
  reports a touchscreen.

**Deletes `modules/gamepad` entirely (789 LOC).** Detection and device mapping are engine
responsibilities. Menu navigation (`gamepad_menu_controller`, `gamepad_nav_service`,
`gamepad_route_aware`, and the `gamepadRouteObserver` wired into `MaterialApp`) is replaced by
`Control.focus_neighbor_*` plus built-in `ui_up` / `ui_down` / `ui_accept`.

The current code lacks this indirection — `action_game.dart:416` reads `joystick.relativeDelta`
directly, which is precisely why gamepad support needed 789 LOC bolted on afterward.

### UI: full rewrite, no reuse

All 3,247 LOC of Flutter widgets across 8 screens are discarded; `StatefulWidget` has no Godot
analogue. Each screen becomes a Control scene using Containers (`VBoxContainer`,
`GridContainer`) rather than manual positioning, with one shared `Theme` resource.

**Do not forget:** `font_awesome_flutter` icons (HUD health/coins/skull) need replacing —
either an icon font imported as a `FontFile`, or extracted SVGs.

### Localization

Drops `intl`, `LocalizationManager`, and the `AnimatedBuilder` rebuild dance for Godot's
`TranslationServer`: a CSV of keys per locale, auto-imported, `tr("game_title")` at call sites.
`set_locale()` re-renders every Control automatically.

---

## 6. Map pipeline & procedural generation

### PRNG non-equivalence (important)

**Dart's `Random(seed)` and Godot's `RandomNumberGenerator` are different algorithms** (LCG vs
PCG32). Same seed, different number stream, different map. No arrangement makes generator
output identical across engines.

Generator fixtures therefore assert **structural invariants**, not identity:

- platform count within configured min/max
- every platform reachable from spawn (DFS)
- no overlaps; all within bounds
- difficulty honored — platform width ranges per tier (Expert 100–150px, Hard 120–200px,
  Medium 150–250px, Easy 200–300px)
- style honored — `towers` produces vertical stacks, `platformer` produces four layers

Reimplementing Dart's PRNG in GDScript (~40 lines) for identical output is **rejected**:
seed-sharing only needs consistency *within* Godot after cutover.

### Structure

```
scripts/map_generator.gd    pure: MapConfig → Array[PlatformData]     ← invariant tests
scripts/map_validator.gd    pure: DFS reachability + bridge insertion ← unit tests
scenes/map_builder.gd       PlatformData → instanced nodes
scenes/maps/level_1.tscn    hand-authored, rebuilt in the Godot editor
```

Keeping a pure-data layer *inside* the generator preserves fixture testability despite the
Godot-native map decision. This mirrors the split the Dart code already has between
`map_generator_config.dart` and `map_loader.dart`.

### Consolidation

`tiled_platform` + `enhanced_platform` + `tiled_ground_component` + `platform_factory` +
`game_platform` (~830 LOC) collapse into **one** `Platform.tscn`: `StaticBody2D` +
`Sprite2D` with `texture_repeat` + `CollisionShape2D`, type as an exported enum swapping the
texture. Flame needed five classes for seamless tiling; Godot needs a flag.

Retired: `map_loader.dart`, `game_map.dart`, `map-editor/map-editor.html`.

The 351-LOC infinite-world chunk streamer becomes chunk scenes instanced and `queue_free()`d
around the player.

---

## 7. AI & combat

### Tactics become data

The 7 tactic files (`aggressive`, `defensive`, `balanced`, `tactical`, `berserker`, `sniper`,
`coward`) are one algorithm parameterized 7 ways. Port as **one** `bot_ai.gd` + **seven**
`BotPersonality.tres` files. Adding a personality becomes authoring a resource in the
inspector.

```
scripts/bot_decision.gd     pure: WorldSnapshot + Personality → Action   ← unit tested
scenes/BotController.gd     node: throttles by reaction_time, applies action
resources/personalities/    aggressive.tres … coward.tres
```

The six evaluators (`evaluate_attack`, `_defend`, `_reposition`, `_evade`, `_dodge`,
`_jump_attack`) become pure functions taking a plain snapshot struct — distance, health %,
stamina, incoming projectiles, target vulnerability — returning scored actions.

**Port the scoring weights faithfully.** They *are* the game's feel; "improving" them during a
port is how a migration loses its identity.

> Note: `.claude/NEXT_STEPS.md` calls `SmartBotAI` "broken / incompatible — dead weight," but
> that is true only against the 3D branch. Targeting Godot 2D makes those 549 LOC directly
> portable.

### Combat

`collision_system.dart` and every manual AABB overlap check are deleted: `HitBox` / `HurtBox`
`Area2D` nodes with collision layers do it in-engine. Damage math
(`base × combo multiplier × block reduction`) moves to `scripts/combat.gd` as pure functions
with golden fixtures.

`projectile.dart` + `poolable_projectile` + `impact_effect` (~650 LOC) become one
`Projectile.tscn` (`Area2D` + `AnimatedSprite2D` + `GPUParticles2D` on impact).
`pool_manager.dart` retires — pooling at these entity counts is premature in Godot.

---

## 8. Testing strategy

**Framework: GUT 9.6.0** — verified to declare `godot_min: 4.6`, `godot_max: 999`, covering
4.7. Headless mode auto-forces exit and ignores pauses.

### Fixture asymmetry

- **Combat math — exact values.** `calc_damage()` is deterministic arithmetic with no RNG.
  Fixtures like `{base: 15, combo: 3, blocking: false} → 19.5` port across engines exactly
  (float tolerance `1e-6`). Matrix: 4 classes (attack damage 15 / 10 / 20 / 12) × combo count
  1–5 × blocking on/off. Stamina is excluded from the damage matrix — it gates whether an
  attack occurs, not its damage — and is covered by separate unit tests on the stamina
  cost/regen functions.
- **Map generation — invariants only.** See §6.

`combat_damage.json` holds input→output pairs. `map_invariants.json` holds, per
`(style, difficulty)` pair, the **expected bounds** each generated map must satisfy (count
range, width range, connectivity = true) — not captured map output, which is unreproducible
across engines.

### Capture harness

`tools/dart_fixtures/` — a throwaway Dart script (not a test) importing the frozen `engine`
package, sweeping the input matrix, writing `godot/test/fixtures/combat_damage.json` and
`map_invariants.json`. Run once, committed, then Dart can die. Labeled throwaway so it is not
mistaken for a maintained tool.

### Four layers

1. **Pure unit (GUT)** — everything in `scripts/`. No scene instantiation, milliseconds.
2. **Golden fixtures** — the two guarded subsystems.
3. **Scene smoke tests** — instantiate `Character.tscn`, assert gravity lands it on a platform;
   fire a projectile, assert the `HurtBox` reports a hit. Catches broken scene wiring, which
   unit tests structurally cannot.
4. **Manual play-test** — feel. Not automatable; the vertical slice exists to produce this
   judgment early.

**CI:** `godot --headless -s addons/gut/gut_cmdln.gd --path "$PWD" -gdir=res://test -gexit`

**Deliberately not tested:** UI screens, animation timing, audio. Low regression risk, high
test-maintenance cost.

---

## 9. Phasing

> **Planning scope:** this document covers the whole migration, but it is too large for a
> single implementation plan. The first plan covers **Phase 0 and Phase 1 only**, terminating
> at the go/no-go decision. Phases 2–7 get their own plans, written after that decision — their
> content depends on what the slice reveals.

### Phase 0 — Foundation (no gameplay)

- Godot 4.7 project in `godot/`, GUT 9.6 installed, headless CI green on an empty suite
- **All** `InputMap` actions defined up front — keyboard + gamepad + touch bindings
- **⚠️ Capture the Dart fixtures.** The only ordering-critical task in the migration: it
  requires a runnable Dart tree. Everything else can slip; this cannot.
- **⚠️ Resolve sprite-sheet slicing.** `sprite_utils.dart:34` slices strips by image height
  (`textureSize: Vector2(img.height, img.height)`), but `knight_walk.png` is 1024×**1536** —
  taller than wide, so that rule cannot be what produces those frames. Every character's `walk`
  sheet has this shape. Unknown until the files are opened; gates all `SpriteFrames` work.
- `Theme` resource skeleton

### Phase 1 — Vertical slice → **go/no-go decision point**

Knight only; `level_1.tscn` hand-rebuilt; one aggressive bot; HitBox/HurtBox combat on
fixture-tested `combat.gd`; state machine (idle/walk/jump/land/attack/block/dodge); minimal HUD
(health/stamina/combo); all three input devices live. `MultiplayerSynchronizer` present on
`Character.tscn` from day one — inert in single-player, but proving the §4.2 shape before three
more characters inherit it.

Include a two-peer local multiplayer test here (≈1 hour) to de-risk the authority model.

If the feel is wrong here, only a fraction of the budget is spent.

### Phases 2–6 (dependency order)

2. Remaining 3 characters + 6 personalities — pure `.tres` authoring
3. Wave system, 4 game modes, items / chests / inventory, audio, achievements
4. Map generator + validator + builder, 6 styles × 4 difficulties, infinite chunk streaming
5. 8 UI screens + theme + localization + settings
6. Multiplayer — `ENetMultiplayerPeer`, host-authoritative, lobby, replication

### Phase 7 — Cutover

Delete `lib/`, `modules/`, `tools/dart_fixtures/`, `map-editor/`, and the Flutter platform dirs
(`android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`). Configure export presets.
**Rewrite `AGENTS.md` and `.claude/CLAUDE.md`** — they describe a `lib/` layout that stopped
existing several refactors ago and would be actively misleading in a Godot repo.

---

## 10. Risks

| Risk | Mitigation |
|---|---|
| Multiplayer constraint imposed in Phase 1, validated in Phase 6. A wrong authority model reaches back through every entity. | Two-peer local test during Phase 1. |
| Sprite-sheet slicing rule is not what the code implies; frame layout unknown. | Phase 0 blocker, resolved before any `SpriteFrames` work. |
| `assets/` shared between live Dart and live Godot trees for the whole migration. Godot writes `.import` files next to every asset. | Accepted — noisy diffs, harmless. |
| Zero existing test coverage means no parity baseline outside the two guarded subsystems. | Accepted deliberately; the guarded subsystems are where silent drift would be invisible longest. |
| Vertical slice scope creep from decisions 6 and 7. | Phase 1 contents are fixed above; anything else waits for the go/no-go. |

---

## 11. Out of scope

- The pseudo-3D corridor runner (`ActionGame3D` and all `*_3d.dart` files)
- The Node/socket.io multiplayer server
- `map-editor/map-editor.html`
- Preserving cross-engine seed compatibility for procedural maps
- Automated tests for UI, animation timing, and audio
