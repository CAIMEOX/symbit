///|
using @symcore {type Expr, int}

///|
fn unary_application_arg(expr : Expr, name : String) -> Expr? {
  match @symcore.application_args(expr) {
    Some([arg]) if @symcore.application_has_name(expr, name, arity=1) =>
      Some(arg)
    _ => None
  }
}

///|
fn named_unary_application(expr : Expr) -> (String, Expr)? {
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some(name), Some([arg])) => Some((name, arg))
    _ => None
  }
}

///|
fn named_binary_application(expr : Expr) -> (String, Expr, Expr)? {
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some(name), Some([lhs, rhs])) => Some((name, lhs, rhs))
    _ => None
  }
}

///|
fn pow_named_unary_application(expr : Expr) -> (String, Expr, Expr)? {
  match expr {
    Expr::Pow(base, exp) =>
      match named_unary_application(base) {
        Some((name, arg)) => Some((name, arg, exp))
        None => None
      }
    _ => None
  }
}

///|
fn exact_numeric_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(n) => Some(n)
    Expr::Float(f) =>
      if !f.is_finite() {
        None
      } else {
        let (num, den) = f.to_rational() catch { _ => return None }
        Some(@symnum.BigRational::new(num, den) catch { _ => return None })
      }
    Expr::ComplexFloat(z) =>
      if !z.is_finite() || !@symnum.is_zero(z.to_mpc().imag) {
        None
      } else {
        let (num, den) = z.real_part().to_rational() catch { _ => return None }
        Some(@symnum.BigRational::new(num, den) catch { _ => return None })
      }
    _ => None
  }
}

///|
fn exact_integer_value(expr : Expr) -> Int? {
  match exact_numeric_value(expr) {
    Some(value) if value.is_integral() => {
      let num = value.numerator()
      if num.bit_length() > 30 {
        None
      } else {
        Some(num.to_int())
      }
    }
    _ => None
  }
}

///|
fn float_source_precision(expr : Expr) -> Int? {
  match expr {
    Expr::Float(f) => Some(f.precision())
    Expr::ComplexFloat(z) => Some(z.precision())
    Expr::Add(args) | Expr::Mul(args) => {
      let mut best : Int? = None
      for arg in args {
        match float_source_precision(arg) {
          Some(prec) =>
            best = Some(
              match best {
                Some(current) if current > prec => current
                _ => prec
              },
            )
          None => ()
        }
      }
      best
    }
    _ if @symcore.application_parts(expr) is Some(_) => {
      let mut best : Int? = None
      for arg in @symcore.application_args(expr).unwrap_or([]) {
        match float_source_precision(arg) {
          Some(prec) =>
            best = Some(
              match best {
                Some(current) if current > prec => current
                _ => prec
              },
            )
          None => ()
        }
      }
      best
    }
    Expr::Pow(base, exp) =>
      match (float_source_precision(base), float_source_precision(exp)) {
        (Some(lhs), Some(rhs)) => Some(if lhs > rhs { lhs } else { rhs })
        (Some(lhs), None) => Some(lhs)
        (None, Some(rhs)) => Some(rhs)
        (None, None) => None
      }
    _ => None
  }
}

///|
fn numeric_result_like(source : Expr, exact_result : Expr) -> Expr {
  match float_source_precision(source) {
    Some(prec) => @symcore.evalf(exact_result, prec~)
    None => exact_result
  }
}

///|
fn numeric_zero_pred(expr : Expr) -> Bool {
  match exact_numeric_value(expr) {
    Some(value) => value.is_zero()
    None => false
  }
}

///|
fn numeric_one_pred(expr : Expr) -> Bool {
  match exact_numeric_value(expr) {
    Some(value) => value.is_one()
    None => false
  }
}
