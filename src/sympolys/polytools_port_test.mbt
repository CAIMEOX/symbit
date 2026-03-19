///|
using @symcore {type Expr, int, symbol}

///|
test "factor_list x^4 - 1 over ZZ" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let poly = builder.from_expr((x ^ int(4)) - int(1))
  let (content, factors) = poly.factor_list()
  inspect(content.to_string(), content="1")
  let reprs = factors.map(pair => "(\{pair.0.to_string()}, \{pair.1})")
  reprs.sort()
  let joined = reprs.join(" | ")
  inspect(joined, content="(x + 1, 1) | (x + -1, 1) | (x**2 + 1, 1)")
}

///|
test "factor over GF(5) splits x^2 + 1" {
  let builder = PolyBuilder::new(["x"], Domain::GF(5))
  let x = symbol("x")
  let poly = builder.from_expr((x ^ int(2)) + int(1))
  let factors = poly.factor()
  let reprs = factors.map(pair => "(\{pair.0.to_string()}, \{pair.1})")
  reprs.sort()
  let joined = reprs.join(" | ")
  inspect(joined, content="(x + 2, 1) | (x + 3, 1)")
}

///|
test "gcd_univar matches x^2-1 and x^2-x" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let p = builder.from_expr((x ^ int(2)) - int(1))
  let q = builder.from_expr((x ^ int(2)) - x)
  let g = p.gcd_univar(q)
  inspect(g.to_string(), content="x + -1")
}

///|
test "divmod_univar gives quotient and remainder in ZZ" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let p = builder.from_expr((x ^ int(2)) + int(1))
  let d = builder.from_expr(x + int(1))
  let (q, r) = p.divmod_univar(d)
  inspect(q.to_string(), content="x + -1")
  inspect(r.to_string(), content="2")
}

///|
test "sqf_part removes repeated factors" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let poly = builder.from_expr(
    ((x - int(1)) ^ int(2)) * (x + int(2)),
  )
  let sqf = poly.sqf_part()
  inspect(sqf.to_string(), content="x**2 + x + -2")
}

///|
test "groebner simple elimination aligns with SymPy expectation" {
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = symbol("x")
  let y = symbol("y")
  let f1 = builder.from_expr(x * y - int(1))
  let f2 = builder.from_expr(x - int(1))
  let basis = Poly::groebner([f1, f2], order=TermOrder::Lex)
  let repr = basis.map(p => p.to_string()).join(" | ")
  inspect(repr, content="x + -1 | y + -1")
}

///|
test "polytools: gcd/div/resultant parity with SymPy" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let p = b.from_expr((x ^ int(3)) - int(1))
  let q = b.from_expr((x ^ int(2)) - int(1))
  let g = p.gcd_univar(q)
  let ours_g = sympy_normalize(g.to_string()).trim().to_string()
  let oracle_g = @sympy_polys.gcd(p.to_expr(), q.to_expr()).trim().to_string()
  assert_eq(ours_g, oracle_g)
  let (quo, rem) = p.divmod_univar(q)
  let ours_div = div_pair_to_string(quo, rem).trim().to_string()
  let oracle_div = @sympy_polys.div(p.to_expr(), q.to_expr()).trim().to_string()
  assert_eq(ours_div, oracle_div)
  let res = p.resultant(q, 0)
  let ours_res = sympy_normalize(res.to_string()).trim().to_string()
  let oracle_res = @sympy_polys.resultant(p.to_expr(), q.to_expr(), x="x")
    .trim()
    .to_string()
  assert_eq(ours_res, oracle_res)
}

///|
test "polytools: gcd_multivar parity over QQ" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = symbol("x")
  let y = symbol("y")
  let p = b.from_expr(x * (x + y))
  let q = b.from_expr(x * (x + int(2)))
  let g = p.gcd_multivar(q)
  let ours = sympy_normalize(g.to_string()).trim().to_string()
  let oracle = @sympy_polys.gcd(
      p.to_expr(),
      q.to_expr(),
      gens=["x", "y"],
      domain="QQ",
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: factor_list parity over QQ" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = symbol("x")
  let poly = b.from_expr(
    expr_rat(1, 3) * ((x ^ int(2)) - int(1)),
  )
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(@sympy_polys.factor_list(poly.to_expr()))
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: sqf_list parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let poly = b.from_expr(
    ((x - int(2)) ^ int(2)) *
    ((x + int(3)) ^ int(3)),
  )
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(@sympy_polys.sqf_list(poly.to_expr()))
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: factor_list parity over GF(2)" {
  let b = PolyBuilder::new(["x"], Domain::GF(2))
  let x = symbol("x")
  let poly = b.from_expr(
    (x ^ int(6)) + (x ^ int(3)) + int(1),
  )
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
      @sympy_polys.factor_list(poly.to_expr(), modulus=2),
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
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
test "polytools: factor_list parity over GF(5) simple" {
  let b = PolyBuilder::new(["x"], Domain::GF(5))
  let x = symbol("x")
  let poly = b.from_expr((x ^ int(2)) + int(1))
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
      @sympy_polys.factor_list(poly.to_expr(), modulus=5),
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: factor_list parity over GF(7) simple" {
  let b = PolyBuilder::new(["x"], Domain::GF(7))
  let x = symbol("x")
  let poly = b.from_expr((x ^ int(2)) + int(2))
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
      @sympy_polys.factor_list(poly.to_expr(), modulus=7),
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: gcd/div parity over GFExt(5^2)" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = symbol("x")
  let p = b.from_expr((x ^ int(2)) + x + int(1))
  let q = b.from_expr(x + int(1))
  let g = p.gcd_univar(q)
  let ours_g = sympy_normalize(g.to_string()).trim().to_string()
  let oracle_g = @sympy_polys.gcd(
      p.to_expr(),
      q.to_expr(),
      modulus=5,
      gfext_modulus=[1, 0, 1],
      gfext_gen="a",
    )
    .trim()
    .to_string()
  assert_eq(ours_g, oracle_g)
  let (quo, rem) = p.divmod_univar(q)
  let ours_div = div_pair_to_string(quo, rem).trim().to_string()
  let oracle_div = @sympy_polys.div(
      p.to_expr(),
      q.to_expr(),
      modulus=5,
      gfext_modulus=[1, 0, 1],
      gfext_gen="a",
    )
    .trim()
    .to_string()
  assert_eq(ours_div, oracle_div)
}

///|
test "polytools: gcd/div parity over GFExt(5^2) extra" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = symbol("x")
  let p = b.from_expr(
    (x ^ int(3)) + int(2) * x + int(1),
  )
  let q = b.from_expr((x ^ int(2)) + int(1))
  let g = p.gcd_univar(q)
  let ours_g = sympy_normalize(g.to_string()).trim().to_string()
  let oracle_g = @sympy_polys.gcd(
      p.to_expr(),
      q.to_expr(),
      modulus=5,
      gfext_modulus=[1, 0, 1],
      gfext_gen="a",
    )
    .trim()
    .to_string()
  assert_eq(ours_g, oracle_g)
  let (quo, rem) = p.divmod_univar(q)
  let ours_div = div_pair_to_string(quo, rem).trim().to_string()
  let oracle_div = @sympy_polys.div(
      p.to_expr(),
      q.to_expr(),
      modulus=5,
      gfext_modulus=[1, 0, 1],
      gfext_gen="a",
    )
    .trim()
    .to_string()
  assert_eq(ours_div, oracle_div)
}

///|
test "polytools: sqf_list parity over GFExt(5^2)" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = symbol("x")
  let poly = b.from_expr(
    ((x + int(1)) ^ int(2)) * (x + int(2)),
  )
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
      @sympy_polys.sqf_list(
        poly.to_expr(),
        modulus=5,
        gfext_modulus=[1, 0, 1],
        gfext_gen="a",
      ),
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: sqf_list parity over GFExt(5^2) extra" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = symbol("x")
  let poly = b.from_expr(
    ((x + int(2)) ^ int(3)) *
    ((x ^ int(2)) + x + int(1)),
  )
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
      @sympy_polys.sqf_list(
        poly.to_expr(),
        modulus=5,
        gfext_modulus=[1, 0, 1],
        gfext_gen="a",
      ),
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: factor_list GFExt self-consistent" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = symbol("x")
  let poly = b.from_expr(
    ((x + int(1)) ^ int(2)) * (x + int(2)),
  )
  let (content, factors) = poly.factor_list()
  assert_true(content.is_one())
  let mut acc = Poly::one(poly.gens, poly.domain)
  for entry in factors {
    let (f, m) = entry
    for _ in 0..<m {
      acc = acc.mul(f)
    }
  }
  let lhs = acc.to_string()
  let rhs = poly.to_string()
  assert_eq(lhs, rhs)
}

///|

///|
test "polytools: factor_list parity over QQ with repeated factor" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = symbol("x")
  let poly = b.from_expr(
    expr_rat(1, 6) *
    ((x ^ int(2)) - int(2) * x + int(1)),
  )
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(@sympy_polys.factor_list(poly.to_expr()))
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: groebner_list parity for multivariate QQ" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = symbol("x")
  let y = symbol("y")
  let f1 = b.from_expr(x * y - int(1))
  let f2 = b.from_expr(
    (x ^ int(2)) + (y ^ int(2)) - int(1),
  )
  let basis = Poly::groebner([f1, f2], order=TermOrder::Lex)
  let ours = normalize_basis_str_local(groebner_to_string(basis))
  let exprs = [f1.to_expr(), f2.to_expr()]
  let oracle = normalize_basis_str_local(
    @sympy_polys.groebner(exprs, order="lex"),
  )
  assert_eq(ours, oracle)
}

///|
test "polytools: gcd_list parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(2)) - int(1))
  let g = b.from_expr((x ^ int(2)) - x)
  let h = b.from_expr((x ^ int(2)) - int(4))
  let ours = sympy_normalize(gcd_list([f, g, h]).to_string()).trim().to_string()
  let oracle = @sympy_polys.gcd_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: lcm_list parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(2)) - int(1))
  let g = b.from_expr((x ^ int(2)) - x)
  let h = b.from_expr((x ^ int(2)) - int(4))
  let ours = sympy_normalize(lcm_list([f, g, h]).to_string()).trim().to_string()
  let oracle = @sympy_polys.lcm_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: terms_gcd parity over ZZ" {
  let b = PolyBuilder::new(["x", "y"], Domain::ZZ)
  let x = symbol("x")
  let y = symbol("y")
  let f = b.from_expr(
    int(2) * (x ^ int(2)) * (y ^ int(3)) +
    int(4) * x * (y ^ int(2)),
  )
  let ours = sympy_normalize(terms_gcd(f).to_string()).trim().to_string()
  let oracle = @sympy_polys.terms_gcd(f.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: sqf_list parity over GF(5)" {
  let b = PolyBuilder::new(["x"], Domain::GF(5))
  let x = symbol("x")
  let poly = b.from_expr(
    ((x + int(1)) ^ int(2)) * (x + int(2)),
  )
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
      @sympy_polys.sqf_list(poly.to_expr(), modulus=5),
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: sqf_list parity over GF(7)" {
  let b = PolyBuilder::new(["x"], Domain::GF(7))
  let x = symbol("x")
  let poly = b.from_expr(
    ((x + int(1)) ^ int(2)) * (x + int(2)),
  )
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_string()
  let oracle = sort_factor_repr(
      @sympy_polys.sqf_list(poly.to_expr(), modulus=7),
    )
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: cancel parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let num = b.from_expr((x ^ int(2)) - int(1))
  let den = b.from_expr(x - int(1))
  let (n2, d2) = cancel(num, den)
  let ours = div_pair_to_string(n2, d2).trim().to_string()
  let oracle = @sympy_polys.cancel(num.to_expr(), den.to_expr())
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: cancel parity multivariate (no common factor)" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = symbol("x")
  let y = symbol("y")
  let num = b.from_expr(x * y + x + int(1))
  let den = b.from_expr(x + y + int(1))
  let (n2, d2) = cancel(num, den)
  let ours = div_pair_to_string(n2, d2).trim().to_string()
  let oracle = @sympy_polys.cancel(num.to_expr(), den.to_expr())
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: cancel parity multivariate with common x+y factor" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = symbol("x")
  let y = symbol("y")
  let num = b.from_expr((x + y) * (x + int(1)))
  let den = b.from_expr(x + y)
  let (n2, d2) = cancel(num, den)
  let ours = div_pair_to_string(n2, d2).trim().to_string()
  let oracle = @sympy_polys.cancel(num.to_expr(), den.to_expr())
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: reduced parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(2)) + int(1))
  let g = b.from_expr(x - int(1))
  let (qs, r) = reduced(f, [g])
  let ours = reduced_pair_to_string(qs, r).trim().to_string()
  let oracle = @sympy_polys.reduced(f.to_expr(), [g.to_expr()])
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: reduced parity multivariate over ZZ" {
  let b = PolyBuilder::new(["x", "y"], Domain::ZZ)
  let x = symbol("x")
  let y = symbol("y")
  let f = b.from_expr((x ^ int(2)) * y + x * y + y)
  let g1 = b.from_expr(x * y - int(1))
  let g2 = b.from_expr(y - int(1))
  let (qs, r) = reduced(f, [g1, g2])
  let ours = reduced_pair_to_string(qs, r).trim().to_string()
  let oracle = @sympy_polys.reduced(f.to_expr(), [g1.to_expr(), g2.to_expr()])
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: reduced parity multivariate over QQ" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = symbol("x")
  let y = symbol("y")
  let f = b.from_expr((x ^ int(2)) * y + x * y + y)
  let g1 = b.from_expr(x * y - int(1))
  let g2 = b.from_expr(y - int(1))
  let (qs, r) = reduced(f, [g1, g2])
  let ours = reduced_pair_to_string(qs, r).trim().to_string()
  let oracle = @sympy_polys.reduced(f.to_expr(), [g1.to_expr(), g2.to_expr()])
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: compose parity multivariate should error" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = symbol("x")
  let y = symbol("y")
  let f = b.from_expr(x * y + int(1))
  let g = b.from_expr(x + y)
  let ours : Result[Poly, _] = try? compose(f, g)
  assert_true(ours is Err(_))
}

///|
test "polytools: decompose parity for cubic" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(6)) - int(1))
  let parts = decompose(f)
  let ours = parts.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = @sympy_polys.decompose(f.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: reduced parity with two divisors" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(3)) - int(1))
  let g1 = b.from_expr(x - int(1))
  let g2 = b.from_expr(x + int(1))
  let (qs, r) = reduced(f, [g1, g2])
  let ours = reduced_pair_to_string(qs, r).trim().to_string()
  let oracle = @sympy_polys.reduced(f.to_expr(), [g1.to_expr(), g2.to_expr()])
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: compose parity over QQ" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(2)) + int(1))
  let g = b.from_expr(x + int(1))
  let h = compose(f, g)
  let ours = sympy_normalize(h.to_string()).trim().to_string()
  let oracle = @sympy_polys.compose(f.to_expr(), g.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: compose parity higher degree" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(4)) + x)
  let g = b.from_expr((x ^ int(2)) + x)
  let h = compose(f, g)
  let ours = sympy_normalize(h.to_string()).trim().to_string()
  let oracle = @sympy_polys.compose(f.to_expr(), g.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: decompose parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(8)) + int(1))
  let parts = decompose(f)
  let ours = parts.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = @sympy_polys.decompose(f.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: decompose parity for nondecomposable" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(2)) + int(1))
  let parts = decompose(f)
  let ours = parts.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = @sympy_polys.decompose(f.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: sturm sequence parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(3)) - int(1))
  let seq = sturm_sequence(f)
  let ours = seq.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = @sympy_polys.sturm(f.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: discriminant parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(2)) - int(1))
  let disc = discriminant(f)
  let ours = fe_to_string(disc).trim().to_string()
  let oracle = @sympy_polys.discriminant(f.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "polytools: subresultants parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = symbol("x")
  let f = b.from_expr((x ^ int(2)) - int(1))
  let g = b.from_expr(x - int(1))
  let seq = subresultants(f, g)
  let ours = seq.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = @sympy_polys.subresultants(f.to_expr(), g.to_expr())
    .trim()
    .to_string()
  assert_eq(ours, oracle)
}
