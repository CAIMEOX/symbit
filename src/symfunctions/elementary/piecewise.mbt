///|
/// Piecewise expressions.

///|
pub(all) struct PiecewiseCase {
  expr : @symcore.Expr
  cond : @symlogic.BoolExpr
}

///|
fn cond_to_expr(cond : @symlogic.BoolExpr) -> @symcore.Expr {
  match cond {
    @symlogic.BoolExpr::True => @symcore.symbol("True")
    @symlogic.BoolExpr::False => @symcore.symbol("False")
    @symlogic.BoolExpr::Symbol(name) => @symcore.symbol(name)
    _ => @symcore.symbol(@symlogic.to_string(cond))
  }
}

///|
pub fn piecewise(
  cases : Array[PiecewiseCase],
  default? : @symcore.Expr = @symcore.function("NaN", []),
) -> @symcore.Expr {
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
  let args : Array[@symcore.Expr] = Array::new()
  for c in filtered {
    args.push(c.expr)
    args.push(cond_to_expr(c.cond))
  }
  args.push(default)
  args.push(@symcore.symbol("True"))
  if args.length() == 2 && args[1] == @symcore.symbol("True") {
    return args[0]
  }
  @symcore.function("Piecewise", args)
}

///|
pub fn piecewise_fold(expr : @symcore.Expr) -> @symcore.Expr {
  expr
}

///|
pub fn piecewise_exclusive(expr : @symcore.Expr) -> @symcore.Expr {
  expr
}
