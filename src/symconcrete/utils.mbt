///|
/// Shared helpers for symconcrete.

///|
fn is_zero_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn is_one_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_one()
    _ => false
  }
}

///|
fn is_integer_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_integral()
    _ => false
  }
}

///|
fn int_value(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() => {
      let num = n.numerator()
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
fn expr_add(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  if is_zero_expr(a) {
    b
  } else if is_zero_expr(b) {
    a
  } else {
    @symcore.add([a, b])
  }
}

///|
fn expr_mul(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  if is_zero_expr(a) || is_zero_expr(b) {
    @symcore.int(0)
  } else if is_one_expr(a) {
    b
  } else if is_one_expr(b) {
    a
  } else {
    @symcore.mul([a, b])
  }
}

///|
fn expr_neg(a : @symcore.Expr) -> @symcore.Expr {
  expr_mul(@symcore.int(-1), a)
}

///|
fn expr_sub(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  expr_add(a, expr_neg(b))
}

///|
fn expr_inv(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Number(n) =>
      if n.is_zero() {
        None
      } else {
        try n.reciprocal() catch {
          _ => None
        } noraise {
          v => Some(@symcore.number(v))
        }
      }
    _ => Some(@symcore.pow(expr, @symcore.int(-1)))
  }
}

///|
fn symbol_name(expr : @symcore.Expr) -> String? {
  match expr {
    @symcore.Expr::Symbol(name) => Some(name)
    _ => None
  }
}

///|
fn collect_symbol_names(expr : @symcore.Expr, acc : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => acc[name] = true
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      for arg in args {
        collect_symbol_names(arg, acc)
      }
    @symcore.Expr::Pow(base, exp) => {
      collect_symbol_names(base, acc)
      collect_symbol_names(exp, acc)
    }
    @symcore.Expr::Function(_, args) =>
      for arg in args {
        collect_symbol_names(arg, acc)
      }
    _ => ()
  }
}

///|
fn contains_symbol(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(sym) => sym == name
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) => {
      for arg in args {
        if contains_symbol(arg, name) {
          return true
        }
      }
      false
    }
    @symcore.Expr::Pow(base, exp) =>
      contains_symbol(base, name) || contains_symbol(exp, name)
    @symcore.Expr::Function(_, args) => {
      for arg in args {
        if contains_symbol(arg, name) {
          return true
        }
      }
      false
    }
    _ => false
  }
}
