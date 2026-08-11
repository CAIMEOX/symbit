///|
using @symcore {type Expr, int}

///|
test "factor_list x^4 - 1 over ZZ" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let poly = builder.from_expr((x ^ int(4)) - int(1))
  let (content, factors) = poly.factor_list()
  inspect(content, content="1")
  let reprs = factors.map(pair => "(\{pair.0.to_string()}, \{pair.1})")
  reprs.sort()
  let joined = reprs.join(" | ")
  inspect(joined, content="(x + 1, 1) | (x + -1, 1) | (x**2 + 1, 1)")
}

///|
test "factor over GF(5) splits x^2 + 1" {
  let builder = PolyBuilder::new(["x"], Domain::GF(5))
  let x = Expr::Symbol("x")
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
  let x = Expr::Symbol("x")
  let p = builder.from_expr((x ^ int(2)) - int(1))
  let q = builder.from_expr((x ^ int(2)) - x)
  let g = p.gcd_univar(q)
  inspect(g, content="x + -1")
}

///|
test "divmod_univar gives quotient and remainder in ZZ" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let p = builder.from_expr((x ^ int(2)) + int(1))
  let d = builder.from_expr(x + int(1))
  let (q, r) = p.divmod_univar(d)
  inspect(q, content="x + -1")
  inspect(r, content="2")
}

///|
test "sqf_part removes repeated factors" {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let poly = builder.from_expr(((x - int(1)) ^ int(2)) * (x + int(2)))
  let sqf = poly.sqf_part()
  inspect(sqf, content="x**2 + x + -2")
}

///|
test "groebner simple elimination aligns with SymPy expectation" {
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let f1 = builder.from_expr(x * y - int(1))
  let f2 = builder.from_expr(x - int(1))
  let basis = Poly::groebner([f1, f2], order=TermOrder::Lex)
  let repr = basis.map(p => p.to_string()).join(" | ")
  inspect(repr, content="x + -1 | y + -1")
}

///|
test "polytools: gcd/div/resultant parity with SymPy" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let p = b.from_expr((x ^ int(3)) - int(1))
  let q = b.from_expr((x ^ int(2)) - int(1))
  let g = p.gcd_univar(q)
  let ours_g = sympy_normalize(g.to_string()).trim().to_owned()
  let oracle_g = gcd(p.to_expr(), q.to_expr()).trim().to_owned()
  assert_eq(ours_g, oracle_g)
  let (quo, rem) = p.divmod_univar(q)
  let ours_div = div_pair_to_string(quo, rem).trim().to_owned()
  let oracle_div = div(p.to_expr(), q.to_expr()).trim().to_owned()
  assert_eq(ours_div, oracle_div)
  let res = p.resultant(q, 0)
  let ours_res = sympy_normalize(res.to_string()).trim().to_owned()
  let oracle_res = resultant(p.to_expr(), q.to_expr(), x="x").trim().to_owned()
  assert_eq(ours_res, oracle_res)
}

///|
test "polytools: public frontdoor parity with SymPy" {
  let bm = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let p = bm.from_expr(
    int(4) * (x ^ int(2)) + int(2) * x * (y ^ int(2)) + x * y + int(3) * y,
  )
  assert_eq(
    @sympolys.degree(p, gen_index=0).to_string(),
    degree(p.to_expr(), gen="x"),
  )
  assert_eq(
    "(\{@sympolys.degree_list(p)[0]}, \{@sympolys.degree_list(p)[1]})",
    degree_list(p.to_expr(), gens=["x", "y"]),
  )
  assert_eq(
    @sympolys.lc(p).to_string(),
    polytools_lc(p.to_expr(), gens=["x", "y"]),
  )
  assert_eq(
    remove_spaces(@symprint.pretty_string(@sympolys.lm(p))),
    remove_spaces(polytools_lm(p.to_expr(), gens=["x", "y"])),
  )
  assert_eq(
    remove_spaces(@symprint.pretty_string(@sympolys.lt(p))),
    remove_spaces(polytools_lt(p.to_expr(), gens=["x", "y"])),
  )
  let bu = PolyBuilder::new(["x"], Domain::ZZ)
  let f = bu.from_expr((x ^ int(2)) + int(1))
  let g = bu.from_expr(int(2) * x - int(4))
  let (pq, pr) = @sympolys.pdiv(f, g)
  let ours_pdiv = remove_spaces(
    "\{sympy_normalize(pq.to_string())}||\{sympy_normalize(pr.to_string())}",
  )
  let oracle_pdiv = remove_spaces(pdiv(f.to_expr(), g.to_expr()))
  assert_eq(ours_pdiv, oracle_pdiv)
  assert_eq(
    remove_spaces(sympy_normalize(@sympolys.pquo(f, g).to_string())),
    remove_spaces(pquo(f.to_expr(), g.to_expr())),
  )
  assert_eq(
    remove_spaces(sympy_normalize(@sympolys.prem(f, g).to_string())),
    remove_spaces(prem(f.to_expr(), g.to_expr())),
  )
  let exact = bu.from_expr((x ^ int(2)) - int(1))
  let divisor = bu.from_expr(x + int(1))
  let (dq, dr) = @sympolys.div(exact, divisor)
  let ours_div = div_pair_to_string(dq, dr).trim().to_owned()
  let oracle_div = div(exact.to_expr(), divisor.to_expr()).trim().to_owned()
  assert_eq(ours_div, oracle_div)
  let (content, factors) = @sympolys.factor_list(exact)
  let ours_factor = sort_factor_repr(
    factor_list_to_string(content.to_string(), factors),
  )
  let oracle_factor = sort_factor_repr(factor_list(exact.to_expr()))
  assert_eq(ours_factor, oracle_factor)
  assert_eq(
    remove_spaces(sympy_normalize(@sympolys.monic(g).to_string())),
    remove_spaces(monic(g.to_expr())),
  )
}

///|
fn polytools_port_rat(num : Int, den : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(num, den) catch {
    _ => abort("polytools parity rational expects nonzero denominator")
  }
}

///|
fn polytools_port_iv_repr(
  item : ((@symnum.BigRational, @symnum.BigRational), Int),
) -> String {
  let ((a, b), mult) = item
  "((\{a}, \{b}), \{mult})"
}

///|
fn nf_port_iv_text(iv : (@symnum.BigRational, @symnum.BigRational)) -> String {
  "(\{iv.0}, \{iv.1})"
}

///|
fn polytools_port_interval_list_repr(
  items : Array[((@symnum.BigRational, @symnum.BigRational), Int)],
) -> String {
  let body = items.map(polytools_port_iv_repr).join(", ")
  "[\{body}]"
}

///|
fn polytools_port_expr_list_repr(items : Array[Expr]) -> String {
  let body = items.map(item => @symprint.pretty_string(item)).join(", ")
  "[\{body}]"
}

///|
fn polytools_port_ground_roots_repr(items : Array[(Expr, Int)]) -> String {
  let body = items
    .map(item => {
      let root = @symprint.pretty_string(item.0)
      "\{root}: \{item.1}"
    })
    .join(", ")
  "{\{body}}"
}

///|
fn polytools_port_prime_decomp_repr(
  items : Array[@sympolys.PrimeIdeal],
) -> String {
  let body = items
    .map(item => {
      let factor = if item.has_generator {
        item.factor.to_string()
      } else {
        "0"
      }
      "(\{item.p}, \{factor}) e=\{item.ramification}, f=\{item.residue_degree}"
    })
    .join(", ")
  "[[ \{body} ]]"
}

///|
test "polytools: extended euclid and root frontdoor parity with SymPy" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr(
    (x ^ int(4)) -
    int(2) * (x ^ int(3)) -
    int(6) * (x ^ int(2)) +
    int(12) * x +
    int(15),
  )
  let g = b.from_expr((x ^ int(3)) + (x ^ int(2)) - int(4) * x - int(4))
  let (hs, hh) = @sympolys.half_gcdex(f, g)
  let ours_half = remove_spaces(
    "\{sympy_normalize(hs.to_string())}||\{sympy_normalize(hh.to_string())}",
  )
  let oracle_half = remove_spaces(half_gcdex(f.to_expr(), g.to_expr()))
  assert_eq(ours_half, oracle_half)

  let (s, t, h) = @sympolys.gcdex(f, g)
  let ours_gcdex = remove_spaces(
    "\{sympy_normalize(s.to_string())}||\{sympy_normalize(t.to_string())}||\{sympy_normalize(h.to_string())}",
  )
  let oracle_gcdex = remove_spaces(gcdex(f.to_expr(), g.to_expr()))
  assert_eq(ours_gcdex, oracle_gcdex)

  let inv_poly = @sympolys.invert(
    b.from_expr((x ^ int(2)) - int(1)),
    b.from_expr(int(2) * x - int(1)),
  )
  assert_eq(
    remove_spaces(sympy_normalize(inv_poly.to_string())),
    remove_spaces(invert((x ^ int(2)) - int(1), int(2) * x - int(1))),
  )

  let trunc_poly = b.from_expr(
    int(2) * (x ^ int(3)) + int(3) * (x ^ int(2)) + int(5) * x + int(7),
  )
  assert_eq(
    remove_spaces(sympy_normalize(@sympolys.trunc(trunc_poly, 3).to_string())),
    remove_spaces(trunc(trunc_poly.to_expr(), 3)),
  )

  let q = b.from_expr((x ^ int(2)) - int(3))
  assert_eq(
    polytools_port_interval_list_repr(@sympolys.intervals(q)),
    intervals(q.to_expr()),
  )
  let refined = @sympolys.refine_root(
    q,
    polytools_port_rat(1, 1),
    polytools_port_rat(2, 1),
    eps=polytools_port_rat(1, 100),
  )
  assert_eq(
    "(\{refined.0.to_string()}, \{refined.1.to_string()})",
    refine_root(q.to_expr(), 1, 1, 2, 1, eps_num=1, eps_den=100),
  )
  let count_poly = b.from_expr((x ^ int(4)) - int(4))
  assert_eq(
    @sympolys.count_roots(
      count_poly,
      inf=polytools_port_rat(-3, 1),
      sup=polytools_port_rat(3, 1),
    ).to_string(),
    count_roots(
      count_poly.to_expr(),
      inf_num=-3,
      sup_num=3,
      has_inf=true,
      has_sup=true,
    ),
  )
  let simple = b.from_expr((x ^ int(2)) - int(1))
  assert_eq(
    polytools_port_expr_list_repr(@sympolys.all_roots(simple)),
    all_roots(simple.to_expr()),
  )
  let ground_poly = b.from_expr(
    (x ^ int(6)) - int(4) * (x ^ int(4)) + int(4) * (x ^ int(3)) - (x ^ int(2)),
  )
  assert_eq(
    polytools_port_ground_roots_repr(@sympolys.ground_roots(ground_poly)),
    ground_roots(ground_poly.to_expr()),
  )
}

///|
test "polytools: constructor gff and stability frontdoor parity with SymPy" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let expr = (x ^ int(5)) +
    int(2) * (x ^ int(4)) -
    (x ^ int(3)) -
    int(2) * (x ^ int(2))
  let p = b.from_expr(expr)
  assert_eq(
    remove_spaces(sympy_normalize(@sympolys.poly_from_expr(expr).to_string())),
    remove_spaces(poly_from_expr_front(expr)),
  )
  let parallel = @sympolys.parallel_poly_from_expr([
    x + @symcore.rational_from_ints(1, 3),
    x + int(2),
  ])
  let parallel_ours = parallel
    .map(item => sympy_normalize(item.to_string()))
    .join("||")
  let parallel_oracle = parallel_poly_from_expr_front([
    x + @symcore.rational_from_ints(1, 3),
    x + int(2),
  ])
  assert_eq(remove_spaces(parallel_ours), remove_spaces(parallel_oracle))
  assert_eq(
    remove_spaces(sympy_normalize(@sympolys.poly(expr).to_string())),
    remove_spaces(poly_front(expr)),
  )
  let gff_ours = @sympolys.gff_list(p)
    .map(pair => "(\{sympy_normalize(pair.0.to_string())}, \{pair.1})")
    .join("||")
  assert_eq(remove_spaces(gff_ours), remove_spaces(gff_list(expr)))
  let repeated = b.from_expr(((x - int(1)) ^ int(2)) * (x + int(2)))
  assert_eq(
    remove_spaces(sympy_normalize(@sympolys.sqf(repeated).to_string())),
    remove_spaces(sqf(repeated.to_expr())),
  )
  let cubic = b.from_expr(
    int(2) * (x ^ int(3)) - int(7) * (x ^ int(2)) + int(4) * x + int(4),
  )
  assert_eq(
    remove_spaces(polytools_port_expr_list_repr(@sympolys.real_roots(cubic))),
    remove_spaces(real_roots(cubic.to_expr())),
  )
  let powered = b.from_expr((x ^ int(4)) - (x ^ int(2)) + int(1))
  assert_eq(
    remove_spaces(
      sympy_normalize(@sympolys.nth_power_roots_poly(powered, 2).to_string()),
    ),
    remove_spaces(nth_power_roots_poly(powered.to_expr(), 2)),
  )
  assert_true(
    remove_spaces(nroots((x ^ int(2)) - int(3))).has_prefix("[-1.732"),
  )
  let bm = PolyBuilder::new(["x", "y"], Domain::QQ)
  let y = Expr::Symbol("y")
  let finite = [bm.from_expr((x ^ int(2)) - int(1)), bm.from_expr(y - x)]
  let curve = [bm.from_expr(x * y - int(1))]
  assert_eq(
    @sympolys.is_zero_dimensional(finite).to_string(),
    if is_zero_dimensional(finite.map(item => item.to_expr())) == "True" {
      "true"
    } else {
      "false"
    },
  )
  assert_eq(
    @sympolys.is_zero_dimensional(curve).to_string(),
    if is_zero_dimensional(curve.map(item => item.to_expr())) == "True" {
      "true"
    } else {
      "false"
    },
  )
  let k = Expr::Symbol("k")
  let stable = PolyBuilder::new(["x", "k"], Domain::ZZ).from_expr(
    (x ^ int(3)) + (x ^ int(2)) + int(2) * k * x + int(1) - k,
  )
  assert_eq(
    remove_spaces(
      polytools_port_expr_list_repr(@sympolys.hurwitz_conditions(stable)),
    ),
    remove_spaces(hurwitz_conditions(stable.to_expr(), gens=["x"])),
  )
  assert_eq(
    remove_spaces(
      polytools_port_expr_list_repr(@sympolys.schur_conditions(stable)),
    ),
    remove_spaces(schur_conditions(stable.to_expr(), gens=["x"])),
  )

  let together_expr = (x ^ int(-1)) + (y ^ int(-1)) + ((x * y) ^ int(-1))
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.together(together_expr)),
      ),
    ),
    remove_spaces(together(together_expr)),
  )
  let together_func = @symcore.function("exp", [(x ^ int(-1)) + (y ^ int(-1))])
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.together(together_func, deep=true)),
      ),
    ),
    remove_spaces(together(together_func, deep=true)),
  )
  let apart_expr = y * ((x + int(2)) ^ int(-1)) * ((x + int(1)) ^ int(-1))
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.apart(apart_expr, gen="x")),
      ),
    ),
    remove_spaces(apart(apart_expr, gen="x")),
  )
  let apart_structured = @sympolys.apart_list(apart_expr, gen="x")
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(
          @sympolys.assemble_partfrac_list(apart_structured),
        ),
      ),
    ),
    remove_spaces(apart(apart_expr, gen="x")),
  )
  let apart_irreducible = y * (((x ^ int(2)) + x + int(1)) ^ int(-1))
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.apart(apart_irreducible, gen="x")),
      ),
    ),
    remove_spaces(apart(apart_irreducible, gen="x")),
  )
  let pf_builder = @sympolys.PolyBuilder::new(["x"], @sympolys.Domain::QQ)
  let pf_p = pf_builder.from_expr(int(1))
  let pf_q = pf_builder.from_expr((x ^ int(2)) - int(1))
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.apart_undetermined_coeffs(pf_p, pf_q)),
      ),
    ),
    remove_spaces(
      apart_undetermined_coeffs(pf_p.to_expr(), pf_q.to_expr(), "x"),
    ),
  )
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.apart_full_decomposition(pf_p, pf_q)),
      ),
    ),
    remove_spaces(apart_full_decomposition(pf_p.to_expr(), pf_q.to_expr(), "x")),
  )
  let pf_terms = @sympolys.apart_list_full_decomposition(pf_p, pf_q)
  assert_eq(
    pf_terms.length(),
    apart_list_full_decomposition_count(pf_p.to_expr(), pf_q.to_expr(), "x"),
  )

  let a = Expr::Symbol("a")
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [(a ^ int(2)) - int(3)])
  let alg_poly = PolyBuilder::new(["x"], alg_domain).from_expr(
    (x ^ int(2)) - int(2),
  )
  let (sqf_shifts, sqf_shifted, sqf_norm_poly) = @sympolys.sqf_norm(alg_poly)
  let ours_sqf_norm = "(\{Repr(sqf_shifts).to_string()}, \{sympy_normalize(sqf_shifted.to_string())}, \{sympy_normalize(sqf_norm_poly.to_string())})"
  let oracle_sqf_norm = sqf_norm(
    (x ^ int(2)) - int(2),
    gens=["x"],
    extension="sqrt(3)",
  ).replace_all(old="sqrt(3)", new="a")
  assert_eq(remove_spaces(ours_sqf_norm), remove_spaces(oracle_sqf_norm))

  let galois_cases = [
    b.from_expr(x - int(1)),
    b.from_expr((x ^ int(2)) - int(2)),
    b.from_expr((x ^ int(3)) - int(2)),
    b.from_expr((x ^ int(3)) - int(3) * x + int(1)),
  ]
  for item in galois_cases {
    let ours_galois = @sympolys.galois_group(item)
    assert_eq(
      "(\{ours_galois.name}, \{ours_galois.is_alt})",
      galois_group(item.to_expr(), gens=["x"]),
    )
    assert_eq(
      @sympolys.has_square_disc(item),
      has_square_disc(item.to_expr(), gens=["x"]),
    )
  }
  let square_disc_reducible = b.from_expr((x ^ int(2)) - int(4))
  assert_eq(
    @sympolys.has_square_disc(square_disc_reducible),
    has_square_disc(square_disc_reducible.to_expr(), gens=["x"]),
  )

  let sqrt2 = int(2) ^ @symcore.rational_from_ints(1, 2)
  assert_eq(nf_port_iv_text(@sympolys.isolate(sqrt2)), isolate(sqrt2))
  assert_eq(
    @sympolys.round_two(b.from_expr((x ^ int(2)) - int(5))).to_string(),
    round_two((x ^ int(2)) - int(5), gens=["x"]),
  )
  assert_eq(
    polytools_port_prime_decomp_repr(
      @sympolys.prime_decomp(2, b.from_expr((x ^ int(2)) - int(2))),
    ),
    prime_decomp(2, (x ^ int(2)) - int(2), gens=["x"]),
  )
}

///|
test "polytools: gcd_multivar parity over QQ" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let p = b.from_expr(x * (x + y))
  let q = b.from_expr(x * (x + int(2)))
  let g = p.gcd_multivar(q)
  let ours = sympy_normalize(g.to_string()).trim().to_owned()
  let oracle = gcd(p.to_expr(), q.to_expr(), gens=["x", "y"], domain="QQ")
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: factor_list parity over QQ" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = Expr::Symbol("x")
  let poly = b.from_expr(expr_rat(1, 3) * ((x ^ int(2)) - int(1)))
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(factor_list(poly.to_expr())).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: sqf_list parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let poly = b.from_expr(((x - int(2)) ^ int(2)) * ((x + int(3)) ^ int(3)))
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(sqf_list(poly.to_expr())).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: factor_list parity over GF(2)" {
  let b = PolyBuilder::new(["x"], Domain::GF(2))
  let x = Expr::Symbol("x")
  let poly = b.from_expr((x ^ int(6)) + (x ^ int(3)) + int(1))
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(factor_list(poly.to_expr(), modulus=2))
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
fn normalize_basis_str_local(s : String) -> String {
  let parts : Array[String] = Array::new()
  for part in s.split("|") {
    let raw = part.to_owned()
    let trimmed = raw.trim().to_owned()
    parts.push(trimmed)
  }
  parts.sort()
  parts.join("|")
}

///|
test "polytools: factor_list parity over GF(5) simple" {
  let b = PolyBuilder::new(["x"], Domain::GF(5))
  let x = Expr::Symbol("x")
  let poly = b.from_expr((x ^ int(2)) + int(1))
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(factor_list(poly.to_expr(), modulus=5))
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: factor_list parity over GF(7) simple" {
  let b = PolyBuilder::new(["x"], Domain::GF(7))
  let x = Expr::Symbol("x")
  let poly = b.from_expr((x ^ int(2)) + int(2))
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(factor_list(poly.to_expr(), modulus=7))
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: gcd/div parity over GFExt(5^2)" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = Expr::Symbol("x")
  let p = b.from_expr((x ^ int(2)) + x + int(1))
  let q = b.from_expr(x + int(1))
  let g = p.gcd_univar(q)
  let ours_g = sympy_normalize(g.to_string()).trim().to_owned()
  let oracle_g = gcd(
      p.to_expr(),
      q.to_expr(),
      modulus=5,
      gfext_modulus=[1, 0, 1],
      gfext_gen="a",
    )
    .trim()
    .to_owned()
  assert_eq(ours_g, oracle_g)
  let (quo, rem) = p.divmod_univar(q)
  let ours_div = div_pair_to_string(quo, rem).trim().to_owned()
  let oracle_div = div(
      p.to_expr(),
      q.to_expr(),
      modulus=5,
      gfext_modulus=[1, 0, 1],
      gfext_gen="a",
    )
    .trim()
    .to_owned()
  assert_eq(ours_div, oracle_div)
}

///|
test "polytools: gcd/div parity over GFExt(5^2) extra" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = Expr::Symbol("x")
  let p = b.from_expr((x ^ int(3)) + int(2) * x + int(1))
  let q = b.from_expr((x ^ int(2)) + int(1))
  let g = p.gcd_univar(q)
  let ours_g = sympy_normalize(g.to_string()).trim().to_owned()
  let oracle_g = gcd(
      p.to_expr(),
      q.to_expr(),
      modulus=5,
      gfext_modulus=[1, 0, 1],
      gfext_gen="a",
    )
    .trim()
    .to_owned()
  assert_eq(ours_g, oracle_g)
  let (quo, rem) = p.divmod_univar(q)
  let ours_div = div_pair_to_string(quo, rem).trim().to_owned()
  let oracle_div = div(
      p.to_expr(),
      q.to_expr(),
      modulus=5,
      gfext_modulus=[1, 0, 1],
      gfext_gen="a",
    )
    .trim()
    .to_owned()
  assert_eq(ours_div, oracle_div)
}

///|
test "polytools: sqf_list parity over GFExt(5^2)" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = Expr::Symbol("x")
  let poly = b.from_expr(((x + int(1)) ^ int(2)) * (x + int(2)))
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(
      sqf_list(
        poly.to_expr(),
        modulus=5,
        gfext_modulus=[1, 0, 1],
        gfext_gen="a",
      ),
    )
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: sqf_list parity over GFExt(5^2) extra" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = Expr::Symbol("x")
  let poly = b.from_expr(((x + int(2)) ^ int(3)) * ((x ^ int(2)) + x + int(1)))
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(
      sqf_list(
        poly.to_expr(),
        modulus=5,
        gfext_modulus=[1, 0, 1],
        gfext_gen="a",
      ),
    )
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: factor_list GFExt self-consistent" {
  let domain = Domain::GFExt(5, 2, [1, 0, 1])
  let b = PolyBuilder::new(["x"], domain)
  let x = Expr::Symbol("x")
  let poly = b.from_expr(((x + int(1)) ^ int(2)) * (x + int(2)))
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
  let x = Expr::Symbol("x")
  let poly = b.from_expr(expr_rat(1, 6) * ((x ^ int(2)) - int(2) * x + int(1)))
  let (content, factors) = poly.factor_list()
  let ours_raw = factor_list_to_string(content.to_string(), factors)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(factor_list(poly.to_expr())).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: groebner_list parity for multivariate QQ" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let f1 = b.from_expr(x * y - int(1))
  let f2 = b.from_expr((x ^ int(2)) + (y ^ int(2)) - int(1))
  let basis = Poly::groebner([f1, f2], order=TermOrder::Lex)
  let ours = normalize_basis_str_local(groebner_to_string(basis))
  let basis_obj = @sympolys.groebner_basis([f1, f2], order=TermOrder::Lex)
  let ours_structured = normalize_basis_str_local(
    groebner_to_string(basis_obj.polys),
  )
  let exprs = [f1.to_expr(), f2.to_expr()]
  let oracle = normalize_basis_str_local(groebner(exprs, order="lex"))
  assert_eq(ours, oracle)
  assert_eq(ours_structured, oracle)
  assert_eq(basis_obj.gens, ["x", "y"])
  assert_true(basis_obj.order == TermOrder::Lex)
}

///|
test "polytools: gcd_list parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(2)) - int(1))
  let g = b.from_expr((x ^ int(2)) - x)
  let h = b.from_expr((x ^ int(2)) - int(4))
  let ours = sympy_normalize(@sympolys.gcd_list([f, g, h]).to_string())
    .trim()
    .to_owned()
  let oracle = gcd_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: lcm_list parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(2)) - int(1))
  let g = b.from_expr((x ^ int(2)) - x)
  let h = b.from_expr((x ^ int(2)) - int(4))
  let ours = sympy_normalize(@sympolys.lcm_list([f, g, h]).to_string())
    .trim()
    .to_owned()
  let oracle = lcm_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: terms_gcd parity over ZZ" {
  let b = PolyBuilder::new(["x", "y"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let f = b.from_expr(
    int(2) * (x ^ int(2)) * (y ^ int(3)) + int(4) * x * (y ^ int(2)),
  )
  let ours = sympy_normalize(@sympolys.terms_gcd(f).to_string())
    .trim()
    .to_owned()
  let oracle = terms_gcd(f.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: sqf_list parity over GF(5)" {
  let b = PolyBuilder::new(["x"], Domain::GF(5))
  let x = Expr::Symbol("x")
  let poly = b.from_expr(((x + int(1)) ^ int(2)) * (x + int(2)))
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(sqf_list(poly.to_expr(), modulus=5))
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: sqf_list parity over GF(7)" {
  let b = PolyBuilder::new(["x"], Domain::GF(7))
  let x = Expr::Symbol("x")
  let poly = b.from_expr(((x + int(1)) ^ int(2)) * (x + int(2)))
  let (content, parts) = poly.sqf_list()
  let ours_raw = factor_list_to_string(content.to_string(), parts)
  let ours = sort_factor_repr(ours_raw).trim().to_owned()
  let oracle = sort_factor_repr(sqf_list(poly.to_expr(), modulus=7))
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: cancel parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let num = b.from_expr((x ^ int(2)) - int(1))
  let den = b.from_expr(x - int(1))
  let (n2, d2) = @sympolys.cancel(num, den)
  let ours = div_pair_to_string(n2, d2).trim().to_owned()
  let oracle = cancel(num.to_expr(), den.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: cancel parity multivariate (no common factor)" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let num = b.from_expr(x * y + x + int(1))
  let den = b.from_expr(x + y + int(1))
  let (n2, d2) = @sympolys.cancel(num, den)
  let ours = div_pair_to_string(n2, d2).trim().to_owned()
  let oracle = cancel(num.to_expr(), den.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: cancel parity multivariate with common x+y factor" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let num = b.from_expr((x + y) * (x + int(1)))
  let den = b.from_expr(x + y)
  let (n2, d2) = @sympolys.cancel(num, den)
  let ours = div_pair_to_string(n2, d2).trim().to_owned()
  let oracle = cancel(num.to_expr(), den.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: reduced parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(2)) + int(1))
  let g = b.from_expr(x - int(1))
  let (qs, r) = @sympolys.reduced(f, [g])
  let ours = reduced_pair_to_string(qs, r).trim().to_owned()
  let oracle = reduced(f.to_expr(), [g.to_expr()]).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: reduced parity multivariate over ZZ" {
  let b = PolyBuilder::new(["x", "y"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let f = b.from_expr((x ^ int(2)) * y + x * y + y)
  let g1 = b.from_expr(x * y - int(1))
  let g2 = b.from_expr(y - int(1))
  let (qs, r) = @sympolys.reduced(f, [g1, g2])
  let ours = reduced_pair_to_string(qs, r).trim().to_owned()
  let oracle = reduced(f.to_expr(), [g1.to_expr(), g2.to_expr()])
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: reduced parity multivariate over QQ" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let f = b.from_expr((x ^ int(2)) * y + x * y + y)
  let g1 = b.from_expr(x * y - int(1))
  let g2 = b.from_expr(y - int(1))
  let (qs, r) = @sympolys.reduced(f, [g1, g2])
  let ours = reduced_pair_to_string(qs, r).trim().to_owned()
  let oracle = reduced(f.to_expr(), [g1.to_expr(), g2.to_expr()])
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: compose parity multivariate should error" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let f = b.from_expr(x * y + int(1))
  let g = b.from_expr(x + y)
  let _ = expect_poly_error(fn() raise PolyError { @sympolys.compose(f, g) })
}

///|
test "polytools: decompose parity for cubic" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(6)) - int(1))
  let parts = @sympolys.decompose(f)
  let ours = parts.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = decompose(f.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: reduced parity with two divisors" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(3)) - int(1))
  let g1 = b.from_expr(x - int(1))
  let g2 = b.from_expr(x + int(1))
  let (qs, r) = @sympolys.reduced(f, [g1, g2])
  let ours = reduced_pair_to_string(qs, r).trim().to_owned()
  let oracle = reduced(f.to_expr(), [g1.to_expr(), g2.to_expr()])
    .trim()
    .to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: compose parity over QQ" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(2)) + int(1))
  let g = b.from_expr(x + int(1))
  let h = @sympolys.compose(f, g)
  let ours = sympy_normalize(h.to_string()).trim().to_owned()
  let oracle = compose(f.to_expr(), g.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: compose parity higher degree" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(4)) + x)
  let g = b.from_expr((x ^ int(2)) + x)
  let h = @sympolys.compose(f, g)
  let ours = sympy_normalize(h.to_string()).trim().to_owned()
  let oracle = compose(f.to_expr(), g.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: decompose parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(8)) + int(1))
  let parts = @sympolys.decompose(f)
  let ours = parts.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = decompose(f.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: decompose parity for nondecomposable" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(2)) + int(1))
  let parts = @sympolys.decompose(f)
  let ours = parts.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = decompose(f.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: sturm sequence parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(3)) - int(1))
  let seq = @sympolys.sturm_sequence(f)
  let ours = seq.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = sturm(f.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: discriminant parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(2)) - int(1))
  let disc = @sympolys.discriminant(f)
  let ours = disc.to_string().trim().to_owned()
  let oracle = discriminant(f.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: subresultants parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr((x ^ int(2)) - int(1))
  let g = b.from_expr(x - int(1))
  let seq = @sympolys.subresultants(f, g)
  let ours = seq.map(p => sympy_normalize(p.to_string())).join(" | ")
  let oracle = subresultants(f.to_expr(), g.to_expr()).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "polytools: monomial and special polynomial frontdoor parity with SymPy" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let total = @sympolys.itermonomials([x, y], 2).map(item => {
    @symprint.pretty_string(item)
  })
  total.sort()
  assert_eq(total.join(" | "), itermonomials_total(["x", "y"], 2))
  let bounded = @sympolys.itermonomials_bounded([x, y], [2, 3], min_degrees=[
    1, 2,
  ]).map(item => @symprint.pretty_string(item))
  bounded.sort()
  assert_eq(
    bounded.join(" | "),
    itermonomials_bounded(["x", "y"], [2, 3], [1, 2]),
  )
  assert_eq(
    remove_spaces(
      sympy_normalize(@symprint.pretty_string(@sympolys.cyclotomic_poly(5))),
    ),
    remove_spaces(cyclotomic_poly(5)),
  )
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.swinnerton_dyer_poly(2)),
      ),
    ),
    remove_spaces(swinnerton_dyer_poly(2)),
  )
  assert_eq(
    remove_spaces(
      sympy_normalize(
        @symprint.pretty_string(@sympolys.symmetric_poly(2, [x, y, z])),
      ),
    ),
    remove_spaces(symmetric_poly(2, ["x", "y", "z"])),
  )
  let interp = @sympolys.interpolating_poly(2, x, xs=[int(0), int(1)], ys=[
    int(1),
    int(3),
  ])
  assert_eq(
    remove_spaces(sympy_normalize(@symprint.pretty_string(interp))),
    remove_spaces(interpolating_poly_values(2, "x", [0, 1], [1, 3])),
  )
}

///|
test "polytools: orthogonal and appell polynomial frontdoor parity with SymPy" {
  let cmp = fn(ours : Expr, oracle : String) raise {
    assert_eq(
      remove_spaces(sympy_normalize(@symprint.pretty_string(ours))),
      remove_spaces(oracle),
    )
  }
  cmp(@sympolys.chebyshevt_poly(4), chebyshevt_poly(4))
  cmp(@sympolys.chebyshevu_poly(4), chebyshevu_poly(4))
  cmp(@sympolys.hermite_poly(4), hermite_poly(4))
  cmp(@sympolys.hermite_prob_poly(4), hermite_prob_poly(4))
  cmp(@sympolys.legendre_poly(4), legendre_poly(4))
  cmp(@sympolys.laguerre_poly(3), laguerre_poly(3))
  cmp(@sympolys.jacobi_poly(3, int(1), int(2)), jacobi_poly(3, 1, 2))
  cmp(@sympolys.bernoulli_poly(5), bernoulli_poly(5))
  cmp(@sympolys.bernoulli_c_poly(4), bernoulli_c_poly(4))
  cmp(@sympolys.genocchi_poly(4), genocchi_poly(4))
  cmp(@sympolys.euler_poly(4), euler_poly(4))
  cmp(@sympolys.andre_poly(5), andre_poly(5))
}

///|
test "polytools: construct domain frontdoor parity with SymPy" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let ints = @sympolys.construct_domain([int(2), int(3), int(4)])
  assert_eq(
    @sympolys.domain_to_sympy_string(ints.domain),
    construct_domain_domain([int(2), int(3), int(4)]),
  )
  let poly_exprs = [int(2) * x + int(1), @symcore.rational_from_ints(3, 4)]
  let poly = @sympolys.construct_domain(poly_exprs)
  assert_eq(
    @sympolys.domain_to_sympy_string(poly.domain),
    construct_domain_domain(poly_exprs),
  )
  let frac_exprs = [y * (x ^ int(-1)), x * ((int(1) - y) ^ int(-1))]
  let frac = @sympolys.construct_domain(frac_exprs)
  assert_eq(
    @sympolys.domain_to_sympy_string(frac.domain),
    construct_domain_domain(frac_exprs),
  )
}
