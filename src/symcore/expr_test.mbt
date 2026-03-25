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
test "plain symbol names no longer coerce to core singletons" {
  inspect(@symprint.debug_repr(symbol("pi")), content="sym:pi")
  inspect(@symprint.debug_repr(symbol("True")), content="sym:True")
  match number_symbol_kind(symbol("pi")) {
    Some(_) => fail("plain symbol pi should not be a number symbol")
    None => ()
  }
  match bool_value(symbol("True")) {
    Some(_) => fail("plain symbol True should not be a boolean atom")
    None => ()
  }
}

///|
test "number symbols are structured constants" {
  let pi_expr = pi()
  let imag = imag_unit()
  let inf = oo()
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
  match expr_form(d1) {
    ExprForm::Dummy(name, _) => inspect(name, content="x")
    _ => fail("expected dummy expr form")
  }
  match expr_form(w) {
    ExprForm::Wild(name) => inspect(name, content="x")
    _ => fail("expected wild expr form")
  }
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
test "boolean and number symbol helper accessors stay structured" {
  inspect(bool_value(true_()).unwrap_or(false), content="true")
  inspect(bool_value(true_()).unwrap_or(false), content="true")
  match number_symbol_kind(pi()) {
    Some(NumberSymbolKind::Pi) => ()
    _ => fail("expected pi kind")
  }
  match number_symbol_kind(imag_unit()) {
    Some(NumberSymbolKind::ImaginaryUnit) => ()
    _ => fail("expected I kind")
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

///|
test "undefined function heads are distinct from applied functions" {
  let f = undefined_function("f")
  let sin_head = function_head("sin")
  let fx = applied_undefined_function("f", [symbol("x")])
  let sinx = function("sin", [symbol("x")])
  match expr_form(f) {
    ExprForm::UndefinedFunction(name) => inspect(name, content="f")
    _ => fail("expected undefined function head")
  }
  match expr_form(sin_head) {
    ExprForm::FunctionHead(name) => inspect(name, content="sin")
    _ => fail("expected named function head")
  }
  inspect(args(f).length(), content="0")
  inspect(args(sin_head).length(), content="0")
  inspect(args(fx).length(), content="1")
  inspect(head_name(sin_head), content="sin")
  inspect(head_name(fx), content="f")
  inspect(head_name(sinx), content="sin")
  inspect(free_symbols(f).length(), content="0")
  inspect(free_symbols(sin_head).length(), content="0")
}

///|
test "formal application helpers roundtrip named and undefined heads" {
  let x = symbol("x")
  let sin_head = function_head("sin")
  let f_head = undefined_function("f")
  match apply(sin_head, [x]) {
    Some(expr) => {
      inspect(@symprint.to_string(expr), content="sin(x)")
      inspect(application_name(expr).unwrap_or(""), content="sin")
      inspect(application_args(expr).unwrap_or([]).length(), content="1")
      assert_true(application_has_name(expr, "sin", arity=1))
    }
    None => fail("expected named head application")
  }
  match apply(f_head, [x]) {
    Some(expr) =>
      match application_parts(expr) {
        Some((head, [arg])) => {
          inspect(@symprint.to_string(head), content="f")
          inspect(@symprint.to_string(arg), content="x")
          inspect(application_name(expr).unwrap_or(""), content="f")
          assert_true(application_has_name(expr, "f", arity=1))
        }
        _ => fail("expected application parts")
      }
    None => fail("expected undefined head application")
  }
  assert_false(apply(int(1), [x]) is Some(_))
}

///|
test "dict is a first-class container node" {
  let d = dict_expr([(symbol("x"), symbol("y")), (int(1), symbol("z"))])
  match expr_form(d) {
    ExprForm::Dict(items) => inspect(items.length(), content="2")
    _ => fail("expected dict form")
  }
  inspect(args(d).length(), content="2")
  match dict_items(d) {
    Some(items) => {
      let (_, value) = items[1]
      inspect(@symprint.to_string(value), content="z")
    }
    None => fail("expected dict items")
  }
  json_inspect(free_symbols(d).map(@symprint.to_string), content=["x", "y", "z"])
}

///|
test "sympify lifts typed tuple and dict inputs" {
  let expr = sympify_tuple([
    sympify_int_input(1),
    sympify_symbol_input("x"),
    sympify_bool_input(true),
  ])
  inspect(@symprint.to_string(expr), content="(1, x, True)")
  let dict_value = sympify_dict([
    (sympify_symbol_input("x"), sympify_int_input(2)),
    (sympify_symbol_input("y"), sympify_expr_input(undefined_function("f"))),
  ])
  inspect(@symprint.to_string(dict_value), content="{x: 2, y: f}")
}

///|
test "atoms collects unique atomic leaves in canonical order" {
  let expr = add([
    function("f", [symbol("x")]),
    mul([int(2), symbol("x")]),
    tuple_expr([symbol("y"), int(1)]),
  ])
  json_inspect(atoms(expr).map(@symprint.to_string), content=[
    "x", "y", "1", "2",
  ])
}

///|
test "preorder and postorder traversal stay structural" {
  let x = symbol("x")
  let expr = add([derivative(function("f", [x]), x), mod_expr(x, int(2))])
  json_inspect(preorder(expr).map(@symprint.to_string), content=[
    "Mod(x, 2) + Derivative(f(x), x, 1)", "Mod(x, 2)", "x", "2", "Derivative(f(x), x, 1)",
    "f(x)", "x", "(x, 1)", "x", "1",
  ])
  json_inspect(postorder(expr).map(@symprint.to_string), content=[
    "x", "2", "Mod(x, 2)", "x", "f(x)", "x", "1", "(x, 1)", "Derivative(f(x), x, 1)",
    "Mod(x, 2) + Derivative(f(x), x, 1)",
  ])
}

///|
test "xreplace performs exact structural replacement" {
  let x = symbol("x")
  let y = symbol("y")
  let fx = function("f", [x])
  let expr = add([fx, x, y])
  let replaced = xreplace(expr, [(x, int(2)), (fx, symbol("z"))])
  inspect(@symprint.debug_repr(replaced), content="(+ sym:y sym:z 2)")
  inspect(
    @symprint.debug_repr(xreplace(function("f", [x]), [(x, int(2))])),
    content="(call f 2)",
  )
}

///|
test "evalf keeps undefined applications exact and evaluates Mod numerically" {
  inspect(
    @symprint.to_string(evalf(applied_undefined_function("f", [pi()]))),
    content="f(pi)",
  )
  inspect(
    @symprint.to_string(evalf(mod_expr(pi(), int(2)))).has_prefix(
      "1.14159265358979",
    ),
    content="true",
  )
}

///|
test "compare_expr follows function symbol and mod ordering" {
  let exprs : Array[Expr] = [
    symbol("x"),
    pi(),
    applied_undefined_function("f", [symbol("x")]),
    undefined_function("f"),
    dummy(name="x"),
    mod_expr(symbol("x"), int(2)),
  ]
  sort_exprs_in_place(exprs)
  json_inspect(exprs.map(@symprint.to_string), content=[
    "f", "_x", "pi", "x", "f(x)", "Mod(x, 2)",
  ])
}

///|
test "mod is a first-class structured core node" {
  let expr = mod_expr(add([symbol("x"), int(1)]), int(3))
  inspect(head_name(expr), content="Mod")
  json_inspect(args(expr).map(@symprint.to_string), content=["x + 1", "3"])
  inspect(@symprint.debug_repr(expr), content="(call Mod (+ sym:x 1) 3)")
}

///|
test "subst respects lambda bound variables" {
  let x = symbol("x")
  let y = symbol("y")
  let z = symbol("z")
  let expr = lambda_expr(x, add([x, y]))
  let env : Map[String, Expr] = { "x": int(2), "y": int(3) }
  inspect(@symprint.to_string(subst(expr, env)), content="Lambda(x, x + 3)")
  let rename_env : Map[String, Expr] = { "x": z, "y": int(3) }
  inspect(
    @symprint.to_string(subst(expr, rename_env)),
    content="Lambda(z, z + 3)",
  )
  let capture_env : Map[String, Expr] = { "x": y }
  inspect(
    @symprint.to_string(subst(expr, capture_env)),
    content="Lambda(y, y + y)",
  )
}

///|
test "subst respects Subs bound variables" {
  let x = symbol("x")
  let y = symbol("y")
  let z = symbol("z")
  let expr = subs_expr(add([x, y]), x, z)
  let env : Map[String, Expr] = { "x": int(2), "y": int(3), "z": int(4) }
  inspect(@symprint.to_string(subst(expr, env)), content="Subs(x + 3, x, 4)")
}

///|
test "subst respects derivative binding and capture rules" {
  let x = symbol("x")
  let y = symbol("y")
  let z = symbol("z")
  let fx = function("f", [x])
  let simple = derivative(fx, x)
  let with_free = derivative(add([fx, y]), x)
  let rename_env : Map[String, Expr] = { "x": z }
  inspect(
    @symprint.to_string(subst(simple, rename_env)),
    content="Derivative(f(z), z, 1)",
  )
  let invalid_env : Map[String, Expr] = { "x": int(2) }
  inspect(
    @symprint.to_string(subst(with_free, invalid_env)),
    content="Subs(Derivative(y + f(x), x, 1), x, 2)",
  )
  let safe_inner_env : Map[String, Expr] = { "y": int(3) }
  inspect(
    @symprint.to_string(subst(with_free, safe_inner_env)),
    content="Derivative(f(x) + 3, x, 1)",
  )
  let capture_env : Map[String, Expr] = { "y": x }
  inspect(
    @symprint.to_string(subst(with_free, capture_env)),
    content="Subs(Derivative(y + f(x), x, 1), y, x)",
  )
}

///|
test "numeric singleton predicates stay aligned with structured core atoms" {
  assert_true(is_number_symbol(pi()))
  assert_true(is_number_symbol(imag_unit()))
  assert_true(is_number_symbol(oo()))
  assert_true(is_number_symbol(nan_expr()))
  assert_true(is_infinite(oo()))
  assert_true(is_infinite(neg_oo()))
  assert_true(is_infinite(zoo()))
  assert_false(is_infinite(pi()))
  assert_true(is_nan(nan_expr()))
  assert_false(is_nan(pi()))
  assert_true(is_zero(int(0)))
  assert_true(is_zero(float(Float::from_int(0))))
  assert_true(is_one(int(1)))
  assert_true(is_one(float(Float::from_int(1))))
  assert_true(is_finite_number_atom(pi()))
  assert_false(is_finite_number_atom(oo()))
  assert_false(is_finite_number_atom(nan_expr()))
}
