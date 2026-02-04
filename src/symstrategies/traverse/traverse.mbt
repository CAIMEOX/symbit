///|\
/// Strategies to traverse Expr trees.

///|
/// Apply a rule down a tree, running it on top nodes first.
pub fn top_down(
  rule : (@symcore.Expr) -> @symcore.Expr,
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_core.chain([
    rule,
    (expr : @symcore.Expr) => sall(top_down(rule, fns~), fns~)(expr),
  ])
}

///|
/// Apply a rule down a tree, running it on bottom nodes first.
pub fn bottom_up(
  rule : (@symcore.Expr) -> @symcore.Expr,
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_core.chain([
    (expr : @symcore.Expr) => sall(bottom_up(rule, fns~), fns~)(expr),
    rule,
  ])
}

///|
/// Apply a rule down a tree - stop on success.
pub fn top_down_once(
  rule : (@symcore.Expr) -> @symcore.Expr,
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_core.do_one([
    rule,
    (expr : @symcore.Expr) => sall(top_down(rule, fns~), fns~)(expr),
  ])
}

///|
/// Apply a rule up a tree - stop on success.
pub fn bottom_up_once(
  rule : (@symcore.Expr) -> @symcore.Expr,
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_core.do_one([
    (expr : @symcore.Expr) => sall(bottom_up(rule, fns~), fns~)(expr),
    rule,
  ])
}

///|
/// Strategic all - apply rule to args.
pub fn sall(
  rule : (@symcore.Expr) -> @symcore.Expr,
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> (@symcore.Expr) -> @symcore.Expr {
  let op = fns.op
  let new = fns.new
  let children = fns.children
  let leaf = fns.leaf
  (expr : @symcore.Expr) => if leaf(expr) {
    expr
  } else {
    let args : Array[@symcore.Expr] = Array::new()
    for child in children(expr) {
      args.push(rule(child))
    }
    new(op(expr), args)
  }
}
