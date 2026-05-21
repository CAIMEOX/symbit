///|
fn sr_wb_poly(expr : @symcore.Expr) -> Poly raise PolyError {
  PolyBuilder::new(["x"], Domain::ZZ).from_expr(expr)
}

///|
fn sr_wb_list_repr(polys : Array[Poly]) -> String {
  polys.map(p => p.to_string()).join(" | ")
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
