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
  let ours_g = @sympy_polys.normalize_spaces(
    @sympy_polys.sympy_normalize(g.to_string()),
  )
  let oracle_g = @sympy_polys.normalize_spaces(
    @sympy_polys.gcd(p.to_string(), q.to_string()),
  )
  guard ours_g == oracle_g else { fail("gcd mismatch") }

  let (quo, rem) = p.divmod_univar(q)
  let ours_div = @sympy_polys.normalize_spaces(div_pair_to_string(quo, rem))
  let oracle_div = @sympy_polys.normalize_spaces(
    @sympy_polys.div_pair_str(p.to_string(), q.to_string()),
  )
  guard ours_div == oracle_div else { fail("div mismatch") }

  let res = p.resultant(q, 0)
  let ours_res = @sympy_polys.normalize_spaces(
    @sympy_polys.sympy_normalize(res.to_string()),
  )
  let oracle_res = @sympy_polys.normalize_spaces(
    @sympy_polys.resultant(p.to_string(), q.to_string(), var_name="x"),
  )
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
  let ours = @sympy_polys.normalize_spaces(
    @sympy_polys.sort_factor_repr(ours_raw),
  )
  let oracle = @sympy_polys.normalize_spaces(
    @sympy_polys.sort_factor_repr(@sympy_polys.factor_list_str(poly.to_string())),
  )
  guard ours == oracle else { fail("factor_list mismatch") }
}
