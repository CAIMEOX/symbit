///|
test "physics.quantum.qexpr/state/operator: parity" {
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(qexpr([@symcore.int(0)]).as_expr())),
    "0",
    "QExpr str",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_srepr_str(@symprint.to_string(qexpr([@symcore.int(0), @symcore.int(1)]).as_expr())),
    try! @sympy_physics.quantum_srepr_str("QExpr(0, 1)"),
    "QExpr srepr",
  )

  let k = ket([@symcore.symbol("k")])
  let b = bra([@symcore.symbol("b")])
  let t = time_dep_ket([@symcore.int(0)], @symcore.symbol("t"))
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(k.as_expr())),
    "|k>",
    "Ket str",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_srepr_str(@symprint.to_string(b.as_expr())),
    try! @sympy_physics.quantum_srepr_str("Bra(b)"),
    "Bra srepr",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(t.as_expr())),
    "|0;t>",
    "TimeDepKet str",
  )

  let a = operator([@symcore.symbol("A")])
  let h = hermitian_operator([@symcore.symbol("Hh")])
  let u = unitary_operator([@symcore.symbol("Uu")])
  let id = identity_operator(dimension=@symcore.int(3))
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(a.as_expr())),
    "A",
    "Operator str",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(dagger(h.as_expr()))),
    "Hh",
    "Hermitian dagger",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(dagger(u.as_expr()))),
    "Uu**(-1)",
    "Unitary dagger",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(id.as_expr())),
    "I",
    "IdentityOperator str",
  )
}
