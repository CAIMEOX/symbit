///|
/// Meijer-style integration front door.
///
/// Current Limits:
/// - Coverage is limited to the non-elementary families recognized by the current heuristics.
/// - Unsupported cases return `None`.

///|
/// Try the Meijer-style fallback integrator.
///
/// - Does: Searches for non-elementary antiderivatives recognized by the local Meijer-style rules.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Coverage is limited to the currently implemented special-function families.
pub fn meijerg_integrate(expr : Expr, var_name : String) -> Expr? {
  let target = expr_simplify(expr)
  if @symcore.application_has_name(target, "exp", arity=1) {
    match
      extract_erf_scale(@symcore.application_args(target).unwrap()[0], var_name) {
      Some(scale) =>
        Some(
          expr_mul(
            expr_div(sqrt_pi(), @symcore.int(2)),
            @symspec.erf(expr_mul(scale, @symcore.Expr::Symbol(var_name))),
          ),
        )
      None => None
    }
  } else {
    match sincos_division(target, var_name) {
      Some(res) => Some(res)
      None => None
    }
  }
}

///|
fn sincos_division(expr : Expr, var_name : String) -> Expr? {
  let (numerator, den_opt) = extract_division(expr)
  match den_opt {
    None => None
    Some(den) =>
      if !expr_is_symbol(den, var_name) {
        None
      } else if numerator.length() != 1 {
        None
      } else {
        match
          (
            @symcore.application_name(numerator[0]),
            @symcore.application_args(numerator[0]),
          ) {
          (Some("sin"), Some([arg])) =>
            match linear_coeffs(arg, var_name) {
              Some(pair) => {
                let a = pair.0
                let b = pair.1
                if expr_is_zero(b) && !expr_is_zero(a) {
                  Some(
                    @symspec.si(expr_mul(a, @symcore.Expr::Symbol(var_name))),
                  )
                } else {
                  None
                }
              }
              None => None
            }
          (Some("cos"), Some([arg])) =>
            match linear_coeffs(arg, var_name) {
              Some(pair) => {
                let a = pair.0
                let b = pair.1
                if expr_is_zero(b) && !expr_is_zero(a) {
                  Some(
                    @symspec.ci(expr_mul(a, @symcore.Expr::Symbol(var_name))),
                  )
                } else {
                  None
                }
              }
              None => None
            }
          _ => None
        }
      }
  }
}

///|
fn extract_erf_scale(inner : Expr, var_name : String) -> Expr? {
  match poly_coeffs_upto2(expr_simplify(inner), var_name) {
    Some(coeffs) =>
      if !expr_is_zero(coeffs[1]) || !expr_is_zero(coeffs[0]) {
        None
      } else {
        let quad = expr_simplify(coeffs[2])
        if expr_is_negative(quad) {
          Some(expr_sqrt_positive(expr_mul(@symcore.int(-1), quad)))
        } else {
          None
        }
      }
    _ => None
  }
}

///|
fn extract_division(expr : Expr) -> (Array[Expr], Expr?) {
  let simplified = expr_simplify(expr)
  match simplified {
    @symcore.Expr::Pow(base, exp) if expr_is_minus_one(exp) =>
      ([@symcore.int(1)], Some(base))
    @symcore.Expr::Mul(args) => {
      let numerator : Array[Expr] = []
      let denominator : Array[Expr] = []
      for item in args {
        match item {
          @symcore.Expr::Pow(base, exp) if expr_is_minus_one(exp) =>
            denominator.push(base)
          _ => numerator.push(item)
        }
      }
      if denominator.length() == 0 {
        (numerator, None)
      } else {
        let den = if denominator.length() == 1 {
          denominator[0]
        } else {
          expr_simplify(@symcore.mul(denominator))
        }
        (numerator, Some(den))
      }
    }
    _ => ([simplified], None)
  }
}
