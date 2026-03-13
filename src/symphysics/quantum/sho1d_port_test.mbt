///|
test "physics.quantum.sho1d: parity" {
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("Dagger(RaisingOp(a))"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(dagger(raising_op())),
    ),
    "raising adjoint parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_doit_str(
      "Commutator(RaisingOp(a), LoweringOp(a))",
    ),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(commutator(raising_op(), lowering_op())),
    ),
    "sho commutator parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("RaisingOp(a)*SHOKet(1)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([raising_op(), sho_ket(@symcore.int(1))])),
      ),
    ),
    "sho qapply parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(raising_op(), basis=Some(number_op()), ndim=4),
    try! @sympy_physics.quantum_represent_matrix(
      "RaisingOp(a)", "NumberOp(n)", 4,
    ),
    4,
    4,
    "raising matrix parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(sho_hamiltonian(), basis=Some(number_op()), ndim=4),
    try! @sympy_physics.quantum_represent_matrix(
      "Hamiltonian(d)", "NumberOp(n)", 4,
    ),
    4,
    4,
    "Hamiltonian matrix parity",
  )
}
