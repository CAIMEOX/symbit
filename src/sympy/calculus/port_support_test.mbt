///|
using @symcalculus {
  type BigRational,
  type Expr,
  accum_bounds,
  accum_neg,
  apply_finite_diff,
  diff,
  euler_equations,
  finite_diff_weights,
  periodicity,
  singularities,
}

///|
fn calc_accum_delta(expr : Expr) -> Expr? {
  @symcalculus.accum_delta(expr)
}

///|
fn calc_accum_mid(expr : Expr) -> Expr? {
  @symcalculus.accum_mid(expr)
}

///|
fn calc_accum_add(lhs : Expr, rhs : Expr) -> Expr {
  @symcalculus.accum_add(lhs, rhs)
}

///|
fn calc_accum_sub(lhs : Expr, rhs : Expr) -> Expr {
  @symcalculus.accum_sub(lhs, rhs)
}

///|
fn calc_accum_mul(lhs : Expr, rhs : Expr) -> Expr {
  @symcalculus.accum_mul(lhs, rhs)
}

///|
fn calc_accum_div(lhs : Expr, rhs : Expr) -> Expr {
  @symcalculus.accum_div(lhs, rhs)
}

///|
fn calc_accum_pow(base : Expr, exp : Expr) -> Expr {
  @symcalculus.accum_pow(base, exp)
}

///|
fn calc_accum_abs(expr : Expr) -> Expr {
  @symcalculus.accum_abs(expr)
}
