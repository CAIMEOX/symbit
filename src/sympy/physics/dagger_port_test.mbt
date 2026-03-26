///|
test "physics.quantum.dagger: parity" {
  inspect(physics_eval_str("Dagger(x, evaluate=False)"), content="Dagger(x)")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let matrix = @symphysics.explicit_matrix_from_rows([
    [@symcore.int(1), i],
    [@symcore.int(2), @symcore.int(-1) * i],
  ])
  quantum_test_assert_matrix_expr_equal(
    matrix_dagger(matrix),
    physics_eval_matrix("Dagger(Matrix([[1, I], [2, -I]]))"),
    2,
    2,
    "matrix dagger parity",
  )
}
