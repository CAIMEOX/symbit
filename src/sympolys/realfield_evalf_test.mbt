///|
test "RR evalf_expr returns Expr::Float with requested precision" {
  let rr = Domain::RR
  let half = @symcore.rational_from_ints(1, 2)
  let evaled = rr.evalf_expr(half, prec=Some(90))
  match evaled {
    @symcore.Expr::Float(f) => {
      assert_true(f.precision() == 90)
      assert_true(f.to_rational() == (1N, 2N))
    }
    _ => fail("expected float")
  }
}

///|
test "Poly::from_expr_defaults infers RR from float coefficients" {
  let half = @symcore.Float::from_str("0.5", prec=100)
  let expr = @symcore.add([
    @symcore.Expr::Symbol("x"),
    @symcore.Expr::Float(half),
  ])
  let poly = Poly::from_expr_defaults(expr)
  match poly.domain {
    Domain::RR => ()
    _ => fail("expected RR domain")
  }
  inspect(@symprint.pretty_string(poly.to_expr()), content="x + 1/2")
}
