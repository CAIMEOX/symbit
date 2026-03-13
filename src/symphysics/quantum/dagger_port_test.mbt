///|
test "physics.quantum.dagger: parity" {
  inspect(
    try! @sympy_physics.physics_eval_str("Dagger(x, evaluate=False)"),
    content="Dagger(x)",
  )
  let i = @symcore.symbol("I")
  let matrix = try! @symphysics.explicit_matrix_from_rows([
    [@symcore.int(1), i],
    [@symcore.int(2), @symcore.int(-1) * i],
  ])
  try! quantum_test_assert_matrix_expr_equal(
    matrix_dagger(matrix),
    try! @sympy_physics.physics_eval_matrix("Dagger(Matrix([[1, I], [2, -I]]))"),
    2,
    2,
    "matrix dagger parity",
  )
}
