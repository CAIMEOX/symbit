///|
/// Elementary miscellaneous functions.
///
/// Current Limits:
/// - Exact numeric simplification is intentionally small and local.
/// - Symbolic ordering, radical branch handling, and algebraic simplification
///   are not complete.

///|
/// Build a symbolic square-root expression.
///
/// - Does: Returns exact `0` or `1` unchanged, otherwise builds `sqrt(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic square-root expression.
/// - Limits: Does not rewrite to powers or simplify general numeric radicals.
pub fn sqrt(expr : Expr) -> Expr {
  if is_zero_expr(expr) || is_one_expr(expr) {
    return expr
  }
  @symcore.function("sqrt", [expr])
}

///|
/// Build a symbolic nth-root expression.
///
/// - Does: Returns the base when `n` is exact one, otherwise builds
///   `root(base, n)`.
/// - Input: A symbolic base and symbolic root degree.
/// - Returns: A symbolic root expression.
/// - Limits: Does not validate integer degree or branch selection.
pub fn root(base : Expr, n : Expr) -> Expr {
  if is_one_expr(n) {
    return base
  }
  @symcore.function("root", [base, n])
}

///|
/// Build a symbolic real-root expression.
///
/// - Does: Builds `real_root(base, n)`.
/// - Input: A symbolic base and symbolic root degree.
/// - Returns: A symbolic real-root expression.
/// - Limits: Does not validate odd/even degree semantics or numeric branches.
pub fn real_root(base : Expr, n : Expr) -> Expr {
  @symcore.function("real_root", [base, n])
}

///|
/// Build a symbolic cube-root expression.
///
/// - Does: Builds `cbrt(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic cube-root expression.
/// - Limits: Does not simplify numeric cubes or rewrite to rational powers.
pub fn cbrt(expr : Expr) -> Expr {
  @symcore.function("cbrt", [expr])
}

///|
/// Build or evaluate a minimum expression.
///
/// - Does: Returns the exact minimum when all inputs are numeric, otherwise
///   builds `Min(...)`.
/// - Input: An array of symbolic expressions.
/// - Returns: A numeric expression or symbolic `Min` application.
/// - Limits: Does not sort, deduplicate, or compare non-numeric symbolic
///   expressions.
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
    return Number(best.unwrap())
  }
  @symcore.function("Min", args)
}

///|
/// Build or evaluate a maximum expression.
///
/// - Does: Returns the exact maximum when all inputs are numeric, otherwise
///   builds `Max(...)`.
/// - Input: An array of symbolic expressions.
/// - Returns: A numeric expression or symbolic `Max` application.
/// - Limits: Does not sort, deduplicate, or compare non-numeric symbolic
///   expressions.
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
    return Number(best.unwrap())
  }
  @symcore.function("Max", args)
}

///|
/// Return an expression unchanged.
///
/// - Does: Implements the identity function.
/// - Input: One symbolic expression.
/// - Returns: The same expression value.
/// - Limits: Performs no normalization or copying.
pub fn id(expr : Expr) -> Expr {
  expr
}

///|
/// Build a symbolic remainder expression.
///
/// - Does: Builds `Rem(a, b)`.
/// - Input: Two symbolic expressions.
/// - Returns: A symbolic remainder expression.
/// - Limits: Does not currently evaluate numeric remainders.
pub fn rem(a : Expr, b : Expr) -> Expr {
  @symcore.function("Rem", [a, b])
}
