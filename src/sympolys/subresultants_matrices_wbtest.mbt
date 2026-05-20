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
fn subres_mat_wb_row(values : Array[Int]) -> Array[FieldElem] raise PolyError {
  let row : Array[FieldElem] = []
  for value in values {
    row.push(fe_from_int(value, Domain::ZZ))
  }
  row
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
test "subresultants matrices wb: correct sign and create_ma" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.Expr::Symbol("x")
  let p = b.from_expr(
    (x ^ @symcore.int(3)) - @symcore.int(2) * x + @symcore.int(1),
  )
  let q = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  let s1 = sylvester(p, q)
  inspect(correct_sign(3, 2, s1, 1, 0).to_string(), content="-1")
  inspect(correct_sign(3, 2, s1, 1, 1).to_string(), content="1")
  inspect(
    create_ma(
      4,
      2,
      subres_mat_wb_row([1, 2, 3, 4, 5, 6]),
      subres_mat_wb_row([6, 5, 4, 3, 2, 1]),
      6,
    ).to_matrix_string(),
    content="Matrix([[1, 2, 3, 4, 5, 6], [6, 1, 2, 3, 4, 5], [5, 6, 1, 2, 3, 4], [6, 5, 4, 3, 2, 1]])",
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
