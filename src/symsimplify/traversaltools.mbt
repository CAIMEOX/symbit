///|
/// - Does: Applies one callback to nodes at a fixed depth in the expression tree.
/// - Input: One `Expr`, one callback, and optional `level`.
/// - Returns: One rewritten `Expr`.
/// - Limits: Negative levels are clamped to `0`, and atoms are left untouched below that point.
pub fn apply_at_level(
  expr : Expr,
  func : (Expr) -> Expr,
  level? : Int = 0,
) -> Expr {
  let depth = if level < 0 { 0 } else { level }
  use_at(expr, func, depth)
}

///|
fn use_at(expr : Expr, func : (Expr) -> Expr, depth : Int) -> Expr {
  if depth <= 0 {
    return func(expr)
  }
  if is_atom_traversal(expr) {
    return expr
  }
  @symcore.map_children(expr, child => use_at(child, func, depth - 1))
}

///|
fn is_atom_traversal(expr : Expr) -> Bool {
  match expr {
    Expr::Number(_) | Expr::Symbol(_) => true
    _ => false
  }
}
