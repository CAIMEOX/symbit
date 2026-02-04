///|\
/// Aggregator for branch strategies.

///|
pub type BRule[T] = @branch_core.BRule[T]

///|
pub fn[T] identity(x : T) -> Array[T] {
  @branch_core.identity(x)
}

///|
pub fn[T : Eq + Hash] exhaust(brule : BRule[T]) -> BRule[T] {
  @branch_core.exhaust(brule)
}

///|
pub fn[T : Eq] onaction(
  brule : BRule[T],
  action : (BRule[T], T, T) -> Unit,
) -> BRule[T] {
  @branch_core.onaction(brule, action)
}

///|
pub fn[T : Eq + Show] debug(
  brule : BRule[T],
  name? : String = "rule",
  write? : (String) -> Unit = s => println(s),
) -> BRule[T] {
  @branch_core.debug(brule, name~, write~)
}

///|
pub fn[T : Eq + Hash] multiplex(brules : Array[BRule[T]]) -> BRule[T] {
  @branch_core.multiplex(brules)
}

///|
pub fn[T] condition(cond : (T) -> Bool, brule : BRule[T]) -> BRule[T] {
  @branch_core.condition(cond, brule)
}

///|
pub fn[T] sfilter(pred : (T) -> Bool, brule : BRule[T]) -> BRule[T] {
  @branch_core.sfilter(pred, brule)
}

///|
pub fn[T] notempty(brule : BRule[T]) -> BRule[T] {
  @branch_core.notempty(brule)
}

///|
pub fn[T] do_one(brules : Array[BRule[T]]) -> BRule[T] {
  @branch_core.do_one(brules)
}

///|
pub fn[T] chain(brules : Array[BRule[T]]) -> BRule[T] {
  @branch_core.chain(brules)
}

///|
pub fn[T] yieldify(rule : (T) -> T) -> BRule[T] {
  @branch_core.yieldify(rule)
}

///|
pub fn top_down(
  brule : BRule[@symcore.Expr],
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> BRule[@symcore.Expr] {
  @branch_traverse.top_down(brule, fns~)
}

///|
pub fn sall(
  brule : BRule[@symcore.Expr],
  fns? : @strategies_util.Fns[@symcore.Expr, @strategies_util.ExprOp] = @strategies_util.basic_fns,
) -> BRule[@symcore.Expr] {
  @branch_traverse.sall(brule, fns~)
}

///|
pub fn canon(rules : Array[BRule[@symcore.Expr]]) -> BRule[@symcore.Expr] {
  @branch_tools.canon(rules)
}
