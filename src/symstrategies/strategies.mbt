///|\
/// Aggregator module for sympy.strategies equivalents.

///|
pub type ExprOp = @strategies_util.ExprOp

///|
pub type Fns[T, Op] = @strategies_util.Fns[T, Op]

///|
pub let basic_fns : @strategies_util.Fns[@symcore.Expr, ExprOp] = @strategies_util.basic_fns

///|
pub let expr_fns : @strategies_util.Fns[@symcore.Expr, ExprOp] = @strategies_util.expr_fns

///|
pub fn new(op : ExprOp, args : Array[@symcore.Expr]) -> @symcore.Expr {
  @strategies_util.new(op, args)
}

///|
pub fn[T] condition(cond : (T) -> Bool, rule : (T) -> T) -> (T) -> T {
  @strategies_core.condition(cond, rule)
}

///|
pub fn[T : Eq + Show] debug(
  rule : (T) -> T,
  name? : String = "rule",
  write? : (String) -> Unit = s => println(s),
) -> (T) -> T {
  @strategies_core.debug(rule, name~, write~)
}

///|
pub fn[T] chain(rules : Array[(T) -> T]) -> (T) -> T {
  @strategies_core.chain(rules)
}

///|
pub fn[T] null_safe(rule : (T) -> T?) -> (T) -> T {
  @strategies_core.null_safe(rule)
}

///|
pub fn[T : Eq] do_one(rules : Array[(T) -> T]) -> (T) -> T {
  @strategies_core.do_one(rules)
}

///|
pub fn[T : Eq] exhaust(rule : (T) -> T) -> (T) -> T {
  @strategies_core.exhaust(rule)
}

///|
pub fn[T : Compare] minimize(
  rules : Array[(T) -> T],
  objective? : (T) -> T = @strategies_core.identity,
) -> (T) -> T {
  @strategies_core.minimize(rules, objective~)
}

///|
pub fn[T] tryit(rule : (T) -> T raise, exception? : String = "") -> (T) -> T {
  @strategies_core.tryit(rule, _exception=exception)
}

///|
pub fn rm_id(
  isid : (@symcore.Expr) -> Bool,
  new? : (ExprOp, Array[@symcore.Expr]) -> @symcore.Expr = @strategies_util.new,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_rl.rm_id(isid, new~)
}

///|
pub fn unpack(expr : @symcore.Expr) -> @symcore.Expr {
  @strategies_rl.unpack(expr)
}

///|
pub fn flatten(
  expr : @symcore.Expr,
  new? : (ExprOp, Array[@symcore.Expr]) -> @symcore.Expr = @strategies_util.new,
) -> @symcore.Expr {
  @strategies_rl.flatten(expr, new~)
}

///|
pub fn[K : Compare] sort(
  key : (@symcore.Expr) -> K,
  new? : (ExprOp, Array[@symcore.Expr]) -> @symcore.Expr = @strategies_util.new,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_rl.sort(key, new~)
}

///|
pub fn[K : Eq + Hash, C : Add] glom(
  key : (@symcore.Expr) -> K,
  count : (@symcore.Expr) -> C,
  combine : (C, K) -> @symcore.Expr,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_rl.glom(key, count, combine)
}

///|
pub fn distribute(
  opA : ExprOp,
  opB : ExprOp,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_rl.distribute(opA, opB)
}

///|
pub fn rebuild(expr : @symcore.Expr) -> @symcore.Expr {
  @strategies_rl.rebuild(expr)
}

///|
pub fn canon(
  rules : Array[(@symcore.Expr) -> @symcore.Expr],
  fns? : @strategies_util.Fns[@symcore.Expr, ExprOp] = @strategies_util.basic_fns,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_tools.canon(rules, fns~)
}

///|
pub fn typed(
  ruletypes : Map[ExprOp, (@symcore.Expr) -> @symcore.Expr],
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_tools.typed(ruletypes)
}
