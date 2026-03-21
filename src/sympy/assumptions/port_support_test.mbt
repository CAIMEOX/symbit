///|
using @symassume {
  type AskError,
  type AssumeEnv,
  type PredicateKey,
  type Query,
  type Tri,
  add_global_assumption,
  and_q,
  ask,
  ask_global,
  assume_env,
  clear_global_assumptions,
  empty_env,
  env_to_query,
  equivalent_q,
  implies_q,
  not_q,
  or_q,
  q1,
  q_algebraic,
  q_antihermitian,
  q_complex,
  q_complex_elements,
  q_composite,
  q_diagonal,
  q_eq,
  q_even,
  q_extended_nonnegative,
  q_extended_nonzero,
  q_extended_positive,
  q_extended_real,
  q_finite,
  q_fullrank,
  q_ge,
  q_gt,
  q_hermitian,
  q_imaginary,
  q_infinite,
  q_integer,
  q_integer_elements,
  q_invertible,
  q_le,
  q_lower_triangular,
  q_lt,
  q_ne,
  q_negative,
  q_negative_infinite,
  q_nonnegative,
  q_nonzero,
  q_normal,
  q_odd,
  q_orthogonal,
  q_positive,
  q_positive_definite,
  q_positive_infinite,
  q_prime,
  q_rational,
  q_real,
  q_real_elements,
  q_singular,
  q_square,
  q_symmetric,
  q_triangular,
  q_unit_triangular,
  q_unitary,
  q_upper_triangular,
  q_zero,
  query_to_sympy,
  query_true,
  symbol_facts,
  tri_and,
  tri_not,
  tri_or,
}

///|
fn assume_is_zero(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  @symassume.is_zero(expr, env~)
}

///|
fn assume_is_nonzero(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  @symassume.is_nonzero(expr, env~)
}

///|
fn assume_is_integer(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  @symassume.is_integer(expr, env~)
}

///|
fn assume_is_rational(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  @symassume.is_rational(expr, env~)
}

///|
fn assume_is_real(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  @symassume.is_real(expr, env~)
}

///|
fn assume_is_positive(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  @symassume.is_positive(expr, env~)
}

///|
fn assume_is_nonnegative(expr : @symcore.Expr, env? : AssumeEnv = {}) -> Tri {
  @symassume.is_nonnegative(expr, env~)
}
