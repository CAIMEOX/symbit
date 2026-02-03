///|
test "add flattens and folds constants" {
  let expr = add([int(1), symbol("x"), add([int(2), symbol("y")])])
  inspect(@symprint.debug_repr(expr), content="(+ sym:x sym:y 3)")
}

///|
test "mul flattens and handles identities" {
  let expr = mul([symbol("x"), int(1), mul([symbol("y"), int(2)])])
  inspect(@symprint.debug_repr(expr), content="(* 2 sym:x sym:y)")
  let zeroed = mul([symbol("x"), int(0), symbol("y")])
  inspect(@symprint.debug_repr(zeroed), content="0")
}

///|
test "pow normalizes trivial exponents" {
  inspect(@symprint.debug_repr(pow(symbol("x"), int(1))), content="sym:x")
  inspect(@symprint.debug_repr(pow(symbol("x"), int(0))), content="1")
  inspect(@symprint.debug_repr(pow(int(0), int(0))), content="1")
}

///|
test "subst replaces symbols" {
  let env : Map[String, Expr] = { "x": int(2) }
  let expr = add([symbol("x"), symbol("y")])
  let replaced = subst(expr, env)
  inspect(@symprint.debug_repr(replaced), content="(+ sym:y 2)")
}
