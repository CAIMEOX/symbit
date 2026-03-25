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

///|
test "basic helpers expose structured heads" {
  let rel = le(symbol("x"), int(2))
  let tup = tuple_expr([symbol("x"), int(2)])
  let deriv = derivative(
    function("f", [symbol("x")]),
    symbol("x"),
    order=int(2),
  )
  inspect(@symprint.debug_repr(rel), content="(call Le sym:x 2)")
  inspect(@symprint.debug_repr(tup), content="(call Tuple sym:x 2)")
  inspect(
    @symprint.debug_repr(deriv),
    content="(call Derivative (call f sym:x) sym:x 2)",
  )
  inspect(is_true(bool_expr(true)), content="true")
  inspect(is_false(bool_expr(false)), content="true")
}

///|
test "free_symbols respects bound variables" {
  let x = symbol("x")
  let y = symbol("y")
  let z = symbol("z")
  let lam = lambda_expr(tuple_expr([x, y]), add([x, z]))
  let deriv = derivative(function("f", [x, y]), x, order=y)
  json_inspect(free_symbols(lam).map(@symprint.to_string), content=["z"])
  json_inspect(free_symbols(deriv).map(@symprint.to_string), content=["y"])
  inspect(has(lam, z), content="true")
  inspect(has(lam, y), content="true")
}

///|
test "number symbols are structured constants" {
  let pi_expr = symbol("pi")
  let imag = symbol("I")
  let inf = symbol("oo")
  match expr_form(pi_expr) {
    ExprForm::NumberSymbol(NumberSymbolKind::Pi) => ()
    _ => fail("expected pi number symbol")
  }
  match expr_form(imag) {
    ExprForm::NumberSymbol(NumberSymbolKind::ImaginaryUnit) => ()
    _ => fail("expected I number symbol")
  }
  match expr_form(inf) {
    ExprForm::NumberSymbol(NumberSymbolKind::Infinity) => ()
    _ => fail("expected oo number symbol")
  }
  json_inspect(
    free_symbols(add([pi_expr, imag, symbol("x")])).map(@symprint.to_string),
    content=["x"],
  )
  inspect(@symprint.to_string(mul([int(-1), inf])), content="-oo")
}

///|
test "dummy and wild are distinct structured symbols" {
  let d1 = dummy(name="x")
  let d2 = dummy(name="x")
  let w = wild("x")
  assert_false(d1 == d2)
  inspect(@symprint.to_string(d1), content="_x")
  inspect(@symprint.to_string(w), content="x_")
  match dummy_parts(d1) {
    Some((name, _)) => inspect(name, content="x")
    None => fail("expected dummy parts")
  }
  match wild_name(w) {
    Some(name) => inspect(name, content="x")
    None => fail("expected wild name")
  }
}

///|
test "free_symbols tracks dummy identity and bound dummy removal" {
  let d1 = dummy(name="x")
  let d2 = dummy(name="x")
  let expr = add([d1, d2])
  inspect(free_symbols(expr).length(), content="2")
  let lam = lambda_expr(tuple_expr([d1]), add([d1, d2, symbol("y")]))
  let free = free_symbols(lam)
  inspect(free.length(), content="2")
  assert_true(free.contains(symbol("y")))
  assert_true(free.contains(d2))
  assert_false(free.contains(d1))
}

///|
test "derivative free symbols remove dummy variables but keep order symbols" {
  let d = dummy(name="x")
  let order = symbol("n")
  let expr = derivative(function("f", [d, order]), d, order~)
  let free = free_symbols(expr)
  inspect(free.length(), content="1")
  assert_true(free.contains(order))
  assert_false(free.contains(d))
}
