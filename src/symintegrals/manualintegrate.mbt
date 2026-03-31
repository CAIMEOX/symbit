///|
/// Rule-based antiderivative engine for the high-value practical subset of
/// `sympy.integrals.manualintegrate`.

///|
fn integrate_linear_power(
  base : Expr,
  exp_value : Expr,
  var_name : String,
) -> Expr? {
  if expr_depends_on(exp_value, var_name) {
    return None
  }
  match linear_coeffs(base, var_name) {
    Some((a, _)) if !expr_is_zero(a) && expr_eq(exp_value, @symcore.int(-1)) =>
      Some(expr_div(@symelem.log(base), a))
    Some((a, _)) if !expr_is_zero(a) => {
      let next = expr_add(exp_value, @symcore.int(1))
      Some(expr_div(expr_pow(base, next), expr_mul(a, next)))
    }
    _ => None
  }
}

///|
fn integrate_poly_times_exp(
  poly_expr : Expr,
  arg : Expr,
  var_name : String,
) -> Expr? {
  match (poly_coeffs_upto2(poly_expr, var_name), linear_coeffs(arg, var_name)) {
    (Some(pc), Some((a, b))) if !expr_is_zero(a) && expr_is_zero(pc[2]) => {
      let x = @symcore.Expr::Symbol(var_name)
      let alpha = expr_add(expr_mul(a, x), b)
      let c1 = expr_div(pc[1], a)
      let c0 = expr_div(expr_sub(pc[0], expr_div(pc[1], a)), a)
      Some(@symelem.exp(alpha) * (c1 * x + c0))
    }
    _ => None
  }
}

///|
fn integrate_poly_times_trig(
  poly_expr : Expr,
  trig_name : String,
  arg : Expr,
  var_name : String,
) -> Expr? {
  match (poly_coeffs_upto2(poly_expr, var_name), linear_coeffs(arg, var_name)) {
    (Some(pc), Some((a, b))) if !expr_is_zero(a) && expr_is_zero(pc[2]) => {
      let x = @symcore.Expr::Symbol(var_name)
      let alpha = expr_add(expr_mul(a, x), b)
      let m = pc[1]
      let n = pc[0]
      match trig_name {
        "sin" =>
          Some(
            expr_div(@symcore.int(-1) * (m * x + n) * @symelem.cos(alpha), a) +
            expr_div(m * @symelem.sin(alpha), expr_pow(a, @symcore.int(2))),
          )
        "cos" =>
          Some(
            expr_div((m * x + n) * @symelem.sin(alpha), a) +
            expr_div(m * @symelem.cos(alpha), expr_pow(a, @symcore.int(2))),
          )
        _ => None
      }
    }
    _ => None
  }
}

///|
fn reciprocal_sqrt_quadratic(inner : Expr, var_name : String) -> Expr? {
  match poly_coeffs_upto2(inner, var_name) {
    Some(coeffs) if expr_is_one(coeffs[0]) &&
      expr_is_zero(coeffs[1]) &&
      expr_is_minus_one(coeffs[2]) =>
      Some(@symelem.asin(@symcore.Expr::Symbol(var_name)))
    Some(coeffs) if expr_is_one(coeffs[0]) &&
      expr_is_zero(coeffs[1]) &&
      expr_is_one(coeffs[2]) =>
      Some(@symelem.asinh(@symcore.Expr::Symbol(var_name)))
    _ => None
  }
}

///|
fn integrate_exp_power(base : Expr, exp : Expr, var_name : String) -> Expr? {
  if expr_depends_on(exp, var_name) || expr_is_zero(exp) {
    return None
  }
  match (@symcore.application_name(base), @symcore.application_args(base)) {
    (Some("exp"), Some([arg])) =>
      match linear_coeffs(arg, var_name) {
        Some((a, _)) if !expr_is_zero(a) =>
          Some(expr_div(expr_pow(base, exp), expr_mul(exp, a)))
        _ => None
      }
    _ => None
  }
}

///|
fn fallback_pow_integrate(base : Expr, exp : Expr, var_name : String) -> Expr? {
  match integrate_exp_power(base, exp, var_name) {
    Some(res) => return Some(res)
    None => ()
  }
  match integrate_linear_power(base, exp, var_name) {
    Some(res) => return Some(res)
    None => ()
  }
  if expr_eq(
      base,
      expr_add(
        expr_pow(@symcore.Expr::Symbol(var_name), @symcore.int(2)),
        @symcore.int(1),
      ),
    ) &&
    expr_eq(exp, @symcore.int(-1)) {
    return Some(@symelem.atan(@symcore.Expr::Symbol(var_name)))
  }
  if expr_eq(
      base,
      expr_sub(
        @symcore.int(1),
        expr_pow(@symcore.Expr::Symbol(var_name), @symcore.int(2)),
      ),
    ) &&
    expr_eq(exp, expr_rat(-1, 2)) {
    return Some(@symelem.asin(@symcore.Expr::Symbol(var_name)))
  }
  if expr_eq(
      base,
      expr_add(
        expr_pow(@symcore.Expr::Symbol(var_name), @symcore.int(2)),
        @symcore.int(1),
      ),
    ) &&
    expr_eq(exp, expr_rat(-1, 2)) {
    return Some(@symelem.asinh(@symcore.Expr::Symbol(var_name)))
  }
  None
}

///|
/// Rule-based single-variable antiderivative.
///
/// This mirrors the practical core of SymPy's `manualintegrate`: it returns
/// `None` when no elementary/manual rule applies instead of constructing an
/// unevaluated `Integral`.
pub fn manual_integrate(expr : Expr, var_name : String) -> Expr? {
  let simplified = expr_simplify(expr)
  if !expr_depends_on(simplified, var_name) {
    return Some(simplified * @symcore.Expr::Symbol(var_name))
  }
  match singularityintegrate(simplified, var_name) {
    Some(res) => return Some(expr_simplify(res))
    None => ()
  }
  match simplified {
    @symcore.Expr::Add(args) => {
      let out : Array[Expr] = []
      for arg in args {
        match manual_integrate(arg, var_name) {
          Some(item) => out.push(item)
          None => return None
        }
      }
      return Some(expr_simplify(@symcore.add(out)))
    }
    @symcore.Expr::Mul(args) => {
      let indep : Array[Expr] = []
      let dep : Array[Expr] = []
      for arg in args {
        if expr_depends_on(arg, var_name) {
          dep.push(arg)
        } else {
          indep.push(arg)
        }
      }
      let coeff = if indep.is_empty() {
        @symcore.int(1)
      } else {
        expr_simplify(@symcore.mul(indep))
      }
      if dep.length() == 1 {
        match manual_integrate(dep[0], var_name) {
          Some(item) => return Some(expr_simplify(coeff * item))
          None => ()
        }
      }
      if dep.length() == 2 {
        match
          (@symcore.application_name(dep[0]), @symcore.application_args(dep[0])) {
          (Some("exp"), Some([arg])) =>
            match integrate_poly_times_exp(dep[1], arg, var_name) {
              Some(item) => return Some(expr_simplify(coeff * item))
              None => ()
            }
          (Some("sin"), Some([arg])) =>
            match integrate_poly_times_trig(dep[1], "sin", arg, var_name) {
              Some(item) => return Some(expr_simplify(coeff * item))
              None => ()
            }
          (Some("cos"), Some([arg])) =>
            match integrate_poly_times_trig(dep[1], "cos", arg, var_name) {
              Some(item) => return Some(expr_simplify(coeff * item))
              None => ()
            }
          _ => ()
        }
        match
          (@symcore.application_name(dep[1]), @symcore.application_args(dep[1])) {
          (Some("exp"), Some([arg])) =>
            match integrate_poly_times_exp(dep[0], arg, var_name) {
              Some(item) => return Some(expr_simplify(coeff * item))
              None => ()
            }
          (Some("sin"), Some([arg])) =>
            match integrate_poly_times_trig(dep[0], "sin", arg, var_name) {
              Some(item) => return Some(expr_simplify(coeff * item))
              None => ()
            }
          (Some("cos"), Some([arg])) =>
            match integrate_poly_times_trig(dep[0], "cos", arg, var_name) {
              Some(item) => return Some(expr_simplify(coeff * item))
              None => ()
            }
          _ => ()
        }
      }
      match deltaintegrate(simplified, var_name, None, None) {
        Some(item) => return Some(expr_simplify(item))
        None => ()
      }
      match trigintegrate(simplified, var_name) {
        Some(item) => return Some(expr_simplify(item))
        None => ()
      }
      match ratint(simplified, var_name) {
        Some(item) => return Some(expr_simplify(item))
        None => None
      }
    }
    @symcore.Expr::Symbol(name) if name == var_name =>
      Some(
        expr_rat(1, 2) *
        expr_pow(@symcore.Expr::Symbol(var_name), @symcore.int(2)),
      )
    @symcore.Expr::Pow(base, exp) => {
      let pow_res = match
        (@symcore.application_name(base), @symcore.application_args(base)) {
        (Some("sqrt"), Some([inner])) if expr_eq(exp, @symcore.int(-1)) =>
          match reciprocal_sqrt_quadratic(inner, var_name) {
            Some(res) => Some(res)
            None => fallback_pow_integrate(base, exp, var_name)
          }
        _ => fallback_pow_integrate(base, exp, var_name)
      }
      match pow_res {
        Some(res) => Some(res)
        None => trigintegrate(simplified, var_name)
      }
    }
    _ =>
      match
        (
          @symcore.application_name(simplified),
          @symcore.application_args(simplified),
        ) {
        (Some("exp"), Some([arg])) =>
          match linear_coeffs(arg, var_name) {
            Some((a, _)) if !expr_is_zero(a) =>
              Some(expr_div(@symelem.exp(arg), a))
            _ => None
          }
        (Some("Heaviside"), Some([arg])) =>
          match linear_coeffs(arg, var_name) {
            Some((a, _)) if !expr_is_zero(a) =>
              Some(expr_div(arg * @symspec.heaviside(arg), a))
            _ => None
          }
        (Some("log"), Some([@symcore.Expr::Symbol(name)])) if name == var_name =>
          Some(
            @symcore.Expr::Symbol(var_name) *
            @symelem.log(@symcore.Expr::Symbol(var_name)) -
            @symcore.Expr::Symbol(var_name),
          )
        (Some("Piecewise"), Some(args)) => {
          let out_cases : Array[(Expr, Expr)] = []
          let mut i = 0
          while i + 1 < args.length() {
            let branch = args[i]
            let cond = args[i + 1]
            if cond == @symcore.Expr::Boolean(true) {
              match manual_integrate(branch, var_name) {
                Some(item) =>
                  return Some(piecewise_expr(out_cases, default=item))
                None => return None
              }
            }
            match manual_integrate(branch, var_name) {
              Some(item) => out_cases.push((item, cond))
              None => return None
            }
            i += 2
          }
          Some(piecewise_expr(out_cases))
        }
        _ =>
          match deltaintegrate(simplified, var_name, None, None) {
            Some(item) => Some(expr_simplify(item))
            None =>
              match trigintegrate(simplified, var_name) {
                Some(item) => Some(expr_simplify(item))
                None => ratint(simplified, var_name).map(expr_simplify)
              }
          }
      }
  }
}
