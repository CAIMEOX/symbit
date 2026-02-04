///|
fn sing_set_empty() -> Expr {
  @symcore.symbol("EmptySet")
}

///|
fn sing_set_finite(items : Array[Expr]) -> Expr {
  @symcore.function("FiniteSet", items)
}

///|
fn sing_expr_is_symbol(expr : Expr, sym : Expr) -> Bool {
  @symcore.compare_expr(expr, sym) == 0
}

///|
fn sing_rat_add(a : BigRational, b : BigRational) -> BigRational {
  a.add_r(b)
}

///|
fn sing_rat_neg(a : BigRational) -> BigRational {
  a.neg_r()
}

///|
fn sing_rat_div(a : BigRational, b : BigRational) -> BigRational? {
  let res : Result[BigRational, Error] = try? a.div_r(b)
  match res {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn sing_linear_coeff_const(
  expr : Expr,
  sym : Expr,
) -> (BigRational, BigRational)? {
  match expr {
    Expr::Symbol(_) if sing_expr_is_symbol(expr, sym) =>
      Some((BigRational::one(), BigRational::zero()))
    Expr::Mul(args) if args.length() == 2 =>
      match (args[0], args[1]) {
        (Expr::Number(c), Expr::Symbol(_)) if sing_expr_is_symbol(args[1], sym) =>
          Some((c, BigRational::zero()))
        _ => None
      }
    Expr::Add(args) => {
      let mut coeff = BigRational::zero()
      let mut constant = BigRational::zero()
      for arg in args {
        match arg {
          Expr::Number(n) => constant = sing_rat_add(constant, n)
          Expr::Symbol(_) if sing_expr_is_symbol(arg, sym) =>
            coeff = sing_rat_add(coeff, BigRational::one())
          Expr::Mul(margs) if margs.length() == 2 =>
            match (margs[0], margs[1]) {
              (Expr::Number(c), Expr::Symbol(_)) if sing_expr_is_symbol(
                  margs[1],
                  sym,
                ) => coeff = sing_rat_add(coeff, c)
              _ => return None
            }
          _ => return None
        }
      }
      Some((coeff, constant))
    }
    _ => None
  }
}

///|
fn sing_solve_linear(expr : Expr, sym : Expr) -> Expr? {
  match sing_linear_coeff_const(expr, sym) {
    Some((coeff, constant)) =>
      if coeff.is_zero() {
        None
      } else {
        let neg_const = sing_rat_neg(constant)
        match sing_rat_div(neg_const, coeff) {
          Some(sol) => Some(@symcore.number(sol))
          None => None
        }
      }
    None => None
  }
}

///|
fn sing_is_negative_integer(expr : Expr) -> Bool {
  match expr {
    Expr::Number(n) => n.is_integral() && n.compare(BigRational::zero()) < 0
    _ => false
  }
}

///|
fn sing_contains_expr(items : Array[Expr], expr : Expr) -> Bool {
  for item in items {
    if @symcore.compare_expr(item, expr) == 0 {
      return true
    }
  }
  false
}

///|
fn sing_collect(expr : Expr, sym : Expr, out : Array[Expr]) -> Unit {
  match expr {
    Expr::Pow(base, exp) => {
      if sing_is_negative_integer(exp) {
        match sing_solve_linear(base, sym) {
          Some(sol) => if !sing_contains_expr(out, sol) { out.push(sol) }
          None => ()
        }
      }
      sing_collect(base, sym, out)
      sing_collect(exp, sym, out)
    }
    Expr::Function(name, args) => {
      if name == "log" && args.length() >= 1 {
        match sing_solve_linear(args[0], sym) {
          Some(sol) => if !sing_contains_expr(out, sol) { out.push(sol) }
          None => ()
        }
      }
      for arg in args {
        sing_collect(arg, sym, out)
      }
    }
    Expr::Add(args) | Expr::Mul(args) =>
      for arg in args {
        sing_collect(arg, sym, out)
      }
    _ => ()
  }
}

///|
pub fn singularities(expr : Expr, sym : Expr) -> Expr {
  let out : Array[Expr] = Array::new()
  sing_collect(expr, sym, out)
  if out.is_empty() {
    sing_set_empty()
  } else {
    sing_set_finite(out)
  }
}
