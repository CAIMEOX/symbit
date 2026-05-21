///|
fn roots_repr(roots : Array[@symcore.Expr]) -> String raise {
  let parts : Array[String] = Array::new()
  for r in roots {
    parts.push(sympy_normalize(@symprint.pretty_string(r)))
  }
  let joined = parts.join(",")
  sympy_normalize("[\{joined}]")
}

///|
fn normalize_root_list(raw : String) -> String raise {
  sympy_normalize(raw)
}

///|
fn rootof_list(expr : @symcore.Expr, deg : Int) -> String raise {
  let parts : Array[String] = Array::new()
  for i in 0..<deg {
    parts.push(sympy_normalize(rootof(expr, i, radicals=false)))
  }
  let joined = parts.join(",")
  sympy_normalize("[\{joined}]")
}

///|
fn preprocess_repr(pair : (@symcore.Expr, @sympolys.Poly)) -> String raise {
  let (coeff, poly) = pair
  let coeff_text = sympy_normalize(@symprint.pretty_string(coeff))
  let poly_text = sympy_normalize(@symprint.pretty_string(poly.to_expr()))
  "\{coeff_text}||\{poly_text}"
}

///|
test "polyroots: linear/quadratic parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let f = b.from_expr(@symcore.int(2) * x + @symcore.int(1))
  let ours_lin = roots_repr(@sympolys.roots_linear(f))
  let oracle_lin = normalize_root_list(roots_linear(f.to_expr()))
  assert_eq(ours_lin, oracle_lin)
  let g = b.from_expr(
    (x ^ @symcore.int(2)) - @symcore.int(3) * x + @symcore.int(2),
  )
  let ours_quad = roots_repr(@sympolys.roots_quadratic(g))
  let oracle_quad = normalize_root_list(roots_quadratic(g.to_expr()))
  assert_eq(ours_quad, oracle_quad)
}

///|
test "polyroots: cubic/quartic parity (factorable)" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let f = b.from_expr((x - @symcore.int(1)) ^ @symcore.int(3))
  let ours_cubic = roots_repr(@sympolys.roots_cubic(f))
  let oracle_cubic = normalize_root_list(roots_cubic(f.to_expr()))
  assert_eq(ours_cubic, oracle_cubic)
  let g = b.from_expr(x ^ @symcore.int(4))
  let ours_quartic = roots_repr(@sympolys.roots_quartic(g))
  let oracle_quartic = normalize_root_list(roots_quartic(g.to_expr()))
  assert_eq(ours_quartic, oracle_quartic)
}

///|
test "polyroots: cubic/quartic parity (rootof fallback)" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let f = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(2))
  let ours_cubic = roots_repr(@sympolys.roots_cubic(f))
  let oracle_cubic = rootof_list(f.to_expr(), 3)
  assert_eq(ours_cubic, oracle_cubic)
  let g = b.from_expr((x ^ @symcore.int(4)) + x + @symcore.int(1))
  let ours_quartic = roots_repr(@sympolys.roots_quartic(g))
  let oracle_quartic = rootof_list(g.to_expr(), 4)
  assert_eq(ours_quartic, oracle_quartic)
}

///|
test "polyroots: generic roots handles degree > 4 via CRootOf fallback" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let f = b.from_expr((x ^ @symcore.int(5)) - @symcore.int(2))
  let ours = roots_repr(@sympolys.roots(f))
  let oracle = rootof_list(f.to_expr(), 5)
  assert_eq(ours, oracle)
}

///|
test "polyroots: generic roots keeps multiplicities" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let f = b.from_expr(
    ((x - @symcore.int(1)) ^ @symcore.int(2)) *
    ((x - @symcore.int(2)) ^ @symcore.int(3)),
  )
  let ours = roots_repr(@sympolys.roots(f))
  let expected = sympy_normalize("[1,1,2,2,2]")
  assert_eq(ours, expected)
}

///|
test "polyroots: root_factors parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let f = b.from_expr((x - @symcore.int(1)) * (x + @symcore.int(2)))
  let ours = roots_repr(@sympolys.root_factors(f))
  let oracle = normalize_root_list(root_factors(f.to_expr(), gens=["x"]))
  assert_eq(ours, oracle)
  let g = b.from_expr((x - @symcore.int(1)) ^ @symcore.int(2))
  let repeated = roots_repr(@sympolys.root_factors(g))
  assert_eq(
    repeated,
    normalize_root_list(root_factors(g.to_expr(), gens=["x"])),
  )
}

///|
test "polyroots: binomial roots parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  for
    expr in [
      (x ^ @symcore.int(2)) - @symcore.int(4),
      (x ^ @symcore.int(3)) + @symcore.int(8),
      (x ^ @symcore.int(4)) + @symcore.int(16),
      @symcore.int(2) * (x ^ @symcore.int(3)) + @symcore.int(4),
      (x ^ @symcore.int(5)) - @symcore.int(32),
    ] {
    let poly = b.from_expr(expr)
    let ours = roots_repr(@sympolys.roots_binomial(poly))
    let oracle = normalize_root_list(roots_binomial(poly.to_expr(), gens=["x"]))
    assert_eq(ours, oracle)
  }
}

///|
test "polyroots: preprocess_roots parity" {
  let x = @symcore.Expr::Symbol("x")
  let zz = PolyBuilder::new(["x"], Domain::ZZ)
  let qq = PolyBuilder::new(["x"], Domain::QQ)
  let half = @symcore.rational_from_ints(1, 2)
  for
    poly in [
      zz.from_expr((x ^ @symcore.int(3)) - @symcore.int(1)),
      zz.from_expr(
        (x ^ @symcore.int(5)) + @symcore.int(512) * x + @symcore.int(1024),
      ),
      zz.from_expr(
        @symcore.int(2) * (x ^ @symcore.int(2)) +
        @symcore.int(4) * x +
        @symcore.int(2),
      ),
      qq.from_expr(half * (x ^ @symcore.int(2)) + x + half),
    ] {
    let ours = preprocess_repr(@sympolys.preprocess_roots(poly))
    let oracle = preprocess_roots(poly.to_expr(), gens=["x"])
    assert_eq(ours, oracle)
  }
}

///|
test "polyroots: cyclotomic roots parity" {
  for n in [1, 2, 3, 4, 5, 6, 8, 10, 12] {
    let phi = Poly::from_expr(@sympolys.cyclotomic_poly(n), ["x"], Domain::QQ)
    let ours = roots_repr(@sympolys.roots_cyclotomic(phi))
    let oracle = normalize_root_list(
      roots_cyclotomic(phi.to_expr(), gens=["x"]),
    )
    assert_eq(ours, oracle)
  }
}
