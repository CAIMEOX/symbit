///|
test "sympy polys oracle: gcd/resultant/div" {
  let g = gcd("x**2 - 1", "x - 1")
  inspect(g, content="x - 1")
  let r = resultant("x**2 - 1", "x - 1", var_name="x")
  inspect(r, content="0")
  let div = div_pair_str("x**2 - 1", "x - 1")
  inspect(div, content="x + 1||0")
}

///|
test "sympy polys oracle: groebner/factor/sqf" {
  let basis = groebner_list(["x*y - 1", "x - y"], order="lex")
  guard basis.length() >= 1 else { fail("expected groebner basis") }
  let fact = factor_list_json("x**2 - 1")
  match fact {
    Array(items) => {
      guard items.length() == 2 else { fail("expected factor_list array") }
    }
    _ => fail("expected factor_list array")
  }
  let sqf = sqf_list_json("x**2*(x + 1)")
  match sqf {
    Array(items) => {
      guard items.length() == 2 else { fail("expected sqf_list array") }
    }
    _ => fail("expected sqf_list array")
  }
}
