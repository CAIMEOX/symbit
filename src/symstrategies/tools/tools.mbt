///|\
/// Composite strategies (tools port).

///|
/// Full simultaneous exact substitution.
pub fn subs(
  mapping : Map[@symcore.Expr, @symcore.Expr],
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> (@symcore.Expr) -> @symcore.Expr {
  if mapping.is_empty() {
    return @strategies_core.identity
  }
  let rules : Array[(@symcore.Expr) -> @symcore.Expr] = Array::new()
  for k, v in mapping {
    rules.push(@strategies_rl.subs(k, v))
  }
  @strategies_traverse.top_down(@strategies_core.do_one(rules), fns~)
}

///|
/// Strategy for canonicalization.
pub fn canon(
  rules : Array[(@symcore.Expr) -> @symcore.Expr],
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> (@symcore.Expr) -> @symcore.Expr {
  let inner = @strategies_core.exhaust(@strategies_core.do_one(rules))
  @strategies_core.exhaust(@strategies_traverse.top_down(inner, fns~))
}

///|
/// Apply rules based on the expression type.
pub fn typed(
  ruletypes : Map[@strategies_util.ExprOp, (@symcore.Expr) -> @symcore.Expr],
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_core.switch(@strategies_util.expr_op, ruletypes)
}
