///|
fn parse_repr(src : String) -> String raise {
  @symprint.debug_repr(parse_expr(src))
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
fn parse_repr_in_local_context(src : String) -> String raise {
  parse_repr_with(src, default_parse_options(), local_context())
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
fn evaluate_false_options() -> ParseOptions {
  parse_options(evaluate=false)
}

///|
test "symparse arithmetic precedence" {
  inspect(parse_repr("x + 2*y"), content="(+ (* 2 sym:y) sym:x)")
  inspect(parse_repr("2**3**2"), content="(^ 2 (^ 3 2))")
  inspect(parse_repr("-x**2"), content="(* -1 (^ sym:x 2))")
  inspect(parse_repr("(x + 1) / y"), content="(* (^ sym:y -1) (+ sym:x 1))")
}

///|
test "symparse function calls and tuples" {
  inspect(parse_repr("f(x, y + 1)"), content="(call f sym:x (+ sym:y 1))")
  inspect(parse_repr("(x, y + 1)"), content="(call Tuple sym:x (+ sym:y 1))")
  inspect(parse_repr("g()"), content="(call g)")
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
  let options = evaluate_false_options()
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
  inspect(
    @symprint.debug_repr(parse_expr_with("x!=y", options)),
    content="(call Ne sym:x sym:y)",
  )
  inspect(
    @symprint.debug_repr(parse_expr_with("x<y<z", options)),
    content="(call Lt sym:x sym:y)",
  )
}

///|
fn structured_callable_context() -> ParseContext {
  parse_context(
    callable_names=["f", "sin", "g"],
    bindings={
      "f": @symcore.Expr::UndefinedFunction("g"),
      "sin": @symcore.Expr::FunctionHead("cos"),
      "g": @symcore.Expr::FunctionHead("exp"),
    },
  )
}

///|
test "symparse lexer exposes typed tokens" {
  let tokens = lex("f(x!!, 2e-3 != y)")
  json_inspect(tokens.map(tok => token_kind_name(tok.kind)), content=[
    "identifier", "`(`", "identifier", "`!!`", "`,`", "decimal", "`!=`", "identifier",
    "`)`", "end of input",
  ])
}

///|
test "symparse error paths" {
  let invalid_char : Result[@symcore.Expr, ParseError] = try? parse_expr(
    "x @ y",
  )
  guard invalid_char is Err(ParseError::UnexpectedChar(span=sp, '@')) &&
    sp.start == 2 &&
    sp.stop == 3 else {
    fail("expected UnexpectedChar at '@'")
  }
  inspect(parse_repr("(f + g)(x)"), content="(* sym:x (+ sym:f sym:g))")
}

///|
test "symparse default parser handles implicit multiplication" {
  inspect(parse_repr("2x"), content="(* 2 sym:x)")
  inspect(parse_repr("x(y + 1)"), content="(* sym:x (+ sym:y 1))")
  inspect(parse_repr("(x + 1)(y + 1)"), content="(* (+ sym:x 1) (+ sym:y 1))")
  inspect(parse_repr("2sin(x)"), content="(* 2 (call sin sym:x))")
  inspect(parse_repr("sin**2(x)"), content="(^ (call sin sym:x) 2)")
  inspect(parse_repr("sin**2 x"), content="(^ (call sin sym:x) 2)")
  inspect(parse_repr("cos(x)^2"), content="(^ (call cos sym:x) 2)")
  inspect(parse_repr("2cos(x)^2"), content="(* 2 (^ (call cos sym:x) 2))")
  inspect(
    parse_repr("sin(x)cos(x)"),
    content="(* (call cos sym:x) (call sin sym:x))",
  )
  inspect(
    parse_repr("(x + 1)!^2"),
    content="(^ (call factorial (+ sym:x 1)) 2)",
  )
  inspect(
    parse_repr("2sin**2 x**2"),
    content="(* 2 (^ (call sin (^ sym:x 2)) 2))",
  )
}

///|
test "symparse default parser handles application factorial and double factorial" {
  inspect(parse_repr("sin x"), content="(call sin sym:x)")
  inspect(parse_repr("sin x y"), content="(call sin (* sym:x sym:y))")
  inspect(parse_repr("x!"), content="(call factorial sym:x)")
  inspect(parse_repr("(x + 1)!"), content="(call factorial (+ sym:x 1))")
  inspect(parse_repr("x!!"), content="(call factorial2 sym:x)")
  inspect(parse_repr("(x + 1)!!"), content="(call factorial2 (+ sym:x 1))")
  inspect(
    parse_repr("(x + 1)!!^2"),
    content="(^ (call factorial2 (+ sym:x 1)) 2)",
  )
  inspect(parse_repr("x = y"), content="(call Eq sym:x sym:y)")
  inspect(parse_repr("x == x"), content="sym:True")
  inspect(parse_repr("x == y"), content="sym:False")
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
  inspect(parse_repr("1 != 2 < x"), content="(call Lt 2 sym:x)")
  inspect(parse_repr("x == x < y"), content="(call Lt sym:x sym:y)")
  inspect(parse_repr("x == y < z"), content="sym:False")
}

///|
test "symparse default parser matches sympy callable heuristic" {
  inspect(parse_repr("sin"), content="fhead:sin")
  inspect(parse_repr("f(x)"), content="(* sym:f sym:x)")
  inspect(parse_repr("f x"), content="(* sym:f sym:x)")
}

///|
test "symparse default parser accepts full transformed syntax" {
  inspect(parse_repr("2x"), content="(* 2 sym:x)")
  inspect(parse_repr("sin x"), content="(call sin sym:x)")
  inspect(parse_repr("x!"), content="(call factorial sym:x)")
  inspect(parse_repr("x = y"), content="(call Eq sym:x sym:y)")
}

///|
test "symparse repeated decimals leading-dot decimals and scientific notation" {
  inspect(parse_repr(".3 + x"), content="(+ sym:x 3/10)")
  inspect(parse_repr("0.2[1] + x"), content="(+ sym:x 19/90)")
  inspect(parse_repr("1.[23] + x"), content="(+ sym:x 122/99)")
  inspect(parse_repr("1e3 + x"), content="(+ sym:x 1000)")
  inspect(parse_repr("1e-3 + x"), content="(+ sym:x 1/1000)")
  inspect(parse_repr("1.2e3 + x"), content="(+ sym:x 1200)")
  inspect(parse_repr("3E-1 + x"), content="(+ sym:x 3/10)")
}

///|
test "symparse context overrides implicit multiplication heuristic" {
  inspect(parse_repr_in_local_context("f"), content="ufunc:f")
  inspect(parse_repr_in_local_context("f(x)"), content="(call f sym:x)")
  inspect(parse_repr_in_local_context("f x"), content="(call f sym:x)")
  inspect(
    parse_repr_in_local_context("f(x) + 1"),
    content="(+ (call f sym:x) 1)",
  )
}

///|
test "symparse callable context preserves undefined-function applications structurally" {
  let expr = parse_expr_in("f(x)", default_parse_options(), local_context())
  match @symcore.undefined_application_parts(expr) {
    Some((name, [arg])) => {
      inspect(name, content="f")
      inspect(@symprint.to_string(arg), content="x")
    }
    _ => fail("expected undefined function application")
  }
}

///|
test "symparse callable bindings accept structured function heads" {
  inspect(
    parse_repr_with("f(x)", default_parse_options(), structured_callable_context()),
    content="(call g sym:x)",
  )
  inspect(
    parse_repr_with("sin(x)", default_parse_options(), structured_callable_context()),
    content="(call cos sym:x)",
  )
  inspect(
    parse_repr_with("g(x)", default_parse_options(), structured_callable_context()),
    content="(call exp sym:x)",
  )
}

///|
test "symparse local bindings resolve symbols and override builtins" {
  inspect(parse_repr_in_local_context("a + b"), content="(+ sym:b sym:z)")
  inspect(parse_repr_in_local_context("n + b"), content="(+ sym:b 2)")
  inspect(parse_repr_in_local_context("sin x"), content="(call g sym:x)")
  let symbol_override = parse_context(bindings={ "sin": @symcore.Expr::Symbol("z") })
  inspect(
    parse_repr_with("sin x", default_parse_options(), symbol_override),
    content="(* sym:x sym:z)",
  )
}

///|
test "symparse global bindings participate in name resolution" {
  inspect(
    parse_repr_with("a + b", default_parse_options(), global_context()),
    content="(+ sym:b sym:t)",
  )
  inspect(
    parse_repr_with("f(x)", default_parse_options(), global_context()),
    content="(call g sym:x)",
  )
  inspect(
    parse_repr_with("f x", default_parse_options(), global_context()),
    content="(call g sym:x)",
  )
  inspect(
    parse_repr_with("sin x", default_parse_options(), global_context()),
    content="(call g sym:x)",
  )
}

///|
test "symparse local names shadow global names" {
  let context = parse_context(
    bindings={ "a": @symcore.Expr::Symbol("z"), "sin": @symcore.Expr::Symbol("w") },
    global_callable_names=["sin"],
    global_bindings={ "a": @symcore.Expr::Symbol("t"), "sin": @symcore.Expr::Symbol("g") },
  )
  inspect(
    parse_repr_with("a + b", default_parse_options(), context),
    content="(+ sym:b sym:z)",
  )
  inspect(
    parse_repr_with("sin x", default_parse_options(), context),
    content="(* sym:w sym:x)",
  )
}
