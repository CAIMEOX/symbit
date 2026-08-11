///|
/// Rule-based manual integration front door.
///
/// Current Limits:
/// - Coverage is focused on the practical elementary rules implemented locally.
/// - Unsupported inputs return `None` instead of constructing an unevaluated integral.

///|
/// Typed equivalent of SymPy manualintegrate's `(integrand, symbol)` tuple.
pub struct IntegralInfo {
  integrand : Expr
  symbol : Expr
}

///|
/// Lightweight, evaluable integration step used by the public rule helpers.
pub struct ManualStep {
  rule_name : String
  integrand : Expr
  variable : Expr
  result : Expr?
}

///|
pub fn integral_info(integrand : Expr, symbol : Expr) -> IntegralInfo {
  IntegralInfo::{ integrand, symbol }
}

///|
pub fn ManualStep::name(self : ManualStep) -> String {
  self.rule_name
}

///|
pub fn ManualStep::integrand(self : ManualStep) -> Expr {
  self.integrand
}

///|
pub fn ManualStep::variable(self : ManualStep) -> Expr {
  self.variable
}

///|
pub fn ManualStep::eval(self : ManualStep) -> Expr? {
  self.result
}

///|
pub fn ManualStep::contains_dont_know(self : ManualStep) -> Bool {
  self.result is None
}

///|
fn manual_var_name(symbol : Expr) -> String? {
  match symbol {
    @symcore.Expr::Symbol(name) => Some(name)
    _ => None
  }
}

///|
fn manual_known_step(
  rule_name : String,
  info : IntegralInfo,
  result : Expr,
) -> ManualStep {
  ManualStep::{
    rule_name,
    integrand: info.integrand,
    variable: info.symbol,
    result: Some(result),
  }
}

///|
fn manual_unknown_step(rule_name : String, info : IntegralInfo) -> ManualStep {
  ManualStep::{
    rule_name,
    integrand: info.integrand,
    variable: info.symbol,
    result: None,
  }
}

///|
fn manual_integrator_step(
  rule_name : String,
  info : IntegralInfo,
) -> ManualStep? {
  match manual_var_name(info.symbol) {
    Some(name) =>
      match manual_integrate(info.integrand, name) {
        Some(result) => Some(manual_known_step(rule_name, info, result))
        None => None
      }
    None => None
  }
}

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
/// Try the rule-based manual integrator.
///
/// - Does: Applies local elementary integration rules to `expr` in one variable.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Returns `None` when no manual rule applies.
pub fn manual_integrate(expr : Expr, var_name : String) -> Expr? {
  match poly_coeffs_general_int(expr, var_name) {
    Some(coeffs) => return Some(polynomial_antiderivative(coeffs, var_name))
    None => ()
  }
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

///|
/// Derivative helper used by manual substitution search.
///
/// - Does: Differentiates one expression, using explicit trig derivatives for tan/cot/sec/csc shapes.
/// - Input: An expression and a differentiation symbol.
/// - Returns: The symbolic derivative.
/// - Limits: Falls back to the calculus package for unrecognized shapes.
pub fn manual_diff(f : Expr, symbol : Expr) -> Expr {
  match
    (
      manual_var_name(symbol),
      @symcore.application_name(f),
      @symcore.application_args(f),
    ) {
    (Some(_), Some("tan"), Some([arg])) =>
      @symcalculus.diff(arg, symbol) * (@symelem.sec(arg) ^ @symcore.int(2))
    (Some(_), Some("cot"), Some([arg])) =>
      @symcore.int(-1) *
      @symcalculus.diff(arg, symbol) *
      (@symelem.csc(arg) ^ @symcore.int(2))
    (Some(_), Some("sec"), Some([arg])) =>
      @symcalculus.diff(arg, symbol) * @symelem.sec(arg) * @symelem.tan(arg)
    (Some(_), Some("csc"), Some([arg])) =>
      @symcore.int(-1) *
      @symcalculus.diff(arg, symbol) *
      @symelem.csc(arg) *
      @symelem.cot(arg)
    _ =>
      match f {
        @symcore.Expr::Add(args) =>
          expr_simplify(@symcore.add(args.map(arg => manual_diff(arg, symbol))))
        @symcore.Expr::Mul([coeff, rest]) if expr_num_value(coeff) is Some(_) =>
          expr_simplify(coeff * manual_diff(rest, symbol))
        _ => @symcalculus.diff(f, symbol)
      }
  }
}

///|
/// Substitute one expression for another, with log-power compatibility.
///
/// - Does: Performs the common `manual_subs(expr, old, new)` case from SymPy manualintegrate.
/// - Input: Source expression, old expression, and replacement expression.
/// - Returns: The substituted expression.
/// - Limits: Mapping/sequence forms are represented by direct repeated calls in MoonBit.
pub fn manual_subs(expr : Expr, old : Expr, new : Expr) -> Expr {
  let env : Map[String, Expr] = Map([])
  match old {
    @symcore.Expr::Symbol(name) => {
      env[name] = new
      @symcore.subst(expr, env)
    }
    _ => @symcore.xreplace(expr, [(old, new)])
  }
}

///|
pub fn constant_rule(integral : IntegralInfo) -> ManualStep? {
  match manual_var_name(integral.symbol) {
    Some(name) =>
      if !expr_depends_on(integral.integrand, name) {
        Some(
          manual_known_step(
            "ConstantRule",
            integral,
            integral.integrand * integral.symbol,
          ),
        )
      } else {
        None
      }
    None => None
  }
}

///|
pub fn power_rule(integral : IntegralInfo) -> ManualStep? {
  match manual_var_name(integral.symbol) {
    Some(name) =>
      match expr_simplify(integral.integrand) {
        @symcore.Expr::Symbol(sym) if sym == name =>
          manual_integrator_step("PowerRule", integral)
        @symcore.Expr::Pow(base, exp) =>
          match base {
            @symcore.Expr::Symbol(sym) =>
              if sym == name && !expr_depends_on(exp, name) {
                manual_integrator_step("PowerRule", integral)
              } else {
                None
              }
            _ => None
          }
        _ => None
      }
    None => None
  }
}

///|
pub fn nested_pow_rule(integral : IntegralInfo) -> ManualStep? {
  match expr_simplify(integral.integrand) {
    @symcore.Expr::Pow(@symcore.Expr::Pow(_, _), _) =>
      manual_integrator_step("NestedPowRule", integral)
    _ => None
  }
}

///|
pub fn exp_rule(integral : IntegralInfo) -> ManualStep? {
  match @symcore.application_name(integral.integrand) {
    Some("exp") => manual_integrator_step("ExpRule", integral)
    _ => None
  }
}

///|
pub fn add_rule(integral : IntegralInfo) -> ManualStep? {
  match expr_simplify(integral.integrand) {
    @symcore.Expr::Add(_) => manual_integrator_step("AddRule", integral)
    _ => None
  }
}

///|
pub fn mul_rule(integral : IntegralInfo) -> ManualStep? {
  match expr_simplify(integral.integrand) {
    @symcore.Expr::Mul(_) =>
      manual_integrator_step("ConstantTimesRule", integral)
    _ => None
  }
}

///|
pub fn powsimp_rule(integral : IntegralInfo) -> ManualStep? {
  manual_integrator_step("RewriteRule", integral)
}

///|
pub fn fallback_rule(integral : IntegralInfo) -> ManualStep {
  manual_integrator_step("FallbackRule", integral).unwrap_or(
    manual_unknown_step("DontKnowRule", integral),
  )
}

///|
pub fn derivative_rule(integral : IntegralInfo) -> ManualStep? {
  if @symcore.application_has_name(integral.integrand, "Derivative") {
    manual_integrator_step("DerivativeRule", integral)
  } else {
    None
  }
}

///|
pub fn rewrites_rule(integral : IntegralInfo) -> ManualStep? {
  manual_integrator_step("RewriteRule", integral)
}

///|
pub fn substitution_rule(integral : IntegralInfo) -> ManualStep? {
  manual_integrator_step("URule", integral)
}

///|
pub fn integral_steps(integrand : Expr, symbol : Expr) -> ManualStep {
  let info = integral_info(integrand, symbol)
  manual_integrator_step("ManualRule", info).unwrap_or(
    manual_unknown_step("DontKnowRule", info),
  )
}

///|
pub fn make_wilds(symbol : Expr) -> Map[String, Expr] {
  let out : Map[String, Expr] = Map([])
  let suffix = match manual_var_name(symbol) {
    Some(name) => "_" + name
    None => ""
  }
  for name in ["a", "b", "c", "d", "n"] {
    out[name] = @symcore.Expr::Symbol(name + suffix)
  }
  out
}

///|
pub fn sincos_pattern(symbol : Expr) -> Map[String, Expr] {
  make_wilds(symbol)
}

///|
pub fn tansec_pattern(symbol : Expr) -> Map[String, Expr] {
  make_wilds(symbol)
}

///|
pub fn cotcsc_pattern(symbol : Expr) -> Map[String, Expr] {
  make_wilds(symbol)
}

///|
pub fn heaviside_pattern(symbol : Expr) -> Map[String, Expr] {
  make_wilds(symbol)
}

///|
pub fn find_substitutions(
  integrand : Expr,
  symbol : Expr,
  u_var : Expr,
) -> Array[(Expr, Expr, Expr)] {
  let out : Array[(Expr, Expr, Expr)] = []
  match manual_var_name(symbol) {
    Some(sym_name) => {
      let candidates = @symcore.children(integrand)
      for node in candidates {
        match @symcore.application_args(node) {
          Some([arg]) if expr_depends_on(arg, sym_name) => {
            let u_diff = manual_diff(arg, symbol)
            if !expr_is_zero(u_diff) {
              let substituted = manual_subs(
                expr_div(integrand, u_diff),
                arg,
                u_var,
              )
              if !expr_depends_on(substituted, sym_name) {
                out.push((arg, @symcore.int(1), substituted))
              }
            }
          }
          _ => ()
        }
      }
      out
    }
    None => out
  }
}

///|
fn manual_named_rule(
  rule_name : String,
  integral : IntegralInfo,
) -> ManualStep? {
  manual_integrator_step(rule_name, integral)
}

///|
pub fn dirac_delta_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("DiracDeltaRule", integral)
}

///|
pub fn heaviside_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("HeavisideRule", integral)
}

///|
pub fn hyperbolic_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("HyperbolicRule", integral)
}

///|
pub fn inverse_trig_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("ArctanRule", integral)
}

///|
pub fn orthogonal_poly_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("OrthogonalPolyRule", integral)
}

///|
pub fn parts_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("PartsRule", integral)
}

///|
pub fn quadratic_denom_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("SqrtQuadraticDenomRule", integral)
}

///|
pub fn special_function_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("SpecialFunctionRule", integral)
}

///|
pub fn sqrt_linear_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("SqrtQuadraticRule", integral)
}

///|
pub fn sqrt_quadratic_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("SqrtQuadraticRule", integral)
}

///|
pub fn trig_cmplx_exp_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("TrigRule", integral)
}

///|
pub fn trig_cotcsc_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("CscCotRule", integral)
}

///|
pub fn trig_powers_products_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("TrigRule", integral)
}

///|
pub fn trig_product_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("TrigRule", integral)
}

///|
pub fn trig_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("TrigRule", integral)
}

///|
pub fn trig_sincos_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("TrigRule", integral)
}

///|
pub fn trig_sindouble_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("TrigRule", integral)
}

///|
pub fn trig_substitution_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("TrigSubstitutionRule", integral)
}

///|
pub fn trig_tansec_rule(integral : IntegralInfo) -> ManualStep? {
  manual_named_rule("SecTanRule", integral)
}

///|
pub fn rewriter(
  condition : (IntegralInfo) -> Bool,
  rewrite : (IntegralInfo) -> Expr,
) -> (IntegralInfo) -> ManualStep? {
  fn(info : IntegralInfo) -> ManualStep? {
    if condition(info) {
      let rewritten = rewrite(info)
      if @symcore.compare_expr(rewritten, info.integrand) != 0 {
        integral_steps(rewritten, info.symbol).result.map(fn(result) {
          manual_known_step("RewriteRule", info, result)
        })
      } else {
        None
      }
    } else {
      None
    }
  }
}

///|
pub fn proxy_rewriter(
  condition : (Expr, IntegralInfo) -> Bool,
  rewrite : (Expr, IntegralInfo) -> Expr,
) -> (Expr, IntegralInfo) -> ManualStep? {
  fn(criteria : Expr, info : IntegralInfo) -> ManualStep? {
    if condition(criteria, info) {
      let rewritten = rewrite(criteria, info)
      integral_steps(rewritten, info.symbol).result.map(fn(result) {
        manual_known_step("RewriteRule", info, result)
      })
    } else {
      None
    }
  }
}

///|
pub fn multiplexer(
  conditions : Array[((IntegralInfo) -> Bool, (IntegralInfo) -> ManualStep?)],
) -> (IntegralInfo) -> ManualStep? {
  fn(info : IntegralInfo) -> ManualStep? {
    for item in conditions {
      if (item.0)(info) {
        return (item.1)(info)
      }
    }
    None
  }
}

///|
pub fn alternatives(
  rules : Array[(IntegralInfo) -> ManualStep?],
) -> (IntegralInfo) -> ManualStep? {
  fn(info : IntegralInfo) -> ManualStep? {
    let mut fallback : ManualStep? = None
    for rule in rules {
      match rule(info) {
        Some(step) if !step.contains_dont_know() => return Some(step)
        Some(step) if fallback is None => fallback = Some(step)
        _ => ()
      }
    }
    fallback
  }
}

///|
pub fn trig_rewriter(_rewrite : String) -> (IntegralInfo) -> ManualStep? {
  fn(info : IntegralInfo) -> ManualStep? { trig_rule(info) }
}

///|
pub fn uncurry(func : (Array[Expr]) -> Expr) -> (Array[Expr]) -> Expr {
  func
}
