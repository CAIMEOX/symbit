///|
/// Piecewise expressions.
///
/// Current Limits:
/// - This package stores piecewise cases as symbolic applications.
/// - Only direct true/false conditions are simplified.
/// - Folding and exclusivity normalization are currently conservative
///   pass-through front doors.

///|
/// Store one expression-and-condition branch for `piecewise`.
///
/// - Does: Carries a branch expression and its boolean condition.
/// - Input: An `Expr` result and a `BoolExpr` condition.
/// - Returns: One `PiecewiseCase` value.
/// - Limits: The struct does not validate condition overlap or exclusivity.
pub(all) struct PiecewiseCase {
  expr : Expr
  cond : @symlogic.BoolExpr
}

///|
fn cond_to_expr(cond : @symlogic.BoolExpr) -> Expr {
  match cond {
    True => Boolean(true)
    False => Boolean(false)
    Symbol(name) => Symbol(name)
    _ => Symbol(@symlogic.to_string(cond))
  }
}

///|
/// Build a symbolic piecewise expression.
///
/// - Does: Drops false cases, returns the first true case immediately, or builds
///   a symbolic `Piecewise` application with a default true branch.
/// - Input: An array of `PiecewiseCase` values and an optional default
///   expression.
/// - Returns: A selected branch, the default, or a symbolic `Piecewise`
///   expression.
/// - Limits: Does not simplify overlapping symbolic conditions or nested
///   piecewise forms.
pub fn piecewise(
  cases : Array[PiecewiseCase],
  default? : Expr = @symcore.function("NaN", []),
) -> Expr {
  let filtered : Array[PiecewiseCase] = Array::new()
  for c in cases {
    match c.cond {
      False => ()
      True => return c.expr
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
  args.push(Boolean(true))
  if args.length() == 2 && args[1] == Boolean(true) {
    return args[0]
  }
  @symcore.function("Piecewise", args)
}

///|
/// Fold piecewise subexpressions.
///
/// - Does: Public front door for piecewise folding.
/// - Input: One symbolic expression.
/// - Returns: The input expression unchanged.
/// - Limits: Full piecewise folding is not implemented yet.
pub fn piecewise_fold(expr : Expr) -> Expr {
  expr
}

///|
/// Make piecewise conditions mutually exclusive.
///
/// - Does: Public front door for exclusive piecewise normalization.
/// - Input: One symbolic expression.
/// - Returns: The input expression unchanged.
/// - Limits: Condition refinement and exclusivity generation are not implemented
///   yet.
pub fn piecewise_exclusive(expr : Expr) -> Expr {
  expr
}
