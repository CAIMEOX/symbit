///|
/// Piecewise expressions.

///|
pub(all) struct PiecewiseCase {
  expr : Expr
  cond : @symlogic.BoolExpr
}

///|
fn cond_to_expr(cond : @symlogic.BoolExpr) -> Expr {
  match cond {
    @symlogic.BoolExpr::True => @symcore.Expr::Boolean(true)
    @symlogic.BoolExpr::False => @symcore.Expr::Boolean(false)
    @symlogic.BoolExpr::Symbol(name) => Expr::Symbol(name)
    _ => Expr::Symbol(@symlogic.to_string(cond))
  }
}

///|
pub fn piecewise(
  cases : Array[PiecewiseCase],
  default? : Expr = @symcore.function("NaN", []),
) -> Expr {
  let filtered : Array[PiecewiseCase] = Array::new()
  for c in cases {
    match c.cond {
      @symlogic.BoolExpr::False => ()
      @symlogic.BoolExpr::True => return c.expr
      _ => filtered.push(c)
    }
  }
  if filtered.is_empty() {
    return default
  }
  let args : Array[Expr] = Array::new()
  for c in filtered {
    args.push(c.expr)
    args.push(cond_to_expr(c.cond))
  }
  args.push(default)
  args.push(@symcore.Expr::Boolean(true))
  if args.length() == 2 && args[1] == @symcore.Expr::Boolean(true) {
    return args[0]
  }
  @symcore.function("Piecewise", args)
}

///|
pub fn piecewise_fold(expr : Expr) -> Expr {
  expr
}

///|
pub fn piecewise_exclusive(expr : Expr) -> Expr {
  expr
}
