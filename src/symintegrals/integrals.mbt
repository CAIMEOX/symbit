///|
/// Core `Integral` / transform objects and the main integration entrypoints.
///
/// Current Limits:
/// - This file exposes the main symbolic front doors and unevaluated transform constructors.
/// - Unsupported cases generally fall back to unevaluated objects instead of raising.

///|
/// Construct an unevaluated `Integral` object.
///
/// - Does: Wraps the integrand and integration limits without evaluating them.
/// - Input: One integrand `Expr` and an optional array of limit tuples.
/// - Returns: One symbolic `Integral` expression.
/// - Limits: This front door only constructs the object; no integration is attempted here.
pub fn integral(expr : Expr, limits? : Array[Expr] = []) -> Expr {
  let args : Array[Expr] = [expr]
  for limit in limits {
    args.push(limit)
  }
  @symcore.raw_function("Integral", args)
}

///|
/// Build a limit tuple for integral-like front doors.
///
/// - Does: Packages the integration variable and optional bounds into one tuple expression.
/// - Input: An array such as `[x]` or `[x, a, b]`.
/// - Returns: One tuple `Expr`.
/// - Limits: The tuple is not validated here beyond being wrapped as-is.
pub fn integral_limit(items : Array[Expr]) -> Expr {
  Expr::Tuple(items)
}

///|
/// Construct an unevaluated Laplace transform object.
///
/// - Does: Wraps the source expression and transform variables as `LaplaceTransform(...)`.
/// - Input: One source `Expr`, one time variable `t`, and one transform variable `s`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `laplace_transform_eval` to evaluate it.
pub fn laplace_transform(expr : Expr, t : Expr, s : Expr) -> Expr {
  @symcore.raw_function("LaplaceTransform", [expr, t, s])
}

///|
/// Construct an unevaluated inverse Laplace transform object.
///
/// - Does: Wraps the source expression, variables, and optional fundamental plane as `InverseLaplaceTransform(...)`.
/// - Input: One source `Expr`, one transform variable `s`, one time variable `t`, and an optional `plane`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `inverse_laplace_transform_eval` to evaluate it.
pub fn inverse_laplace_transform(
  expr : Expr,
  s : Expr,
  t : Expr,
  plane? : Expr? = None,
) -> Expr {
  inverse_laplace_transform_with_plane(expr, s, t, plane)
}

///|
fn inverse_laplace_transform_with_plane(
  expr : Expr,
  s : Expr,
  t : Expr,
  plane : Expr?,
) -> Expr {
  match plane {
    Some(value) =>
      @symcore.raw_function("InverseLaplaceTransform", [expr, s, t, value])
    None => inverse_laplace_transform_with_none(expr, s, t)
  }
}

///|
fn inverse_laplace_transform_with_none(expr : Expr, s : Expr, t : Expr) -> Expr {
  // Source map: SymPy's InverseLaplaceTransform.__new__ stores plane=None as
  // a private sentinel, and sstr renders that sentinel as `_None`.
  @symcore.raw_function("InverseLaplaceTransform", [
    expr,
    s,
    t,
    inverse_laplace_none_sentinel(),
  ])
}

///|
fn inverse_laplace_none_sentinel() -> Expr {
  @symcore.Expr::Symbol("_None")
}

///|
/// Read the fundamental plane from an inverse Laplace transform object.
///
/// - Does: Mirrors SymPy's `InverseLaplaceTransform.fundamental_plane` property.
/// - Input: One `InverseLaplaceTransform(F, s, t, plane)` object.
/// - Returns: `Some(plane)` for explicit planes, and `None` for SymPy's stored `None` sentinel.
/// - Limits: Non inverse-Laplace expressions also return `None`.
pub fn inverse_laplace_transform_fundamental_plane(transform : Expr) -> Expr? {
  match @symcore.application_parts(transform) {
    Some((head, [_, _, _])) if @symcore.function_head_name(head) ==
      Some("InverseLaplaceTransform") => None
    Some((head, [_, _, _, plane])) if @symcore.function_head_name(head) ==
      Some("InverseLaplaceTransform") =>
      match plane {
        @symcore.Expr::Symbol("_None") => None
        _ => Some(plane)
      }
    _ => None
  }
}

///|
/// Rewrite an unevaluated inverse Laplace transform object as its Bromwich integral.
///
/// - Does: Mirrors SymPy's `InverseLaplaceTransform._as_integral` object hook.
/// - Input: One `InverseLaplaceTransform(F, s, t, plane)` object.
/// - Returns: `Some(Integral(exp(s*t)*F, (s, _c - I*oo, _c + I*oo))/(2*pi*I))`.
/// - Limits: The source hook ignores the stored plane and uses a fresh contour symbol `_c`.
pub fn inverse_laplace_transform_as_integral(transform : Expr) -> Expr? {
  match @symcore.application_parts(transform) {
    Some((head, [inner, s, t])) | Some((head, [inner, s, t, _])) if @symcore.function_head_name(
        head,
      ) ==
      Some("InverseLaplaceTransform") =>
      Some(inverse_laplace_bromwich_integral(inner, s, t))
    _ => None
  }
}

///|
fn inverse_laplace_bromwich_integral(inner : Expr, s : Expr, t : Expr) -> Expr {
  let contour = @symcore.Expr::Symbol("_c")
  let imag = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::ImaginaryUnit,
  )
  let infinity = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::Infinity,
  )
  let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
  let imag_infinity = imag * infinity
  expr_div(
    integral(@symelem.exp(s * t) * inner, limits=[
      integral_limit([s, contour - imag_infinity, contour + imag_infinity]),
    ]),
    @symcore.int(2) * pi * imag,
  )
}

///|
/// Construct an unevaluated Fourier transform object.
///
/// - Does: Wraps the source expression and variables as `FourierTransform(...)`.
/// - Input: One source `Expr`, one space variable `x`, and one frequency variable `k`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `fourier_transform_eval` to evaluate it.
pub fn fourier_transform(expr : Expr, x : Expr, k : Expr) -> Expr {
  @symcore.raw_function("FourierTransform", [expr, x, k])
}

///|
/// Construct an unevaluated inverse Fourier transform object.
///
/// - Does: Wraps the source expression and variables as `InverseFourierTransform(...)`.
/// - Input: One source `Expr`, one frequency variable `k`, and one space variable `x`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `inverse_fourier_transform_eval` to evaluate it.
pub fn inverse_fourier_transform(expr : Expr, k : Expr, x : Expr) -> Expr {
  @symcore.raw_function("InverseFourierTransform", [expr, k, x])
}

///|
/// Construct an unevaluated sine transform object.
///
/// - Does: Wraps the source expression and variables as `SineTransform(...)`.
/// - Input: One source `Expr`, one space variable `x`, and one frequency variable `k`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `sine_transform_eval` to evaluate it.
pub fn sine_transform(expr : Expr, x : Expr, k : Expr) -> Expr {
  @symcore.raw_function("SineTransform", [expr, x, k])
}

///|
/// Construct an unevaluated inverse sine transform object.
///
/// - Does: Wraps the source expression and variables as `InverseSineTransform(...)`.
/// - Input: One source `Expr`, one frequency variable `k`, and one space variable `x`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `inverse_sine_transform_eval` to evaluate it.
pub fn inverse_sine_transform(expr : Expr, k : Expr, x : Expr) -> Expr {
  @symcore.raw_function("InverseSineTransform", [expr, k, x])
}

///|
/// Construct an unevaluated cosine transform object.
///
/// - Does: Wraps the source expression and variables as `CosineTransform(...)`.
/// - Input: One source `Expr`, one space variable `x`, and one frequency variable `k`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `cosine_transform_eval` to evaluate it.
pub fn cosine_transform(expr : Expr, x : Expr, k : Expr) -> Expr {
  @symcore.raw_function("CosineTransform", [expr, x, k])
}

///|
/// Construct an unevaluated inverse cosine transform object.
///
/// - Does: Wraps the source expression and variables as `InverseCosineTransform(...)`.
/// - Input: One source `Expr`, one frequency variable `k`, and one space variable `x`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `inverse_cosine_transform_eval` to evaluate it.
pub fn inverse_cosine_transform(expr : Expr, k : Expr, x : Expr) -> Expr {
  @symcore.raw_function("InverseCosineTransform", [expr, k, x])
}

///|
/// Construct an unevaluated Mellin transform object.
///
/// - Does: Wraps the source expression and variables as `MellinTransform(...)`.
/// - Input: One source `Expr`, one variable `x`, and one Mellin variable `s`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `mellin_transform_eval` to evaluate it.
pub fn mellin_transform(expr : Expr, x : Expr, s : Expr) -> Expr {
  @symcore.raw_function("MellinTransform", [expr, x, s])
}

///|
/// Construct an unevaluated inverse Mellin transform object.
///
/// - Does: Wraps the source expression and variables as `InverseMellinTransform(...)`.
/// - Input: One source `Expr`, one Mellin variable `s`, and one target variable `x`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or the inverse Mellin evaluation helpers to evaluate it.
pub fn inverse_mellin_transform(expr : Expr, s : Expr, x : Expr) -> Expr {
  @symcore.raw_function("InverseMellinTransform", [expr, s, x])
}

///|
/// Construct an unevaluated Hankel transform object.
///
/// - Does: Wraps the source expression and variables as `HankelTransform(...)` with order `nu`.
/// - Input: One source `Expr`, radial variable `r`, frequency variable `k`, and order `nu`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `hankel_transform_eval` to evaluate it.
pub fn hankel_transform(expr : Expr, r : Expr, k : Expr, nu : Expr) -> Expr {
  @symcore.raw_function("HankelTransform", [expr, r, k, nu])
}

///|
/// Construct an unevaluated inverse Hankel transform object.
///
/// - Does: Wraps the source expression and variables as `InverseHankelTransform(...)` with order `nu`.
/// - Input: One source `Expr`, frequency variable `k`, radial variable `r`, and order `nu`.
/// - Returns: One unevaluated transform `Expr`.
/// - Limits: Use `doit` or `inverse_hankel_transform_eval` to evaluate it.
pub fn inverse_hankel_transform(
  expr : Expr,
  k : Expr,
  r : Expr,
  nu : Expr,
) -> Expr {
  @symcore.raw_function("InverseHankelTransform", [expr, k, r, nu])
}

///|
/// Integrate a scalar field along a parametric curve.
///
/// - Does: Pulls the field back along the curve, multiplies by the speed, and integrates over the curve parameter.
/// - Input: One scalar-field `Expr`, one `Curve`, and an ordered variable array.
/// - Returns: One line-integral `Expr`.
/// - Limits: Raises `IntegralError` when the variables or curve data are invalid.
pub fn line_integrate(
  field : Expr,
  curve : @symgeometry.Curve,
  vars : Array[Expr],
) -> Expr raise IntegralError {
  if vars.is_empty() {
    raise IntegralError::ValueError("Expecting ordered iterable for variables.")
  }
  let functions = curve.functions()
  if functions.length() != vars.length() {
    raise IntegralError::ValueError(
      "Field variable size does not match curve dimension.",
    )
  }
  let (parameter, lower, upper) = curve.limits()
  for variable in vars {
    if @symcore.compare_expr(variable, parameter) == 0 {
      raise IntegralError::ValueError(
        "Curve parameter clashes with field parameters.",
      )
    }
  }
  let mut transformed = field
  let mut speed_sq = @symcore.int(0)
  for i in 0..<functions.length() {
    let name = match vars[i] {
      @symcore.Expr::Symbol(var_name) => var_name
      _ =>
        raise IntegralError::ValueError(
          "Expecting symbols as line integral variables.",
        )
    }
    let deriv = @symcalculus.diff(functions[i], parameter)
    speed_sq = expr_add(speed_sq, deriv * deriv)
    transformed = subst_symbol(transformed, name, functions[i])
  }
  let value = integrate(
    expr_simplify(transformed * expr_sqrt_positive(speed_sq)),
    limits=[integral_limit([parameter, lower, upper])],
  )
  expr_eval_special(value)
}

///|
/// Try the Heurisch-style antiderivative for one limit.
///
/// - Does: Applies the heuristic integrator when the limit is a plain indefinite variable and otherwise returns an unevaluated integral.
/// - Input: One integrand `Expr` and one limit tuple expression.
/// - Returns: One `Expr`, either an antiderivative or an unevaluated integral.
/// - Limits: Non-plain limits and failed heuristic solves fall back to `Integral(...)`.
pub fn heurisch_integrate(expr : Expr, limit_expr : Expr) -> Expr {
  match parse_limit(limit_expr) {
    Some((name, None, None)) =>
      heurisch(expr, name).unwrap_or(integral(expr, limits=[limit_expr]))
    _ => integral(expr, limits=[limit_expr])
  }
}

///|
/// Try the rule-based manual integration path for one limit.
///
/// - Does: Applies the manual integrator when the limit is a plain indefinite variable and otherwise returns an unevaluated integral.
/// - Input: One integrand `Expr` and one limit tuple expression.
/// - Returns: One `Expr`, either an antiderivative or an unevaluated integral.
/// - Limits: Non-plain limits and failed manual rules fall back to `Integral(...)`.
pub fn manualintegrate(expr : Expr, limit_expr : Expr) -> Expr {
  match parse_limit(limit_expr) {
    Some((name, None, None)) =>
      manual_integrate(expr, name).unwrap_or(
        integral(expr, limits=[limit_expr]),
      )
    _ => integral(expr, limits=[limit_expr])
  }
}

///|
/// Main symbolic integration entrypoint.
///
/// - Does: Dispatches to the currently available symbolic integrators and falls back to unevaluated `Integral` objects when needed.
/// - Input: One integrand `Expr` and an optional array of limit tuples.
/// - Returns: One `Expr`, either evaluated or unevaluated.
/// - Limits: Coverage depends on the currently implemented symbolic subsolvers.
pub fn integrate(expr : Expr, limits? : Array[Expr] = []) -> Expr {
  if limits.is_empty() {
    match infer_single_symbol(expr) {
      Some(name) =>
        match risch_integrate(expr, name) {
          Some(res) => expr_simplify(res)
          None =>
            match meijerg_integrate(expr, name) {
              Some(res) => expr_simplify(res)
              None =>
                integral(expr, limits=[
                  Expr::Tuple([@symcore.Expr::Symbol(name)]),
                ])
            }
        }
      None => integral(expr)
    }
  } else {
    let mut cur = expr
    let mut idx = limits.length()
    while idx > 0 {
      idx -= 1
      cur = integrate_one(cur, limits[idx])
    }
    cur
  }
}

///|
fn integrate_one(expr : Expr, limit : Expr) -> Expr {
  match parse_limit(limit) {
    Some((name, None, None)) => {
      match poly_coeffs_general_int(expr, name) {
        Some(coeffs) => return polynomial_antiderivative(coeffs, name)
        None => ()
      }
      match risch_integrate(expr, name) {
        Some(res) => expr_simplify(res)
        None =>
          match meijerg_integrate(expr, name) {
            Some(res) => expr_simplify(res)
            None => integral(expr, limits=[limit])
          }
      }
    }
    Some((name, Some(lower), Some(upper))) => {
      match deltaintegrate(expr, name, Some(lower), Some(upper)) {
        Some(res) => return expr_simplify(res)
        None => ()
      }
      match risch_integrate(expr, name) {
        Some(anti) =>
          expr_eval_special(
            expr_simplify(
              subst_symbol(anti, name, upper) - subst_symbol(anti, name, lower),
            ),
          )
        None =>
          match meijerg_integrate(expr, name) {
            Some(anti) =>
              expr_eval_special(
                expr_simplify(
                  subst_symbol(anti, name, upper) -
                  subst_symbol(anti, name, lower),
                ),
              )
            None => integral(expr, limits=[limit])
          }
      }
    }
    Some(_) => integral(expr, limits=[limit])
    None => integral(expr, limits=[limit])
  }
}

///|
/// Evaluate a forward Laplace transform.
///
/// - Does: Runs the Laplace rule engine and optionally keeps the convergence metadata.
/// - Input: One source `Expr`, variables `t` and `s`, and an optional `noconds` flag.
/// - Returns: Either the transformed `Expr` or a tuple `(value, plane, condition)`.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn laplace_transform_eval(
  expr : Expr,
  t : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  laplace_transform_result(expr, t, s, noconds~)
}

///|
/// Evaluate an inverse Laplace transform.
///
/// - Does: Runs the inverse Laplace rule engine and optionally keeps a trailing condition flag.
/// - Input: One source `Expr`, variables `s` and `t`, plus optional `plane`, `noconds`, and `simplify` flags.
/// - Returns: Either the transformed `Expr` or a tuple carrying the value and a condition flag.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn inverse_laplace_transform_eval(
  expr : Expr,
  s : Expr,
  t : Expr,
  plane? : Expr? = None,
  noconds? : Bool = true,
  simplify? : Bool = false,
) -> Expr {
  // Source map: SymPy's public inverse_laplace_transform defaults to
  // noconds=True, while internally it still calls
  // InverseLaplaceTransform(...).doit(noconds=False) and strips the condition
  // only at the public wrapper boundary. The local condition reconstruction is
  // post-hoc and recursive, so skip it when the public result will discard it.
  let (raw_found, cond) = if noconds {
    let raw_value = match do_inverse_laplace_doit(expr, s, t) {
      Some(value) => value
      None => inverse_laplace_transform_with_plane(expr, s, t, plane)
    }
    (raw_value, true_expr())
  } else {
    match do_inverse_laplace_doit_with_condition(expr, s, t) {
      Some((value, condition)) => (value, condition)
      None =>
        (inverse_laplace_transform_with_plane(expr, s, t, plane), true_expr())
    }
  }
  let raw_value = if noconds && plane is None {
    raw_found
  } else {
    inverse_laplace_fill_plane(raw_found, plane)
  }
  let value = if simplify {
    @symsimplify.simplify(raw_value)
  } else {
    raw_value
  }
  if noconds {
    value
  } else {
    Expr::Tuple([value, cond])
  }
}

///|
fn inverse_laplace_fill_plane(expr : Expr, plane : Expr?) -> Expr {
  match @symcore.application_parts(expr) {
    Some((head, args)) =>
      match @symcore.function_head_name(head) {
        Some("InverseLaplaceTransform") =>
          match args {
            [inner, s, t] =>
              inverse_laplace_transform_with_plane(
                inverse_laplace_fill_plane(inner, plane),
                s,
                t,
                plane,
              )
            [inner, s, t, existing_plane] =>
              @symcore.raw_function("InverseLaplaceTransform", [
                inverse_laplace_fill_plane(inner, plane),
                s,
                t,
                existing_plane,
              ])
            _ => expr
          }
        _ =>
          @symcore.raw_apply(
            head,
            args.map(fn(arg) { inverse_laplace_fill_plane(arg, plane) }),
          ).unwrap_or(expr)
      }
    None =>
      match expr {
        Expr::Add(args) =>
          @symcore.add(
            args.map(fn(arg) { inverse_laplace_fill_plane(arg, plane) }),
          )
        Expr::Mul(args) =>
          @symcore.mul(
            args.map(fn(arg) { inverse_laplace_fill_plane(arg, plane) }),
          )
        Expr::Pow(base, exp) =>
          @symcore.pow(
            inverse_laplace_fill_plane(base, plane),
            inverse_laplace_fill_plane(exp, plane),
          )
        Expr::Mod(lhs, rhs) =>
          Expr::Mod(
            inverse_laplace_fill_plane(lhs, plane),
            inverse_laplace_fill_plane(rhs, plane),
          )
        Expr::Tuple(args) =>
          Expr::Tuple(
            args.map(fn(arg) { inverse_laplace_fill_plane(arg, plane) }),
          )
        Expr::Dict(items) =>
          Expr::Dict(
            items.map(fn(item) {
              (
                inverse_laplace_fill_plane(item.0, plane),
                inverse_laplace_fill_plane(item.1, plane),
              )
            }),
          )
        Expr::Relational(op, lhs, rhs) =>
          Expr::Relational(
            op,
            inverse_laplace_fill_plane(lhs, plane),
            inverse_laplace_fill_plane(rhs, plane),
          )
        Expr::Derivative(inner, args) =>
          Expr::Derivative(
            inverse_laplace_fill_plane(inner, plane),
            args.map(fn(arg) { inverse_laplace_fill_plane(arg, plane) }),
          )
        Expr::Subs(inner, variable, value) =>
          Expr::Subs(
            inverse_laplace_fill_plane(inner, plane),
            inverse_laplace_fill_plane(variable, plane),
            inverse_laplace_fill_plane(value, plane),
          )
        Expr::Lambda(vars, body) =>
          Expr::Lambda(
            inverse_laplace_fill_plane(vars, plane),
            inverse_laplace_fill_plane(body, plane),
          )
        _ => expr
      }
  }
}

///|
/// Evaluate a Mellin transform.
///
/// - Does: Runs the Mellin rule engine and optionally keeps strip and condition metadata.
/// - Input: One source `Expr`, variables `x` and `s`, and an optional `noconds` flag.
/// - Returns: Either the transformed `Expr` or a tuple carrying the value, strip, and condition.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn mellin_transform_eval(
  expr : Expr,
  x : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  mellin_transform_result(expr, x, s, noconds~)
}

///|
/// Evaluate a Fourier transform.
///
/// - Does: Runs the forward Fourier rule engine.
/// - Input: One source `Expr`, variables `x` and `k`.
/// - Returns: One transformed `Expr`.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn fourier_transform_eval(expr : Expr, x : Expr, k : Expr) -> Expr {
  do_fourier_doit(expr, x, k).unwrap_or(fourier_transform(expr, x, k))
}

///|
/// Evaluate an inverse Fourier transform.
///
/// - Does: Runs the inverse Fourier rule engine.
/// - Input: One source `Expr`, variables `k` and `x`.
/// - Returns: One transformed `Expr`.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn inverse_fourier_transform_eval(expr : Expr, k : Expr, x : Expr) -> Expr {
  do_inverse_fourier_doit(expr, k, x).unwrap_or(
    inverse_fourier_transform(expr, k, x),
  )
}

///|
/// Evaluate a sine transform.
///
/// - Does: Runs the forward sine-transform rule engine.
/// - Input: One source `Expr`, variables `x` and `k`.
/// - Returns: One transformed `Expr`.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn sine_transform_eval(expr : Expr, x : Expr, k : Expr) -> Expr {
  do_sine_doit(expr, x, k).unwrap_or(sine_transform(expr, x, k))
}

///|
/// Evaluate an inverse sine transform.
///
/// - Does: Runs the inverse sine-transform rule engine.
/// - Input: One source `Expr`, variables `k` and `x`.
/// - Returns: One transformed `Expr`.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn inverse_sine_transform_eval(expr : Expr, k : Expr, x : Expr) -> Expr {
  do_inverse_sine_doit(expr, k, x).unwrap_or(inverse_sine_transform(expr, k, x))
}

///|
/// Evaluate a cosine transform.
///
/// - Does: Runs the forward cosine-transform rule engine.
/// - Input: One source `Expr`, variables `x` and `k`.
/// - Returns: One transformed `Expr`.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn cosine_transform_eval(expr : Expr, x : Expr, k : Expr) -> Expr {
  do_cosine_doit(expr, x, k).unwrap_or(cosine_transform(expr, x, k))
}

///|
/// Evaluate an inverse cosine transform.
///
/// - Does: Runs the inverse cosine-transform rule engine.
/// - Input: One source `Expr`, variables `k` and `x`.
/// - Returns: One transformed `Expr`.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn inverse_cosine_transform_eval(expr : Expr, k : Expr, x : Expr) -> Expr {
  do_inverse_cosine_doit(expr, k, x).unwrap_or(
    inverse_cosine_transform(expr, k, x),
  )
}

///|
/// Evaluate a Hankel transform.
///
/// - Does: Runs the forward Hankel-transform rule engine for order `nu`.
/// - Input: One source `Expr`, variables `r` and `k`, and order `nu`.
/// - Returns: One transformed `Expr`.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn hankel_transform_eval(
  expr : Expr,
  r : Expr,
  k : Expr,
  nu : Expr,
) -> Expr {
  do_hankel_doit(expr, r, k, nu).unwrap_or(hankel_transform(expr, r, k, nu))
}

///|
/// Evaluate an inverse Hankel transform.
///
/// - Does: Runs the inverse Hankel-transform rule engine for order `nu`.
/// - Input: One source `Expr`, variables `k` and `r`, and order `nu`.
/// - Returns: One transformed `Expr`.
/// - Limits: Unevaluated transforms are returned when no rule applies.
pub fn inverse_hankel_transform_eval(
  expr : Expr,
  k : Expr,
  r : Expr,
  nu : Expr,
) -> Expr {
  do_inverse_hankel_doit(expr, k, r, nu).unwrap_or(
    inverse_hankel_transform(expr, k, r, nu),
  )
}

///|
/// Evaluate one integral or transform object recursively.
///
/// - Does: Acts as the common `.doit()`-style front door for integral and transform objects.
/// - Input: One symbolic `Expr`.
/// - Returns: One evaluated or partially evaluated `Expr`.
/// - Limits: Unsupported subexpressions remain unevaluated.
pub fn doit(expr : Expr) -> Expr {
  match @symcore.application_parts(expr) {
    Some((head, args)) =>
      match @symcore.function_head_name(head) {
        Some("Integral") if !args.is_empty() =>
          if args.length() == 1 {
            integrate(args[0])
          } else {
            let limits : Array[Expr] = []
            for i in 1..<args.length() {
              limits.push(args[i])
            }
            integrate(args[0], limits~)
          }
        Some("LaplaceTransform") =>
          match args {
            [inner, t, s] =>
              match do_laplace_doit(inner, t, s) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("InverseLaplaceTransform") =>
          match args {
            [inner, s, t] | [inner, s, t, _] =>
              match do_inverse_laplace_doit(inner, s, t) {
                Some(res) =>
                  match args {
                    [_, _, _, plane] =>
                      inverse_laplace_fill_plane(res, Some(plane))
                    _ => res
                  }
                None => expr
              }
            _ => expr
          }
        Some("FourierTransform") =>
          match args {
            [inner, x, k] =>
              match do_fourier_doit(inner, x, k) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("InverseFourierTransform") =>
          match args {
            [inner, k, x] =>
              match do_inverse_fourier_doit(inner, k, x) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("SineTransform") =>
          match args {
            [inner, x, k] =>
              match do_sine_doit(inner, x, k) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("InverseSineTransform") =>
          match args {
            [inner, k, x] =>
              match do_inverse_sine_doit(inner, k, x) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("CosineTransform") =>
          match args {
            [inner, x, k] =>
              match do_cosine_doit(inner, x, k) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("InverseCosineTransform") =>
          match args {
            [inner, k, x] =>
              match do_inverse_cosine_doit(inner, k, x) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("MellinTransform") =>
          match args {
            [inner, x, s] =>
              match do_mellin_doit(inner, x, s) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("InverseMellinTransform") =>
          match args {
            [inner, s, x] =>
              match do_inverse_mellin_doit(inner, s, x) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("HankelTransform") =>
          match args {
            [inner, r, k, nu] =>
              match do_hankel_doit(inner, r, k, nu) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        Some("InverseHankelTransform") =>
          match args {
            [inner, k, r, nu] =>
              match do_inverse_hankel_doit(inner, k, r, nu) {
                Some(res) => res
                None => expr
              }
            _ => expr
          }
        _ => expr
      }
    None => expr
  }
}
