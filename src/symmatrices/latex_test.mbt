///|
test "matrices latex renders dense sparse and expression forms" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let dense = matrix([[x, @symcore.int(1)], [@symcore.int(0), y]])
  inspect(
    dense.latex(),
    content="\\left[\\begin{matrix}x & 1\\\\0 & y\\end{matrix}\\right]",
  )
  let sparse_entries : Map[(Int, Int), @symcore.Expr] = Map([])
  sparse_entries[(0, 0)] = x
  sparse_entries[(0, 1)] = @symcore.int(1)
  sparse_entries[(1, 1)] = y
  let sparse = sparse_matrix(2, 2, sparse_entries) catch { _ => fail("sparse") }
  inspect(
    sparse.latex(),
    content="\\left[\\begin{matrix}x & 1\\\\0 & y\\end{matrix}\\right]",
  )

  let a = matrix_symbol("A", 2, 2)
  let b = matrix_symbol("B", 2, 2)
  inspect(a.latex(), content="A")
  inspect(mat_add([a, b]).latex(), content="A + B")
  inspect(mat_mul([a, b]).latex(), content="A B")
  inspect(matrix_expr_transpose(a).latex(), content="A^{T}")
  inspect(matrix_expr_inverse(a).latex(), content="A^{-1}")
  inspect(
    matrix_expr_pow(mat_mul([a, b]), 2).latex(),
    content="\\left(A B\\right)^{2}",
  )
  inspect(identity_expr(2).latex(), content="\\mathbb{I}")
  inspect(zero_matrix_expr(2, 3).latex(), content="0")
  inspect(
    block_diag_matrix_expr([a, b]).latex(),
    content="\\left[\\begin{matrix}A & 0\\\\0 & B\\end{matrix}\\right]",
  )
  inspect(
    block_matrix_expr([[a, b], [b, a]]).latex(),
    content="\\left[\\begin{matrix}A & B\\\\B & A\\end{matrix}\\right]",
  )
}
