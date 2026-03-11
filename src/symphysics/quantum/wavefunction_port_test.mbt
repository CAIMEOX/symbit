///|
test "physics.quantum.wavefunction: parity" {
  let n = @symcore.symbol("n")
  let x = @symcore.symbol("x")
  let wf = wavefunction(x ^ @symcore.int(2), [x])
  let f_of_x = @symcore.raw_function("f", [x])
  let dop = differential_operator(
    @symcore.raw_function("Derivative", [f_of_x, x]),
    f_of_x,
  )
  let dop2 = differential_operator(
    @symcore.raw_mul([
      @symcore.raw_pow(x, @symcore.int(-1)),
      @symcore.raw_function("Derivative", [f_of_x, x]),
    ]),
    f_of_x,
  )

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_doit_str("InnerProduct(OrthogonalBra(n), OrthogonalKet(n))"),
    @symprint.to_string(inner_product(orthogonal_bra([n]).as_expr(), orthogonal_ket([n]).as_expr())),
    "orthogonal equal parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_doit_str("InnerProduct(OrthogonalBra(n), OrthogonalKet(n + 1))"),
    @symprint.to_string(
      inner_product(
        orthogonal_bra([n]).as_expr(),
        orthogonal_ket([n + @symcore.int(1)]).as_expr(),
      ),
    ),
    "orthogonal shifted parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("Dagger(Wavefunction(x**2, x))"),
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(dagger(wf.as_expr()))),
    "wavefunction dagger parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("Wavefunction(x**2, x).prob()"),
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(wf.prob().as_expr())),
    "wavefunction prob parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("DifferentialOperator(Derivative(wf(x), x), wf(x))*Wavefunction(x**2, x)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([dop.as_expr(), wf.as_expr()]))),
    ),
    "differential operator qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("DifferentialOperator(x**(-1)*Derivative(wf(x), x), wf(x))*Wavefunction(x**2, x)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([dop2.as_expr(), wf.as_expr()]))),
    ),
    "scaled differential operator qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("represent(Wavefunction(x**2, x))"),
    try! @sympy_physics.quantum_eval_str(matrix_scalar_value_to_string(try! represent(wf.as_expr()))),
    "represent wavefunction parity",
  )
}
