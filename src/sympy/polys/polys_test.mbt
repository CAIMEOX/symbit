///|
test "sympy polys oracle: gcd/resultant/div" {
  let g = gcd("x**2 - 1", "x - 1")
  inspect(g, content="x - 1")
  let r = resultant("x**2 - 1", "x - 1", x="x")
  inspect(r, content="0")
  let div = div("x**2 - 1", "x - 1")
  inspect(div, content="x + 1||0")
}

///|
test "sympy polys oracle: groebner/factor/sqf" {
  let basis = groebner(["x*y - 1", "x - y"], order="lex")
  guard basis.contains("x") else { fail("expected groebner basis") }
  let fact = factor_list("x**2 - 1")
  guard fact.contains("x - 1") else { fail("expected factor_list str") }
  let sqf = sqf_list("x**2*(x + 1)")
  guard sqf.contains("x + 1") else { fail("expected sqf_list str") }
}
