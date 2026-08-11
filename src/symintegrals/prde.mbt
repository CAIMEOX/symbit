///|
/// Parametric RDE helper front door.
///
/// Current Limits:
/// - The current exported path is a thin wrapper over the heuristic integrator.
/// - It does not expose a separate parametric differential-equation object layer.

///|
/// Run the local PRDE-style integrator.
///
/// - Does: Delegates to the heuristic integration path and simplifies the result.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Behavior is currently tied to the heuristic integrator's coverage.
pub fn prde_integrate(expr : Expr, var_name : String) -> Expr? {
  heurisch(expr, var_name).map(expr_simplify)
}

///|
pub fn is_deriv_k(expr : Expr, candidate : Expr, var_name : String) -> Bool {
  expr_eq(@symcalculus.diff(candidate, Symbol(var_name)), expr)
}

///|
pub fn is_log_deriv_k_t_radical(
  expr : Expr,
  candidate : Expr,
  var_name : String,
) -> Bool {
  let deriv = @symcalculus.diff(candidate, Symbol(var_name))
  expr_eq(expr, expr_div(deriv, candidate))
}

///|
pub fn is_log_deriv_k_t_radical_in_field(
  expr : Expr,
  candidate : Expr,
  var_name : String,
) -> Bool {
  is_log_deriv_k_t_radical(expr, candidate, var_name)
}

///|
pub fn constant_system(exprs : Array[Expr], var_name : String) -> Array[Expr] {
  exprs.filter(expr => !expr_depends_on(expr, var_name))
}

///|
pub fn real_imag(expr : Expr) -> (Expr, Expr) {
  (@symcore.raw_function("re", [expr]), @symcore.raw_function("im", [expr]))
}

///|
pub fn limited_integrate(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn limited_integrate_reduce(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn param_poly_rischDE(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn param_rischDE(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn parametric_log_deriv(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn parametric_log_deriv_heu(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn poly_linear_constraints(
  exprs : Array[Expr],
  var_name : String,
) -> Array[Expr] {
  constant_system(exprs, var_name)
}

///|
pub fn prde_linear_constraints(
  exprs : Array[Expr],
  var_name : String,
) -> Array[Expr] {
  constant_system(exprs, var_name)
}

///|
pub fn prde_cancel_liouvillian(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn prde_no_cancel_b_large(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn prde_no_cancel_b_small(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn prde_normal_denom(expr : Expr, var_name : String) -> Expr? {
  normal_denom(expr, var_name)
}

///|
pub fn prde_spde(expr : Expr, var_name : String) -> Expr? {
  prde_integrate(expr, var_name)
}

///|
pub fn prde_special_denom(expr : Expr, var_name : String) -> Expr? {
  special_denom(expr, var_name)
}
