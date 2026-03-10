///|
test "physics.quantum.cg: symbolic constructor parity" {
  let half = quantum_test_frac(1, 2)
  try! quantum_test_assert_string_equal(
    @symprint.to_string(wigner3j(@symcore.int(6), @symcore.int(0), @symcore.int(4), @symcore.int(0), @symcore.int(2), @symcore.int(0)).as_expr()),
    try! @sympy_physics.quantum_wigner3j_expr(@symcore.int(6), @symcore.int(0), @symcore.int(4), @symcore.int(0), @symcore.int(2), @symcore.int(0)),
    "Wigner3j expr",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(cg(half, half, half, @symcore.int(-1) * half, @symcore.int(1), @symcore.int(0)).as_expr()),
    try! @sympy_physics.quantum_cg_expr(half, half, half, @symcore.int(-1) * half, @symcore.int(1), @symcore.int(0)),
    "CG expr",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(wigner6j(@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(2), @symcore.int(1), @symcore.int(2)).as_expr()),
    try! @sympy_physics.quantum_wigner6j_expr(@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(2), @symcore.int(1), @symcore.int(2)),
    "Wigner6j expr",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(wigner9j(@symcore.int(2), @symcore.int(1), @symcore.int(1), quantum_test_frac(3, 2), half, @symcore.int(1), half, half, @symcore.int(0)).as_expr()),
    try! @sympy_physics.quantum_wigner9j_expr(@symcore.int(2), @symcore.int(1), @symcore.int(1), quantum_test_frac(3, 2), half, @symcore.int(1), half, half, @symcore.int(0)),
    "Wigner9j expr",
  )
}

///|
test "physics.quantum.cg: doit parity" {
  let half = quantum_test_frac(1, 2)
  try! quantum_test_assert_expr_equal(
    try! wigner3j(half, @symcore.int(-1) * half, half, half, @symcore.int(0), @symcore.int(0)).doit(),
    try! @sympy_physics.quantum_wigner3j_doit(half, @symcore.int(-1) * half, half, half, @symcore.int(0), @symcore.int(0)),
    "Wigner3j.doit",
  )
  try! quantum_test_assert_expr_equal(
    try! cg(half, half, half, @symcore.int(-1) * half, @symcore.int(1), @symcore.int(0)).doit(),
    try! @sympy_physics.quantum_cg_doit(half, half, half, @symcore.int(-1) * half, @symcore.int(1), @symcore.int(0)),
    "CG.doit",
  )
  try! quantum_test_assert_expr_equal(
    try! wigner6j(@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(2), @symcore.int(1), @symcore.int(2)).doit(),
    try! @sympy_physics.quantum_wigner6j_doit(@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(2), @symcore.int(1), @symcore.int(2)),
    "Wigner6j.doit",
  )
  try! quantum_test_assert_expr_equal(
    try! wigner9j(@symcore.int(2), @symcore.int(1), @symcore.int(1), quantum_test_frac(3, 2), half, @symcore.int(1), half, half, @symcore.int(0)).doit(),
    try! @sympy_physics.quantum_wigner9j_doit(@symcore.int(2), @symcore.int(1), @symcore.int(1), quantum_test_frac(3, 2), half, @symcore.int(1), half, half, @symcore.int(0)),
    "Wigner9j.doit",
  )
}
