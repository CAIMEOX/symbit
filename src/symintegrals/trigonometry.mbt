///|
/// Trigonometric integration helpers for the common closed forms used by the
/// main `integrate` dispatcher.

///|
fn trig_linear_arg(expr : Expr, var_name : String) -> (String, Expr, Expr)? {
  let simplified = expr_simplify(expr)
  match (@symcore.application_name(simplified), @symcore.application_args(simplified)) {
    (Some(name), Some([arg])) =>
      match linear_coeffs(arg, var_name) {
        Some((a, b)) if !expr_is_zero(a) => Some((name, a, b))
        _ => None
      }
    _ => None
  }
}

///|
/// Trigonometric-pattern integrator for one variable.
pub fn trigintegrate(expr : Expr, var_name : String) -> Expr? {
  match trig_linear_arg(expr, var_name) {
    Some(("sin", a, b)) =>
      Some(
        expr_div(
          expr_neg_one() *
          @symelem.cos(expr_add(expr_mul(a, @symcore.symbol(var_name)), b)),
          a,
        ),
      )
    Some(("cos", a, b)) =>
      Some(
        expr_div(
          @symelem.sin(expr_add(expr_mul(a, @symcore.symbol(var_name)), b)),
          a,
        ),
      )
    Some(("tan", a, b)) =>
      Some(
        expr_div(
          expr_neg_one() *
          @symelem.log(
            @symelem.cos(expr_add(expr_mul(a, @symcore.symbol(var_name)), b)),
          ),
          a,
        ),
      )
    Some(("cot", a, b)) =>
      Some(
        expr_div(
          @symelem.log(
            @symelem.sin(expr_add(expr_mul(a, @symcore.symbol(var_name)), b)),
          ),
          a,
        ),
      )
    Some(("sinh", a, b)) =>
      Some(
        expr_div(
          @symelem.cosh(expr_add(expr_mul(a, @symcore.symbol(var_name)), b)),
          a,
        ),
      )
    Some(("cosh", a, b)) =>
      Some(
        expr_div(
          @symelem.sinh(expr_add(expr_mul(a, @symcore.symbol(var_name)), b)),
          a,
        ),
      )
    Some(("tanh", a, b)) =>
      Some(
        expr_div(
          @symelem.log(
            @symelem.cosh(expr_add(expr_mul(a, @symcore.symbol(var_name)), b)),
          ),
          a,
        ),
      )
    Some(("coth", a, b)) =>
      Some(
        expr_div(
          @symelem.log(
            @symelem.sinh(expr_add(expr_mul(a, @symcore.symbol(var_name)), b)),
          ),
          a,
        ),
      )
    _ =>
      match expr_simplify(expr) {
        @symcore.Expr::Pow(base, exp) if expr_eq(exp, expr_int(2)) =>
          match trig_linear_arg(base, var_name) {
            Some(("sec", a, b)) =>
              Some(
                expr_div(
                  @symelem.tan(
                    expr_add(expr_mul(a, @symcore.symbol(var_name)), b),
                  ),
                  a,
                ),
              )
            Some(("csc", a, b)) =>
              Some(
                expr_div(
                  expr_neg_one() *
                  @symelem.cot(
                    expr_add(expr_mul(a, @symcore.symbol(var_name)), b),
                  ),
                  a,
                ),
              )
            Some(("sin", a, b)) => {
              let arg = expr_add(expr_mul(a, @symcore.symbol(var_name)), b)
              Some(
                @symcore.symbol(var_name) * expr_rat(1, 2) -
                expr_div(
                  @symelem.sin(expr_mul(expr_int(2), arg)),
                  expr_mul(expr_int(4), a),
                ),
              )
            }
            Some(("cos", a, b)) => {
              let arg = expr_add(expr_mul(a, @symcore.symbol(var_name)), b)
              Some(
                @symcore.symbol(var_name) * expr_rat(1, 2) +
                expr_div(
                  @symelem.sin(expr_mul(expr_int(2), arg)),
                  expr_mul(expr_int(4), a),
                ),
              )
            }
            _ => None
          }
        @symcore.Expr::Mul(args) if args.length() == 2 => {
          let left = args[0]
          let right = args[1]
          match
            (trig_linear_arg(left, var_name), trig_linear_arg(right, var_name)) {
            (Some(("sin", a1, b1)), Some(("cos", a2, b2))) if expr_eq(a1, a2) &&
              expr_eq(b1, b2) => {
              let arg = expr_add(expr_mul(a1, @symcore.symbol(var_name)), b1)
              Some(
                expr_div(
                  expr_pow(@symelem.sin(arg), expr_int(2)),
                  expr_mul(expr_int(2), a1),
                ),
              )
            }
            (Some(("cos", a1, b1)), Some(("sin", a2, b2))) if expr_eq(a1, a2) &&
              expr_eq(b1, b2) => {
              let arg = expr_add(expr_mul(a1, @symcore.symbol(var_name)), b1)
              Some(
                expr_div(
                  expr_pow(@symelem.sin(arg), expr_int(2)),
                  expr_mul(expr_int(2), a1),
                ),
              )
            }
            _ => None
          }
        }
        _ => None
      }
  }
}
