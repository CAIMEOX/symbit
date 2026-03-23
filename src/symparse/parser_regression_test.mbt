///|
fn parse_repr(src : String) -> String raise {
  @symprint.to_string(parse_expr(src))
}

///|
test "symparse parses explicit call exponentiation" {
  inspect(
    parse_repr("cos(x)^2"),
    content=(
      #|cos(x)**2
    ),
  )
  inspect(
    parse_repr("cos(x)**2"),
    content=(
      #|cos(x)**2
    ),
  )
  inspect(
    parse_repr("exp(x)^-1"),
    content=(
      #|exp(x)**-1
    ),
  )
  inspect(
    parse_repr("(cos(x) + sin(x))^2"),
    content=(
      #|(cos(x) + sin(x))**2
    ),
  )
}

///|
test "symparse composes explicit calls with transformed default syntax" {
  inspect(
    parse_repr("cos(x)^2"),
    content=(
      #|cos(x)**2
    ),
  )
  inspect(
    parse_repr("2cos(x)^2"),
    content=(
      #|2*cos(x)**2
    ),
  )
  inspect(
    parse_repr("sin(x)cos(x)"),
    content=(
      #|cos(x)*sin(x)
    ),
  )
  inspect(
    parse_repr("(x + 1)!^2"),
    content=(
      #|factorial((x + 1))**2
    ),
  )
  inspect(
    parse_repr("(x + 1)!!^2"),
    content=(
      #|factorial2((x + 1))**2
    ),
  )
  inspect(
    parse_repr("cos^2(x + y)"),
    content=(
      #|cos((x + y))**2
    ),
  )
  inspect(
    parse_repr("cos x^2 + sin(x)^2"),
    content=(
      #|sin(x)**2 + cos((x**2))
    ),
  )
}
