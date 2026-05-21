///|
fn groebner_wb_builder() -> PolyBuilder {
  PolyBuilder::new(["x", "y"], Domain::QQ)
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
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = @symcore.Expr::Symbol("x")
  let f = b.from_expr((x - @symcore.int(1)) * (x + @symcore.int(2)))
  let g = b.from_expr((x - @symcore.int(1)) * (x + @symcore.int(3)))
  inspect(groebner_gcd(f, g).to_string(), content="x - 1")
  inspect(groebner_lcm(f, g).to_string(), content="x**3 + 4*x**2 + x - 6")
}

///|
test "groebner wb: f5 signature helpers" {
  let s = sig(monomial_from_array([1, 0]), 3)
  inspect(s.0.to_array().to_string(), content="[1, 0]")
  inspect(s.1, content="3")
  inspect(
    sig_mult(s, monomial_from_array([0, 2])).0.to_array().to_string(),
    content="[1, 2]",
  )
  inspect(
    sig_cmp(sig(monomial_from_array([1, 0]), 2), s, TermOrder::Lex),
    content="1",
  )
  inspect(
    sig_cmp(s, sig(monomial_from_array([0, 3]), 3), TermOrder::Lex),
    content="1",
  )
  inspect(
    sig_cmp(sig(monomial_from_array([0, 3]), 3), s, TermOrder::Lex),
    content="-1",
  )
}

///|
test "groebner wb: f5 labeled polynomial helpers" {
  let b = groebner_wb_builder()
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = lbp(sig(monomial_from_array([1, 0]), 2), b.from_expr(x + y), 3)
  let g = lbp(sig(monomial_from_array([0, 2]), 3), b.from_expr(y), 4)
  let sub = lbp_sub(f, g)
  inspect(sub.0.0.to_array().to_string(), content="[1, 0]")
  inspect(sub.2, content="3")
  inspect(sub.1.to_string(), content="x")
  let mul = lbp_mul_term(
    f,
    (monomial_from_array([0, 1]), fe_from_int(2, Domain::QQ)),
  )
  inspect(mul.0.0.to_array().to_string(), content="[1, 1]")
  inspect(mul.2, content="3")
  inspect(mul.1.to_string(), content="2*x*y + 2*y**2")
  inspect(lbp_cmp(f, g), content="1")
  inspect(lbp_cmp(g, f), content="-1")
  inspect(lbp_key(f).1, content="-3")
}

///|
test "groebner wb: basis predicates and reduction" {
  let b = groebner_wb_builder()
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f = b.from_expr(x * y - @symcore.int(1))
  let g = b.from_expr(x - @symcore.int(1))
  let basis = Poly::groebner([f, g], order=TermOrder::Lex)
  inspect(groebner_wb_sorted(basis), content="x - 1 | y - 1")
  inspect(is_groebner(basis), content="true")
  inspect(is_minimal(basis), content="true")
  inspect(is_reduced(basis), content="true")
  inspect(is_groebner([f, g]), content="false")
  inspect(groebner_wb_sorted(red_groebner(basis)), content="x - 1 | y - 1")
}
