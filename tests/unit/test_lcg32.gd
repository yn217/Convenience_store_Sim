extends RefCounted
## 10_TEST_VECTORS §E / 09 §1


func test_seed1_first_state(t, _tree) -> void:
	var rng := Lcg32.new(1)
	t.eq(rng.next_state(), 1015568748, "LCG32(seed=1) first state")


func test_seed0_is_valid_and_deterministic(t, _tree) -> void:
	var a := Lcg32.new(0)
	var b := Lcg32.new(0)
	t.eq(a.next_state(), 1013904223, "seed 0 first state")
	t.eq(b.next_state(), a.state, "same seed same state")


func test_state_stays_32bit_and_uniform_in_range(t, _tree) -> void:
	var rng := Lcg32.new(4294967295)
	for i in 1000:
		var u := rng.uniform_0_1()
		t.ok(u >= 0.0 and u < 1.0, "uniform in [0,1)")
		t.ok(rng.state >= 0 and rng.state < Lcg32.MODULUS, "state in 32bit range")
