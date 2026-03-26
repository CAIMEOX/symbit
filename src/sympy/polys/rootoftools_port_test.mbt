///|
test "rootoftools: rootof parity (degree 5)" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = b.from_expr((x ^ @symcore.int(5)) - x + @symcore.int(1))
  let ours = @sympolys.rootof(poly, 0).to_string()
  let oracle = rootof(poly.to_expr(), 0)
  let ours_norm = sympy_normalize(ours)
  let oracle_norm = sympy_normalize(oracle)
  assert_eq(ours_norm, oracle_norm)

  // Cover `impl Show for RootOf`.
  let shown = "\{@sympolys.rootof(poly, 0)}"
  assert_true(shown.contains("CRootOf(") && shown.contains(", 0)"))
}
