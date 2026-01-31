///|
fn expect_gcd_oracle(p : Poly, q : Poly) -> Unit raise {
  let g = try p.gcd_univar(q) catch { e => fail(e.to_string()) } noraise { v => v }
  let ours = @sympy.normalize_spaces(@sympy.sympy_normalize(g.to_string()))
  let oracle = @sympy.normalize_spaces(@sympy.sympy_oracle_call("gcd_str", [
    @sympy.OracleArg::Str(p.to_string()),
    @sympy.OracleArg::Str(q.to_string()),
  ]))
  guard ours == oracle else {
    fail("gcd mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn expect_div_oracle(p : Poly, q : Poly) -> Unit raise {
  let (quo, rem) = try p.divmod_univar(q) catch { e => fail(e.to_string()) } noraise { v => v }
  let ours = @sympy.normalize_spaces(div_pair_to_string(quo, rem))
  let oracle = @sympy.normalize_spaces(@sympy.sympy_oracle_call("div_str", [
    @sympy.OracleArg::Str(p.to_string()),
    @sympy.OracleArg::Str(q.to_string()),
  ]))
  guard ours == oracle else {
    fail("divmod mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn expect_resultant_oracle(p : Poly, q : Poly) -> Unit raise {
  let res = try p.resultant(q, 0) catch { e => fail(e.to_string()) } noraise { v => v }
  let ours = @sympy.normalize_spaces(@sympy.sympy_normalize(res.to_string()))
  let oracle = @sympy.normalize_spaces(@sympy.sympy_oracle_call("resultant_str", [
    @sympy.OracleArg::Str(p.to_string()),
    @sympy.OracleArg::Str(q.to_string()),
    @sympy.OracleArg::Str("x"),
  ]))
  guard ours == oracle else {
    fail("resultant mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn expr_rat(n : Int, d : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(n, d)
}

///|
test "euclidtools: gcd_univar oracle parity (x^4-1, x^3-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([expr_pow(expr_sym("x"), 4), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  let q = b.from_expr(expr_add([expr_pow(expr_sym("x"), 3), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  expect_gcd_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: divmod oracle parity (x^4-1) / (x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([expr_pow(expr_sym("x"), 4), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  let d = b.from_expr(expr_add([expr_pow(expr_sym("x"), 2), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  expect_div_oracle(p, d) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: gcd_univar oracle parity (QQ example)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 4),
    expr_mul([expr_int(-2), expr_pow(expr_sym("x"), 3)]),
    expr_mul([expr_int(-6), expr_pow(expr_sym("x"), 2)]),
    expr_mul([expr_int(12), expr_sym("x")]),
    expr_int(15),
  ])) catch { e => fail(e.to_string()) }
  let q = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 3),
    expr_pow(expr_sym("x"), 2),
    expr_mul([expr_int(-4), expr_sym("x")]),
    expr_int(-4),
  ])) catch { e => fail(e.to_string()) }
  expect_gcd_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: gcd_univar oracle parity (2*x, x^2-16)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(expr_mul([expr_int(2), expr_sym("x")])) catch { e => fail(e.to_string()) }
  let q = b.from_expr(expr_add([expr_pow(expr_sym("x"), 2), expr_int(-16)])) catch {
    e => fail(e.to_string())
  }
  expect_gcd_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: gcd_univar oracle parity (QQ rational square)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(
    expr_mul([
      expr_rat(1, 2),
      expr_add([
        expr_pow(expr_sym("x"), 2),
        expr_mul([expr_int(-2), expr_sym("x")]),
        expr_int(1),
      ]),
    ]),
  ) catch { e => fail(e.to_string()) }
  let q = b.from_expr(expr_add([expr_pow(expr_sym("x"), 2), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  expect_gcd_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: gcd_univar oracle parity (QQ mixed coeffs)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(
    expr_add([
      expr_pow(expr_sym("x"), 3),
      expr_mul([expr_rat(1, 3), expr_pow(expr_sym("x"), 2)]),
      expr_mul([expr_rat(-1, 3), expr_sym("x")]),
      expr_rat(-1, 3),
    ]),
  ) catch { e => fail(e.to_string()) }
  let q = b.from_expr(
    expr_add([
      expr_pow(expr_sym("x"), 2),
      expr_mul([expr_rat(-1, 3), expr_sym("x")]),
      expr_rat(-2, 3),
    ]),
  ) catch { e => fail(e.to_string()) }
  expect_gcd_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: gcd_univar oracle parity (x^6-1, x^4-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([expr_pow(expr_sym("x"), 6), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  let q = b.from_expr(expr_add([expr_pow(expr_sym("x"), 4), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  expect_gcd_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: divmod oracle parity (x^5+1) / (x+1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([expr_pow(expr_sym("x"), 5), expr_int(1)])) catch {
    e => fail(e.to_string())
  }
  let d = b.from_expr(expr_add([expr_sym("x"), expr_int(1)])) catch { e => fail(e.to_string()) }
  expect_div_oracle(p, d) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: divmod oracle parity (QQ x^5+1) / (x+1)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(expr_add([expr_pow(expr_sym("x"), 5), expr_int(1)])) catch {
    e => fail(e.to_string())
  }
  let d = b.from_expr(expr_add([expr_sym("x"), expr_int(1)])) catch { e => fail(e.to_string()) }
  expect_div_oracle(p, d) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: divmod oracle parity (QQ rational divisor)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(
    expr_add([
      expr_mul([expr_rat(1, 2), expr_pow(expr_sym("x"), 3)]),
      expr_mul([expr_rat(3, 2), expr_pow(expr_sym("x"), 2)]),
      expr_sym("x"),
      expr_int(1),
    ]),
  ) catch { e => fail(e.to_string()) }
  let d = b.from_expr(expr_add([expr_sym("x"), expr_rat(1, 2)])) catch { e => fail(e.to_string()) }
  expect_div_oracle(p, d) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: divmod oracle parity (QQ rational coefficients)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(
    expr_add([
      expr_pow(expr_sym("x"), 4),
      expr_mul([expr_rat(1, 2), expr_pow(expr_sym("x"), 2)]),
      expr_int(-1),
    ]),
  ) catch { e => fail(e.to_string()) }
  let d = b.from_expr(expr_add([expr_pow(expr_sym("x"), 2), expr_rat(1, 2)])) catch {
    e => fail(e.to_string())
  }
  expect_div_oracle(p, d) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: divmod dense arrays (x^5+1) / (x+1)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let p = b.from_expr(expr_add([expr_pow(expr_sym("x"), 5), expr_int(1)])) catch {
    e => fail(e.to_string())
  }
  let d = b.from_expr(expr_add([expr_sym("x"), expr_int(1)])) catch { e => fail(e.to_string()) }
  let (q, r) = try p.divmod_univar(d) catch { e => fail(e.to_string()) } noraise { v => v }
  let q_dense = try to_dense(q) catch { e => fail(e.to_string()) } noraise { v => v }
  let r_dense = try to_dense(r) catch { e => fail(e.to_string()) } noraise { v => v }
  inspect(q_dense.map(c => c.to_string()).join(","), content="1,-1,1,-1,1")
  inspect(r_dense.map(c => c.to_string()).join(","), content="0")
  let pair = try div_pair_to_string(q, r) catch { e => fail(e.to_string()) } noraise { v => v }
  inspect(@sympy.normalize_spaces(pair), content="x**4-x**3+x**2-x+1||0")
}

///|
test "euclidtools: divmod oracle parity (x^4+x^3-x-1) / (x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 4),
    expr_pow(expr_sym("x"), 3),
    expr_mul([expr_int(-1), expr_sym("x")]),
    expr_int(-1),
  ])) catch { e => fail(e.to_string()) }
  let d = b.from_expr(expr_add([expr_pow(expr_sym("x"), 2), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  expect_div_oracle(p, d) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: resultant oracle parity (x^2+1, x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([expr_pow(expr_sym("x"), 2), expr_int(1)])) catch {
    e => fail(e.to_string())
  }
  let q = b.from_expr(expr_add([expr_pow(expr_sym("x"), 2), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  expect_resultant_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: resultant oracle parity (x^3-1, x^3+2*x^2+2*x-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([expr_pow(expr_sym("x"), 3), expr_int(-1)])) catch {
    e => fail(e.to_string())
  }
  let q = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 3),
    expr_mul([expr_int(2), expr_pow(expr_sym("x"), 2)]),
    expr_mul([expr_int(2), expr_sym("x")]),
    expr_int(-1),
  ])) catch { e => fail(e.to_string()) }
  expect_resultant_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: resultant oracle parity (x^8-2, x-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([expr_pow(expr_sym("x"), 8), expr_int(-2)])) catch {
    e => fail(e.to_string())
  }
  let q = b.from_expr(expr_add([expr_sym("x"), expr_int(-1)])) catch { e => fail(e.to_string()) }
  expect_resultant_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: resultant oracle parity (3*x^3-x, 5*x^2+1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([
    expr_mul([expr_int(3), expr_pow(expr_sym("x"), 3)]),
    expr_mul([expr_int(-1), expr_sym("x")]),
  ])) catch { e => fail(e.to_string()) }
  let q = b.from_expr(expr_add([
    expr_mul([expr_int(5), expr_pow(expr_sym("x"), 2)]),
    expr_int(1),
  ])) catch { e => fail(e.to_string()) }
  expect_resultant_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: resultant oracle parity (x^2-2*x+1, x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 2),
    expr_mul([expr_int(-2), expr_sym("x")]),
    expr_int(1),
  ])) catch { e => fail(e.to_string()) }
  let q = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 2),
    expr_int(-1),
  ])) catch { e => fail(e.to_string()) }
  expect_resultant_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: resultant oracle parity (x^2-2*x+7, x^3-x+5)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 2),
    expr_mul([expr_int(-2), expr_sym("x")]),
    expr_int(7),
  ])) catch { e => fail(e.to_string()) }
  let q = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 3),
    expr_mul([expr_int(-1), expr_sym("x")]),
    expr_int(5),
  ])) catch { e => fail(e.to_string()) }
  expect_resultant_oracle(p, q) catch { e => fail(e.to_string()) }
}

///|
test "euclidtools: resultant oracle parity (x^3-6*x^2+11*x-6, x^3-15*x^2+74*x-120)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 3),
    expr_mul([expr_int(-6), expr_pow(expr_sym("x"), 2)]),
    expr_mul([expr_int(11), expr_sym("x")]),
    expr_int(-6),
  ])) catch { e => fail(e.to_string()) }
  let q = b.from_expr(expr_add([
    expr_pow(expr_sym("x"), 3),
    expr_mul([expr_int(-15), expr_pow(expr_sym("x"), 2)]),
    expr_mul([expr_int(74), expr_sym("x")]),
    expr_int(-120),
  ])) catch { e => fail(e.to_string()) }
  expect_resultant_oracle(p, q) catch { e => fail(e.to_string()) }
}
