///|
fn parse_repr(src : String) -> String {
  @symprint.debug_repr(try! parse_expr(src))
}

///|
fn stage2_options() -> ParseOptions {
  parse_options(
    implicit_multiplication=true,
    implicit_application=true,
    factorial_notation=true,
    convert_equals_signs=true,
  )
}

///|
fn parse_repr_stage2(src : String) -> String {
  @symprint.debug_repr(try! parse_expr_with(src, stage2_options()))
}

///|
fn parse_repr_with(
  src : String,
  options : ParseOptions,
  context : ParseContext,
) -> String {
  @symprint.debug_repr(try! parse_expr_in(src, options, context))
}

///|
fn stage3_context() -> ParseContext {
  parse_context(callable_names=["f", "sin"], bindings={
    "a": @symcore.symbol("z"),
    "n": @symcore.int(2),
    "sin": @symcore.symbol("g"),
  })
}

///|
fn parse_repr_stage3(src : String) -> String {
  parse_repr_with(src, stage2_options(), stage3_context())
}

///|
fn evaluate_false_options() -> ParseOptions {
  parse_options(evaluate=false, convert_equals_signs=true)
}

///|
test "symparse stage-1 arithmetic precedence" {
  inspect(parse_repr("x + 2*y"), content="(+ (* 2 sym:y) sym:x)")
  inspect(parse_repr("2**3**2"), content="(^ 2 (^ 3 2))")
  inspect(parse_repr("-x**2"), content="(* -1 (^ sym:x 2))")
  inspect(parse_repr("(x + 1) / y"), content="(* (^ sym:y -1) (+ sym:x 1))")
}

///|
test "symparse stage-1 function calls and tuples" {
  inspect(parse_repr("f(x, y + 1)"), content="(call f sym:x (+ sym:y 1))")
  inspect(parse_repr("(x, y + 1)"), content="(call Tuple sym:x (+ sym:y 1))")
  inspect(parse_repr("g()"), content="(call g)")
}

///|
test "symparse stage-1 comparisons lower to symbolic heads" {
  inspect(parse_repr("x < y"), content="(call Lt sym:x sym:y)")
  inspect(parse_repr("x == x"), content="sym:True")
  inspect(parse_repr("x == y"), content="sym:False")
}

///|
test "symparse evaluate false preserves flat raw operators" {
  let options = evaluate_false_options()
  inspect(
    @symprint.debug_repr(try! parse_expr_with("1 + 2 + x", options)),
    content="(+ 1 2 sym:x)",
  )
  inspect(
    @symprint.debug_repr(try! parse_expr_with("a*b*c", options)),
    content="(* sym:a sym:b sym:c)",
  )
  inspect(
    @symprint.debug_repr(try! parse_expr_with("x/y/z", options)),
    content="(* sym:x (^ sym:y -1) (^ sym:z -1))",
  )
  inspect(
    @symprint.debug_repr(try! parse_expr_with("x-y-z", options)),
    content="(+ sym:x (* -1 sym:y) (* -1 sym:z))",
  )
  inspect(
    @symprint.debug_repr(try! parse_expr_with("x==x", options)),
    content="(call Eq sym:x sym:x)",
  )
  inspect(
    @symprint.debug_repr(try! parse_expr_with("x<y<z", options)),
    content="(call Lt sym:x sym:y)",
  )
}

///|
test "symparse lexer exposes typed tokens" {
  let tokens = try! lex("f(x, 2**y)")
  inspect(
    tokens.map(tok => token_kind_name(tok.kind)),
    content="[\"identifier\", \"`(`\", \"identifier\", \"`,`\", \"integer\", \"`**`\", \"identifier\", \"`)`\", \"end of input\"]",
  )
}

///|
test "symparse stage-1 error paths" {
  let invalid_char : Result[@symcore.Expr, ParseError] = try? parse_expr(
    "x @ y",
  )
  guard invalid_char is Err(ParseError::UnexpectedChar(span=sp, '@')) &&
    sp.start == 2 &&
    sp.stop == 3 else {
    fail("expected UnexpectedChar at '@'")
  }

  let invalid_call : Result[@symcore.Expr, ParseError] = try? parse_expr(
    "(f + g)(x)",
  )
  guard invalid_call is Err(ParseError::UnsupportedConstruct(span=_, detail)) &&
    detail == "stage-1 call lowering only accepts a simple function name" else {
    fail("expected UnsupportedConstruct for non-symbol callee")
  }
}

///|
test "symparse stage-2 implicit multiplication" {
  inspect(parse_repr_stage2("2x"), content="(* 2 sym:x)")
  inspect(parse_repr_stage2("x(y + 1)"), content="(* sym:x (+ sym:y 1))")
  inspect(
    parse_repr_stage2("(x + 1)(y + 1)"),
    content="(* (+ sym:x 1) (+ sym:y 1))",
  )
  inspect(parse_repr_stage2("2sin(x)"), content="(* 2 (call sin sym:x))")
}

///|
test "symparse stage-2 implicit application and factorial" {
  inspect(parse_repr_stage2("sin x"), content="(call sin sym:x)")
  inspect(parse_repr_stage2("sin x y"), content="(call sin (* sym:x sym:y))")
  inspect(parse_repr_stage2("x!"), content="(call factorial sym:x)")
  inspect(parse_repr_stage2("(x + 1)!"), content="(call factorial (+ sym:x 1))")
  inspect(parse_repr_stage2("x = y"), content="(call Eq sym:x sym:y)")
  inspect(parse_repr_stage2("x == x"), content="sym:True")
  inspect(parse_repr_stage2("x == y"), content="sym:False")
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
  inspect(parse_repr("x == x < y"), content="(call Lt sym:x sym:y)")
  inspect(parse_repr("x == y < z"), content="sym:False")
}

///|
test "symparse stage-2 matches sympy callable heuristic" {
  inspect(parse_repr_stage2("f(x)"), content="(* sym:f sym:x)")
  inspect(parse_repr_stage2("f x"), content="(* sym:f sym:x)")
}

///|
test "symparse default parser still rejects stage-2 sugar" {
  let implicit_mul : Result[@symcore.Expr, ParseError] = try? parse_expr("2x")
  guard implicit_mul is Err(_) else {
    fail("default parse_expr should reject implicit multiplication")
  }
  let implicit_app : Result[@symcore.Expr, ParseError] = try? parse_expr(
    "sin x",
  )
  guard implicit_app is Err(_) else {
    fail("default parse_expr should reject implicit application")
  }
  let factorial : Result[@symcore.Expr, ParseError] = try? parse_expr("x!")
  guard factorial is Err(_) else {
    fail("default parse_expr should reject factorial notation")
  }
  let single_eq : Result[@symcore.Expr, ParseError] = try? parse_expr("x = y")
  guard single_eq is Err(_) else {
    fail(
      "default parse_expr should reject single '=' without convert_equals_signs",
    )
  }
}

///|
test "symparse stage-2 repeated decimals and leading-dot decimals" {
  inspect(parse_repr_stage2(".3 + x"), content="(+ sym:x 3/10)")
  inspect(parse_repr_stage2("0.2[1] + x"), content="(+ sym:x 19/90)")
  inspect(parse_repr_stage2("1.[23] + x"), content="(+ sym:x 122/99)")
}

///|
test "symparse stage-3 callable context overrides implicit multiplication heuristic" {
  inspect(parse_repr_stage3("f(x)"), content="(call f sym:x)")
  inspect(parse_repr_stage3("f x"), content="(call f sym:x)")
  inspect(parse_repr_stage3("f(x) + 1"), content="(+ (call f sym:x) 1)")
}

///|
test "symparse stage-3 local bindings resolve symbols and override builtins" {
  inspect(parse_repr_stage3("a + b"), content="(+ sym:b sym:z)")
  inspect(parse_repr_stage3("n + b"), content="(+ sym:b 2)")
  inspect(parse_repr_stage3("sin x"), content="(call g sym:x)")
  let symbol_override = parse_context(bindings={ "sin": @symcore.symbol("z") })
  inspect(
    parse_repr_with("sin x", stage2_options(), symbol_override),
    content="(* sym:x sym:z)",
  )
}
