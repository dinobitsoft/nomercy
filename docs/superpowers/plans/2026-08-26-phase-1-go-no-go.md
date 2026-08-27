# Phase 1 Vertical Slice — Go/No-Go Report

**Date:** 2026-08-27
**Scope:** Tasks 1–18 of `docs/superpowers/plans/2026-08-26-godot-migration-phase-0-1.md`
**Spec:** `docs/superpowers/specs/2026-08-26-flutter-to-godot-migration-design.md`
**Ledger:** `.superpowers/sdd/2026-08-26-godot-migration-phase-0-1/progress.md` (rulings R1–R22)
**Worktree:** `.claude/worktrees/godot-migration`, branch `worktree-godot-migration`, HEAD `8bed14b`

---

## ⚠️ Scope boundary on this document

This report is written by a headless agent. It can run the test suite, count lines, and mine
the execution ledger. It **cannot** judge whether the game feels right — that requires a human
playing it. Section 3 below (Play-test) is a **template with the six required questions left
blank**, plus whatever objective data bears on each. No subjective verdict has been fabricated
or inferred from test results. **The overall go/no-go decision is blocked on a human filling in
Section 3.**

---

## 1. Test results

### 1.1 Full suite (headless GUT)

Command: `godot --headless -s addons/gut/gut_cmdln.gd --path godot -gdir=res://test -gexit`

Actual summary output:

```
==============================================
= Run Summary
==============================================

Totals
------
Deprecated           49

Scripts              17
Tests               121
Passing Tests       121
Asserts             245
Time              86.398s

---- All tests passed! ----
```

Exit code: `0`.

17 scripts break down as 15 `test/unit/` + 2 `test/integration/`. The 49 "Deprecated" notices
are all `wait_frames has been replaced with wait_physics_frames` — GUT 9.6's own API drift, not
a project defect (see §3 of the deferred-findings table).

### 1.2 Project-open smoke check

Command: `godot --headless --path godot --quit`

Actual output:

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org
```

Exit code: `0`. No import errors, no script errors, no missing-resource warnings. The project
opens cleanly with `level_1.tscn` as `run/main_scene`.

### 1.3 Architectural boundary checks (from the task brief's verification block)

| Check | Command | Result |
|---|---|---|
| `scripts/` is node-free | `grep -rnE '\bNode\b\|get_node\|\$\|preload\(' godot/scripts/` | **OK** — no matches |
| No direct device reads outside the input layer | `grep -rnE 'is_key_pressed\|get_joy_\|InputEventKey\|joy_connection' godot/scenes/ godot/ui/virtual_joystick.gd` | **OK** — no matches |
| Dart tree untouched | `git diff --stat main -- lib/ modules/` | **OK** — empty diff |
| Shared assets untouched | `git diff --stat main -- assets/` | **OK** — empty diff |
| Working tree clean | `git status --short` | **OK** — clean |

All five hold. The suite is genuinely green and the structural guarantees the plan promised
(pure logic layer, no direct device reads, frozen Dart reference) are real, not aspirational.

### 1.4 What "green" does and doesn't prove here

Worth stating plainly because this project surfaced the counterexample itself: during Task 17,
`test_enemy_closes_on_the_player_over_time` **passed** while the enemy was physically frozen
(`on_wall=true`) against a platform lip 127px from the player, forever. The test only checked
that distance decreased over its polling window, which happened to be true during the airborne
fall before the bot got stuck. It took a reviewer building an independent physics probe — not
the suite — to catch it. The bug is fixed (R20/R21 below), but it is a real, in-repo example of
green tests coexisting with visibly broken gameplay, and it is why this report cannot treat
121/121 as itself a play-test substitute.

---

## 2. LOC comparison

### 2.1 Godot artifacts (measured, `wc -l`, excluding `addons/`)

| Category | Files | LOC |
|---|---:|---:|
| Implementation `.gd` (`scripts/`, `scenes/`, `resources/`, `ui/`, `tools/`) | 15 | 981 |
| Scenes/resources (`.tscn`, `.tres`) | 11 | 465 |
| Test `.gd` (`test/unit/` + `test/integration/`) | 17 | 1,010 |
| Golden fixture (`combat_damage.json`, 96 records, generated once from Dart) | 1 | 769 |
| **Total slice footprint** | 44 | **3,225** |

Production code + data (excluding tests and the generated fixture): **1,446 LOC** implements a
Knight-only, melee-only, single-player-playable, all-three-input-devices vertical slice (see §7.1
for exactly which InputMap actions each device — including touch — can reach; touch is not yet
complete for all 8).

### 2.2 Named replacements (brief §2, measured against the actual files)

| Dart source | Measured LOC | Ledger's estimate | Godot replacement | Measured LOC | Reduction |
|---|---:|---:|---|---:|---:|
| `modules/gamepad/` (11 files) | 789 | 789 | Nothing — `InputMap` (project.godot) + engine device handling. Zero gamepad-specific GDScript exists anywhere in the slice (verified by grep). | 0 | **100%** |
| 5 platform classes (`tiled_platform` 174, `enhanced_platform` 178, `tiled_ground_component` 257, `platform_factory` 222, `game_platform` 44) | **875** | ~830 | `Platform.tscn` (11) + `platform.gd` (43) | 54 | **94%** |
| `sprite_utils.dart` | 96 | 96 | `knight_frames.tres` (90, data) + `build_knight_frames.gd` (44, one-time authoring tool, not shipped runtime code) | 90 shipped / 134 incl. tool | **~6%** (moved to data, not deleted) |
| `collision_system.dart` | 122 | (n/a) | HitBox/HurtBox `Area2D` nodes built into `character.tscn`; melee resolution folded into `character.gd` (not separately counted) | 0 standalone | **100%** (absorbed into engine collision) |
| `pool_manager.dart` | 139 | (n/a) | Nothing — direct `instantiate()`/`queue_free()`, no pooling (spec §7: "premature at these entity counts") | 0 | **100%** (deleted, not replaced) |

Two corrections to the brief's own numbers, found while measuring: the five platform classes
total **875 LOC**, not the ~830 the ledger estimated (off by including/excluding
`platforms.dart`'s 3-line barrel differently — immaterial to the conclusion). `sprite_utils.dart`
matched exactly at 96.

**Important honesty note:** the four Dart files/packages above still physically exist in
`lib/`/`modules/` — the design (spec §2 decision 3) freezes Dart as reference until Phase 7
cutover; nothing is deleted yet. "Replaced" means *architecturally superseded and slated for
deletion*, verified by the empty `git diff` against `main` in §1.3, not *removed*.

### 2.3 Character/combat/AI/HUD — not a clean 1:1, scope differs

| Dart backing (Knight + 1 personality + HUD only) | LOC | Godot slice equivalent | LOC |
|---|---:|---|---:|
| `game_character.dart` | 692 | `character.gd` | 291 |
| `knight.dart` | 72 | `character_stats.gd` + `knight_stats.tres` | 16 + 16 |
| `combat_system.dart` | 357 | `combat.gd` | 36 |
| `character_state_machine.dart` + `character_animation_state.dart` | 237 | `state_machine.gd` | 57 |
| `movement_strategy.dart` + `knight_movement_strategy.dart` | 33 | `movement_profile.gd` + `knight_movement.tres` | 22 + 10 |
| `smart_bot_ai.dart` (all personalities, generic) + `aggressive_tactic.dart` | 536 | `bot_decision.gd` + `world_snapshot.gd` + `bot_controller.gd` + `bot_personality.gd` + `aggressive.tres` (1 of 7 personalities authored) | 67+13+106+15+13 = 214 |
| `hud.dart` (Flutter widget, full framework overhead) | 464 | `hud.gd` + `hud.tscn` | 59 + 52 |
| **Total** | **2,391** | | **852** |

Caveat: this is **not apples-to-apples**. `smart_bot_ai.dart` already implements all personality
math generically in Dart; the Godot port carries the same generic structure
(`bot_decision.gd` is personality-agnostic) but only **1 of 7** personalities has an authored
`.tres`. `hud.dart` includes Flutter widget/rebuild scaffolding with no Godot analogue. The
reduction is real but partly reflects "not yet built" rather than pure consolidation — see §5.

### 2.4 What this slice does NOT replace (explicitly out of scope, spec §9)

Thief, Wizard, Trader; the other 6 bot personalities; projectiles (Knight is melee-only); dodge
and i-frames (`Stamina.can_dodge` exists, the action doesn't); landing recovery / hard-landing
stun; wave system, game modes, items, chests, audio, achievements; procedural map generation and
infinite chunk streaming; 7 of 8 UI screens, theming, localization; actual networked play
(Task 18 proves the authority model, not multiplayer itself); the `autoload/` layer
(`GameState`, `AudioService`, `EventBus`).

---

## 3. Play-test — TEMPLATE, awaiting human input

**These six questions cannot be answered by this agent.** Each is stated below with whatever
objective, measured context bears on it. The blanks must be filled in by a human running
`godot --path godot` and playing for at least ten minutes, per the brief.

> **1. Does movement feel like the Flutter build, better, or worse?**
> Objective context: gravity (1000), max fall speed (800), jump velocity (-300), and the speed
> formula (`dexterity/2` base, ×100 walk / ×160 run, threshold 0.8) are all ported verbatim from
> `game_config.dart` / `knight_movement_strategy.dart`. `floor_snap_length = 10.0` was added
> (R20) to match Dart's `platformSnapDistance`, which the engine default (1.0) did not — without
> it, characters would feel stickier/less forgiving than Dart on uneven ground. Dodge and
> landing-recovery are absent (out of slice scope), so those axes of feel are not comparable yet.
> **Answer: _______________________________________________**

> **2. Does the melee swing land where you expect at 60px reach?**
> Objective context: `melee_reach = attackRange × 30 × (1 + combo × 0.1)` is fixture-matched
> exactly (60px at combo 0, up to 84px at combo 4). The HitBox/HurtBox wiring was fixed twice by
> review (R2: monitoring-timing bug that made the first swing always miss; Task 11 fix round: a
> three-part combo/reach coupling bug, closed with a discriminating regression test). One
> architectural gap remains and is unverified: the hit-candidate set is captured once at swing
> start and does not grow as combo-driven reach grows mid-swing (bounded to ~6px per hit at
> Knight scale; not exercised by any current test or by a single-target fight).
> **Answer: _______________________________________________**

> **3. Is the aggressive bot a credible opponent, or does it just walk into you?**
> Objective context: this exact question already surfaced a real bug during automated work (see
> §1.4) — the enemy got physically stuck against a platform lip while its own "closes distance"
> test kept passing. That specific failure is fixed and re-verified by an independent physics
> probe (closes to 0.758px, kills the player). But the bot's movement speed is a **known,
> deliberate departure from ported Dart values in two separate places, both purpose-built rather
> than ported** (§5.1 items 1–2): during the melee attack state, 40/30 px/s approach/retreat
> constants (R16) replace a Dart value that is not merely slow but literally zero (dead code
> killed by `stopThreshold`); outside the attack state, the "approach"/"retreat" bot actions run at
> **640 px/s** against a Dart source that likewise never moves via that path. Whether either speed
> feels credible is exactly what cannot be verified here.
> **Answer: _______________________________________________**

> **4. Does combo scaling read on screen?**
> Objective context: combo damage/reach growth is fixture- and unit-tested for correctness
> (values only); the HUD combo counter is signal-bound and unit-tested for propagation. Nothing
> tests animation timing or visual legibility of the scaling — spec §8 explicitly excludes
> animation timing from automated coverage by design.
> **Answer: _______________________________________________**

> **5. Does the gamepad feel right without any gamepad-specific code?**
> Objective context: confirmed by grep that zero gamepad-specific GDScript exists anywhere in
> the slice — only `InputMap` bindings in `project.godot` and generic `Input.get_axis` /
> `is_action_pressed` calls in `player_controller.gd`. This is the concrete evidence for the
> input-indirection decision (spec §5) and the reason `modules/gamepad`'s 789 LOC can be deleted.
> However, the InputMap's 0.2 analog deadzone is **unverifiable by the automated suite by
> construction** (R14): `Input.action_press()` in tests bypasses the real joypad-event pipeline
> that applies deadzone rescaling. It has never been checked against real hardware at any point
> in this project, including in this report.
> **Answer: _______________________________________________**

> **6. Anything that felt wrong and is not covered by a test?**
> No objective proxy exists for this question by definition. Everything the ledger already
> knows to be imperfect-but-untested is listed in §4 below; this question is for whatever isn't.
> **Answer: _______________________________________________**

---

## 4. Deferred findings and known gaps (consolidated from the ledger)

| # | What | Why deferred | When it will bite |
|---|---|---|---|
| 1 | `Platform.tscn`'s `texture_repeat` tiling is wired but **never exercised** — every `level_1` platform is ≤120×30px, smaller than `brick_tile.png` (128×128) or `ground_tile.png` (1536×1024), so `region_rect` never exceeds one tile. | Task 8 finding; headless GUT cannot assert rendered pixels; escalated explicitly to Task 19. | The spec's central justification for collapsing 5 platform classes into one scene is "Godot's `texture_repeat` does the tiling those classes hand-rolled" — **unverified by anything in this report**, since the human play-test that could check it hasn't happened. Bites the first time a platform larger than one tile is authored. |
| 2 | `stop_block()` has no `is_authority()` guard, unlike every other mutator; `_is_blocking` is also not in `MultiplayerSynchronizer`'s replicated property list (`health`/`stamina`/`combo`/`position`/`facing_right` only). | Judged Minor for single-player: not one of the three protected fields, internal call sites already authority-gated, `PlayerController` checks authority before calling it. | Phase 6 multiplayer: a non-authoritative peer can locally flip `_is_blocking`, desyncing the 70% block-damage-reduction outcome from what the authority computes. |
| 3 | The melee hit-candidate set is captured once at swing start (`CircleShape2D` sized to combo-at-start) and cannot grow as combo-driven reach grows mid-swing, unlike Dart's per-target re-evaluated loop. | Bounded effect (~6px per hit at Knight scale); nothing in the slice chains enough hits on multiple targets to exercise it; introduced as a side effect of fixing a worse bug (Task 11 fix round 1). | Phase 2+ multi-enemy waves, or any character/personality with faster combo-driven reach growth. |
| 4 | Ground-tier platform Y jitter (1–11px in the original JSON) creates genuinely impassable walls for **climbing** in Godot. `floor_snap_length=10.0` (ported from `platformSnapDistance`) fixes descending onto a lower tile but not climbing a higher one — confirmed by an empirical physics probe (`on_wall=true` against a 9px lip). | Routed around for the slice via enemy spawn placement, not fixed at the source. | Phase 2+, the moment any traversal — player or bot — needs to cross the original ground tier's jitter rather than spawn past it. Candidate fixes: normalize the JSON source, or add step-up handling to `Character`. |
| 5 | **Fixed by this fix wave (F4).** `tools/convert_map.py` used to do a blind full-file overwrite of `level_1.tscn` (and defaulted to `level_1` with no arguments), silently destroying everything Task 17 added (Player/Enemy/UILayer/HUD/TouchControls) whenever it was rerun. | Was assessed as documented design (spec §6, Task 8 brief: converter is one-off), not a defect. Now fixed rather than left as a footgun. | The script now requires an explicit map-name argument (refuses with usage text if omitted) and refuses to overwrite a destination `.tscn` containing any node beyond a Platform instance / `PlayerSpawn` / scaffolding, unless `--force` is passed. Verified: no-args refuses (exit 2); against the assembled `level_1.tscn` refuses and lists the 5 unexpected nodes (exit 1); with `--force` it proceeds; `level_1.tscn` was then restored via `git checkout` and `git status` confirmed clean. |
| 6 | InputMap's 0.2 analog gamepad deadzone cannot be exercised by GUT — `Input.action_press(action, strength)` sets action strength directly and bypasses the real `InputEventJoypadMotion` translation pipeline that applies deadzone rescaling. | Engine behavior, unverifiable headlessly by construction, not by omission. Routed to Task 19's manual play-test. | **Still unverified as of this report** — the manual play-test that was the only place this could be checked has not happened yet. |
| 7 | Bot action tie-breaking resolves by `Dictionary` insertion order (deterministic in Godot 4, not random) rather than an explicit rule. Algebraically reachable only at extreme personality values (e.g. dodge-vs-attack ties need `0.5a - 0.1c = 0.4`) that no currently-defined personality hits. | Theoretical fragility, not a live bug — Aggressive doesn't trigger it. | Phase 2, when Berserker (`a=1.0, c=0.0`) and other extreme personalities are authored — worth a recheck then. |
| 8 | Under Knight's current constants, two of the bot's three attack-state movement branches (approach, hold-at-range) are dead code — `melee_reach` (60–84px) is always below `optimalRange × 0.7` (105px), so only the retreat branch ever fires. Commented in code, kept for structural fidelity to Dart (which has the same dead-branch property). | Deliberate, matches Dart's own structure. | Phase 2, if any character/personality combination puts `melee_reach` above 105px — the dead branches wake up completely untested. |
| 9 | GUT's `wait_frames()` is deprecated (49 warnings in the current run) in favor of `wait_physics_frames`/`wait_process_frames`. | Cosmetic test-framework API drift; semantics currently unaffected — confirmed via R17's investigation into GUT's own off-by-one frame count. | A future GUT major version may remove `wait_frames` outright, breaking every timing-based test in one bump. |
| 10 | One HUD timing test's tolerance was widened (0.01 → 1.0) rather than restructured to avoid the timing dependency entirely, though a cleaner fix (assert immediately after the synchronous signal emit) was identified by review. | The widening is justified and proven deterministic (exactly a 0.75 drift from GUT's frame-waiter off-by-one, confirmed against GUT source and 3 repeat runs); the cleaner fix wasn't required. | Never functionally — the assertion is measuring real deterministic engine behavior, not masking a bug. Worth doing anyway for precision. |
| 11 | Only 1 of 7 bot personalities (`aggressive.tres`) has been authored, though `bot_decision.gd` is already personality-agnostic and would accept the other 6 with zero code changes. | Explicitly out of Phase 1 scope (spec §9 / brief "Deferred to later phases"). | Not a bug — flagged here because it materially affects how §2.3's LOC comparison should be read: most of the AI "reduction" is architecture, not yet content. |
| 12 | The golden fixture (`tools/dart_fixtures/bin/capture.dart`) does not call `CombatSystem.processAttack()`; it re-implements the damage formula independently, so its 96/96 match (§7.2) proves internal consistency between two transcriptions, not correctness against the frozen Dart engine. Concretely, Dart's `_canBlock` requires facing + stamina ≥ 10 (`combat_system.dart:250-258`); the Godot port passes bare `is_blocking()` (`character.gd:263`), and the fixture cannot see the gap because `blocking` is a free boolean input on both sides. | Spec §8 required importing the frozen `engine` package for exactly this reason; the fixture harness instead took the R6 relative-import route, which loses formula-source guarantees the constant-import route would have kept. | Any future combat rule that depends on facing/stamina context around blocking, or any other condition the fixture's re-implementation omits, ships silently wrong and golden-fixture-green at the same time. Phase 2 should either import the real `engine` package per spec §8, or explicitly accept this as a known, permanent limitation of the fixture approach. |

---

## 5. Rulings made (R1–R22)

One line each, with the cost if the ruling is wrong. Full reasoning is in the ledger.

| # | Ruling | Cost if wrong |
|---|---|---|
| R1 | `_apply_gravity` was zeroing ALL vertical velocity on-floor, cancelling the jump impulse it had just set; fixed to only zero downward velocity. | Jump feel differs slightly from Dart; one-line tunable. |
| R2 | `Area2D.monitoring` toggled on and queried the same physics frame meant the first melee swing always reported zero hits; fixed to always-monitoring, never toggled. | Marginal per-frame overlap bookkeeping for two extra `Area2D`s. |
| R3 | Two `BotDecision` tests contradicted the scoring math as specified; corrected the retreat-score weight (hard gate vs. Dart's soft weight) and one test's snapshot, hand-verified both against Dart. | A retreating bot flees too eagerly; one constant to retune. |
| R4 | The local asset symlink route breaks CI (fresh checkout has no `godot/assets`); added a CI-only symlink step. | CI red until added; no local effect. |
| R5 | GUT's `-gdir` doesn't recurse subdirectories by default, so the plan's own layout silently reports "0 tests, exit 0"; added `.gutconfig.json`. | None identified — treat any "0 tests, exit 0" report from here forward as a false green. |
| R6 | The Dart fixture harness can't depend on `package:core` (pulls in Flutter SDK); switched to a relative import of one zero-import config file. | Fixture loses strict constant-provenance guarantee; formula shape/coverage unaffected. |
| R7 | Symlinking `assets/` locally on Windows transparently pollutes the tracked Dart `assets/` tree with `.import` files; switched local route to a plain copy (CI keeps the symlink, since CI checkouts are ephemeral). | A stale local copy could drift from repo-root `assets/` if art changes; re-copy fixes it. |
| R8 | Godot doesn't register a new `class_name` for headless GUT runs without one prior editor pass; documented the required incantation and carried it through every later `class_name`-introducing task. | ~10 min misdiagnosis per task, and real risk of "fixing" already-correct code chasing a phantom error. |
| R9 | Pre-authorized a `ResourceSaver`-script fallback in case hand-authored `.tres` for a custom Resource class didn't round-trip. Never needed. | None — contingency only. |
| R10 | The controller's own Task 7 test-count arithmetic was off by one; corrected all downstream cumulative-count expectations by −1. | A reviewer could reject a correct task for a phantom "missing" test. |
| R11 | The plan was authored against the wrong branch (`3d_last` vs. this worktree's `origin/main` base); full diff-audit of every cited Dart source file found exactly one wrong provenance citation (a `health` field) and zero wrong captured values. | None to the artifact — the audit is the finding. |
| R12 | GUT hard-errors (not warns) on `:=` type inference through an unsafe member access when the local is typed as a generic engine base class; typed test locals as the custom class instead, in the two remaining tasks carrying the pattern. | A parse error in test code supplied verbatim by the plan; high risk of an implementer weakening correct assertions to "fix" it. |
| R13 | Gave the character root body `collision_layer=0`/`mask=1` so two characters don't physically shove each other; verified against Dart source that character-vs-character collision never existed (dead event type, zero call sites). | One mask value to change if body-blocking is ever wanted. |
| R14 | The InputMap analog deadzone is unverifiable by GUT (`Input.action_press` bypasses the real device-event pipeline); routed to manual play-test rather than fixed or faked. | Stick drift would be obvious on real hardware immediately — but that check has still not happened (see §4 item 6). |
| R15/R16 | **KEEP the constants (40/30 px/s), DISCARD the original reasoning — corrected below.** The original ruling justified 40/30 as preserving Dart's 4:3 approach:retreat *ratio* while calling Dart's literal magnitude (`dexterity/3 = 2.67 px/s`) "unusably slow." That reasoning does not survive scrutiny: (1) Dart's true faithful value is not "slow," it is **zero** — `_performReposition`'s assigned velocities (`dexterity/2 = 4.0`, `/2.5 = 3.2`, `/3 = 2.67` px/s; `smart_bot_ai.dart:364-377`) are all below `GameConfig.stopThreshold = 5.0`, which `game_character.dart:474-477` zeroes every tick, so **Dart's bots do not walk at all** — this layer is dead code, not slow code. (2) The magnitude was justified via `ATTACK_APPROACH_SPEED`, which the ledger itself later proved is dead code in the shipped Godot bot too (`bot_controller.gd`'s own comment: `melee_reach` tops out at ~84px, always below `optimal_range × 0.7 = 105px`, so the `attack` action's approach branch never fires — only retreat does). (3) The claimed "preserved 4:3 ratio" is not what shipped: Dart's dead-code ratio was 4.0:3.2 ≈ 4:3, but the *live* Godot pair is 40 (dead) : 30 (live) against a Dart baseline of 0:0 — there is no ratio to preserve, since the Dart source is inert. (4) The only constant that actually executes, `ATTACK_RETREAT_SPEED = 30.0`, makes the bot flee **~11× faster** than Dart's already-dead 2.67 px/s value, the opposite of the stated goal of moderation. **Correct framing:** Dart's bot locomotion layer is dead code killed by `stopThreshold`; the entire Godot bot attack-state movement model is purpose-built, not ported, and 40/30 are retained as reasonable purpose-built values, not as a preserved ratio. | Bot attack-state shuffle feels faster/slower than the original; one constant pair to retune — but this is a place "port faithfully" was knowingly broken and the human may want to overturn it. |
| R17 | Widened one stamina-bar timing test's tolerance (0.01 → 1.0), justified by a proven, deterministic off-by-one in GUT's own frame-waiter (traced to GUT source, reproduced exactly 3×). | None — the widened assertion is measuring real deterministic engine behavior, not a bug. A tighter fix exists but wasn't required (see §4 item 10). |
| R18 | **REVERSED by the F1 fix wave (this document's own fix pass).** The brief invented a 3-tier (green/orange/red) HUD health-bar color scheme, sourced from the stale `AGENTS.md`, that does not exist in the real Dart HUD (`hud.dart:63`, which is 2-tier — green above 0.3, orange at/below, no red — and never uses its own declared-but-dead `lowHealthThreshold=0.2` constant, `game_config.dart:30`). The original ruling kept the 3-tier scheme; that ruling is now **overturned**: `hud.gd` reverted to the real 2-tier scheme at the 0.3 threshold, the red branch removed, and the false "matches the Dart HUD (green -> orange -> red)" comment corrected. The one test guarding this (`test_health_bar_turns_red_at_low_health`) also could not fail — red `Color(1.0,0.2,0.2)` and orange `Color(1.0,0.6,0.1)` both have `r≈1.0` — and has been rewritten (`test_health_bar_turns_orange_below_threshold`) to assert both `r` and `g` channels, verified to fail when health is above threshold and pass when below. | Was: health bar showed red below 20% where Dart stayed orange, and green→orange also moved 20 percentage points earlier (0.3→0.5) than Dart, undisclosed. Now: fixed, matches Dart exactly. |
| R19 | `class_name VirtualJoystick` collides with a native Godot 4.7 class (confirmed via `ClassDB.class_exists` in a fresh, unrelated project, ruling out a stale cache); renamed to `GameVirtualJoystick`. | Unjustified rename churn if the collision were false — confirmed real, so no cost. |
| R20 | An implementer hand-fixed a real collision bug by editing generated map geometry — edits that don't survive regeneration. Root cause traced to the plan omitting three Dart collision-tolerance constants; reverted the map edits and ported the missing `floor_snap_length=10.0` to the character body instead. | Characters snap to floors from up to 10px, matching Dart; one exported value to retune if it feels sticky. |
| R21 | (Finding tied to R20, not independently reversible.) `floor_snap_length` fixes descending onto jitter but not climbing it; the ground tier's 1–11px seams are still impassable walls. Routed around via spawn placement, not fixed. | N/A — accepted, unfixed, documented limitation (§4 item 4). Will resurface. |
| R22 | `convert_map.py`'s blind overwrite of `level_1.tscn` is documented design, not a defect, but is a live footgun; not mitigated now to avoid scope creep. | N/A — deferred by design (§4 item 5). |

### 5.1 Four knowing divergences from "port faithfully" — disclosed with equal prominence

An earlier draft of this report disclosed only two divergences (R16, R18). A subsequent review
found **two more that were not disclosed at all**, one of which is larger and more behaviorally
significant than either originally-flagged item. All four are listed here together, at equal
weight:

1. **Bot attack-state shuffle speed (R16, table above).** Live divergence, kept. `40/30 px/s`
   approach/retreat constants during the "attack" bot action are purpose-built, not ported — see
   the corrected R16 reasoning above. Only the retreat branch (30 px/s) is currently reachable
   under Knight + Aggressive.

2. **General bot locomotion is purpose-built, not ported — not previously disclosed, and larger
   than R16.** This is a separate mechanism from R16: it covers the bot's non-attack `"approach"`
   / `"retreat"` actions, which call `Character.move_horizontal()` → `MovementProfile.resolve_speed()`.
   Dart's `_performReposition` (`smart_bot_ai.dart:364-377`) assigns `dexterity/2 = 4.0 px/s` for
   Knight, but `game_character.dart:474-477` then multiplies by `groundFriction = 0.85` and zeroes
   anything below `stopThreshold = 5.0` — **every velocity `_performReposition` can assign (4.0,
   3.2, 2.67 px/s for Knight) is below that threshold, so Dart's bots do not walk via this path at
   all.** The Godot bot instead runs approach/retreat at **640 px/s** (`bot_controller.gd:94,97` →
   `move_horizontal(±1.0)`, whose input magnitude `1.0` exceeds `MovementProfile.run_threshold =
   0.8`, selecting the 160×-multiplier run speed: `base_speed(8) × 160 = 640`). No test pins this
   number; `test_attack_state_shuffle_speed_is_bounded` explicitly excludes the non-attack
   locomotion path. **This is a larger and more behaviorally significant divergence than R16 or
   R18** — a bot that closes distance at 640 px/s reads completely differently than one whose Dart
   equivalent cannot move — and it was not in the original two-item disclosure. Not fixed by this
   pass: fixing it would mean editing `bot_controller.gd`/`character.gd`, which is out of scope for
   a documentation-only fix wave and is explicitly listed among Phase 2's follow-ups (§8).

3. **Character collision width silently halved, 240 → 120 — not previously disclosed.**
   `game_config.dart:26` sets `characterWidth = 240.0`; the Godot character body ships at half
   that, 120px wide (`character.tscn`, `size = Vector2(120, 240)`; height was ported correctly).
   The plan justified this by claiming a 240-wide box "cannot land on a 120-wide platform" — **that
   premise is false**: Dart's own landing test (`game_character.dart:484`,
   `if (proposed.x+size.x/2<=pL || proposed.x-size.x/2>=pR) continue;`) requires only *any*
   x-overlap between character and platform spans, not full containment, so a 240-wide Dart
   character lands fine while hanging off either edge. This changes ledge tolerance (a
   120-wide Godot character can stand on much less of a platform than the 240-wide Dart original
   could) and the body's visual/physical scale relative to the 60px melee reach. It also
   undermines R20's own reasoning, which leaned on "same 240px character" — true of height, false
   of width. Not fixed by this pass: fixing it means editing `character.tscn`, out of scope here
   and listed for Phase 2 (§8).

4. **HUD health-bar color scheme, R18 (table above).** No longer a live divergence — **fixed** by
   this fix wave (see the R18 row above and F1 in the accompanying fix-report). Kept here for
   completeness of the disclosure history, since it was one of the original two flagged items.

Items 2 and 3 are new findings surfaced during this fix wave's review, not part of the original
Task 1–18 execution; they are disclosed here rather than silently absorbed because both directly
affect how credible the bot opponent and character collision feel, which bears on the still-open
Section 3 play-test.

---

## 6. Surprises the design did not anticipate

- The Dart-vs-Godot branch mismatch (R11): the plan was authored reading `3d_last`, the worktree
  is based on `origin/main`. Every cited constant turned out identical across both branches
  except one provenance citation — but the process gap (planning against a different tree than
  the one being built) was real and only caught by an after-the-fact audit.
- Godot 4.7's headless `class_name` registration requiring a prior editor pass (R8) was not
  anticipated anywhere in the spec and cost real implementer time on the first two tasks that
  hit it, before being documented and carried forward.
- GUT 9.6's hard parse error on `:=` through an unsafe member access (R12), and its `wait_frames`
  off-by-one (R17), are both framework quirks nothing in the spec or plan predicted.
- The AI movement invariant (R16, §5.1) — that Dart's bot locomotion layer (both the attack-state
  shuffle and the general approach/retreat movement) is dead code, permanently zeroed by
  `stopThreshold` before it can move a melee bot at all — is a genuine design-level surprise, not
  an implementation bug, and a bigger one than the original report disclosed: it doesn't just
  affect the attack-state shuffle (R16's original scope), it means the *entire* Godot bot movement
  model (§5.1 item 2, 640 px/s approach/retreat) is purpose-built with no faithful Dart baseline to
  port from. "Port faithfully" as a blanket rule (spec §7) has at least one real, load-bearing
  exception baked into the physics/AI interaction, not just an isolated instance.
- Test-passing-while-broken (§1.4, the frozen enemy) is the sharpest surprise: it is direct,
  in-repo evidence that this project's own automated coverage — 121/121, mutation-tested
  authority model and all — was insufficient on its own to catch a gameplay-breaking bug. Only
  independent physics probing (by a reviewer, not the suite) caught it. This bears directly on
  how much weight the "GO" recommendation below can put on the green suite alone.

---

## 7. Recommendation

Splitting the objectively-answerable parts from the one part that isn't, as instructed.

### 7.1 Technical foundation: **GO**

- 121/121 tests pass, exit 0, reproducibly (multiple 3× reruns logged in the ledger with
  identical assert counts — no flakiness observed anywhere in 18 tasks).
- Project opens cleanly headless with zero errors.
- All four architectural boundaries the plan promised are real and independently checked in this
  report: pure logic layer (`scripts/` node-free), no direct device reads, frozen Dart reference,
  frozen shared assets.
- The two riskiest structural bets both held under adversarial verification, not just green
  tests:
  - **MP-authority model (decision 6)** — proven by *mutation testing*: a reviewer removed the
    `is_authority()` guard from `apply_damage()` and confirmed the authority test goes red before
    restoring it. This is the strongest evidence in the whole run and it's exactly the thing
    Phase 1 existed to de-risk before three more characters copy the pattern.
  - **Input indirection (decision 4)** — touch support (Task 16, extended by the F5 fix wave) was
    added with a `git diff` touching *zero* lines in `character.gd`, `player_controller.gd`,
    `bot_controller.gd`, `bot_decision.gd`, `world_snapshot.gd`, or any scene under
    `godot/scenes/`. That is the concrete proof gamepad/touch can be deleted/added without
    gameplay code ever knowing, which is the entire justification for deleting `modules/gamepad`'s
    789 LOC. This is an **architectural** claim, not a completeness one — see the precise scope
    below.
    **Completeness, corrected:** as originally shipped (Task 16), `touch_controls.tscn` contained
    only the movement joystick — **2 of 8** InputMap actions (`move_left`, `move_right`) were
    reachable from touch; `attack`, `jump`, and `block` were not, despite
    `GameVirtualJoystick.tap()`/`release()` already existing for exactly this purpose with zero
    callers, and a docstring claiming (falsely, at the time) that on-screen buttons used them. The
    F5 fix wave added `AttackButton`/`JumpButton`/`BlockButton` to `touch_controls.tscn`, wired to
    `tap()`/`release()`, purely via `InputMap` — no gameplay file changed. Touch now reaches **5 of
    8** actions (`move_left`, `move_right`, `jump`, `attack`, `block`). `dodge`, `crouch`, and
    `pause` are still not reachable from touch — `crouch` and `pause` are unimplemented for *any*
    input device in this slice, and `dodge` is scored by the bot's decision logic but has no
    player-input path yet (§2.4), so touch is not uniquely behind those three.

### 7.2 Do the tests actually verify behaviour: **GO, with two caveats**

Discrimination-proof discipline was genuinely enforced on every behavioral fix (Task 11's combo
bug, Task 14's bot-movement bug — both required a reviewer to reproduce red-before/green-after,
not just trust the claim), and the authority mutation test above is the strongest single piece of
evidence in the whole run.

**Caveat 1 (§1.4, frozen enemy):** a fully green suite does not, by itself, guarantee the game is
playable — that bug was caught by a human-style physics probe, not by the suite. The suite is
necessary and was executed with real discipline; it is demonstrably not sufficient alone.

**Caveat 2, downgraded rather than deleted (golden fixture):** this report previously led with
"96/96 combat records matched to 1e-6" as evidence of rigor. That claim is **real but weaker than
presented**: `tools/dart_fixtures/bin/capture.dart` does **not** call
`CombatSystem.processAttack()` — it re-implements the damage formula itself at lines 20–33 and
imports only two constants from `game_config.dart`. Spec §8 required importing the frozen `engine`
package; this fixture does not. So the 96/96 match proves that **two independent
hand-transcriptions of the same formula agree with each other** — real value (it would catch a
transcription typo in either the Godot or the fixture-generation side) but it structurally
**cannot** catch a misreading of the Dart source that gets propagated into both transcriptions
identically, because neither transcription is the source it claims to verify against.

**Concrete proof this blind spot is real, not hypothetical:** Dart's `_canBlock`
(`combat_system.dart:250-258`) requires the blocker to be **facing the attacker** *and* have
**stamina ≥ `GameConfig.blockStaminaDrain` (10)** before a block reduces damage. The Godot port
(`character.gd:263`, via `Combat.calc_damage(stats.attack_damage, combo, other.is_blocking(),
false)`) passes bare `other.is_blocking()` — neither the facing check nor the stamina check is
present. The golden fixture cannot see this gap: `calcDamage()`'s `blocking` parameter is a free
boolean input in both the Dart capture script and the Godot test, so a blocker facing the wrong
way, or out of stamina, still gets the 70% reduction in Godot when Dart would deny it. **This is
now added to the deferred/Phase-2 list (§4, new item 12).**

Net: the suite's discrimination discipline is real and demonstrated; the golden fixture's
exactness claim should be read as "internally consistent," not "verified against the frozen
engine," and is downgraded accordingly rather than removed — it still catches a real class of
transcription error.

### 7.3 Did the architecture survive contact: **GO**

Every named consolidation (gamepad deletion, 5-platform-classes → 1 scene, collision system →
engine `Area2D`s, pooling → direct instantiate) held up under real implementation pressure across
18 tasks, with measured LOC reductions of 94–100% where they apply. The one unproven claim is
the platform tiling's *visual* correctness (§4 item 1) — code-complete, never rendered and
observed.

### 7.4 Overall feel verdict: **UNAVAILABLE**

Per spec §8, manual play-test is "Layer 4" — explicitly not automatable and the reason the
vertical slice exists. That layer has not been executed. Section 3 above is the template; it
must be filled in by a human before any overall go/no-go can be issued. Known live risks sit
directly inside that blank: whether R16's invented bot-shuffle speed and the general 640 px/s
bot approach/retreat speed (§5.1 items 1–2) read as credible combat, whether the 120px-wide
character collision box (§5.1 item 3) feels right against 60–84px melee reach, and whether R14's
never-tested gamepad deadzone feels right on real hardware.

### 7.5 Composite recommendation

**GO on the technical foundation and architecture; the overall Phase 2 decision is BLOCKED
pending the human play-test in Section 3.** If the human's answers to Q1–Q6 come back
substantially positive, the three still-live flagged divergences (§5.1: R16's attack-state
shuffle, the general bot-locomotion speed, and the 240→120 character width — R18 is already
resolved) should be explicitly ratified or overturned before Phase 2 copies their pattern across
three more characters and six more personalities. If the play-test surfaces a feel problem,
address it before Phase 2 begins — per the spec's own logic, this is the cheapest point in the
whole migration to find that out.

---

## 8. What Phase 2's plan must account for

Derived from the ledger, not from imagination:

1. **Resolve or explicitly accept §4 item 4 (ground-tier climbing).** Phase 2 adds no new levels
   per se, but Phase 4 (map generator) will produce arbitrary geometry — the jitter problem needs
   a real fix (normalize source data, or step-up handling in `Character`) before generated levels
   can be trusted to be traversable, not just spawn-routed-around.
2. **Visually verify `Platform.tscn` tiling (§4 item 1) at the first opportunity** — ideally
   during the human play-test itself, or as the first thing checked when Phase 2/4 authors a
   platform larger than one texture tile. The 94% LOC reduction claim's core justification rests
   on this being true and it has never been observed.
3. **Decide on the three still-live divergences before they propagate (§5.1).** Phase 2 adds 3
   characters and 6 personalities that will copy `bot_controller.gd`'s attack-movement pattern
   (R16, 40/30 px/s), its general approach/retreat pattern (640 px/s, §5.1 item 2), and
   `character.tscn`'s 120px collision width (§5.1 item 3) wholesale. R18 (HUD color tiers) is
   already fixed and needs no decision. Ratify or overturn the remaining three now if the human
   disagrees — it's a handful of constants today, a wider revert across four characters later.
4. **`stop_block()`'s missing authority guard (§4 item 2)** should be closed before or during
   Phase 6 multiplayer work, when `_is_blocking` desync becomes an actual reachable bug rather
   than a theoretical one.
5. **`convert_map.py`'s overwrite footgun (§4 item 5) — fixed by this fix wave.** The script now
   requires an explicit map name (no default, refuses with usage text if omitted) and refuses to
   overwrite a destination `.tscn` containing any node beyond a Platform instance, `PlayerSpawn`,
   or scaffolding, unless `--force` is passed. Verified against `level_1.tscn`'s Player/Enemy/
   UILayer/HUD/TouchControls assembly (refuses without `--force`, proceeds with it). No action
   needed in Phase 2 beyond keeping this guard in mind when adding new node kinds to a level scene
   that the guard doesn't yet recognize as "expected."
6. **Re-check bot tie-breaking and dead movement branches (§4 items 7–8) against real personality
   data** the moment Berserker (`a=1.0, c=0.0`) or any character with `melee_reach` above 105px
   is authored — both were only ever validated against Knight + Aggressive.
7. **The melee candidate-set gap (§4 item 3)** should be revisited once Phase 2/3 puts multiple
   enemies in reach simultaneously — untestable meaningfully with the current one-attacker/
   one-target slice.
8. **Class-name collisions with Godot natives (R19)** are now a documented risk class, not a
   one-off — check every new `class_name` against `ClassDB` before authoring it in Phase 2+.
9. **§2.3's AI/HUD LOC reduction is partly "not yet built," not pure consolidation** — Phase 2's
   plan should budget real authoring time for the other 6 personality `.tres` files and 3
   character stat/movement resources, even though the supporting GDScript is already generic and
   needs no further code changes to accept them.
10. **Test-layer balance** (15 unit scripts vs. 2 integration scripts) worked for this slice but
    caught the frozen-enemy bug only via manual reviewer probing, not via the integration layer
    itself. Phase 2 should consider whether integration coverage needs to grow faster than unit
    coverage as more scenes compose, given the demonstrated blind spot in §1.4.

---

## Appendix: raw commands run for this report

```
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gdir=res://test -gexit   # exit 0, 121/121
godot --headless --path godot --quit                                               # exit 0, clean
grep -rnE '\bNode\b|get_node|\$|preload\(' godot/scripts/                          # no matches
grep -rnE 'is_key_pressed|get_joy_|InputEventKey|joy_connection' godot/scenes/ godot/ui/virtual_joystick.gd  # no matches
git diff --stat main -- lib/ modules/ assets/                                      # empty
find godot -name '*.gd' -not -path '*/addons/*' | xargs wc -l                      # 1991 total
find godot \( -name '*.tscn' -o -name '*.tres' \) -not -path '*/addons/*' | xargs wc -l  # 465 total
wc -l modules/gamepad/**/*.dart                                                    # 789
wc -l modules/engine/lib/src/components/platform/{tiled_platform,enhanced_platform,tiled_ground_component,platform_factory,game_platform}.dart  # 875
wc -l modules/engine/lib/src/utils/sprite_utils.dart                               # 96
wc -l modules/engine/lib/src/system/collision_system.dart                          # 122
wc -l modules/engine/lib/src/manager/pool_manager.dart                             # 139
```
