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
  if a.compare(util_rat_zero()) < 0 { a.neg_r() } else { a }
}

///|
fn util_rat_div(a : BigRational, b : BigRational) -> BigRational? {
  let res : Result[BigRational, Error] = try? a.div_r(b)
  match res {
    Ok(v) => Some(v)
    Err(_) => None
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
    Expr::Add(args) | Expr::Mul(args) => args.any(arg => util_depends_on(arg, sym))
    Expr::Pow(base, exp) => util_depends_on(base, sym) || util_depends_on(exp, sym)
    Expr::Function(_, args) => args.any(arg => util_depends_on(arg, sym))
    _ => false
  }
}

///|
fn util_extract_linear_coeff(expr : Expr, sym : Expr) -> BigRational? {
  match expr {
    Expr::Symbol(_) if util_expr_is_symbol(expr, sym) => Some(util_rat_one())
    Expr::Mul(args) if args.length() == 2 =>
      match (args[0], args[1]) {
        (Expr::Number(c), Expr::Symbol(_)) if util_expr_is_symbol(args[1], sym) => Some(c)
        _ => None
      }
    Expr::Add(args) => {
      let mut coeff = util_rat_zero()
      for arg in args {
        match arg {
          Expr::Number(_) => ()
          Expr::Symbol(_) if util_expr_is_symbol(arg, sym) =>
            coeff = util_rat_add(coeff, util_rat_one())
          Expr::Mul(margs) if margs.length() == 2 =>
            match (margs[0], margs[1]) {
              (Expr::Number(c), Expr::Symbol(_)) if util_expr_is_symbol(margs[1], sym) =>
                coeff = util_rat_add(coeff, c)
              _ => return None
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
    @symcore.mul([@symcore.number(k), expr])
  }
}

///|
pub fn periodicity(expr : Expr, sym : Expr) -> Expr? {
  if !util_depends_on(expr, sym) {
    return Some(@symcore.int(0))
  }
  match expr {
    Expr::Function(name, args) if args.length() >= 1 => {
      let k_opt = util_extract_linear_coeff(args[0], sym)
      match k_opt {
        Some(k) => {
          if k.is_zero() {
            return Some(@symcore.int(0))
          }
          let abs_k = util_rat_abs(k)
          let inv = util_rat_div(util_rat_one(), abs_k)
          let pi = @symcore.symbol("pi")
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
