///|
/// Front doors for Big-O markers in series expressions.
///
/// Current Limits:
/// - This file exposes lightweight wrappers around the local `O(...)` representation.
/// - It does not attempt full algebra over order terms.

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
/// Check whether an expression is an order marker.
///
/// - Does: Detects whether `expr` is stored as an `O(...)` application.
/// - Input: Any `Expr`.
/// - Returns: `true` when the expression is an order term and `false` otherwise.
/// - Limits: Only the local `O(...)` representation is recognized.
pub fn is_order(expr : @symcore.Expr) -> Bool {
  @symcore.application_has_name(expr, "O")
}

///|
/// Extract the argument of an order marker.
///
/// - Does: Returns the first argument of `O(...)` when `expr` is an order term.
/// - Input: Any `Expr`.
/// - Returns: `Some(arg)` for order terms and `None` otherwise.
/// - Limits: Only `O(...)` with at least one argument is recognized.
pub fn order_arg(expr : @symcore.Expr) -> @symcore.Expr? {
  match @symcore.application_args(expr) {
    Some(args) if @symcore.application_has_name(expr, "O") =>
      if args.is_empty() {
        None
      } else {
        Some(args[0])
      }
    _ => None
  }
}

///|
/// Wrap an expression into an order marker.
///
/// - Does: Normalizes the input and returns its `O(...)` representation.
/// - Input: Any `Expr`.
/// - Returns: One `Expr` that is either `0`, an existing order term, or a new `O(...)` wrapper.
/// - Limits: The normalization is intentionally lightweight and only strips obvious scalar factors.
pub fn big_o(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    _ if @symcore.application_has_name(expr, "O") => expr
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
/// Alias for `big_o`.
///
/// - Does: Builds the local order marker for `expr`.
/// - Input: Any `Expr`.
/// - Returns: One `Expr` in the same form as `big_o(expr)`.
/// - Limits: Has the same behavior and limits as `big_o`.
pub fn order(expr : @symcore.Expr) -> @symcore.Expr {
  big_o(expr)
}
