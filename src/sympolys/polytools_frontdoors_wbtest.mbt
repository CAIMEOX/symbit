///|
test "polytools frontdoors: degree and leading term helpers" {
  let b = PolyBuilder::new(["x", "y"], QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let p = b.from_expr(
    int(4) * (x ^ int(2)) + int(2) * x * (y ^ int(2)) + x * y + int(3) * y,
  )
  inspect(degree(p, gen_index=0), content="2")
  inspect(degree(p, gen_index=1), content="2")
  debug_inspect(degree_list(p), content="[2, 2]")
  inspect(total_degree(p), content="3")
  inspect(lc(p), content="4")
  inspect(@symprint.pretty_string(lm(p)), content="x**2")
  inspect(@symprint.pretty_string(lt(p)), content="4*x**2")
}

///|
test "polytools frontdoors: zero leading conventions" {
  let z = Poly::zero(["x"], ZZ)
  inspect(degree(z), content="-1")
  debug_inspect(degree_list(z), content="[-1]")
  inspect(total_degree(z), content="0")
  inspect(lc(z), content="0")
  inspect(@symprint.pretty_string(lm(z)), content="1")
  inspect(@symprint.pretty_string(lt(z)), content="0")
}

///|
test "polytools frontdoors: expression constructors and order helpers" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let p = poly_from_expr(x * y + @symcore.rational_from_ints(1, 2))
  debug_inspect(p.gens, content="[\"x\", \"y\"]")
  match p.domain {
    QQ => ()
    _ => fail("expected QQ domain")
  }
  inspect(p, content="x*y + 1/2")
  let ps = parallel_poly_from_expr([
    x + @symcore.rational_from_ints(1, 3),
    y + int(2),
  ])
  inspect(ps.length(), content="2")
  inspect(ps[0], content="x + 1/3")
  inspect(ps[1], content="y + 2")
  inspect(
    poly((x + int(1)) ^ int(2), gens=["x"]),
    content=(
      #|x**2 + 2*x + 1
    ),
  )
  inspect(lex() == Lex, content="true")
  inspect(grlex() == Grlex, content="true")
  inspect(grevlex() == Grevlex, content="true")
  inspect(monomial_key() == Lex, content="true")
  inspect(monomial_key(order="igrevlex") == Igrevlex, content="true")
  sympolys_assert_error(
    fn() raise PolyError { monomial_key(order="bad") },
    "BadGenerator",
  )
}

///|
test "polytools frontdoors: division and pseudo division" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = Expr::Symbol("x")
  let p = b.from_expr((x ^ int(2)) + int(1))
  let d = b.from_expr(x + int(1))
  let (q, r) = div(p, d)
  inspect(
    q,
    content=(
      #|x - 1
    ),
  )
  inspect(r, content="2")
  inspect(
    quo(p, d),
    content=(
      #|x - 1
    ),
  )
  inspect(rem(p, d), content="2")
  sympolys_assert_error(
    fn() raise PolyError { exquo(p, d) },
    "ExactQuotientFailed",
  )
  let exact = b.from_expr((x ^ int(2)) - int(1))
  inspect(
    exquo(exact, d),
    content=(
      #|x - 1
    ),
  )
  let pd = b.from_expr(int(2) * x - int(4))
  let (pq, pr) = pdiv(p, pd)
  inspect(pq, content="2*x + 4")
  inspect(pr, content="20")
  inspect(pquo(p, pd), content="2*x + 4")
  inspect(prem(p, pd), content="20")
}

///|
test "polytools frontdoors: gcd lcm cofactors and normalization" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = Expr::Symbol("x")
  let p = b.from_expr((x ^ int(2)) - int(1))
  let q = b.from_expr((x ^ int(2)) - x)
  inspect(
    gcd(p, q),
    content=(
      #|x - 1
    ),
  )
  inspect(
    lcm(p, q),
    content=(
      #|x**3 - x
    ),
  )
  let (h, cff, cfg) = cofactors(p, q)
  inspect(
    h,
    content=(
      #|x - 1
    ),
  )
  inspect(cff, content="x + 1")
  inspect(cfg, content="x")
  let (hh, hcff, hcfg) = heugcd(p, q)
  inspect(hh, content="x - 1")
  inspect(hcff, content="x + 1")
  inspect(hcfg, content="x")
  let scaled = b.from_expr(int(6) * (x ^ int(2)) + int(9) * x)
  let (cont, prim) = primitive(scaled)
  inspect(cont, content="3")
  inspect(prim, content="2*x**2 + 3*x")
  inspect(content(scaled), content="3")
  inspect(
    monic(scaled),
    content=(
      #|x**2 + 3*x/2
    ),
  )
}

///|
test "polytools frontdoors: factor squarefree sturm groebner resultant" {
  let bu = PolyBuilder::new(["x"], ZZ)
  let x = Expr::Symbol("x")
  let p = bu.from_expr((x ^ int(4)) - int(1))
  let factors = factor(p).map(pair => "(\{pair.0}, \{pair.1})")
  factors.sort()
  inspect(
    factors.join(" | "),
    content=(
      #|(x + 1, 1) | (x - 1, 1) | (x**2 + 1, 1)
    ),
  )
  let (fl_cont, fl_factors) = factor_list(p)
  inspect(fl_cont, content="1")
  let fl_reprs = fl_factors.map(pair => "(\{pair.0}, \{pair.1})")
  fl_reprs.sort()
  inspect(
    fl_reprs.join(" | "),
    content=(
      #|(x + 1, 1) | (x - 1, 1) | (x**2 + 1, 1)
    ),
  )
  let repeated = bu.from_expr(((x - int(1)) ^ int(2)) * (x + int(2)))
  inspect(
    sqf_part(repeated),
    content=(
      #|x**2 + x - 2
    ),
  )
  inspect(sqf_list(repeated).1.length(), content="2")
  inspect(
    sqf(repeated),
    content=(
      #|x**3 - 3*x + 2
    ),
  )
  let chain = sturm(bu.from_expr((x ^ int(3)) - x))
  inspect(
    chain.map(poly => poly.to_string()).join(" | "),
    content=(
      #|x**3 - x | 3*x**2 - 1 | 2*x/3 | 1
    ),
  )
  let bm = PolyBuilder::new(["x", "y"], QQ)
  let y = Expr::Symbol("y")
  let g1 = bm.from_expr(x * y - int(1))
  let g2 = bm.from_expr(x - int(1))
  inspect(
    groebner([g1, g2]).map(poly => poly.to_string()).join(" | "),
    content=(
      #|x - 1 | y - 1
    ),
  )
  let basis_obj = groebner_basis([g1, g2], order=Lex)
  inspect(
    basis_obj.polys.map(poly => poly.to_string()).join(" | "),
    content=(
      #|x - 1 | y - 1
    ),
  )
  debug_inspect(basis_obj.gens, content="[\"x\", \"y\"]")
  inspect(domain_to_sympy_string(basis_obj.domain), content="QQ")
  inspect(basis_obj.order == Lex, content="true")
  let r = resultant(
    bu.from_expr((x ^ int(2)) + int(1)),
    bu.from_expr((x ^ int(2)) - int(1)),
  )
  inspect(r, content="4")
}

///|
test "polytools frontdoors: gff stability and powered roots" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = Expr::Symbol("x")
  let gff_input = b.from_expr(
    (x ^ int(5)) + int(2) * (x ^ int(4)) - (x ^ int(3)) - int(2) * (x ^ int(2)),
  )
  let gff_items = gff_list(gff_input).map(pair => "(\{pair.0}, \{pair.1})")
  inspect(
    gff_items.join(" | "),
    content=(
      #|(x, 1) | (x + 2, 4)
    ),
  )
  sympolys_assert_error(fn() raise PolyError { gff(gff_input) }, "BadGenerator")
  let p = b.from_expr((x ^ int(4)) - (x ^ int(2)) + int(1))
  inspect(
    nth_power_roots_poly(p, 2),
    content=(
      #|x**4 - 2*x**3 - 2*x + 3*x**2 + 1
    ),
  )
  inspect(
    nth_power_roots_poly(p, 3),
    content=(
      #|x**4 + 2*x**2 + 1
    ),
  )
}

///|
fn pt_wb_rat(num : Int, den : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(num, den) catch {
    _ => abort("polytools frontdoor test rational expects nonzero denominator")
  }
}

///|
fn pt_wb_iv_repr(
  item : ((@symnum.BigRational, @symnum.BigRational), Int),
) -> String {
  let ((a, b), mult) = item
  "((\{a}, \{b}), \{mult})"
}

///|
test "polytools frontdoors: extended euclidean family" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = Expr::Symbol("x")
  let f = b.from_expr(
    (x ^ int(4)) -
    int(2) * (x ^ int(3)) -
    int(6) * (x ^ int(2)) +
    int(12) * x +
    int(15),
  )
  let g = b.from_expr((x ^ int(3)) + (x ^ int(2)) - int(4) * x - int(4))
  let (hs, hh) = half_gcdex(f, g)
  inspect(
    hs,
    content=(
      #|3/5 - x/5
    ),
  )
  inspect(hh, content="x + 1")
  let (s, t, h) = gcdex(f, g)
  inspect(
    s,
    content=(
      #|3/5 - x/5
    ),
  )
  inspect(
    t,
    content=(
      #|-6*x/5 + x**2/5 + 2
    ),
  )
  inspect(h, content="x + 1")
  let steps = gcdex_steps(f, g)
  inspect(steps.length(), content="3")
  inspect(
    steps.map(step => "(\{step.0}; \{step.1}; \{step.2})").join(" | "),
    content=(
      #|(0; 1; x**2 + x**3 - 4*x - 4) | (1; 3 - x; x**2 + 4*x + 3) | (3 - x; x**2 - 6*x + 10; 5*x + 5)
    ),
  )
  let inv = invert(
    b.from_expr((x ^ int(2)) - int(1)),
    b.from_expr(int(2) * x - int(1)),
  )
  inspect(inv, content="-4/3")
  sympolys_assert_error(
    fn() raise PolyError {
      invert(b.from_expr((x ^ int(2)) - int(1)), b.from_expr(x - int(1)))
    },
    "ExactQuotientFailed",
  )
}

///|
test "polytools frontdoors: trunc and root fronts" {
  let b = PolyBuilder::new(["x"], ZZ)
  let x = Expr::Symbol("x")
  let p = b.from_expr(
    int(2) * (x ^ int(3)) + int(3) * (x ^ int(2)) + int(5) * x + int(7),
  )
  inspect(
    trunc(p, 3),
    content=(
      #|-x**3 - x + 1
    ),
  )

  let q = b.from_expr((x ^ int(2)) - int(3))
  inspect(
    intervals(q).map(pt_wb_iv_repr).join(" | "),
    content=(
      #|((-2, -1), 1) | ((1, 2), 1)
    ),
  )
  let refined = refine_root(
    q,
    pt_wb_rat(1, 1),
    pt_wb_rat(2, 1),
    eps=pt_wb_rat(1, 100),
  )
  inspect(
    "(\{Show::to_string(refined.0)}, \{Show::to_string(refined.1)})",
    content="(19/11, 26/15)",
  )
  inspect(
    count_roots(
      b.from_expr((x ^ int(4)) - int(4)),
      inf=pt_wb_rat(-3, 1),
      sup=pt_wb_rat(3, 1),
    ),
    content="2",
  )
  inspect(
    all_roots(b.from_expr((x ^ int(2)) - int(1)))
    .map(root => @symprint.pretty_string(root))
    .join(" | "),
    content=(
      #|-1 | 1
    ),
  )
  inspect(
    ground_roots(
      b.from_expr(
        (x ^ int(6)) -
        int(4) * (x ^ int(4)) +
        int(4) * (x ^ int(3)) -
        (x ^ int(2)),
      ),
    )
    .map(pair => "(\{@symprint.pretty_string(pair.0)}, \{pair.1})")
    .join(" | "),
    content="(0, 2) | (1, 2)",
  )
  inspect(
    real_roots(
      b.from_expr(
        int(2) * (x ^ int(3)) - int(7) * (x ^ int(2)) + int(4) * x + int(4),
      ),
    )
    .map(root => @symprint.pretty_string(root))
    .join(" | "),
    content=(
      #|-1/2 | 2 | 2
    ),
  )
  inspect(
    nroots(q)
    .map(root => @symprint.pretty_string(root))
    .join(" | ")
    .has_prefix("-1.732"),
    content="true",
  )
}

///|
test "polytools frontdoors: zero-dimensional groebner criterion" {
  let b = PolyBuilder::new(["x", "y"], QQ)
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let finite = [b.from_expr((x ^ int(2)) - int(1)), b.from_expr(y - x)]
  let curve = [b.from_expr(x * y - int(1))]
  inspect(is_zero_dimensional(finite), content="true")
  inspect(is_zero_dimensional(curve), content="false")
}

///|
fn pt_wb_expr_list_repr(items : Array[Expr]) -> String {
  let body = items.map(item => @symprint.pretty_string(item)).join(", ")
  "[\{body}]"
}

///|
test "polytools frontdoors: Hurwitz and Schur stability conditions" {
  let x = Expr::Symbol("x")
  let k = Expr::Symbol("k")
  let numeric = PolyBuilder::new(["x"], ZZ).from_expr(
    int(2) * (x ^ int(3)) + int(3) * (x ^ int(2)) + int(4) * x + int(5),
  )
  inspect(
    pt_wb_expr_list_repr(hurwitz_conditions(numeric)),
    content="[6, 2, 10]",
  )
  inspect(
    pt_wb_expr_list_repr(schur_conditions(numeric)),
    content="[-28, -112, -28]",
  )

  let symbolic = PolyBuilder::new(["x", "k"], ZZ).from_expr(
    (x ^ int(3)) + (x ^ int(2)) + int(2) * k * x + int(1) - k,
  )
  inspect(
    pt_wb_expr_list_repr(hurwitz_conditions(symbolic)),
    content=(
      #|[1, 3*k - 1, 1 - k]
    ),
  )
  inspect(
    pt_wb_expr_list_repr(schur_conditions(symbolic)),
    content=(
      #|[-15*k**2 + 20*k - 5, -8*k**2 - 8*k + 8, 3*k**2 + 8*k - 3]
    ),
  )
}
