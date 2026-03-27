///|
fn assert_sympy_parse_matches(src : String) -> Unit raise {
  let ours = @symprint.to_string(parse_expr(src))
  let oracle = parse_expr_equiv(ours, src)
  inspect(oracle, content="0")
}

///|
fn has_inexact_number_syntax(src : String) -> Bool {
  if src.contains(".") || src.contains("[") {
    return true
  }
  let chars = src.to_array()
  for i in 1..<(chars.length() - 1) {
    if (chars[i] == 'e' || chars[i] == 'E') &&
      chars[i - 1].is_ascii_digit() &&
      (
        chars[i + 1].is_ascii_digit() ||
        chars[i + 1] == '+' ||
        chars[i + 1] == '-'
      ) {
      return true
    }
  }
  false
}

///|
fn assert_sympy_parse_matches_relaxed(src : String) -> Unit raise {
  let ours = @symprint.to_string(
    parse_expr_with(
      src,
      parse_options(transformations=relaxed_transformations()),
    ),
  )
  if has_inexact_number_syntax(src) {
    let oracle = parse_expr_equiv_relaxed_near_zero(ours, src)
    inspect(oracle, content="True")
  } else {
    let oracle = parse_expr_equiv_relaxed(ours, src)
    inspect(oracle, content="0")
  }
}

///|
fn assert_sympy_parse_string(src : String) -> Unit raise {
  let ours = @symprint.to_string(parse_expr(src))
  let oracle = parse_expr_sstr(src)
  inspect(ours, content=oracle)
}

///|
fn assert_sympy_parse_string_relaxed(src : String) -> Unit raise {
  let ours = @symprint.to_string(
    parse_expr_with(
      src,
      parse_options(transformations=relaxed_transformations()),
    ),
  )
  let oracle = parse_expr_sstr_relaxed(src)
  inspect(ours, content=oracle)
}

///|
fn assert_sympy_parse_matches_in(
  src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
  global_callable_names? : Array[String] = [],
  global_binding_names? : Array[String] = [],
  global_binding_exprs? : Array[String] = [],
) -> Unit raise {
  let bindings : Map[String, @symcore.Expr] = {}
  for i in 0..<binding_names.length() {
    bindings[binding_names[i]] = parse_expr(binding_exprs[i])
  }
  let global_bindings : Map[String, @symcore.Expr] = {}
  for i in 0..<global_binding_names.length() {
    global_bindings[global_binding_names[i]] = parse_expr(
      global_binding_exprs[i],
    )
  }
  let ours = @symprint.to_string(
    parse_expr_in(
      src,
      default_parse_options(),
      parse_context(
        callable_names~,
        bindings~,
        global_callable_names~,
        global_bindings~,
      ),
    ),
  )
  let oracle = parse_expr_sstr_in(
    src,
    callable_names,
    binding_names~,
    binding_exprs~,
    global_callable_names~,
    global_binding_names~,
    global_binding_exprs~,
  )
  inspect(ours, content=oracle)
}

///|
fn assert_sympy_parse_matches_in_relaxed(
  src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
  global_callable_names? : Array[String] = [],
  global_binding_names? : Array[String] = [],
  global_binding_exprs? : Array[String] = [],
) -> Unit raise {
  let bindings : Map[String, @symcore.Expr] = {}
  for i in 0..<binding_names.length() {
    bindings[binding_names[i]] = parse_expr(binding_exprs[i])
  }
  let global_bindings : Map[String, @symcore.Expr] = {}
  for i in 0..<global_binding_names.length() {
    global_bindings[global_binding_names[i]] = parse_expr(
      global_binding_exprs[i],
    )
  }
  let ours = @symprint.to_string(
    parse_expr_in(
      src,
      parse_options(transformations=relaxed_transformations()),
      parse_context(
        callable_names~,
        bindings~,
        global_callable_names~,
        global_bindings~,
      ),
    ),
  )
  let oracle = parse_expr_sstr_in_relaxed(
    src,
    callable_names,
    binding_names~,
    binding_exprs~,
    global_callable_names~,
    global_binding_names~,
    global_binding_exprs~,
  )
  inspect(ours, content=oracle)
}

///|
test "symparse parity arithmetic and calls" {
  assert_sympy_parse_matches("x + 2*y")
  assert_sympy_parse_matches("2**3**x")
  assert_sympy_parse_matches("-x**2 + 3")
  assert_sympy_parse_matches("(x + 1)/y")
  assert_sympy_parse_matches("12.34 + x")
}

///|
test "symparse parity transformed relaxed syntax" {
  assert_sympy_parse_matches_relaxed("2x")
  assert_sympy_parse_matches_relaxed("x(y + 1)")
  assert_sympy_parse_matches_relaxed("2sin(x)")
  assert_sympy_parse_matches_relaxed("sin**2(x)")
  assert_sympy_parse_matches_relaxed("sin**2 x")
  assert_sympy_parse_matches_relaxed("cos(x)^2")
  assert_sympy_parse_matches_relaxed("2cos(x)^2")
  assert_sympy_parse_matches_relaxed("sin(x)cos(x)")
  assert_sympy_parse_matches_relaxed("(x + 1)!^2")
  assert_sympy_parse_matches_relaxed("(x + 1)!!^2")
  assert_sympy_parse_matches_relaxed("cos^2(x + y)")
  assert_sympy_parse_matches_relaxed("cos x^2 + sin(x)^2")
  assert_sympy_parse_matches_relaxed("2sin**2 x**2")
  assert_sympy_parse_matches_relaxed("sin x")
  assert_sympy_parse_matches_relaxed("sin x y")
  assert_sympy_parse_matches_relaxed("x!")
  assert_sympy_parse_matches_relaxed("x!!")
  assert_sympy_parse_matches_relaxed("(x + 1)!")
  assert_sympy_parse_matches_relaxed(".3 + x")
  assert_sympy_parse_matches_relaxed("0.2[1] + x")
  assert_sympy_parse_matches_relaxed("1.[23] + x")
  assert_sympy_parse_matches_relaxed("1e3 + x")
  assert_sympy_parse_matches_relaxed("1e-3 + x")
  assert_sympy_parse_matches_relaxed("1.2e3 + x")
  assert_sympy_parse_matches_relaxed("3E-1 + x")
  assert_sympy_parse_matches_relaxed("10sin**2 x**2 + 3xyz + tan theta")
  assert_sympy_parse_matches_relaxed("cot z + csc z")
  assert_sympy_parse_matches_relaxed("2e-3x + cos^2 theta")
  assert_sympy_parse_matches_relaxed("sqrt x + log 10")
}

///|
test "symparse parity equality and inequality string forms" {
  assert_sympy_parse_string_relaxed("x = y")
  assert_sympy_parse_string("x == x")
  assert_sympy_parse_string("x == y")
  assert_sympy_parse_string("x != x")
  assert_sympy_parse_string("x != y")
}

///|
test "symparse parity callable context" {
  assert_sympy_parse_string("sin")
  assert_sympy_parse_matches_in("f", ["f"])
  assert_sympy_parse_matches_in("f(x)", ["f"])
  assert_sympy_parse_matches_in_relaxed("f x", ["f"])
  assert_sympy_parse_matches_in("a + b", [], binding_names=["a"], binding_exprs=[
    "z",
  ])
  assert_sympy_parse_matches_in("n + b", [], binding_names=["n"], binding_exprs=[
    "2",
  ])
  assert_sympy_parse_matches_in_relaxed(
    "sin x",
    ["sin"],
    binding_names=["sin"],
    binding_exprs=["g"],
  )
  assert_sympy_parse_matches_in_relaxed("sin x", [], binding_names=["sin"], binding_exprs=[
    "z",
  ])
  assert_sympy_parse_matches_in("a + b", [], global_binding_names=["a"], global_binding_exprs=[
    "t",
  ])
  assert_sympy_parse_matches_in(
    "f(x)",
    [],
    global_callable_names=["f"],
    global_binding_names=["f"],
    global_binding_exprs=["g"],
  )
  assert_sympy_parse_matches_in_relaxed(
    "f x",
    [],
    global_callable_names=["f"],
    global_binding_names=["f"],
    global_binding_exprs=["g"],
  )
  assert_sympy_parse_matches_in_relaxed(
    "sin x",
    [],
    binding_names=["sin"],
    binding_exprs=["w"],
    global_callable_names=["sin"],
    global_binding_names=["sin"],
    global_binding_exprs=["g"],
  )
}

///|
test "symparse parity split symbols custom and ast parser" {
  inspect(
    @symprint.to_string(
      parse_expr_with(
        "xy",
        parse_options(
          transformations=[
            ..standard_transformations(),
            Transformation::SplitSymbols,
            Transformation::ImplicitMultiplication,
          ],
        ),
      ),
    ),
    content=parse_expr_sstr_with(
      "xy",
      "sympy.parsing.sympy_parser.standard_transformations + " +
      "(sympy.parsing.sympy_parser.split_symbols, " +
      "sympy.parsing.sympy_parser.implicit_multiplication)",
      "{}",
      "{}",
      true,
    ),
  )
  inspect(
    @symprint.to_string(
      parse_expr_with(
        "unsplittable",
        parse_options(
          transformations=[
            ..standard_transformations(),
            Transformation::SplitSymbolsCustom(fn(symbol : String) -> Bool {
              symbol != "unsplittable" && default_split_symbol_predicate(symbol)
            }),
            Transformation::ImplicitMultiplication,
          ],
        ),
      ),
    ),
    content=parse_expr_split_custom_sstr("unsplittable", ["unsplittable"]),
  )
  inspect(
    @symprint.to_string(
      ast_parse_expr("x + y", local_bindings={ "x": @symcore.int(2) }),
    ),
    content=ast_parse_expr_sstr("x + y", binding_names=["x"], binding_exprs=[
      "2",
    ]),
  )
  inspect(
    @symprint.to_string(ast_parse_expr("lambda x: x + 1")),
    content=ast_parse_expr_sstr("lambda x: x + 1"),
  )
  inspect(
    @symprint.to_string(ast_parse_expr("lambda x, y: x + y")),
    content=ast_parse_expr_sstr("lambda x, y: x + y"),
  )
}

///|
test "symparse parity relation truthiness string forms" {
  inspect(
    @symprint.to_string(parse_expr("1 < 2 <= 3")),
    content=parse_expr_sstr("1 < 2 <= 3"),
  )
  inspect(
    @symprint.to_string(parse_expr("1 == 1 < x")),
    content=parse_expr_sstr("1 == 1 < x"),
  )
  inspect(
    @symprint.to_string(parse_expr("1 == 2 < x")),
    content=parse_expr_sstr("1 == 2 < x"),
  )
  inspect(
    @symprint.to_string(parse_expr("1 != 2 < x")),
    content=parse_expr_sstr("1 != 2 < x"),
  )
  inspect(
    @symprint.to_string(parse_expr("x == x < y")),
    content=parse_expr_sstr("x == x < y"),
  )
  inspect(
    @symprint.to_string(parse_expr("x == y < z")),
    content=parse_expr_sstr("x == y < z"),
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("x == x", parse_options(evaluate=false)),
    ),
    content=parse_expr_sstr("x == x", evaluate=false),
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("x != y", parse_options(evaluate=false)),
    ),
    content=parse_expr_sstr("x != y", evaluate=false),
  )
  inspect(
    @symprint.to_string(
      parse_expr_with("x < y < z", parse_options(evaluate=false)),
    ),
    content=parse_expr_sstr("x < y < z", evaluate=false),
  )
}
