///|
test "add flattens and folds constants" {
  let expr = add([int(1), Symbol("x"), add([int(2), Symbol("y")])])
  inspect(Repr(expr), content="(+ sym:x sym:y 3)")
  inspect(
    @symprint.pretty_string(add([Symbol("x"), Symbol("x")])),
    content="2*x",
  )
}

///|
test "mul flattens and handles identities" {
  let expr = mul([Symbol("x"), int(1), mul([Symbol("y"), int(2)])])
  inspect(Repr(expr), content="(* 2 sym:x sym:y)")
  let zeroed = mul([Symbol("x"), int(0), Symbol("y")])
  inspect(Repr(zeroed), content="0")
}

///|
test "pow normalizes trivial exponents" {
  inspect(Repr(pow(Symbol("x"), int(1))), content="sym:x")
  inspect(Repr(pow(Symbol("x"), int(0))), content="1")
  inspect(Repr(pow(int(0), int(0))), content="1")
  inspect(@symprint.pretty_string(pow(int(0), Symbol("x"))), content="0**x")
  inspect(
    @symprint.pretty_string(pow(pow(Symbol("x"), int(2)), int(2))),
    content="x**4",
  )
}

///|
test "subst replaces symbols" {
  let env : Map[String, Expr] = { "x": int(2) }
  let expr = add([Symbol("x"), Symbol("y")])
  let replaced = subst(expr, env)
  inspect(Repr(replaced), content="(+ sym:y 2)")
}

///|
test "basic helpers expose structured heads" {
  let rel = Expr::Relational(Le, Symbol("x"), int(2))
  let tup = Expr::Tuple([Symbol("x"), int(2)])
  let deriv = derivative(
    function("f", [Symbol("x")]),
    Symbol("x"),
    order=int(2),
  )
  inspect(Repr(rel), content="(call Le sym:x 2)")
  inspect(Repr(tup), content="(call Tuple sym:x 2)")
  inspect(
    Repr(deriv),
    content="(call Derivative (call f sym:x) (call Tuple sym:x 2))",
  )
  inspect(is_true(Boolean(true)), content="true")
  inspect(is_false(Boolean(false)), content="true")
}

///|
test "free_symbols respects bound variables" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let lam = lambda_expr(Tuple([x, y]), add([x, z]))
  let deriv = derivative(function("f", [x, y]), x, order=y)
  let subs_multi = subs_expr(add([x, y]), Tuple([x, y]), Tuple([y, z]))
  json_inspect(free_symbols(lam).map(@symprint.pretty_string), content=["z"])
  json_inspect(free_symbols(deriv).map(@symprint.pretty_string), content=[
    "x", "y",
  ])
  json_inspect(free_symbols(subs_multi).map(@symprint.pretty_string), content=[
    "y", "z",
  ])
  inspect(has(lam, z), content="true")
  inspect(has(lam, y), content="true")
  json_inspect(
    free_symbols(lambda_expr(Tuple([]), int(42))).map(@symprint.pretty_string),
    content=[],
  )
  json_inspect(
    free_symbols(lambda_expr(Tuple([]), mul([x, y]))).map(
      @symprint.pretty_string,
    ),
    content=["x", "y"],
  )
  let subs_structural = subs_expr(x, x, int(0))
  inspect(has(subs_structural, x), content="true")
  json_inspect(free_symbols(subs_structural).map(@symprint.pretty_string), content=[])
  let subs_env : Map[String, Expr] = Map([])
  subs_env.set("x", y)
  inspect(has(subst(subs_expr(x, x, int(1)), subs_env), y), content="true")
}

///|
test "has sees callable heads in canonical applications" {
  let x = Expr::Symbol("x")
  assert_true(has(function("sin", [x]), FunctionHead("sin")))
  assert_true(has(applied_undefined_function("f", [x]), UndefinedFunction("f")))
  let dfx = derivative(applied_undefined_function("f", [x]), x)
  assert_true(has(dfx, FunctionHead("Derivative")))
  assert_true(has(pow(x, int(2)), FunctionHead("Symbol")))
  assert_false(has(pow(x, int(2)), FunctionHead("Wild")))
  assert_true(has(mul([int(2), Wild("p", [], [])]), FunctionHead("Wild")))
}

///|
test "has follows SymPy class-head and additive subset semantics" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")

  assert_true(has(int(1), FunctionHead("Integer")))
  assert_true(has(int(1), FunctionHead("Rational")))
  assert_true(has(rational_from_ints(1, 2), FunctionHead("Rational")))
  assert_false(has(rational_from_ints(1, 2), FunctionHead("Integer")))
  assert_true(has(NumberSymbol(Pi), FunctionHead("NumberSymbol")))
  assert_true(has(Dummy("d", 1), FunctionHead("Symbol")))
  assert_true(has(Wild("p", [], []), FunctionHead("Symbol")))
  assert_true(has(int(1), FunctionHead("Atom")))
  assert_true(has(int(1), FunctionHead("Expr")))
  assert_true(has(x, FunctionHead("AtomicExpr")))
  assert_true(has(function("sin", [x]), FunctionHead("Application")))
  assert_true(has(function("sin", [x]), FunctionHead("Function")))
  assert_true(has(add([x, y]), FunctionHead("Expr")))
  assert_true(has(mod_expr(x, int(2)), FunctionHead("Function")))
  assert_true(has(subs_expr(x, x, int(0)), FunctionHead("Expr")))
  assert_false(has(Tuple([Boolean(true)]), FunctionHead("Expr")))
  assert_false(
    has(Relational(Eq, Boolean(true), Boolean(false)), FunctionHead("Expr")),
  )
  assert_true(has(add([x, y, int(1)]), add([x, int(1)])))
  assert_false(has(add([x, y]), add([x, z])))
  assert_true(has(mul([x, y, z]), mul([x, y])))
  assert_false(has(mul([x, y]), mul([x, z])))
}

///|
test "plain symbol names no longer coerce to core singletons" {
  inspect(Repr(Expr::Symbol("pi")), content="sym:pi")
  inspect(Repr(Expr::Symbol("True")), content="sym:True")
  match number_symbol_kind(Symbol("pi")) {
    Some(_) => fail("plain symbol pi should not be a number symbol")
    None => ()
  }
  match bool_value(Symbol("True")) {
    Some(_) => fail("plain symbol True should not be a boolean atom")
    None => ()
  }
}

///|
test "number symbols are structured constants" {
  let pi_expr = Expr::NumberSymbol(Pi)
  let imag = Expr::NumberSymbol(ImaginaryUnit)
  let inf = Expr::NumberSymbol(Infinity)
  match expr_form(pi_expr) {
    NumberSymbol(Pi) => ()
    _ => fail("expected pi number symbol")
  }
  match expr_form(imag) {
    NumberSymbol(ImaginaryUnit) => ()
    _ => fail("expected I number symbol")
  }
  match expr_form(inf) {
    NumberSymbol(Infinity) => ()
    _ => fail("expected oo number symbol")
  }
  json_inspect(
    free_symbols(add([pi_expr, imag, Symbol("x")])).map(@symprint.pretty_string),
    content=["x"],
  )
  inspect(@symprint.pretty_string(mul([int(-1), inf])), content="-oo")
  inspect(@symprint.pretty_string(pow(int(1), int(-1))), content="1")
  inspect(
    @symprint.pretty_string(
      pow(int(16), rational_from_ints(1, 2) catch { _ => fail("half power") }),
    ),
    content="4",
  )
  inspect(@symprint.pretty_string(pow(imag, int(2))), content="-1")
  inspect(@symprint.pretty_string(pow(imag, int(3))), content="-I")
  inspect(@symprint.pretty_string(pow(imag, int(4))), content="1")
  inspect(@symprint.pretty_string(function("sqrt", [int(-1)])), content="I")
  inspect(@symprint.pretty_string(function("sqrt", [int(-4)])), content="2*I")
}

///|
test "dummy and wild are distinct structured symbols" {
  let d1 = dummy(name="x")
  let d2 = dummy(name="x")
  let w = Expr::Wild("x", [], [])
  assert_false(d1 == d2)
  inspect(@symprint.pretty_string(d1), content="_x")
  inspect(@symprint.pretty_string(w), content="x_")
  match expr_form(d1) {
    Dummy(name, _) => inspect(name, content="x")
    _ => fail("expected dummy expr form")
  }
  match expr_form(w) {
    Wild(name, _, _) => inspect(name, content="x")
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
  inspect(bool_value(Boolean(true)).unwrap_or(false), content="true")
  inspect(bool_value(Boolean(true)).unwrap_or(false), content="true")
  match number_symbol_kind(NumberSymbol(Pi)) {
    Some(Pi) => ()
    _ => fail("expected pi kind")
  }
  match number_symbol_kind(NumberSymbol(ImaginaryUnit)) {
    Some(ImaginaryUnit) => ()
    _ => fail("expected I kind")
  }
}

///|
test "free_symbols tracks dummy identity and bound dummy removal" {
  let d1 = dummy(name="x")
  let d2 = dummy(name="x")
  let expr = add([d1, d2])
  inspect(free_symbols(expr).length(), content="2")
  let lam = lambda_expr(Tuple([d1]), add([d1, d2, Symbol("y")]))
  let free = free_symbols(lam)
  inspect(free.length(), content="2")
  assert_true(free.contains(Symbol("y")))
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
    args(derivative(function("f", [x]), x)).map(@symprint.pretty_string),
    content=["f(x)", "(x, 1)"],
  )
  json_inspect(args(lambda_expr(x, add([x, y]))).map(@symprint.pretty_string), content=[
    "(x,)", "x + y",
  ])
  json_inspect(
    args(lambda_expr(Tuple([x, y]), add([x, y]))).map(@symprint.pretty_string),
    content=["(x, y)", "x + y"],
  )
}

///|
test "func and args expose canonical heads for containers and binders" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  inspect(
    @symprint.pretty_string(func(Tuple([x, y])).unwrap_or(int(0))),
    content="<class 'sympy.core.containers.Tuple'>",
  )
  inspect(
    @symprint.pretty_string(func(Dict([(x, y)])).unwrap_or(int(0))),
    content="<class 'sympy.core.containers.Dict'>",
  )
  inspect(
    @symprint.pretty_string(func(Relational(Eq, x, y)).unwrap_or(int(0))),
    content="<class 'sympy.core.relational.Equality'>",
  )
  inspect(
    @symprint.pretty_string(
      func(subs_expr(add([x, y]), x, int(1))).unwrap_or(int(0)),
    ),
    content="<class 'sympy.core.function.Subs'>",
  )
  let dict_args = args(Dict([(x, y), (int(1), x)])).map(@symprint.pretty_string)
  inspect(dict_args.length(), content="2")
  assert_true(dict_args.contains("(1, x)"))
  assert_true(dict_args.contains("(x, y)"))
  json_inspect(args(Relational(Eq, x, y)).map(@symprint.pretty_string), content=[
    "x", "y",
  ])
  json_inspect(
    args(subs_expr(add([x, y]), x, int(1))).map(@symprint.pretty_string),
    content=["x + y", "(x,)", "(1,)"],
  )
}

///|
test "func exposes canonical heads for atomic core nodes" {
  inspect(
    @symprint.pretty_string(func(int(2)).unwrap_or(int(0))),
    content="<class 'sympy.core.numbers.Integer'>",
  )
  inspect(
    @symprint.pretty_string(func(rational_from_ints(1, 2)).unwrap_or(int(0))),
    content="<class 'sympy.core.numbers.Half'>",
  )
  inspect(
    @symprint.pretty_string(func(NumberSymbol(Pi)).unwrap_or(int(0))),
    content="<class 'sympy.core.numbers.Pi'>",
  )
  inspect(
    @symprint.pretty_string(func(Symbol("x")).unwrap_or(int(0))),
    content="<class 'sympy.core.symbol.Symbol'>",
  )
  inspect(
    @symprint.pretty_string(func(dummy(name="x")).unwrap_or(int(0))),
    content="<class 'sympy.core.symbol.Dummy'>",
  )
  inspect(
    @symprint.pretty_string(func(Wild("x", [], [])).unwrap_or(int(0))),
    content="<class 'sympy.core.symbol.Wild'>",
  )
  inspect(
    @symprint.pretty_string(func(Boolean(true)).unwrap_or(int(0))),
    content="<class 'sympy.logic.boolalg.BooleanTrue'>",
  )
  inspect(
    @symprint.pretty_string(func(Boolean(false)).unwrap_or(int(0))),
    content="<class 'sympy.logic.boolalg.BooleanFalse'>",
  )
}

///|
test "undefined function heads are distinct from applied functions" {
  let f = Expr::UndefinedFunction("f")
  let sin_head = Expr::FunctionHead("sin")
  let fx = applied_undefined_function("f", [Symbol("x")])
  let sinx = function("sin", [Symbol("x")])
  match expr_form(f) {
    UndefinedFunction(name) => inspect(name, content="f")
    _ => fail("expected undefined function head")
  }
  match expr_form(sin_head) {
    FunctionHead(name) => inspect(name, content="sin")
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
      guard expr is Apply(FunctionHead("sin"), [Symbol("x")]) else {
        fail("expected first-class named application storage")
      }
      inspect(@symprint.pretty_string(expr), content="sin(x)")
      inspect(application_name(expr).unwrap_or(""), content="sin")
      inspect(application_args(expr).unwrap_or([]).length(), content="1")
      assert_true(application_has_name(expr, "sin", arity=1))
      match func(expr) {
        Some(head) => inspect(@symprint.pretty_string(head), content="sin")
        None => fail("expected application func")
      }
    }
    None => fail("expected named head application")
  }
  match apply(f_head, [x]) {
    Some(expr) =>
      match application_parts(expr) {
        Some((head, [arg])) => {
          inspect(@symprint.pretty_string(head), content="f")
          inspect(@symprint.pretty_string(arg), content="x")
          inspect(application_name(expr).unwrap_or(""), content="f")
          assert_true(application_has_name(expr, "f", arity=1))
        }
        _ => fail("expected application parts")
      }
    None => fail("expected undefined head application")
  }
  match apply(FunctionHead("Integer"), [rational_from_ints(5, 2)]) {
    Some(Number(n)) => inspect(Show::to_string(n), content="2")
    _ => fail("expected Integer constructor semantics through apply")
  }
  match apply(FunctionHead("Integer"), [rational_from_ints(-2, 3)]) {
    Some(Number(n)) => inspect(Show::to_string(n), content="0")
    _ => fail("expected Integer truncation through apply")
  }
  match apply(FunctionHead("Rational"), [int(2), int(3)]) {
    Some(Number(n)) => inspect(Show::to_string(n), content="2/3")
    _ => fail("expected Rational constructor semantics through apply")
  }
  match apply(FunctionHead("Rational"), [Float(Float::from_double(2.5))]) {
    Some(Number(n)) => inspect(Show::to_string(n), content="5/2")
    _ => fail("expected Rational(float) constructor semantics through apply")
  }
  match apply(FunctionHead("Float"), [int(2)]) {
    Some(Float(_)) => ()
    _ => fail("expected Float constructor semantics through apply")
  }
  match apply(FunctionHead("Float"), [int(2), int(20)]) {
    Some(Float(value)) =>
      inspect(
        value.precision().to_string(),
        content=@symnum.dps_to_prec(20).to_string(),
      )
    _ => fail("expected Float precision constructor semantics through apply")
  }
  match apply(FunctionHead("Float"), [Tuple([int(0), int(0), int(-123)])]) {
    Some(Number(n)) => inspect(Show::to_string(n), content="0")
    _ => fail("expected Float 3-tuple zero semantics through apply")
  }
  match
    apply(FunctionHead("Float"), [Tuple([int(0), int(0), int(-123), int(-1)])]) {
    Some(NumberSymbol(NaN)) => ()
    _ => fail("expected Float special tuple NaN semantics through apply")
  }
  match
    apply(FunctionHead("Float"), [Tuple([int(0), int(0), int(-456), int(-2)])]) {
    Some(NumberSymbol(Infinity)) => ()
    _ => fail("expected Float special tuple infinity semantics through apply")
  }
  match
    apply(FunctionHead("Float"), [Tuple([int(1), int(0), int(-789), int(-3)])]) {
    Some(NumberSymbol(NegativeInfinity)) => ()
    _ =>
      fail(
        "expected Float special tuple negative infinity semantics through apply",
      )
  }
  inspect(
    @symprint.pretty_string(
      function("Float", [Tuple([int(2), int(1), int(0)])]),
    ),
    content="Float((2, 1, 0))",
  )
  match apply(FunctionHead("Tuple"), [x, int(1)]) {
    Some(Tuple([Symbol("x"), Number(n)])) =>
      inspect(Show::to_string(n), content="1")
    _ => fail("expected Tuple constructor semantics through apply")
  }
  match apply(FunctionHead("S"), [add([x, x])]) {
    Some(expr) => inspect(@symprint.pretty_string(expr), content="2*x")
    _ => fail("expected S constructor semantics through apply")
  }
  match raw_apply(FunctionHead("S"), [function("sin", [x])]) {
    Some(expr) => inspect(@symprint.pretty_string(expr), content="sin(x)")
    _ => fail("expected S raw constructor semantics through apply")
  }
  match apply(FunctionHead("S"), [x, Symbol("y")]) {
    Some(expr) => inspect(@symprint.pretty_string(expr), content="x")
    _ => fail("expected multi-arg S to return first sympified argument")
  }
  match apply(FunctionHead("S"), []) {
    Some(Apply(FunctionHead("S"), [])) => ()
    _ => fail("expected unsupported S arity to stay canonical Apply")
  }
  assert_false(apply(Symbol("g"), [x]) is Some(_))
  assert_false(raw_apply(Symbol("g"), [x]) is Some(_))
  assert_false(apply(int(1), [x]) is Some(_))
  inspect(
    @symprint.pretty_string(func(Tuple([x])).unwrap_or(int(0))),
    content="<class 'sympy.core.containers.Tuple'>",
  )
}

///|
test "legacy function storage normalizes to canonical core semantics" {
  let x = Expr::Symbol("x")
  let legacy_named = Expr::Function("sin", [x])
  let canonical_named = function("sin", [x])
  inspect(@symprint.pretty_string(legacy_named), content="sin(x)")
  inspect(application_name(legacy_named).unwrap_or(""), content="sin")
  json_inspect(children(legacy_named).map(@symprint.pretty_string), content=[
    "x",
  ])
  inspect(compare_expr(legacy_named, canonical_named), content="0")
  inspect(
    Hash::hash(legacy_named).to_string(),
    content=Hash::hash(canonical_named).to_string(),
  )
  inspect(
    @symprint.pretty_string(evalf(Function("sin", [NumberSymbol(Pi)]))),
    content=@symprint.pretty_string(evalf(function("sin", [NumberSymbol(Pi)]))),
  )
  let legacy_derivative = Expr::Function("Derivative", [function("f", [x]), x])
  json_inspect(children(legacy_derivative).map(@symprint.pretty_string), content=[
    "f(x)", "(x, 1)",
  ])
  inspect(
    @symprint.pretty_string(xreplace(legacy_derivative, [(x, int(2))])),
    content="Derivative(f(2), 2)",
  )
  let nested_legacy = Expr::Add([
    Function("sin", [Function("Tuple", [x, int(1)])]),
    Function("Derivative", [function("f", [x]), x]),
  ])
  match normalize_legacy_expr(nested_legacy) {
    Add([lhs, rhs]) => {
      match application_parts(lhs) {
        Some((FunctionHead("sin"), [Tuple([Symbol("x"), one])])) =>
          inspect(@symprint.pretty_string(one), content="1")
        _ => fail("expected recursively normalized named application")
      }
      match derivative_parts(rhs) {
        Some((inner, [Symbol("x"), one])) => {
          inspect(@symprint.pretty_string(inner), content="f(x)")
          inspect(@symprint.pretty_string(one), content="1")
        }
        _ => fail("expected recursively normalized derivative")
      }
    }
    _ => fail("expected recursively normalized Add")
  }
  match function("Dict", [x]) {
    Apply(FunctionHead("Dict"), [Symbol("x")]) => ()
    _ => fail("expected malformed Dict to canonicalize as Apply")
  }
  match
    normalize_legacy_expr(
      Function("Lambda", [Tuple([x, int(2)]), add([x, int(1)])]),
    ) {
    Apply(FunctionHead("Lambda"), [Tuple([Symbol("x"), two]), body]) => {
      inspect(@symprint.pretty_string(two), content="2")
      inspect(@symprint.pretty_string(body), content="x + 1")
    }
    _ => fail("expected invalid legacy Lambda to canonicalize as Apply")
  }
  inspect(
    @symprint.pretty_string(normalize_legacy_expr(Lambda(x, x))),
    content="Lambda(_x, _x)",
  )
  inspect(
    @symprint.pretty_string(normalize_legacy_expr(Derivative(x, [x]))),
    content="Derivative(x, x)",
  )
  inspect(
    @symprint.pretty_string(
      normalize_legacy_expr(Derivative(x, [x, Symbol("n")])),
    ),
    content="Derivative(x, (x, n))",
  )
}

///|
test "application constructors canonicalize legacy children eagerly" {
  let x = Expr::Symbol("x")
  let legacy_derivative = Expr::Function("Derivative", [x, x])
  match function("sin", [legacy_derivative]) {
    Apply(FunctionHead("sin"), [Derivative(_, [_, one])]) =>
      inspect(@symprint.pretty_string(one), content="1")
    _ => fail("expected canonical named application child")
  }
  match apply(FunctionHead("sin"), [legacy_derivative]) {
    Some(Apply(FunctionHead("sin"), [Derivative(_, [_, one])])) =>
      inspect(@symprint.pretty_string(one), content="1")
    _ => fail("expected apply() to canonicalize legacy child")
  }
  match applied_undefined_function("f", [legacy_derivative]) {
    Apply(UndefinedFunction("f"), [Derivative(_, [_, one])]) =>
      inspect(@symprint.pretty_string(one), content="1")
    _ => fail("expected undefined application child normalization")
  }
}

///|
test "function constructors follow SymPy core semantics" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  inspect(@symprint.pretty_string(function("Eq", [x, x])), content="True")
  inspect(@symprint.pretty_string(function("Ne", [x, x])), content="False")
  inspect(
    @symprint.pretty_string(function("Lt", [int(1), int(2)])),
    content="True",
  )
  inspect(
    @symprint.pretty_string(function("Ge", [int(1), int(2)])),
    content="False",
  )
  inspect(
    @symprint.pretty_string(
      function("Derivative", [function("sin", [x]), x, int(2)]),
    ),
    content="Derivative(sin(x), (x, 2))",
  )
  inspect(
    @symprint.pretty_string(
      function("Derivative", [function("sin", [x]), x, y]),
    ),
    content="Derivative(sin(x), x, y)",
  )
  inspect(
    @symprint.pretty_string(
      function("Derivative", [function("sin", [x]), Tuple([x, int(0)])]),
    ),
    content="sin(x)",
  )
  inspect(
    @symprint.pretty_string(
      function("Derivative", [function("sin", [x]), x, y, int(2)]),
    ),
    content="Derivative(sin(x), x, (y, 2))",
  )
  inspect(
    @symprint.pretty_string(
      function("Subs", [add([x, y]), Tuple([x, y]), Symbol("z")]),
    ),
    content="Subs(x + y, (x, y), z)",
  )
  inspect(
    @symprint.pretty_string(
      function("Integer", [raw_mul([int(3), raw_pow(int(2), int(-1))])]),
    ),
    content="1",
  )
  inspect(
    @symprint.pretty_string(function("Integer", [NumberSymbol(Pi)])),
    content="3",
  )
  inspect(
    @symprint.pretty_string(
      function("Integer", [Float(Float::from_double(0.9))]),
    ),
    content="0",
  )
  inspect(
    @symprint.pretty_string(
      function("Integer", [Float(Float::from_double(10.5))]),
    ),
    content="10",
  )
  inspect(
    @symprint.pretty_string(
      function("Integer", [Float(Float::from_double(-3.8))]),
    ),
    content="-3",
  )
  inspect(
    @symprint.pretty_string(function("Integer", [Boolean(true)])),
    content="1",
  )
  inspect(
    @symprint.pretty_string(function("Integer", [Boolean(false)])),
    content="0",
  )
  inspect(
    @symprint.pretty_string(
      function("Rational", [raw_mul([int(3), raw_pow(int(2), int(-1))])]),
    ),
    content="3/2",
  )
  match
    with_evaluate(false, fn() {
      function("Rational", [raw_mul([int(3), raw_pow(int(2), int(-1))])])
    }) {
    Apply(FunctionHead("Rational"), [_]) => ()
    other =>
      fail(
        "expected evaluate=false Rational raw expression to stay unevaluated, got \{@symprint.pretty_string(other)}",
      )
  }
  match function("Float", [NumberSymbol(Pi)]) {
    Float(_) => ()
    other =>
      fail(
        "expected Float(pi) to evaluate, got \{@symprint.pretty_string(other)}",
      )
  }
  inspect(
    @symprint.pretty_string(function("Rational", [Boolean(true)])),
    content="1",
  )
  inspect(
    @symprint.pretty_string(function("Rational", [Boolean(false)])),
    content="0",
  )
  inspect(
    @symprint.pretty_string(function("Rational", [int(1), Boolean(false)])),
    content="zoo",
  )
  inspect(
    @symprint.pretty_string(
      function("Rational", [Boolean(false), Boolean(false)]),
    ),
    content="nan",
  )
  inspect(
    @symprint.pretty_string(
      function("Rational", [Float(Float::from_double(1.0)), int(3)]),
    ),
    content="1/3",
  )
  inspect(
    @symprint.pretty_string(
      function("Rational", [int(1), Float(Float::from_double(3.0))]),
    ),
    content="1/3",
  )
  inspect(
    @symprint.pretty_string(
      function("Rational", [rational_from_ints(1, 2), rational_from_ints(1, 3)]),
    ),
    content="3/2",
  )
  inspect(
    @symprint.pretty_string(
      function("Rational", [int(1), rational_from_ints(1, 3)]),
    ),
    content="3",
  )
  inspect(
    @symprint.pretty_string(function("S", [Boolean(true)])),
    content="True",
  )
  inspect(
    @symprint.pretty_string(function("S", [Boolean(false)])),
    content="False",
  )
}

///|
test "invalid Subs signatures stay as canonical applications" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  inspect(
    @symprint.pretty_string(subs_expr(add([x, y]), Tuple([x, y]), z)),
    content="Subs(x + y, (x, y), z)",
  )
  inspect(
    @symprint.pretty_string(
      normalize_legacy_expr(Subs(add([x, y]), Tuple([x, y]), z)),
    ),
    content="Subs(x + y, (x, y), z)",
  )
  match subs_expr(add([x, y]), Tuple([x, y]), z) {
    Apply(FunctionHead("Subs"), _) => ()
    _ => fail("expected invalid Subs signature to remain an application")
  }
  inspect(
    @symprint.pretty_string(subs_expr(add([x, y]), Tuple([]), Tuple([]))),
    content="x + y",
  )
  inspect(
    @symprint.pretty_string(subs_expr(subs_expr(x, x, int(0)), y, int(1))),
    content="Subs(x, (x, y), (0, 1))",
  )
  inspect(
    subs_signature_error(Tuple([x, x]), Tuple([int(0), int(1)])).unwrap_or(""),
    content="The following expressions appear more than once: x",
  )
}

///|
test "dict is a first-class container node" {
  let d = Expr::Dict([(Symbol("x"), Symbol("y")), (int(1), Symbol("z"))])
  match expr_form(d) {
    Dict(items) => inspect(items.length(), content="2")
    _ => fail("expected dict form")
  }
  inspect(args(d).length(), content="2")
  match dict_items(d) {
    Some(items) => {
      let (_, value) = items[1]
      inspect(@symprint.pretty_string(value), content="z")
    }
    None => fail("expected dict items")
  }
  json_inspect(free_symbols(d).map(@symprint.pretty_string), content=[
    "x", "y", "z",
  ])
}

///|
test "sympify lifts typed tuple and dict inputs" {
  let expr = sympify_tuple([FromInt(1), SymbolName("x"), FromBool(true)])
  inspect(@symprint.pretty_string(expr), content="(1, x, True)")
  let dict_value = sympify_dict([
    (SymbolName("x"), FromInt(2)),
    (SymbolName("y"), FromExpr(UndefinedFunction("f"))),
  ])
  inspect(@symprint.pretty_string(dict_value), content="{x: 2, y: f}")
  inspect(
    @symprint.pretty_string(
      sympify(Application(FunctionHeadName("sin"), [SymbolName("x")])),
    ),
    content="sin(x)",
  )
  inspect(
    @symprint.pretty_string(
      sympify(
        Application(UndefinedFunctionName("f"), [DummyName("x"), WildName("y")]),
      ),
    ),
    content="f(_x, y_)",
  )
  match sympify(FromExpr(Function("sin", [Symbol("x")]))) {
    Apply(FunctionHead("sin"), [Symbol("x")]) => ()
    _ => fail("expected sympify FromExpr to canonicalize named application")
  }
  match sympify(FromExpr(Function("Derivative", [Symbol("x"), Symbol("x")]))) {
    Derivative(Symbol("x"), [Symbol("x"), one]) =>
      inspect(@symprint.pretty_string(one), content="1")
    _ => fail("expected sympify FromExpr to canonicalize derivative")
  }
}

///|
test "atoms collects unique atomic leaves in canonical order" {
  let expr = add([
    function("f", [Symbol("x")]),
    mul([int(2), Symbol("x")]),
    Tuple([Symbol("y"), int(1)]),
  ])
  json_inspect(atoms(expr).map(@symprint.pretty_string), content=[
    "x", "y", "1", "2",
  ])
}

///|
test "preorder and postorder traversal stay structural" {
  let x = Expr::Symbol("x")
  let expr = add([derivative(function("f", [x]), x), mod_expr(x, int(2))])
  json_inspect(preorder(expr).map(@symprint.pretty_string), content=[
    "Derivative(f(x), x) + Mod(x, 2)", "Derivative(f(x), x)", "f(x)", "x", "(x, 1)",
    "x", "1", "Mod(x, 2)", "x", "2",
  ])
  json_inspect(postorder(expr).map(@symprint.pretty_string), content=[
    "x", "f(x)", "x", "1", "(x, 1)", "Derivative(f(x), x)", "x", "2", "Mod(x, 2)",
    "Derivative(f(x), x) + Mod(x, 2)",
  ])
}

///|
test "preorder and postorder canonicalize legacy roots before traversal" {
  let x = Expr::Symbol("x")
  let legacy = Expr::Function("sin", [x])
  json_inspect(preorder(legacy).map(@symprint.pretty_string), content=[
    "sin(x)", "x",
  ])
  json_inspect(postorder(legacy).map(@symprint.pretty_string), content=[
    "x", "sin(x)",
  ])
}

///|
test "children wrap Subs and Lambda binders like SymPy args" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  json_inspect(
    children(subs_expr(add([x, y]), x, int(1))).map(@symprint.pretty_string),
    content=["x + y", "(x,)", "(1,)"],
  )
  json_inspect(
    args(subs_expr(add([x, y]), Tuple([x, y]), Tuple([y, int(1)]))).map(
      @symprint.pretty_string,
    ),
    content=["x + y", "(x, y)", "(y, 1)"],
  )
  json_inspect(
    children(lambda_expr(x, add([x, y]))).map(@symprint.pretty_string),
    content=["(x,)", "x + y"],
  )
}

///|
test "xreplace performs exact structural replacement" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let fx = function("f", [x])
  let expr = add([fx, x, y])
  let replaced = xreplace(expr, [(x, int(2)), (fx, Symbol("z"))])
  inspect(Repr(replaced), content="(+ sym:y sym:z 2)")
  inspect(
    Repr(xreplace(function("f", [x]), [(x, int(2))])),
    content="(call f 2)",
  )
  inspect(
    @symprint.pretty_string(
      xreplace(derivative(add([function("sin", [x]), y]), x), [(y, Symbol("z"))]),
    ),
    content="Derivative(z + sin(x), x)",
  )
  inspect(
    @symprint.pretty_string(
      xreplace(derivative(add([function("sin", [x]), y]), x), [(x, Symbol("z"))]),
    ),
    content="Derivative(y + sin(z), z)",
  )
  let legacy_sinx = Expr::Function("sin", [x])
  inspect(
    @symprint.pretty_string(xreplace(function("sin", [x]), [(legacy_sinx, y)])),
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
  inspect(@symprint.pretty_string(rewritten), content="cos(x) + cos(y)")
  inspect(
    @symprint.pretty_string(
      replace(
        add([x, function("sin", [x])]),
        fn(node : Expr) -> Bool { node == x },
        fn(_node : Expr) -> Expr { add([x, int(1)]) },
      ),
    ),
    content="x + sin(x + 1) + 1",
  )
  inspect(
    @symprint.pretty_string(
      replace(
        Function("sin", [x]),
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
    @symprint.pretty_string(
      evalf(applied_undefined_function("f", [NumberSymbol(Pi)])),
    ),
    content="f(pi)",
  )
  inspect(
    @symprint.pretty_string(evalf(mod_expr(NumberSymbol(Pi), int(2)))).has_prefix(
      "1.14159265358979",
    ),
    content="true",
  )
}

///|
test "compare_expr follows function symbol and mod ordering" {
  let exprs : Array[Expr] = [
    Symbol("x"),
    NumberSymbol(Pi),
    applied_undefined_function("f", [Symbol("x")]),
    UndefinedFunction("f"),
    dummy(name="x"),
    mod_expr(Symbol("x"), int(2)),
  ]
  sort_exprs_in_place(exprs)
  json_inspect(exprs.map(@symprint.pretty_string), content=[
    "f", "_x", "pi", "x", "f(x)", "Mod(x, 2)",
  ])
}

///|
test "mod is a first-class structured core node" {
  let expr = mod_expr(add([Symbol("x"), int(1)]), int(3))
  inspect(head_name(expr), content="Mod")
  json_inspect(args(expr).map(@symprint.pretty_string), content=["x + 1", "3"])
  inspect(Repr(expr), content="(call Mod (+ sym:x 1) 3)")
}

///|
test "subst respects lambda bound variables" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let expr = lambda_expr(x, add([x, y]))
  let env : Map[String, Expr] = { "x": int(2), "y": int(3) }
  inspect(@symprint.pretty_string(subst(expr, env)), content="Lambda(x, x + 3)")
  let rename_env : Map[String, Expr] = { "x": z, "y": int(3) }
  inspect(
    @symprint.pretty_string(subst(expr, rename_env)),
    content="Lambda(z, z + 3)",
  )
  let capture_env : Map[String, Expr] = { "x": y }
  inspect(
    @symprint.pretty_string(subst(expr, capture_env)),
    content="Lambda(y, 2*y)",
  )
  let tuple_expr = lambda_expr(Tuple([x, y]), add([x, y]))
  inspect(
    @symprint.pretty_string(subst(tuple_expr, { "y": z })),
    content="Lambda((x, z), x + z)",
  )
  inspect(
    @symprint.pretty_string(subst(tuple_expr, { "x": z })),
    content="Lambda((z, y), y + z)",
  )
  inspect(
    @symprint.pretty_string(subst(tuple_expr, { "y": x })),
    content="Lambda((x, y), x + y)",
  )
  inspect(
    @symprint.pretty_string(subst(tuple_expr, { "x": y })),
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
  inspect(
    @symprint.pretty_string(subst(expr, env)),
    content="Subs(x + 3, x, 4)",
  )
  let multi = subs_expr(add([x, y]), Tuple([x, y]), Tuple([y, z]))
  inspect(
    @symprint.pretty_string(subst(multi, { "y": w })),
    content="Subs(w + x, (x, w), (w, z))",
  )
  inspect(
    @symprint.pretty_string(subst(multi, { "x": w })),
    content="Subs(w + y, (w, y), (y, z))",
  )
  inspect(
    @symprint.pretty_string(subst(multi, { "y": x })),
    content="Subs(x + y, (x, y), (y, z))",
  )
  inspect(
    @symprint.pretty_string(subst(multi, { "x": y })),
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
  let left = subs_expr(fxy, Tuple([x, y]), Tuple([int(0), int(1)]))
  let right = subs_expr(fxy, Tuple([y, x]), Tuple([int(1), int(0)]))
  inspect((left == right).to_string(), content="true")
  inspect(compare_expr(left, right), content="0")
  let nonbinding_left = subs_expr(x, y, int(0))
  let nonbinding_right = subs_expr(x, z, int(0))
  inspect((nonbinding_left == nonbinding_right).to_string(), content="false")
}

///|
test "mul does not merge a dummy with its square" {
  let y = dummy(name="y")
  let y2 = pow(y, int(2))
  inspect(compare_expr(y2, y), content="-1")
  inspect(compare_expr(y, y2), content="1")
  let product = mul([y2, y])
  let sample = evalf(xreplace(product, [(y, int(2))]), prec=80)
  inspect(@symprint.pretty_string(sample), content="8.0")
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
    @symprint.pretty_string(subst(simple, rename_env)),
    content="Derivative(f(z), z)",
  )
  let invalid_env : Map[String, Expr] = { "x": int(2) }
  inspect(
    @symprint.pretty_string(subst(with_free, invalid_env)),
    content="Subs(Derivative(y + f(x), x), x, 2)",
  )
  let safe_inner_env : Map[String, Expr] = { "y": int(3) }
  inspect(
    @symprint.pretty_string(subst(with_free, safe_inner_env)),
    content="Derivative(f(x) + 3, x)",
  )
  let capture_env : Map[String, Expr] = { "y": x }
  inspect(
    @symprint.pretty_string(subst(with_free, capture_env)),
    content="Subs(Derivative(y + f(x), x), y, x)",
  )
  let mixed = Expr::Derivative(add([function("sin", [x]), y]), [
    x,
    int(1),
    y,
    int(1),
  ])
  inspect(
    @symprint.pretty_string(subst(mixed, { "y": z })),
    content="Derivative(z + sin(x), x, z)",
  )
  inspect(
    @symprint.pretty_string(subst(mixed, { "x": z })),
    content="Derivative(y + sin(z), z, y)",
  )
  let gy = applied_undefined_function("g", [y])
  inspect(
    @symprint.pretty_string(
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
  let sin_env : Map[String, Expr] = { "sin": FunctionHead("cos") }
  inspect(@symprint.pretty_string(subst(sinx, sin_env)), content="cos(x)")
  let f_env : Map[String, Expr] = { "f": UndefinedFunction("g") }
  inspect(@symprint.pretty_string(subst(fx, f_env)), content="g(x)")
  let non_callable_env : Map[String, Expr] = { "f": Symbol("z") }
  inspect(@symprint.pretty_string(subst(fx, non_callable_env)), content="f(x)")
}

///|
test "subst beta-reduces callable heads to lambda replacements" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  inspect(
    @symprint.pretty_string(
      subst(function("sin", [x]), { "sin": lambda_expr(x, add([x, int(1)])) }),
    ),
    content="x + 1",
  )
  inspect(
    @symprint.pretty_string(
      subst(applied_undefined_function("f", [x, y]), {
        "f": lambda_expr(Tuple([x, y]), add([x, y])),
      }),
    ),
    content="x + y",
  )
  inspect(
    @symprint.pretty_string(
      subst(function("sin", [x]), {
        "sin": lambda_expr(Tuple([x, y]), add([x, y])),
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
    Apply(FunctionHead("Derivative"), _) => ()
    other =>
      fail(
        "expected invalid derivative variable to stay canonical Apply, got \{@symprint.pretty_string(other)}",
      )
  }
  inspect(
    @symprint.pretty_string(
      subst(Derivative(gx, [gx, int(1)]), { "g": UndefinedFunction("f") }),
    ),
    content="Derivative(f(x), f(x))",
  )
  let invalid = subst(Derivative(gx, [gx, int(1)]), { "g": FunctionHead("cos") })
  match invalid {
    Subs(Derivative(inner, [wrt, order]), variable, value) => {
      inspect((inner == wrt).to_string(), content="true")
      inspect((variable == wrt).to_string(), content="true")
      inspect(@symprint.pretty_string(order), content="1")
      inspect(@symprint.pretty_string(value), content="cos(x)")
    }
    other =>
      fail(
        "expected invalid callable substitution to wrap derivative in Subs, got \{@symprint.pretty_string(other)}",
      )
  }
}

///|
test "lambda canonicalizes identity forms and applies canonically" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let z = Expr::Symbol("z")
  let id = lambda_expr(x, x)
  inspect(@symprint.pretty_string(id), content="Lambda(_x, _x)")
  inspect(
    @symprint.pretty_string(lambda_expr(Tuple([x]), x)),
    content="Lambda(_x, _x)",
  )
  inspect(
    @symprint.pretty_string(func(id).unwrap_or(int(0))),
    content="<class 'sympy.functions.elementary.miscellaneous.IdentityFunction'>",
  )
  json_inspect(args(id).map(@symprint.pretty_string), content=[])
  inspect(has(id, x), content="false")
  inspect(
    @symprint.pretty_string(xreplace(id, [(x, y)])),
    content="Lambda(_x, _x)",
  )
  inspect(
    @symprint.pretty_string(subst(id, { "x": y })),
    content="Lambda(_x, _x)",
  )
  inspect(
    @symprint.pretty_string(apply(id, [y]).unwrap_or(int(0))),
    content="y",
  )
  inspect(
    @symprint.pretty_string(
      apply(lambda_expr(Tuple([x, y]), add([x, y])), [int(1), int(2)]).unwrap_or(
        int(0),
      ),
    ),
    content="3",
  )
  inspect(
    @symprint.pretty_string(
      apply(lambda_expr(Tuple([Tuple([x, y]), z]), add([x, y, z])), [
        Tuple([int(1), int(2)]),
        int(3),
      ]).unwrap_or(int(0)),
    ),
    content="6",
  )
  inspect(
    @symprint.pretty_string(
      lambda_expr(WildFunction("f", []), add([x, int(1)])),
    ),
    content="Lambda(f_, x + 1)",
  )
}

///|
test "numeric singleton predicates stay aligned with structured core atoms" {
  assert_true(is_number_symbol(NumberSymbol(Pi)))
  assert_true(is_number_symbol(NumberSymbol(ImaginaryUnit)))
  assert_true(is_number_symbol(NumberSymbol(Infinity)))
  assert_true(is_number_symbol(NumberSymbol(NaN)))
  assert_true(is_infinite(NumberSymbol(Infinity)))
  assert_true(is_infinite(NumberSymbol(NegativeInfinity)))
  assert_true(is_infinite(NumberSymbol(ComplexInfinity)))
  assert_false(is_infinite(NumberSymbol(Pi)))
  assert_true(is_nan(NumberSymbol(NaN)))
  assert_false(is_nan(NumberSymbol(Pi)))
  assert_true(is_zero(int(0)))
  assert_true(is_zero(Float(Float::from_int(0))))
  assert_true(is_one(int(1)))
  assert_true(is_one(Float(Float::from_int(1))))
  assert_true(is_finite_number_atom(NumberSymbol(Pi)))
  assert_false(is_finite_number_atom(NumberSymbol(Infinity)))
  assert_false(is_finite_number_atom(NumberSymbol(NaN)))
}
