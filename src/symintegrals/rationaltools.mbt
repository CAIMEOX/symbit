///|
/// Rational antiderivative helpers for the practical closed forms used in the
/// Stage 0-3 `integrate` implementation.

///|
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
                    expr_add(expr_mul(a, @symcore.symbol(var_name)), b),
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
              let lead = expr_div(p, expr_mul(expr_int(2), a))
              let remainder = expr_sub(q, expr_mul(lead, b))
              let log_part = if expr_is_zero(p) {
                expr_zero()
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
                    expr_pow(@symcore.symbol(var_name), expr_int(2)),
                    expr_one(),
                  ),
                ) &&
                expr_is_zero(p) &&
                expr_is_one(q) {
                return Some(@symelem.atan(@symcore.symbol(var_name)))
              }
              match expr_num_value(disc) {
                Some(delta) if delta.compare(@symnum.BigRational::zero()) < 0 => {
                  let pos = expr_neg_one() * disc
                  let root = expr_exact_sqrt(pos)
                  let arg = expr_div(
                    expr_add(
                      expr_mul(
                        expr_int(2),
                        expr_mul(a, @symcore.symbol(var_name)),
                      ),
                      b,
                    ),
                    root,
                  )
                  return Some(
                    log_part +
                    expr_div(
                      expr_mul(expr_int(2), remainder) * @symelem.atan(arg),
                      root,
                    ),
                  )
                }
                Some(delta) if delta.compare(@symnum.BigRational::zero()) > 0 => {
                  let root = expr_exact_sqrt(disc)
                  let arg = expr_div(
                    expr_add(
                      expr_mul(
                        expr_int(2),
                        expr_mul(a, @symcore.symbol(var_name)),
                      ),
                      b,
                    ),
                    root,
                  )
                  return Some(
                    log_part -
                    expr_div(
                      expr_mul(expr_int(2), remainder) *
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
