///|
fn parse_repr(src : String) -> String {
  @symprint.debug_repr(try! parse_expr(src))
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
  inspect(
    parse_repr("x < y <= z"),
    content="(call And (call Lt sym:x sym:y) (call Le sym:y sym:z))",
  )
  inspect(parse_repr("x = y"), content="(call Eq sym:x sym:y)")
}

///|
test "symparse evaluate false preserves raw nesting" {
  let options = parse_options(evaluate=false)
  inspect(
    @symprint.debug_repr(try! parse_expr_with("1 + 2 + x", options)),
    content="(+ (+ 1 2) sym:x)",
  )
  inspect(
    @symprint.debug_repr(try! parse_expr_with("a*b*c", options)),
    content="(* (* sym:a sym:b) sym:c)",
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
