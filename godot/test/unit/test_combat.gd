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
