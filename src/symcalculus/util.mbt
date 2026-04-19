///|
/// Calculus utility front doors.
///
/// Current Limits:
/// - Period detection is limited to elementary linear arguments.
/// - Unknown periods return `None` instead of raising.

///|
fn util_rat_zero() -> BigRational {
  BigRational::zero()
}

///|
fn util_rat_one() -> BigRational {
  BigRational::one()
}

///|
fn util_rat_add(a : BigRational, b : BigRational) -> BigRational {
  a.add_r(b)
}

///|
fn util_rat_abs(a : BigRational) -> BigRational {
  if a.compare(util_rat_zero()) < 0 {
    a.neg_r()
  } else {
    a
  }
}

///|
fn util_rat_div(a : BigRational, b : BigRational) -> BigRational? {
  if b.is_zero() {
    None
  } else {
    match (try? a.div_r(b) : Result[BigRational, @symnum.RationalError]) {
      Ok(value) => Some(value)
      Err(_) => None
    }
  }
}

///|
fn util_expr_is_symbol(expr : Expr, sym : Expr) -> Bool {
  @symcore.compare_expr(expr, sym) == 0
}

///|
fn util_depends_on(expr : Expr, sym : Expr) -> Bool {
  if util_expr_is_symbol(expr, sym) {
    return true
  }
  match expr {
    Expr::Add(args) | Expr::Mul(args) =>
      args.any(arg => util_depends_on(arg, sym))
    Expr::Pow(base, exp) =>
      util_depends_on(base, sym) || util_depends_on(exp, sym)
    _ => @symcore.args(expr).any(arg => util_depends_on(arg, sym))
  }
}

///|
fn util_extract_linear_coeff(expr : Expr, sym : Expr) -> BigRational? {
  match expr {
    Expr::Symbol(_) if util_expr_is_symbol(expr, sym) => Some(util_rat_one())
    Expr::Mul(args) if args.length() == 2 => {
      let mut coeff : BigRational? = None
      let mut saw_sym = false
      for arg in args {
        match arg {
          Expr::Number(c) =>
            if coeff is None {
              coeff = Some(c)
            } else {
              return None
            }
          Expr::Symbol(_) if util_expr_is_symbol(arg, sym) => saw_sym = true
          _ => return None
        }
      }
      if saw_sym {
        coeff
      } else {
        None
      }
    }
    Expr::Add(args) => {
      let mut coeff = util_rat_zero()
      for arg in args {
        match arg {
          Expr::Number(_) => ()
          Expr::Symbol(_) if util_expr_is_symbol(arg, sym) =>
            coeff = util_rat_add(coeff, util_rat_one())
          Expr::Mul(margs) if margs.length() == 2 => {
            let mut linear_coeff : BigRational? = None
            let mut saw_sym = false
            for marg in margs {
              match marg {
                Expr::Number(c) =>
                  if linear_coeff is None {
                    linear_coeff = Some(c)
                  } else {
                    return None
                  }
                Expr::Symbol(_) if util_expr_is_symbol(marg, sym) =>
                  saw_sym = true
                _ => return None
              }
            }
            if saw_sym {
              match linear_coeff {
                Some(c) => coeff = util_rat_add(coeff, c)
                None => return None
              }
            } else {
              return None
            }
          }
          _ => return None
        }
      }
      Some(coeff)
    }
    _ => None
  }
}

///|
fn util_mul_scalar(expr : Expr, k : BigRational) -> Expr {
  if k.is_one() {
    expr
  } else {
    @symcore.mul([@symcore.Expr::Number(k), expr])
  }
}

///|
/// Return the smallest positive period of an elementary periodic expression.
///
/// The current implementation recognizes linear arguments of `sin`, `cos`, and
/// `tan`. Expressions independent of `sym` have period `0`.
///
/// - Does: Attempts to find a smallest positive period for an expression.
/// - Input: An expression and the symbol with respect to which periodicity is
///   checked.
/// - Returns: `Some(period)` for known cases, `Some(0)` for independent
///   expressions, or `None` when unknown.
/// - Limits: Only simple linear `sin`, `cos`, and `tan` cases are recognized.
pub fn periodicity(expr : Expr, sym : Expr) -> Expr? {
  if !util_depends_on(expr, sym) {
    return Some(@symcore.int(0))
  }
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some(name), Some([arg, ..])) => {
      let k_opt = util_extract_linear_coeff(arg, sym)
      match k_opt {
        Some(k) => {
          if k.is_zero() {
            return Some(@symcore.int(0))
          }
          let abs_k = util_rat_abs(k)
          let inv = util_rat_div(util_rat_one(), abs_k)
          let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
          let base = match name {
            "sin" | "cos" => @symcore.mul([@symcore.int(2), pi])
            "tan" => pi
            _ => return None
          }
          match inv {
            Some(factor) => Some(util_mul_scalar(base, factor))
            None => None
          }
        }
        None => None
      }
    }
    _ => None
  }
}
