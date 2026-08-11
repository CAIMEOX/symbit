///|
/// Delta-function integration front doors.
///
/// Current Limits:
/// - Coverage is restricted to the currently recognized `DiracDelta` products and linear roots.
/// - Unsupported cases return `None`.

///|
fn dirac_delta_atom(expr : Expr) -> Expr? {
  if @symcore.application_has_name(expr, "DiracDelta") {
    Some(expr)
  } else {
    None
  }
}

///|
fn split_dirac_linear_term(expr : Expr) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    delta if dirac_delta_atom(delta) is Some(_) =>
      Some((delta, @symcore.int(1)))
    Mul(args) => {
      let rest : Array[Expr] = []
      let mut delta : Expr? = None
      for arg in args {
        match dirac_delta_atom(arg) {
          Some(item) if delta is None => delta = Some(item)
          _ => rest.push(arg)
        }
      }
      match delta {
        Some(item) =>
          Some(
            (
              item,
              if rest.is_empty() {
                @symcore.int(1)
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
/// Split a linear combination by DiracDelta atoms.
///
/// - Does: Mirrors the useful surface of SymPy `laplace.expand_dirac_delta` by returning coefficients for every additive `DiracDelta(...)` term.
/// - Input: One expression.
/// - Returns: A map from each `DiracDelta` atom to its coefficient.
/// - Limits: Nonlinear products containing multiple delta atoms are ignored.
pub fn expand_dirac_delta(expr : Expr) -> Map[Expr, Expr] {
  let out : Map[Expr, Expr] = Map([])
  let terms = match expr_simplify(expr) {
    Add(args) => args
    simplified => [simplified]
  }
  for term in terms {
    match split_dirac_linear_term(term) {
      Some((delta, coeff)) =>
        match out.get(delta) {
          Some(current) => out[delta] = expr_simplify(expr_add(current, coeff))
          None => out[delta] = coeff
        }
      None => ()
    }
  }
  out
}

///|
fn extract_dirac_factor(expr : Expr, var_name : String) -> (Expr, Expr)? {
  match expr_simplify(expr) {
    simplified if @symcore.application_has_name(
        simplified,
        "DiracDelta",
        arity=1,
      ) => {
      let arg = @symcore.application_args(simplified).unwrap()[0]
      if expr_depends_on(arg, var_name) {
        Some((arg, @symcore.int(1)))
      } else {
        None
      }
    }
    Mul(args) => {
      let rest : Array[Expr] = []
      let mut delta_arg : Expr? = None
      for arg in args {
        match @symcore.application_args(arg) {
          Some([inner]) if @symcore.application_has_name(arg, "DiracDelta") &&
            expr_depends_on(inner, var_name) &&
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
                @symcore.int(1)
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
/// Split a product around one `DiracDelta` factor.
///
/// - Does: Extracts one `DiracDelta(...)` factor and the remaining multiplicative part when possible.
/// - Input: One candidate product `Expr` and one variable name.
/// - Returns: A pair `(delta?, rest?)`.
/// - Limits: Returns `(None, None)` when no supported delta factor is found.
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
      Some((expr_div(@symcore.int(-1) * b, a), @symelem.abs(a)))
    _ => None
  }
}

///|
/// Integrate an expression containing `DiracDelta`.
///
/// - Does: Pulls the integrand back to the delta root and applies the local scaling and interval gating rules.
/// - Input: One integrand `Expr`, one variable name, and optional lower and upper bounds.
/// - Returns: `Some(Expr)` for a computed result or `None`.
/// - Limits: Only the currently recognized delta products and linear roots are supported.
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
                    Some(@symcore.int(0))
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
