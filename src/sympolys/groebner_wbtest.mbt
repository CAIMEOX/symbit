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
