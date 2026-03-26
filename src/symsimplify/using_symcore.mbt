///|
using @symcore {type Expr, int}

///|
fn exact_numeric_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(n) => Some(n)
    Expr::Float(f) =>
      if !f.is_finite() {
        None
      } else {
        let pair : Result[(BigInt, BigInt), @symnum.MpfError] = try? f.to_rational()
        match pair {
          Ok((num, den)) =>
            match
              (
                try? @symnum.BigRational::new(num, den) :
                Result[@symnum.BigRational, @symnum.RationalError]) {
              Ok(value) => Some(value)
              Err(_) => None
            }
          Err(_) => None
        }
      }
    Expr::ComplexFloat(z) =>
      if !z.is_finite() || !@symnum.is_zero(z.to_mpc().imag) {
        None
      } else {
        let pair : Result[(BigInt, BigInt), @symnum.MpfError] = try? z
          .real_part()
          .to_rational()
        match pair {
          Ok((num, den)) =>
            match
              (
                try? @symnum.BigRational::new(num, den) :
                Result[@symnum.BigRational, @symnum.RationalError]) {
              Ok(value) => Some(value)
              Err(_) => None
            }
          Err(_) => None
        }
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
    Expr::Add(args) | Expr::Mul(args) | Expr::Function(_, args) => {
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
