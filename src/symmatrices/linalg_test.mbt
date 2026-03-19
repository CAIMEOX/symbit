///|
fn vecs_to_string(values : Array[Array[Expr]]) -> String {
  let rows : Array[String] = []
  for row in values {
    rows.push("[" + row.map(@symprint.to_string).join(", ") + "]")
  }
  "[" + rows.join(", ") + "]"
}

///|
test "matrices determinant inverse and solve" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  inspect(@symprint.to_string(a.det()), content="-2")
  inspect(a.inv().to_string(), content="Matrix([[-2, 1], [3/2, -1/2]])")
  let rhs = matrix([[@symcore.int(5)], [@symcore.int(11)]])
  inspect(a.solve(rhs).to_string(), content="Matrix([[1], [2]])")
}

///|
test "matrices rref rank rowspace columnspace nullspace" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
    [@symcore.int(2), @symcore.int(4), @symcore.int(6)],
  ])
  let (rref, pivots) = a.rref()
  inspect(rref.to_string(), content="Matrix([[1, 2, 3], [0, 0, 0]])")
  inspect(pivots, content="[0]")
  assert_eq(a.rank(), 1)
  inspect(vecs_to_string(a.rowspace()), content="[[1, 2, 3]]")
  inspect(vecs_to_string(a.columnspace()), content="[[1, 2]]")
  inspect(vecs_to_string(a.nullspace()), content="[[-2, 1, 0], [-3, 0, 1]]")
}

///|
test "matrices lu and qr decomposition" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ])
  let (l, u, swaps) = a.lu()
  inspect(l.to_string(), content="Matrix([[1, 0], [3, 1]])")
  inspect(u.to_string(), content="Matrix([[1, 2], [0, -2]])")
  inspect(swaps, content="[]")
  let (q, r) = a.qr()
  assert_eq(q.shape(), (2, 2))
  assert_eq(r.shape(), (2, 2))
}

///|
test "matrices minors cofactors adjugate and echelon helpers" {
  let a = matrix([
    [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
    [@symcore.int(0), @symcore.int(4), @symcore.int(5)],
    [@symcore.int(1), @symcore.int(0), @symcore.int(6)],
  ])
  inspect(
    a.minor_submatrix(0, 1).to_string(),
    content="Matrix([[0, 5], [1, 6]])",
  )
  inspect(@symprint.to_string(a.minor(0, 1)), content="-5")
  inspect(@symprint.to_string(a.cofactor(0, 1)), content="5")
  inspect(
    a.adjugate().to_string(),
    content="Matrix([[24, -12, -2], [5, 3, -5], [-4, 2, 4]])",
  )
  let (echelon, pivots) = a.echelon_form_with_pivots()
  assert_true(echelon.is_echelon())
  inspect(pivots, content="[0, 1, 2]")
}

///|
test "matrices triangular solves rref rhs cholesky and ldl" {
  let lower = matrix([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(2), @symcore.int(3)],
  ])
  let rhs = matrix([[@symcore.int(4)], [@symcore.int(11)]])
  inspect(
    lower.lower_triangular_solve(rhs).to_string(),
    content="Matrix([[4], [1]])",
  )
  let upper = matrix([
    [@symcore.int(2), @symcore.int(1)],
    [@symcore.int(0), @symcore.int(3)],
  ])
  let rhs2 = matrix([[@symcore.int(5)], [@symcore.int(6)]])
  inspect(
    upper.upper_triangular_solve(rhs2).to_string(),
    content="Matrix([[3/2], [2]])",
  )
  let coeff = matrix([
    [@symcore.int(1), @symcore.int(1)],
    [@symcore.int(2), @symcore.int(1)],
  ])
  let vars = matrix([[@symcore.symbol("r1")], [@symcore.symbol("r2")]])
  let (rref_lhs, rref_rhs) = coeff.rref_rhs(vars)
  inspect(rref_lhs.to_string(), content="Matrix([[1, 0], [0, 1]])")
  inspect(
    rref_rhs.to_string(),
    content="Matrix([[-1*r1 + r2], [-1*(-2*r1 + r2)]])",
  )
  let spd = matrix([
    [@symcore.int(4), @symcore.int(2)],
    [@symcore.int(2), @symcore.int(3)],
  ])
  inspect(spd.cholesky().shape(), content="(2, 2)")
  let (l, d) = spd.ldl()
  assert_eq(l.shape(), (2, 2))
  assert_eq(d.shape(), (2, 2))
}
