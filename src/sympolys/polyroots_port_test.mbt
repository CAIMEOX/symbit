///|
fn roots_repr(roots : Array[@symcore.Expr]) -> String {
  let parts : Array[String] = Array::new()
  for r in roots {
    parts.push(sympy_normalize(@symprint.to_string(r)))
  }
  let joined = parts.join(",")
  sympy_normalize("[\{joined}]")
}

///|
fn normalize_root_list(raw : String) -> String {
  sympy_normalize(raw)
}

///|
fn rootof_list(expr : @symcore.Expr, deg : Int) -> String {
  let parts : Array[String] = Array::new()
  for i in 0..<deg {
    parts.push(sympy_normalize(try! @sympy_polys.rootof(expr, i, radicals=false)))
  }
  let joined = parts.join(",")
  sympy_normalize("[\{joined}]")
}

///|
test "polyroots: linear/quadratic parity" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let f = b.from_expr(@symcore.int(2) * x + @symcore.int(1))
  let ours_lin = roots_repr(roots_linear(f))
  let oracle_lin = normalize_root_list(@sympy_polys.roots_linear(f.to_expr()))
  guard ours_lin == oracle_lin else { fail("roots_linear mismatch") }

  let g = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(3) * x + @symcore.int(2))
  let ours_quad = roots_repr(roots_quadratic(g))
  let oracle_quad = normalize_root_list(@sympy_polys.roots_quadratic(g.to_expr()))
  guard ours_quad == oracle_quad else {
    fail("roots_quadratic mismatch: ours=\{ours_quad}, oracle=\{oracle_quad}")
  }
}

///|
test "polyroots: cubic/quartic parity (factorable)" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)

  let f = b.from_expr((x - @symcore.int(1)) ^ @symcore.int(3))
  let ours_cubic = roots_repr(roots_cubic(f))
  let oracle_cubic = normalize_root_list(@sympy_polys.roots_cubic(f.to_expr()))
  guard ours_cubic == oracle_cubic else {
    fail("roots_cubic mismatch: ours=\{ours_cubic}, oracle=\{oracle_cubic}")
  }

  let g = b.from_expr(x ^ @symcore.int(4))
  let ours_quartic = roots_repr(roots_quartic(g))
  let oracle_quartic = normalize_root_list(@sympy_polys.roots_quartic(g.to_expr()))
  guard ours_quartic == oracle_quartic else {
    fail("roots_quartic mismatch: ours=\{ours_quartic}, oracle=\{oracle_quartic}")
  }
}

///|
test "polyroots: cubic/quartic parity (rootof fallback)" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)

  let f = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(2))
  let ours_cubic = roots_repr(roots_cubic(f))
  let oracle_cubic = rootof_list(f.to_expr(), 3)
  guard ours_cubic == oracle_cubic else {
    fail("roots_cubic rootof mismatch: ours=\{ours_cubic}, oracle=\{oracle_cubic}")
  }

  let g = b.from_expr((x ^ @symcore.int(4)) + x + @symcore.int(1))
  let ours_quartic = roots_repr(roots_quartic(g))
  let oracle_quartic = rootof_list(g.to_expr(), 4)
  guard ours_quartic == oracle_quartic else {
    fail("roots_quartic rootof mismatch: ours=\{ours_quartic}, oracle=\{oracle_quartic}")
  }
}
