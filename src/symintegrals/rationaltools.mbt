///|
/// Rational antiderivative front door.
///
/// Current Limits:
/// - Coverage is focused on the rational families recognized by the current integration pipeline.
/// - Unsupported rational shapes return `None` instead of an unevaluated object.

///|
/// Integrate one rational function.
///
/// - Does: Tries the local rational antiderivative rules for `expr` in one variable.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Only the currently recognized rational families are covered.
pub fn ratint(expr : Expr, var_name : String) -> Expr? {
  match is_univariate_rational(expr, var_name) {
    Some((num, den)) =>
      match
        (poly_coeffs_upto2(num, var_name), poly_coeffs_upto2(den, var_name)) {
        (Some(nc), Some(dc)) => {
          if !(expr_is_zero(dc[1]) && expr_is_zero(dc[2])) {
            if expr_is_zero(dc[2]) &&
              !expr_is_zero(dc[1]) &&
              expr_is_zero(nc[1]) &&
              expr_is_zero(nc[2]) {
              let a = dc[1]
              let b = dc[0]
              let c = nc[0]
              return Some(
                expr_div(
                  c *
                  @symelem.log(
                    expr_add(expr_mul(a, @symcore.Expr::Symbol(var_name)), b),
                  ),
                  a,
                ),
              )
            }
            if !expr_is_zero(dc[2]) && expr_is_zero(nc[2]) {
              let a = dc[2]
              let b = dc[1]
              let c = dc[0]
              let p = nc[1]
              let q = nc[0]
              let lead = expr_div(p, expr_mul(@symcore.int(2), a))
              let remainder = expr_sub(q, expr_mul(lead, b))
              let log_part = if expr_is_zero(p) {
                @symcore.int(0)
              } else {
                lead * @symelem.log(den)
              }
              if expr_is_zero(remainder) {
                return Some(log_part)
              }
              let disc = quadratic_discriminant(a, b, c)
              if expr_eq(
                  den,
                  expr_add(
                    expr_pow(@symcore.Expr::Symbol(var_name), @symcore.int(2)),
                    @symcore.int(1),
                  ),
                ) &&
                expr_is_zero(p) &&
                expr_is_one(q) {
                return Some(@symelem.atan(@symcore.Expr::Symbol(var_name)))
              }
              match expr_num_value(disc) {
                Some(delta) if delta.compare(@symnum.BigRational::zero()) < 0 => {
                  let pos = @symcore.int(-1) * disc
                  let root = expr_exact_sqrt(pos)
                  let arg = expr_div(
                    expr_add(
                      expr_mul(
                        @symcore.int(2),
                        expr_mul(a, @symcore.Expr::Symbol(var_name)),
                      ),
                      b,
                    ),
                    root,
                  )
                  return Some(
                    log_part +
                    expr_div(
                      expr_mul(@symcore.int(2), remainder) * @symelem.atan(arg),
                      root,
                    ),
                  )
                }
                Some(delta) if delta.compare(@symnum.BigRational::zero()) > 0 => {
                  let root = expr_exact_sqrt(disc)
                  let arg = expr_div(
                    expr_add(
                      expr_mul(
                        @symcore.int(2),
                        expr_mul(a, @symcore.Expr::Symbol(var_name)),
                      ),
                      b,
                    ),
                    root,
                  )
                  return Some(
                    log_part -
                    expr_div(
                      expr_mul(@symcore.int(2), remainder) *
                      @symcore.raw_function("atanh", [arg]),
                      root,
                    ),
                  )
                }
                _ => ()
              }
            }
          }
          None
        }
        _ => None
      }
    None => None
  }
}
