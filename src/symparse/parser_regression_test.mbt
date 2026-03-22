///|
fn parse_repr(src : String) -> String raise {
  @symprint.debug_repr(parse_expr(src))
}

///|
test "symparse parses explicit call exponentiation" {
  inspect(parse_repr("cos(x)^2"), content="(^ (call cos sym:x) 2)")
  inspect(parse_repr("cos(x)**2"), content="(^ (call cos sym:x) 2)")
  inspect(parse_repr("exp(x)^-1"), content="(^ (call exp sym:x) -1)")
  inspect(
    parse_repr("(cos(x) + sin(x))^2"),
    content="(^ (+ (call cos sym:x) (call sin sym:x)) 2)",
  )
}

///|
test "symparse composes explicit calls with transformed default syntax" {
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
    parse_repr("(x + 1)!!^2"),
    content="(^ (call factorial2 (+ sym:x 1)) 2)",
  )
  inspect(
    parse_repr("cos^2(x + y)"),
    content="(^ (call cos (+ sym:x sym:y)) 2)",
  )
  inspect(
    parse_repr("cos x^2 + sin(x)^2"),
    content="(+ (^ (call sin sym:x) 2) (call cos (^ sym:x 2)))",
  )
}
