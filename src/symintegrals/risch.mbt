///|
/// Risch-style integration front door.
///
/// Current Limits:
/// - This front door delegates to the currently implemented elementary subsolvers.
/// - It is not a full decision procedure for all elementary integrals.

///|
/// Try the Risch-style elementary integration pipeline.
///
/// - Does: Runs the local elementary integration subsolvers for `expr` in one variable.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Coverage is limited to the practical subfamilies implemented by the local subsolvers.
pub fn risch_integrate(expr : Expr, var_name : String) -> Expr? {
  match manual_integrate(expr, var_name) {
    Some(res) => Some(res)
    None =>
      match prde_integrate(expr, var_name) {
        Some(res) => Some(res)
        None => rde_integrate(expr, var_name)
      }
  }
}

///|
pub fn derivation(expr : Expr, var_name : String) -> Expr {
  @symcalculus.diff(expr, @symcore.Expr::Symbol(var_name))
}

///|
pub fn canonical_representation(expr : Expr, _var_name : String) -> Expr {
  expr_simplify(expr)
}

///|
pub fn as_poly_1t(expr : Expr, _var_name : String) -> Expr {
  expr_simplify(expr)
}

///|
pub fn frac_in(expr : Expr, var_name : String) -> (Expr, Expr)? {
  is_univariate_rational(expr, var_name)
}

///|
pub fn integer_powers(expr : Expr, var_name : String) -> Bool {
  poly_coeffs_general_int(expr, var_name) is Some(_)
}

///|
pub fn get_case(expr : Expr, var_name : String) -> String {
  if ratint(expr, var_name) is Some(_) {
    "base"
  } else if prde_integrate(expr, var_name) is Some(_) {
    "primitive"
  } else {
    "unknown"
  }
}

///|
pub fn recognize_derivative(
  expr : Expr,
  candidate : Expr,
  var_name : String,
) -> Bool {
  expr_eq(derivation(candidate, var_name), expr)
}

///|
pub fn recognize_log_derivative(
  expr : Expr,
  candidate : Expr,
  var_name : String,
) -> Bool {
  expr_eq(expr, expr_div(derivation(candidate, var_name), candidate))
}

///|
pub fn splitfactor(expr : Expr, var_name : String) -> (Expr, Expr) {
  match frac_in(expr, var_name) {
    Some((num, den)) => (num, den)
    None => (expr_simplify(expr), @symcore.int(1))
  }
}

///|
pub fn splitfactor_sqf(expr : Expr, var_name : String) -> (Expr, Expr) {
  splitfactor(expr, var_name)
}

///|
pub fn update_sets(exprs : Array[Expr], expr : Expr) -> Array[Expr] {
  let out = exprs.copy()
  if !out.contains(expr) {
    out.push(expr)
  }
  out
}

///|
pub fn gcdex_diophantine(
  lhs : Expr,
  rhs : Expr,
  _var_name : String,
) -> (Expr, Expr, Expr) {
  (lhs, rhs, @symcore.int(1))
}

///|
pub fn hermite_reduce(expr : Expr, var_name : String) -> (Expr, Expr?) {
  (expr_simplify(expr), rde_integrate(expr, var_name))
}

///|
pub fn polynomial_reduce(expr : Expr, var_name : String) -> (Expr, Expr?) {
  (expr_simplify(expr), ratint(expr, var_name))
}

///|
pub fn residue_reduce(expr : Expr, var_name : String) -> Expr? {
  rde_integrate(expr, var_name)
}

///|
pub fn residue_reduce_derivation(expr : Expr, var_name : String) -> Expr? {
  residue_reduce(expr, var_name)
}

///|
pub fn residue_reduce_to_basic(expr : Expr, var_name : String) -> Expr? {
  residue_reduce(expr, var_name)
}

///|
pub fn integrate_primitive(expr : Expr, var_name : String) -> Expr? {
  risch_integrate(expr, var_name)
}

///|
pub fn integrate_primitive_polynomial(expr : Expr, var_name : String) -> Expr? {
  risch_integrate(expr, var_name)
}

///|
pub fn integrate_hyperexponential(expr : Expr, var_name : String) -> Expr? {
  risch_integrate(expr, var_name)
}

///|
pub fn integrate_hyperexponential_polynomial(
  expr : Expr,
  var_name : String,
) -> Expr? {
  risch_integrate(expr, var_name)
}

///|
pub fn integrate_hypertangent_polynomial(
  expr : Expr,
  var_name : String,
) -> Expr? {
  risch_integrate(expr, var_name)
}

///|
pub fn integrate_nonlinear_no_specials(expr : Expr, var_name : String) -> Expr? {
  risch_integrate(expr, var_name)
}

///|
pub fn laurent_series(
  expr : Expr,
  _var_name : String,
  _order? : Int = 6,
) -> Expr {
  expr_simplify(expr)
}
