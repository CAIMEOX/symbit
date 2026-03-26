///|
test "physics.quantum.dagger and tensorproduct: parity" {
  assert_eq(
    @symprint.to_string(dagger(@symcore.Expr::Symbol("x"), evaluate=false)),
    "Dagger(x)",
  )

  let mat = @symphysics.explicit_matrix_from_rows([
    [@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), @symcore.Expr::Symbol("x") * @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)],
    [@symcore.int(2), @symcore.int(4)],
  ])
  quantum_test_assert_matrix_expr_equal(
    matrix_dagger(mat),
    physics_eval_matrix("Dagger(Matrix([[I, x*I], [2, 4]]))"),
    2,
    2,
    "matrix dagger parity",
  )

  let sigma_x = @symphysics.msigma(1)
  quantum_test_assert_matrix_expr_equal(
    tensor_product_matrix([sigma_x, matrix_eye(2)]),
    physics_eval_matrix("TensorProduct(Matrix([[0, 1], [1, 0]]), eye(2))"),
    4,
    4,
    "tensor-product matrix parity",
  )
}
