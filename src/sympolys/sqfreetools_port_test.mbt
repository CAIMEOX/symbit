///|
fn expect_sqf_list_same(poly : Poly) -> Unit raise {
  let (content, parts) = try poly.sqf_list() catch {
    e => fail(e.to_string())
  } noraise {
    v => v
  }
  let ours_raw = try factor_list_to_string(content.to_string(), parts) catch {
    e => fail(e.to_string())
  } noraise {
    v => v
  }
  let ours = @sympy.canonical_cmp(@sympy_polys.sort_factor_repr(ours_raw))
  let oracle = @sympy.canonical_cmp(
    @sympy_polys.sort_factor_repr(
      match poly.domain {
        Domain::GF(p) => @sympy_polys.sqf_list_str(poly.to_string(), modulus=p)
        _ => @sympy_polys.sqf_list_str(poly.to_string())
      },
    ),
  )
  guard ours == oracle else {
    fail("sqf_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn expect_sqf_part_same(poly : Poly) -> Unit raise {
  let sqf = try poly.sqf_part() catch {
    e => fail(e.to_string())
  } noraise {
    v => v
  }
  let oracle_sqf = @sympy_polys.sqf_part_str(poly.to_string())
  let eq = @sympy_polys.expr_equal(sqf.to_string(), oracle_sqf)
  guard eq else {
    fail("sqf_part mismatch: ours=\{sqf.to_string()}, oracle=\{oracle_sqf}")
  }
}

///|

///|
test "sqfreetools: sqf_list for repeated linear factors over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    expr_mul([
      expr_pow(expr_add([expr_sym("x"), expr_int(-1)]), 2),
      expr_pow(expr_add([expr_sym("x"), expr_int(2)]), 3),
    ]),
  ) catch {
    e => fail(e.to_string())
  }
  expect_sqf_list_same(poly) catch {
    e => fail(e.to_string())
  }
}

///|
test "sqfreetools: sqf_part drops multiplicities" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    expr_mul([
      expr_pow(expr_add([expr_sym("x"), expr_int(-3)]), 2),
      expr_pow(expr_add([expr_sym("x"), expr_int(1)]), 1),
      expr_pow(expr_add([expr_sym("x"), expr_int(5)]), 4),
    ]),
  ) catch {
    e => fail(e.to_string())
  }
  expect_sqf_part_same(poly) catch {
    e => fail(e.to_string())
  }
}

///|
test "sqfreetools: sqf_list mixed factors over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    expr_add([
      expr_mul([expr_int(-1), expr_pow(expr_sym("x"), 5)]),
      expr_pow(expr_sym("x"), 4),
      expr_sym("x"),
      expr_int(-1),
    ]),
  ) catch {
    e => fail(e.to_string())
  }
  expect_sqf_list_same(poly) catch {
    e => fail(e.to_string())
  }
}

///|
test "sqfreetools: sqf_list composite even powers over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    expr_add([
      expr_pow(expr_sym("x"), 8),
      expr_mul([expr_int(6), expr_pow(expr_sym("x"), 6)]),
      expr_mul([expr_int(12), expr_pow(expr_sym("x"), 4)]),
      expr_mul([expr_int(8), expr_pow(expr_sym("x"), 2)]),
    ]),
  ) catch {
    e => fail(e.to_string())
  }
  expect_sqf_list_same(poly) catch {
    e => fail(e.to_string())
  }
}

///|
test "sqfreetools: sqf_list over QQ keeps content" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let poly = b.from_expr(
    expr_add([
      expr_mul([expr_int(2), expr_pow(expr_sym("x"), 2)]),
      expr_mul([expr_int(4), expr_sym("x")]),
      expr_int(2),
    ]),
  ) catch {
    e => fail(e.to_string())
  }
  expect_sqf_list_same(poly) catch {
    e => fail(e.to_string())
  }
}

///|
test "sqfreetools: sqf_list over GF(2) handles pth powers" {
  let b = PolyBuilder::new(["x"], Domain::GF(2))
  let poly = b.from_expr(expr_add([expr_pow(expr_sym("x"), 2), expr_int(1)])) catch {
    e => fail(e.to_string())
  }
  expect_sqf_list_same(poly) catch {
    e => fail(e.to_string())
  }
}

///|
test "sqfreetools: sqf_list over GF(3) splits multiplicities" {
  let b = PolyBuilder::new(["x"], Domain::GF(3))
  let poly = b.from_expr(
    expr_add([
      expr_pow(expr_sym("x"), 10),
      expr_mul([expr_int(2), expr_pow(expr_sym("x"), 7)]),
      expr_mul([expr_int(2), expr_pow(expr_sym("x"), 4)]),
      expr_sym("x"),
    ]),
  ) catch {
    e => fail(e.to_string())
  }
  expect_sqf_list_same(poly) catch {
    e => fail(e.to_string())
  }
}

///|
test "sqfreetools: sqf_part signs normalize" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    expr_add([
      expr_mul([expr_int(-1), expr_pow(expr_sym("x"), 3)]),
      expr_sym("x"),
      expr_int(1),
    ]),
  ) catch {
    e => fail(e.to_string())
  }
  expect_sqf_part_same(poly) catch {
    e => fail(e.to_string())
  }
}

///|
test "sqfreetools: sqf_list handles zero and constants" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let zero = b.from_expr(expr_int(0)) catch { e => fail(e.to_string()) }
  let one = b.from_expr(expr_int(7)) catch { e => fail(e.to_string()) }
  expect_sqf_list_same(zero) catch {
    e => fail(e.to_string())
  }
  expect_sqf_list_same(one) catch {
    e => fail(e.to_string())
  }
}

///|
test "sqfreetools: sqf_list composite factors over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr(
    expr_mul([
      expr_pow(expr_add([expr_pow(expr_sym("x"), 2), expr_int(1)]), 2),
      expr_add([
        expr_pow(expr_sym("x"), 2),
        expr_mul([expr_int(2), expr_sym("x")]),
        expr_int(2),
      ]),
    ]),
  ) catch {
    e => fail(e.to_string())
  }
  expect_sqf_list_same(poly) catch {
    e => fail(e.to_string())
  }
}
