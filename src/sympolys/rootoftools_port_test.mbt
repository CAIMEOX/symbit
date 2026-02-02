///|
test "rootoftools: rootof parity (degree 5)" {
  let x = @symcore.symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr((x ^ @symcore.int(5)) - x + @symcore.int(1))
  let ours = rootof(poly, 0).to_string()
  let oracle = @sympy_polys.rootof(poly.to_expr(), 0)
  let ours_norm = sympy_normalize(ours)
  let oracle_norm = sympy_normalize(oracle)
  guard ours_norm == oracle_norm else {
    fail("rootof mismatch: ours=\{ours_norm}, oracle=\{oracle_norm}")
  }
}
