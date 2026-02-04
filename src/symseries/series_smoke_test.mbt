///|
test "symseries series smoke" {
  let x = @symcore.symbol("x")
  let expr = @symcore.add([x, @symcore.int(1)])
  let out = try! series(expr, x~, n=6)
  assert_eq(@symprint.debug_repr(out), @symprint.debug_repr(expr))
}
