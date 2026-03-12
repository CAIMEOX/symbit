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

  guard sp_norm(sum.to_expr()) == "4*x**2+3*x+1" else {
    fail("series add mismatch")
  }
  // (1 + 2x + 3x^2)*(x + x^2) = x + 3x^2 + 5x^3 + 3x^4
  guard sp_norm(prod.to_expr()) == "3*x**4+5*x**3+3*x**2+x" else {
    fail("series mul mismatch")
  }

  let trunc = prod.truncate(3)
  guard sp_norm(trunc.to_expr()) == "3*x**2+x" else {
    fail("series truncation mismatch")
  }
}

///|
test "series: differentiation and integration" {
  let ring = power_series_ring(Domain::QQ, "x", 6)
  let f = ring.from_int_coeffs([2, -3, 4]) // 2 - 3x + 4x^2

  let df = f.diff()
  guard sp_norm(df.to_expr()) == "8*x-3" else { fail("series diff mismatch") }

  let intf = f.integrate()
  // integral with zero constant: 2x - 3/2 x^2 + 4/3 x^3
  guard sp_norm(intf.to_expr()) == "4*x**3/3-3*x**2/2+2*x" else {
    fail("series integrate mismatch")
  }
}

///|
test "series: generator, scalar ops, inverse, divide, compose" {
  let ring = power_series_ring(Domain::ZZ, "x", 6)
  let x = ring.gen()
  let one = ring.one()

  guard sp_norm(x.to_expr()) == "x" else { fail("series generator mismatch") }

  let lifted = x.add_ground(fe_from_int(2, Domain::ZZ))
  guard sp_norm(lifted.to_expr()) == "x+2" else {
    fail("series add_ground mismatch")
  }

  let scaled = lifted.mul_ground(fe_from_int(-3, Domain::ZZ))
  guard sp_norm(scaled.to_expr()) == "-3*x-6" else {
    fail("series mul_ground mismatch")
  }

  let inv = one.add(x).inverse()
  guard sp_norm(inv.to_expr()) == "-x**5+x**4-x**3+x**2-x+1" else {
    fail("series inverse mismatch: \{sp_norm(inv.to_expr())}")
  }

  let div = one.add(x).divide(one.sub(x))
  guard sp_norm(div.to_expr()) == "2*x**5+2*x**4+2*x**3+2*x**2+2*x+1" else {
    fail("series divide mismatch: \{sp_norm(div.to_expr())}")
  }

  let lhs = ring.from_int_coeffs([3, 1, 14])
  let rhs = ring.from_int_coeffs([0, 0, 1, 1])
  let comp = lhs.compose(rhs)
  let got = sp_norm(comp.to_expr())
  guard got == "28*x**5+14*x**4+x**3+x**2+3" else {
    fail("series compose mismatch: \{got}")
  }
}

///|
test "series: powers and analytic functions over QQ" {
  let ring = power_series_ring(Domain::QQ, "x", 6)
  let x = ring.gen()
  let one = ring.one()

  let pow = one.add(x).pow_int(5)
  guard sp_norm(pow.to_expr()) == "x**5+5*x**4+10*x**3+10*x**2+5*x+1" else {
    fail("series pow_int mismatch: \{sp_norm(pow.to_expr())}")
  }

  let log1p = x.log1p()
  guard sp_norm(log1p.to_expr()) == "x**5/5-x**4/4+x**3/3-x**2/2+x" else {
    fail("series log1p mismatch: \{sp_norm(log1p.to_expr())}")
  }

  let expx = x.exp()
  guard sp_norm(expx.to_expr()) == "x**5/120+x**4/24+x**3/6+x**2/2+x+1" else {
    fail("series exp mismatch: \{sp_norm(expx.to_expr())}")
  }

  let sqrt1mx = one.sub(x).sqrt()
  guard sp_norm(sqrt1mx.to_expr()) ==
    "-7*x**5/256-5*x**4/128-x**3/16-x**2/8-x/2+1" else {
    fail("series sqrt mismatch: \{sp_norm(sqrt1mx.to_expr())}")
  }

  let sinx = x.sin()
  guard sp_norm(sinx.to_expr()) == "x**5/120-x**3/6+x" else {
    fail("series sin mismatch: \{sp_norm(sinx.to_expr())}")
  }

  let cosx = x.cos()
  guard sp_norm(cosx.to_expr()) == "x**4/24-x**2/2+1" else {
    fail("series cos mismatch: \{sp_norm(cosx.to_expr())}")
  }

  let tanhx = x.tanh()
  guard sp_norm(tanhx.to_expr()) == "2*x**5/15-x**3/3+x" else {
    fail("series tanh mismatch: \{sp_norm(tanhx.to_expr())}")
  }

  let asinx = x.asin()
  guard sp_norm(asinx.to_expr()) == "3*x**5/40+x**3/6+x" else {
    fail("series asin mismatch: \{sp_norm(asinx.to_expr())}")
  }
}

///|
test "series: invalid inverse and analytic preconditions fail" {
  let zz = power_series_ring(Domain::ZZ, "x", 5)
  let x_zz = zz.gen()
  let bad_inv : Result[SeriesElem, PolyError] = try? x_zz.inverse()
  guard bad_inv is Err(_) else { fail("inverse(x) should fail") }

  let qq = power_series_ring(Domain::QQ, "x", 5)
  let x = qq.gen()
  let bad_exp : Result[SeriesElem, PolyError] = try? x
    .add_ground(fe_from_int(1, Domain::QQ))
    .exp()
  guard bad_exp is Err(_) else { fail("exp(1 + x) should fail") }

  let bad_sqrt : Result[SeriesElem, PolyError] = try? x.sqrt()
  guard bad_sqrt is Err(_) else { fail("sqrt(x) should fail") }
}
