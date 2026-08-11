///|
fn tri_repr(value : Tri) -> String {
  match value {
    True => "True"
    False => "False"
    Unknown => "None"
  }
}

///|
fn assert_predicate_parity(
  label : String,
  ours : Tri,
  oracle : String,
) -> Unit raise {
  let got = tri_repr(ours)
  guard got == oracle else {
    fail("predicate mismatch for \{label}: ours=\{got} oracle=\{oracle}")
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
    assume_is_zero(expr, env~),
    is_zero(expr, env~),
  )
  assert_predicate_parity(
    "\{label}.is_nonzero",
    assume_is_nonzero(expr, env~),
    is_nonzero(expr, env~),
  )
  assert_predicate_parity(
    "\{label}.is_integer",
    assume_is_integer(expr, env~),
    is_integer(expr, env~),
  )
  assert_predicate_parity(
    "\{label}.is_rational",
    assume_is_rational(expr, env~),
    is_rational(expr, env~),
  )
  assert_predicate_parity(
    "\{label}.is_real",
    assume_is_real(expr, env~),
    is_real(expr, env~),
  )
  assert_predicate_parity(
    "\{label}.is_positive",
    assume_is_positive(expr, env~),
    is_positive(expr, env~),
  )
  assert_predicate_parity(
    "\{label}.is_nonnegative",
    assume_is_nonnegative(expr, env~),
    is_nonnegative(expr, env~),
  )
}

///|
test "symassume tri logic" {
  inspect(tri_not(True), content="False")
  inspect(tri_not(False), content="True")
  inspect(tri_not(Unknown), content="Unknown")
  inspect(tri_and(True, Unknown), content="Unknown")
  inspect(tri_and(False, Unknown), content="False")
  inspect(tri_or(False, Unknown), content="Unknown")
  inspect(tri_or(True, Unknown), content="True")
}

///|
test "symassume facts normalization" {
  let facts = symbol_facts(is_positive=True)
  inspect(facts.is_nonnegative, content="True")
  inspect(facts.is_nonzero, content="True")
  inspect(facts.is_real, content="True")
  inspect(facts.is_zero, content="False")
}

///|
test "symassume numeric predicate parity" {
  let env = empty_env()
  assert_all_predicates(@symcore.int(0), env, "zero")
  assert_all_predicates(@symcore.int(2), env, "two")
  let half = @symcore.rational_from_ints(1, 2)
  assert_all_predicates(half, env, "half")
  let expr = @symcore.mul([@symcore.int(-3), half])
  assert_all_predicates(expr, env, "mul")
}

///|
test "symassume symbolic parity basic algebra" {
  let env = assume_env([
    ("x", symbol_facts(is_integer=True)),
    ("p", symbol_facts(is_positive=True)),
    ("n", symbol_facts(is_nonnegative=True)),
    ("r", symbol_facts(is_real=True)),
    ("nz", symbol_facts(is_nonzero=True, is_real=True)),
  ])
  let x = @symcore.Expr::Symbol("x")
  let p = @symcore.Expr::Symbol("p")
  let n = @symcore.Expr::Symbol("n")
  let nz = @symcore.Expr::Symbol("nz")

  assert_all_predicates(x, env, "x")
  assert_all_predicates(@symcore.add([x, @symcore.int(1)]), env, "x_plus_1")
  assert_all_predicates(@symcore.pow(p, @symcore.int(2)), env, "p_sq")
  assert_all_predicates(@symcore.pow(n, @symcore.int(2)), env, "n_sq")
  assert_all_predicates(@symcore.pow(nz, @symcore.int(-1)), env, "inv_nz")
}

///|
test "symassume symbolic parity elementary functions" {
  let env = assume_env([
    ("p", symbol_facts(is_positive=True)),
    ("n", symbol_facts(is_nonnegative=True)),
    ("r", symbol_facts(is_real=True)),
    ("nz", symbol_facts(is_nonzero=True, is_real=True)),
  ])
  let p = @symcore.Expr::Symbol("p")
  let n = @symcore.Expr::Symbol("n")
  let r = @symcore.Expr::Symbol("r")
  let nz = @symcore.Expr::Symbol("nz")

  assert_all_predicates(@symcore.function("exp", [r]), env, "exp_r")
  assert_all_predicates(@symcore.function("log", [p]), env, "log_p")
  assert_all_predicates(@symcore.function("sqrt", [n]), env, "sqrt_n")
  assert_all_predicates(@symcore.function("Abs", [nz]), env, "abs_nz")
}
