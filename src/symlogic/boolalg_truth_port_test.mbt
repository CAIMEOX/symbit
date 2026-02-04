///|
test "boolalg truth_table and term conversions" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let rows = truth_table(bool_implies(x, y), [x, y])
  let expected : Array[TruthTableRow] = [
    TruthTableRow::WithInput([0, 0], true),
    TruthTableRow::WithInput([0, 1], true),
    TruthTableRow::WithInput([1, 0], false),
    TruthTableRow::WithInput([1, 1], true),
  ]
  assert_eq(rows, expected)
  assert_eq(term_to_integer_bits([1, 0, 0]), 4)
  assert_eq(term_to_integer_str("100"), 4)
}

///|
test "boolalg minterm/maxterm/monomial parity" {
  let vars = [bool_symbol("x"), bool_symbol("y"), bool_symbol("z")]
  let min_bits = bool_minterm(BitPattern::Bits([1, 0, 1]), vars)
  assert_eq(
    to_string(min_bits),
    try! @sympy_logic.boolalg_bool_minterm_bits(["x", "y", "z"], [1, 0, 1]),
  )
  let min_idx = bool_minterm(BitPattern::Index(6), vars)
  assert_eq(
    to_string(min_idx),
    try! @sympy_logic.boolalg_bool_minterm_int(["x", "y", "z"], 6),
  )
  let max_bits = bool_maxterm(BitPattern::Bits([1, 0, 1]), vars)
  assert_eq(
    to_string(max_bits),
    try! @sympy_logic.boolalg_bool_maxterm_bits(["x", "y", "z"], [1, 0, 1]),
  )
  let max_idx = bool_maxterm(BitPattern::Index(6), vars)
  assert_eq(
    to_string(max_idx),
    try! @sympy_logic.boolalg_bool_maxterm_int(["x", "y", "z"], 6),
  )
  let mono_bits = bool_monomial(BitPattern::Bits([1, 0, 1]), vars)
  assert_eq(
    to_string(mono_bits),
    try! @sympy_logic.boolalg_bool_monomial_bits(["x", "y", "z"], [1, 0, 1]),
  )
  let mono_idx = bool_monomial(BitPattern::Index(6), vars)
  assert_eq(
    to_string(mono_idx),
    try! @sympy_logic.boolalg_bool_monomial_int(["x", "y", "z"], 6),
  )
}

///|
test "boolalg to_int_repr basic" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let clauses = [bool_or([x, y]), y]
  let repr = to_int_repr(clauses, [x, y])
  assert_eq(repr, [[1, 2], [2]])
}
