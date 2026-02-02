///|
test "factor_modular: hensel/crt parity with linear + quadratic factors" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let x2 = x ^ @symcore.int(2)
  let quad1 = x2 + @symcore.int(1)
  let quad2 = x2 + @symcore.int(2)
  let poly = b.from_expr((x - @symcore.int(1)) * quad1 * quad2)
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(@sympy_polys.factor_list(poly.to_expr()))
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("hensel/crt factor_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "factor_modular: hensel/crt parity with mixed factors" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let x2 = x ^ @symcore.int(2)
  let quad1 = x2 + @symcore.int(3) * x + @symcore.int(2)
  let quad2 = x2 + @symcore.int(2)
  let poly = b.from_expr((x + @symcore.int(2)) * quad1 * quad2)
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(@sympy_polys.factor_list(poly.to_expr()))
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("hensel/crt factor_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "factor_modular: zassenhaus parity (no linear factors)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let x2 = x ^ @symcore.int(2)
  let poly = b.from_expr((x2 - @symcore.int(1)) * (x2 - @symcore.int(4)))
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(@sympy_polys.factor_list(poly.to_expr()))
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("zassenhaus factor_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}
