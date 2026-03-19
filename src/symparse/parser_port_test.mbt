///|
fn assert_sympy_parse_matches(src : String) -> Unit raise {
  let ours = @symprint.to_string(parse_expr(src))
  let oracle = @sympy_parsing.parse_expr_equiv(ours, src)
  inspect(oracle, content="0")
}

///|
test "symparse parity arithmetic and calls" {
  try! assert_sympy_parse_matches("x + 2*y")
  try! assert_sympy_parse_matches("2**3**x")
  try! assert_sympy_parse_matches("-x**2 + 3")
  try! assert_sympy_parse_matches("f(x, y + 1)")
  try! assert_sympy_parse_matches("(x + 1)/y")
  try! assert_sympy_parse_matches("12.34 + x")
}
