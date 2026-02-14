///|
pub fn use(
  expr : @symcore.Expr,
  func : (@symcore.Expr) -> @symcore.Expr,
  level? : Int = 0,
) -> @symcore.Expr {
  let depth = if level < 0 { 0 } else { level }
  use_at(expr, func, depth)
}

///|
fn use_at(
  expr : @symcore.Expr,
  func : (@symcore.Expr) -> @symcore.Expr,
  depth : Int,
) -> @symcore.Expr {
  if depth <= 0 {
    return func(expr)
  }
  if is_atom_traversal(expr) {
    return expr
  }
  @symcore.map_children(expr, child => use_at(child, func, depth - 1))
}

///|
fn is_atom_traversal(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(_) | @symcore.Expr::Symbol(_) => true
    _ => false
  }
}
