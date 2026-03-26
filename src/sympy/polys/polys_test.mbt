///|
test "sympy polys oracle: gcd/resultant/div" {
  let x = @symcore.Expr::Symbol("x")
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
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f1 = x * y - @symcore.int(1)
  let f2 = x - @symcore.int(1) * y
  let basis = groebner([f1, f2], order="lex")
  assert_true(basis.contains("x"))
  let fact = factor_list((x ^ @symcore.int(2)) - @symcore.int(1))
  assert_true(fact.contains("x - 1"))
  let sqf = sqf_list((x ^ @symcore.int(2)) * (x + @symcore.int(1)))
  assert_true(sqf.contains("x + 1"))
}
