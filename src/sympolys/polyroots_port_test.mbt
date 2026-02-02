///|
fn roots_repr(roots : Array[FieldElem]) -> String {
  let parts = roots.map(r => r.to_string()).join(",")
  "[\{parts}]"
}

///|
test "polyroots: linear/quadratic parity" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let f = b.from_expr(@symcore.int(2) * x + @symcore.int(1))
  let ours_lin = roots_repr(roots_linear(f))
  let oracle_lin = @sympy_polys.roots_linear(f.to_expr())
  guard ours_lin == oracle_lin else { fail("roots_linear mismatch") }

  let g = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(3) * x + @symcore.int(2))
  let ours_quad = roots_repr(roots_quadratic(g))
  let oracle_quad = @sympy_polys.roots_quadratic(g.to_expr())
  guard ours_quad == oracle_quad else { fail("roots_quadratic mismatch") }
}
