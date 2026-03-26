///|
test "physics.quantum.dagger: symbolic and matrix behaviors" {
  assert_eq(
    @symprint.to_string(dagger(@symcore.Expr::Symbol("x"), evaluate=false)),
    "Dagger(x)",
  )
  assert_eq(
    @symprint.to_string(
      dagger(@symcore.raw_mul([@symcore.Expr::Symbol("a"), @symcore.Expr::Symbol("b")])),
    ),
    "conjugate(b)*conjugate(a)",
  )

  let mat = @symphysics.explicit_matrix_from_rows([
    [@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), @symcore.int(2) * @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)],
    [@symcore.int(0), @symcore.int(1)],
  ])
  quantum_test_assert_matrix_expr_equal(
    matrix_dagger(mat),
    ["-I", "0", "-2*I", "1"],
    2,
    2,
    "matrix dagger",
  )
}

///|
test "physics.quantum.tensorproduct: symbolic wrapper and matrix behavior" {
  let tp = @symquant.tensor_product([
    @symcore.Expr::Symbol("a") + @symcore.Expr::Symbol("b"),
    @symcore.Expr::Symbol("c"),
  ])
  assert_eq(tp.to_string(), "(a + b)xc")
  assert_eq(
    tp.dagger().to_string(),
    "(conjugate(a) + conjugate(b))xconjugate(c)",
  )

  let sigma_x = @symphysics.msigma(1)
  quantum_test_assert_matrix_equal(
    tensor_product_matrix([sigma_x, matrix_eye(2)]),
    [
      "0", "0", "1", "0", "0", "0", "0", "1", "1", "0", "0", "0", "0", "1", "0",
      "0",
    ],
    4,
    4,
    "tensor-product matrix",
  )
}
