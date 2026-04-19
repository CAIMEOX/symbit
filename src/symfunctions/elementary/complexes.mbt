///|
/// Elementary complex-valued functions.
///
/// Current Limits:
/// - Exact rational numbers get small local simplifications.
/// - Assumption-driven real/imaginary analysis and matrix-specific adjoints are
///   not complete.
/// - Polar branch handling is represented symbolically.

///|
/// Extract the real part of an expression.
///
/// - Does: Returns exact numeric input unchanged, otherwise builds `re(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the real part.
/// - Limits: Does not infer realness from assumptions or composed functions.
pub fn re(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(_) => expr
    None => @symcore.function("re", [expr])
  }
}

///|
/// Extract the imaginary part of an expression.
///
/// - Does: Returns `0` for exact numeric input, otherwise builds `im(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the imaginary part.
/// - Limits: Does not infer imaginary components from assumptions or composed
///   functions.
pub fn im(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(_) => int(0)
    None => @symcore.function("im", [expr])
  }
}

///|
/// Build or evaluate the sign of an expression.
///
/// - Does: Returns the sign of exact numeric input, otherwise builds
///   `sign(expr)`.
/// - Input: One symbolic expression.
/// - Returns: `-1`, `0`, `1`, or a symbolic sign expression.
/// - Limits: Does not use assumptions or complex phase analysis.
pub fn sign(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(n) => int(sign_rational(n))
    None => @symcore.function("sign", [expr])
  }
}

///|
/// Build or evaluate the absolute value of an expression.
///
/// - Does: Returns the non-negative exact numeric value when possible, otherwise
///   builds `Abs(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A numeric or symbolic absolute-value expression.
/// - Limits: Does not simplify products, powers, or assumption-constrained
///   expressions.
pub fn abs(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(n) => @symcore.Expr::Number(abs_rational(n))
    None => @symcore.function("Abs", [expr])
  }
}

///|
/// Build a symbolic complex conjugate.
///
/// - Does: Builds `conjugate(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the complex conjugate.
/// - Limits: Does not currently simplify real or imaginary assumptions.
pub fn conjugate(expr : Expr) -> Expr {
  @symcore.function("conjugate", [expr])
}

///|
/// Build a symbolic complex argument.
///
/// - Does: Builds `arg(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the principal argument.
/// - Limits: Does not evaluate quadrant or branch-cut cases.
pub fn arg(expr : Expr) -> Expr {
  @symcore.function("arg", [expr])
}

///|
/// Lift an expression to the polar surface.
///
/// - Does: Builds `polar_lift(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic polar-lift expression.
/// - Limits: Does not canonicalize nested polar expressions.
pub fn polar_lift(expr : Expr) -> Expr {
  @symcore.function("polar_lift", [expr])
}

///|
/// Build a periodic argument expression.
///
/// - Does: Builds `periodic_argument(expr, period)`.
/// - Input: One symbolic expression and one symbolic period.
/// - Returns: A symbolic periodic-argument expression.
/// - Limits: Does not reduce arguments modulo the period.
pub fn periodic_argument(expr : Expr, period : Expr) -> Expr {
  @symcore.function("periodic_argument", [expr, period])
}

///|
/// Build an unbranched argument expression.
///
/// - Does: Builds `unbranched_argument(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic unbranched-argument expression.
/// - Limits: Does not evaluate branch sheets.
pub fn unbranched_argument(expr : Expr) -> Expr {
  @symcore.function("unbranched_argument", [expr])
}

///|
/// Build a principal branch expression.
///
/// - Does: Builds `principal_branch(expr, period)`.
/// - Input: One symbolic expression and one symbolic period.
/// - Returns: A symbolic principal-branch expression.
/// - Limits: Does not reduce or normalize the branch representative.
pub fn principal_branch(expr : Expr, period : Expr) -> Expr {
  @symcore.function("principal_branch", [expr, period])
}

///|
/// Build a symbolic transpose expression.
///
/// - Does: Builds `transpose(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic transpose expression.
/// - Limits: Does not inspect matrix shape or distribute over expressions.
pub fn transpose(expr : Expr) -> Expr {
  @symcore.function("transpose", [expr])
}

///|
/// Build a symbolic adjoint expression.
///
/// - Does: Builds `adjoint(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic adjoint expression.
/// - Limits: Does not inspect matrix shape or simplify conjugate transpose
///   cases.
pub fn adjoint(expr : Expr) -> Expr {
  @symcore.function("adjoint", [expr])
}

///|
/// Build a symbolic polarification request.
///
/// - Does: Builds `polarify(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic polarification expression.
/// - Limits: Does not return auxiliary replacement maps.
pub fn polarify(expr : Expr) -> Expr {
  @symcore.function("polarify", [expr])
}

///|
/// Build a symbolic unpolarification request.
///
/// - Does: Builds `unpolarify(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic unpolarification expression.
/// - Limits: Does not traverse and rewrite nested polar subexpressions.
pub fn unpolarify(expr : Expr) -> Expr {
  @symcore.function("unpolarify", [expr])
}
