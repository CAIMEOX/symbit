///|
test "symseries series smoke" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.add([x, @symcore.int(1)])
  let out = series(expr, x~, n=6)
  assert_eq(Repr(out).to_string(), Repr(expr).to_string())
}
