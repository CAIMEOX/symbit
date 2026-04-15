///|
test "special gamma/erf basics" {
  let g5 = gamma(@symcore.int(5))
  let e0 = erf(@symcore.int(0))
  assert_eq(@symprint.pretty_string(g5), "24")
  assert_eq(@symprint.pretty_string(e0), "0")
  assert_oracle(try? expr_str_eq(@symprint.pretty_string(g5), "gamma(5)"))
  assert_oracle(try? expr_str_eq(@symprint.pretty_string(e0), "erf(0)"))
}

///|
test "special zeta wrapper" {
  let x = @symcore.Expr::Symbol("x")
  let z = zeta(x)
  assert_eq(@symprint.pretty_string(z), "zeta(x)")
  assert_oracle(try? expr_str_eq(@symprint.pretty_string(z), "zeta(x)"))
}
