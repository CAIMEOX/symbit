///|
test "physics.quantum.spin: parity" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("Jz*JzKet(1, 1)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([jz(), jz_ket(one, one).as_expr()]))),
    ),
    "Jz qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("Jplus*JzKet(1, 0)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([jplus(), jz_ket(one, @symcore.int(0)).as_expr()]))),
    ),
    "Jplus qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("Dagger(Jplus)"),
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(dagger(jplus()))),
    "spin dagger parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("Commutator(Jx, Jy).doit()"),
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(commutator(jx(), jy()))),
    "spin commutator parity",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jz(), spin_j=half),
    try! @sympy_physics.physics_eval_matrix("represent(Jz, j=Rational(1, 2))"),
    2,
    2,
    "represent Jz parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jplus(), spin_j=one),
    try! @sympy_physics.physics_eval_matrix("represent(Jplus, j=1)"),
    3,
    3,
    "represent Jplus parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jz_ket(one, @symcore.int(0)).as_expr()),
    try! @sympy_physics.physics_eval_matrix("represent(JzKet(1, 0))"),
    3,
    1,
    "represent JzKet parity",
  )
}
