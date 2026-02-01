///|
fn expect_sqf_list_same(poly : Poly) -> Unit raise {
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = canonical_cmp(sort_factor_repr(ours_raw))
  let oracle = canonical_cmp(
    sort_factor_repr(
      match poly.domain {
        Domain::GF(p) => @sympy_polys.sqf_list(poly.to_expr(), modulus=p)
        _ => @sympy_polys.sqf_list(poly.to_expr())
      },
    ),
  )
  guard ours == oracle else {
    fail("sqf_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn expect_sqf_part_same(poly : Poly) -> Unit raise {
  let sqf = poly.sqf_part()
  let oracle_sqf = @sympy_polys.sqf_part(poly.to_expr())
  let eq = expr_equal(sqf.to_string(), oracle_sqf)
  guard eq else {
    fail("sqf_part mismatch: ours=\{sqf.to_string()}, oracle=\{oracle_sqf}")
  }
}

///|

///|
test "sqfreetools: sqf_list for repeated linear factors over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    ((x - expr_int(1)) ^ expr_int(2)) * ((x + expr_int(2)) ^ expr_int(3)),
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_part drops multiplicities" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    ((x - expr_int(3)) ^ expr_int(2)) *
    ((x + expr_int(1)) ^ expr_int(1)) *
    ((x + expr_int(5)) ^ expr_int(4)),
  )
  expect_sqf_part_same(poly)
}

///|
test "sqfreetools: sqf_list mixed factors over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    expr_int(-1) * (x ^ expr_int(5)) + (x ^ expr_int(4)) + x + expr_int(-1),
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_list composite even powers over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    (x ^ expr_int(8)) +
    expr_int(6) * (x ^ expr_int(6)) +
    expr_int(12) * (x ^ expr_int(4)) +
    expr_int(8) * (x ^ expr_int(2)),
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_list over QQ keeps content" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    expr_int(2) * (x ^ expr_int(2)) + expr_int(4) * x + expr_int(2),
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_list over GF(2) handles pth powers" {
  let b = PolyBuilder::new(["x"], Domain::GF(2))
  let x = expr_sym("x")
  let poly = b.from_expr((x ^ expr_int(2)) + expr_int(1))
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_list over GF(3) splits multiplicities" {
  let b = PolyBuilder::new(["x"], Domain::GF(3))
  let x = expr_sym("x")
  let poly = b.from_expr(
    (x ^ expr_int(10)) +
    expr_int(2) * (x ^ expr_int(7)) +
    expr_int(2) * (x ^ expr_int(4)) +
    x,
  )
  expect_sqf_list_same(poly)
}

///|
test "sqfreetools: sqf_part signs normalize" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(expr_int(-1) * (x ^ expr_int(3)) + x + expr_int(1))
  expect_sqf_part_same(poly)
}

///|
test "sqfreetools: sqf_list handles zero and constants" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let zero = b.from_expr(expr_int(0))
  let one = b.from_expr(expr_int(7))
  expect_sqf_list_same(zero)
  expect_sqf_list_same(one)
}

///|
test "sqfreetools: sqf_list composite factors over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let poly = b.from_expr(
    (((x ^ expr_int(2)) + expr_int(1)) ^ expr_int(2)) *
    ((x ^ expr_int(2)) + expr_int(2) * x + expr_int(2)),
  )
  expect_sqf_list_same(poly)
}
