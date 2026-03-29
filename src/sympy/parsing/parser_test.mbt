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
  inspect(@symprint.to_string(parse_expr("beta(x)")), content="beta(x, x)")
  inspect(@symprint.to_string(parse_expr("beta(x, y)")), content="beta(x, y)")
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
  guard (try? parse_expr_with("sqrt(x, y)", parse_options(evaluate=false)))
    is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "TypeError: sqrt() got multiple values for argument 'evaluate'" else {
    fail("expected sqrt evaluate=False callable error")
  }
}

///|
test "ast parser compatibility entrypoint" {
  inspect(@symprint.to_string(ast_parse_expr("sin")), content="sin")
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
  match ast_parse_expr("lambda x: x + 1") {
    @symcore.Expr::Lambda(@symcore.Expr::Symbol("x"), body) =>
      inspect(@symprint.to_string(body), content="x + 1")
    _ => fail("expected ast parser lambda to lower to first-class Lambda node")
  }
}
