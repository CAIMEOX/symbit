///|
test "subresultants_qq_zz: res parity" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(
    (x ^ @symcore.int(3)) - @symcore.int(7) * x + @symcore.int(7),
  )
  let q = b.from_expr(@symcore.int(3) * (x ^ @symcore.int(2)) - @symcore.int(7))
  let ours = res(p, q).to_string()
  let oracle = @sympy_polys.res_qq_zz(p.to_expr(), q.to_expr(), x="x")
  guard ours == oracle else { fail("res mismatch") }
  let ours_q = res_q(p, q).to_string()
  let oracle_q = @sympy_polys.res_q_qq_zz(p.to_expr(), q.to_expr(), x="x")
  guard ours_q == oracle_q else { fail("res_q mismatch") }
  let ours_z = res_z(p, q).to_string()
  let oracle_z = @sympy_polys.res_z_qq_zz(p.to_expr(), q.to_expr(), x="x")
  guard ours_z == oracle_z else { fail("res_z mismatch") }
}

///|
test "subresultants_qq_zz: res parity (extra)" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(2))
  let q = b.from_expr(x - @symcore.int(1))
  let ours = res(p, q).to_string()
  let oracle = @sympy_polys.res_qq_zz(p.to_expr(), q.to_expr(), x="x")
  guard ours == oracle else { fail("res extra mismatch") }
}

///|
test "subresultants_qq_zz: subresultants_rem parity" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(4)) - @symcore.int(1))
  let q = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let ours = poly_list_to_string(subresultants_rem(p, q))
  let oracle = @sympy_polys.subresultants_rem_qq_zz(
    p.to_expr(),
    q.to_expr(),
    x="x",
  )
  guard ours == oracle else { fail("subresultants_rem mismatch") }
}

///|
test "subresultants_qq_zz: subresultants_rem parity (extra)" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let q = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  let ours = poly_list_to_string(subresultants_rem(p, q))
  let oracle = @sympy_polys.subresultants_rem_qq_zz(
    p.to_expr(),
    q.to_expr(),
    x="x",
  )
  guard ours == oracle else { fail("subresultants_rem extra mismatch") }
}

///|
test "subresultants_qq_zz: euclid_q/sturm_q parity" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(4)) - @symcore.int(1))
  let q = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let ours_e = poly_list_to_string(euclid_q(p, q))
  let oracle_e = @sympy_polys.euclid_q_qq_zz(p.to_expr(), q.to_expr(), x="x")
  guard ours_e == oracle_e else {
    fail("euclid_q mismatch: ours=\{ours_e}, oracle=\{oracle_e}")
  }
  let ours_s = poly_list_to_string(sturm_q(p, q))
  let oracle_s = @sympy_polys.sturm_q_qq_zz(p.to_expr(), q.to_expr(), x="x")
  guard ours_s == oracle_s else {
    fail("sturm_q mismatch: ours=\{ours_s}, oracle=\{oracle_s}")
  }
}

///|
test "subresultants_qq_zz: rem_z/quo_z parity" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr((x ^ @symcore.int(5)) + @symcore.int(1))
  let q = b.from_expr(x + @symcore.int(1))
  let ours_rem = sympy_normalize(rem_z(p, q).to_string())
  let oracle_rem = @sympy_polys.rem_z_qq_zz(p.to_expr(), q.to_expr(), x="x")
  guard ours_rem == oracle_rem else {
    fail("rem_z mismatch: ours=\{ours_rem}, oracle=\{oracle_rem}")
  }
  let ours_quo = sympy_normalize(quo_z(p, q).to_string())
  let oracle_quo = @sympy_polys.quo_z_qq_zz(p.to_expr(), q.to_expr(), x="x")
  guard ours_quo == oracle_quo else {
    fail("quo_z mismatch: ours=\{ours_quo}, oracle=\{oracle_quo}")
  }
}
