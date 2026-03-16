///|
/// Rational differential equation helper surface. For the current Stage 3 core,
/// the exported antiderivative entrypoint reuses the exact rational integrator.

///|
pub fn rde_integrate(expr : Expr, var_name : String) -> Expr? {
  ratint(expr, var_name).map(expr_simplify)
}
