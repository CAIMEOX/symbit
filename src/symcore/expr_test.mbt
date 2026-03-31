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
  let subs_multi = subs_expr(
    add([x, y]),
    Expr::Tuple([x, y]),
    Expr::Tuple([y, z]),
  )
  json_inspect(free_symbols(lam).map(@symprint.to_string), content=["z"])
  json_inspect(free_symbols(deriv).map(@symprint.to_string), content=["x", "y"])
  json_inspect(free_symbols(subs_multi).map(@symprint.to_string), content=[
    "y", "z",
  ])
  inspect(has(lam, z), content="true")
  inspect(has(lam, y), content="true")
  json_inspect(
    free_symbols(lambda_expr(Expr::Tuple([]), int(42))).map(@symprint.to_string),
    content=[],
  )
  json_inspect(
    free_symbols(lambda_expr(Expr::Tuple([]), mul([x, y]))).map(
      @symprint.to_string,
    ),
    content=["x", "y"],
  )
  let subs_structural = subs_expr(x, x, int(0))
  inspect(has(subs_structural, x), content="true")
  json_inspect(free_symbols(subs_structural).map(@symprint.to_string), content=[])
  let subs_env : Map[String, Expr] = {}
  subs_env.set("x", y)
  inspect(has(subst(subs_expr(x, x, int(1)), subs_env), y), content="true")
}

///|
test "has sees callable heads in canonical applications" {
  let x = Expr::Symbol("x")
  assert_true(has(function("sin", [x]), Expr::FunctionHead("sin")))
  assert_true(
    has(applied_undefined_function("f", [x]), Expr::UndefinedFunction("f")),
  )
  let dfx = derivative(applied_undefined_function("f", [x]), x)
  assert_true(has(dfx, Expr::FunctionHead("Derivative")))
  assert_true(has(pow(x, int(2)), Expr::FunctionHead("Symbol")))
  assert_false(has(pow(x, int(2)), Expr::FunctionHead("Wild")))
  assert_true(
    has(mul([int(2), Expr::Wild("p", [], [])]), Expr::FunctionHead("Wild")),
  )
}

///|
test "has follows SymPy class-head and additive subset semantics" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")

  assert_true(has(int(1), Expr::FunctionHead("Integer")))
  assert_true(has(int(1), Expr::FunctionHead("Rational")))
  assert_true(has(rational_from_ints(1, 2), Expr::FunctionHead("Rational")))
  assert_false(has(rational_from_ints(1, 2), Expr::FunctionHead("Integer")))
  assert_true(
    has(
      Expr::NumberSymbol(NumberSymbolKind::Pi),
      Expr::FunctionHead("NumberSymbol"),
    ),
  )
  assert_true(has(Expr::Dummy("d", 1), Expr::FunctionHead("Symbol")))
  assert_true(has(Expr::Wild("p", [], []), Expr::FunctionHead("Symbol")))
  assert_true(has(int(1), Expr::FunctionHead("Atom")))
  assert_true(has(int(1), Expr::FunctionHead("Expr")))
  assert_true(has(x, Expr::FunctionHead("AtomicExpr")))
  assert_true(has(function("sin", [x]), Expr::FunctionHead("Application")))
  assert_true(has(function("sin", [x]), Expr::FunctionHead("Function")))
  assert_true(has(add([x, y]), Expr::FunctionHead("Expr")))
  assert_true(has(mod_expr(x, int(2)), Expr::FunctionHead("Function")))
  assert_true(has(subs_expr(x, x, int(0)), Expr::FunctionHead("Expr")))
  assert_false(
    has(Expr::Tuple([Expr::Boolean(true)]), Expr::FunctionHead("Expr")),
  )
  assert_false(
    has(
      Expr::Relational(RelOp::Eq, Expr::Boolean(true), Expr::Boolean(false)),
      Expr::FunctionHead("Expr"),
    ),
  )
  assert_true(has(add([x, y, int(1)]), add([x, int(1)])))
  assert_false(has(add([x, y]), add([x, z])))
  assert_true(has(mul([x, y, z]), mul([x, y])))
  assert_false(has(mul([x, y]), mul([x, z])))
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
  let w = Expr::Wild("x", [], [])
  assert_false(d1 == d2)
  inspect(@symprint.to_string(d1), content="_x")
  inspect(@symprint.to_string(w), content="x_")
  match expr_form(d1) {
    ExprForm::Dummy(name, _) => inspect(name, content="x")
    _ => fail("expected dummy expr form")
  }
  match expr_form(w) {
    ExprForm::Wild(name, _, _) => inspect(name, content="x")
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
    content="<class 'sympy.core.relational.Equality'>",
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
    content="<class 'sympy.core.numbers.Integer'>",
  )
  inspect(
    @symprint.to_string(func(rational_from_ints(1, 2)).unwrap_or(int(0))),
    content="<class 'sympy.core.numbers.Half'>",
  )
  inspect(
    @symprint.to_string(
      func(Expr::NumberSymbol(NumberSymbolKind::Pi)).unwrap_or(int(0)),
    ),
    content="<class 'sympy.core.numbers.Pi'>",
  )
  inspect(
    @symprint.to_string(func(Expr::Symbol("x")).unwrap_or(int(0))),
    content="<class 'sympy.core.symbol.Symbol'>",
  )
  inspect(
    @symprint.to_string(func(dummy(name="x")).unwrap_or(int(0))),
    content="<class 'sympy.core.symbol.Dummy'>",
  )
  inspect(
    @symprint.to_string(func(Expr::Wild("x", [], [])).unwrap_or(int(0))),
    content="<class 'sympy.core.symbol.Wild'>",
  )
  inspect(
    @symprint.to_string(func(Expr::Boolean(true)).unwrap_or(int(0))),
    content="<class 'sympy.logic.boolalg.BooleanTrue'>",
  )
  inspect(
    @symprint.to_string(func(Expr::Boolean(false)).unwrap_or(int(0))),
    content="<class 'sympy.logic.boolalg.BooleanFalse'>",
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
  match apply(Expr::FunctionHead("Integer"), [rational_from_ints(5, 2)]) {
    Some(Expr::Number(n)) => inspect(n.to_string(), content="2")
    _ => fail("expected Integer constructor semantics through apply")
  }
  match apply(Expr::FunctionHead("Integer"), [rational_from_ints(-2, 3)]) {
    Some(Expr::Number(n)) => inspect(n.to_string(), content="0")
    _ => fail("expected Integer truncation through apply")
  }
  match apply(Expr::FunctionHead("Rational"), [int(2), int(3)]) {
    Some(Expr::Number(n)) => inspect(n.to_string(), content="2/3")
    _ => fail("expected Rational constructor semantics through apply")
  }
  match
    apply(Expr::FunctionHead("Rational"), [Expr::Float(Float::from_double(2.5))]) {
    Some(Expr::Number(n)) => inspect(n.to_string(), content="5/2")
    _ => fail("expected Rational(float) constructor semantics through apply")
  }
  match apply(Expr::FunctionHead("Float"), [int(2)]) {
    Some(Expr::Float(_)) => ()
    _ => fail("expected Float constructor semantics through apply")
  }
  match apply(Expr::FunctionHead("Float"), [int(2), int(20)]) {
    Some(Expr::Float(value)) =>
      inspect(
        value.precision().to_string(),
        content=@symnum.dps_to_prec(20).to_string(),
      )
    _ => fail("expected Float precision constructor semantics through apply")
  }
  match
    apply(Expr::FunctionHead("Float"), [
      Expr::Tuple([int(0), int(0), int(-123)]),
    ]) {
    Some(Expr::Number(n)) => inspect(n.to_string(), content="0")
    _ => fail("expected Float 3-tuple zero semantics through apply")
  }
  match
    apply(Expr::FunctionHead("Float"), [
      Expr::Tuple([int(0), int(0), int(-123), int(-1)]),
    ]) {
    Some(Expr::NumberSymbol(NumberSymbolKind::NaN)) => ()
    _ => fail("expected Float special tuple NaN semantics through apply")
  }
  match
    apply(Expr::FunctionHead("Float"), [
      Expr::Tuple([int(0), int(0), int(-456), int(-2)]),
    ]) {
    Some(Expr::NumberSymbol(NumberSymbolKind::Infinity)) => ()
    _ => fail("expected Float special tuple infinity semantics through apply")
  }
  match
    apply(Expr::FunctionHead("Float"), [
      Expr::Tuple([int(1), int(0), int(-789), int(-3)]),
    ]) {
    Some(Expr::NumberSymbol(NumberSymbolKind::NegativeInfinity)) => ()
    _ =>
      fail(
        "expected Float special tuple negative infinity semantics through apply",
      )
  }
  inspect(
    @symprint.to_string(
      function("Float", [Expr::Tuple([int(2), int(1), int(0)])]),
    ),
    content="Float((2, 1, 0))",
  )
  match apply(Expr::FunctionHead("Tuple"), [x, int(1)]) {
    Some(Expr::Tuple([Expr::Symbol("x"), Expr::Number(n)])) =>
      inspect(n.to_string(), content="1")
    _ => fail("expected Tuple constructor semantics through apply")
  }
  match apply(Expr::FunctionHead("S"), [add([x, x])]) {
    Some(expr) => inspect(@symprint.to_string(expr), content="2*x")
    _ => fail("expected S constructor semantics through apply")
  }
  match raw_apply(Expr::FunctionHead("S"), [function("sin", [x])]) {
    Some(expr) => inspect(@symprint.to_string(expr), content="sin(x)")
    _ => fail("expected S raw constructor semantics through apply")
  }
  match apply(Expr::FunctionHead("S"), [x, Expr::Symbol("y")]) {
    Some(expr) => inspect(@symprint.to_string(expr), content="x")
    _ => fail("expected multi-arg S to return first sympified argument")
  }
  match apply(Expr::FunctionHead("S"), []) {
    Some(Expr::Apply(Expr::FunctionHead("S"), [])) => ()
    _ => fail("expected unsupported S arity to stay canonical Apply")
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
  match
    normalize_legacy_expr(
      Expr::Function("Lambda", [Expr::Tuple([x, int(2)]), add([x, int(1)])]),
    ) {
    Expr::Apply(
      Expr::FunctionHead("Lambda"),
      [Expr::Tuple([Expr::Symbol("x"), two]), body]
    ) => {
      inspect(@symprint.to_string(two), content="2")
      inspect(@symprint.to_string(body), content="x + 1")
    }
    _ => fail("expected invalid legacy Lambda to canonicalize as Apply")
  }
  inspect(
    @symprint.to_string(normalize_legacy_expr(Expr::Lambda(x, x))),
    content="Lambda(_x, _x)",
  )
  inspect(
    @symprint.to_string(normalize_legacy_expr(Expr::Derivative(x, [x]))),
    content="Derivative(x, x)",
  )
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
  inspect(
    @symprint.to_string(function("Ge", [int(1), int(2)])),
    content="False",
  )
  inspect(
    @symprint.to_string(
      function("Derivative", [function("sin", [x]), x, int(2)]),
    ),
    content="Derivative(sin(x), (x, 2))",
  )
  inspect(
    @symprint.to_string(function("Derivative", [function("sin", [x]), x, y])),
    content="Derivative(sin(x), x, y)",
  )
  inspect(
    @symprint.to_string(
      function("Derivative", [function("sin", [x]), Expr::Tuple([x, int(0)])]),
    ),
    content="sin(x)",
  )
  inspect(
    @symprint.to_string(
      function("Derivative", [function("sin", [x]), x, y, int(2)]),
    ),
    content="Derivative(sin(x), x, (y, 2))",
  )
  inspect(
    @symprint.to_string(
      function("Subs", [add([x, y]), Expr::Tuple([x, y]), Expr::Symbol("z")]),
    ),
    content="Subs(x + y, (x, y), z)",
  )
  inspect(
    @symprint.to_string(
      function("Integer", [raw_mul([int(3), raw_pow(int(2), int(-1))])]),
    ),
    content="1",
  )
  inspect(
    @symprint.to_string(
      function("Integer", [Expr::NumberSymbol(NumberSymbolKind::Pi)]),
    ),
    content="3",
  )
  inspect(
    @symprint.to_string(
      function("Integer", [Expr::Float(Float::from_double(0.9))]),
    ),
    content="0",
  )
  inspect(
    @symprint.to_string(
      function("Integer", [Expr::Float(Float::from_double(10.5))]),
    ),
    content="10",
  )
  inspect(
    @symprint.to_string(
      function("Integer", [Expr::Float(Float::from_double(-3.8))]),
    ),
    content="-3",
  )
  inspect(
    @symprint.to_string(function("Integer", [Expr::Boolean(true)])),
    content="1",
  )
  inspect(
    @symprint.to_string(function("Integer", [Expr::Boolean(false)])),
    content="0",
  )
  inspect(
    @symprint.to_string(
      function("Rational", [raw_mul([int(3), raw_pow(int(2), int(-1))])]),
    ),
    content="3/2",
  )
  match
    with_evaluate(false, fn() {
      function("Rational", [raw_mul([int(3), raw_pow(int(2), int(-1))])])
    }) {
    Expr::Apply(Expr::FunctionHead("Rational"), [_]) => ()
    other =>
      fail(
        "expected evaluate=false Rational raw expression to stay unevaluated, got \{@symprint.to_string(other)}",
      )
  }
  match function("Float", [Expr::NumberSymbol(NumberSymbolKind::Pi)]) {
    Expr::Float(_) => ()
    other =>
      fail("expected Float(pi) to evaluate, got \{@symprint.to_string(other)}")
  }
  inspect(
    @symprint.to_string(function("Rational", [Expr::Boolean(true)])),
    content="1",
  )
  inspect(
    @symprint.to_string(function("Rational", [Expr::Boolean(false)])),
    content="0",
  )
  inspect(
    @symprint.to_string(function("Rational", [int(1), Expr::Boolean(false)])),
    content="zoo",
  )
  inspect(
    @symprint.to_string(
      function("Rational", [Expr::Boolean(false), Expr::Boolean(false)]),
    ),
    content="nan",
  )
  inspect(
    @symprint.to_string(
      function("Rational", [Expr::Float(Float::from_double(1.0)), int(3)]),
    ),
    content="1/3",
  )
  inspect(
    @symprint.to_string(
      function("Rational", [int(1), Expr::Float(Float::from_double(3.0))]),
    ),
    content="1/3",
  )
  inspect(
    @symprint.to_string(
      function("Rational", [rational_from_ints(1, 2), rational_from_ints(1, 3)]),
    ),
    content="3/2",
  )
  inspect(
    @symprint.to_string(
      function("Rational", [int(1), rational_from_ints(1, 3)]),
    ),
    content="3",
  )
  inspect(
    @symprint.to_string(function("S", [Expr::Boolean(true)])),
    content="True",
  )
  inspect(
    @symprint.to_string(function("S", [Expr::Boolean(false)])),
    content="False",
  )
}

///|
test "invalid Subs signatures stay as canonical applications" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  inspect(
    @symprint.to_string(subs_expr(add([x, y]), Expr::Tuple([x, y]), z)),
    content="Subs(x + y, (x, y), z)",
  )
  inspect(
    @symprint.to_string(
      normalize_legacy_expr(Expr::Subs(add([x, y]), Expr::Tuple([x, y]), z)),
    ),
    content="Subs(x + y, (x, y), z)",
  )
  match subs_expr(add([x, y]), Expr::Tuple([x, y]), z) {
    Expr::Apply(Expr::FunctionHead("Subs"), _) => ()
    _ => fail("expected invalid Subs signature to remain an application")
  }
  inspect(
    @symprint.to_string(
      subs_expr(add([x, y]), Expr::Tuple([]), Expr::Tuple([])),
    ),
    content="x + y",
  )
  inspect(
    @symprint.to_string(subs_expr(subs_expr(x, x, int(0)), y, int(1))),
    content="Subs(x, (x, y), (0, 1))",
  )
  inspect(
    subs_signature_error(Expr::Tuple([x, x]), Expr::Tuple([int(0), int(1)])).unwrap_or(
      "",
    ),
    content="The following expressions appear more than once: x",
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
test "preorder and postorder canonicalize legacy roots before traversal" {
  let x = Expr::Symbol("x")
  let legacy = Expr::Function("sin", [x])
  json_inspect(preorder(legacy).map(@symprint.to_string), content=[
    "sin(x)", "x",
  ])
  json_inspect(postorder(legacy).map(@symprint.to_string), content=[
    "x", "sin(x)",
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
  let legacy_sinx = Expr::Function("sin", [x])
  inspect(
    @symprint.to_string(xreplace(function("sin", [x]), [(legacy_sinx, y)])),
    content="y",
  )
  assert_true(has(function("sin", [x]), legacy_sinx))
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
    content="x + sin(x + 1) + 1",
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
test "Subs equality and ordering use canonical variable semantics" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let a = subs_expr(x, x, int(0))
  let b = subs_expr(y, y, int(0))
  inspect((a == b).to_string(), content="true")
  inspect(compare_expr(a, b), content="0")
  let fxy = function("f", [x, y])
  let left = subs_expr(fxy, Expr::Tuple([x, y]), Expr::Tuple([int(0), int(1)]))
  let right = subs_expr(fxy, Expr::Tuple([y, x]), Expr::Tuple([int(1), int(0)]))
  inspect((left == right).to_string(), content="true")
  inspect(compare_expr(left, right), content="0")
  let nonbinding_left = subs_expr(x, y, int(0))
  let nonbinding_right = subs_expr(x, z, int(0))
  inspect((nonbinding_left == nonbinding_right).to_string(), content="false")
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
  let gy = applied_undefined_function("g", [y])
  inspect(
    @symprint.to_string(
      subst(derivative(function("f", [x, y]), y), { "y": gy }),
    ),
    content="Derivative(f(x, g(y)), g(y))",
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
test "derivative constructors and callable substitution follow SymPy source" {
  let x = Expr::Symbol("x")
  let gx = applied_undefined_function("g", [x])
  match function("Derivative", [function("sin", [x]), function("sin", [x])]) {
    Expr::Apply(Expr::FunctionHead("Derivative"), _) => ()
    other =>
      fail(
        "expected invalid derivative variable to stay canonical Apply, got \{@symprint.to_string(other)}",
      )
  }
  inspect(
    @symprint.to_string(
      subst(Expr::Derivative(gx, [gx, int(1)]), {
        "g": Expr::UndefinedFunction("f"),
      }),
    ),
    content="Derivative(f(x), f(x))",
  )
  let invalid = subst(Expr::Derivative(gx, [gx, int(1)]), {
    "g": Expr::FunctionHead("cos"),
  })
  match invalid {
    Expr::Subs(Expr::Derivative(inner, [wrt, order]), variable, value) => {
      inspect((inner == wrt).to_string(), content="true")
      inspect((variable == wrt).to_string(), content="true")
      inspect(@symprint.to_string(order), content="1")
      inspect(@symprint.to_string(value), content="cos(x)")
    }
    other =>
      fail(
        "expected invalid callable substitution to wrap derivative in Subs, got \{@symprint.to_string(other)}",
      )
  }
}

///|
test "lambda canonicalizes identity forms and applies canonically" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let id = lambda_expr(x, x)
  inspect(@symprint.to_string(id), content="Lambda(_x, _x)")
  inspect(
    @symprint.to_string(lambda_expr(Expr::Tuple([x]), x)),
    content="Lambda(_x, _x)",
  )
  inspect(
    @symprint.to_string(func(id).unwrap_or(int(0))),
    content="<class 'sympy.functions.elementary.miscellaneous.IdentityFunction'>",
  )
  json_inspect(args(id).map(@symprint.to_string), content=[])
  inspect(has(id, x), content="false")
  inspect(@symprint.to_string(xreplace(id, [(x, y)])), content="Lambda(_x, _x)")
  inspect(@symprint.to_string(subst(id, { "x": y })), content="Lambda(_x, _x)")
  inspect(@symprint.to_string(apply(id, [y]).unwrap_or(int(0))), content="y")
  inspect(
    @symprint.to_string(
      apply(lambda_expr(Expr::Tuple([x, y]), add([x, y])), [int(1), int(2)]).unwrap_or(
        int(0),
      ),
    ),
    content="3",
  )
  inspect(
    @symprint.to_string(
      apply(
        lambda_expr(Expr::Tuple([Expr::Tuple([x, y]), z]), add([x, y, z])),
        [Expr::Tuple([int(1), int(2)]), int(3)],
      ).unwrap_or(int(0)),
    ),
    content="6",
  )
  inspect(
    @symprint.to_string(
      lambda_expr(Expr::WildFunction("f", []), add([x, int(1)])),
    ),
    content="Lambda(f_, x + 1)",
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
