///|
test "diff tan and gamma" {
  let x = @symcore.symbol("x")
  let tanx = @symcore.function("tan", [x])
  let gammax = @symcore.function("gamma", [x])
  let dt = diff(tanx, x)
  let dg = diff(gammax, x)
  assert_eq(@symprint.to_string(dt), "sec(x)**2")
  assert_eq(@symprint.to_string(dg), "gamma(x)*digamma(x)")
}
