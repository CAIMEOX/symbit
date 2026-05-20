///|
fn subres_mat_wb_pair() -> (Poly, Poly) raise PolyError {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.Expr::Symbol("x")
  (
    b.from_expr((x ^ @symcore.int(2)) + @symcore.int(1)),
    b.from_expr(x + @symcore.int(1)),
  )
}

///|
test "subresultants matrices wb: backward eye" {
  inspect(
    backward_eye(3).to_matrix_string(),
    content="Matrix([[0, 0, 1], [0, 1, 0], [1, 0, 0]])",
  )
}

///|
test "subresultants matrices wb: sylvester matrices" {
  let (p, q) = subres_mat_wb_pair()
  inspect(
    sylvester(p, q).to_matrix_string(),
    content="Matrix([[1, 0, 1], [1, 1, 0], [0, 1, 1]])",
  )
  inspect(
    sylvester(p, q, kind=2).to_matrix_string(),
    content="Matrix([[1, 0, 1, 0], [0, 1, 1, 0], [0, 1, 0, 1], [0, 0, 1, 1]])",
  )
}

///|
test "subresultants matrices wb: bezout matrices" {
  let (p, q) = subres_mat_wb_pair()
  inspect(bezout(p, q).to_matrix_string(), content="Matrix([[-1, 1], [1, 1]])")
  inspect(
    bezout(p, q, kind="prs").to_matrix_string(),
    content="Matrix([[1, 1], [1, -1]])",
  )
}
