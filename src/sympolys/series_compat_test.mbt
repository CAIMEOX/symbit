///|
fn sp_norm(expr : @symcore.Expr) -> String {
  (try! @sympy_polys.sympy_normalize(@symprint.to_string(expr))
  .trim()
  .to_string()).replace_all(old=" ", new="")
}

///|
test "series: ring arithmetic and truncation" {
  let ring = power_series_ring(Domain::QQ, "x", 5)
  let f = ring.from_int_coeffs([1, 2, 3])
  let g = ring.from_int_coeffs([0, 1, 1])

  let sum = f.add(g)
  let prod = f.mul(g)

  assert_eq(sp_norm(sum.to_expr()), "4*x**2+3*x+1")
  // (1 + 2x + 3x^2)*(x + x^2) = x + 3x^2 + 5x^3 + 3x^4
  assert_eq(sp_norm(prod.to_expr()), "3*x**4+5*x**3+3*x**2+x")

  let trunc = prod.truncate(3)
  assert_eq(sp_norm(trunc.to_expr()), "3*x**2+x")
}

///|
test "series: differentiation and integration" {
  let ring = power_series_ring(Domain::QQ, "x", 6)
  let f = ring.from_int_coeffs([2, -3, 4]) // 2 - 3x + 4x^2

  let df = f.diff()
  assert_eq(sp_norm(df.to_expr()), "8*x-3")

  let intf = f.integrate()
  // integral with zero constant: 2x - 3/2 x^2 + 4/3 x^3
  assert_eq(sp_norm(intf.to_expr()), "4*x**3/3-3*x**2/2+2*x")
}

///|
test "series: generator, scalar ops, inverse, divide, compose" {
  let ring = power_series_ring(Domain::ZZ, "x", 6)
  let x = ring.gen()
  let one = ring.one()

  assert_eq(sp_norm(x.to_expr()), "x")

  let lifted = x.add_ground(fe_from_int(2, Domain::ZZ))
  assert_eq(sp_norm(lifted.to_expr()), "x+2")

  let scaled = lifted.mul_ground(fe_from_int(-3, Domain::ZZ))
  assert_eq(sp_norm(scaled.to_expr()), "-3*x-6")

  let inv = one.add(x).inverse()
  assert_eq(sp_norm(inv.to_expr()), "-x**5+x**4-x**3+x**2-x+1")

  let div = one.add(x).divide(one.sub(x))
  assert_eq(sp_norm(div.to_expr()), "2*x**5+2*x**4+2*x**3+2*x**2+2*x+1")

  let lhs = ring.from_int_coeffs([3, 1, 14])
  let rhs = ring.from_int_coeffs([0, 0, 1, 1])
  let comp = lhs.compose(rhs)
  let got = sp_norm(comp.to_expr())
  assert_eq(got, "28*x**5+14*x**4+x**3+x**2+3")
}

///|
test "series: powers and analytic functions over QQ" {
  let ring = power_series_ring(Domain::QQ, "x", 6)
  let x = ring.gen()
  let one = ring.one()

  let pow = one.add(x).pow_int(5)
  assert_eq(sp_norm(pow.to_expr()), "x**5+5*x**4+10*x**3+10*x**2+5*x+1")

  let log1p = x.log1p()
  assert_eq(sp_norm(log1p.to_expr()), "x**5/5-x**4/4+x**3/3-x**2/2+x")

  let expx = x.exp()
  assert_eq(sp_norm(expx.to_expr()), "x**5/120+x**4/24+x**3/6+x**2/2+x+1")

  let sqrt1mx = one.sub(x).sqrt()
  assert_eq(sp_norm(sqrt1mx.to_expr()), "-7*x**5/256-5*x**4/128-x**3/16-x**2/8-x/2+1")

  let sinx = x.sin()
  assert_eq(sp_norm(sinx.to_expr()), "x**5/120-x**3/6+x")

  let cosx = x.cos()
  assert_eq(sp_norm(cosx.to_expr()), "x**4/24-x**2/2+1")

  let tanhx = x.tanh()
  assert_eq(sp_norm(tanhx.to_expr()), "2*x**5/15-x**3/3+x")

  let asinx = x.asin()
  assert_eq(sp_norm(asinx.to_expr()), "3*x**5/40+x**3/6+x")
}

///|
test "series: invalid inverse and analytic preconditions fail" {
  let zz = power_series_ring(Domain::ZZ, "x", 5)
  let x_zz = zz.gen()
  let bad_inv : Result[SeriesElem, PolyError] = try? x_zz.inverse()
  assert_true(bad_inv is Err(_))

  let qq = power_series_ring(Domain::QQ, "x", 5)
  let x = qq.gen()
  let bad_exp : Result[SeriesElem, PolyError] = try? x
    .add_ground(fe_from_int(1, Domain::QQ))
    .exp()
  assert_true(bad_exp is Err(_))

  let bad_sqrt : Result[SeriesElem, PolyError] = try? x.sqrt()
  assert_true(bad_sqrt is Err(_))
}
