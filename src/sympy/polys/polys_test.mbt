///|
test "sympy polys oracle: gcd/resultant/div" {
  let x = @symcore.symbol("x")
  let p = (x ^ @symcore.int(2)) - @symcore.int(1)
  let q = x - @symcore.int(1)
  let g = gcd(p, q)
  inspect(g, content="x - 1")
  let r = resultant(p, q, x="x")
  inspect(r, content="0")
  let div = div(p, q)
  inspect(div, content="x + 1||0")
}

///|
test "sympy polys oracle: groebner/factor/sqf" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let f1 = x * y - @symcore.int(1)
  let f2 = x - @symcore.int(1) * y
  let basis = groebner([f1, f2], order="lex")
  guard basis.contains("x") else { fail("expected groebner basis") }
  let fact = factor_list((x ^ @symcore.int(2)) - @symcore.int(1))
  guard fact.contains("x - 1") else { fail("expected factor_list str") }
  let sqf = sqf_list((x ^ @symcore.int(2)) * (x + @symcore.int(1)))
  guard sqf.contains("x + 1") else { fail("expected sqf_list str") }
}
