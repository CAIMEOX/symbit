///|
pub fn children(expr : Expr) -> ArrayView[Expr] {
  match expr {
    Expr::Add(args) | Expr::Mul(args) | Expr::Function(_, args) => args[:]
    Expr::Pow(base, exp) => [base, exp][:]
    _ => [][:]
  }
}

///|
pub fn map_children(expr : Expr, f : (Expr) -> Expr) -> Expr {
  match expr {
    Expr::Add(args) => add(args.map(f))
    Expr::Mul(args) => mul(args.map(f))
    Expr::Pow(base, exp) => pow(f(base), f(exp))
    Expr::Function(name, args) => function(name, args.map(f))
    _ => expr
  }
}

///|
pub fn subst(expr : Expr, env : Map[String, Expr]) -> Expr {
  match expr {
    Expr::Symbol(name) =>
      match env.get(name) {
        Some(value) => value
        None => expr
      }
    _ => map_children(expr, child => subst(child, env))
  }
}
