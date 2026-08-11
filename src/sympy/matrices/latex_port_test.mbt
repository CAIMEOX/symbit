///|
test "matrices latex parity for dense sparse and matrix expressions" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let dense = @symmatrices.matrix([[x, @symcore.int(1)], [@symcore.int(0), y]])
  assert_eq(dense.latex(), matrix_latex(dense))

  let sparse_entries : Map[(Int, Int), @symcore.Expr] = Map([])
  sparse_entries[(0, 0)] = x
  sparse_entries[(0, 1)] = @symcore.int(1)
  sparse_entries[(1, 1)] = y
  let sparse = @symmatrices.sparse_matrix(2, 2, sparse_entries) catch {
    _ => fail("sparse")
  }
  assert_eq(sparse.latex(), sparse_matrix_latex(sparse))

  let a = @symmatrices.matrix_symbol("A", 2, 2)
  let b = @symmatrices.matrix_symbol("B", 2, 2)
  let cases = [
    a,
    @symmatrices.mat_add([a, b]),
    @symmatrices.mat_mul([a, b]),
    @symmatrices.matrix_expr_transpose(a),
    @symmatrices.matrix_expr_inverse(a),
    @symmatrices.matrix_expr_pow(@symmatrices.mat_mul([a, b]), 2),
    @symmatrices.identity_expr(2),
    @symmatrices.zero_matrix_expr(2, 3),
    @symmatrices.block_diag_matrix_expr([a, b]),
    @symmatrices.block_matrix_expr([[a, b], [b, a]]),
  ]
  for item in cases {
    assert_eq(item.latex(), matrix_expr_latex(item))
  }
}
