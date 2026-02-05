///|
/// Elementary complex-valued functions.

///|
pub fn re(expr : @symcore.Expr) -> @symcore.Expr {
  match num_value(expr) {
    Some(_) => expr
    None => @symcore.function("re", [expr])
  }
}

///|
pub fn im(expr : @symcore.Expr) -> @symcore.Expr {
  match num_value(expr) {
    Some(_) => @symcore.int(0)
    None => @symcore.function("im", [expr])
  }
}

///|
pub fn sign(expr : @symcore.Expr) -> @symcore.Expr {
  match num_value(expr) {
    Some(n) => @symcore.int(sign_rational(n))
    None => @symcore.function("sign", [expr])
  }
}

///|
pub fn abs(expr : @symcore.Expr) -> @symcore.Expr {
  match num_value(expr) {
    Some(n) => @symcore.number(abs_rational(n))
    None => @symcore.function("Abs", [expr])
  }
}

///|
pub fn conjugate(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("conjugate", [expr])
}

///|
pub fn arg(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("arg", [expr])
}

///|
pub fn polar_lift(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("polar_lift", [expr])
}

///|
pub fn periodic_argument(
  expr : @symcore.Expr,
  period : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("periodic_argument", [expr, period])
}

///|
pub fn unbranched_argument(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("unbranched_argument", [expr])
}

///|
pub fn principal_branch(
  expr : @symcore.Expr,
  period : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("principal_branch", [expr, period])
}

///|
pub fn transpose(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("transpose", [expr])
}

///|
pub fn adjoint(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("adjoint", [expr])
}

///|
pub fn polarify(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("polarify", [expr])
}

///|
pub fn unpolarify(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("unpolarify", [expr])
}
