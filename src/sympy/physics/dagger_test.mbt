///|
test "physics.quantum.dagger: symbolic and matrix subset" {
  let a = @symcore.Expr::Symbol("A")
  let b = @symcore.Expr::Symbol("B")
  inspect(@symprint.to_string(dagger(a, evaluate=false)), content="Dagger(A)")
  inspect(
    @symprint.to_string(dagger(@symcore.raw_mul([a, b]))),
    content="conjugate(B)*conjugate(A)",
  )

  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let matrix = @symphysics.explicit_matrix_from_rows([
    [@symcore.int(1), i],
    [@symcore.int(2), @symcore.int(-1) * i],
  ])
  quantum_test_assert_matrix_expr_equal(
    matrix_dagger(matrix),
    ["1", "2", "-I", "I"],
    2,
    2,
    "matrix dagger local",
  )
}
