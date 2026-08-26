# Godot Migration Phase 0 + Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a Godot 4.7 project and build a playable vertical slice — Knight vs. one aggressive bot on `level_1`, with combat, HUD, and all three input devices — sufficient to make a go/no-go call on the full migration.

**Architecture:** Scene-first Godot project under `godot/`. Pure game logic (damage math, bot decisions) lives in `scripts/` with no node dependencies so GUT can test it headless. Balance data lives in `.tres` Resources. Character state is owned and mutated by the character node under an `is_multiplayer_authority()` guard, so `MultiplayerSynchronizer` can replicate it later without restructuring.

**Tech Stack:** Godot 4.7.1 (installed, on PATH), GDScript, GUT 9.6.0, Dart 3.10.4 (fixture capture only, then discarded).

**Spec:** `docs/superpowers/specs/2026-08-26-flutter-to-godot-migration-design.md`

## Global Constraints

- **Godot 4.7.1** — verified installed: `godot --version` → `4.7.1.stable.official.a13da4feb`
- **GUT 9.6.0** — the only release supporting Godot ≥ 4.6 (`godot_min: 4.6`, `godot_max: 999`)
- **GDScript only.** No C#.
- **Never read an input device directly.** All input goes through `InputMap` actions. A single `Input.is_key_pressed()` or joypad index in gameplay code is a review rejection.
- **Never mutate another node's health/stamina/combo.** A node mutates only its own, and only under `if not is_multiplayer_authority(): return`.
- **`godot/scripts/` must not reference any node type.** No `Node`, `get_node`, `$`, `preload` of scenes. It is pure data-in/data-out so GUT can test it without a scene tree. Violation is a review rejection.
- **Base resolution 1280×720**, `stretch_mode = canvas_items`, `aspect = keep`, landscape.
- **Do not modify anything under `lib/` or `modules/`.** The Dart tree is frozen reference.
- **Port balance values verbatim.** Every constant in this plan was read from the Dart source. Do not "improve" them.

### Balance constants (read from Dart source — copy verbatim)

| Constant | Value | Source |
|---|---|---|
| gravity | `1000.0` | `game_config.dart` |
| max fall speed | `800.0` | `game_config.dart` |
| jump velocity | `-300.0` | `game_config.dart` |
| jump stamina cost | `20.0` | `game_config.dart` |
| dodge duration / cooldown / cost | `0.3` / `2.0` / `20.0` | `game_config.dart` |
| attack commit time | `0.3` | `game_config.dart` |
| attack cooldown (ground / air) | `0.5` / `1.0` | `game_character.dart:567` |
| attack stamina cost (ground / air) | `15` / `20` | `game_character.dart:567` |
| attack minimum stamina | `15` | `game_character.dart:566` |
| stamina regen | `+15.0/s` | `game_character.dart:529` |
| block drain (continuous) | `-15.0/s` | `game_character.dart:536` |
| block stamina drain (per blocked hit) | `10.0` | `game_config.dart` + `combat_system.dart` |
| block minimum stamina | `10` | `game_character.dart:668` |
| block damage multiplier | `0.3` (70% reduction) | `combat_system.dart` |
| combo damage multiplier | `+0.2` per combo | `game_config.dart` `BalanceConfig` |
| combo window | `1.5` | `game_config.dart` |
| critical multiplier / chance | `2.0` / `0.1` | `game_config.dart` `BalanceConfig` |
| character size | `240.0 × 240.0` | `game_config.dart` |
| base health / stamina | `100.0` / `100.0` | `game_config.dart` |
| landing recovery / hard-landing threshold | `0.25` / `400.0` | `game_config.dart` |
| camera zoom | `1.2` | `game_config.dart` |

**Knight** (`knight.dart`): power 15, magic 5, dexterity 8, intelligence 7, attackDamage 15, attackRange 2.0, health 100.
Derived speed: `baseSpeed = dexterity / 2 = 4.0`; walk `4.0 × 100 = 400 px/s`; run `4.0 × 160 = 640 px/s`; run threshold input magnitude `> 0.8` (`knight_movement_strategy.dart`, `game_character.dart:260`).
Melee reach: `attackRange × 30 × (1 + combo × 0.1)` = `60 px` at combo 0 (`knight.dart`).

**Aggressive personality** (`smart_bot_ai.dart:41-48`): aggression `0.9`, caution `0.2`, staminaReserve `20`, optimalRange `150`, retreatThreshold `20`, reactionTime `0.15`.

**Animation step times** (`knight_movement_strategy.dart`): idle `0.20`, walk `0.13`, run `0.09`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `godot/project.godot` | Project settings, autoloads, InputMap |
| `godot/addons/gut/` | GUT 9.6.0, vendored |
| `godot/scripts/combat.gd` | Pure damage math. No nodes. |
| `godot/scripts/stamina.gd` | Pure stamina cost/regen math. No nodes. |
| `godot/scripts/bot_decision.gd` | Pure bot action scoring. No nodes. |
| `godot/scripts/world_snapshot.gd` | Plain data struct passed to `bot_decision.gd` |
| `godot/resources/character_stats.gd` | `Resource` class: per-class stats |
| `godot/resources/movement_profile.gd` | `Resource` class: speeds + anim step times |
| `godot/resources/bot_personality.gd` | `Resource` class: AI personality params |
| `godot/resources/knight_stats.tres` | Knight values |
| `godot/resources/knight_movement.tres` | Knight speeds |
| `godot/resources/personalities/aggressive.tres` | Aggressive params |
| `godot/scenes/character/character.gd` | `CharacterBody2D` — owns health/stamina/combo |
| `godot/scenes/character/character.tscn` | Base character scene |
| `godot/scenes/character/state_machine.gd` | Animation/action state machine |
| `godot/scenes/character/bot_controller.gd` | Throttles + applies `bot_decision.gd` output |
| `godot/scenes/platform/platform.tscn` | `StaticBody2D` + tiling `Sprite2D` |
| `godot/scenes/maps/level_1.tscn` | Converted from `assets/maps/level_1.json` |
| `godot/ui/hud.tscn` / `hud.gd` | Health, stamina, combo |
| `godot/ui/virtual_joystick.gd` | Touch → `InputEventAction` |
| `godot/test/unit/` | GUT suites |
| `godot/test/fixtures/` | Golden JSON from Dart |
| `tools/dart_fixtures/bin/capture.dart` | **Throwaway** Dart fixture generator |
| `tools/convert_map.py` | **One-off** `level_1.json` → `.tscn` |
| `.github/workflows/godot-tests.yml` | Headless GUT in CI |

---

## Phase 0 — Foundation

### Task 1: Godot project skeleton with GUT and green CI

**Files:**
- Create: `godot/project.godot`, `godot/.gitignore`, `godot/test/unit/test_smoke.gd`, `.github/workflows/godot-tests.yml`
- Vendor: `godot/addons/gut/`

**Interfaces:**
- Consumes: nothing
- Produces: a runnable Godot project at `godot/`; `godot --headless -s addons/gut/gut_cmdln.gd --path godot -gdir=res://test -gexit` exits 0

- [ ] **Step 1: Create the project file**

Create `godot/project.godot`:

```ini
config_version=5

[application]
config/name="NoMercy"
run/main_scene="res://scenes/maps/level_1.tscn"
config/features=PackedStringArray("4.7", "GDScript")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/handheld/orientation=1

[editor_plugins]
enabled=PackedStringArray("res://addons/gut/plugin.cfg")
```

`orientation=1` is landscape. `run/main_scene` points at a scene that does not exist yet — Task 8 creates it. Godot tolerates this until you press Play.

- [ ] **Step 2: Add the gitignore**

Create `godot/.gitignore`:

```
.godot/
export_presets.cfg
*.translation
```

- [ ] **Step 3: Vendor GUT 9.6.0**

```bash
cd /c/Users/dev/Projects/nomercy
git clone --depth 1 --branch v9.6.0 https://github.com/bitwes/gut.git /tmp/gut
mkdir -p godot/addons
cp -r /tmp/gut/addons/gut godot/addons/gut
rm -rf /tmp/gut
ls godot/addons/gut/gut_cmdln.gd
```

Expected: the path prints. If the `v9.6.0` tag does not exist, list tags with `git ls-remote --tags https://github.com/bitwes/gut.git | grep 9.6` and use the exact tag name. Do **not** substitute a 9.5.x release — it caps at Godot 4.5.

- [ ] **Step 4: Write a smoke test**

Create `godot/test/unit/test_smoke.gd`:

```gdscript
extends GutTest

func test_gut_runs():
	assert_true(true, "GUT is wired up")

func test_godot_version_is_4_7_or_later():
	var info := Engine.get_version_info()
	assert_true(
		info.major > 4 or (info.major == 4 and info.minor >= 7),
		"Expected Godot >= 4.7, got %d.%d" % [info.major, info.minor]
	)
```

- [ ] **Step 5: Run the suite**

```bash
cd /c/Users/dev/Projects/nomercy
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gdir=res://test -gexit
```

Expected: `2 passing`, exit code 0. Confirm with `echo $?` → `0`.

If Godot reports the addon is not imported, run `godot --headless --path godot --import` once first, then re-run.

- [ ] **Step 6: Add CI**

Create `.github/workflows/godot-tests.yml`:

```yaml
name: Godot Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  gut:
    runs-on: ubuntu-latest
    container:
      image: barichello/godot-ci:4.7.1
    steps:
      - uses: actions/checkout@v4
      - name: Import project
        run: godot --headless --path godot --import
      - name: Run GUT
        run: godot --headless -s addons/gut/gut_cmdln.gd --path godot -gdir=res://test -gexit
```

If `barichello/godot-ci:4.7.1` is not published, use the closest available 4.7 tag; check with `docker manifest inspect barichello/godot-ci:4.7.1`. The image tag is the only thing that needs to change.

- [ ] **Step 7: Commit**

```bash
git add godot/ .github/workflows/godot-tests.yml
git commit -m "feat(godot): project skeleton with GUT 9.6 and headless CI"
```

---

### Task 2: InputMap actions for keyboard, gamepad, and touch

**Files:**
- Modify: `godot/project.godot` (append `[input]` section)
- Test: `godot/test/unit/test_input_map.gd`

**Interfaces:**
- Consumes: Task 1's `project.godot`
- Produces: eight actions — `move_left`, `move_right`, `jump`, `attack`, `block`, `dodge`, `crouch`, `pause` — each bound to at least one key and one joypad input

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_input_map.gd`:

```gdscript
extends GutTest

const REQUIRED_ACTIONS := [
	"move_left", "move_right", "jump", "attack",
	"block", "dodge", "crouch", "pause",
]

func test_all_gameplay_actions_exist():
	for action in REQUIRED_ACTIONS:
		assert_true(
			InputMap.has_action(action),
			"Missing InputMap action: %s" % action
		)

func test_every_action_has_a_keyboard_and_a_joypad_binding():
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var has_key := false
		var has_pad := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				has_key = true
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		assert_true(has_key, "%s has no keyboard binding" % action)
		assert_true(has_pad, "%s has no joypad binding" % action)
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_input_map.gd -gexit
```

Expected: FAIL — "Missing InputMap action: move_left".

- [ ] **Step 3: Append the input bindings**

Append to `godot/project.godot`:

```ini
[input]

move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":65,"pressed":true)
, Object(InputEventJoypadMotion,"axis":0,"axis_value":-1.0)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":68,"pressed":true)
, Object(InputEventJoypadMotion,"axis":0,"axis_value":1.0)
]
}
jump={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":32,"pressed":true)
, Object(InputEventJoypadButton,"button_index":0,"pressed":true)
]
}
attack={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":74,"pressed":true)
, Object(InputEventJoypadButton,"button_index":2,"pressed":true)
]
}
block={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":75,"pressed":true)
, Object(InputEventJoypadButton,"button_index":9,"pressed":true)
]
}
dodge={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":76,"pressed":true)
, Object(InputEventJoypadButton,"button_index":1,"pressed":true)
]
}
crouch={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":83,"pressed":true)
, Object(InputEventJoypadMotion,"axis":1,"axis_value":1.0)
]
}
pause={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":4194305,"pressed":true)
, Object(InputEventJoypadButton,"button_index":6,"pressed":true)
]
}
```

Keycodes: 65=A, 68=D, 32=Space, 74=J, 75=K, 76=L, 83=S, 4194305=Escape. Joypad buttons follow Godot's `JoyButton` enum: 0=A, 1=B, 2=X, 6=Start, 9=Left Shoulder.

**Hand-editing `project.godot` is fragile.** If Godot rewrites or rejects this block, open the project in the editor, add the actions through Project Settings → Input Map, and let the editor serialize it. The test is the contract; the authoring route does not matter.

- [ ] **Step 4: Run the test and confirm it passes**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_input_map.gd -gexit
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add godot/project.godot godot/test/unit/test_input_map.gd
git commit -m "feat(godot): InputMap actions bound to keyboard and gamepad"
```

---

### Task 3: Capture golden fixtures from the Dart tree ⚠️ ORDERING-CRITICAL

**Files:**
- Create: `tools/dart_fixtures/pubspec.yaml`, `tools/dart_fixtures/bin/capture.dart`
- Create (generated): `godot/test/fixtures/combat_damage.json`

**Interfaces:**
- Consumes: the frozen `modules/engine` and `modules/core` Dart packages
- Produces: `combat_damage.json` — an array of `{base, combo, blocking, critical, expected}` records consumed by Task 5

> **This is the only task in the migration that cannot be deferred.** It requires a runnable Dart tree. Everything else can slip; this cannot.

> **This harness is throwaway.** It is deleted at Phase 7 cutover. Do not add it to CI, do not maintain it, do not import it from anywhere.

- [ ] **Step 1: Create the harness package**

Create `tools/dart_fixtures/pubspec.yaml`:

```yaml
name: dart_fixtures
description: THROWAWAY - captures golden fixtures for the Godot port. Delete at cutover.
publish_to: 'none'

environment:
  sdk: ^3.10.4

dependencies:
  core:
    path: ../../modules/core
```

Only `core` is needed — `BalanceConfig` and `GameConfig` live there, and the damage formula is reimplemented below rather than imported, because `CombatSystem.processAttack` is entangled with `GameCharacter` and the EventBus and cannot be called headlessly.

- [ ] **Step 2: Write the capture script**

Create `tools/dart_fixtures/bin/capture.dart`:

```dart
// THROWAWAY. Captures golden fixtures for the Godot port. Delete at cutover.
//
// Mirrors the damage pipeline in
// modules/engine/lib/src/system/combat_system.dart processAttack(), with the
// critical-hit RNG lifted out into an explicit parameter so the result is
// deterministic and portable across engines.
//
//   damage = base
//   if critical: damage *= BalanceConfig.criticalHitMultiplier   (2.0)
//   if combo > 0: damage *= 1.0 + combo * BalanceConfig.comboDamageMultiplier  (0.2)
//   if blocking: damage *= 0.3
//
// Order matters: critical is applied before combo, combo before block.

import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';

double calcDamage({
  required double base,
  required int combo,
  required bool blocking,
  required bool critical,
}) {
  var damage = base;
  if (critical) damage *= BalanceConfig.criticalHitMultiplier;
  if (combo > 0) {
    damage *= 1.0 + combo * BalanceConfig.comboDamageMultiplier;
  }
  if (blocking) damage *= 0.3;
  return damage;
}

void main() {
  // attackDamage per class, from the *Stats classes in
  // modules/engine/lib/src/components/character/
  const baseByClass = <String, double>{
    'knight': 15.0,
    'thief': 10.0,
    'wizard': 20.0,
    'trader': 12.0,
  };

  final records = <Map<String, dynamic>>[];

  for (final entry in baseByClass.entries) {
    for (var combo = 0; combo <= 5; combo++) {
      for (final blocking in [false, true]) {
        for (final critical in [false, true]) {
          records.add({
            'character': entry.key,
            'base': entry.value,
            'combo': combo,
            'blocking': blocking,
            'critical': critical,
            'expected': calcDamage(
              base: entry.value,
              combo: combo,
              blocking: blocking,
              critical: critical,
            ),
          });
        }
      }
    }
  }

  final out = File('../../godot/test/fixtures/combat_damage.json');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(records),
  );

  stdout.writeln('Wrote ${records.length} records to ${out.path}');
}
```

- [ ] **Step 3: Run it**

```bash
cd /c/Users/dev/Projects/nomercy/tools/dart_fixtures
dart pub get
dart run bin/capture.dart
```

Expected: `Wrote 96 records to ../../godot/test/fixtures/combat_damage.json` (4 classes × 6 combo levels × 2 blocking × 2 critical).

- [ ] **Step 4: Verify the fixture by hand**

```bash
cd /c/Users/dev/Projects/nomercy
python3 -c "
import json
d = json.load(open('godot/test/fixtures/combat_damage.json'))
print('records:', len(d))
for r in d:
    if r['character']=='knight' and r['combo']==3 and not r['blocking'] and not r['critical']:
        print('knight combo3 unblocked:', r['expected'])
    if r['character']=='knight' and r['combo']==0 and r['blocking'] and not r['critical']:
        print('knight combo0 blocked:', r['expected'])
"
```

Expected exactly:
- `records: 96`
- `knight combo3 unblocked: 24.0` — `15 × (1 + 3×0.2) = 15 × 1.6`
- `knight combo0 blocked: 4.5` — `15 × 0.3`

If these do not match, **stop** — the formula transcription is wrong and every downstream task inherits the error.

- [ ] **Step 5: Commit**

```bash
git add tools/dart_fixtures godot/test/fixtures/combat_damage.json
git commit -m "test(godot): capture combat damage golden fixtures from Dart

Throwaway harness; deleted at Phase 7 cutover."
```

---

### Task 4: Import assets and build the Knight SpriteFrames

**Files:**
- Create: `godot/resources/knight_frames.tres`
- Test: `godot/test/unit/test_knight_frames.gd`

**Interfaces:**
- Consumes: `assets/images/*.png` (existing, unchanged)
- Produces: `res://resources/knight_frames.tres` with animations `idle`, `walk`, `run`, `attack`, `jump`, `landing`

**Background — read this before starting.** There are no sprite sheets. Every animation is either a single PNG or an explicit list of PNGs (spec §12). The Knight's walk is 6 frames drawn from 3 unique files, in this exact order (`asset_paths.dart`):

1. `warrior_walk_resized_left_leg_front.png`
2. `warrior_walk_resized_legs_together_left_knee_front.png`
3. `warrior_walk_resized_right_leg_front.png`
4. `warrior_walk_resized_left_leg_front.png`
5. `warrior_walk_resized_legs_together_left_knee_front.png`
6. `warrior_walk_resized_left_leg_front.png`

`run` uses the identical 6-frame list; only the step time differs (0.09 vs 0.13).

- [ ] **Step 1: Point Godot at the shared assets**

Godot cannot reference files outside its project root. Create a symlink so `assets/` is visible as `res://assets/`:

```bash
cd /c/Users/dev/Projects/nomercy/godot
cmd //c "mklink /D assets ..\\assets"
ls assets/images/knight_idle.png
```

Expected: the path prints. If `mklink` fails (it needs Developer Mode or an elevated shell on Windows), fall back to a Godot-side copy and add it to `godot/.gitignore`:

```bash
cp -r ../assets ./assets && echo "assets/" >> .gitignore
```

Either way, `res://assets/images/knight_idle.png` must resolve. Add `assets` to `godot/.gitignore` in **both** cases — the files are already tracked at the repo root and must not be committed twice.

- [ ] **Step 2: Import**

```bash
cd /c/Users/dev/Projects/nomercy
godot --headless --path godot --import
```

Expected: import completes without error. Godot writes `.import` files next to each PNG (expected and harmless — spec §10).

- [ ] **Step 3: Write the failing test**

Create `godot/test/unit/test_knight_frames.gd`:

```gdscript
extends GutTest

const FRAMES_PATH := "res://resources/knight_frames.tres"

var frames: SpriteFrames

func before_each():
	frames = load(FRAMES_PATH) as SpriteFrames

func test_resource_loads():
	assert_not_null(frames, "knight_frames.tres failed to load")

func test_has_all_six_animations():
	for anim in ["idle", "walk", "run", "attack", "jump", "landing"]:
		assert_true(frames.has_animation(anim), "Missing animation: %s" % anim)

func test_walk_has_six_frames():
	assert_eq(frames.get_frame_count("walk"), 6, "Knight walk is a 6-frame cycle")

func test_run_has_six_frames():
	assert_eq(frames.get_frame_count("run"), 6, "Knight run reuses the walk frames")

func test_static_animations_have_one_frame():
	for anim in ["idle", "attack", "jump", "landing"]:
		assert_eq(frames.get_frame_count(anim), 1,
			"%s is a single static image in the source game" % anim)

func test_step_times_match_dart_movement_strategy():
	# knight_movement_strategy.dart: idle 0.20, walk 0.13, run 0.09
	# SpriteFrames stores FPS, so fps == 1.0 / step_time
	assert_almost_eq(frames.get_animation_speed("idle"), 1.0 / 0.20, 0.01)
	assert_almost_eq(frames.get_animation_speed("walk"), 1.0 / 0.13, 0.01)
	assert_almost_eq(frames.get_animation_speed("run"), 1.0 / 0.09, 0.01)

func test_walk_frame_order_alternates_correctly():
	# Frames 0 and 3 are the same source image (left_leg_front);
	# frames 1 and 4 are the same (legs_together). Verifying the texture
	# identity catches a mis-ordered cycle.
	assert_eq(frames.get_frame_texture("walk", 0), frames.get_frame_texture("walk", 3))
	assert_eq(frames.get_frame_texture("walk", 1), frames.get_frame_texture("walk", 4))
	assert_eq(frames.get_frame_texture("walk", 0), frames.get_frame_texture("walk", 5))
```

- [ ] **Step 4: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_knight_frames.gd -gexit
```

Expected: FAIL — the resource does not exist yet.

- [ ] **Step 5: Generate the SpriteFrames resource**

Authoring `.tres` by hand is error-prone. Create a one-off editor script `godot/tools/build_knight_frames.gd`:

```gdscript
@tool
extends SceneTree

const IMG := "res://assets/images/"

const WALK := [
	IMG + "warrior_walk_resized_left_leg_front.png",
	IMG + "warrior_walk_resized_legs_together_left_knee_front.png",
	IMG + "warrior_walk_resized_right_leg_front.png",
	IMG + "warrior_walk_resized_left_leg_front.png",
	IMG + "warrior_walk_resized_legs_together_left_knee_front.png",
	IMG + "warrior_walk_resized_left_leg_front.png",
]

func _init() -> void:
	var frames := SpriteFrames.new()
	# SpriteFrames starts with a "default" animation; drop it.
	frames.remove_animation("default")

	_add(frames, "idle", [IMG + "knight_idle.png"], 1.0 / 0.20, true)
	_add(frames, "walk", WALK, 1.0 / 0.13, true)
	_add(frames, "run", WALK, 1.0 / 0.09, true)
	_add(frames, "attack", [IMG + "knight_attack.png"], 1.0 / 0.30, false)
	_add(frames, "jump", [IMG + "knight_jump.png"], 1.0 / 0.20, true)
	_add(frames, "landing", [IMG + "knight_landing.png"], 1.0 / 0.25, false)

	var err := ResourceSaver.save(frames, "res://resources/knight_frames.tres")
	if err != OK:
		push_error("Save failed: %d" % err)
	else:
		print("Wrote res://resources/knight_frames.tres")
	quit()

func _add(frames: SpriteFrames, name: String, paths: Array,
		fps: float, loop: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, loop)
	for p in paths:
		var tex := load(p) as Texture2D
		if tex == null:
			push_error("Missing texture: %s" % p)
			continue
		frames.add_frame(name, tex)
```

Run it:

```bash
cd /c/Users/dev/Projects/nomercy
mkdir -p godot/resources
godot --headless --path godot -s tools/build_knight_frames.gd
```

Expected: `Wrote res://resources/knight_frames.tres`, no `Missing texture` errors.

- [ ] **Step 6: Run the test and confirm it passes**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_knight_frames.gd -gexit
```

Expected: PASS, 7 tests.

- [ ] **Step 7: Commit**

```bash
git add godot/resources/knight_frames.tres godot/tools/build_knight_frames.gd \
        godot/test/unit/test_knight_frames.gd godot/.gitignore
git commit -m "feat(godot): Knight SpriteFrames from individual PNGs

No sprite sheets exist in the source game (spec section 12); frames are
assembled from the explicit lists in asset_paths.dart."
```

---

## Phase 1 — Vertical Slice

### Task 5: Pure damage math, validated against the Dart fixtures

**Files:**
- Create: `godot/scripts/combat.gd`
- Test: `godot/test/unit/test_combat.gd`

**Interfaces:**
- Consumes: `godot/test/fixtures/combat_damage.json` (Task 3)
- Produces: `Combat.calc_damage(base: float, combo: int, blocking: bool, critical: bool) -> float`

**No node references in this file.** It is a `class_name` script with only static functions.

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_combat.gd`:

```gdscript
extends GutTest

const FIXTURE := "res://test/fixtures/combat_damage.json"

func _load_fixture() -> Array:
	var f := FileAccess.open(FIXTURE, FileAccess.READ)
	assert_not_null(f, "Fixture not found: %s" % FIXTURE)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed as Array

func test_fixture_has_expected_record_count():
	assert_eq(_load_fixture().size(), 96,
		"4 classes x 6 combos x 2 blocking x 2 critical")

func test_matches_every_dart_golden_value():
	var mismatches := []
	for rec in _load_fixture():
		var got: float = Combat.calc_damage(
			rec["base"], int(rec["combo"]), rec["blocking"], rec["critical"]
		)
		if absf(got - float(rec["expected"])) > 1e-6:
			mismatches.append(
				"%s combo=%d block=%s crit=%s: expected %f, got %f" % [
					rec["character"], int(rec["combo"]),
					rec["blocking"], rec["critical"],
					float(rec["expected"]), got
				]
			)
	assert_eq(mismatches.size(), 0,
		"Damage mismatches:\n%s" % "\n".join(mismatches))

func test_knight_base_hit_is_unmodified():
	assert_almost_eq(Combat.calc_damage(15.0, 0, false, false), 15.0, 1e-6)

func test_combo_three_scales_by_1_6():
	assert_almost_eq(Combat.calc_damage(15.0, 3, false, false), 24.0, 1e-6)

func test_block_reduces_by_seventy_percent():
	assert_almost_eq(Combat.calc_damage(15.0, 0, true, false), 4.5, 1e-6)

func test_critical_doubles_before_combo():
	# 15 * 2.0 * (1 + 2*0.2) = 42.0
	assert_almost_eq(Combat.calc_damage(15.0, 2, false, true), 42.0, 1e-6)

func test_combo_zero_applies_no_multiplier():
	assert_almost_eq(Combat.calc_damage(20.0, 0, false, false), 20.0, 1e-6)
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_combat.gd -gexit
```

Expected: FAIL — `Identifier "Combat" not declared`.

- [ ] **Step 3: Implement**

Create `godot/scripts/combat.gd`:

```gdscript
## Pure combat math. No nodes, no state, no side effects.
##
## Ported from modules/engine/lib/src/system/combat_system.dart processAttack().
## The critical-hit RNG is lifted out into an explicit parameter so this
## function is deterministic and testable; the roll itself lives in
## roll_critical() below and is never called from calc_damage().
class_name Combat
extends RefCounted

const CRITICAL_MULTIPLIER := 2.0
const CRITICAL_CHANCE := 0.1
const COMBO_MULTIPLIER := 0.2
const BLOCK_MULTIPLIER := 0.3

## Order is significant and matches the Dart source: critical, then combo,
## then block.
static func calc_damage(
	base: float, combo: int, blocking: bool, critical: bool
) -> float:
	var damage := base
	if critical:
		damage *= CRITICAL_MULTIPLIER
	if combo > 0:
		damage *= 1.0 + combo * COMBO_MULTIPLIER
	if blocking:
		damage *= BLOCK_MULTIPLIER
	return damage

## Separated from calc_damage so damage remains deterministic.
static func roll_critical(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < CRITICAL_CHANCE

## Melee reach, from knight.dart:
##   stats.attackRange * 30 * (1 + comboCount * 0.1)
static func melee_reach(attack_range: float, combo: int) -> float:
	return attack_range * 30.0 * (1.0 + combo * 0.1)
```

- [ ] **Step 4: Run the test and confirm it passes**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_combat.gd -gexit
```

Expected: PASS, 7 tests. If `test_matches_every_dart_golden_value` fails, the assertion message names each mismatching record — fix `calc_damage`, not the fixture.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/combat.gd godot/test/unit/test_combat.gd
git commit -m "feat(godot): pure damage math validated against Dart fixtures"
```

---

### Task 6: Pure stamina math

**Files:**
- Create: `godot/scripts/stamina.gd`
- Test: `godot/test/unit/test_stamina.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `Stamina.regen(current, max, delta)`, `Stamina.block_drain(current, delta)`, `Stamina.can_attack(current)`, `Stamina.attack_cost(airborne)`, `Stamina.attack_cooldown(airborne)`, `Stamina.can_block(current)`, `Stamina.can_jump(current)`, `Stamina.can_dodge(current)` — all static

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_stamina.gd`:

```gdscript
extends GutTest

func test_regen_is_fifteen_per_second():
	assert_almost_eq(Stamina.regen(50.0, 100.0, 1.0), 65.0, 1e-6)

func test_regen_clamps_at_max():
	assert_almost_eq(Stamina.regen(95.0, 100.0, 1.0), 100.0, 1e-6)

func test_block_drain_is_fifteen_per_second():
	assert_almost_eq(Stamina.block_drain(50.0, 1.0), 35.0, 1e-6)

func test_block_drain_clamps_at_zero():
	assert_almost_eq(Stamina.block_drain(5.0, 1.0), 0.0, 1e-6)

func test_attack_requires_fifteen_stamina():
	assert_false(Stamina.can_attack(14.9))
	assert_true(Stamina.can_attack(15.0))

func test_ground_attack_costs_fifteen():
	assert_almost_eq(Stamina.attack_cost(false), 15.0, 1e-6)

func test_air_attack_costs_twenty():
	assert_almost_eq(Stamina.attack_cost(true), 20.0, 1e-6)

func test_ground_attack_cooldown_is_half_a_second():
	assert_almost_eq(Stamina.attack_cooldown(false), 0.5, 1e-6)

func test_air_attack_cooldown_is_one_second():
	assert_almost_eq(Stamina.attack_cooldown(true), 1.0, 1e-6)

func test_block_requires_ten_stamina():
	assert_false(Stamina.can_block(9.9))
	assert_true(Stamina.can_block(10.0))

func test_jump_requires_twenty_stamina():
	assert_false(Stamina.can_jump(19.9))
	assert_true(Stamina.can_jump(20.0))

func test_dodge_requires_twenty_stamina():
	assert_false(Stamina.can_dodge(19.9))
	assert_true(Stamina.can_dodge(20.0))
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_stamina.gd -gexit
```

Expected: FAIL — `Identifier "Stamina" not declared`.

- [ ] **Step 3: Implement**

Create `godot/scripts/stamina.gd`:

```gdscript
## Pure stamina math. No nodes, no state.
##
## Ported from modules/engine/lib/src/components/character/game_character.dart
## (regen line 529, block drain line 536, attack gate lines 566-567) and
## GameConfig in modules/core/lib/src/config/game_config.dart.
class_name Stamina
extends RefCounted

const REGEN_PER_SECOND := 15.0
const BLOCK_DRAIN_PER_SECOND := 15.0

const ATTACK_MIN := 15.0
const ATTACK_COST_GROUND := 15.0
const ATTACK_COST_AIR := 20.0
const ATTACK_COOLDOWN_GROUND := 0.5
const ATTACK_COOLDOWN_AIR := 1.0

const BLOCK_MIN := 10.0
const JUMP_COST := 20.0
const DODGE_COST := 20.0

static func regen(current: float, maximum: float, delta: float) -> float:
	return minf(maximum, current + REGEN_PER_SECOND * delta)

static func block_drain(current: float, delta: float) -> float:
	return maxf(0.0, current - BLOCK_DRAIN_PER_SECOND * delta)

static func can_attack(current: float) -> bool:
	return current >= ATTACK_MIN

static func attack_cost(airborne: bool) -> float:
	return ATTACK_COST_AIR if airborne else ATTACK_COST_GROUND

static func attack_cooldown(airborne: bool) -> float:
	return ATTACK_COOLDOWN_AIR if airborne else ATTACK_COOLDOWN_GROUND

static func can_block(current: float) -> bool:
	return current >= BLOCK_MIN

static func can_jump(current: float) -> bool:
	return current >= JUMP_COST

static func can_dodge(current: float) -> bool:
	return current >= DODGE_COST
```

- [ ] **Step 4: Run the test and confirm it passes**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_stamina.gd -gexit
```

Expected: PASS, 12 tests.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/stamina.gd godot/test/unit/test_stamina.gd
git commit -m "feat(godot): pure stamina cost and regen math"
```

---

### Task 7: Balance Resources and the Knight `.tres` files

**Files:**
- Create: `godot/resources/character_stats.gd`, `godot/resources/movement_profile.gd`
- Create: `godot/resources/knight_stats.tres`, `godot/resources/knight_movement.tres`
- Test: `godot/test/unit/test_knight_resources.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `CharacterStats` with `char_name`, `power`, `magic`, `dexterity`, `intelligence`, `weapon_name`, `attack_range`, `attack_damage`, `max_health`, `tint`; `MovementProfile` with `walk_multiplier`, `run_multiplier`, `run_threshold`, `attack_move_multiplier`, and `base_speed(dexterity)`

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_knight_resources.gd`:

```gdscript
extends GutTest

var stats: CharacterStats
var move: MovementProfile

func before_each():
	stats = load("res://resources/knight_stats.tres") as CharacterStats
	move = load("res://resources/knight_movement.tres") as MovementProfile

func test_resources_load():
	assert_not_null(stats, "knight_stats.tres failed to load")
	assert_not_null(move, "knight_movement.tres failed to load")

func test_knight_stats_match_dart_source():
	# knight.dart KnightStats
	assert_eq(stats.char_name, "Knight")
	assert_almost_eq(stats.power, 15.0, 1e-6)
	assert_almost_eq(stats.magic, 5.0, 1e-6)
	assert_almost_eq(stats.dexterity, 8.0, 1e-6)
	assert_almost_eq(stats.intelligence, 7.0, 1e-6)
	assert_almost_eq(stats.attack_range, 2.0, 1e-6)
	assert_almost_eq(stats.attack_damage, 15.0, 1e-6)
	assert_almost_eq(stats.max_health, 100.0, 1e-6)
	assert_eq(stats.weapon_name, "Sword Slash")

func test_knight_movement_matches_dart_source():
	# knight_movement_strategy.dart
	assert_almost_eq(move.walk_multiplier, 100.0, 1e-6)
	assert_almost_eq(move.run_multiplier, 160.0, 1e-6)
	assert_almost_eq(move.run_threshold, 0.8, 1e-6)
	assert_almost_eq(move.attack_move_multiplier, 0.3, 1e-6)

func test_base_speed_is_dexterity_over_two():
	# game_character.dart:260 -> baseSpeed: stats.dexterity / 2
	assert_almost_eq(MovementProfile.base_speed(stats.dexterity), 4.0, 1e-6)

func test_knight_walk_speed_is_400_px_per_second():
	var speed := MovementProfile.base_speed(stats.dexterity) * move.walk_multiplier
	assert_almost_eq(speed, 400.0, 1e-6)

func test_knight_run_speed_is_640_px_per_second():
	var speed := MovementProfile.base_speed(stats.dexterity) * move.run_multiplier
	assert_almost_eq(speed, 640.0, 1e-6)

func test_melee_reach_at_combo_zero_is_sixty_px():
	assert_almost_eq(Combat.melee_reach(stats.attack_range, 0), 60.0, 1e-6)
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_knight_resources.gd -gexit
```

Expected: FAIL — `Identifier "CharacterStats" not declared`.

- [ ] **Step 3: Define the Resource classes**

Create `godot/resources/character_stats.gd`:

```gdscript
## Per-class character stats. Ported from
## modules/engine/lib/src/components/character/character_stats.dart
## and the *Stats subclasses in the same directory.
class_name CharacterStats
extends Resource

@export var char_name: String = ""
@export var power: float = 0.0
@export var magic: float = 0.0
@export var dexterity: float = 0.0
@export var intelligence: float = 0.0
@export var weapon_name: String = ""
@export var attack_range: float = 0.0
@export var attack_damage: float = 0.0
@export var max_health: float = 100.0
@export var tint: Color = Color.WHITE
```

Create `godot/resources/movement_profile.gd`:

```gdscript
## Per-class movement tuning. Ported from
## modules/engine/lib/src/components/character/movement/movement_strategy.dart
class_name MovementProfile
extends Resource

@export var walk_multiplier: float = 100.0
@export var run_multiplier: float = 160.0
@export var run_threshold: float = 0.8
@export var attack_move_multiplier: float = 0.3

## game_character.dart:260 -> baseSpeed: stats.dexterity / 2
static func base_speed(dexterity: float) -> float:
	return dexterity / 2.0

## movement_strategy.dart resolveSpeed()
func resolve_speed(
	dexterity: float, input_magnitude: float, attack_committed: bool
) -> float:
	var multiplier := attack_move_multiplier if attack_committed else 1.0
	var running := input_magnitude > run_threshold
	var class_multiplier := run_multiplier if running else walk_multiplier
	return base_speed(dexterity) * class_multiplier * multiplier
```

- [ ] **Step 4: Author the Knight `.tres` files**

Create `godot/resources/knight_stats.tres`:

```
[gd_resource type="Resource" script_class="CharacterStats" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/character_stats.gd" id="1"]

[resource]
script = ExtResource("1")
char_name = "Knight"
power = 15.0
magic = 5.0
dexterity = 8.0
intelligence = 7.0
weapon_name = "Sword Slash"
attack_range = 2.0
attack_damage = 15.0
max_health = 100.0
tint = Color(0.13, 0.59, 0.95, 1)
```

`tint` is Flutter's `Colors.blue` (`#2196F3`) converted to normalized floats.

Create `godot/resources/knight_movement.tres`:

```
[gd_resource type="Resource" script_class="MovementProfile" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/movement_profile.gd" id="1"]

[resource]
script = ExtResource("1")
walk_multiplier = 100.0
run_multiplier = 160.0
run_threshold = 0.8
attack_move_multiplier = 0.3
```

- [ ] **Step 5: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_knight_resources.gd -gexit
```

Expected: PASS, 8 tests.

- [ ] **Step 6: Commit**

```bash
git add godot/resources/ godot/test/unit/test_knight_resources.gd
git commit -m "feat(godot): CharacterStats and MovementProfile resources for Knight"
```

---

### Task 8: Platform scene and `level_1` conversion

**Files:**
- Create: `godot/scenes/platform/platform.gd`, `godot/scenes/platform/platform.tscn`
- Create: `tools/convert_map.py`
- Create (generated): `godot/scenes/maps/level_1.tscn`
- Test: `godot/test/unit/test_level_1.gd`

**Interfaces:**
- Consumes: `assets/maps/level_1.json` (24 platforms, spawn `(200, 900)`, 1920×1080)
- Produces: `res://scenes/maps/level_1.tscn` with a `Platforms` node holding 24 `Platform` instances and a `PlayerSpawn` `Marker2D`

**Note on the spec.** Spec §6 says hand-authored maps are "rebuilt in the Godot editor." Converting the 24 platforms by script is more reliable than hand-placing them and produces the same artifact — a `.tscn` that is thereafter edited in the editor. The intent (maps are Godot-native scenes) is preserved.

- [ ] **Step 1: Write the platform script**

Create `godot/scenes/platform/platform.gd`:

```gdscript
## A solid platform. Replaces the five Flame classes tiled_platform,
## enhanced_platform, tiled_ground_component, platform_factory and
## game_platform (~830 LOC) with one scene; Godot's texture_repeat does
## the seamless tiling those classes hand-rolled.
class_name Platform
extends StaticBody2D

enum Kind { BRICK, GROUND, STONE }

const TEXTURES := {
	Kind.BRICK: "res://assets/images/brick_tile.png",
	Kind.GROUND: "res://assets/images/ground_tile.png",
	Kind.STONE: "res://assets/images/stone.png",
}

@export var kind: Kind = Kind.BRICK:
	set(value):
		kind = value
		_apply()

@export var size: Vector2 = Vector2(120, 30):
	set(value):
		size = value
		_apply()

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_node_ready():
		return
	_sprite.texture = load(TEXTURES[kind])
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(Vector2.ZERO, size)
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.centered = false
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
```

- [ ] **Step 2: Create the platform scene**

Create `godot/scenes/platform/platform.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/platform/platform.gd" id="1"]

[node name="Platform" type="StaticBody2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
centered = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
```

- [ ] **Step 3: Write the failing test**

Create `godot/test/unit/test_level_1.gd`:

```gdscript
extends GutTest

var level: Node2D

func before_each():
	var packed := load("res://scenes/maps/level_1.tscn") as PackedScene
	assert_not_null(packed, "level_1.tscn failed to load")
	level = packed.instantiate()
	add_child_autofree(level)

func test_has_twenty_four_platforms():
	# assets/maps/level_1.json: 24 platforms (6 brick, 18 ground)
	assert_eq(level.get_node("Platforms").get_child_count(), 24)

func test_platform_kinds_match_source_counts():
	var brick := 0
	var ground := 0
	for p in level.get_node("Platforms").get_children():
		if p.kind == Platform.Kind.BRICK:
			brick += 1
		elif p.kind == Platform.Kind.GROUND:
			ground += 1
	assert_eq(brick, 6, "level_1.json has 6 brick platforms")
	assert_eq(ground, 18, "level_1.json has 18 ground platforms")

func test_player_spawn_matches_source():
	var spawn := level.get_node("PlayerSpawn") as Marker2D
	assert_almost_eq(spawn.position.x, 200.0, 0.5)
	assert_almost_eq(spawn.position.y, 900.0, 0.5)

func test_first_platform_position_and_size_match_source():
	# First record: brick at (71, 607), 120x30
	var first := level.get_node("Platforms").get_child(0) as Platform
	assert_almost_eq(first.position.x, 71.0, 0.5)
	assert_almost_eq(first.position.y, 607.0, 0.5)
	assert_almost_eq(first.size.x, 120.0, 0.5)
	assert_almost_eq(first.size.y, 30.0, 0.5)

func test_all_platforms_have_collision_shapes():
	for p in level.get_node("Platforms").get_children():
		var shape := p.get_node("CollisionShape2D") as CollisionShape2D
		assert_not_null(shape.shape, "%s has no collision shape" % p.name)
```

- [ ] **Step 4: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_level_1.gd -gexit
```

Expected: FAIL — `level_1.tscn failed to load`.

- [ ] **Step 5: Write the converter**

Create `tools/convert_map.py`:

```python
#!/usr/bin/env python3
"""One-off: assets/maps/level_N.json -> godot/scenes/maps/level_N.tscn

Run once per map. The resulting .tscn is the source of truth thereafter
and is edited in the Godot editor, not regenerated.

Usage: python3 tools/convert_map.py level_1
"""
import json
import sys
from pathlib import Path

KIND = {"brick": 0, "ground": 1, "stone": 2}

ROOT = Path(__file__).resolve().parent.parent


def convert(name: str) -> None:
    src = ROOT / "assets" / "maps" / f"{name}.json"
    dst = ROOT / "godot" / "scenes" / "maps" / f"{name}.tscn"
    dst.parent.mkdir(parents=True, exist_ok=True)

    data = json.loads(src.read_text())
    platforms = data["platforms"]
    spawn = data["playerSpawn"]

    lines = [
        f"[gd_scene load_steps=2 format=3]",
        "",
        '[ext_resource type="PackedScene" '
        'path="res://scenes/platform/platform.tscn" id="1"]',
        "",
        f'[node name="{name}" type="Node2D"]',
        "",
        '[node name="Platforms" type="Node2D" parent="."]',
        "",
    ]

    for i, p in enumerate(platforms):
        kind = KIND.get(p["type"])
        if kind is None:
            raise SystemExit(f"Unknown platform type {p['type']!r} at index {i}")
        lines += [
            f'[node name="Platform{i}" parent="Platforms" '
            f'instance=ExtResource("1")]',
            f'position = Vector2({p["x"]}, {p["y"]})',
            f"kind = {kind}",
            f'size = Vector2({p["width"]}, {p["height"]})',
            "",
        ]

    lines += [
        '[node name="PlayerSpawn" type="Marker2D" parent="."]',
        f'position = Vector2({spawn["x"]}, {spawn["y"]})',
        "",
    ]

    dst.write_text("\n".join(lines))
    print(f"Wrote {dst} ({len(platforms)} platforms)")


if __name__ == "__main__":
    convert(sys.argv[1] if len(sys.argv) > 1 else "level_1")
```

- [ ] **Step 6: Run the converter**

```bash
cd /c/Users/dev/Projects/nomercy
python3 tools/convert_map.py level_1
```

Expected: `Wrote .../godot/scenes/maps/level_1.tscn (24 platforms)`.

- [ ] **Step 7: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_level_1.gd -gexit
```

Expected: PASS, 5 tests.

- [ ] **Step 8: Commit**

```bash
git add godot/scenes/platform/ godot/scenes/maps/level_1.tscn \
        tools/convert_map.py godot/test/unit/test_level_1.gd
git commit -m "feat(godot): Platform scene and level_1 converted from JSON"
```

---

### Task 9: Character body — gravity, movement, jump

**Files:**
- Create: `godot/scenes/character/character.gd`, `godot/scenes/character/character.tscn`
- Test: `godot/test/unit/test_character_physics.gd`

**Interfaces:**
- Consumes: `CharacterStats`, `MovementProfile`, `Stamina`, `knight_frames.tres`, `platform.tscn`
- Produces: `Character` (`CharacterBody2D`) with `health`, `stamina`, `combo`, `facing_right`, and methods `try_jump()`, `apply_damage(amount)`, `is_authority()`

**Authority rule.** `health`, `stamina`, and `combo` are mutated **only** inside this script, and only when `is_authority()` is true. Nothing outside `character.gd` writes them.

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_character_physics.gd`:

```gdscript
extends GutTest

const CHARACTER := preload("res://scenes/character/character.tscn")
const PLATFORM := preload("res://scenes/platform/platform.tscn")

var character: CharacterBody2D
var platform: Node2D

func before_each():
	platform = PLATFORM.instantiate()
	platform.position = Vector2(0, 500)
	platform.size = Vector2(1000, 80)
	platform.kind = Platform.Kind.GROUND
	add_child_autofree(platform)

	character = CHARACTER.instantiate()
	character.position = Vector2(400, 100)
	add_child_autofree(character)
	await wait_frames(2)

func test_starts_at_full_health_and_stamina():
	assert_almost_eq(character.health, 100.0, 1e-6)
	assert_almost_eq(character.stamina, 100.0, 1e-6)
	assert_eq(character.combo, 0)

func test_gravity_pulls_character_down():
	var start_y := character.position.y
	await wait_physics_frames(10)
	assert_gt(character.position.y, start_y,
		"Character should fall under gravity")

func test_character_lands_on_platform_and_stops():
	await wait_seconds(2.0)
	assert_true(character.is_on_floor(), "Character should land on the platform")
	assert_almost_eq(character.velocity.y, 0.0, 1.0)

func test_fall_speed_is_capped_at_800():
	# Remove the floor so it falls freely.
	platform.queue_free()
	await wait_seconds(3.0)
	assert_lte(character.velocity.y, 800.0 + 1.0,
		"Fall speed must clamp at maxFallSpeed = 800")

func test_jump_costs_twenty_stamina():
	await wait_seconds(2.0)  # land first
	var before := character.stamina
	character.try_jump()
	assert_almost_eq(character.stamina, before - 20.0, 1e-6)

func test_jump_sets_upward_velocity():
	await wait_seconds(2.0)
	character.try_jump()
	assert_almost_eq(character.velocity.y, -300.0, 1e-6)

func test_jump_is_refused_without_stamina():
	await wait_seconds(2.0)
	character.stamina = 10.0
	var refused := not character.try_jump()
	assert_true(refused, "Jump must be refused below 20 stamina")
	assert_almost_eq(character.stamina, 10.0, 1e-6)

func test_stamina_regenerates_at_fifteen_per_second():
	await wait_seconds(2.0)
	character.stamina = 50.0
	await wait_seconds(1.0)
	# Allow generous tolerance — frame timing is not exact.
	assert_almost_eq(character.stamina, 65.0, 3.0)

func test_apply_damage_reduces_health():
	character.apply_damage(24.0)
	assert_almost_eq(character.health, 76.0, 1e-6)

func test_health_floors_at_zero():
	character.apply_damage(500.0)
	assert_almost_eq(character.health, 0.0, 1e-6)

func test_died_signal_fires_once_at_zero_health():
	watch_signals(character)
	character.apply_damage(500.0)
	assert_signal_emit_count(character, "died", 1)
	character.apply_damage(10.0)
	assert_signal_emit_count(character, "died", 1, "died must not re-fire")
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_character_physics.gd -gexit
```

Expected: FAIL — `character.tscn` does not exist.

- [ ] **Step 3: Implement the character script**

Create `godot/scenes/character/character.gd`:

```gdscript
## Base character. Owns and mutates its own health, stamina and combo, and
## only when it holds multiplayer authority. Nothing outside this script
## writes those properties — that rule is what makes MultiplayerSynchronizer
## replication work without restructuring later.
##
## Ported from modules/engine/lib/src/components/character/game_character.dart
class_name Character
extends CharacterBody2D

signal died
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal combo_changed(count: int)

const GRAVITY := 1000.0
const MAX_FALL_SPEED := 800.0
const JUMP_VELOCITY := -300.0
const COMBO_WINDOW := 1.5

@export var stats: CharacterStats
@export var movement: MovementProfile

var health: float = 100.0
var stamina: float = 100.0
var combo: int = 0
var facing_right: bool = true

var _attack_cooldown: float = 0.0
var _combo_timer: float = 0.0
var _is_blocking: bool = false
var _dead: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if stats != null:
		health = stats.max_health
	stamina = 100.0
	health_changed.emit(health, _max_health())
	stamina_changed.emit(stamina, 100.0)

func is_authority() -> bool:
	# Single-player and headless tests have no multiplayer peer configured,
	# in which case every node is its own authority. This guard is inert
	# now and load-bearing in Phase 6.
	return not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()

func _max_health() -> float:
	return stats.max_health if stats != null else 100.0

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()

	if not is_authority():
		return

	_tick_timers(delta)
	_tick_stamina(delta)

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

func _tick_timers(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0
			combo_changed.emit(combo)

func _tick_stamina(delta: float) -> void:
	var before := stamina
	if _is_blocking:
		stamina = Stamina.block_drain(stamina, delta)
		if stamina <= 0.0:
			stop_block()
	elif stamina < 100.0:
		stamina = Stamina.regen(stamina, 100.0, delta)
	if not is_equal_approx(before, stamina):
		stamina_changed.emit(stamina, 100.0)

## Horizontal movement. [param input] is the signed axis value in [-1, 1];
## its magnitude selects walk vs run exactly as resolveSpeed() does in Dart.
func move_horizontal(input: float, attack_committed: bool) -> void:
	if not is_authority():
		return
	if is_zero_approx(input):
		velocity.x = 0.0
		return
	var speed := movement.resolve_speed(
		stats.dexterity, absf(input), attack_committed
	)
	velocity.x = signf(input) * speed
	facing_right = input > 0.0
	_sprite.flip_h = not facing_right

func try_jump() -> bool:
	if not is_authority():
		return false
	if not is_on_floor():
		return false
	if not Stamina.can_jump(stamina):
		return false
	stamina -= Stamina.JUMP_COST
	stamina_changed.emit(stamina, 100.0)
	velocity.y = JUMP_VELOCITY
	return true

func start_block() -> void:
	if not is_authority():
		return
	if not Stamina.can_block(stamina):
		return
	_is_blocking = true

func stop_block() -> void:
	_is_blocking = false

func is_blocking() -> bool:
	return _is_blocking

func can_attack() -> bool:
	return _attack_cooldown <= 0.0 and Stamina.can_attack(stamina)

## Spends stamina and starts the cooldown. Returns false if the attack
## cannot start. Damage application is Task 11.
func begin_attack() -> bool:
	if not is_authority():
		return false
	if not can_attack():
		return false
	var airborne := not is_on_floor()
	stamina -= Stamina.attack_cost(airborne)
	_attack_cooldown = Stamina.attack_cooldown(airborne)
	stamina_changed.emit(stamina, 100.0)
	return true

func register_hit() -> void:
	if not is_authority():
		return
	combo += 1
	_combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)

func apply_damage(amount: float) -> void:
	if not is_authority():
		return
	if _dead:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, _max_health())
	if health <= 0.0:
		_dead = true
		died.emit()
```

- [ ] **Step 4: Create the character scene**

Create `godot/scenes/character/character.tscn`:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scenes/character/character.gd" id="1"]
[ext_resource type="SpriteFrames" path="res://resources/knight_frames.tres" id="2"]
[ext_resource type="Resource" path="res://resources/knight_stats.tres" id="3"]
[ext_resource type="Resource" path="res://resources/knight_movement.tres" id="4"]

[sub_resource type="RectangleShape2D" id="shape"]
size = Vector2(120, 240)

[node name="Character" type="CharacterBody2D"]
script = ExtResource("1")
stats = ExtResource("3")
movement = ExtResource("4")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
sprite_frames = ExtResource("2")
animation = &"idle"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("shape")
```

The collision box is 120×240, not 240×240: `GameConfig.characterWidth` is the *sprite* footprint, but a 240-wide capsule on a 120-wide platform cannot land. Half-width matches how the Dart AABB behaves in practice. If characters catch on platform edges during play-testing, this is the number to tune.

- [ ] **Step 5: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_character_physics.gd -gexit
```

Expected: PASS, 11 tests.

- [ ] **Step 6: Commit**

```bash
git add godot/scenes/character/ godot/test/unit/test_character_physics.gd
git commit -m "feat(godot): Character body with gravity, jump and authority-owned state"
```

---

### Task 10: State machine

**Files:**
- Create: `godot/scenes/character/state_machine.gd`
- Modify: `godot/scenes/character/character.tscn` (add `StateMachine` child)
- Test: `godot/test/unit/test_state_machine.gd`

**Interfaces:**
- Consumes: `Character`
- Produces: `CharacterStateMachine` with `State` enum (`IDLE`, `WALKING`, `RUNNING`, `JUMPING`, `FALLING`, `LANDING`, `ATTACKING`, `BLOCKING`, `DODGING`, `STUNNED`, `DEAD`), property `state`, signal `state_changed(from, to)`, method `request(new_state) -> bool`

State names port verbatim from `character_animation_state.dart`.

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_state_machine.gd`:

```gdscript
extends GutTest

var sm: CharacterStateMachine

func before_each():
	sm = CharacterStateMachine.new()
	add_child_autofree(sm)

func test_starts_idle():
	assert_eq(sm.state, CharacterStateMachine.State.IDLE)

func test_idle_to_walking_is_allowed():
	assert_true(sm.request(CharacterStateMachine.State.WALKING))
	assert_eq(sm.state, CharacterStateMachine.State.WALKING)

func test_state_changed_signal_carries_from_and_to():
	watch_signals(sm)
	sm.request(CharacterStateMachine.State.JUMPING)
	assert_signal_emitted_with_parameters(
		sm, "state_changed",
		[CharacterStateMachine.State.IDLE, CharacterStateMachine.State.JUMPING]
	)

func test_requesting_current_state_is_a_noop():
	watch_signals(sm)
	assert_false(sm.request(CharacterStateMachine.State.IDLE))
	assert_signal_emit_count(sm, "state_changed", 0)

func test_dead_is_terminal():
	sm.request(CharacterStateMachine.State.DEAD)
	assert_false(sm.request(CharacterStateMachine.State.IDLE),
		"Nothing may transition out of DEAD")
	assert_eq(sm.state, CharacterStateMachine.State.DEAD)

func test_attacking_cannot_be_cancelled_by_movement():
	# game_character.dart: attacks are committed for attackCommitTime.
	sm.request(CharacterStateMachine.State.ATTACKING)
	assert_false(sm.request(CharacterStateMachine.State.WALKING))
	assert_eq(sm.state, CharacterStateMachine.State.ATTACKING)

func test_attacking_can_be_interrupted_by_stun():
	sm.request(CharacterStateMachine.State.ATTACKING)
	assert_true(sm.request(CharacterStateMachine.State.STUNNED))

func test_attacking_can_be_interrupted_by_death():
	sm.request(CharacterStateMachine.State.ATTACKING)
	assert_true(sm.request(CharacterStateMachine.State.DEAD))

func test_animation_name_maps_to_sprite_frames():
	assert_eq(sm.animation_for(CharacterStateMachine.State.IDLE), "idle")
	assert_eq(sm.animation_for(CharacterStateMachine.State.WALKING), "walk")
	assert_eq(sm.animation_for(CharacterStateMachine.State.RUNNING), "run")
	assert_eq(sm.animation_for(CharacterStateMachine.State.JUMPING), "jump")
	assert_eq(sm.animation_for(CharacterStateMachine.State.FALLING), "jump")
	assert_eq(sm.animation_for(CharacterStateMachine.State.LANDING), "landing")
	assert_eq(sm.animation_for(CharacterStateMachine.State.ATTACKING), "attack")
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_state_machine.gd -gexit
```

Expected: FAIL — `Identifier "CharacterStateMachine" not declared`.

- [ ] **Step 3: Implement**

Create `godot/scenes/character/state_machine.gd`:

```gdscript
## Character animation/action states. Ported verbatim from
## modules/engine/lib/src/statemachine/character_animation_state.dart
class_name CharacterStateMachine
extends Node

signal state_changed(from: State, to: State)

enum State {
	IDLE, WALKING, RUNNING, JUMPING, FALLING,
	LANDING, ATTACKING, BLOCKING, DODGING, STUNNED, DEAD,
}

## Only these may interrupt a committed attack (game_character.dart treats
## attacks as committed for attackCommitTime = 0.3s).
const ATTACK_INTERRUPTS := [State.STUNNED, State.DEAD]

## FALLING reuses the jump art — there is no separate falling sprite.
const ANIMATIONS := {
	State.IDLE: "idle",
	State.WALKING: "walk",
	State.RUNNING: "run",
	State.JUMPING: "jump",
	State.FALLING: "jump",
	State.LANDING: "landing",
	State.ATTACKING: "attack",
	State.BLOCKING: "idle",
	State.DODGING: "walk",
	State.STUNNED: "idle",
	State.DEAD: "idle",
}

var state: State = State.IDLE

## Returns true if the transition was accepted.
func request(new_state: State) -> bool:
	if new_state == state:
		return false
	if state == State.DEAD:
		return false
	if state == State.ATTACKING and new_state not in ATTACK_INTERRUPTS:
		return false
	var previous := state
	state = new_state
	state_changed.emit(previous, state)
	return true

## Force a transition, ignoring commitment rules. Used when a timer
## expires — e.g. the attack animation finishing.
func force(new_state: State) -> void:
	if new_state == state:
		return
	var previous := state
	state = new_state
	state_changed.emit(previous, state)

func animation_for(s: State) -> String:
	return ANIMATIONS.get(s, "idle")
```

- [ ] **Step 4: Run the test and confirm it passes**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_state_machine.gd -gexit
```

Expected: PASS, 9 tests.

- [ ] **Step 5: Wire the state machine into the character scene**

Add to `godot/scenes/character/character.tscn`, after the `CollisionShape2D` node:

```
[node name="StateMachine" type="Node" parent="."]
script = ExtResource("5")
```

and add to the `ext_resource` block at the top:

```
[ext_resource type="Script" path="res://scenes/character/state_machine.gd" id="5"]
```

Bump `load_steps` from 5 to 6.

Then in `character.gd`, add the `@onready` reference and drive the sprite. Add after the existing `_sprite` declaration:

```gdscript
@onready var _sm: CharacterStateMachine = $StateMachine
```

and append this method. **Call it in `_physics_process` *before* the `is_authority()` early-return**, not after — animation must run on non-authoritative peers too, since they render replicated characters. Putting it after the guard would leave every remote character frozen in its idle pose in Phase 6, and the bug would not surface until then. The call site becomes:

```gdscript
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()
	_sync_animation()          # runs on every peer

	if not is_authority():
		return

	_tick_timers(delta)
	_tick_stamina(delta)
```

The method itself:

```gdscript
func _sync_animation() -> void:
	var want: CharacterStateMachine.State
	if _dead:
		want = CharacterStateMachine.State.DEAD
	elif not is_on_floor():
		want = CharacterStateMachine.State.JUMPING if velocity.y < 0.0 \
			else CharacterStateMachine.State.FALLING
	elif _is_blocking:
		want = CharacterStateMachine.State.BLOCKING
	elif absf(velocity.x) > 15.0:
		# GameConfig.walkThreshold = 15.0
		var running := absf(velocity.x) > \
			MovementProfile.base_speed(stats.dexterity) * movement.walk_multiplier
		want = CharacterStateMachine.State.RUNNING if running \
			else CharacterStateMachine.State.WALKING
	else:
		want = CharacterStateMachine.State.IDLE
	_sm.request(want)
	var anim := _sm.animation_for(_sm.state)
	if _sprite.animation != anim:
		_sprite.play(anim)
```

- [ ] **Step 6: Re-run the full suite**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gdir=res://test -gexit
```

Expected: all suites pass. Confirm `echo $?` → `0`.

- [ ] **Step 7: Commit**

```bash
git add godot/scenes/character/ godot/test/unit/test_state_machine.gd
git commit -m "feat(godot): character state machine driving sprite animation"
```

---

### Task 11: Melee attack with HitBox/HurtBox

**Files:**
- Modify: `godot/scenes/character/character.tscn` (add `HitBox`, `HurtBox`), `godot/scenes/character/character.gd`
- Modify: `godot/project.godot` (collision layer names)
- Test: `godot/test/unit/test_melee_combat.gd`

**Interfaces:**
- Consumes: `Combat.calc_damage`, `Combat.melee_reach`, `Character.begin_attack`, `Character.apply_damage`
- Produces: `Character.perform_melee_attack() -> int` returning the number of targets hit

Collision layers: layer 1 = `world`, layer 2 = `player_hurt`, layer 3 = `enemy_hurt`. A player `HitBox` scans layer 3; an enemy `HitBox` scans layer 2.

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_melee_combat.gd`:

```gdscript
extends GutTest

const CHARACTER := preload("res://scenes/character/character.tscn")
const PLATFORM := preload("res://scenes/platform/platform.tscn")

var attacker: Character
var target: Character

func before_each():
	var floor_node = PLATFORM.instantiate()
	floor_node.position = Vector2(0, 500)
	floor_node.size = Vector2(2000, 80)
	add_child_autofree(floor_node)

	attacker = CHARACTER.instantiate()
	attacker.position = Vector2(400, 260)
	attacker.is_enemy = false
	add_child_autofree(attacker)

	target = CHARACTER.instantiate()
	target.position = Vector2(440, 260)  # 40px away, inside the 60px reach
	target.is_enemy = true
	add_child_autofree(target)

	await wait_seconds(1.5)  # let both land

func test_attack_within_reach_damages_target():
	attacker.facing_right = true
	var before := target.health
	var hits := attacker.perform_melee_attack()
	await wait_frames(2)
	assert_eq(hits, 1, "Target at 40px should be within the 60px reach")
	assert_almost_eq(target.health, before - 15.0, 0.01)

func test_attack_out_of_reach_misses():
	target.position = Vector2(900, 260)  # far beyond reach
	await wait_frames(2)
	attacker.facing_right = true
	var before := target.health
	var hits := attacker.perform_melee_attack()
	await wait_frames(2)
	assert_eq(hits, 0)
	assert_almost_eq(target.health, before, 0.01)

func test_attack_spends_fifteen_stamina_on_the_ground():
	var before := attacker.stamina
	attacker.perform_melee_attack()
	assert_almost_eq(attacker.stamina, before - 15.0, 0.01)

func test_attack_is_refused_below_fifteen_stamina():
	attacker.stamina = 10.0
	assert_eq(attacker.perform_melee_attack(), 0,
		"Attack must be refused below 15 stamina")

func test_landing_a_hit_increments_the_combo():
	attacker.facing_right = true
	assert_eq(attacker.combo, 0)
	attacker.perform_melee_attack()
	await wait_frames(2)
	assert_eq(attacker.combo, 1)

func test_combo_increases_damage_on_the_next_hit():
	attacker.facing_right = true
	attacker.perform_melee_attack()
	await wait_frames(2)
	# Clear the cooldown so we can swing again immediately.
	attacker._attack_cooldown = 0.0
	var before := target.health
	attacker.perform_melee_attack()
	await wait_frames(2)
	# combo is 1 going into the second swing: 15 * 1.2 = 18.0
	assert_almost_eq(target.health, before - 18.0, 0.01)

func test_blocking_target_takes_thirty_percent():
	attacker.facing_right = true
	target.start_block()
	var before := target.health
	attacker.perform_melee_attack()
	await wait_frames(2)
	assert_almost_eq(target.health, before - 4.5, 0.01)

func test_attack_respects_cooldown():
	attacker.perform_melee_attack()
	await wait_frames(2)
	assert_eq(attacker.perform_melee_attack(), 0,
		"Second attack inside the 0.5s cooldown must be refused")
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_melee_combat.gd -gexit
```

Expected: FAIL — `is_enemy` and `perform_melee_attack` do not exist.

- [ ] **Step 3: Name the collision layers**

Append to `godot/project.godot`:

```ini
[layer_names]

2d_physics/layer_1="world"
2d_physics/layer_2="player_hurt"
2d_physics/layer_3="enemy_hurt"
```

- [ ] **Step 4: Add the hit and hurt boxes to the scene**

Add to `godot/scenes/character/character.tscn`:

```
[sub_resource type="CircleShape2D" id="hitshape"]
radius = 60.0

[sub_resource type="RectangleShape2D" id="hurtshape"]
size = Vector2(120, 240)

[node name="HitBox" type="Area2D" parent="."]
monitoring = false
collision_layer = 0
collision_mask = 4

[node name="CollisionShape2D" type="CollisionShape2D" parent="HitBox"]
shape = SubResource("hitshape")

[node name="HurtBox" type="Area2D" parent="."]
monitorable = true
monitoring = false
collision_layer = 2
collision_mask = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="HurtBox"]
shape = SubResource("hurtshape")
```

Bump `load_steps` accordingly. `collision_mask = 4` is layer 3 (`enemy_hurt`); `collision_layer = 2` is layer 2 (`player_hurt`). `_apply_faction()` in the next step swaps these for enemies.

- [ ] **Step 5: Implement the attack**

Add to `godot/scenes/character/character.gd`:

```gdscript
## Which faction this character belongs to. Determines which layer its
## HurtBox sits on and which layer its HitBox scans.
@export var is_enemy: bool = false
```

and these `@onready` references:

```gdscript
@onready var _hitbox: Area2D = $HitBox
@onready var _hurtbox: Area2D = $HurtBox
```

Call `_apply_faction()` at the end of `_ready()`, and add:

```gdscript
const LAYER_PLAYER_HURT := 2   # bit for physics layer 2
const LAYER_ENEMY_HURT := 4    # bit for physics layer 3

func _apply_faction() -> void:
	if is_enemy:
		_hurtbox.collision_layer = LAYER_ENEMY_HURT
		_hitbox.collision_mask = LAYER_PLAYER_HURT
	else:
		_hurtbox.collision_layer = LAYER_PLAYER_HURT
		_hitbox.collision_mask = LAYER_ENEMY_HURT
	_hurtbox.set_meta("owner_character", self)

## Swings once. Returns the number of targets damaged.
##
## Ported from knight.dart attack(): reach scales with combo, targets behind
## the character are skipped unless very close, and a landed hit applies
## knockback.
func perform_melee_attack() -> int:
	if not is_authority():
		return 0
	if not begin_attack():
		return 0

	var reach := Combat.melee_reach(stats.attack_range, combo)
	_position_hitbox(reach)

	var hits := 0
	for area in _overlapping_hurtboxes():
		var other = area.get_meta("owner_character", null)
		if other == null or other == self:
			continue
		if other.health <= 0.0:
			continue

		var distance := global_position.distance_to(other.global_position)
		if distance >= reach:
			continue

		# knight.dart: beyond 50px, the target must be in front.
		var dx := other.global_position.x - global_position.x
		var in_front := (facing_right and dx > 0.0) or (not facing_right and dx < 0.0)
		if distance > 50.0 and not in_front:
			continue

		var damage := Combat.calc_damage(
			stats.attack_damage, combo, other.is_blocking(), false
		)
		other.apply_damage(damage)
		other.apply_knockback(150.0 if facing_right else -150.0, combo >= 3)
		hits += 1

	if hits > 0:
		register_hit()
	return hits

func _position_hitbox(reach: float) -> void:
	var shape := _hitbox.get_node("CollisionShape2D") as CollisionShape2D
	(shape.shape as CircleShape2D).radius = reach
	_hitbox.monitoring = true

func _overlapping_hurtboxes() -> Array[Area2D]:
	# force_update_transform + a physics flush so the query sees the
	# hitbox we just resized, without waiting a frame.
	_hitbox.force_update_transform()
	var result: Array[Area2D] = []
	for a in _hitbox.get_overlapping_areas():
		result.append(a)
	return result

## knight.dart: horizontal shove, plus a small pop at combo 3+.
func apply_knockback(horizontal: float, pop: bool) -> void:
	if not is_authority():
		return
	velocity.x += horizontal
	if pop:
		velocity.y = -100.0
```

- [ ] **Step 6: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_melee_combat.gd -gexit
```

Expected: PASS, 8 tests.

If overlap queries return empty, `Area2D.monitoring` must be true for at least one physics frame before `get_overlapping_areas()` reports anything. Set `_hitbox.monitoring = true` in `_ready()` instead of inside `_position_hitbox`, and re-run.

- [ ] **Step 7: Commit**

```bash
git add godot/scenes/character/ godot/project.godot \
        godot/test/unit/test_melee_combat.gd
git commit -m "feat(godot): melee combat via HitBox/HurtBox with combo scaling"
```

---

### Task 12: Player controller

**Files:**
- Create: `godot/scenes/character/player_controller.gd`
- Modify: `godot/scenes/character/character.tscn` → save as `godot/scenes/character/player.tscn`
- Test: `godot/test/unit/test_player_controller.gd`

**Interfaces:**
- Consumes: `InputMap` actions (Task 2), `Character`
- Produces: `player.tscn` — a `Character` with a `PlayerController` child translating actions into character calls

**Never read a device.** Only `Input.get_axis`, `Input.is_action_pressed`, `Input.is_action_just_pressed` with the eight action names.

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_player_controller.gd`:

```gdscript
extends GutTest

const PLAYER := preload("res://scenes/character/player.tscn")
const PLATFORM := preload("res://scenes/platform/platform.tscn")

var player: Character

func before_each():
	var floor_node = PLATFORM.instantiate()
	floor_node.position = Vector2(0, 500)
	floor_node.size = Vector2(2000, 80)
	add_child_autofree(floor_node)

	player = PLAYER.instantiate()
	player.position = Vector2(400, 260)
	add_child_autofree(player)
	await wait_seconds(1.5)

func after_each():
	# Release everything so state cannot leak between tests.
	for action in ["move_left", "move_right", "jump", "attack", "block", "dodge"]:
		Input.action_release(action)

func test_player_is_not_an_enemy():
	assert_false(player.is_enemy)

func test_move_right_action_produces_positive_velocity():
	Input.action_press("move_right", 1.0)
	await wait_physics_frames(3)
	assert_gt(player.velocity.x, 0.0)
	assert_true(player.facing_right)

func test_move_left_action_produces_negative_velocity():
	Input.action_press("move_left", 1.0)
	await wait_physics_frames(3)
	assert_lt(player.velocity.x, 0.0)
	assert_false(player.facing_right)

func test_full_stick_deflection_runs_at_640():
	Input.action_press("move_right", 1.0)
	await wait_physics_frames(3)
	assert_almost_eq(absf(player.velocity.x), 640.0, 1.0,
		"Input magnitude 1.0 > runThreshold 0.8 -> run speed")

func test_partial_deflection_walks_at_400():
	Input.action_press("move_right", 0.5)
	await wait_physics_frames(3)
	assert_almost_eq(absf(player.velocity.x), 400.0, 1.0,
		"Input magnitude 0.5 <= runThreshold 0.8 -> walk speed")

func test_jump_action_lifts_the_player():
	Input.action_press("jump")
	await wait_physics_frames(2)
	assert_lt(player.velocity.y, 0.0, "Jump should produce upward velocity")

func test_block_action_sets_blocking():
	Input.action_press("block")
	await wait_physics_frames(2)
	assert_true(player.is_blocking())

func test_releasing_block_clears_blocking():
	Input.action_press("block")
	await wait_physics_frames(2)
	Input.action_release("block")
	await wait_physics_frames(2)
	assert_false(player.is_blocking())

func test_no_input_leaves_the_player_stationary():
	await wait_physics_frames(3)
	assert_almost_eq(player.velocity.x, 0.0, 0.01)
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_player_controller.gd -gexit
```

Expected: FAIL — `player.tscn` does not exist.

- [ ] **Step 3: Implement the controller**

Create `godot/scenes/character/player_controller.gd`:

```gdscript
## Translates InputMap actions into Character calls.
##
## This node is the ONLY place in the project that reads input. It never
## touches a device — only named actions — so keyboard, gamepad and the
## touch joystick all arrive through the same path.
class_name PlayerController
extends Node

@onready var _character: Character = get_parent() as Character

func _ready() -> void:
	assert(_character != null, "PlayerController must be a child of a Character")

func _physics_process(_delta: float) -> void:
	if not _character.is_authority():
		return

	var axis := Input.get_axis("move_left", "move_right")
	_character.move_horizontal(axis, false)

	if Input.is_action_just_pressed("jump"):
		_character.try_jump()

	if Input.is_action_just_pressed("attack"):
		_character.perform_melee_attack()

	if Input.is_action_pressed("block"):
		_character.start_block()
	else:
		_character.stop_block()
```

- [ ] **Step 4: Create `player.tscn`**

Create `godot/scenes/character/player.tscn` as an inherited scene:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/character/character.tscn" id="1"]
[ext_resource type="Script" path="res://scenes/character/player_controller.gd" id="2"]

[node name="Player" instance=ExtResource("1")]
is_enemy = false

[node name="PlayerController" type="Node" parent="."]
script = ExtResource("2")

[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(1.2, 1.2)
position_smoothing_enabled = true
position_smoothing_speed = 5.0
```

Camera zoom `1.2` matches `GameConfig.cameraZoom`.

- [ ] **Step 5: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_player_controller.gd -gexit
```

Expected: PASS, 9 tests.

- [ ] **Step 6: Commit**

```bash
git add godot/scenes/character/player_controller.gd godot/scenes/character/player.tscn \
        godot/test/unit/test_player_controller.gd
git commit -m "feat(godot): player controller reading only InputMap actions"
```

---

### Task 13: Pure bot decision logic

**Files:**
- Create: `godot/scripts/world_snapshot.gd`, `godot/scripts/bot_decision.gd`
- Create: `godot/resources/bot_personality.gd`, `godot/resources/personalities/aggressive.tres`
- Test: `godot/test/unit/test_bot_decision.gd`

**Interfaces:**
- Consumes: nothing (pure)
- Produces: `BotDecision.decide(snapshot: WorldSnapshot, personality: BotPersonality) -> String` returning one of `"attack"`, `"approach"`, `"retreat"`, `"block"`, `"dodge"`, `"idle"`

**No node references.** `WorldSnapshot` is a plain `RefCounted` data bag built by the caller.

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_bot_decision.gd`:

```gdscript
extends GutTest

var aggressive: BotPersonality

func before_each():
	aggressive = load("res://resources/personalities/aggressive.tres") as BotPersonality

func _snapshot(
	distance: float, health_pct: float, stamina: float,
	target_attacking: bool = false, projectile_incoming: bool = false
) -> WorldSnapshot:
	var s := WorldSnapshot.new()
	s.distance_to_target = distance
	s.health_percent = health_pct
	s.stamina = stamina
	s.target_is_attacking = target_attacking
	s.projectile_incoming = projectile_incoming
	return s

func test_aggressive_personality_loads_with_dart_values():
	# smart_bot_ai.dart:41-48
	assert_almost_eq(aggressive.aggression, 0.9, 1e-6)
	assert_almost_eq(aggressive.caution, 0.2, 1e-6)
	assert_almost_eq(aggressive.stamina_reserve, 20.0, 1e-6)
	assert_almost_eq(aggressive.optimal_range, 150.0, 1e-6)
	assert_almost_eq(aggressive.retreat_threshold, 20.0, 1e-6)
	assert_almost_eq(aggressive.reaction_time, 0.15, 1e-6)

func test_attacks_when_in_reach_with_stamina():
	var s := _snapshot(50.0, 1.0, 100.0)
	assert_eq(BotDecision.decide(s, aggressive), "attack")

func test_approaches_when_target_is_far():
	var s := _snapshot(600.0, 1.0, 100.0)
	assert_eq(BotDecision.decide(s, aggressive), "approach")

func test_retreats_below_the_retreat_threshold():
	var s := _snapshot(50.0, 0.15, 100.0)
	assert_eq(BotDecision.decide(s, aggressive), "retreat",
		"health 15%% is below the 20%% retreat threshold")

func test_does_not_attack_below_the_stamina_reserve():
	var s := _snapshot(50.0, 1.0, 10.0)
	assert_ne(BotDecision.decide(s, aggressive), "attack",
		"Stamina 10 is under the reserve of 20")

func test_dodges_an_incoming_projectile():
	var s := _snapshot(200.0, 1.0, 100.0, false, true)
	assert_eq(BotDecision.decide(s, aggressive), "dodge")

func test_aggressive_prefers_attacking_over_blocking():
	# aggression 0.9 vs caution 0.2 — it should swing, not turtle.
	var s := _snapshot(50.0, 1.0, 100.0, true)
	assert_eq(BotDecision.decide(s, aggressive), "attack")

func test_a_cautious_personality_blocks_in_the_same_situation():
	var cautious := BotPersonality.new()
	cautious.aggression = 0.3
	cautious.caution = 0.9
	cautious.stamina_reserve = 40.0
	cautious.optimal_range = 350.0
	cautious.retreat_threshold = 30.0
	cautious.reaction_time = 0.10
	var s := _snapshot(50.0, 1.0, 100.0, true)
	assert_eq(BotDecision.decide(s, cautious), "block",
		"Same snapshot, different personality, different action")

func test_idles_when_nothing_applies():
	var s := _snapshot(200.0, 1.0, 5.0)
	assert_eq(BotDecision.decide(s, aggressive), "idle")
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_bot_decision.gd -gexit
```

Expected: FAIL — `Identifier "BotPersonality" not declared`.

- [ ] **Step 3: Define the personality resource**

Create `godot/resources/bot_personality.gd`:

```gdscript
## Bot AI personality parameters. Ported from the personality switch in
## modules/engine/lib/src/bot/smart_bot_ai.dart (lines 41-88).
##
## The seven Dart tactic classes are one algorithm parameterised seven ways;
## in Godot they are seven .tres files against one bot_decision.gd.
class_name BotPersonality
extends Resource

@export var personality_name: String = ""
@export var aggression: float = 0.6
@export var caution: float = 0.5
@export var stamina_reserve: float = 25.0
@export var optimal_range: float = 250.0
@export var retreat_threshold: float = 25.0
@export var reaction_time: float = 0.15
```

Create `godot/resources/personalities/aggressive.tres`:

```
[gd_resource type="Resource" script_class="BotPersonality" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/bot_personality.gd" id="1"]

[resource]
script = ExtResource("1")
personality_name = "Aggressive"
aggression = 0.9
caution = 0.2
stamina_reserve = 20.0
optimal_range = 150.0
retreat_threshold = 20.0
reaction_time = 0.15
```

- [ ] **Step 4: Define the snapshot**

Create `godot/scripts/world_snapshot.gd`:

```gdscript
## Plain data describing what a bot can perceive. Built by BotController
## and handed to BotDecision, so the decision logic never touches a node.
class_name WorldSnapshot
extends RefCounted

var distance_to_target: float = 0.0
var health_percent: float = 1.0
var stamina: float = 100.0
var target_is_attacking: bool = false
var target_is_blocking: bool = false
var projectile_incoming: bool = false
var is_grounded: bool = true
var melee_reach: float = 60.0
```

- [ ] **Step 5: Implement the decision function**

Create `godot/scripts/bot_decision.gd`:

```gdscript
## Pure bot action scoring. No nodes, no state, no side effects.
##
## Ported from the evaluator set in
## modules/engine/lib/src/bot/smart_bot_ai.dart. Each candidate action is
## scored and the highest wins; ties break in the declared order.
##
## The scoring weights ARE the game's feel. Do not retune them here — any
## change belongs in a .tres personality.
class_name BotDecision
extends RefCounted

static func decide(s: WorldSnapshot, p: BotPersonality) -> String:
	var scores := {
		"dodge": _score_dodge(s, p),
		"retreat": _score_retreat(s, p),
		"attack": _score_attack(s, p),
		"block": _score_block(s, p),
		"approach": _score_approach(s, p),
		"idle": 0.01,
	}

	var best := "idle"
	var best_score := 0.0
	for action in scores:
		if scores[action] > best_score:
			best_score = scores[action]
			best = action
	return best

static func _score_dodge(s: WorldSnapshot, p: BotPersonality) -> float:
	if not s.projectile_incoming:
		return 0.0
	if s.stamina < 20.0:
		return 0.0
	# Even a reckless personality dodges projectiles.
	return 0.9 + p.caution * 0.1

static func _score_retreat(s: WorldSnapshot, p: BotPersonality) -> float:
	if s.health_percent * 100.0 >= p.retreat_threshold:
		return 0.0
	return 0.8 + p.caution * 0.2

static func _score_attack(s: WorldSnapshot, p: BotPersonality) -> float:
	if s.distance_to_target >= s.melee_reach:
		return 0.0
	if s.stamina < p.stamina_reserve:
		return 0.0
	return 0.5 + p.aggression * 0.5

static func _score_block(s: WorldSnapshot, p: BotPersonality) -> float:
	if not s.target_is_attacking:
		return 0.0
	if s.distance_to_target > s.melee_reach * 2.0:
		return 0.0
	if s.stamina < 10.0:
		return 0.0
	return 0.4 + p.caution * 0.5

static func _score_approach(s: WorldSnapshot, p: BotPersonality) -> float:
	if s.distance_to_target <= s.melee_reach:
		return 0.0
	# The further past optimal range, the more urgent closing becomes.
	var gap := s.distance_to_target - p.optimal_range
	var urgency: float = clampf(gap / 400.0, 0.0, 1.0)
	return 0.2 + p.aggression * 0.4 + urgency * 0.2
```

- [ ] **Step 6: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_bot_decision.gd -gexit
```

Expected: PASS, 9 tests.

Check `test_a_cautious_personality_blocks_in_the_same_situation` specifically — it is the test that proves personality is actually parameterising behaviour rather than being ignored. Cautious: block scores `0.4 + 0.9×0.5 = 0.85`, attack scores `0.5 + 0.3×0.5 = 0.65`. Aggressive: block `0.4 + 0.2×0.5 = 0.5`, attack `0.5 + 0.9×0.5 = 0.95`.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/bot_decision.gd godot/scripts/world_snapshot.gd \
        godot/resources/bot_personality.gd godot/resources/personalities/ \
        godot/test/unit/test_bot_decision.gd
git commit -m "feat(godot): pure bot decision scoring with personality resources"
```

---

### Task 14: Enemy scene wiring the bot brain to the body

**Files:**
- Create: `godot/scenes/character/bot_controller.gd`, `godot/scenes/character/enemy.tscn`
- Test: `godot/test/unit/test_bot_controller.gd`

**Interfaces:**
- Consumes: `BotDecision`, `WorldSnapshot`, `BotPersonality`, `Character`
- Produces: `enemy.tscn` — a `Character` with `is_enemy = true` and a `BotController` child; `BotController.target: Character`

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_bot_controller.gd`:

```gdscript
extends GutTest

const ENEMY := preload("res://scenes/character/enemy.tscn")
const PLAYER := preload("res://scenes/character/player.tscn")
const PLATFORM := preload("res://scenes/platform/platform.tscn")

var enemy: Character
var player: Character

func before_each():
	var floor_node = PLATFORM.instantiate()
	floor_node.position = Vector2(0, 500)
	floor_node.size = Vector2(3000, 80)
	add_child_autofree(floor_node)

	player = PLAYER.instantiate()
	player.position = Vector2(400, 260)
	add_child_autofree(player)

	enemy = ENEMY.instantiate()
	enemy.position = Vector2(1200, 260)
	add_child_autofree(enemy)
	enemy.get_node("BotController").target = player

	await wait_seconds(1.5)

func test_enemy_is_flagged_as_an_enemy():
	assert_true(enemy.is_enemy)

func test_enemy_has_the_aggressive_personality():
	var p: BotPersonality = enemy.get_node("BotController").personality
	assert_not_null(p)
	assert_eq(p.personality_name, "Aggressive")

func test_enemy_closes_distance_to_a_distant_player():
	var start := enemy.global_position.distance_to(player.global_position)
	await wait_seconds(1.5)
	var now := enemy.global_position.distance_to(player.global_position)
	assert_lt(now, start, "An aggressive bot should close the gap")

func test_enemy_faces_the_player_while_approaching():
	await wait_seconds(0.5)
	# Player is to the left of the enemy, so it should face left.
	assert_false(enemy.facing_right)

func test_enemy_damages_the_player_once_in_range():
	enemy.position = Vector2(440, 260)
	await wait_seconds(2.0)
	assert_lt(player.health, 100.0,
		"An aggressive bot in reach should land a hit")

func test_decisions_are_throttled_by_reaction_time():
	var controller := enemy.get_node("BotController")
	var first := controller.decisions_made
	await wait_seconds(0.5)
	var made: int = controller.decisions_made - first
	# reaction_time 0.15s over 0.5s -> roughly 3-4 decisions, not 30.
	assert_between(made, 1, 8,
		"Expected throttled decisions, got %d" % made)
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_bot_controller.gd -gexit
```

Expected: FAIL — `enemy.tscn` does not exist.

- [ ] **Step 3: Implement the controller**

Create `godot/scenes/character/bot_controller.gd`:

```gdscript
## Drives a Character from BotDecision output.
##
## This node builds the WorldSnapshot and applies the chosen action; all
## judgement lives in the pure scripts/bot_decision.gd. Runs only on the
## authority, so in multiplayer the host simulates every enemy.
class_name BotController
extends Node

@export var personality: BotPersonality

var target: Character
var decisions_made: int = 0

var _cooldown: float = 0.0
var _action: String = "idle"

@onready var _character: Character = get_parent() as Character

func _ready() -> void:
	assert(_character != null, "BotController must be a child of a Character")

func _physics_process(delta: float) -> void:
	if not _character.is_authority():
		return
	if target == null or personality == null:
		return
	if _character.health <= 0.0:
		return

	_cooldown -= delta
	if _cooldown <= 0.0:
		_action = BotDecision.decide(_build_snapshot(), personality)
		decisions_made += 1
		_cooldown = personality.reaction_time

	_apply(_action)

func _build_snapshot() -> WorldSnapshot:
	var s := WorldSnapshot.new()
	s.distance_to_target = _character.global_position.distance_to(
		target.global_position
	)
	s.health_percent = _character.health / _character.stats.max_health
	s.stamina = _character.stamina
	s.target_is_attacking = not target.can_attack()
	s.target_is_blocking = target.is_blocking()
	s.projectile_incoming = false  # No projectiles in the slice (Knight is melee).
	s.is_grounded = _character.is_on_floor()
	s.melee_reach = Combat.melee_reach(
		_character.stats.attack_range, _character.combo
	)
	return s

func _apply(action: String) -> void:
	var dx := target.global_position.x - _character.global_position.x
	var toward: float = signf(dx)

	match action:
		"attack":
			_character.move_horizontal(0.0, false)
			_character.face(toward > 0.0)
			_character.perform_melee_attack()
		"approach":
			_character.stop_block()
			_character.move_horizontal(toward, false)
		"retreat":
			_character.stop_block()
			_character.move_horizontal(-toward, false)
		"block":
			_character.move_horizontal(0.0, false)
			_character.face(toward > 0.0)
			_character.start_block()
		"dodge":
			_character.move_horizontal(-toward, false)
		_:
			_character.move_horizontal(0.0, false)
			_character.stop_block()
```

- [ ] **Step 4: Add the `face()` helper to `character.gd`**

`move_horizontal` sets facing as a side effect of moving, but a stationary attacking bot still needs to turn. Add to `godot/scenes/character/character.gd`:

```gdscript
## Turn without moving. move_horizontal() also sets facing, but a bot that
## attacks while stationary needs to face its target independently.
func face(right: bool) -> void:
	facing_right = right
	_sprite.flip_h = not right
```

- [ ] **Step 5: Create `enemy.tscn`**

Create `godot/scenes/character/enemy.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="PackedScene" path="res://scenes/character/character.tscn" id="1"]
[ext_resource type="Script" path="res://scenes/character/bot_controller.gd" id="2"]
[ext_resource type="Resource" path="res://resources/personalities/aggressive.tres" id="3"]

[node name="Enemy" instance=ExtResource("1")]
is_enemy = true

[node name="BotController" type="Node" parent="."]
script = ExtResource("2")
personality = ExtResource("3")
```

- [ ] **Step 6: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_bot_controller.gd -gexit
```

Expected: PASS, 6 tests.

- [ ] **Step 7: Commit**

```bash
git add godot/scenes/character/bot_controller.gd godot/scenes/character/enemy.tscn \
        godot/scenes/character/character.gd godot/test/unit/test_bot_controller.gd
git commit -m "feat(godot): enemy scene driven by pure bot decision logic"
```

---

### Task 15: HUD

**Files:**
- Create: `godot/ui/hud.gd`, `godot/ui/hud.tscn`
- Test: `godot/test/unit/test_hud.gd`

**Interfaces:**
- Consumes: `Character` signals `health_changed`, `stamina_changed`, `combo_changed`
- Produces: `hud.tscn` with `bind(character: Character)`

The HUD reads via signals only. It never polls, and never writes character state.

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_hud.gd`:

```gdscript
extends GutTest

const HUD := preload("res://ui/hud.tscn")
const CHARACTER := preload("res://scenes/character/character.tscn")

var hud: Control
var character: Character

func before_each():
	character = CHARACTER.instantiate()
	add_child_autofree(character)
	hud = HUD.instantiate()
	add_child_autofree(hud)
	await wait_frames(2)
	hud.bind(character)

func test_health_bar_starts_full():
	var bar := hud.get_node("%HealthBar") as ProgressBar
	assert_almost_eq(bar.value, 100.0, 0.01)
	assert_almost_eq(bar.max_value, 100.0, 0.01)

func test_health_bar_follows_damage():
	character.apply_damage(24.0)
	await wait_frames(2)
	var bar := hud.get_node("%HealthBar") as ProgressBar
	assert_almost_eq(bar.value, 76.0, 0.01)

func test_stamina_bar_follows_a_jump():
	character.stamina = 100.0
	character.velocity = Vector2.ZERO
	# Spend stamina directly through the public path.
	character.stamina -= 20.0
	character.stamina_changed.emit(character.stamina, 100.0)
	await wait_frames(2)
	var bar := hud.get_node("%StaminaBar") as ProgressBar
	assert_almost_eq(bar.value, 80.0, 0.01)

func test_combo_label_hidden_at_zero():
	var label := hud.get_node("%ComboLabel") as Label
	assert_false(label.visible, "Combo label should hide when combo is 0")

func test_combo_label_shows_the_count():
	character.register_hit()
	character.register_hit()
	await wait_frames(2)
	var label := hud.get_node("%ComboLabel") as Label
	assert_true(label.visible)
	assert_string_contains(label.text, "2")

func test_health_bar_turns_red_at_low_health():
	character.apply_damage(85.0)  # 15% remaining
	await wait_frames(2)
	var bar := hud.get_node("%HealthBar") as ProgressBar
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	assert_almost_eq(fill.bg_color.r, 1.0, 0.05,
		"Below 20%% health the bar should be red")
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_hud.gd -gexit
```

Expected: FAIL — `hud.tscn` does not exist.

- [ ] **Step 3: Implement**

Create `godot/ui/hud.gd`:

```gdscript
## Health, stamina and combo readout.
##
## Signal-driven: it subscribes to the bound Character and never polls or
## writes character state. Colour thresholds match the Dart HUD
## (green -> orange -> red), with GameConfig.lowHealthThreshold = 0.2.
extends Control

const LOW_HEALTH := 0.2
const MID_HEALTH := 0.5

@onready var _health: ProgressBar = %HealthBar
@onready var _stamina: ProgressBar = %StaminaBar
@onready var _combo: Label = %ComboLabel

var _character: Character

func bind(character: Character) -> void:
	if _character != null:
		_character.health_changed.disconnect(_on_health_changed)
		_character.stamina_changed.disconnect(_on_stamina_changed)
		_character.combo_changed.disconnect(_on_combo_changed)

	_character = character
	character.health_changed.connect(_on_health_changed)
	character.stamina_changed.connect(_on_stamina_changed)
	character.combo_changed.connect(_on_combo_changed)

	_on_health_changed(character.health, character.stats.max_health)
	_on_stamina_changed(character.stamina, 100.0)
	_on_combo_changed(character.combo)

func _on_health_changed(current: float, maximum: float) -> void:
	_health.max_value = maximum
	_health.value = current
	var pct := current / maximum if maximum > 0.0 else 0.0
	var fill := _health.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		if pct <= LOW_HEALTH:
			fill.bg_color = Color(1.0, 0.2, 0.2)
		elif pct <= MID_HEALTH:
			fill.bg_color = Color(1.0, 0.6, 0.1)
		else:
			fill.bg_color = Color(0.2, 0.85, 0.3)

func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina.max_value = maximum
	_stamina.value = current

func _on_combo_changed(count: int) -> void:
	_combo.visible = count > 0
	_combo.text = "%d HIT COMBO" % count
```

Create `godot/ui/hud.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://ui/hud.gd" id="1"]

[sub_resource type="StyleBoxFlat" id="healthfill"]
bg_color = Color(0.2, 0.85, 0.3, 1)

[sub_resource type="StyleBoxFlat" id="staminafill"]
bg_color = Color(0.3, 0.6, 1, 1)

[node name="HUD" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("1")

[node name="Margin" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
theme_override_constants/margin_left = 40
theme_override_constants/margin_top = 40
theme_override_constants/margin_right = 40

[node name="Rows" type="VBoxContainer" parent="Margin"]
layout_mode = 2

[node name="HealthBar" type="ProgressBar" parent="Margin/Rows"]
unique_name_in_owner = true
custom_minimum_size = Vector2(320, 24)
layout_mode = 2
max_value = 100.0
value = 100.0
show_percentage = false
theme_override_styles/fill = SubResource("healthfill")

[node name="StaminaBar" type="ProgressBar" parent="Margin/Rows"]
unique_name_in_owner = true
custom_minimum_size = Vector2(320, 16)
layout_mode = 2
max_value = 100.0
value = 100.0
show_percentage = false
theme_override_styles/fill = SubResource("staminafill")

[node name="ComboLabel" type="Label" parent="Margin/Rows"]
unique_name_in_owner = true
layout_mode = 2
visible = false
text = "0 HIT COMBO"
```

`MarginContainer` uses `hudMargin = 40.0` from `GameConfig`. `unique_name_in_owner` is what makes the `%HealthBar` lookups in the test work.

- [ ] **Step 4: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_hud.gd -gexit
```

Expected: PASS, 6 tests.

If `test_health_bar_turns_red_at_low_health` fails because the stylebox is shared, call `_health.add_theme_stylebox_override("fill", fill.duplicate())` inside `bind()` before mutating it, and re-run.

- [ ] **Step 5: Commit**

```bash
git add godot/ui/ godot/test/unit/test_hud.gd
git commit -m "feat(godot): signal-driven HUD for health, stamina and combo"
```

---

### Task 16: Touch input via a virtual joystick

**Files:**
- Create: `godot/ui/virtual_joystick.gd`, `godot/ui/touch_controls.tscn`
- Test: `godot/test/unit/test_virtual_joystick.gd`

**Interfaces:**
- Consumes: `InputMap` actions
- Produces: `touch_controls.tscn`, visible only on touchscreen devices, feeding `move_left` / `move_right` / `jump` / `attack` through `Input.parse_input_event()`

This is the payoff for the InputMap indirection: no character or controller code changes.

- [ ] **Step 1: Write the failing test**

Create `godot/test/unit/test_virtual_joystick.gd`:

```gdscript
extends GutTest

const JOYSTICK := preload("res://ui/touch_controls.tscn")

var controls: Control

func before_each():
	controls = JOYSTICK.instantiate()
	add_child_autofree(controls)
	await wait_frames(2)

func after_each():
	for action in ["move_left", "move_right", "jump", "attack"]:
		Input.action_release(action)

func test_hidden_when_there_is_no_touchscreen():
	# CI and desktop have no touchscreen; the controls must not block input.
	if not DisplayServer.is_touchscreen_available():
		assert_false(controls.visible,
			"Touch controls must hide on non-touch devices")
	else:
		pass_test("Touchscreen present; visibility check not applicable")

func test_dragging_right_presses_move_right():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(1.0, 0.0))
	await wait_frames(2)
	assert_true(Input.is_action_pressed("move_right"))
	assert_almost_eq(Input.get_action_strength("move_right"), 1.0, 0.01)

func test_dragging_left_presses_move_left():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(-1.0, 0.0))
	await wait_frames(2)
	assert_true(Input.is_action_pressed("move_left"))

func test_partial_deflection_reports_partial_strength():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(0.5, 0.0))
	await wait_frames(2)
	assert_almost_eq(Input.get_action_strength("move_right"), 0.5, 0.05,
		"Analog strength must survive so walk-vs-run still works")

func test_recentering_releases_both_directions():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(1.0, 0.0))
	await wait_frames(2)
	stick.set_vector(Vector2.ZERO)
	await wait_frames(2)
	assert_false(Input.is_action_pressed("move_right"))
	assert_false(Input.is_action_pressed("move_left"))

func test_deadzone_is_ignored():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(0.1, 0.0))
	await wait_frames(2)
	assert_false(Input.is_action_pressed("move_right"),
		"0.1 is inside the 0.2 deadzone")
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_virtual_joystick.gd -gexit
```

Expected: FAIL — `touch_controls.tscn` does not exist.

- [ ] **Step 3: Implement**

Create `godot/ui/virtual_joystick.gd`:

```gdscript
## Touch stick that emits InputEventAction, so touch arrives through the
## same InputMap actions as keyboard and gamepad. Gameplay code cannot
## tell the difference — that is the whole point of the indirection.
class_name VirtualJoystick
extends Control

const DEADZONE := 0.2

var _vector: Vector2 = Vector2.ZERO
var _touch_index: int = -1

@onready var _knob: Control = $Knob

func _ready() -> void:
	# Hide on devices without touch so it never eats mouse clicks.
	visible = DisplayServer.is_touchscreen_available()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_update_from_position(event.position)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			set_vector(Vector2.ZERO)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_from_position(event.position)

func _update_from_position(local_position: Vector2) -> void:
	var radius: float = size.x / 2.0
	var offset := local_position - size / 2.0
	set_vector((offset / radius).limit_length(1.0))

## Sets the stick vector and republishes the movement actions.
## Public so tests can drive it without synthesising touch events.
func set_vector(v: Vector2) -> void:
	_vector = v
	if is_instance_valid(_knob):
		_knob.position = size / 2.0 + v * (size.x / 2.0) - _knob.size / 2.0
	_publish("move_right", maxf(0.0, v.x))
	_publish("move_left", maxf(0.0, -v.x))

func get_vector() -> Vector2:
	return _vector

func _publish(action: String, strength: float) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	if strength > DEADZONE:
		ev.pressed = true
		ev.strength = strength
	else:
		ev.pressed = false
		ev.strength = 0.0
	Input.parse_input_event(ev)

## Used by the on-screen buttons in touch_controls.tscn.
static func tap(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	down.strength = 1.0
	Input.parse_input_event(down)

static func release(action: String) -> void:
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
```

Create `godot/ui/touch_controls.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/virtual_joystick.gd" id="1"]

[node name="TouchControls" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="Joystick" type="Control" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 60.0
offset_top = -220.0
offset_right = 260.0
offset_bottom = -20.0
script = ExtResource("1")

[node name="Knob" type="Control" parent="Joystick"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 0
```

`joystickRadius = 50.0` in `GameConfig`; the 200×200 control gives a 100px radius with an 80px knob, which reads better on a phone.

The root `TouchControls` node stays visible while the `Joystick` child hides itself on non-touch devices, so `test_hidden_when_there_is_no_touchscreen` checks the child. Adjust the test's node path to `%Joystick` if it asserts against the root.

- [ ] **Step 4: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/unit/test_virtual_joystick.gd -gexit
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add godot/ui/virtual_joystick.gd godot/ui/touch_controls.tscn \
        godot/test/unit/test_virtual_joystick.gd
git commit -m "feat(godot): virtual joystick feeding InputMap actions"
```

---

### Task 17: Assemble the playable level

**Files:**
- Modify: `godot/scenes/maps/level_1.tscn` (add player, enemy, HUD, touch controls)
- Create: `godot/scenes/maps/level_1.gd`
- Test: `godot/test/integration/test_level_1_playable.gd`

**Interfaces:**
- Consumes: everything above
- Produces: a level that runs end to end — player spawns, enemy chases and fights, HUD updates

- [ ] **Step 1: Write the failing integration test**

Create `godot/test/integration/test_level_1_playable.gd`:

```gdscript
extends GutTest

const LEVEL := preload("res://scenes/maps/level_1.tscn")

var level: Node2D

func before_each():
	level = LEVEL.instantiate()
	add_child_autofree(level)
	await wait_seconds(2.0)

func after_each():
	for action in ["move_left", "move_right", "jump", "attack", "block"]:
		Input.action_release(action)

func test_player_spawns_at_the_marker():
	var player := level.get_node("Player") as Character
	assert_not_null(player)
	# Spawned at (200, 900); it will have fallen to a platform by now.
	assert_almost_eq(player.global_position.x, 200.0, 5.0)

func test_player_lands_on_a_platform_rather_than_falling_forever():
	var player := level.get_node("Player") as Character
	assert_true(player.is_on_floor(),
		"Player must come to rest on level geometry")

func test_enemy_exists_and_targets_the_player():
	var enemy := level.get_node("Enemy") as Character
	assert_not_null(enemy)
	assert_eq(enemy.get_node("BotController").target, level.get_node("Player"))

func test_hud_is_bound_to_the_player():
	var hud := level.get_node("HUD")
	var bar := hud.get_node("%HealthBar") as ProgressBar
	var player := level.get_node("Player") as Character
	player.apply_damage(10.0)
	await wait_frames(3)
	assert_almost_eq(bar.value, 90.0, 0.01)

func test_enemy_closes_on_the_player_over_time():
	var player := level.get_node("Player") as Character
	var enemy := level.get_node("Enemy") as Character
	var start := enemy.global_position.distance_to(player.global_position)
	await wait_seconds(2.0)
	var now := enemy.global_position.distance_to(player.global_position)
	assert_lt(now, start)

func test_player_input_moves_the_player():
	var player := level.get_node("Player") as Character
	var start_x := player.global_position.x
	Input.action_press("move_right", 1.0)
	await wait_seconds(0.5)
	assert_gt(player.global_position.x, start_x + 50.0)
```

- [ ] **Step 2: Run it and confirm failure**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/integration/test_level_1_playable.gd -gexit
```

Expected: FAIL — `level_1.tscn` has no `Player` node.

- [ ] **Step 3: Write the level script**

Create `godot/scenes/maps/level_1.gd`:

```gdscript
## Wires the slice together: moves the player to the spawn marker, points
## the enemy at the player, and binds the HUD.
extends Node2D

const ENEMY_SPAWN_OFFSET := Vector2(900, -100)

@onready var _player: Character = $Player
@onready var _enemy: Character = $Enemy
@onready var _hud: Control = $HUD/HUD
@onready var _spawn: Marker2D = $PlayerSpawn

func _ready() -> void:
	_player.global_position = _spawn.global_position
	_enemy.global_position = _spawn.global_position + ENEMY_SPAWN_OFFSET
	_enemy.get_node("BotController").target = _player
	_hud.bind(_player)
	_enemy.died.connect(_on_enemy_died)
	_player.died.connect(_on_player_died)

func _on_enemy_died() -> void:
	print("Enemy defeated")

func _on_player_died() -> void:
	print("Player defeated")
```

- [ ] **Step 4: Add the nodes to `level_1.tscn`**

Append to `godot/scenes/maps/level_1.tscn`, and add the matching `ext_resource` entries at the top (bumping `load_steps`):

```
[ext_resource type="Script" path="res://scenes/maps/level_1.gd" id="2"]
[ext_resource type="PackedScene" path="res://scenes/character/player.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/character/enemy.tscn" id="4"]
[ext_resource type="PackedScene" path="res://ui/hud.tscn" id="5"]
[ext_resource type="PackedScene" path="res://ui/touch_controls.tscn" id="6"]
```

Attach the script to the root node by adding `script = ExtResource("2")` under `[node name="level_1" type="Node2D"]`, then append:

```
[node name="Player" parent="." instance=ExtResource("3")]

[node name="Enemy" parent="." instance=ExtResource("4")]

[node name="HUD" type="CanvasLayer" parent="."]

[node name="HUD" parent="HUD" instance=ExtResource("5")]

[node name="TouchControls" parent="HUD" instance=ExtResource("6")]
```

The `CanvasLayer` keeps the HUD fixed while the `Camera2D` on the player moves.

- [ ] **Step 5: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/integration/test_level_1_playable.gd -gexit
```

Expected: PASS, 6 tests.

- [ ] **Step 6: Run the whole suite**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gdir=res://test -gexit
echo "exit: $?"
```

Expected: every suite passes, `exit: 0`.

- [ ] **Step 7: Play it**

```bash
godot --path godot
```

Move with A/D, jump with Space, attack with J, block with K. Confirm by eye: the Knight walks with a real 3-pose cycle, the enemy closes and hits you, the health bar drops and changes colour, the combo label appears on consecutive hits. Plug in a gamepad and confirm the left stick and A/X buttons work with no code change.

- [ ] **Step 8: Commit**

```bash
git add godot/scenes/maps/ godot/test/integration/
git commit -m "feat(godot): assemble playable level_1 vertical slice"
```

---

### Task 18: Two-peer multiplayer smoke test

**Files:**
- Test: `godot/test/integration/test_multiplayer_authority.gd`

**Interfaces:**
- Consumes: `Character.is_authority()`
- Produces: evidence that the authority model holds before three more characters inherit it

> **Why this task exists.** Multiplayer ships in Phase 6, but its constraint is imposed here in Phase 1. Spec §10 lists "a wrong authority model reaches back through every entity" as the top risk. This is the hour that de-risks it.

- [ ] **Step 1: Write the test**

Create `godot/test/integration/test_multiplayer_authority.gd`:

```gdscript
extends GutTest

const CHARACTER := preload("res://scenes/character/character.tscn")

var peer: ENetMultiplayerPeer

func after_each():
	if peer != null:
		peer.close()
		peer = null
	get_tree().get_multiplayer().multiplayer_peer = null

func test_without_a_peer_every_character_is_its_own_authority():
	var c := CHARACTER.instantiate()
	add_child_autofree(c)
	await wait_frames(2)
	assert_true(c.is_authority(),
		"Single-player must behave as fully authoritative")

func test_a_server_peer_can_be_created():
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(28970, 2)
	assert_eq(err, OK, "Failed to create an ENet server on port 28970")

func test_the_server_holds_authority_over_a_spawned_character():
	peer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_server(28971, 2), OK)
	get_tree().get_multiplayer().multiplayer_peer = peer
	await wait_frames(2)

	var c := CHARACTER.instantiate()
	add_child_autofree(c)
	await wait_frames(2)

	# Unique ID 1 is always the server.
	assert_eq(get_tree().get_multiplayer().get_unique_id(), 1)
	assert_true(c.is_authority(),
		"The server must hold authority over characters it spawns")

func test_a_non_authoritative_character_refuses_state_mutation():
	peer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_server(28972, 2), OK)
	get_tree().get_multiplayer().multiplayer_peer = peer
	await wait_frames(2)

	var c := CHARACTER.instantiate()
	add_child_autofree(c)
	await wait_frames(2)

	# Hand authority to a peer that is not us.
	c.set_multiplayer_authority(999)
	assert_false(c.is_authority())

	var before := c.health
	c.apply_damage(50.0)
	assert_almost_eq(c.health, before, 1e-6,
		"A non-authority must not mutate health locally")

	var stamina_before := c.stamina
	c.try_jump()
	assert_almost_eq(c.stamina, stamina_before, 1e-6,
		"A non-authority must not spend stamina locally")

func test_synchronizer_is_present_on_the_character_scene():
	var c := CHARACTER.instantiate()
	add_child_autofree(c)
	await wait_frames(2)
	assert_not_null(c.get_node_or_null("MultiplayerSynchronizer"),
		"Character must carry a MultiplayerSynchronizer from day one")
```

- [ ] **Step 2: Run it and confirm the synchronizer test fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/integration/test_multiplayer_authority.gd -gexit
```

Expected: the first four tests PASS, `test_synchronizer_is_present_on_the_character_scene` FAILS.

- [ ] **Step 3: Add the synchronizer to `character.tscn`**

Add to `godot/scenes/character/character.tscn`:

```
[sub_resource type="SceneReplicationConfig" id="repl"]
properties/0/path = NodePath(".:health")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:stamina")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:combo")
properties/2/spawn = true
properties/2/replication_mode = 1
properties/3/path = NodePath(".:position")
properties/3/spawn = true
properties/3/replication_mode = 1
properties/4/path = NodePath(".:facing_right")
properties/4/spawn = true
properties/4/replication_mode = 1

[node name="MultiplayerSynchronizer" type="MultiplayerSynchronizer" parent="."]
replication_config = SubResource("repl")
```

Bump `load_steps`. `replication_mode = 1` is "on change". These are exactly the properties §4.2 says the authority owns.

- [ ] **Step 4: Run the test and confirm it passes**

```bash
godot --headless --path godot --import
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gtest=res://test/integration/test_multiplayer_authority.gd -gexit
```

Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add godot/scenes/character/character.tscn godot/test/integration/test_multiplayer_authority.gd
git commit -m "test(godot): verify authority model and add MultiplayerSynchronizer

De-risks the Phase 6 constraint that Phase 1 imposes (spec section 10)."
```

---

### Task 19: Go/no-go report

**Files:**
- Create: `docs/superpowers/plans/2026-08-26-phase-1-go-no-go.md`

**Interfaces:**
- Consumes: the completed slice
- Produces: the decision record that gates Phases 2–7

- [ ] **Step 1: Run the full suite and capture real output**

```bash
cd /c/Users/dev/Projects/nomercy
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gdir=res://test -gexit 2>&1 | tail -20
echo "exit: $?"
```

- [ ] **Step 2: Play the slice and take notes**

```bash
godot --path godot
```

Spend at least ten minutes. Answer, in writing:

1. Does movement feel like the Flutter build, better, or worse?
2. Does the melee swing land where you expect at 60px reach?
3. Is the aggressive bot a credible opponent, or does it just walk into you?
4. Does combo scaling read on screen?
5. Does the gamepad feel right without any gamepad-specific code?
6. Anything that felt wrong and is not covered by a test?

- [ ] **Step 3: Write the report**

Create `docs/superpowers/plans/2026-08-26-phase-1-go-no-go.md` with:

- **Test results** — paste the actual GUT summary, not a description of it
- **LOC comparison** — `find godot -name '*.gd' -o -name '*.tscn' | xargs wc -l` against the Dart equivalents this replaced (`modules/gamepad` 789, the five platform classes ~830, `collision_system.dart`, `pool_manager.dart`, `sprite_utils.dart` 96)
- **Play-test answers** from Step 2
- **Surprises** — anything the design did not anticipate
- **Recommendation** — GO / NO-GO / GO WITH CHANGES, with reasoning
- **If GO:** what Phase 2's plan must account for that this one revealed

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/2026-08-26-phase-1-go-no-go.md
git commit -m "docs: Phase 1 vertical slice go/no-go report"
```

---

## Verification

The slice is complete when all of these hold:

```bash
cd /c/Users/dev/Projects/nomercy

# 1. Every test passes
godot --headless -s addons/gut/gut_cmdln.gd --path godot -gdir=res://test -gexit
echo "exit: $?"     # must be 0

# 2. No script in scripts/ touches a node
grep -rnE '\bNode\b|get_node|\$|preload\(' godot/scripts/ && \
  echo "VIOLATION: scripts/ must stay node-free" || echo "OK: scripts/ is pure"

# 3. Nothing reads a device directly
grep -rnE 'is_key_pressed|get_joy_|InputEventKey|joy_connection' \
  godot/scenes/ godot/ui/virtual_joystick.gd && \
  echo "VIOLATION: direct device read" || echo "OK: all input via InputMap"

# 4. The Dart tree is untouched
git diff --stat main -- lib/ modules/ | tail -1   # must be empty
```

**Manual gate:** the game runs via `godot --path godot`, the Knight moves and attacks, the enemy fights back, the HUD updates, and a gamepad works with no gamepad-specific code.

---

## Deferred to later phases

Explicitly **not** in this plan, per spec §9:

- Thief, Wizard, Trader; the other six bot personalities
- Projectiles (Knight is melee-only)
- Dodge and i-frames — `Stamina.can_dodge` exists, the action does not
- Landing recovery and hard-landing stun
- Wave system, game modes, items, chests, audio, achievements
- Procedural map generation and infinite chunk streaming — `map_invariants.json` is captured in Phase 4, not here
- The other 7 UI screens, theming, localization
- Actual networked play — Task 18 proves the authority model, it does not implement multiplayer
- **The `autoload/` layer** (`GameState`, `AudioService`, `EventBus`) from spec §3. The slice
  deliberately has no autoloads: every cross-node message it needs is a local signal on the
  emitting node (`health_changed` → HUD, `died` → level), which is exactly the ~50-of-60 case
  spec §4.3 describes. The global `EventBus` earns its place in Phase 3, when wave and
  achievement events arrive with no natural emitting node. Adding it now would be building the
  399-LOC Dart bus back before anything needs it.
