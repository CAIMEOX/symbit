///|
test "ops: gcd_list/lcm_list parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.Expr::Symbol("x")
  let f = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  let g = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(4))
  let h = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(9))
  let ours_g = sympy_normalize(@sympolys.gcd_list([f, g, h]).to_string())
    .trim()
    .to_string()
  let oracle_g = gcd_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_string()
  assert_eq(ours_g, oracle_g)
  let ours_l = sympy_normalize(@sympolys.lcm_list([f, g, h]).to_string())
    .trim()
    .to_string()
  let oracle_l = lcm_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_string()
  assert_eq(ours_l, oracle_l)
}

///|
test "ops: discriminant parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.Expr::Symbol("x")
  let f = b.from_expr(
    (x ^ @symcore.int(3)) - @symcore.int(2) * x + @symcore.int(1),
  )
  let disc = @sympolys.discriminant(f)
  let ours = disc.to_string()
  let oracle = discriminant(f.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "ops: resultant_expr parity with gens/domain (univariate)" {
  let x = @symcore.Expr::Symbol("x")
  let f = (x ^ @symcore.int(3)) + @symcore.int(2) * x + @symcore.int(1)
  let g = (x ^ @symcore.int(2)) + @symcore.int(1)
  let res = @sympolys.resultant_expr(f, g, "x", gens=["x"], domain=Domain::ZZ)
  let ours = sympy_normalize(@symprint.pretty_string(res)).trim().to_string()
  let oracle = resultant(f, g, x="x", gens=["x"], domain="ZZ")
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "ops: resultant_expr parity for multivar with univariate support" {
  let y = @symcore.Expr::Symbol("y")
  let f = (y ^ @symcore.int(2)) - @symcore.int(2)
  let g = y - @symcore.int(1)
  let res = @sympolys.resultant_expr(
    f,
    g,
    "y",
    gens=["x", "y"],
    domain=Domain::ZZ,
  )
  let ours = sympy_normalize(@symprint.pretty_string(res)).trim().to_string()
  let oracle = resultant(f, g, x="y", gens=["x", "y"], domain="ZZ")
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "ops: resultant_expr parity for non-constant multivar elimination" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = x * y + @symcore.int(1)
  let g = x + y
  let res = @sympolys.resultant_expr(
    f,
    g,
    "x",
    gens=["x", "y"],
    domain=Domain::ZZ,
  )
  let ours = sympy_normalize(@symprint.pretty_string(res)).trim().to_string()
  let oracle = resultant(f, g, x="x", gens=["x", "y"], domain="ZZ")
    .trim()
    .to_string()
  assert_eq(ours, oracle)
  let scalar_res : Result[@symnum.BigRational, PolyError] = try? @sympolys.resultant_expr_scalar(
    f,
    g,
    "x",
    gens=["x", "y"],
    domain=Domain::ZZ,
  )
  match scalar_res {
    Err(PolyError::DomainMismatch) => ()
    _ => fail("expected scalar resultant_expr to reject non-constant output")
  }
}
