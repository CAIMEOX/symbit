///|
fn parse_repr(src : String) -> String raise {
  @symprint.debug_repr(parse_expr(src))
}

///|
fn relaxed_options(evaluate? : Bool = true) -> ParseOptions {
  parse_options(transformations=relaxed_transformations(), evaluate~)
}

///|
fn split_options() -> ParseOptions {
  parse_options(
    transformations=[
      ..standard_transformations(),
      Transformation::SplitSymbols,
      Transformation::ImplicitMultiplication,
    ],
  )
}

///|
fn split_custom_options() -> ParseOptions {
  let can_split = fn(symbol : String) -> Bool {
    symbol != "unsplittable" &&
    symbol != "names" &&
    default_split_symbol_predicate(symbol)
  }
  parse_options(
    transformations=[
      ..standard_transformations(),
      Transformation::SplitSymbolsCustom(can_split),
      Transformation::ImplicitMultiplication,
    ],
  )
}

///|
fn parse_relaxed_repr(src : String) -> String raise {
  @symprint.debug_repr(parse_expr_with(src, relaxed_options()))
}

///|
fn parse_repr_with(
  src : String,
  options : ParseOptions,
  context : ParseContext,
) -> String raise {
  @symprint.debug_repr(parse_expr_in(src, options, context))
}

///|
fn local_context() -> ParseContext {
  parse_context(callable_names=["f", "sin"], bindings={
    "a": @symcore.Expr::Symbol("z"),
    "n": @symcore.int(2),
    "sin": @symcore.Expr::Symbol("g"),
  })
}

///|
fn global_context() -> ParseContext {
  parse_context(global_callable_names=["f", "sin"], global_bindings={
    "a": @symcore.Expr::Symbol("t"),
    "f": @symcore.Expr::Symbol("g"),
    "sin": @symcore.Expr::Symbol("g"),
  })
}

///|
fn structured_callable_context() -> ParseContext {
  parse_context(callable_names=["f", "sin", "g"], bindings={
    "f": @symcore.Expr::UndefinedFunction("g"),
    "sin": @symcore.Expr::FunctionHead("cos"),
    "g": @symcore.Expr::FunctionHead("exp"),
  })
}

///|
test "symparse arithmetic precedence" {
  inspect(parse_repr("x + 2*y"), content="(+ (* 2 sym:y) sym:x)")
  inspect(parse_repr("2**3**2"), content="(^ 2 (^ 3 2))")
  inspect(parse_repr("-x**2"), content="(* -1 (^ sym:x 2))")
  inspect(parse_repr("(x + 1) / y"), content="(* (^ sym:y -1) (+ sym:x 1))")
}

///|
test "symparse function calls tuples and lambda on standard parser" {
  inspect(parse_repr("f(x, y + 1)"), content="(call f sym:x (+ sym:y 1))")
  inspect(parse_repr("(x, y + 1)"), content="(call Tuple sym:x (+ sym:y 1))")
  inspect(parse_repr("g()"), content="(call g)")
  inspect(
    parse_repr("lambda x: x + 1"),
    content="(call Lambda sym:x (+ sym:x 1))",
  )
  inspect(
    parse_repr("lambda x, y: x + y"),
    content="(call Lambda (call Tuple sym:x sym:y) (+ sym:x sym:y))",
  )
}

///|
test "symparse comparisons lower to symbolic heads" {
  inspect(parse_repr("x < y"), content="(call Lt sym:x sym:y)")
  inspect(parse_repr("x == x"), content="sym:True")
  inspect(parse_repr("x == y"), content="sym:False")
  inspect(parse_repr("x != x"), content="sym:False")
  inspect(parse_repr("x != y"), content="sym:True")
}

///|
test "symparse evaluate false preserves raw operators" {
  let options = parse_options(evaluate=false)
  inspect(
    @symprint.debug_repr(parse_expr_with("1 + 2 + x", options)),
    content="(+ 1 2 sym:x)",
  )
  inspect(
    @symprint.debug_repr(parse_expr_with("a*b*c", options)),
    content="(* sym:a sym:b sym:c)",
  )
  inspect(
    @symprint.debug_repr(parse_expr_with("x/y/z", options)),
    content="(* sym:x (^ sym:y -1) (^ sym:z -1))",
  )
  inspect(
    @symprint.debug_repr(parse_expr_with("x-y-z", options)),
    content="(+ sym:x (* -1 sym:y) (* -1 sym:z))",
  )
  inspect(
    @symprint.debug_repr(parse_expr_with("x==x", options)),
    content="(call Eq sym:x sym:x)",
  )
}

///|
test "symparse lexer exposes typed tokens" {
  let tokens = lex("lambda x: f(x!!, 2e-3 != y)")
  json_inspect(tokens.map(tok => token_kind_name(tok.kind)), content=[
    "identifier", "identifier", "`:`", "identifier", "`(`", "identifier", "`!!`",
    "`,`", "decimal", "`!=`", "identifier", "`)`", "end of input",
  ])
}

///|
test "symparse standard parser matches sympy defaults" {
  inspect(parse_repr("sin"), content="fhead:sin")
  inspect(parse_repr("pi"), content="const:pi")
  inspect(parse_repr("EulerGamma"), content="const:EulerGamma")
  inspect(parse_repr("oo"), content="const:oo")
  inspect(parse_repr("Pi"), content="sym:Pi")
  inspect(parse_repr("NaN"), content="sym:NaN")
  inspect(parse_repr("f"), content="sym:f")
  inspect(parse_repr("f(x)"), content="(call f sym:x)")
  match parse_expr("sin(x)") {
    @symcore.Expr::Apply(
      @symcore.Expr::FunctionHead("sin"),
      [@symcore.Expr::Symbol("x")]
    ) => ()
    _ => fail("expected first-class named application from parser")
  }
  inspect(parse_repr("x!"), content="(call factorial sym:x)")
  let dec = parse_expr("0.1")
  guard @symcore.expr_form(dec) is @symcore.ExprForm::Float(_) else {
    fail("expected decimal literal to lower to Float")
  }
  let rep = parse_expr("0.2[1]")
  guard @symcore.expr_form(rep) is @symcore.ExprForm::Number(n) else {
    fail("expected repeated decimal to lower to exact rational")
  }
  assert_eq(n.to_string(), "19/90")
}

///|
test "symparse standard parser rejects relaxed syntax" {
  let implicit_mul : Result[@symcore.Expr, ParseError] = try? parse_expr("2x")
  guard implicit_mul is Err(_) else { fail("expected 2x to fail by default") }
  let implicit_app : Result[@symcore.Expr, ParseError] = try? parse_expr(
    "sin x",
  )
  guard implicit_app is Err(_) else {
    fail("expected implicit application to fail")
  }
  let equals_expr : Result[@symcore.Expr, ParseError] = try? parse_expr("x = y")
  guard equals_expr is Err(_) else { fail("expected single equals to fail") }
  let caret_expr : Result[@symcore.Expr, ParseError] = try? parse_expr("x^2")
  guard caret_expr is Err(_) else {
    fail("expected caret to fail without convert_xor")
  }
}

///|
test "symparse relaxed parser handles transformed syntax" {
  inspect(parse_relaxed_repr("2x"), content="(* 2 sym:x)")
  inspect(parse_relaxed_repr("x(y + 1)"), content="(* sym:x (+ sym:y 1))")
  inspect(parse_relaxed_repr("2sin(x)"), content="(* 2 (call sin sym:x))")
  inspect(parse_relaxed_repr("sin**2(x)"), content="(^ (call sin sym:x) 2)")
  inspect(parse_relaxed_repr("sin**2 x"), content="(^ (call sin sym:x) 2)")
  inspect(parse_relaxed_repr("sin x"), content="(call sin sym:x)")
  inspect(parse_relaxed_repr("x!"), content="(call factorial sym:x)")
  inspect(parse_relaxed_repr("x!!"), content="(call factorial2 sym:x)")
  inspect(parse_relaxed_repr("x = y"), content="(call Eq sym:x sym:y)")
}

///|
test "symparse split symbols and split_symbols_custom" {
  inspect(
    @symprint.debug_repr(parse_expr_with("xy", split_options())),
    content="(* sym:x sym:y)",
  )
  inspect(
    @symprint.debug_repr(parse_expr_with("theta", split_options())),
    content="sym:theta",
  )
  inspect(
    parse_repr_with(
      "af(x + 1)",
      split_options(),
      parse_context(callable_names=["f"]),
    ),
    content="(* sym:a (call f (+ sym:x 1)))",
  )
  inspect(
    @symprint.debug_repr(
      parse_expr_with("unsplittable", split_custom_options()),
    ),
    content="sym:unsplittable",
  )
  inspect(
    @symprint.debug_repr(parse_expr_with("xy", split_custom_options())),
    content="(* sym:x sym:y)",
  )
}

///|
test "symparse relation chains follow python truthiness at evaluate=true" {
  let symbolic_chain : Result[@symcore.Expr, ParseError] = try? parse_expr(
    "x < y < z",
  )
  guard symbolic_chain is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "cannot determine truth value of Relational" else {
    fail("expected chained symbolic relation to raise truth-value error")
  }
  inspect(parse_repr("1 < 2 <= 3"), content="sym:True")
  inspect(parse_repr("1 == 1 < x"), content="(call Lt 1 sym:x)")
  inspect(parse_repr("1 == 2 < x"), content="sym:False")
}

///|
test "symparse callable context and structured bindings" {
  inspect(
    parse_repr_with("f", default_parse_options(), local_context()),
    content="ufunc:f",
  )
  inspect(
    parse_repr_with("f(x)", default_parse_options(), local_context()),
    content="(call f sym:x)",
  )
  inspect(
    parse_repr_with(
      "f(x)",
      default_parse_options(),
      structured_callable_context(),
    ),
    content="(call g sym:x)",
  )
  inspect(
    parse_repr_with(
      "sin(x)",
      default_parse_options(),
      structured_callable_context(),
    ),
    content="(call cos sym:x)",
  )
  inspect(
    parse_repr_with(
      "f(x)",
      default_parse_options(),
      parse_context(callable_names=["f"], bindings={
        "f": @symcore.Expr::Symbol("g"),
      }),
    ),
    content="(call g sym:x)",
  )
  inspect(
    parse_repr_with("a + b", default_parse_options(), global_context()),
    content="(+ sym:b sym:t)",
  )
  let symbol_bound_call : Result[@symcore.Expr, ParseError] = try? parse_expr_in(
    "f(x)",
    default_parse_options(),
    parse_context(bindings={ "f": @symcore.Expr::Symbol("g") }),
  )
  guard symbol_bound_call
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: 'Symbol' object is not callable" else {
    fail("expected plain symbol binding call to stay non-callable")
  }
  match parse_expr_with("sin(x)", parse_options(evaluate=false)) {
    @symcore.Expr::Apply(
      @symcore.Expr::FunctionHead("sin"),
      [@symcore.Expr::Symbol("x")]
    ) => ()
    _ =>
      fail(
        "evaluate=false should preserve ordinary applications as first-class Apply",
      )
  }
  inspect(
    @symprint.to_string(
      parse_expr_in(
        "pi x",
        parse_options(transformations=relaxed_transformations()),
        parse_context(bindings={ "pi": @symcore.Expr::UndefinedFunction("f") }),
      ),
    ),
    content="f(x)",
  )
  inspect(
    @symprint.to_string(
      parse_expr_in(
        "f x",
        parse_options(transformations=relaxed_transformations()),
        parse_context(bindings={ "f": @symcore.Expr::FunctionHead("cos") }),
      ),
    ),
    content="cos(x)",
  )
  inspect(
    @symprint.to_string(
      parse_expr_in(
        "g x",
        parse_options(transformations=relaxed_transformations()),
        parse_context(bindings={ "g": @symcore.Expr::Symbol("h") }),
      ),
    ),
    content="h*x",
  )
  inspect(
    @symprint.to_string(
      parse_expr_in(
        "f x",
        parse_options(transformations=relaxed_transformations()),
        parse_context(bindings={
          "f": @symcore.lambda_expr(
            @symcore.Expr::Symbol("x"),
            @symcore.add([@symcore.Expr::Symbol("x"), @symcore.int(1)]),
          ),
        }),
      ),
    ),
    content="x + 1",
  )
  inspect(
    @symprint.to_string(
      parse_expr_in(
        "f x",
        parse_options(transformations=relaxed_transformations()),
        parse_context(bindings={ "f": @symcore.Expr::IdentityFunction }),
      ),
    ),
    content="x",
  )
}

///|
test "symparse parser parity-critical lambda and relaxed evaluate false paths" {
  inspect(
    @symprint.to_string(parse_expr("lambda x: x + 1")),
    content="Lambda(x, x + 1)",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with(
        "sin x",
        parse_options(transformations=relaxed_transformations(), evaluate=false),
      ),
    ),
    content="sin(x)",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with(
        "sin**2 x",
        parse_options(transformations=relaxed_transformations(), evaluate=false),
      ),
    ),
    content="sin(x)**2",
  )
}

///|
test "symparse builtin callable semantics follow SymPy parser behavior" {
  inspect(
    @symprint.to_string(parse_expr("Integral")),
    content="<class 'sympy.integrals.integrals.Integral'>",
  )
  inspect(@symprint.to_string(parse_expr("DiracDelta")), content="DiracDelta")
  inspect(@symprint.to_string(parse_expr("Piecewise")), content="Piecewise")
  inspect(
    @symprint.to_string(parse_expr("Integer")),
    content="<class 'sympy.core.numbers.Integer'>",
  )
  inspect(
    @symprint.to_string(parse_expr("Symbol")),
    content="<class 'sympy.core.symbol.Symbol'>",
  )
  inspect(
    parse_expr_equiv(@symprint.to_string(parse_expr("log(x, y)")), "log(x, y)"),
    content="0",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("log(x, y)", parse_options(evaluate=false)),
    ),
    content="log(x, y)",
  )
  inspect(@symprint.to_string(parse_expr("Max()")), content="-oo")
  inspect(@symprint.to_string(parse_expr("Min()")), content="oo")
  inspect(@symprint.to_string(parse_expr("Max(x)")), content="x")
  inspect(@symprint.to_string(parse_expr("Min(x)")), content="x")
  inspect(@symprint.to_string(parse_expr("sqrt(x, y)")), content="sqrt(x)")
  inspect(@symprint.to_string(parse_expr("atan2(x, y)")), content="atan2(x, y)")
  inspect(
    @symprint.to_string(parse_expr("binomial(x, y)")),
    content="binomial(x, y)",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(parse_expr("Integer(2)")),
      "Integer(2)",
    ),
    content="0",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(parse_expr("Integer(2/3)")),
      "Integer(2/3)",
    ),
    content="0",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(parse_expr("Integer(-2/3)")),
      "Integer(-2/3)",
    ),
    content="0",
  )
  inspect(@symprint.to_string(parse_expr("Integer(0.9)")), content="0")
  inspect(@symprint.to_string(parse_expr("Integer(10.5)")), content="10")
  inspect(@symprint.to_string(parse_expr("Integer(-3.8)")), content="-3")
  inspect(@symprint.to_string(parse_expr("Integer(True)")), content="1")
  inspect(@symprint.to_string(parse_expr("Integer(False)")), content="0")
  inspect(
    parse_expr_equiv(
      @symprint.to_string(parse_expr("Rational(2)")),
      "Rational(2)",
    ),
    content="0",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(parse_expr("Rational(2, 3)")),
      "Rational(2, 3)",
    ),
    content="0",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(parse_expr("Rational(0.2)")),
      "Rational(0.2)",
    ),
    content="0",
  )
  inspect(@symprint.to_string(parse_expr("Rational(1.0, 3)")), content="1/3")
  inspect(@symprint.to_string(parse_expr("Rational(1, 3.0)")), content="1/3")
  inspect(@symprint.to_string(parse_expr("Rational(1/2, 1/3)")), content="3/2")
  inspect(@symprint.to_string(parse_expr("Rational(1, 1/3)")), content="3")
  inspect(
    parse_expr_equiv(@symprint.to_string(parse_expr("Float(2)")), "Float(2)"),
    content="0",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(parse_expr("Float(2.5)")),
      "Float(2.5)",
    ),
    content="0",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(parse_expr("Float(2, 20)")),
      "Float(2, 20)",
    ),
    content="0",
  )
  inspect(
    parse_expr_equiv_relaxed_near_zero(
      @symprint.to_string(parse_expr("Float(2/3)")),
      "Float(2/3)",
    ),
    content="True",
  )
  inspect(@symprint.to_string(parse_expr("Float((0, 0, -123))")), content="0")
  inspect(
    @symprint.to_string(parse_expr("Float((0, 0, -123, -1))")),
    content="nan",
  )
  inspect(
    @symprint.to_string(parse_expr("Float((0, 0, -456, -2))")),
    content="oo",
  )
  inspect(
    @symprint.to_string(parse_expr("Float((1, 0, -789, -3))")),
    content="-oo",
  )
  inspect(@symprint.to_string(parse_expr("beta(x)")), content="beta(x, x)")
  inspect(@symprint.to_string(parse_expr("beta(x, y)")), content="beta(x, y)")
  guard (try? parse_expr("pi(x)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: 'Pi' object is not callable" else {
    fail("expected number symbol callable error")
  }
  inspect(
    @symprint.to_string(
      parse_expr_in(
        "pi",
        default_parse_options(),
        parse_context(bindings={ "pi": @symcore.Expr::Symbol("x") }),
      ),
    ),
    content="x",
  )
  guard (try? parse_expr("sin(x, y)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: sin takes exactly 1 argument (2 given)" else {
    fail("expected unary builtin arity error")
  }
  guard (try? parse_expr("atan2(x)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: atan2 takes exactly 2 arguments (1 given)" else {
    fail("expected atan2 arity error")
  }
  guard (try? parse_expr("beta()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: beta takes at least 1 argument (0 given)" else {
    fail("expected beta arity error")
  }
  guard (try? parse_expr("Integer()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Integer.__new__() missing 1 required positional argument: 'i'" else {
    fail("expected Integer constructor arity error")
  }
  guard (try? parse_expr("Integer(sin(x))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Argument of Integer should be of numeric type, got sin(x)." else {
    fail("expected Integer(sin(x)) invalid input error")
  }
  inspect(@symprint.to_string(parse_expr("Integer(pi)")), content="3")
  inspect(@symprint.to_string(parse_expr("Integer(E)")), content="2")
  guard (try? parse_expr("Integer(oo)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert oo to int" else {
    fail("expected Integer(oo) conversion error")
  }
  guard (try? parse_expr("Integer(nan)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected Integer(nan) non-comparable error")
  }
  guard (try? parse_expr("Integer(I)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected Integer(I) non-comparable error")
  }
  guard (try? parse_expr("Integer(I*pi)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected Integer(I*pi) non-comparable error")
  }
  guard (try? parse_expr("Integer(1 + I)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected Integer(1 + I) non-comparable error")
  }
  guard (try? parse_expr("Integer(zoo)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected Integer(zoo) non-comparable error")
  }
  guard (try? parse_expr("Rational()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Rational.__new__() missing 1 required positional argument: 'p'" else {
    fail("expected Rational constructor arity error")
  }
  guard (try? parse_expr("Rational(sin(x))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: sin(x)" else {
    fail("expected Rational(sin(x)) invalid input error")
  }
  guard (try? parse_expr("Rational(sin(x), 2)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: sin(x)" else {
    fail("expected Rational(sin(x), 2) lhs invalid input error")
  }
  guard (try? parse_expr("Rational(sin(x), 0)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: sin(x)" else {
    fail("expected Rational(sin(x), 0) lhs invalid input error")
  }
  guard (try? parse_expr("Rational(2, sin(x))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: sin(x)" else {
    fail("expected Rational(2, sin(x)) rhs invalid input error")
  }
  guard (try? parse_expr("Float()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Float.__new__() missing 1 required positional argument: 'num'" else {
    fail("expected Float constructor arity error")
  }
  guard (try? parse_expr("Float((2, 1, 0))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "ValueError: malformed mpf: (2, 1, 0)" else {
    fail("expected Float malformed mpf error")
  }
  guard (try? parse_expr_with("sqrt(x, y)", parse_options(evaluate=false)))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: sqrt() got multiple values for argument 'evaluate'" else {
    fail("expected sqrt evaluate=False callable error")
  }
}

///|
test "ast parser compatibility entrypoint" {
  inspect(@symprint.to_string(ast_parse_expr("sin")), content="sin")
  inspect(@symprint.to_string(ast_parse_expr("pi")), content="pi")
  inspect(
    @symprint.to_string(ast_parse_expr("GoldenRatio")),
    content="GoldenRatio",
  )
  inspect(@symprint.to_string(ast_parse_expr("NaN")), content="NaN")
  inspect(
    @symprint.to_string(
      ast_parse_expr("pi", local_bindings={ "pi": @symcore.Expr::Symbol("x") }),
    ),
    content="x",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Integral")),
    content="<class 'sympy.integrals.integrals.Integral'>",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("DiracDelta")),
    content="DiracDelta",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Integer")),
    content="<class 'sympy.core.numbers.Integer'>",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Symbol")),
    content="<class 'sympy.core.symbol.Symbol'>",
  )
  inspect(@symprint.to_string(ast_parse_expr("f")), content="f")
  inspect(@symprint.to_string(ast_parse_expr("sin(x)")), content="sin(x)")
  inspect(@symprint.to_string(ast_parse_expr("1/2")), content="1/2")
  inspect(@symprint.to_string(ast_parse_expr("x + 1")), content="x + 1")
  inspect(
    @symprint.to_string(
      ast_parse_expr("x + y", local_bindings={ "x": @symcore.int(2) }),
    ),
    content="y + 2",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("lambda x: x + 1")),
    content="Lambda(x, x + 1)",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("lambda x, y: x + y")),
    content="Lambda((x, y), x + y)",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Derivative(x)")),
    content="Derivative(x, x)",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Derivative(sin(x), (x, 0))")),
    content="sin(x)",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(ast_parse_expr("Integer(2)")),
      "Integer(2)",
    ),
    content="0",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(ast_parse_expr("Integer(2/3)")),
      "Integer(2/3)",
    ),
    content="0",
  )
  inspect(@symprint.to_string(ast_parse_expr("Integer(0.9)")), content="0")
  inspect(@symprint.to_string(ast_parse_expr("Integer(10.5)")), content="10")
  inspect(@symprint.to_string(ast_parse_expr("Integer(-3.8)")), content="-3")
  inspect(@symprint.to_string(ast_parse_expr("Integer(True)")), content="1")
  inspect(@symprint.to_string(ast_parse_expr("Integer(False)")), content="0")
  inspect(
    parse_expr_equiv(
      @symprint.to_string(ast_parse_expr("Rational(2, 3)")),
      "Rational(2, 3)",
    ),
    content="0",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(ast_parse_expr("Rational(0.2)")),
      "Rational(0.2)",
    ),
    content="0",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Rational(1.0, 3)")),
    content="1/3",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Rational(1, 3.0)")),
    content="1/3",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Rational(1/2, 1/3)")),
    content="3/2",
  )
  inspect(@symprint.to_string(ast_parse_expr("Rational(1, 1/3)")), content="3")
  inspect(@symprint.to_string(ast_parse_expr("Rational(True)")), content="1")
  inspect(@symprint.to_string(ast_parse_expr("Rational(False)")), content="0")
  inspect(
    parse_expr_equiv(
      @symprint.to_string(ast_parse_expr("Float(2.5)")),
      "Float(2.5)",
    ),
    content="0",
  )
  inspect(
    parse_expr_equiv(
      @symprint.to_string(ast_parse_expr("Float(2, 20)")),
      "Float(2, 20)",
    ),
    content="0",
  )
  inspect(@symprint.to_string(ast_parse_expr("S(True)")), content="True")
  inspect(@symprint.to_string(ast_parse_expr("S(False)")), content="False")
  inspect(@symprint.to_string(ast_parse_expr("S(1/2)")), content="1/2")
  inspect(@symprint.to_string(ast_parse_expr("S(sin(x))")), content="sin(x)")
  inspect(@symprint.to_string(ast_parse_expr("S(x, y)")), content="x")
  guard (try? ast_parse_expr("pi(x)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: 'Pi' object is not callable" else {
    fail("expected ast parser number symbol callable error")
  }
  guard (try? ast_parse_expr("Integer()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Integer.__new__() missing 1 required positional argument: 'i'" else {
    fail("expected ast parser Integer constructor arity error")
  }
  guard (try? ast_parse_expr("Float((2, 1, 0))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "ValueError: malformed mpf: (2, 1, 0)" else {
    fail("expected ast parser Float malformed mpf error")
  }
  guard (try? ast_parse_expr("Integer(sin(x))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Argument of Integer should be of numeric type, got sin(x)." else {
    fail("expected ast parser Integer(sin(x)) invalid input error")
  }
  inspect(@symprint.to_string(ast_parse_expr("Integer(pi)")), content="3")
  inspect(@symprint.to_string(ast_parse_expr("Integer(E)")), content="2")
  guard (try? ast_parse_expr("Integer(oo)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert oo to int" else {
    fail("expected ast parser Integer(oo) conversion error")
  }
  guard (try? ast_parse_expr("Integer(nan)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected ast parser Integer(nan) non-comparable error")
  }
  guard (try? ast_parse_expr("Integer(I)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected ast parser Integer(I) non-comparable error")
  }
  guard (try? ast_parse_expr("Integer(I*pi)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected ast parser Integer(I*pi) non-comparable error")
  }
  guard (try? ast_parse_expr("Integer(1 + I)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected ast parser Integer(1 + I) non-comparable error")
  }
  guard (try? ast_parse_expr("Integer(zoo)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Cannot convert non-comparable expression to int" else {
    fail("expected ast parser Integer(zoo) non-comparable error")
  }
  guard (try? ast_parse_expr("S()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: SingletonRegistry.__call__() missing 1 required positional argument: 'a'" else {
    fail("expected ast parser S constructor arity error")
  }
  guard (try? ast_parse_expr("Rational(sin(x))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: sin(x)" else {
    fail("expected ast parser Rational(sin(x)) invalid input error")
  }
  guard (try? ast_parse_expr("Rational(sin(x), 2)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: sin(x)" else {
    fail("expected ast parser Rational(sin(x), 2) lhs invalid input error")
  }
  guard (try? ast_parse_expr("Rational(sin(x), 0)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: sin(x)" else {
    fail("expected ast parser Rational(sin(x), 0) lhs invalid input error")
  }
  guard (try? ast_parse_expr("Rational(2, sin(x))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: sin(x)" else {
    fail("expected ast parser Rational(2, sin(x)) rhs invalid input error")
  }
  guard (try? ast_parse_expr("Subs(x, (x, x), (0, 1))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "ValueError: The following expressions appear more than once: x" else {
    fail("expected ast parser duplicate Subs variables error")
  }
  inspect(@symprint.to_string(ast_parse_expr("Subs(x, (), ())")), content="x")
  inspect(
    @symprint.to_string(ast_parse_expr("Subs(Subs(x, x, 0), y, 1)")),
    content="Subs(x, (x, y), (0, 1))",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Rational(True, False)")),
    content="zoo",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("Rational(False, False)")),
    content="nan",
  )
  inspect(
    @symprint.to_string(
      ast_parse_expr("f", local_bindings={
        "f": @symcore.Expr::FunctionHead("cos"),
      }),
    ),
    content="cos",
  )
  inspect(
    @symprint.to_string(
      ast_parse_expr("f", local_bindings={
        "f": @symcore.Expr::UndefinedFunction("g"),
      }),
    ),
    content="g",
  )
  inspect(
    @symprint.to_string(
      ast_parse_expr("f(x)", local_bindings={
        "f": @symcore.Expr::FunctionHead("cos"),
      }),
    ),
    content="cos(x)",
  )
  inspect(
    @symprint.to_string(
      ast_parse_expr("f(x)", local_bindings={
        "f": @symcore.Expr::UndefinedFunction("g"),
      }),
    ),
    content="g(x)",
  )
  let ast_symbol_call : Result[@symcore.Expr, ParseError] = try? ast_parse_expr(
    "f(x)",
    local_bindings={ "f": @symcore.Expr::Symbol("g") },
  )
  guard ast_symbol_call is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: 'Symbol' object is not callable" else {
    fail("expected ast parser symbol binding call to stay non-callable")
  }
  let ast_eq_error : Result[@symcore.Expr, ParseError] = try? ast_parse_expr(
    "Eq()",
  )
  guard ast_eq_error is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Equality.__new__() missing 2 required positional arguments: 'lhs' and 'rhs'" else {
    fail("expected ast parser Eq() constructor arity error")
  }
  let ast_derivative_error : Result[@symcore.Expr, ParseError] = try? ast_parse_expr(
    "Derivative(sin(x), (1, 2))",
  )
  guard ast_derivative_error
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "ValueError: \nCan't calculate derivative wrt 1." else {
    fail("expected ast parser invalid derivative variable error")
  }
  let ast_dict_error : Result[@symcore.Expr, ParseError] = try? ast_parse_expr(
    "Dict(x)",
  )
  guard ast_dict_error is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: object of type 'Symbol' has no len()" else {
    fail("expected ast parser Dict(x) constructor type error")
  }
  let ast_subs_error : Result[@symcore.Expr, ParseError] = try? ast_parse_expr(
    "Subs(x + y, (x, y), z)",
  )
  guard ast_subs_error is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "ValueError: Number of point values must be the same as the number of variables." else {
    fail("expected ast parser Subs variable/value arity error")
  }
  inspect(
    parse_expr_equiv(
      @symprint.to_string(ast_parse_expr("log(x, y)")),
      "log(x, y)",
    ),
    content="0",
  )
  inspect(
    @symprint.to_string(ast_parse_expr("atan2(x, y)")),
    content="atan2(x, y)",
  )
  inspect(@symprint.to_string(ast_parse_expr("beta(x)")), content="beta(x, x)")
  inspect(@symprint.to_string(ast_parse_expr("Max()")), content="-oo")
  inspect(@symprint.to_string(ast_parse_expr("Min(x)")), content="x")
  inspect(
    @symprint.to_string(ast_parse_expr("lambda x: x")),
    content="Lambda(_x, _x)",
  )
  match ast_parse_expr("lambda x: x + 1") {
    @symcore.Expr::Lambda(@symcore.Expr::Symbol("x"), body) =>
      inspect(@symprint.to_string(body), content="x + 1")
    _ => fail("expected ast parser lambda to lower to first-class Lambda node")
  }
}

///|
test "symparse local bindings shadow builtin heads like SymPy" {
  inspect(
    @symprint.to_string(
      parse_expr_in(
        "pi(x)",
        default_parse_options(),
        parse_context(bindings={ "pi": @symcore.Expr::UndefinedFunction("f") }),
      ),
    ),
    content="f(x)",
  )
  inspect(
    @symprint.to_string(
      parse_expr_in(
        "Integral(x)",
        default_parse_options(),
        parse_context(bindings={
          "Integral": @symcore.Expr::UndefinedFunction("f"),
        }),
      ),
    ),
    content="f(x)",
  )
  guard (try? parse_expr_in(
      "Integral(x)",
      default_parse_options(),
      parse_context(bindings={ "Integral": @symcore.Expr::Symbol("g") }),
    ))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: 'Symbol' object is not callable" else {
    fail("expected non-callable builtin binding shadow error")
  }
  inspect(
    @symprint.to_string(
      ast_parse_expr("DiracDelta(x)", local_bindings={
        "DiracDelta": @symcore.Expr::UndefinedFunction("f"),
      }),
    ),
    content="f(x)",
  )
}

///|
test "symparse explicit core constructor calls stay canonical" {
  inspect(
    @symprint.to_string(parse_expr("Eq")),
    content="<class 'sympy.core.relational.Equality'>",
  )
  inspect(@symprint.to_string(parse_expr("Integer(3/2)")), content="1")
  inspect(@symprint.to_string(parse_expr("Integer(pi)")), content="3")
  inspect(@symprint.to_string(parse_expr("Rational(6, 4)")), content="3/2")
  inspect(@symprint.to_string(parse_expr("Rational(1, 0)")), content="zoo")
  inspect(@symprint.to_string(parse_expr("Rational(True)")), content="1")
  inspect(@symprint.to_string(parse_expr("Rational(False)")), content="0")
  inspect(@symprint.to_string(parse_expr("S(True)")), content="True")
  inspect(@symprint.to_string(parse_expr("S(False)")), content="False")
  inspect(@symprint.to_string(parse_expr("S(1/2)")), content="1/2")
  inspect(@symprint.to_string(parse_expr("S(sin(x))")), content="sin(x)")
  inspect(@symprint.to_string(parse_expr("S(x, y)")), content="x")
  guard (try? parse_expr("Rational(pi)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: pi" else {
    fail("expected Rational(pi) invalid input error")
  }
  inspect(@symprint.to_string(parse_expr("Float(1/2)")), content="0.5")
  match parse_expr("Float(pi)") {
    @symcore.Expr::Float(_) => ()
    other =>
      fail("expected Float(pi) to evaluate, got \{@symprint.to_string(other)}")
  }
  inspect(@symprint.to_string(parse_expr("Tuple(x, 1)")), content="(x, 1)")
  inspect(@symprint.to_string(parse_expr("Eq(x, y)")), content="Eq(x, y)")
  inspect(@symprint.to_string(parse_expr("Eq(x, x)")), content="True")
  inspect(@symprint.to_string(parse_expr("Ne(x, x)")), content="False")
  inspect(@symprint.to_string(parse_expr("Lt(1 + 1, 3)")), content="True")
  inspect(
    @symprint.to_string(parse_expr("Derivative(x)")),
    content="Derivative(x, x)",
  )
  inspect(@symprint.to_string(parse_expr("Derivative(2)")), content="0")
  inspect(
    @symprint.to_string(parse_expr("Derivative(sin(x), x)")),
    content="Derivative(sin(x), x)",
  )
  inspect(
    @symprint.to_string(parse_expr("Derivative(sin(x), x, 2)")),
    content="Derivative(sin(x), (x, 2))",
  )
  inspect(
    @symprint.to_string(parse_expr("Derivative(sin(x), (x, 0))")),
    content="sin(x)",
  )
  inspect(
    @symprint.to_string(parse_expr("Derivative(sin(x), x, 0)")),
    content="sin(x)",
  )
  inspect(
    @symprint.to_string(parse_expr("Derivative(sin(x), x, y, 2)")),
    content="Derivative(sin(x), x, (y, 2))",
  )
  inspect(
    @symprint.to_string(parse_expr("Subs(x + y, x, z)")),
    content="Subs(x + y, x, z)",
  )
  inspect(
    @symprint.to_string(parse_expr("Lambda(x, x + 1)")),
    content="Lambda(x, x + 1)",
  )
  inspect(
    @symprint.to_string(parse_expr("Lambda((x, y), x + y)")),
    content="Lambda((x, y), x + y)",
  )
  inspect(
    @symprint.to_string(parse_expr("Lambda(x, x)")),
    content="Lambda(_x, _x)",
  )
  inspect(
    @symprint.to_string(parse_expr("Lambda((x,), x)")),
    content="Lambda(_x, _x)",
  )
  inspect(
    @symprint.to_string(parse_expr("lambda x: x")),
    content="Lambda(_x, _x)",
  )
  inspect(@symprint.to_string(parse_expr("Lambda(x, x)(y)")), content="y")
  inspect(
    @symprint.to_string(parse_expr("Lambda((x, y), x + y)(1, 2)")),
    content="3",
  )
  inspect(
    @symprint.to_string(parse_expr("Lambda(((x, y), z), x + y + z)((1, 2), 3)")),
    content="6",
  )
  inspect(@symprint.to_string(parse_expr("Mod(x, 2)")), content="Mod(x, 2)")
  inspect(
    @symprint.to_string(parse_expr("Dict((x, y), (1, z))")),
    content="{1: z, x: y}",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("Eq(x + x, 2*x)", parse_options(evaluate=false)),
    ),
    content="True",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("Rational(6, 4)", parse_options(evaluate=false)),
    ),
    content="3/2",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("Ne(x, x)", parse_options(evaluate=false)),
    ),
    content="False",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("Lt(1 + 1, 3)", parse_options(evaluate=false)),
    ),
    content="True",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("Derivative(x)", parse_options(evaluate=false)),
    ),
    content="Derivative(x, x)",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("S(x + x)", parse_options(evaluate=false)),
    ),
    content="x + x",
  )
  guard (try? parse_expr("Eq()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Equality.__new__() missing 2 required positional arguments: 'lhs' and 'rhs'" else {
    fail("expected Eq() constructor arity error")
  }
  guard (try? parse_expr("Eq(x)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Equality.__new__() missing 1 required positional argument: 'rhs'" else {
    fail("expected Eq(x) constructor arity error")
  }
  guard (try? parse_expr("Mod(x)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: Mod takes exactly 2 arguments (1 given)" else {
    fail("expected Mod(x) constructor arity error")
  }
  guard (try? parse_expr("S()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: SingletonRegistry.__call__() missing 1 required positional argument: 'a'" else {
    fail("expected S() constructor arity error")
  }
  inspect(
    @symprint.to_string(
      parse_expr_with("Integer(3/2)", parse_options(evaluate=false)),
    ),
    content="1",
  )
  guard (try? parse_expr_with("Rational(3/2)", parse_options(evaluate=false)))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: invalid input: 3/2" else {
    fail("expected Rational(3/2) evaluate=false invalid input error")
  }
  inspect(@symprint.to_string(parse_expr("Rational(0, 0)")), content="nan")
  inspect(
    @symprint.to_string(parse_expr("Rational(True, False)")),
    content="zoo",
  )
  inspect(
    @symprint.to_string(parse_expr("Rational(False, False)")),
    content="nan",
  )
  guard (try? parse_expr("Subs(x)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Subs.__new__() missing 2 required positional arguments: 'variables' and 'point'" else {
    fail("expected Subs(x) constructor arity error")
  }
  guard (try? parse_expr("Subs(x + y, (x, y), z)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "ValueError: Number of point values must be the same as the number of variables." else {
    fail("expected Subs variable/value arity error")
  }
  guard (try? parse_expr("Subs(x, (x, x), (0, 1))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "ValueError: The following expressions appear more than once: x" else {
    fail("expected duplicate Subs variables error")
  }
  inspect(@symprint.to_string(parse_expr("Subs(x, (), ())")), content="x")
  inspect(
    @symprint.to_string(parse_expr("Subs(Subs(x, x, 0), y, 1)")),
    content="Subs(x, (x, y), (0, 1))",
  )
  guard (try? parse_expr("Dict(x)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: object of type 'Symbol' has no len()" else {
    fail("expected Dict(x) constructor type error")
  }
  guard (try? parse_expr("Dict((x, y, z))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Pass Dict args as Dict((k1, v1), ...) or Dict({k1: v1, ...})" else {
    fail("expected Dict((x, y, z)) constructor shape error")
  }
  guard (try? parse_expr("Derivative(sin(x), (1, 2))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "ValueError: \nCan't calculate derivative wrt 1." else {
    fail("expected invalid derivative variable error")
  }
  guard (try? parse_expr("Derivative(sin(x), (x, -1))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "ValueError: order of differentiation must be nonnegative" else {
    fail("expected negative derivative order error")
  }
  guard (try? parse_expr("Derivative(sin(x), sin(x))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "ValueError: \nCan't calculate derivative wrt sin(x)." else {
    fail("expected defined-function derivative variable error")
  }
  guard (try? ast_parse_expr("Derivative(sin(x), sin(x))"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "ValueError: \nCan't calculate derivative wrt sin(x)." else {
    fail("expected ast parser defined-function derivative variable error")
  }
  guard (try? parse_expr("Lambda()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "TypeError: Lambda.__new__() missing 2 required positional arguments: 'signature' and 'expr'" else {
    fail("expected Lambda() constructor arity error")
  }
  guard (try? parse_expr("Lambda((x, x), x)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "BadSignatureError: Duplicate symbol x" else {
    fail("expected duplicate lambda signature error")
  }
  guard (try? parse_expr("Lambda((x, 1), x)"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "BadSignatureError: Lambda signature should be only tuples and symbols, not 1" else {
    fail("expected invalid lambda signature error")
  }
  guard (try? parse_expr("lambda x, x: x"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "BadSignatureError: Duplicate symbol x" else {
    fail("expected duplicate lambda-notation signature error")
  }
  guard (try? parse_expr("Lambda(x, x)()"))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail ==
    "BadArgumentsError: Lambda(_x, _x) takes exactly 1 argument (0 given)" else {
    fail("expected lambda call arity error")
  }
  inspect(
    @symprint.to_string(
      parse_expr_with("Tuple(x + 1, y)", parse_options(evaluate=false)),
    ),
    content="(x + 1, y)",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("Derivative(sin(x), x, 2)", parse_options(evaluate=false)),
    ),
    content="Derivative(sin(x), (x, 2))",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("Lambda(x, x + 1)", parse_options(evaluate=false)),
    ),
    content="Lambda(x, x + 1)",
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("Lambda(x, x)(y)", parse_options(evaluate=false)),
    ),
    content="y",
  )
}
