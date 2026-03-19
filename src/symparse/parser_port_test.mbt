///|
fn assert_sympy_parse_matches(src : String) -> Unit raise {
  let ours = @symprint.to_string(parse_expr(src))
  let oracle = @sympy_parsing.parse_expr_equiv(ours, src)
  inspect(oracle, content="0")
}

///|
fn assert_sympy_parse_matches_stage2(src : String) -> Unit raise {
  let ours = @symprint.to_string(parse_expr_with(src, stage2_options()))
  let oracle = @sympy_parsing.parse_expr_equiv_stage2(ours, src)
  inspect(oracle, content="0")
}

///|
fn assert_sympy_parse_string_stage2(src : String) -> Unit raise {
  let ours = @symprint.to_string(parse_expr_with(src, stage2_options()))
  let oracle = @sympy_parsing.parse_expr_sstr_stage2(src)
  inspect(ours, content=oracle)
}

///|
fn assert_sympy_parse_matches_stage3(
  src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
) -> Unit raise {
  let bindings : Map[String, @symcore.Expr] = {}
  for i in 0..<binding_names.length() {
    bindings[binding_names[i]] = try! parse_expr(binding_exprs[i])
  }
  let ours = @symprint.to_string(
    parse_expr_in(
      src,
      stage2_options(),
      parse_context(callable_names~, bindings~),
    ),
  )
  let oracle = @sympy_parsing.parse_expr_sstr_stage3(
    src,
    callable_names,
    binding_names~,
    binding_exprs~,
  )
  inspect(ours, content=oracle)
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

///|
test "symparse parity stage-2 transformed syntax" {
  try! assert_sympy_parse_matches_stage2("2x")
  try! assert_sympy_parse_matches_stage2("x(y + 1)")
  try! assert_sympy_parse_matches_stage2("2sin(x)")
  try! assert_sympy_parse_matches_stage2("sin x")
  try! assert_sympy_parse_matches_stage2("sin x y")
  try! assert_sympy_parse_matches_stage2("x!")
  try! assert_sympy_parse_matches_stage2("(x + 1)!")
  try! assert_sympy_parse_matches_stage2(".3 + x")
  try! assert_sympy_parse_matches_stage2("0.2[1] + x")
  try! assert_sympy_parse_matches_stage2("1.[23] + x")
}

///|
test "symparse parity stage-2 equality string forms" {
  try! assert_sympy_parse_string_stage2("x = y")
  try! assert_sympy_parse_string_stage2("x == x")
  try! assert_sympy_parse_string_stage2("x == y")
}

///|
test "symparse parity stage-3 callable context" {
  try! assert_sympy_parse_matches_stage3("f(x)", ["f"])
  try! assert_sympy_parse_matches_stage3("f x", ["f"])
  try! assert_sympy_parse_matches_stage3("a + b", [], binding_names=["a"], binding_exprs=[
    "z",
  ])
  try! assert_sympy_parse_matches_stage3("n + b", [], binding_names=["n"], binding_exprs=[
    "2",
  ])
  try! assert_sympy_parse_matches_stage3(
    "sin x",
    ["sin"],
    binding_names=["sin"],
    binding_exprs=["g"],
  )
  try! assert_sympy_parse_matches_stage3("sin x", [], binding_names=["sin"], binding_exprs=[
    "z",
  ])
}

///|
test "symparse parity stage-2 relation truthiness string forms" {
  inspect(
    @symprint.to_string(try! parse_expr_with("1 < 2 <= 3", stage2_options())),
    content=@sympy_parsing.parse_expr_sstr_stage2("1 < 2 <= 3"),
  )
  inspect(
    @symprint.to_string(try! parse_expr_with("1 == 1 < x", stage2_options())),
    content=@sympy_parsing.parse_expr_sstr_stage2("1 == 1 < x"),
  )
  inspect(
    @symprint.to_string(try! parse_expr_with("1 == 2 < x", stage2_options())),
    content=@sympy_parsing.parse_expr_sstr_stage2("1 == 2 < x"),
  )
  inspect(
    @symprint.to_string(try! parse_expr_with("x == x < y", stage2_options())),
    content=@sympy_parsing.parse_expr_sstr_stage2("x == x < y"),
  )
  inspect(
    @symprint.to_string(try! parse_expr_with("x == y < z", stage2_options())),
    content=@sympy_parsing.parse_expr_sstr_stage2("x == y < z"),
  )
  inspect(
    @symprint.to_string(
      try! parse_expr_with("x == x", parse_options(evaluate=false)),
    ),
    content=@sympy_parsing.parse_expr_sstr("x == x", evaluate=false),
  )
  inspect(
    @symprint.to_string(
      try! parse_expr_with("x < y < z", parse_options(evaluate=false)),
    ),
    content=@sympy_parsing.parse_expr_sstr("x < y < z", evaluate=false),
  )
}
