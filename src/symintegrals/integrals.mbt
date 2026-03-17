///|
/// Core `Integral` / transform objects and the main `integrate` entrypoint.

///|
pub fn integral(expr : Expr, limits? : Array[Expr] = []) -> Expr {
  let args : Array[Expr] = [expr]
  for limit in limits {
    args.push(limit)
  }
  @symcore.raw_function("Integral", args)
}

///|
pub fn integral_limit(items : Array[Expr]) -> Expr {
  tuple_expr(items)
}

///|
pub fn laplace_transform(expr : Expr, t : Expr, s : Expr) -> Expr {
  @symcore.raw_function("LaplaceTransform", [expr, t, s])
}

///|
pub fn inverse_laplace_transform(expr : Expr, s : Expr, t : Expr) -> Expr {
  @symcore.raw_function("InverseLaplaceTransform", [expr, s, t])
}

///|
pub fn fourier_transform(expr : Expr, x : Expr, k : Expr) -> Expr {
  @symcore.raw_function("FourierTransform", [expr, x, k])
}

///|
pub fn inverse_fourier_transform(expr : Expr, k : Expr, x : Expr) -> Expr {
  @symcore.raw_function("InverseFourierTransform", [expr, k, x])
}

///|
pub fn sine_transform(expr : Expr, x : Expr, k : Expr) -> Expr {
  @symcore.raw_function("SineTransform", [expr, x, k])
}

///|
pub fn inverse_sine_transform(expr : Expr, k : Expr, x : Expr) -> Expr {
  @symcore.raw_function("InverseSineTransform", [expr, k, x])
}

///|
pub fn cosine_transform(expr : Expr, x : Expr, k : Expr) -> Expr {
  @symcore.raw_function("CosineTransform", [expr, x, k])
}

///|
pub fn inverse_cosine_transform(expr : Expr, k : Expr, x : Expr) -> Expr {
  @symcore.raw_function("InverseCosineTransform", [expr, k, x])
}

///|
pub fn mellin_transform(expr : Expr, x : Expr, s : Expr) -> Expr {
  @symcore.raw_function("MellinTransform", [expr, x, s])
}

///|
pub fn inverse_mellin_transform(expr : Expr, s : Expr, x : Expr) -> Expr {
  @symcore.raw_function("InverseMellinTransform", [expr, s, x])
}

///|
pub fn hankel_transform(expr : Expr, r : Expr, k : Expr, nu : Expr) -> Expr {
  @symcore.raw_function("HankelTransform", [expr, r, k, nu])
}

///|
pub fn inverse_hankel_transform(
  expr : Expr,
  k : Expr,
  r : Expr,
  nu : Expr,
) -> Expr {
  @symcore.raw_function("InverseHankelTransform", [expr, k, r, nu])
}

///|
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
  let mut speed_sq = expr_zero()
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
pub fn heurisch_integrate(expr : Expr, limit_expr : Expr) -> Expr {
  match parse_limit(limit_expr) {
    Some((name, None, None)) =>
      heurisch(expr, name).unwrap_or(integral(expr, limits=[limit_expr]))
    _ => integral(expr, limits=[limit_expr])
  }
}

///|
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
                integral(expr, limits=[tuple_expr([@symcore.symbol(name)])])
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
    Some((name, None, None)) =>
      match risch_integrate(expr, name) {
        Some(res) => expr_simplify(res)
        None =>
          match meijerg_integrate(expr, name) {
            Some(res) => expr_simplify(res)
            None => integral(expr, limits=[limit])
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
pub fn laplace_transform_eval(
  expr : Expr,
  t : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  laplace_transform_result(expr, t, s, noconds~)
}

///|
pub fn mellin_transform_eval(
  expr : Expr,
  x : Expr,
  s : Expr,
  noconds? : Bool = false,
) -> Expr {
  mellin_transform_result(expr, x, s, noconds~)
}

///|
pub fn fourier_transform_eval(expr : Expr, x : Expr, k : Expr) -> Expr {
  do_fourier_doit(expr, x, k).unwrap_or(fourier_transform(expr, x, k))
}

///|
pub fn inverse_fourier_transform_eval(expr : Expr, k : Expr, x : Expr) -> Expr {
  do_inverse_fourier_doit(expr, k, x).unwrap_or(
    inverse_fourier_transform(expr, k, x),
  )
}

///|
pub fn sine_transform_eval(expr : Expr, x : Expr, k : Expr) -> Expr {
  do_sine_doit(expr, x, k).unwrap_or(sine_transform(expr, x, k))
}

///|
pub fn inverse_sine_transform_eval(expr : Expr, k : Expr, x : Expr) -> Expr {
  do_inverse_sine_doit(expr, k, x).unwrap_or(inverse_sine_transform(expr, k, x))
}

///|
pub fn cosine_transform_eval(expr : Expr, x : Expr, k : Expr) -> Expr {
  do_cosine_doit(expr, x, k).unwrap_or(cosine_transform(expr, x, k))
}

///|
pub fn inverse_cosine_transform_eval(expr : Expr, k : Expr, x : Expr) -> Expr {
  do_inverse_cosine_doit(expr, k, x).unwrap_or(
    inverse_cosine_transform(expr, k, x),
  )
}

///|
pub fn hankel_transform_eval(
  expr : Expr,
  r : Expr,
  k : Expr,
  nu : Expr,
) -> Expr {
  do_hankel_doit(expr, r, k, nu).unwrap_or(hankel_transform(expr, r, k, nu))
}

///|
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
pub fn doit(expr : Expr) -> Expr {
  match expr {
    @symcore.Expr::Function("Integral", args) if !args.is_empty() =>
      if args.length() == 1 {
        integrate(args[0])
      } else {
        let limits : Array[Expr] = []
        for i in 1..<args.length() {
          limits.push(args[i])
        }
        integrate(args[0], limits~)
      }
    @symcore.Expr::Function("LaplaceTransform", [inner, t, s]) =>
      match do_laplace_doit(inner, t, s) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("InverseLaplaceTransform", [inner, s, t]) =>
      match do_inverse_laplace_doit(inner, s, t) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("FourierTransform", [inner, x, k]) =>
      match do_fourier_doit(inner, x, k) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("InverseFourierTransform", [inner, k, x]) =>
      match do_inverse_fourier_doit(inner, k, x) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("SineTransform", [inner, x, k]) =>
      match do_sine_doit(inner, x, k) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("InverseSineTransform", [inner, k, x]) =>
      match do_inverse_sine_doit(inner, k, x) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("CosineTransform", [inner, x, k]) =>
      match do_cosine_doit(inner, x, k) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("InverseCosineTransform", [inner, k, x]) =>
      match do_inverse_cosine_doit(inner, k, x) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("MellinTransform", [inner, x, s]) =>
      match do_mellin_doit(inner, x, s) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("InverseMellinTransform", [inner, s, x]) =>
      match do_inverse_mellin_doit(inner, s, x) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("HankelTransform", [inner, r, k, nu]) =>
      match do_hankel_doit(inner, r, k, nu) {
        Some(res) => res
        None => expr
      }
    @symcore.Expr::Function("InverseHankelTransform", [inner, k, r, nu]) =>
      match do_inverse_hankel_doit(inner, k, r, nu) {
        Some(res) => res
        None => expr
      }
    _ => expr
  }
}
