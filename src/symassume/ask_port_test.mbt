///|
fn tri_to_string(value : Tri) -> String {
  match value {
    Tri::True => "True"
    Tri::False => "False"
    Tri::Unknown => "None"
  }
}

///|
fn ask_result_to_string(result : Result[Tri, AskError]) -> String {
  match result {
    Ok(v) => tri_to_string(v)
    Err(AskError::InconsistentAssumptions) => "InconsistentAssumptions"
  }
}

///|
fn assert_ask_parity(
  proposition : Query,
  assumptions? : Query = query_true(),
  env? : AssumeEnv = {},
) -> Unit raise {
  let ours = ask_result_to_string(try? ask(proposition, assumptions~, env~))
  let oracle = @sympy_assumptions.ask_query_str(
    query_to_sympy(proposition),
    assumptions=query_to_sympy(and_q([assumptions, env_to_query(env)])),
  )
  guard ours == oracle else {
    println(
      "ask mismatch: ours=\{ours} oracle=\{oracle}; proposition=\{query_to_sympy(proposition)}; assumptions=\{query_to_sympy(assumptions)}; env=\{query_to_sympy(env_to_query(env))}",
    )
    fail(
      "ask mismatch: ours=\{ours} oracle=\{oracle}; proposition=\{query_to_sympy(proposition)}; assumptions=\{query_to_sympy(assumptions)}",
    )
  }
}

///|
fn assert_ask_global_parity(
  proposition : Query,
  context : Array[Query],
  assumptions? : Query = query_true(),
  env? : AssumeEnv = {},
) -> Unit raise {
  clear_global_assumptions()
  for q in context {
    add_global_assumption(q)
  }
  let ours = ask_result_to_string(
    try? ask_global(proposition, assumptions~, env~),
  )
  let oracle = @sympy_assumptions.ask_query_str(
    query_to_sympy(proposition),
    assumptions=query_to_sympy(
      and_q([assumptions, and_q(context), env_to_query(env)]),
    ),
  )
  clear_global_assumptions()
  guard ours == oracle else {
    println(
      "ask_global mismatch: ours=\{ours} oracle=\{oracle}; proposition=\{query_to_sympy(proposition)}; assumptions=\{query_to_sympy(assumptions)}; context=\{query_to_sympy(and_q(context))}",
    )
    fail(
      "ask_global mismatch: ours=\{ours} oracle=\{oracle}; proposition=\{query_to_sympy(proposition)}",
    )
  }
}

///|
fn assert_unary_keys_parity(
  keys : Array[PredicateKey],
  expr : @symcore.Expr,
  assumptions? : Query = query_true(),
) -> Unit {
  for key in keys {
    try! assert_ask_parity(q1(key, expr), assumptions~)
  }
}

///|
test "symassume ask: implication chain parity" {
  let x = @symcore.symbol("x")
  try! assert_ask_parity(q_nonzero(x), assumptions=q_positive(x))
  try! assert_ask_parity(q_nonnegative(x), assumptions=q_positive(x))
  try! assert_ask_parity(q_integer(x), assumptions=q_even(x))
  try! assert_ask_parity(or_q([q_even(x), q_odd(x)]), assumptions=q_integer(x))
  try! assert_ask_parity(q_integer(x), assumptions=or_q([q_even(x), q_odd(x)]))
}

///|
test "symassume ask: numeric parity" {
  try! assert_ask_parity(q_zero(@symcore.int(0)))
  try! assert_ask_parity(q_nonzero(@symcore.int(7)))
  try! assert_ask_parity(q_even(@symcore.int(8)))
  try! assert_ask_parity(q_odd(@symcore.int(9)))
  try! assert_ask_parity(q_prime(@symcore.int(7)))
  try! assert_ask_parity(q_composite(@symcore.int(9)))
  try! assert_ask_parity(q_gt(@symcore.int(5), @symcore.int(3)))
  try! assert_ask_parity(q_eq(@symcore.int(5), @symcore.int(5)))
}

///|
test "symassume ask: logical combinations parity" {
  let x = @symcore.symbol("x")
  try! assert_ask_parity(
    not_q(q_zero(x)),
    assumptions=and_q([q_real(x), q_nonzero(x)]),
  )
  try! assert_ask_parity(
    implies_q(q_positive(x), q_nonnegative(x)),
    assumptions=q_real(x),
  )
  try! assert_ask_parity(
    equivalent_q([q_nonzero(x), or_q([q_positive(x), q_negative(x)])]),
    assumptions=q_real(x),
  )
}

///|
test "symassume ask: inconsistent assumptions parity" {
  let x = @symcore.symbol("x")
  try! assert_ask_parity(q_integer(x), assumptions=and_q([q_even(x), q_odd(x)]))
}

///|
test "symassume ask: env parity" {
  let env = assume_env([
    ("x", symbol_facts(is_positive=Tri::True)),
    ("n", symbol_facts(is_integer=Tri::True, is_nonnegative=Tri::True)),
  ])
  let x = @symcore.symbol("x")
  let n = @symcore.symbol("n")
  try! assert_ask_parity(q_positive(x), env~)
  try! assert_ask_parity(q_nonzero(x), env~)
  try! assert_ask_parity(q_integer(n), env~)
  try! assert_ask_parity(q_nonnegative(n), env~)
}

///|
test "symassume ask: eq substitution parity" {
  let x = @symcore.symbol("x")
  let eq_two = q_eq(x, @symcore.int(2))
  try! assert_ask_parity(q_integer(x), assumptions=eq_two)
  try! assert_ask_parity(q_rational(x), assumptions=eq_two)
  try! assert_ask_parity(q_real(x), assumptions=eq_two)
  try! assert_ask_parity(q_positive(x), assumptions=eq_two)
  try! assert_ask_parity(q_nonzero(x), assumptions=eq_two)
  try! assert_ask_parity(q_even(x), assumptions=eq_two)
  try! assert_ask_parity(q_prime(x), assumptions=eq_two)
  try! assert_ask_parity(q_composite(x), assumptions=eq_two)
}

///|
test "symassume ask: relation chain parity" {
  let x = @symcore.symbol("x")
  try! assert_ask_parity(q_ge(@symcore.int(5), @symcore.int(5)))
  try! assert_ask_parity(q_le(@symcore.int(5), @symcore.int(5)))
  try! assert_ask_parity(q_gt(@symcore.int(5), @symcore.int(5)))
  try! assert_ask_parity(q_lt(@symcore.int(5), @symcore.int(5)))
  try! assert_ask_parity(q_nonzero(x), assumptions=q_gt(x, @symcore.int(0)))
  try! assert_ask_parity(q_real(x), assumptions=q_gt(x, @symcore.int(0)))
}

///|
test "symassume ask: global assumptions parity" {
  let x = @symcore.symbol("x")
  try! assert_ask_global_parity(q_nonzero(x), [q_positive(x)])
  try! assert_ask_global_parity(q_nonnegative(x), [q_positive(x)])
  try! assert_ask_global_parity(q_integer(x), [or_q([q_even(x), q_odd(x)])])
}

///|
test "symassume ask: infinity predicate parity" {
  let oo = @symcore.symbol("oo")
  try! assert_ask_parity(q_infinite(oo))
  try! assert_ask_parity(q_finite(oo))
  try! assert_ask_parity(q_extended_real(oo))
  try! assert_ask_parity(q_positive_infinite(oo))
  try! assert_ask_parity(q_negative_infinite(oo))
  try! assert_ask_parity(q_extended_positive(oo))
  try! assert_ask_parity(q_extended_nonnegative(oo))
  try! assert_ask_parity(q_extended_nonzero(oo))
}

///|
test "symassume ask: unary predicate surface parity (numeric)" {
  let keys : Array[PredicateKey] = [
    PredicateKey::Hermitian,
    PredicateKey::Antihermitian,
    PredicateKey::Real,
    PredicateKey::ExtendedReal,
    PredicateKey::Imaginary,
    PredicateKey::Complex,
    PredicateKey::Algebraic,
    PredicateKey::Transcendental,
    PredicateKey::Integer,
    PredicateKey::NonInteger,
    PredicateKey::Rational,
    PredicateKey::Irrational,
    PredicateKey::Finite,
    PredicateKey::Infinite,
    PredicateKey::Positive,
    PredicateKey::Negative,
    PredicateKey::Zero,
    PredicateKey::Nonzero,
    PredicateKey::Nonpositive,
    PredicateKey::Nonnegative,
    PredicateKey::Even,
    PredicateKey::Odd,
    PredicateKey::Prime,
    PredicateKey::Composite,
    PredicateKey::Commutative,
  ]
  assert_unary_keys_parity(keys, @symcore.int(0))
  assert_unary_keys_parity(keys, @symcore.int(2))
  assert_unary_keys_parity(keys, @symcore.int(-3))
}

///|
test "symassume ask: symbolic implication surface parity" {
  let x = @symcore.symbol("x")
  try! assert_ask_parity(q_real(x), assumptions=q_positive(x))
  try! assert_ask_parity(q_complex(x), assumptions=q_positive(x))
  try! assert_ask_parity(q_nonzero(x), assumptions=q_positive(x))
  try! assert_ask_parity(q_nonnegative(x), assumptions=q_positive(x))
  try! assert_ask_parity(q_finite(x), assumptions=q_complex(x))
  try! assert_ask_parity(q_algebraic(x), assumptions=q_rational(x))
  try! assert_ask_parity(q_rational(x), assumptions=q_integer(x))
  try! assert_ask_parity(q_integer(x), assumptions=q_even(x))
  try! assert_ask_parity(q_integer(x), assumptions=q_odd(x))
}

///|
test "symassume ask: structural propagation parity" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  try! assert_ask_parity(
    q_complex(@symcore.add([x, @symcore.int(1)])),
    assumptions=q_real(x),
  )
  try! assert_ask_parity(
    q_finite(@symcore.add([x, @symcore.int(1)])),
    assumptions=q_real(x),
  )
  try! assert_ask_parity(
    q_nonzero(@symcore.add([x, @symcore.int(1)])),
    assumptions=q_positive(x),
  )
  try! assert_ask_parity(
    q_extended_nonnegative(@symcore.add([x, @symcore.int(1)])),
    assumptions=q_nonnegative(x),
  )
  try! assert_ask_parity(
    q_imaginary(@symcore.mul([i, x])),
    assumptions=q_real(x),
  )
}

///|
test "symassume ask: named constants parity" {
  let keys : Array[PredicateKey] = [
    PredicateKey::Hermitian,
    PredicateKey::Antihermitian,
    PredicateKey::Real,
    PredicateKey::ExtendedReal,
    PredicateKey::Imaginary,
    PredicateKey::Complex,
    PredicateKey::Algebraic,
    PredicateKey::Transcendental,
    PredicateKey::Integer,
    PredicateKey::NonInteger,
    PredicateKey::Rational,
    PredicateKey::Irrational,
    PredicateKey::Finite,
    PredicateKey::Infinite,
    PredicateKey::PositiveInfinite,
    PredicateKey::NegativeInfinite,
    PredicateKey::Positive,
    PredicateKey::Negative,
    PredicateKey::Zero,
    PredicateKey::ExtendedPositive,
    PredicateKey::ExtendedNegative,
    PredicateKey::Nonzero,
    PredicateKey::Nonpositive,
    PredicateKey::Nonnegative,
    PredicateKey::ExtendedNonzero,
    PredicateKey::ExtendedNonpositive,
    PredicateKey::ExtendedNonnegative,
    PredicateKey::Even,
    PredicateKey::Odd,
    PredicateKey::Prime,
    PredicateKey::Composite,
    PredicateKey::Commutative,
  ]
  for c in ["I", "oo", "-oo", "zoo", "pi", "E"] {
    assert_unary_keys_parity(keys, @symcore.symbol(c))
  }
}

///|
test "symassume ask: matrix and tensor implication parity" {
  let x = @symcore.symbol("x")
  try! assert_ask_parity(q_upper_triangular(x), assumptions=q_diagonal(x))
  try! assert_ask_parity(q_lower_triangular(x), assumptions=q_diagonal(x))
  try! assert_ask_parity(q_triangular(x), assumptions=q_diagonal(x))
  try! assert_ask_parity(q_symmetric(x), assumptions=q_diagonal(x))
  try! assert_ask_parity(q_normal(x), assumptions=q_diagonal(x))
  try! assert_ask_parity(q_square(x), assumptions=q_diagonal(x))
  try! assert_ask_parity(q_triangular(x), assumptions=q_upper_triangular(x))
  try! assert_ask_parity(q_triangular(x), assumptions=q_lower_triangular(x))
  try! assert_ask_parity(q_triangular(x), assumptions=q_unit_triangular(x))
  try! assert_ask_parity(q_square(x), assumptions=q_symmetric(x))
  try! assert_ask_parity(q_square(x), assumptions=q_normal(x))
  try! assert_ask_parity(q_unitary(x), assumptions=q_orthogonal(x))
  try! assert_ask_parity(q_invertible(x), assumptions=q_orthogonal(x))
  try! assert_ask_parity(q_normal(x), assumptions=q_orthogonal(x))
  try! assert_ask_parity(q_invertible(x), assumptions=q_unitary(x))
  try! assert_ask_parity(q_normal(x), assumptions=q_unitary(x))
  try! assert_ask_parity(q_invertible(x), assumptions=q_positive_definite(x))
  try! assert_ask_parity(q_fullrank(x), assumptions=q_invertible(x))
  try! assert_ask_parity(q_real_elements(x), assumptions=q_integer_elements(x))
  try! assert_ask_parity(q_complex_elements(x), assumptions=q_real_elements(x))
  try! assert_ask_parity(
    q_complex_elements(x),
    assumptions=q_integer_elements(x),
  )
  try! assert_ask_parity(q_singular(x), assumptions=q_invertible(x))
  try! assert_ask_parity(q_invertible(x), assumptions=q_singular(x))
}

///|
test "symassume ask: relation symbolic implication parity" {
  let x = @symcore.symbol("x")
  let z0 = @symcore.int(0)
  try! assert_ask_parity(q_eq(x, z0), assumptions=q_zero(x))
  try! assert_ask_parity(q_ne(x, z0), assumptions=q_nonzero(x))
  try! assert_ask_parity(q_gt(x, z0), assumptions=q_positive(x))
  try! assert_ask_parity(q_lt(x, z0), assumptions=q_negative(x))
  try! assert_ask_parity(q_ge(x, z0), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_ne(x, z0), assumptions=q_positive(x))
  try! assert_ask_parity(q_ne(x, z0), assumptions=q_negative(x))

  // SymPy currently keeps these reverse directions unknown.
  try! assert_ask_parity(q_zero(x), assumptions=q_eq(x, z0))
  try! assert_ask_parity(q_positive(x), assumptions=q_gt(x, z0))
  try! assert_ask_parity(q_negative(x), assumptions=q_lt(x, z0))
  try! assert_ask_parity(q_nonzero(x), assumptions=q_gt(x, z0))
  try! assert_ask_parity(q_nonnegative(x), assumptions=q_ge(x, z0))
}

///|
test "symassume ask: relation nonzero-constant parity" {
  let x = @symcore.symbol("x")
  let m1 = @symcore.int(-1)
  let p1 = @symcore.int(1)
  let z0 = @symcore.int(0)

  // positive(x)
  try! assert_ask_parity(q_eq(x, m1), assumptions=q_positive(x))
  try! assert_ask_parity(q_ne(x, m1), assumptions=q_positive(x))
  try! assert_ask_parity(q_ge(x, m1), assumptions=q_positive(x))
  try! assert_ask_parity(q_lt(x, m1), assumptions=q_positive(x))
  try! assert_ask_parity(q_gt(x, z0), assumptions=q_positive(x))
  try! assert_ask_parity(q_le(x, z0), assumptions=q_positive(x))

  // nonnegative(x)
  try! assert_ask_parity(q_eq(x, m1), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_ne(x, m1), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_ge(x, m1), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_lt(x, m1), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_ge(x, z0), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_lt(x, z0), assumptions=q_nonnegative(x))

  // zero(x)
  try! assert_ask_parity(q_eq(x, p1), assumptions=q_zero(x))
  try! assert_ask_parity(q_ne(x, p1), assumptions=q_zero(x))
  try! assert_ask_parity(q_gt(x, p1), assumptions=q_zero(x))
  try! assert_ask_parity(q_le(x, p1), assumptions=q_zero(x))
  try! assert_ask_parity(q_eq(x, m1), assumptions=q_zero(x))
  try! assert_ask_parity(q_ne(x, m1), assumptions=q_zero(x))
  try! assert_ask_parity(q_ge(x, m1), assumptions=q_zero(x))
  try! assert_ask_parity(q_lt(x, m1), assumptions=q_zero(x))

  // nonzero(x)
  try! assert_ask_parity(q_eq(x, z0), assumptions=q_nonzero(x))
  try! assert_ask_parity(q_ne(x, z0), assumptions=q_nonzero(x))
}

///|
test "symassume ask: relation linear form parity" {
  let x = @symcore.symbol("x")
  let plus1 = @symcore.add([x, @symcore.int(1)])
  let minus1 = @symcore.add([x, @symcore.int(-1)])
  let z0 = @symcore.int(0)

  try! assert_ask_parity(q_eq(plus1, z0), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_ne(plus1, z0), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_ge(plus1, z0), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_lt(plus1, z0), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_gt(plus1, z0), assumptions=q_nonnegative(x))
  try! assert_ask_parity(q_le(plus1, z0), assumptions=q_nonnegative(x))

  try! assert_ask_parity(q_eq(minus1, z0), assumptions=q_zero(x))
  try! assert_ask_parity(q_ne(minus1, z0), assumptions=q_zero(x))
  try! assert_ask_parity(q_gt(minus1, z0), assumptions=q_zero(x))
  try! assert_ask_parity(q_le(minus1, z0), assumptions=q_zero(x))
  try! assert_ask_parity(q_ge(minus1, z0), assumptions=q_zero(x))
  try! assert_ask_parity(q_lt(minus1, z0), assumptions=q_zero(x))
}

///|
test "symassume ask: matrix positive_definite fine parity" {
  let x = @symcore.symbol("x")
  let n = @symcore.symbol("n")
  let m = @symcore.function("MatrixSymbol", [x, n, n])
  try! assert_ask_parity(q_hermitian(m), assumptions=q_positive_definite(m))
  try! assert_ask_parity(q_antihermitian(m), assumptions=q_positive_definite(m))
  try! assert_ask_parity(q_symmetric(m), assumptions=q_positive_definite(m))
}
