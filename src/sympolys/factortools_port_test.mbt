///|
fn expect_factor_list_same(poly : Poly, modulus : Int?) -> Unit raise {
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = normalize_spaces(sort_factor_repr(ours_raw))
  let oracle = normalize_spaces(
    sort_factor_repr(
      match modulus {
        Some(p) => @sympy_polys.factor_list(poly.to_string(), modulus=p)
        None => @sympy_polys.factor_list(poly.to_string())
      },
    ),
  )
  guard ours == oracle else {
    fail("factor_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "factortools: x^5 - x over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    @symcore.mul([
      @symcore.symbol("x"),
      @symcore.add([
        @symcore.pow(@symcore.symbol("x"), @symcore.int(4)),
        @symcore.int(-1),
      ]),
    ]),
  )
  expect_factor_list_same(poly, None)
}

///|
test "factortools: x^6 + x^3 + 1 over GF(2)" {
  let b = PolyBuilder::new(["x"], Domain::GF(2))
  let poly = b.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(6)),
      @symcore.pow(@symcore.symbol("x"), @symcore.int(3)),
      @symcore.int(1),
    ]),
  )
  expect_factor_list_same(poly, Some(2))
}

///|
test "factortools: sqf_list compares with SymPy" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    @symcore.mul([
      @symcore.pow(
        @symcore.add([@symcore.symbol("x"), @symcore.int(-2)]),
        @symcore.int(2),
      ),
      @symcore.pow(
        @symcore.add([@symcore.symbol("x"), @symcore.int(3)]),
        @symcore.int(3),
      ),
    ]),
  )
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = normalize_spaces(sort_factor_repr(ours_raw))
  let oracle = normalize_spaces(
    sort_factor_repr(@sympy_polys.sqf_list(poly.to_string())),
  )
  guard ours == oracle else {
    fail("sqf_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "factortools: QQ content factors (1/2)*(x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let poly = b.from_expr(
    @symcore.mul([
      expr_rat(1, 2),
      @symcore.add([
        @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
        @symcore.int(-1),
      ]),
    ]),
  )
  expect_factor_list_same(poly, None)
}
