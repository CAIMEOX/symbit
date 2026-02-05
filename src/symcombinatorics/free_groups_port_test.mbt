///|
test "free groups basic operations parity" {
  let (free_group, _) = free_group("x, y")
  let symbols = free_group.symbols()
  let form_a : Array[(Int, Int)] = [(0, 2), (1, -1)]
  let form_b : Array[(Int, Int)] = [(1, 2), (0, -1)]
  let w1 = free_group_element_from_form(free_group, form_a)
  let w2 = free_group_element_from_form(free_group, form_b)
  let prod = try! w1.mul(w2)
  assert_oracle(
    try? @sympy_combinatorics.free_group_mul_equiv(
      symbols,
      form_a,
      form_b,
      prod.array_form(),
    ),
  )
  let inv = w1.inverse()
  assert_oracle(
    try? @sympy_combinatorics.free_group_inverse_equiv(
      symbols,
      form_a,
      inv.array_form(),
    ),
  )
  let pow = try! w1.pow(3)
  assert_oracle(
    try? @sympy_combinatorics.free_group_pow_equiv(
      symbols,
      form_a,
      3,
      pow.array_form(),
    ),
  )
  let sub = try! w1.subword(1, 3)
  assert_oracle(
    try? @sympy_combinatorics.free_group_subword_equiv(
      symbols,
      form_a,
      1,
      3,
      sub.array_form(),
    ),
  )
}
