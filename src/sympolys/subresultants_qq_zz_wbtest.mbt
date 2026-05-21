///|
fn sr_wb_poly(expr : @symcore.Expr) -> Poly raise PolyError {
  PolyBuilder::new(["x"], Domain::ZZ).from_expr(expr)
}

///|
fn sr_wb_list_repr(polys : Array[Poly]) -> String {
  polys.map(p => p.to_string()).join(" | ")
}

///|
fn sr_wb_fe_row(values : Array[Int]) -> Array[FieldElem] raise PolyError {
  values.map(v => fe_from_int(v, Domain::ZZ))
}

///|
fn sr_wb_matrix(values : Array[Array[Int]]) -> DomainMatrix raise PolyError {
  let rows : Array[Array[FieldElem]] = []
  for row in values {
    rows.push(sr_wb_fe_row(row))
  }
  DomainMatrix::from_list(rows, Domain::ZZ)
}

///|
test "subresultants qq zz wb: sign and matrix output helpers" {
  let x = @symcore.Expr::Symbol("x")
  let p = sr_wb_poly((x ^ @symcore.int(3)) - @symcore.int(2) * x)
  let q = sr_wb_poly(
    @symcore.int(-1) * ((x ^ @symcore.int(2)) + @symcore.int(1)),
  )
  let zero = Poly::zero(["x"], Domain::ZZ)
  inspect(sign_seq([p, q, zero]), content="[1, -1, 0]")

  let r = sr_wb_poly(x + @symcore.int(1))
  let same_degree = sr_wb_poly(@symcore.int(2) * x + @symcore.int(3))
  inspect(
    sr_wb_list_repr(process_matrix_output([p, q, zero, r, same_degree])),
    content="x**3 - 2*x | -x**2 - 1 | x + 1",
  )
}

///|
test "subresultants qq zz wb: compute_sign" {
  inspect(compute_sign(2, 5), content="1")
  inspect(compute_sign(-2, 4), content="1")
  inspect(compute_sign(-2, 5), content="-1")
  inspect(compute_sign(0, 3), content="0")
  let bad : Result[Int, PolyError] = try? compute_sign(-2, -1)
  assert_true(bad is Err(PolyError::BadExponent))
}

///|
test "subresultants qq zz wb: prs input normalization" {
  let x = @symcore.Expr::Symbol("x")
  let p = sr_wb_poly(
    @symcore.int(-1) * ((x ^ @symcore.int(2)) - @symcore.int(1)),
  )
  let q = sr_wb_poly(x - @symcore.int(1))
  inspect(sr_wb_list_repr(euclid_q(q, p)), content="1 - x**2 | x - 1")
  inspect(sr_wb_list_repr(sturm_q(q, p)), content="1 - x**2 | x - 1")
}

///|
test "subresultants qq zz wb: public algorithm aliases" {
  let x = @symcore.Expr::Symbol("x")
  let p = sr_wb_poly(
    (x ^ @symcore.int(3)) - @symcore.int(2) * x + @symcore.int(1),
  )
  let q = sr_wb_poly((x ^ @symcore.int(2)) - @symcore.int(1))
  inspect(
    sr_wb_list_repr(euclid_pg(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | 1 - x",
  )
  inspect(
    sr_wb_list_repr(euclid_amv(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | 1 - x",
  )
  inspect(
    sr_wb_list_repr(sturm_pg(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | x - 1",
  )
  inspect(
    sr_wb_list_repr(sturm_amv(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | x - 1",
  )
  inspect(
    sr_wb_list_repr(subresultants_sylv(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | 1 - x",
  )
  inspect(
    sr_wb_list_repr(subresultants_bezout(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | 1 - x",
  )
  inspect(
    sr_wb_list_repr(subresultants_amv(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | 1 - x",
  )
  inspect(
    sr_wb_list_repr(subresultants_amv_q(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | 1 - x",
  )
  inspect(
    sr_wb_list_repr(subresultants_vv(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | 1 - x",
  )
  inspect(
    sr_wb_list_repr(subresultants_vv_2(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | 1 - x",
  )
  inspect(
    sr_wb_list_repr(modified_subresultants_sylv(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | x - 1",
  )
  inspect(
    sr_wb_list_repr(modified_subresultants_bezout(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | x - 1",
  )
  inspect(
    sr_wb_list_repr(modified_subresultants_amv(p, q)),
    content="x**3 - 2*x + 1 | x**2 - 1 | x - 1",
  )
}

///|
test "subresultants qq zz wb: row and matrix helper frontdoors" {
  inspect(
    rotate_r(sr_wb_fe_row([1, 2, 3, 4]), 2).map(v => v.to_string()).join(", "),
    content="3, 4, 1, 2",
  )
  inspect(
    rotate_l(sr_wb_fe_row([1, 2, 3, 4]), 2).map(v => v.to_string()).join(", "),
    content="3, 1, 2, 4",
  )
  inspect(
    row2poly(sr_wb_fe_row([0, 0, 1, 2, 3, 0]), 2).to_string(),
    content="x**2 + 2*x + 3",
  )
  inspect(
    pivot(sr_wb_matrix([[2, 1, 3], [4, 5, 6], [0, 7, 8]]), 0, 0).to_matrix_string(),
    content="Matrix([[2, 1, 3], [0, 6, 0], [0, 7, 8]])",
  )
  inspect(
    find_degree(sr_wb_matrix([[1, 2, 3, 0], [0, 0, 4, 5]]), 3),
    content="Some(1)",
  )
  inspect(
    final_touches(
      sr_wb_matrix([[0, 0, 0, 0], [0, 1, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0]]),
      2,
      1,
    ).to_matrix_string(),
    content="Matrix([[0, 0, 0, 0], [0, 1, 2, 0], [0, 0, 1, 2], [0, 0, 0, 0]])",
  )
}
