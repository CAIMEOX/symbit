///|
/// Elementary miscellaneous functions.

///|
pub fn sqrt(expr : Expr) -> Expr {
  if is_zero_expr(expr) || is_one_expr(expr) {
    return expr
  }
  @symcore.function("sqrt", [expr])
}

///|
pub fn root(base : Expr, n : Expr) -> Expr {
  if is_one_expr(n) {
    return base
  }
  @symcore.function("root", [base, n])
}

///|
pub fn real_root(base : Expr, n : Expr) -> Expr {
  @symcore.function("real_root", [base, n])
}

///|
pub fn cbrt(expr : Expr) -> Expr {
  @symcore.function("cbrt", [expr])
}

///|
pub fn min(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    return @symcore.function("Min", [])
  }
  let mut all_num = true
  let mut best : @symnum.BigRational? = None
  for arg in args {
    match num_value(arg) {
      Some(n) =>
        match best {
          Some(b) => if n.compare(b) < 0 { best = Some(n) }
          None => best = Some(n)
        }
      None => {
        all_num = false
        break
      }
    }
  }
  if all_num {
    return @symcore.Expr::Number(best.unwrap())
  }
  @symcore.function("Min", args)
}

///|
pub fn max(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    return @symcore.function("Max", [])
  }
  let mut all_num = true
  let mut best : @symnum.BigRational? = None
  for arg in args {
    match num_value(arg) {
      Some(n) =>
        match best {
          Some(b) => if n.compare(b) > 0 { best = Some(n) }
          None => best = Some(n)
        }
      None => {
        all_num = false
        break
      }
    }
  }
  if all_num {
    return @symcore.Expr::Number(best.unwrap())
  }
  @symcore.function("Max", args)
}

///|
pub fn id(expr : Expr) -> Expr {
  expr
}

///|
pub fn rem(a : Expr, b : Expr) -> Expr {
  @symcore.function("Rem", [a, b])
}
