///|
fn sp_norm(expr : @symcore.Expr) -> String {
  (try! @sympy_polys.sympy_normalize(@symprint.to_string(expr)).trim().to_string())
    .replace_all(old=" ", new="")
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
  guard sp_norm(df.to_expr()) == "8*x-3" else {
    fail("series diff mismatch")
  }

  let intf = f.integrate()
  // integral with zero constant: 2x - 3/2 x^2 + 4/3 x^3
  guard sp_norm(intf.to_expr()) == "4*x**3/3-3*x**2/2+2*x" else {
    fail("series integrate mismatch")
  }
}
