///|
test "factor_list x^4 - 1 over ZZ" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(4)),
      @symcore.int(-1),
    ]),
  )
  let (content, factors) = poly.factor_list()
  inspect(content.to_string(), content="1")
  let reprs = factors.map(pair => "(\{pair.0.to_string()}, \{pair.1})")
  reprs.sort()
  let joined = reprs.join(" | ")
  inspect(joined, content="(1 + x, 1) | (-1 + x, 1) | (1 + x**2, 1)")
}

///|
test "factor over GF(5) splits x^2 + 1" {
  let builder = PolyBuilder::new(["x"], Domain::GF(5))
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(1),
    ]),
  )
  let factors = poly.factor()
  let reprs = factors.map(pair => "(\{pair.0.to_string()}, \{pair.1})")
  reprs.sort()
  let joined = reprs.join(" | ")
  inspect(joined, content="(2 + x, 1) | (3 + x, 1)")
}

///|
test "gcd_univar matches x^2-1 and x^2-x" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(-1),
    ]),
  )
  let q = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.mul([@symcore.int(-1), @symcore.symbol("x")]),
    ]),
  )
  let g = p.gcd_univar(q)
  inspect(g.to_string(), content="-1 + x")
}

///|
test "divmod_univar gives quotient and remainder in ZZ" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(1),
    ]),
  )
  let d = builder.from_expr(
    @symcore.add([@symcore.symbol("x"), @symcore.int(1)]),
  )
  let (q, r) = p.divmod_univar(d)
  inspect(q.to_string(), content="-1 + x")
  inspect(r.to_string(), content="2")
}

///|
test "sqf_part removes repeated factors" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = builder.from_expr(
    @symcore.mul([
      @symcore.pow(
        @symcore.add([@symcore.symbol("x"), @symcore.int(-1)]),
        @symcore.int(2),
      ),
      @symcore.add([@symcore.symbol("x"), @symcore.int(2)]),
    ]),
  )
  let sqf = poly.sqf_part()
  inspect(sqf.to_string(), content="-2 + x + x**2")
}

///|
test "groebner simple elimination aligns with SymPy expectation" {
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)
  let f1 = builder.from_expr(
    @symcore.add([
      @symcore.mul([@symcore.symbol("x"), @symcore.symbol("y")]),
      @symcore.int(-1),
    ]),
  )
  let f2 = builder.from_expr(
    @symcore.add([@symcore.symbol("x"), @symcore.int(-1)]),
  )
  let basis = Poly::groebner([f1, f2], order=TermOrder::Lex)
  let repr = basis.map(p => p.to_string()).join(" | ")
  inspect(repr, content="-1 + x | -1 + y")
}

///|
test "polytools: gcd/div/resultant parity with SymPy" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let p = b.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(3)),
      @symcore.int(-1),
    ]),
  )
  let q = b.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(-1),
    ]),
  )
  let g = p.gcd_univar(q)
  let ours_g = sympy_normalize(g.to_string()).trim().to_string()
  let oracle_g = @sympy_polys.gcd(p.to_expr(), q.to_expr()).trim().to_string()
  guard ours_g == oracle_g else { fail("gcd mismatch") }
  let (quo, rem) = p.divmod_univar(q)
  let ours_div = div_pair_to_string(quo, rem).trim().to_string()
  let oracle_div = @sympy_polys.div(p.to_expr(), q.to_expr()).trim().to_string()
  guard ours_div == oracle_div else { fail("div mismatch") }
  let res = p.resultant(q, 0)
  let ours_res = sympy_normalize(res.to_string()).trim().to_string()
  let oracle_res = @sympy_polys
    .resultant(p.to_expr(), q.to_expr(), x="x")
    .trim()
    .to_string()
  guard ours_res == oracle_res else { fail("resultant mismatch") }
}

///|
test "polytools: factor_list parity over QQ" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let poly = b.from_expr(
    @symcore.mul([
      expr_rat(1, 3),
      @symcore.add([
        @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
        @symcore.int(-1),
      ]),
    ]),
  )
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle =
    sort_factor_repr(@sympy_polys.factor_list(poly.to_expr())).trim().to_string()
  guard ours == oracle else { fail("factor_list mismatch") }
}

///|
test "polytools: sqf_list parity over ZZ" {
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
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle =
    sort_factor_repr(@sympy_polys.sqf_list(poly.to_expr())).trim().to_string()
  guard ours == oracle else { fail("sqf_list mismatch") }
}

///|
test "polytools: factor_list parity over GF(2)" {
  let b = PolyBuilder::new(["x"], Domain::GF(2))
  let poly = b.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(6)),
      @symcore.pow(@symcore.symbol("x"), @symcore.int(3)),
      @symcore.int(1),
    ]),
  )
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
    @sympy_polys.factor_list(poly.to_expr(), modulus=2),
  )
  .trim()
  .to_string()
  guard ours == oracle else {
    fail("factor_list GF mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn normalize_basis_str_local(s : String) -> String {
  let parts : Array[String] = Array::new()
  for part in s.split("|") {
    let raw = part.to_string()
    let trimmed = raw.trim().to_string()
    parts.push(trimmed)
  }
  parts.sort()
  parts.join("|")
}

///|
test "polytools: groebner_list parity for multivariate QQ" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let f1 = b.from_expr(
    @symcore.add([
      @symcore.mul([@symcore.symbol("x"), @symcore.symbol("y")]),
      @symcore.int(-1),
    ]),
  )
  let f2 = b.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.pow(@symcore.symbol("y"), @symcore.int(2)),
      @symcore.int(-1),
    ]),
  )
  let basis = Poly::groebner([f1, f2], order=TermOrder::Lex)
  let ours = normalize_basis_str_local(groebner_to_string(basis))
  let exprs = [f1.to_expr(), f2.to_expr()]
  let oracle = normalize_basis_str_local(
    @sympy_polys.groebner(exprs, order="lex"),
  )
  guard ours == oracle else {
    fail("groebner_list mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}
