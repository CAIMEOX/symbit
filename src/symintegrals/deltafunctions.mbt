///|
/// Delta and singularity integration helpers aligned with the practical core of
/// `sympy.integrals.deltafunctions` and `sympy.integrals.singularityfunctions`.

///|
fn extract_dirac_factor(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    @symcore.Expr::Function("DiracDelta", [arg]) if expr_depends_on(
        arg, var_name,
      ) => Some((arg, expr_one()))
    @symcore.Expr::Mul(args) => {
      let rest : Array[Expr] = []
      let mut delta_arg : Expr? = None
      for arg in args {
        match arg {
          @symcore.Expr::Function("DiracDelta", [inner]) if expr_depends_on(
              inner, var_name,
            ) &&
            delta_arg is None => delta_arg = Some(inner)
          _ => rest.push(arg)
        }
      }
      match delta_arg {
        Some(inner) =>
          Some(
            (
              inner,
              if rest.is_empty() {
                expr_one()
              } else {
                expr_simplify(@symcore.mul(rest))
              },
            ),
          )
        None => None
      }
    }
    _ => None
  }
}

///|
/// Split a product into its `DiracDelta(...)` factor and the remaining
/// multiplicative part, if such a factor exists.
pub fn change_mul(node : Expr, var_name : String) -> (Expr?, Expr?) {
  match extract_dirac_factor(node, var_name) {
    Some((arg, rest)) =>
      match delta_root_and_scale(arg, var_name) {
        Some(_) => (Some(@symspec.dirac_delta(arg)), Some(expr_simplify(rest)))
        None => (None, None)
      }
    None => (None, None)
  }
}

///|
fn delta_root_and_scale(arg : Expr, var_name : String) -> (Expr, Expr)? {
  match linear_coeffs(arg, var_name) {
    Some((a, b)) if !expr_is_zero(a) =>
      Some((expr_div(expr_neg_one() * b, a), @symelem.abs(a)))
    _ => None
  }
}

///|
/// Integrate products containing `DiracDelta` over a single variable.
///
/// For bounded integrals this enforces the interval test; for unbounded use it
/// returns the pulled-back value with the usual Heaviside gating.
pub fn deltaintegrate(
  expr : Expr,
  var_name : String,
  lower : Expr?,
  upper : Expr?,
) -> Expr? {
  match extract_dirac_factor(expr, var_name) {
    Some((arg, rest)) =>
      match delta_root_and_scale(arg, var_name) {
        Some((root, scale)) => {
          let value = expr_div(subst_symbol(rest, var_name, root), scale)
          match (lower, upper) {
            (Some(lo0), Some(hi0)) => {
              let lo = lo0
              let hi = hi0
              match
                (expr_num_value(root), expr_num_value(lo), expr_num_value(hi)) {
                (Some(rv), Some(lv), Some(hv)) =>
                  if rv.compare(lv) >= 0 && rv.compare(hv) <= 0 {
                    Some(value)
                  } else {
                    Some(expr_zero())
                  }
                _ =>
                  Some(
                    expr_simplify(
                      value *
                      (
                        @symspec.heaviside(expr_sub(hi, root)) -
                        @symspec.heaviside(expr_sub(lo, root))
                      ),
                    ),
                  )
              }
            }
            _ => Some(value * @symspec.heaviside(arg))
          }
        }
        None => None
      }
    None => None
  }
}
