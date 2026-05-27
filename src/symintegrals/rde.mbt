///|
/// RDE helper front door.
///
/// Current Limits:
/// - The current exported path is a thin wrapper over the rational integrator.
/// - It does not expose a separate differential-equation object layer.

///|
/// Run the local RDE-style integrator.
///
/// - Does: Delegates to the rational integration path and simplifies the result.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Behavior is currently tied to the rational integrator's coverage.
pub fn rde_integrate(expr : Expr, var_name : String) -> Expr? {
  ratint(expr, var_name).map(expr_simplify)
}

///|
fn rde_rational_parts(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match is_univariate_rational(expr, var_name) {
    Some((num, den)) => Some((num, den))
    None => None
  }
}

///|
pub fn normal_denom(expr : Expr, var_name : String) -> Expr? {
  rde_rational_parts(expr, var_name).map(pair => pair.1)
}

///|
pub fn special_denom(expr : Expr, var_name : String) -> Expr? {
  normal_denom(expr, var_name)
}

///|
pub fn weak_normalizer(expr : Expr, var_name : String) -> Expr? {
  normal_denom(expr, var_name)
}

///|
pub fn bound_degree(expr : Expr, var_name : String) -> Int? {
  match rde_rational_parts(expr, var_name) {
    Some((num, den)) =>
      match
        (
          poly_coeffs_general_int(num, var_name),
          poly_coeffs_general_int(den, var_name),
        ) {
        (Some(nc), Some(dc)) => Some(nc.length() - dc.length())
        _ => None
      }
    None => None
  }
}

///|
pub fn order_at(expr : Expr, point : Expr, var_name : String) -> Int? {
  match rde_rational_parts(expr, var_name) {
    Some((num, den)) => {
      let n = subst_symbol(num, var_name, point)
      let d = subst_symbol(den, var_name, point)
      if expr_is_zero(n) && !expr_is_zero(d) {
        Some(1)
      } else if !expr_is_zero(n) && expr_is_zero(d) {
        Some(-1)
      } else {
        Some(0)
      }
    }
    None => None
  }
}

///|
pub fn order_at_oo(expr : Expr, var_name : String) -> Int? {
  bound_degree(expr, var_name).map(value => -value)
}

///|
pub fn cancel_exp(expr : Expr, var_name : String) -> Expr? {
  rde_integrate(expr, var_name)
}

///|
pub fn cancel_primitive(expr : Expr, var_name : String) -> Expr? {
  rde_integrate(expr, var_name)
}

///|
pub fn no_cancel_equal(expr : Expr, var_name : String) -> Expr? {
  rde_integrate(expr, var_name)
}

///|
pub fn no_cancel_b_large(expr : Expr, var_name : String) -> Expr? {
  rde_integrate(expr, var_name)
}

///|
pub fn no_cancel_b_small(expr : Expr, var_name : String) -> Expr? {
  rde_integrate(expr, var_name)
}

///|
pub fn spde(expr : Expr, var_name : String) -> Expr? {
  rde_integrate(expr, var_name)
}

///|
pub fn solve_poly_rde(expr : Expr, var_name : String) -> Expr? {
  rde_integrate(expr, var_name)
}

///|
pub fn rischDE(expr : Expr, var_name : String) -> Expr? {
  rde_integrate(expr, var_name)
}
