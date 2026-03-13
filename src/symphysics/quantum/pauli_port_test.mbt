///|
test "physics.quantum.pauli: parity" {
  let sx = sigma_x()
  let sy = sigma_y()
  let sm = sigma_minus()
  let sp = sigma_plus()

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("SigmaX()*SigmaZKet(0)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(
          @symcore.raw_mul([sx.as_expr(), (try! sigma_z_ket(0)).as_expr()]),
        ),
      ),
    ),
    "SigmaX qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("SigmaY()*SigmaZKet(1)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(
          @symcore.raw_mul([sy.as_expr(), (try! sigma_z_ket(1)).as_expr()]),
        ),
      ),
    ),
    "SigmaY qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_doit_str(
      "InnerProduct(SigmaZBra(1), SigmaZKet(1))",
    ),
    @symprint.to_string(
      inner_product(
        (try! sigma_z_bra(1)).as_expr(),
        (try! sigma_z_ket(1)).as_expr(),
      ),
    ),
    "SigmaZ inner product parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("Dagger(SigmaPlus())"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(dagger(sp.as_expr())),
    ),
    "SigmaPlus dagger parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("qsimplify_pauli(SigmaX()*SigmaY())"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qsimplify_pauli(@symcore.raw_mul([sx.as_expr(), sy.as_expr()])),
      ),
    ),
    "qsimplify parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "Commutator(SigmaX(), SigmaY()).doit()",
    ),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(commutator(sx.as_expr(), sy.as_expr())),
    ),
    "commutator parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "AntiCommutator(SigmaMinus(), SigmaPlus()).doit()",
    ),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(anticommutator(sm.as_expr(), sp.as_expr())),
    ),
    "anticommutator parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(sy.as_expr()),
    try! @sympy_physics.physics_eval_matrix("represent(SigmaY())"),
    2,
    2,
    "represent SigmaY parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix((try! sigma_z_ket(1)).as_expr()),
    try! @sympy_physics.physics_eval_matrix("represent(SigmaZKet(1))"),
    2,
    1,
    "represent SigmaZKet parity",
  )
}
