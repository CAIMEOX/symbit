///|
/// Elementary complex-valued functions.

///|
pub fn re(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(_) => expr
    None => @symcore.function("re", [expr])
  }
}

///|
pub fn im(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(_) => int(0)
    None => @symcore.function("im", [expr])
  }
}

///|
pub fn sign(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(n) => int(sign_rational(n))
    None => @symcore.function("sign", [expr])
  }
}

///|
pub fn abs(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(n) => @symcore.Expr::Number(abs_rational(n))
    None => @symcore.function("Abs", [expr])
  }
}

///|
pub fn conjugate(expr : Expr) -> Expr {
  @symcore.function("conjugate", [expr])
}

///|
pub fn arg(expr : Expr) -> Expr {
  @symcore.function("arg", [expr])
}

///|
pub fn polar_lift(expr : Expr) -> Expr {
  @symcore.function("polar_lift", [expr])
}

///|
pub fn periodic_argument(expr : Expr, period : Expr) -> Expr {
  @symcore.function("periodic_argument", [expr, period])
}

///|
pub fn unbranched_argument(expr : Expr) -> Expr {
  @symcore.function("unbranched_argument", [expr])
}

///|
pub fn principal_branch(expr : Expr, period : Expr) -> Expr {
  @symcore.function("principal_branch", [expr, period])
}

///|
pub fn transpose(expr : Expr) -> Expr {
  @symcore.function("transpose", [expr])
}

///|
pub fn adjoint(expr : Expr) -> Expr {
  @symcore.function("adjoint", [expr])
}

///|
pub fn polarify(expr : Expr) -> Expr {
  @symcore.function("polarify", [expr])
}

///|
pub fn unpolarify(expr : Expr) -> Expr {
  @symcore.function("unpolarify", [expr])
}
