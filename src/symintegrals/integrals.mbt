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
pub fn mellin_transform(expr : Expr, x : Expr, s : Expr) -> Expr {
  @symcore.raw_function("MellinTransform", [expr, x, s])
}

///|
pub fn inverse_mellin_transform(expr : Expr, s : Expr, x : Expr) -> Expr {
  @symcore.raw_function("InverseMellinTransform", [expr, s, x])
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
          None => integral(expr, limits=[tuple_expr([@symcore.symbol(name)])])
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
        None => integral(expr, limits=[limit])
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
        None => integral(expr, limits=[limit])
      }
    }
    Some(_) => integral(expr, limits=[limit])
    None => integral(expr, limits=[limit])
  }
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
    _ => expr
  }
}
