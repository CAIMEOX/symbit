///|
fn groebner_wb_builder() -> PolyBuilder {
  PolyBuilder::new(["x", "y"], QQ)
}

///|
fn groebner_wb_sorted(polys : Array[Poly]) -> String {
  let parts = polys.map(p => p.to_string())
  parts.sort()
  parts.join(" | ")
}

///|
test "groebner wb: spoly monic path" {
  let b = groebner_wb_builder()
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = b.from_expr(x * y - @symcore.int(1))
  let g = b.from_expr(x - @symcore.int(1))
  inspect(spoly(f, g).to_string(), content="y - 1")
}

///|
test "groebner wb: gcd and lcm frontdoors" {
  let b = PolyBuilder::new(["x"], QQ)
  let x = @symcore.Expr::Symbol("x")
  let f = b.from_expr((x - @symcore.int(1)) * (x + @symcore.int(2)))
  let g = b.from_expr((x - @symcore.int(1)) * (x + @symcore.int(3)))
  inspect(groebner_gcd(f, g).to_string(), content="x - 1")
  inspect(groebner_lcm(f, g).to_string(), content="x**3 + 4*x**2 + x - 6")
}

///|
test "groebner wb: f5 signature helpers" {
  let s = sig(monomial_from_array([1, 0]), 3)
  debug_inspect(s.0.to_array(), content="[1, 0]")
  inspect(s.1, content="3")
  debug_inspect(
    sig_mult(s, monomial_from_array([0, 2])).0.to_array(),
    content="[1, 2]",
  )
  inspect(sig_cmp(sig(monomial_from_array([1, 0]), 2), s, Lex), content="1")
  inspect(sig_cmp(s, sig(monomial_from_array([0, 3]), 3), Lex), content="1")
  inspect(sig_cmp(sig(monomial_from_array([0, 3]), 3), s, Lex), content="-1")
}

///|
test "groebner wb: f5 labeled polynomial helpers" {
  let b = groebner_wb_builder()
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = lbp(sig(monomial_from_array([1, 0]), 2), b.from_expr(x + y), 3)
  let g = lbp(sig(monomial_from_array([0, 2]), 3), b.from_expr(y), 4)
  let sub = lbp_sub(f, g)
  debug_inspect(sub.0.0.to_array(), content="[1, 0]")
  inspect(sub.2, content="3")
  inspect(sub.1.to_string(), content="x")
  let mul = lbp_mul_term(f, (monomial_from_array([0, 1]), fe_from_int(2, QQ)))
  debug_inspect(mul.0.0.to_array(), content="[1, 1]")
  inspect(mul.2, content="3")
  inspect(mul.1.to_string(), content="2*x*y + 2*y**2")
  inspect(lbp_cmp(f, g), content="1")
  inspect(lbp_cmp(g, f), content="-1")
  inspect(lbp_key(f).1, content="-3")
}

///|
test "groebner wb: f5 critical pair and s polynomial" {
  let b = groebner_wb_builder()
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = lbp(
    sig(monomial_from_array([0, 0]), 1),
    b.from_expr(x * y - @symcore.int(1)),
    1,
  )
  let g = lbp(
    sig(monomial_from_array([0, 0]), 2),
    b.from_expr(x - @symcore.int(1)),
    2,
  )
  let cp = critical_pair(f, g)
  debug_inspect(cp.1.0.to_array(), content="[0, 0]")
  debug_inspect(cp.4.0.to_array(), content="[0, 1]")
  let s = s_poly(cp)
  inspect(s.1.to_string(), content="y - 1")
  inspect(cp_cmp(cp, cp), content="1")
  inspect(cp_key(cp).0.1, content="-1")
}

///|
test "groebner wb: f5 rewritable comparable and reduce" {
  let b = groebner_wb_builder()
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let comparable = lbp(sig(monomial_from_array([0, 0]), 2), b.from_expr(x), 2)
  inspect(
    is_rewritable_or_comparable(sig(monomial_from_array([1, 0]), 1), 1, [
      comparable,
    ]),
    content="true",
  )
  let rewritable = lbp(sig(monomial_from_array([1, 0]), 2), b.from_expr(y), 3)
  inspect(
    is_rewritable_or_comparable(sig(monomial_from_array([1, 0]), 2), 1, [
      rewritable,
    ]),
    content="true",
  )
  let f = lbp(sig(monomial_from_array([0, 0]), 2), b.from_expr(x + y), 3)
  let g = lbp(sig(monomial_from_array([0, 0]), 3), b.from_expr(x), 1)
  let reduced = f5_reduce(f, [g])
  debug_inspect(reduced.0.0.to_array(), content="[0, 0]")
  inspect(reduced.2, content="3")
  inspect(reduced.1.to_string(), content="y")
}

///|
test "groebner wb: f5 reduction preserves non admissible reductions" {
  let b = PolyBuilder::new(["x", "y", "z"], QQ)
  let x = @symcore.Expr::Symbol("x")
  let f = lbp(sig(monomial_from_array([1, 1, 1]), 4), b.from_expr(x), 3)
  let g = lbp(sig(monomial_from_array([0, 0, 0]), 2), b.from_expr(x), 2)
  let reduced = f5_reduce(f, [g])
  debug_inspect(reduced.0.0.to_array(), content="[1, 1, 1]")
  inspect(reduced.2, content="3")
  inspect(reduced.1.to_string(), content="x")
}

///|
test "groebner wb: basis predicates and reduction" {
  let b = groebner_wb_builder()
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = b.from_expr(x * y - @symcore.int(1))
  let g = b.from_expr(x - @symcore.int(1))
  let basis = Poly::groebner([f, g], order=Lex)
  inspect(groebner_wb_sorted(basis), content="x - 1 | y - 1")
  inspect(is_groebner(basis), content="true")
  inspect(is_minimal(basis), content="true")
  inspect(is_reduced(basis), content="true")
  inspect(is_groebner([f, g]), content="false")
  inspect(groebner_wb_sorted(red_groebner(basis)), content="x - 1 | y - 1")
}

///|
test "groebner wb: matrix_fglm converts through target order" {
  let b = groebner_wb_builder()
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = b.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x * (y ^ @symcore.int(2)),
  )
  let g = b.from_expr(
    x * y + @symcore.int(2) * (y ^ @symcore.int(3)) - @symcore.int(1),
  )
  let source = Poly::groebner([f, g], order=Grlex)
  let converted = matrix_fglm(source, order=Lex)
  let target = Poly::groebner([f, g], order=Lex)
  inspect(groebner_wb_sorted(converted), content=groebner_wb_sorted(target))
}
