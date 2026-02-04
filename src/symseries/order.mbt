///|
/// Minimal Big-O representation for series.

///|
fn normalize_order_arg(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(n) =>
      if n.is_zero() {
        @symcore.int(0)
      } else {
        @symcore.int(1)
      }
    @symcore.Expr::Mul(args) => {
      let kept : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Number(_) => ()
          _ => kept.push(arg)
        }
      }
      if kept.is_empty() {
        @symcore.int(1)
      } else if kept.length() == 1 {
        kept[0]
      } else {
        @symcore.mul(kept)
      }
    }
    @symcore.Expr::Pow(base, exp) =>
      match exp {
        @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(1)
        @symcore.Expr::Number(n) if n.is_one() => base
        _ => expr
      }
    _ => expr
  }
}

///|
pub fn is_order(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Function(name, _) => name == "O"
    _ => false
  }
}

///|
pub fn order_arg(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function(name, args) if name == "O" =>
      if args.is_empty() {
        None
      } else {
        Some(args[0])
      }
    _ => None
  }
}

///|
pub fn big_o(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, _) if name == "O" => expr
    _ => {
      let norm = normalize_order_arg(expr)
      match norm {
        @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(0)
        _ => @symcore.function("O", [norm])
      }
    }
  }
}

///|
pub fn order(expr : @symcore.Expr) -> @symcore.Expr {
  big_o(expr)
}
