///|
test "add flattens and folds constants" {
  let expr = add([int(1), Expr::Symbol("x"), add([int(2), Expr::Symbol("y")])])
  inspect(@symprint.debug_repr(expr), content="(+ sym:x sym:y 3)")
  inspect(
    @symprint.to_string(add([Expr::Symbol("x"), Expr::Symbol("x")])),
    content="2*x",
  )
}

///|
test "mul flattens and handles identities" {
  let expr = mul([Expr::Symbol("x"), int(1), mul([Expr::Symbol("y"), int(2)])])
  inspect(@symprint.debug_repr(expr), content="(* 2 sym:x sym:y)")
  let zeroed = mul([Expr::Symbol("x"), int(0), Expr::Symbol("y")])
  inspect(@symprint.debug_repr(zeroed), content="0")
}

///|
test "pow normalizes trivial exponents" {
  inspect(@symprint.debug_repr(pow(Expr::Symbol("x"), int(1))), content="sym:x")
  inspect(@symprint.debug_repr(pow(Expr::Symbol("x"), int(0))), content="1")
  inspect(@symprint.debug_repr(pow(int(0), int(0))), content="1")
}

///|
test "subst replaces symbols" {
  let env : Map[String, Expr] = { "x": int(2) }
  let expr = add([Expr::Symbol("x"), Expr::Symbol("y")])
  let replaced = subst(expr, env)
  inspect(@symprint.debug_repr(replaced), content="(+ sym:y 2)")
}

///|
test "basic helpers expose structured heads" {
  let rel = Expr::Relational(RelOp::Le, Expr::Symbol("x"), int(2))
  let tup = Expr::Tuple([Expr::Symbol("x"), int(2)])
  let deriv = derivative(
    function("f", [Expr::Symbol("x")]),
    Expr::Symbol("x"),
    order=int(2),
  )
  inspect(@symprint.debug_repr(rel), content="(call Le sym:x 2)")
  inspect(@symprint.debug_repr(tup), content="(call Tuple sym:x 2)")
  inspect(
    @symprint.debug_repr(deriv),
    content="(call Derivative (call f sym:x) (call Tuple sym:x 2))",
  )
  inspect(is_true(Expr::Boolean(true)), content="true")
  inspect(is_false(Expr::Boolean(false)), content="true")
}

///|
test "free_symbols respects bound variables" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let lam = lambda_expr(Expr::Tuple([x, y]), add([x, z]))
  let deriv = derivative(function("f", [x, y]), x, order=y)
  json_inspect(free_symbols(lam).map(@symprint.to_string), content=["z"])
  json_inspect(free_symbols(deriv).map(@symprint.to_string), content=["x", "y"])
  inspect(has(lam, z), content="true")
  inspect(has(lam, y), content="true")
}

///|
test "has sees callable heads in canonical applications" {
  let x = Expr::Symbol("x")
  assert_true(has(function("sin", [x]), Expr::FunctionHead("sin")))
  assert_true(
    has(applied_undefined_function("f", [x]), Expr::UndefinedFunction("f")),
  )
}

///|
test "plain symbol names no longer coerce to core singletons" {
  inspect(@symprint.debug_repr(Expr::Symbol("pi")), content="sym:pi")
  inspect(@symprint.debug_repr(Expr::Symbol("True")), content="sym:True")
  match number_symbol_kind(Expr::Symbol("pi")) {
    Some(_) => fail("plain symbol pi should not be a number symbol")
    None => ()
  }
  match bool_value(Expr::Symbol("True")) {
    Some(_) => fail("plain symbol True should not be a boolean atom")
    None => ()
  }
}

///|
test "number symbols are structured constants" {
  let pi_expr = Expr::NumberSymbol(NumberSymbolKind::Pi)
  let imag = Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit)
  let inf = Expr::NumberSymbol(NumberSymbolKind::Infinity)
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
    free_symbols(add([pi_expr, imag, Expr::Symbol("x")])).map(
      @symprint.to_string,
    ),
    content=["x"],
  )
  inspect(@symprint.to_string(mul([int(-1), inf])), content="-oo")
}

///|
test "dummy and wild are distinct structured symbols" {
  let d1 = dummy(name="x")
  let d2 = dummy(name="x")
  let w = Expr::Wild("x")
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
  inspect(bool_value(Expr::Boolean(true)).unwrap_or(false), content="true")
  inspect(bool_value(Expr::Boolean(true)).unwrap_or(false), content="true")
  match number_symbol_kind(Expr::NumberSymbol(NumberSymbolKind::Pi)) {
    Some(NumberSymbolKind::Pi) => ()
    _ => fail("expected pi kind")
  }
  match
    number_symbol_kind(Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit)) {
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
  let lam = lambda_expr(Expr::Tuple([d1]), add([d1, d2, Expr::Symbol("y")]))
  let free = free_symbols(lam)
  inspect(free.length(), content="2")
  assert_true(free.contains(Expr::Symbol("y")))
  assert_true(free.contains(d2))
  assert_false(free.contains(d1))
}

///|
test "derivative free symbols keep wrt symbols and order symbols" {
  let d = dummy(name="x")
  let order = Expr::Symbol("n")
  let expr = derivative(function("f", [d, order]), d, order~)
  let free = free_symbols(expr)
  inspect(free.length(), content="2")
  assert_true(free.contains(order))
  assert_true(free.contains(d))
}

///|
test "args follow SymPy-style derivative and lambda shapes" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  json_inspect(
    args(derivative(function("f", [x]), x)).map(@symprint.to_string),
    content=["f(x)", "(x, 1)"],
  )
  json_inspect(args(lambda_expr(x, add([x, y]))).map(@symprint.to_string), content=[
    "(x,)", "x + y",
  ])
  json_inspect(
    args(lambda_expr(Expr::Tuple([x, y]), add([x, y]))).map(@symprint.to_string),
    content=["(x, y)", "x + y"],
  )
}

///|
test "func and args expose canonical heads for containers and binders" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  inspect(
    @symprint.to_string(func(Expr::Tuple([x, y])).unwrap_or(int(0))),
    content="<class 'sympy.core.containers.Tuple'>",
  )
  inspect(
    @symprint.to_string(func(Expr::Dict([(x, y)])).unwrap_or(int(0))),
    content="<class 'sympy.core.containers.Dict'>",
  )
  inspect(
    @symprint.to_string(
      func(Expr::Relational(RelOp::Eq, x, y)).unwrap_or(int(0)),
    ),
    content="Equality",
  )
  inspect(
    @symprint.to_string(
      func(subs_expr(add([x, y]), x, int(1))).unwrap_or(int(0)),
    ),
    content="<class 'sympy.core.function.Subs'>",
  )
  let dict_args = args(Expr::Dict([(x, y), (int(1), x)])).map(
    @symprint.to_string,
  )
  inspect(dict_args.length(), content="2")
  assert_true(dict_args.contains("(1, x)"))
  assert_true(dict_args.contains("(x, y)"))
  json_inspect(
    args(Expr::Relational(RelOp::Eq, x, y)).map(@symprint.to_string),
    content=["x", "y"],
  )
  json_inspect(
    args(subs_expr(add([x, y]), x, int(1))).map(@symprint.to_string),
    content=["x + y", "(x,)", "(1,)"],
  )
}

///|
test "func exposes canonical heads for atomic core nodes" {
  inspect(
    @symprint.to_string(func(int(2)).unwrap_or(int(0))),
    content="Integer",
  )
  inspect(
    @symprint.to_string(func(rational_from_ints(1, 2)).unwrap_or(int(0))),
    content="Half",
  )
  inspect(
    @symprint.to_string(
      func(Expr::NumberSymbol(NumberSymbolKind::Pi)).unwrap_or(int(0)),
    ),
    content="Pi",
  )
  inspect(
    @symprint.to_string(func(Expr::Symbol("x")).unwrap_or(int(0))),
    content="Symbol",
  )
  inspect(
    @symprint.to_string(func(dummy(name="x")).unwrap_or(int(0))),
    content="Dummy",
  )
  inspect(
    @symprint.to_string(func(Expr::Wild("x")).unwrap_or(int(0))),
    content="Wild",
  )
  inspect(
    @symprint.to_string(func(Expr::Boolean(true)).unwrap_or(int(0))),
    content="BooleanTrue",
  )
  inspect(
    @symprint.to_string(func(Expr::Boolean(false)).unwrap_or(int(0))),
    content="BooleanFalse",
  )
}

///|
test "undefined function heads are distinct from applied functions" {
  let f = Expr::UndefinedFunction("f")
  let sin_head = Expr::FunctionHead("sin")
  let fx = applied_undefined_function("f", [Expr::Symbol("x")])
  let sinx = function("sin", [Expr::Symbol("x")])
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
  let x = Expr::Symbol("x")
  let sin_head = Expr::FunctionHead("sin")
  let f_head = Expr::UndefinedFunction("f")
  match apply(sin_head, [x]) {
    Some(expr) => {
      guard expr is Expr::Apply(Expr::FunctionHead("sin"), [Expr::Symbol("x")]) else {
        fail("expected first-class named application storage")
      }
      inspect(@symprint.to_string(expr), content="sin(x)")
      inspect(application_name(expr).unwrap_or(""), content="sin")
      inspect(application_args(expr).unwrap_or([]).length(), content="1")
      assert_true(application_has_name(expr, "sin", arity=1))
      match func(expr) {
        Some(head) => inspect(@symprint.to_string(head), content="sin")
        None => fail("expected application func")
      }
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
  assert_false(apply(Expr::Symbol("g"), [x]) is Some(_))
  assert_false(raw_apply(Expr::Symbol("g"), [x]) is Some(_))
  assert_false(apply(int(1), [x]) is Some(_))
  inspect(
    @symprint.to_string(func(Expr::Tuple([x])).unwrap_or(int(0))),
    content="<class 'sympy.core.containers.Tuple'>",
  )
}

///|
test "legacy function storage normalizes to canonical core semantics" {
  let x = Expr::Symbol("x")
  let legacy_named = Expr::Function("sin", [x])
  let canonical_named = function("sin", [x])
  inspect(@symprint.to_string(legacy_named), content="sin(x)")
  inspect(application_name(legacy_named).unwrap_or(""), content="sin")
  json_inspect(children(legacy_named).map(@symprint.to_string), content=["x"])
  inspect(compare_expr(legacy_named, canonical_named), content="0")
  inspect(
    legacy_named.hash().to_string(),
    content=canonical_named.hash().to_string(),
  )
  inspect(
    @symprint.to_string(
      evalf(Expr::Function("sin", [Expr::NumberSymbol(NumberSymbolKind::Pi)])),
    ),
    content=@symprint.to_string(
      evalf(function("sin", [Expr::NumberSymbol(NumberSymbolKind::Pi)])),
    ),
  )
  let legacy_derivative = Expr::Function("Derivative", [function("f", [x]), x])
  json_inspect(children(legacy_derivative).map(@symprint.to_string), content=[
    "f(x)", "(x, 1)",
  ])
  inspect(
    @symprint.to_string(xreplace(legacy_derivative, [(x, int(2))])),
    content="Derivative(f(2), 2)",
  )
  let nested_legacy = Expr::Add([
    Expr::Function("sin", [Expr::Function("Tuple", [x, int(1)])]),
    Expr::Function("Derivative", [function("f", [x]), x]),
  ])
  match normalize_legacy_expr(nested_legacy) {
    Expr::Add([lhs, rhs]) => {
      match application_parts(lhs) {
        Some(
          (Expr::FunctionHead("sin"), [Expr::Tuple([Expr::Symbol("x"), one])])
        ) => inspect(@symprint.to_string(one), content="1")
        _ => fail("expected recursively normalized named application")
      }
      match derivative_parts(rhs) {
        Some((inner, [Expr::Symbol("x"), one])) => {
          inspect(@symprint.to_string(inner), content="f(x)")
          inspect(@symprint.to_string(one), content="1")
        }
        _ => fail("expected recursively normalized derivative")
      }
    }
    _ => fail("expected recursively normalized Add")
  }
  match function("Dict", [x]) {
    Expr::Apply(Expr::FunctionHead("Dict"), [Expr::Symbol("x")]) => ()
    _ => fail("expected malformed Dict to canonicalize as Apply")
  }
}

///|
test "application constructors canonicalize legacy children eagerly" {
  let x = Expr::Symbol("x")
  let legacy_derivative = Expr::Function("Derivative", [x, x])
  match function("sin", [legacy_derivative]) {
    Expr::Apply(Expr::FunctionHead("sin"), [Expr::Derivative(_, [_, one])]) =>
      inspect(@symprint.to_string(one), content="1")
    _ => fail("expected canonical named application child")
  }
  match apply(Expr::FunctionHead("sin"), [legacy_derivative]) {
    Some(
      Expr::Apply(Expr::FunctionHead("sin"), [Expr::Derivative(_, [_, one])])
    ) => inspect(@symprint.to_string(one), content="1")
    _ => fail("expected apply() to canonicalize legacy child")
  }
  match applied_undefined_function("f", [legacy_derivative]) {
    Expr::Apply(Expr::UndefinedFunction("f"), [Expr::Derivative(_, [_, one])]) =>
      inspect(@symprint.to_string(one), content="1")
    _ => fail("expected undefined application child normalization")
  }
}

///|
test "function constructors follow SymPy core semantics" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  inspect(@symprint.to_string(function("Eq", [x, x])), content="True")
  inspect(@symprint.to_string(function("Ne", [x, x])), content="False")
  inspect(@symprint.to_string(function("Lt", [int(1), int(2)])), content="True")
  inspect(@symprint.to_string(function("Ge", [int(1), int(2)])), content="False")
  inspect(
    @symprint.to_string(function("Derivative", [function("sin", [x]), x, int(2)])),
    content="Derivative(sin(x), (x, 2))",
  )
  inspect(
    @symprint.to_string(function("Derivative", [function("sin", [x]), x, y])),
    content="Derivative(sin(x), x, y)",
  )
}

///|
test "dict is a first-class container node" {
  let d = Expr::Dict([
    (Expr::Symbol("x"), Expr::Symbol("y")),
    (int(1), Expr::Symbol("z")),
  ])
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
    SympifyInput::FromInt(1),
    SympifyInput::SymbolName("x"),
    SympifyInput::FromBool(true),
  ])
  inspect(@symprint.to_string(expr), content="(1, x, True)")
  let dict_value = sympify_dict([
    (SympifyInput::SymbolName("x"), SympifyInput::FromInt(2)),
    (
      SympifyInput::SymbolName("y"),
      SympifyInput::FromExpr(Expr::UndefinedFunction("f")),
    ),
  ])
  inspect(@symprint.to_string(dict_value), content="{x: 2, y: f}")
  inspect(
    @symprint.to_string(
      sympify(
        SympifyInput::Application(SympifyInput::FunctionHeadName("sin"), [
          SympifyInput::SymbolName("x"),
        ]),
      ),
    ),
    content="sin(x)",
  )
  inspect(
    @symprint.to_string(
      sympify(
        SympifyInput::Application(SympifyInput::UndefinedFunctionName("f"), [
          SympifyInput::DummyName("x"),
          SympifyInput::WildName("y"),
        ]),
      ),
    ),
    content="f(_x, y_)",
  )
  match
    sympify(SympifyInput::FromExpr(Expr::Function("sin", [Expr::Symbol("x")]))) {
    Expr::Apply(Expr::FunctionHead("sin"), [Expr::Symbol("x")]) => ()
    _ => fail("expected sympify FromExpr to canonicalize named application")
  }
  match
    sympify(
      SympifyInput::FromExpr(
        Expr::Function("Derivative", [Expr::Symbol("x"), Expr::Symbol("x")]),
      ),
    ) {
    Expr::Derivative(Expr::Symbol("x"), [Expr::Symbol("x"), one]) =>
      inspect(@symprint.to_string(one), content="1")
    _ => fail("expected sympify FromExpr to canonicalize derivative")
  }
}

///|
test "atoms collects unique atomic leaves in canonical order" {
  let expr = add([
    function("f", [Expr::Symbol("x")]),
    mul([int(2), Expr::Symbol("x")]),
    Expr::Tuple([Expr::Symbol("y"), int(1)]),
  ])
  json_inspect(atoms(expr).map(@symprint.to_string), content=[
    "x", "y", "1", "2",
  ])
}

///|
test "preorder and postorder traversal stay structural" {
  let x = Expr::Symbol("x")
  let expr = add([derivative(function("f", [x]), x), mod_expr(x, int(2))])
  json_inspect(preorder(expr).map(@symprint.to_string), content=[
    "Derivative(f(x), x) + Mod(x, 2)", "Derivative(f(x), x)", "f(x)", "x", "(x, 1)",
    "x", "1", "Mod(x, 2)", "x", "2",
  ])
  json_inspect(postorder(expr).map(@symprint.to_string), content=[
    "x", "f(x)", "x", "1", "(x, 1)", "Derivative(f(x), x)", "x", "2", "Mod(x, 2)",
    "Derivative(f(x), x) + Mod(x, 2)",
  ])
}

///|
test "children wrap Subs and Lambda binders like SymPy args" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  json_inspect(
    children(subs_expr(add([x, y]), x, int(1))).map(@symprint.to_string),
    content=["x + y", "(x,)", "(1,)"],
  )
  json_inspect(
    args(subs_expr(add([x, y]), Expr::Tuple([x, y]), Expr::Tuple([y, int(1)]))).map(
      @symprint.to_string,
    ),
    content=["x + y", "(x, y)", "(y, 1)"],
  )
  json_inspect(children(lambda_expr(x, add([x, y]))).map(@symprint.to_string), content=[
    "(x,)", "x + y",
  ])
}

///|
test "xreplace performs exact structural replacement" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let fx = function("f", [x])
  let expr = add([fx, x, y])
  let replaced = xreplace(expr, [(x, int(2)), (fx, Expr::Symbol("z"))])
  inspect(@symprint.debug_repr(replaced), content="(+ sym:y sym:z 2)")
  inspect(
    @symprint.debug_repr(xreplace(function("f", [x]), [(x, int(2))])),
    content="(call f 2)",
  )
  inspect(
    @symprint.to_string(
      xreplace(derivative(add([function("sin", [x]), y]), x), [
        (y, Expr::Symbol("z")),
      ]),
    ),
    content="Derivative(z + sin(x), x)",
  )
  inspect(
    @symprint.to_string(
      xreplace(derivative(add([function("sin", [x]), y]), x), [
        (x, Expr::Symbol("z")),
      ]),
    ),
    content="Derivative(y + sin(z), z)",
  )
}

///|
test "replace performs preorder structural rewrites on canonical applications" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let expr = add([function("sin", [x]), function("sin", [y])])
  let rewritten = replace(
    expr,
    fn(node : Expr) -> Bool { application_has_name(node, "sin", arity=1) },
    fn(node : Expr) -> Expr {
      match application_args(node) {
        Some([arg]) => function("cos", [arg])
        _ => node
      }
    },
  )
  inspect(@symprint.to_string(rewritten), content="cos(x) + cos(y)")
  inspect(
    @symprint.to_string(
      replace(
        add([x, function("sin", [x])]),
        fn(node : Expr) -> Bool { node == x },
        fn(_node : Expr) -> Expr { add([x, int(1)]) },
      ),
    ),
    content="x + sin((x + 1)) + 1",
  )
  inspect(
    @symprint.to_string(
      replace(
        Expr::Function("sin", [x]),
        fn(node : Expr) -> Bool { application_has_name(node, "sin", arity=1) },
        fn(node : Expr) -> Expr {
          match application_args(node) {
            Some([arg]) => function("cos", [arg])
            _ => node
          }
        },
      ),
    ),
    content="cos(x)",
  )
}

///|
test "evalf keeps undefined applications exact and evaluates Mod numerically" {
  inspect(
    @symprint.to_string(
      evalf(
        applied_undefined_function("f", [
          Expr::NumberSymbol(NumberSymbolKind::Pi),
        ]),
      ),
    ),
    content="f(pi)",
  )
  inspect(
    @symprint.to_string(
      evalf(mod_expr(Expr::NumberSymbol(NumberSymbolKind::Pi), int(2))),
    ).has_prefix("1.14159265358979"),
    content="true",
  )
}

///|
test "compare_expr follows function symbol and mod ordering" {
  let exprs : Array[Expr] = [
    Expr::Symbol("x"),
    Expr::NumberSymbol(NumberSymbolKind::Pi),
    applied_undefined_function("f", [Expr::Symbol("x")]),
    Expr::UndefinedFunction("f"),
    dummy(name="x"),
    mod_expr(Expr::Symbol("x"), int(2)),
  ]
  sort_exprs_in_place(exprs)
  json_inspect(exprs.map(@symprint.to_string), content=[
    "f", "_x", "pi", "x", "f(x)", "Mod(x, 2)",
  ])
}

///|
test "mod is a first-class structured core node" {
  let expr = mod_expr(add([Expr::Symbol("x"), int(1)]), int(3))
  inspect(head_name(expr), content="Mod")
  json_inspect(args(expr).map(@symprint.to_string), content=["x + 1", "3"])
  inspect(@symprint.debug_repr(expr), content="(call Mod (+ sym:x 1) 3)")
}

///|
test "subst respects lambda bound variables" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
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
    content="Lambda(y, 2*y)",
  )
  let tuple_expr = lambda_expr(Expr::Tuple([x, y]), add([x, y]))
  inspect(
    @symprint.to_string(subst(tuple_expr, { "y": z })),
    content="Lambda((x, z), x + z)",
  )
  inspect(
    @symprint.to_string(subst(tuple_expr, { "x": z })),
    content="Lambda((z, y), y + z)",
  )
  inspect(
    @symprint.to_string(subst(tuple_expr, { "y": x })),
    content="Lambda((x, y), x + y)",
  )
  inspect(
    @symprint.to_string(subst(tuple_expr, { "x": y })),
    content="Lambda((x, y), x + y)",
  )
}

///|
test "subst respects Subs bound variables" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let w = Expr::Symbol("w")
  let expr = subs_expr(add([x, y]), x, z)
  let env : Map[String, Expr] = { "x": int(2), "y": int(3), "z": int(4) }
  inspect(@symprint.to_string(subst(expr, env)), content="Subs(x + 3, x, 4)")
  let multi = subs_expr(add([x, y]), Expr::Tuple([x, y]), Expr::Tuple([y, z]))
  inspect(
    @symprint.to_string(subst(multi, { "y": w })),
    content="Subs(w + x, (x, w), (w, z))",
  )
  inspect(
    @symprint.to_string(subst(multi, { "x": w })),
    content="Subs(w + y, (w, y), (y, z))",
  )
  inspect(
    @symprint.to_string(subst(multi, { "y": x })),
    content="Subs(x + y, (x, y), (y, z))",
  )
  inspect(
    @symprint.to_string(subst(multi, { "x": y })),
    content="Subs(x + y, (x, y), (y, z))",
  )
}

///|
test "subst respects derivative binding and capture rules" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let fx = function("f", [x])
  let simple = derivative(fx, x)
  let with_free = derivative(add([fx, y]), x)
  let rename_env : Map[String, Expr] = { "x": z }
  inspect(
    @symprint.to_string(subst(simple, rename_env)),
    content="Derivative(f(z), z)",
  )
  let invalid_env : Map[String, Expr] = { "x": int(2) }
  inspect(
    @symprint.to_string(subst(with_free, invalid_env)),
    content="Subs(Derivative(y + f(x), x), x, 2)",
  )
  let safe_inner_env : Map[String, Expr] = { "y": int(3) }
  inspect(
    @symprint.to_string(subst(with_free, safe_inner_env)),
    content="Derivative(f(x) + 3, x)",
  )
  let capture_env : Map[String, Expr] = { "y": x }
  inspect(
    @symprint.to_string(subst(with_free, capture_env)),
    content="Subs(Derivative(y + f(x), x), y, x)",
  )
  let mixed = Expr::Derivative(add([function("sin", [x]), y]), [
    x,
    int(1),
    y,
    int(1),
  ])
  inspect(
    @symprint.to_string(subst(mixed, { "y": z })),
    content="Derivative(z + sin(x), x, z)",
  )
  inspect(
    @symprint.to_string(subst(mixed, { "x": z })),
    content="Derivative(y + sin(z), z, y)",
  )
}

///|
test "subst rewrites callable heads only when replacement stays callable" {
  let x = Expr::Symbol("x")
  let sinx = function("sin", [x])
  let fx = applied_undefined_function("f", [x])
  let sin_env : Map[String, Expr] = { "sin": Expr::FunctionHead("cos") }
  inspect(@symprint.to_string(subst(sinx, sin_env)), content="cos(x)")
  let f_env : Map[String, Expr] = { "f": Expr::UndefinedFunction("g") }
  inspect(@symprint.to_string(subst(fx, f_env)), content="g(x)")
  let non_callable_env : Map[String, Expr] = { "f": Expr::Symbol("z") }
  inspect(@symprint.to_string(subst(fx, non_callable_env)), content="f(x)")
}

///|
test "subst beta-reduces callable heads to lambda replacements" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  inspect(
    @symprint.to_string(
      subst(function("sin", [x]), { "sin": lambda_expr(x, add([x, int(1)])) }),
    ),
    content="x + 1",
  )
  inspect(
    @symprint.to_string(
      subst(applied_undefined_function("f", [x, y]), {
        "f": lambda_expr(Expr::Tuple([x, y]), add([x, y])),
      }),
    ),
    content="x + y",
  )
  inspect(
    @symprint.to_string(
      subst(function("sin", [x]), {
        "sin": lambda_expr(Expr::Tuple([x, y]), add([x, y])),
      }),
    ),
    content="sin(x)",
  )
}

///|
test "numeric singleton predicates stay aligned with structured core atoms" {
  assert_true(is_number_symbol(Expr::NumberSymbol(NumberSymbolKind::Pi)))
  assert_true(
    is_number_symbol(Expr::NumberSymbol(NumberSymbolKind::ImaginaryUnit)),
  )
  assert_true(is_number_symbol(Expr::NumberSymbol(NumberSymbolKind::Infinity)))
  assert_true(is_number_symbol(Expr::NumberSymbol(NumberSymbolKind::NaN)))
  assert_true(is_infinite(Expr::NumberSymbol(NumberSymbolKind::Infinity)))
  assert_true(
    is_infinite(Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity)),
  )
  assert_true(
    is_infinite(Expr::NumberSymbol(NumberSymbolKind::ComplexInfinity)),
  )
  assert_false(is_infinite(Expr::NumberSymbol(NumberSymbolKind::Pi)))
  assert_true(is_nan(Expr::NumberSymbol(NumberSymbolKind::NaN)))
  assert_false(is_nan(Expr::NumberSymbol(NumberSymbolKind::Pi)))
  assert_true(is_zero(int(0)))
  assert_true(is_zero(Expr::Float(Float::from_int(0))))
  assert_true(is_one(int(1)))
  assert_true(is_one(Expr::Float(Float::from_int(1))))
  assert_true(is_finite_number_atom(Expr::NumberSymbol(NumberSymbolKind::Pi)))
  assert_false(
    is_finite_number_atom(Expr::NumberSymbol(NumberSymbolKind::Infinity)),
  )
  assert_false(is_finite_number_atom(Expr::NumberSymbol(NumberSymbolKind::NaN)))
}
