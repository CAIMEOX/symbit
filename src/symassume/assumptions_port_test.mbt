///|
fn tri_repr(value : Tri) -> String {
  match value {
    Tri::True => "True"
    Tri::False => "False"
    Tri::Unknown => "None"
  }
}

///|
fn assert_predicate_parity(
  label : String,
  ours : Tri,
  oracle : Result[String, Error],
) -> Unit raise {
  let expected = match oracle {
    Ok(value) => value
    Err(err) => fail("oracle failure for \{label}: \{err}")
  }
  let got = tri_repr(ours)
  guard got == expected else {
    fail("predicate mismatch \{label}: ours=\{got}, oracle=\{expected}")
  }
}

///|
fn assert_all_predicates(
  expr : @symcore.Expr,
  env : AssumeEnv,
  label : String,
) -> Unit raise {
  assert_predicate_parity(
    "\{label}.is_zero",
    is_zero(expr, env=env),
    try? @sympy_assumptions.is_zero(expr, env=env),
  )
  assert_predicate_parity(
    "\{label}.is_nonzero",
    is_nonzero(expr, env=env),
    try? @sympy_assumptions.is_nonzero(expr, env=env),
  )
  assert_predicate_parity(
    "\{label}.is_integer",
    is_integer(expr, env=env),
    try? @sympy_assumptions.is_integer(expr, env=env),
  )
  assert_predicate_parity(
    "\{label}.is_rational",
    is_rational(expr, env=env),
    try? @sympy_assumptions.is_rational(expr, env=env),
  )
  assert_predicate_parity(
    "\{label}.is_real",
    is_real(expr, env=env),
    try? @sympy_assumptions.is_real(expr, env=env),
  )
  assert_predicate_parity(
    "\{label}.is_positive",
    is_positive(expr, env=env),
    try? @sympy_assumptions.is_positive(expr, env=env),
  )
  assert_predicate_parity(
    "\{label}.is_nonnegative",
    is_nonnegative(expr, env=env),
    try? @sympy_assumptions.is_nonnegative(expr, env=env),
  )
}

///|
test "symassume tri logic" {
  inspect(tri_not(Tri::True), content="False")
  inspect(tri_not(Tri::False), content="True")
  inspect(tri_not(Tri::Unknown), content="Unknown")
  inspect(tri_and(Tri::True, Tri::Unknown), content="Unknown")
  inspect(tri_and(Tri::False, Tri::Unknown), content="False")
  inspect(tri_or(Tri::False, Tri::Unknown), content="Unknown")
  inspect(tri_or(Tri::True, Tri::Unknown), content="True")
}

///|
test "symassume facts normalization" {
  let facts = symbol_facts(is_positive=Tri::True)
  inspect(facts.is_nonnegative, content="True")
  inspect(facts.is_nonzero, content="True")
  inspect(facts.is_real, content="True")
  inspect(facts.is_zero, content="False")
}

///|
test "symassume numeric predicate parity" {
  let env = empty_env()
  try! assert_all_predicates(@symcore.int(0), env, "zero")
  try! assert_all_predicates(@symcore.int(2), env, "two")
  let half = try! @symcore.rational_from_ints(1, 2)
  try! assert_all_predicates(half, env, "half")
  let expr = @symcore.mul([@symcore.int(-3), half])
  try! assert_all_predicates(expr, env, "mul")
}

///|
test "symassume symbolic parity basic algebra" {
  let env = assume_env([
    ("x", symbol_facts(is_integer=Tri::True)),
    ("p", symbol_facts(is_positive=Tri::True)),
    ("n", symbol_facts(is_nonnegative=Tri::True)),
    ("r", symbol_facts(is_real=Tri::True)),
    ("nz", symbol_facts(is_nonzero=Tri::True, is_real=Tri::True)),
  ])
  let x = @symcore.symbol("x")
  let p = @symcore.symbol("p")
  let n = @symcore.symbol("n")
  let nz = @symcore.symbol("nz")

  try! assert_all_predicates(x, env, "x")
  try! assert_all_predicates(@symcore.add([x, @symcore.int(1)]), env, "x_plus_1")
  try! assert_all_predicates(@symcore.pow(p, @symcore.int(2)), env, "p_sq")
  try! assert_all_predicates(@symcore.pow(n, @symcore.int(2)), env, "n_sq")
  try! assert_all_predicates(@symcore.pow(nz, @symcore.int(-1)), env, "inv_nz")
}

///|
test "symassume symbolic parity elementary functions" {
  let env = assume_env([
    ("p", symbol_facts(is_positive=Tri::True)),
    ("n", symbol_facts(is_nonnegative=Tri::True)),
    ("r", symbol_facts(is_real=Tri::True)),
    ("nz", symbol_facts(is_nonzero=Tri::True, is_real=Tri::True)),
  ])
  let p = @symcore.symbol("p")
  let n = @symcore.symbol("n")
  let r = @symcore.symbol("r")
  let nz = @symcore.symbol("nz")

  try! assert_all_predicates(@symcore.function("exp", [r]), env, "exp_r")
  try! assert_all_predicates(@symcore.function("log", [p]), env, "log_p")
  try! assert_all_predicates(@symcore.function("sqrt", [n]), env, "sqrt_n")
  try! assert_all_predicates(@symcore.function("Abs", [nz]), env, "abs_nz")
}
