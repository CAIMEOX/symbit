///|
fn plot_interval_numeric_constant(expr : @symcore.Expr) -> PlotInterval? {
  match expr {
    @symcore.Expr::NumberSymbol(kind) =>
      match kind {
        @symcore.NumberSymbolKind::Pi => Some(plot_interval_point(@math.PI))
        @symcore.NumberSymbolKind::Exp1 => Some(plot_interval_point(@math.exp(1.0)))
        _ => None
      }
    _ =>
      match plot_expr_to_complex_parts(expr) {
        Some((real, imag)) if imag.abs() <= 1.0e-8 => Some(plot_interval_point(real))
        _ => None
      }
  }
}

///|
fn plot_interval_eval_scalar(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  interval_x : PlotInterval,
  variable_y : @symcore.Expr,
  interval_y : PlotInterval,
) -> PlotInterval? {
  if expr == variable_x {
    return Some(interval_x)
  }
  if expr == variable_y {
    return Some(interval_y)
  }
  match plot_interval_numeric_constant(expr) {
    Some(value) => return Some(value)
    None => ()
  }
  match expr {
    @symcore.Expr::Add(args) => {
      let mut current = plot_interval_point(0.0)
      for arg in args {
        match plot_interval_eval_scalar(arg, variable_x, interval_x, variable_y, interval_y) {
          Some(value) => current = plot_interval_add(current, value)
          None => return None
        }
      }
      Some(current)
    }
    @symcore.Expr::Mul(args) => {
      let mut current = plot_interval_point(1.0)
      for arg in args {
        match plot_interval_eval_scalar(arg, variable_x, interval_x, variable_y, interval_y) {
          Some(value) => current = plot_interval_mul(current, value)
          None => return None
        }
      }
      Some(current)
    }
    @symcore.Expr::Pow(base, exponent) =>
      match (
        plot_interval_eval_scalar(base, variable_x, interval_x, variable_y, interval_y),
        plot_interval_numeric_constant(exponent),
      ) {
        (Some(base_interval), Some(power_interval)) if plot_interval_width(power_interval).abs() <= 1.0e-12 =>
          Some(plot_interval_pow_float(base_interval, power_interval.start))
        _ => None
      }
    @symcore.Expr::Apply(@symcore.Expr::FunctionHead(name), args)
    | @symcore.Expr::Function(name, args) =>
      match (name, args) {
        ("sin", [arg]) =>
          plot_interval_eval_scalar(arg, variable_x, interval_x, variable_y, interval_y)
          .map(plot_interval_sin)
        ("cos", [arg]) =>
          plot_interval_eval_scalar(arg, variable_x, interval_x, variable_y, interval_y)
          .map(plot_interval_cos)
        ("tan", [arg]) =>
          plot_interval_eval_scalar(arg, variable_x, interval_x, variable_y, interval_y)
          .map(plot_interval_tan)
        ("exp", [arg]) =>
          plot_interval_eval_scalar(arg, variable_x, interval_x, variable_y, interval_y)
          .map(plot_interval_exp)
        ("log", [arg]) =>
          plot_interval_eval_scalar(arg, variable_x, interval_x, variable_y, interval_y)
          .map(plot_interval_log)
        ("sqrt", [arg]) =>
          plot_interval_eval_scalar(arg, variable_x, interval_x, variable_y, interval_y)
          .map(plot_interval_sqrt)
        ("Abs", [arg]) =>
          plot_interval_eval_scalar(arg, variable_x, interval_x, variable_y, interval_y)
          .map(plot_interval_abs)
        _ => None
      }
    _ => None
  }
}

///|
fn plot_interval_eval_boolean(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  interval_x : PlotInterval,
  variable_y : @symcore.Expr,
  interval_y : PlotInterval,
) -> IntervalMembership? {
  match expr {
    @symcore.Expr::Boolean(value) => Some(interval_membership(Some(value), Some(true)))
    @symcore.Expr::Relational(op, lhs, rhs) =>
      match (
        plot_interval_eval_scalar(lhs, variable_x, interval_x, variable_y, interval_y),
        plot_interval_eval_scalar(rhs, variable_x, interval_x, variable_y, interval_y),
      ) {
        (Some(lhs_interval), Some(rhs_interval)) =>
          Some(
            match op {
              @symcore.RelOp::Eq => plot_interval_compare_eq(lhs_interval, rhs_interval)
              @symcore.RelOp::Ne => plot_interval_compare_ne(lhs_interval, rhs_interval)
              @symcore.RelOp::Lt => plot_interval_compare_lt(lhs_interval, rhs_interval)
              @symcore.RelOp::Le => plot_interval_compare_le(lhs_interval, rhs_interval)
              @symcore.RelOp::Gt => plot_interval_compare_gt(lhs_interval, rhs_interval)
              @symcore.RelOp::Ge => plot_interval_compare_ge(lhs_interval, rhs_interval)
            },
          )
        _ => None
      }
    @symcore.Expr::Apply(@symcore.Expr::FunctionHead(name), args)
    | @symcore.Expr::Function(name, args) =>
      match (name, args) {
        ("And", _) => {
          let mut current = interval_membership(Some(true), Some(true))
          for arg in args {
            match plot_interval_eval_boolean(
              arg,
              variable_x,
              interval_x,
              variable_y,
              interval_y,
            ) {
              Some(value) => {
                current = interval_membership_and(current, value)
              }
              None => return None
            }
          }
          Some(current)
        }
        ("Or", _) => {
          let mut current = interval_membership(Some(false), Some(false))
          for arg in args {
            match plot_interval_eval_boolean(
              arg,
              variable_x,
              interval_x,
              variable_y,
              interval_y,
            ) {
              Some(value) => {
                current = interval_membership_or(current, value)
              }
              None => return None
            }
          }
          Some(current)
        }
        ("Not", [arg]) =>
          plot_interval_eval_boolean(arg, variable_x, interval_x, variable_y, interval_y)
          .map(interval_membership_not)
        ("Xor", _) => {
          if args.is_empty() {
            return Some(interval_membership(Some(false), Some(true)))
          }
          let mut current = match plot_interval_eval_boolean(
            args[0],
            variable_x,
            interval_x,
            variable_y,
            interval_y,
          ) {
            Some(value) => value
            None => return None
          }
          for i in 1..<args.length() {
            match plot_interval_eval_boolean(
              args[i],
              variable_x,
              interval_x,
              variable_y,
              interval_y,
            ) {
              Some(value) => {
                current = interval_membership_xor(current, value)
              }
              None => return None
            }
          }
          Some(current)
        }
        _ =>
          plot_interval_eval_scalar(expr, variable_x, interval_x, variable_y, interval_y)
          .map(value => plot_interval_compare_eq(value, plot_interval_point(0.0)))
      }
    _ =>
      plot_interval_eval_scalar(expr, variable_x, interval_x, variable_y, interval_y)
      .map(value => plot_interval_compare_eq(value, plot_interval_point(0.0)))
  }
}

///|
fn plot_implicit_has_equality(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Relational(op, _, _) =>
      match op {
        @symcore.RelOp::Eq | @symcore.RelOp::Ge | @symcore.RelOp::Le => true
        _ => false
      }
    @symcore.Expr::Apply(@symcore.Expr::FunctionHead(name), args)
    | @symcore.Expr::Function(name, args) =>
      if name == "And" || name == "Or" || name == "Xor" {
        args.any(plot_implicit_has_equality)
      } else if name == "Not" {
        match args {
          [inner] => plot_implicit_has_equality(inner)
          _ => false
        }
      } else {
        false
      }
    _ => true
  }
}

///|
fn plot_implicit_interval_membership(
  expr : @symcore.Expr,
  variable_x : @symcore.Expr,
  interval_x : PlotInterval,
  variable_y : @symcore.Expr,
  interval_y : PlotInterval,
) -> IntervalMembership? {
  plot_interval_eval_boolean(expr, variable_x, interval_x, variable_y, interval_y)
}
