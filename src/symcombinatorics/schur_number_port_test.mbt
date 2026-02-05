///|
test "combinatorics schur_number values parity" {
  let k0 = 0
  match schur_number(k0) {
    Some(v) =>
      assert_oracle(try? @sympy_combinatorics.schur_number_equiv(k0, true, v))
    None =>
      assert_oracle(try? @sympy_combinatorics.schur_number_equiv(k0, false, 0))
  }

  let k3 = 3
  match schur_number(k3) {
    Some(v) =>
      assert_oracle(try? @sympy_combinatorics.schur_number_equiv(k3, true, v))
    None =>
      assert_oracle(try? @sympy_combinatorics.schur_number_equiv(k3, false, 0))
  }

  let k6 = 6
  match schur_number(k6) {
    Some(v) =>
      assert_oracle(try? @sympy_combinatorics.schur_number_equiv(k6, true, v))
    None =>
      assert_oracle(try? @sympy_combinatorics.schur_number_equiv(k6, false, 0))
  }
}

///|
test "combinatorics schur_number lower_bound parity" {
  assert_oracle(try? @sympy_combinatorics.schur_number_lower_bound_equiv(6, schur_number_lower_bound(6)))
  assert_oracle(try? @sympy_combinatorics.schur_number_lower_bound_equiv(7, schur_number_lower_bound(7)))
}

///|
test "combinatorics schur_partition parity" {
  let p5 = schur_partition(5)
  assert_oracle(try? @sympy_combinatorics.schur_partition_equiv(5, p5))
  let p8 = schur_partition(8)
  assert_oracle(try? @sympy_combinatorics.schur_partition_equiv(8, p8))
}
