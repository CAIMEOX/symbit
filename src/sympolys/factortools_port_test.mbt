///|
fn expect_factor_list_same(poly : Poly, modulus : Int?) -> Unit raise {
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
      match modulus {
        Some(p) => @sympy_polys.factor_list(poly.to_expr(), modulus=p)
        None => @sympy_polys.factor_list(poly.to_expr())
      },
    )
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("factor_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "factortools: x^5 - x over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let poly = b.from_expr(x * ((x ^ @symcore.int(4)) - @symcore.int(1)))
  expect_factor_list_same(poly, None)
}

///|
test "factortools: x^6 + x^3 + 1 over GF(2)" {
  let b = PolyBuilder::new(["x"], Domain::GF(2))
  let x = @symcore.symbol("x")
  let poly = b.from_expr(
    (x ^ @symcore.int(6)) + (x ^ @symcore.int(3)) + @symcore.int(1),
  )
  expect_factor_list_same(poly, Some(2))
}

///|
test "factortools: sqf_list compares with SymPy" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let poly = b.from_expr(
    ((x - @symcore.int(2)) ^ @symcore.int(2)) *
    ((x + @symcore.int(3)) ^ @symcore.int(3)),
  )
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(@sympy_polys.sqf_list(poly.to_expr()))
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("sqf_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "factortools: QQ content factors (1/2)*(x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = @symcore.symbol("x")
  let poly = b.from_expr(
    expr_rat(1, 2) * ((x ^ @symcore.int(2)) - @symcore.int(1)),
  )
  expect_factor_list_same(poly, None)
}
