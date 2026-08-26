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
