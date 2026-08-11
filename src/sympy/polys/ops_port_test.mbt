///|
test "ops: gcd_list/lcm_list parity over ZZ" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = @symcore.Expr::Symbol("x")
  let f = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  let g = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(4))
  let h = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(9))
  let ours_g = sympy_normalize(@sympolys.gcd_list([f, g, h]).to_string())
    .trim()
    .to_owned()
  let oracle_g = gcd_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_owned()
  assert_eq(ours_g, oracle_g)
  let ours_l = sympy_normalize(@sympolys.lcm_list([f, g, h]).to_string())
    .trim()
    .to_owned()
  let oracle_l = lcm_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_owned()
  assert_eq(ours_l, oracle_l)
}

///|
test "ops: discriminant parity over ZZ" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = @symcore.Expr::Symbol("x")
  let f = b.from_expr(
    (x ^ @symcore.int(3)) - @symcore.int(2) * x + @symcore.int(1),
  )
  let disc = @sympolys.discriminant(f)
  let ours = Show::to_string(disc)
  let oracle = discriminant(f.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "ops: resultant_expr parity with gens/domain (univariate)" {
  let x = @symcore.Expr::Symbol("x")
  let f = (x ^ @symcore.int(3)) + @symcore.int(2) * x + @symcore.int(1)
  let g = (x ^ @symcore.int(2)) + @symcore.int(1)
  let res = @sympolys.resultant_expr(f, g, "x", gens=["x"], domain=ZZ)
  let ours = sympy_normalize(@symprint.pretty_string(res)).trim().to_owned()
  let oracle = resultant(f, g, x="x", gens=["x"], domain="ZZ").trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "ops: resultant_expr parity for multivar with univariate support" {
  let y = @symcore.Expr::Symbol("y")
  let f = (y ^ @symcore.int(2)) - @symcore.int(2)
  let g = y - @symcore.int(1)
  let res = @sympolys.resultant_expr(f, g, "y", gens=["x", "y"], domain=ZZ)
  let ours = sympy_normalize(@symprint.pretty_string(res)).trim().to_owned()
  let oracle = resultant(f, g, x="y", gens=["x", "y"], domain="ZZ")
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "ops: resultant_expr parity for non-constant multivar elimination" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = x * y + @symcore.int(1)
  let g = x + y
  let res = @sympolys.resultant_expr(f, g, "x", gens=["x", "y"], domain=ZZ)
  let ours = sympy_normalize(@symprint.pretty_string(res)).trim().to_owned()
  let oracle = resultant(f, g, x="x", gens=["x", "y"], domain="ZZ")
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
  let error = expect_poly_error(fn() raise PolyError {
    @sympolys.resultant_expr_scalar(f, g, "x", gens=["x", "y"], domain=ZZ)
  })
  assert_true(error is DomainMismatch)
}
